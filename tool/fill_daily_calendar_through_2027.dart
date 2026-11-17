// Fast fill of Luno League daily slot-1 gaps for all locales × leagues,
// 2026-01…2027-12. Loads word pools once; writes via batched SQL upserts.
//
//   $env:LOCAL_PG_PORT='15711'
//   railway connect Postgres --environment production --tunnel-only -P 15711
//   railway run --service api --environment production -- dart run tool/fill_daily_calendar_through_2027.dart
//
//   --report-only
//   --from=2026-01
//   --to=2027-12

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:postgres/postgres.dart';

const _box = 'luno_league__daily_games';
const _wordsBox = 'luno_league__words';

Future<void> main(List<String> args) async {
  final reportOnly = args.contains('--report-only');
  final from = _parseYm(_flag(args, 'from') ?? '2026-01');
  final to = _parseYm(_flag(args, 'to') ?? '2027-12');
  final databaseUrl = Platform.environment['DATABASE_URL'];
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('DATABASE_URL missing (use railway run --service api).');
    exit(1);
  }

  final db = await _open(databaseUrl);
  final rng = Random();
  try {
    final months = _months(from.$1, from.$2, to.$1, to.$2);
    stdout.writeln(
      'range ${from.$1}-${_pad(from.$2)} … ${to.$1}-${_pad(to.$2)} '
      '(${months.length} months) · locales=${GameLocale.all.length} · '
      'leagues=${LeagueTier.values.length} · reportOnly=$reportOnly',
    );

    stdout.writeln('loading word pools…');
    final pools = await _loadPools(db);
    for (final locale in GameLocale.all) {
      for (final league in LeagueTier.values) {
        final n = pools['${locale.id}|${league.wordLength}']?.length ?? 0;
        stdout.writeln('  pool ${locale.id} ${league.name} (${league.wordLength}) = $n');
      }
    }

    stdout.writeln('loading existing slot-1 keys…');
    final existing = await _existingSlot1(db, from, to);
    stdout.writeln('existing slot-1 rows in range: ${existing.length}');

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final pending = <_Row>[];
    final noWord = <String>[];

    for (final locale in GameLocale.all) {
      for (final league in LeagueTier.values) {
        final poolKey = '${locale.id}|${league.wordLength}';
        final pool = List<String>.from(pools[poolKey] ?? const []);
        if (pool.isEmpty) {
          noWord.add('${locale.id} ${league.name}');
          continue;
        }
        pool.shuffle(rng);

        for (final (y, m) in months) {
          final days = DateTime(y, m + 1, 0).day;
          final usedInMonth = <String>{};
          for (var day = 1; day <= days; day++) {
            final dateKey =
                '$y-${_pad(m)}-${_pad(day)}';
            final itemKey = '${dateKey}_${locale.id}_${league.name}';
            final id = existing[itemKey];
            if (id != null) usedInMonth.add(id);
          }

          var poolIndex = 0;
          for (var day = 1; day <= days; day++) {
            final dateKey = '$y-${_pad(m)}-${_pad(day)}';
            final itemKey = '${dateKey}_${locale.id}_${league.name}';
            if (existing.containsKey(itemKey)) continue;

            String? pick;
            for (var tries = 0; tries < pool.length; tries++) {
              final candidate = pool[(poolIndex + tries) % pool.length];
              if (!usedInMonth.contains(candidate)) {
                pick = candidate;
                poolIndex = (poolIndex + tries + 1) % pool.length;
                break;
              }
            }
            pick ??= pool[poolIndex % pool.length];
            poolIndex = (poolIndex + 1) % pool.length;
            usedInMonth.add(pick);

            final body = {
              'date': dateKey,
              'league': league.name,
              'language': locale.id,
              'wordId': pick,
              'index': 1,
              'isActive': true,
              'source': 'admin',
              'createdAt': nowIso,
            };
            pending.add(_Row(itemKey, body));
            if (locale.id == 'tr') {
              pending.add(_Row('${dateKey}_${league.name}', body));
            }
            existing[itemKey] = pick;
          }
        }
      }
    }

    stdout.writeln('to insert: ${pending.length} kv rows · noWord=${noWord.join(", ")}');
    if (reportOnly || pending.isEmpty) {
      stdout.writeln('done (no writes).');
      return;
    }

    const batchSize = 200;
    var written = 0;
    for (var i = 0; i < pending.length; i += batchSize) {
      final slice = pending.sublist(
        i,
        i + batchSize > pending.length ? pending.length : i + batchSize,
      );
      await _upsertBatch(db, slice);
      written += slice.length;
      if (written % 1000 < batchSize || written == pending.length) {
        stdout.writeln('wrote $written / ${pending.length}');
      }
    }

    // verify
    final after = await _existingSlot1(db, from, to);
    var remain = 0;
    for (final locale in GameLocale.all) {
      for (final league in LeagueTier.values) {
        final pool = pools['${locale.id}|${league.wordLength}'] ?? const [];
        if (pool.isEmpty) continue;
        for (final (y, m) in months) {
          final days = DateTime(y, m + 1, 0).day;
          for (var day = 1; day <= days; day++) {
            final dateKey = '$y-${_pad(m)}-${_pad(day)}';
            final itemKey = '${dateKey}_${locale.id}_${league.name}';
            if (!after.containsKey(itemKey)) remain++;
          }
        }
      }
    }
    stdout.writeln(
      'done written=${pending.length} remainingMissingDays=$remain '
      'noWordLocales=${noWord.isEmpty ? "none" : noWord.join("|")}',
    );
  } finally {
    await db.close();
  }
}

class _Row {
  _Row(this.key, this.body);
  final String key;
  final Map<String, dynamic> body;
}

Future<Map<String, List<String>>> _loadPools(Connection db) async {
  final rows = await db.execute('''
    select item_key,
           coalesce(body->>'language','tr') as lang,
           (body->>'length')::int as len
    from kv_entry
    where box = '$_wordsBox'
      and coalesce((body->>'isActive')::boolean, false) = true
      and body->>'status' = 'active'
  ''');
  final map = <String, List<String>>{};
  for (final r in rows) {
    final id = '${r[0]}';
    final lang = '${r[1]}';
    final len = r[2] is int ? r[2] as int : int.parse('${r[2]}');
    map.putIfAbsent('$lang|$len', () => []).add(id);
  }
  return map;
}

Future<Map<String, String>> _existingSlot1(
  Connection db,
  (int, int) from,
  (int, int) to,
) async {
  final fromDate = '${from.$1}-${_pad(from.$2)}-01';
  final toDate =
      '${to.$1}-${_pad(to.$2)}-${_pad(DateTime(to.$1, to.$2 + 1, 0).day)}';
  final rows = await db.execute(
    Sql.named('''
      select item_key, body->>'wordId'
      from kv_entry
      where box = @box
        and body->>'date' >= @fromDate
        and body->>'date' <= @toDate
        and coalesce((body->>'index')::int, 1) <= 1
        and body->>'language' is not null
        and item_key like '%\\_%\\_%' escape '\\'
        and item_key ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}_[a-z]{2}_(bronze|silver|gold)\$'
    '''),
    parameters: {
      'box': _box,
      'fromDate': fromDate,
      'toDate': toDate,
    },
  );
  final map = <String, String>{};
  for (final r in rows) {
    map['${r[0]}'] = '${r[1]}';
  }
  return map;
}

Future<void> _upsertBatch(Connection db, List<_Row> rows) async {
  if (rows.isEmpty) return;
  final values = <String>[];
  final params = <String, Object?>{};
  for (var i = 0; i < rows.length; i++) {
    values.add('(@box, @k$i, @b$i::jsonb)');
    params['k$i'] = rows[i].key;
    params['b$i'] = jsonEncode(rows[i].body);
  }
  params['box'] = _box;
  await db.execute(
    Sql.named('''
      insert into kv_entry (box, item_key, body)
      values ${values.join(',\n')}
      on conflict (box, item_key) do update set body = excluded.body
    '''),
    parameters: params,
  );
}

String? _flag(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

(int, int) _parseYm(String raw) {
  final parts = raw.split('-');
  if (parts.length != 2) {
    throw FormatException('expected YYYY-MM, got $raw');
  }
  return (int.parse(parts[0]), int.parse(parts[1]));
}

String _pad(int n) => n.toString().padLeft(2, '0');

List<(int, int)> _months(int y0, int m0, int y1, int m1) {
  final out = <(int, int)>[];
  var y = y0;
  var m = m0;
  while (y < y1 || (y == y1 && m <= m1)) {
    out.add((y, m));
    m++;
    if (m > 12) {
      m = 1;
      y++;
    }
  }
  return out;
}

Future<Connection> _open(String databaseUrl) async {
  final uri = Uri.parse(databaseUrl);
  final userInfo = uri.userInfo.split(':');
  final tunnelPort = int.tryParse(Platform.environment['LOCAL_PG_PORT'] ?? '');
  final host = tunnelPort != null ? '127.0.0.1' : uri.host;
  return Connection.open(
    Endpoint(
      host: host,
      port: tunnelPort ?? (uri.hasPort ? uri.port : 5432),
      database: uri.pathSegments.isEmpty ? 'railway' : uri.pathSegments.first,
      username: Uri.decodeComponent(userInfo.first),
      password: Uri.decodeComponent(userInfo.skip(1).join(':')),
    ),
    settings: ConnectionSettings(
      sslMode: host == '127.0.0.1' || host.contains('railway.internal')
          ? SslMode.disable
          : SslMode.require,
      connectTimeout: const Duration(seconds: 90),
      queryTimeout: const Duration(seconds: 600),
    ),
  );
}
