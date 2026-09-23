import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/game_dispatch.dart';
import 'package:kelimelig/api/play_receipt.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/remote/session_kv.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';

Future<Response> handleGame(
  Request request,
  Connection db,
  KeyValueStore scoped,
) async {
  final body = await readJson(request);
  final op = body['op'];
  if (op is! String || op.isEmpty) return jsonResponse({'error': 'İşlem yok.'}, status: 400);
  final rawArgs = body['args'];
  final args = rawArgs is Map ? Map<String, dynamic>.from(rawArgs) : <String, dynamic>{};
  final clock = _playerClock(args);
  if (adminOps.contains(op)) {
    if (await adminIdOf(db, request) == null) {
      return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
    }
    return _run(_strict(SessionKv(scoped), clock: clock), op, args, token: null);
  }
  final opened = await _openPlayer(db, request);
  if (opened == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final overlay = SessionKv(scoped, userId: opened.userId, locale: opened.locale);
  final response = await _run(_strict(overlay, clock: clock), op, args, token: opened.token);
  await db.execute(
    Sql.named('''
      update player_sessions
      set user_id = @userId, locale = @locale
      where token_hash = @hash
    '''),
    parameters: {
      'userId': overlay.userId,
      'locale': overlay.locale,
      'hash': opened.hash,
    },
  );
  return response;
}

LocalGameServer _strict(KeyValueStore store, {DateTime Function()? clock}) {
  return LocalGameServer(
    store,
    clock: clock,
    confirmPurchase: confirmPlayPurchase,
    grantUnverifiedAds: false,
  );
}

/// Phone sends its UTC offset so the daily day rolls at local midnight.
DateTime Function() _playerClock(Map<String, dynamic> args) {
  final raw = args.remove('tzOffsetMinutes');
  final minutes = switch (raw) {
    int value => value,
    String value => int.tryParse(value),
    _ => null,
  };
  if (minutes == null || minutes.abs() > 14 * 60) return DateTime.now;
  return () => DateTime.now().toUtc().add(Duration(minutes: minutes));
}

Future<Map<String, dynamic>> liveBootstrap(KeyValueStore scoped) async {
  final game = LocalGameServer(scoped);
  final config = await game.getConfig();
  final shop = await game.adminListShopProducts();
  final daily = await scoped.values('daily_games');
  return {
    'gameId': 'luno_league',
    'config': config.toMap(),
    'shop': shop.map((item) => item.toMap()).toList(),
    'daily': daily,
  };
}

class _Open {
  const _Open(this.token, this.hash, this.userId, this.locale);
  final String token;
  final String hash;
  final String? userId;
  final String? locale;
}

Future<_Open?> _openPlayer(Connection db, Request request) async {
  final token = bearerToken(request);
  if (token != null) {
    final hash = tokenHash(token);
    final rows = await db.execute(
      Sql.named('''
        select user_id, locale from player_sessions
        where token_hash = @hash and expires_at > now()
      '''),
      parameters: {'hash': hash},
    );
    if (rows.isEmpty) return null;
    return _Open(token, hash, rows.first[0] as String?, rows.first[1] as String?);
  }
  final created = newToken();
  final hash = tokenHash(created);
  await db.execute(
    Sql.named('''
      insert into player_sessions (token_hash, user_id, locale, expires_at)
      values (@hash, null, null, now() + interval '14 days')
    '''),
    parameters: {'hash': hash},
  );
  return _Open(created, hash, null, null);
}

Future<Response> _run(
  LocalGameServer game,
  String op,
  Map<String, dynamic> args, {
  required String? token,
}) async {
  try {
    final data = await dispatchGame(game, op, args);
    return jsonResponse({
      'token': ?token,
      'data': data,
    });
  } on AppFailure catch (e) {
    return jsonResponse(
      {'error': e.message, 'code': ?e.code, 'token': ?token},
      status: 400,
    );
  } on FormatException catch (e) {
    return jsonResponse({'error': e.message}, status: 400);
  } on ArgumentError catch (e) {
    return jsonResponse({'error': '${e.message}'}, status: 400);
  }
}
