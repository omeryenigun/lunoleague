import 'dart:convert';

import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

Future<void> migrateBilgiWallet(Connection db) async {
  await db.execute('''
    create table if not exists bilgi_wallet_ledger (
      id text primary key,
      user_id text not null,
      created_at timestamptz not null,
      asset text not null,
      amount int not null,
      balance_after int not null,
      reason text not null,
      ref text not null default '',
      detail jsonb not null default '{}'::jsonb,
      unique (user_id, reason, ref, asset)
    )
  ''');
  await db.execute(
    'create index if not exists bilgi_wallet_ledger_user_idx on bilgi_wallet_ledger (user_id, created_at desc)',
  );
}

void mountBilgiWallet(Router router, Connection db, KeyValueStore store) {
  final book = BilgiWalletBook(store, PostgresBilgiLedger(db));
  router
    ..post('/v1/bilgi/wallet', (request) => _apply(request, book))
    ..get('/v1/admin/bilgi-users/<id>/ledger', (Request request, String id) => _list(request, db, id))
    ..get('/v1/admin/bilgi-games', (request) => _games(request, db, store));
}

Future<Response> _apply(Request request, BilgiWalletBook book) async {
  final body = await readJson(request);
  final password = '${body['password'] ?? ''}';
  if (password.isNotEmpty) body['passwordHashCheck'] = hashBilgiPassword(password);
  final reply = await book.apply(body);
  if (reply.profile == null) {
    return jsonResponse({'error': reply.error ?? 'İşlem tamamlanamadı.'}, status: 400);
  }
  return jsonResponse({'ok': true, 'user': reply.profile!.toPublicMap()});
}

Future<Response> _list(Request request, Connection db, String id) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final userId = id.trim();
  if (userId.isEmpty) return jsonResponse({'error': 'Kullanıcı bulunamadı.'}, status: 404);
  final query = request.url.queryParameters;
  final rows = await PostgresBilgiLedger(db).list(
    userId,
    asset: query['asset'] ?? '',
    reason: query['reason'] ?? '',
    from: _day(query['from'], end: false),
    to: _day(query['to'], end: true),
  );
  return jsonResponse({'lines': [for (final line in rows) line.toMap()]});
}

Future<Response> _games(Request request, Connection db, KeyValueStore store) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final query = request.url.queryParameters;
  final rows = await PostgresBilgiLedger(db).games(
    from: _day(query['from'], end: false),
    to: _day(query['to'], end: true),
  );
  final names = <String, String>{};
  for (final row in await store.values(bilgiWalletUsers)) {
    final id = '${row['id'] ?? ''}'.trim();
    if (id.isEmpty) continue;
    final name = '${row['username'] ?? ''}'.trim();
    if (name.isNotEmpty) names[id] = name;
  }
  return jsonResponse({
    'games': [
      for (final row in rows)
        bilgiAdminGame(
          userId: row.userId,
          username: names[row.userId] ?? '',
          ref: row.ref,
          at: row.at,
          detail: row.detail,
          gold: row.gold,
          xp: row.xp,
          diamonds: row.diamonds,
          doubled: row.doubled,
          jokers: row.jokers,
        ),
    ],
  });
}

int _sqlInt(Object? raw) => raw is int ? raw : int.tryParse('$raw') ?? 0;

DateTime? _day(String? raw, {required bool end}) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty) return null;
  final dotted = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$').firstMatch(text);
  final parsed = dotted != null
      ? DateTime.utc(int.parse(dotted.group(3)!), int.parse(dotted.group(2)!), int.parse(dotted.group(1)!))
      : DateTime.tryParse(text.length == 10 ? '${text}T00:00:00Z' : text);
  if (parsed == null) return null;
  final day = parsed.toUtc();
  final dateOnly = dotted != null || text.length == 10;
  if (!end || !dateOnly) return day;
  return day.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
}

class PostgresBilgiLedger implements BilgiLedgerRepo {
  PostgresBilgiLedger(this.db);

  final Connection db;

  @override
  Future<bool> seen(String userId, String reason, String ref) async {
    if (ref.isEmpty) return false;
    final rows = await db.execute(
      Sql.named(
        'select 1 from bilgi_wallet_ledger where user_id = @userId and reason = @reason and ref = @ref limit 1',
      ),
      parameters: {'userId': userId, 'reason': reason, 'ref': ref},
    );
    return rows.isNotEmpty;
  }

  @override
  Future<void> append(List<BilgiLedgerLine> lines) async {
    for (final line in lines) {
      await db.execute(
        Sql.named('''
          insert into bilgi_wallet_ledger (
            id, user_id, created_at, asset, amount, balance_after, reason, ref, detail
          ) values (
            @id, @userId, @createdAt, @asset, @amount, @balanceAfter, @reason, @ref, @detail::jsonb
          )
          on conflict (user_id, reason, ref, asset) do nothing
        '''),
        parameters: {
          'id': line.id,
          'userId': line.userId,
          'createdAt': line.createdAt.toUtc(),
          'asset': line.asset,
          'amount': line.amount,
          'balanceAfter': line.balanceAfter,
          'reason': line.reason,
          'ref': line.ref,
          'detail': jsonEncode(line.detail),
        },
      );
    }
  }

  @override
  Future<List<BilgiLedgerLine>> list(
    String userId, {
    String asset = '',
    String reason = '',
    DateTime? from,
    DateTime? to,
  }) async {
    final clauses = <String>['user_id = @userId'];
    final parameters = <String, Object?>{'userId': userId};
    if (asset.isNotEmpty) {
      clauses.add('asset = @asset');
      parameters['asset'] = asset;
    }
    if (reason.isNotEmpty) {
      clauses.add('reason = @reason');
      parameters['reason'] = reason;
    }
    if (from != null) {
      clauses.add('created_at >= @from');
      parameters['from'] = from.toUtc();
    }
    if (to != null) {
      clauses.add('created_at <= @to');
      parameters['to'] = to.toUtc();
    }
    final rows = await db.execute(
      Sql.named('''
        select id, user_id, created_at, asset, amount, balance_after, reason, ref, detail::text
        from bilgi_wallet_ledger
        where ${clauses.join(' and ')}
        order by created_at desc
        limit 300
      '''),
      parameters: parameters,
    );
    return [
      for (final row in rows)
        BilgiLedgerLine(
          id: '${row[0]}',
          userId: '${row[1]}',
          createdAt: row[2] is DateTime ? (row[2] as DateTime).toUtc() : DateTime.tryParse('${row[2]}')?.toUtc() ?? DateTime.now().toUtc(),
          asset: '${row[3]}',
          amount: int.tryParse('${row[4]}') ?? 0,
          balanceAfter: int.tryParse('${row[5]}') ?? 0,
          reason: '${row[6]}',
          ref: '${row[7]}',
          detail: _detail(row[8]),
        ),
    ];
  }

  Future<List<({String userId, String ref, DateTime at, Map<String, Object?> detail, int gold, int xp, int diamonds, bool doubled, int jokers})>> games({
    DateTime? from,
    DateTime? to,
  }) async {
    final clauses = <String>['true'];
    final parameters = <String, Object?>{};
    if (from != null) {
      clauses.add('f.at >= @from');
      parameters['from'] = from.toUtc();
    }
    if (to != null) {
      clauses.add('f.at <= @to');
      parameters['to'] = to.toUtc();
    }
    final rows = await db.execute(
      Sql.named('''
        with finishes as (
          select
            user_id,
            ref,
            min(created_at) as at,
            (array_agg(detail order by case when coalesce(detail->>'modeId', '') <> '' then 0 else 1 end, created_at))[1] as detail,
            coalesce(sum(amount) filter (where asset = 'gold'), 0) as gold,
            coalesce(sum(amount) filter (where asset = 'xp'), 0) as xp,
            coalesce(sum(amount) filter (where asset = 'diamond'), 0) as diamonds
          from bilgi_wallet_ledger
          where reason = 'round_finish'
          group by user_id, ref
        )
        select
          f.user_id,
          f.ref,
          f.at,
          f.detail::text,
          f.gold,
          f.xp,
          f.diamonds,
          case when exists (
            select 1 from bilgi_wallet_ledger d
            where d.user_id = f.user_id and d.ref = f.ref and d.reason = 'score_double'
          ) then 1 else 0 end,
          (
            select count(*) from bilgi_wallet_ledger j
            where j.user_id = f.user_id and j.reason = 'joker_use' and j.ref like f.ref || '#%'
          )
        from finishes f
        where ${clauses.join(' and ')}
        order by f.at desc
        limit 1000
      '''),
      parameters: parameters,
    );
    return [
      for (final row in rows)
        (
          userId: '${row[0]}',
          ref: '${row[1]}',
          at: row[2] is DateTime ? (row[2] as DateTime).toUtc() : DateTime.tryParse('${row[2]}')?.toUtc() ?? DateTime.now().toUtc(),
          detail: _detail(row[3]),
          gold: _sqlInt(row[4]),
          xp: _sqlInt(row[5]),
          diamonds: _sqlInt(row[6]),
          doubled: _sqlInt(row[7]) == 1,
          jokers: _sqlInt(row[8]),
        ),
    ];
  }

  Map<String, Object?> _detail(Object? raw) {
    try {
      final decoded = jsonDecode('$raw');
      if (decoded is Map) return Map<String, Object?>.from(decoded);
    } catch (_) {}
    return const {};
  }
}
