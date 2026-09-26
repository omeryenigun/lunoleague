import 'dart:convert';
import 'dart:io';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';

import 'admin_auth.dart';

const _gameId = 'luno_league';

Future<void> main() async {
  final databaseUrl = Platform.environment['DATABASE_URL'];
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('DATABASE_URL is required');
    exit(1);
  }
  final db = await _open(databaseUrl);
  await _migrate(db);
  await migrateAdmin(db);
  await _seed(db);

  final router = Router()
    ..get('/health', (_) => Response.ok(jsonEncode({'ok': true})))
    ..get('/v1/games/$_gameId/bootstrap', (_) async {
      final body = await _bootstrap(db);
      return Response.ok(
        jsonEncode(body),
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
  mountAdmin(router, db);

  final handler = const Pipeline().addMiddleware(_cors).addHandler(router.call);
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('luno api listening on ${server.port}');
}

Middleware get _cors => (inner) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await inner(request);
        return response.change(headers: _corsHeaders);
      };
    };

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'content-type, authorization',
  'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
};

Future<Connection> _open(String databaseUrl) async {
  final uri = Uri.parse(databaseUrl);
  final userInfo = uri.userInfo.split(':');
  final username = Uri.decodeComponent(userInfo.first);
  final password = Uri.decodeComponent(userInfo.skip(1).join(':'));
  final internal = uri.host.contains('railway.internal');
  return Connection.open(
    Endpoint(
      host: uri.host,
      port: uri.hasPort ? uri.port : 5432,
      database: uri.pathSegments.isEmpty ? 'railway' : uri.pathSegments.first,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(
      sslMode: internal ? SslMode.disable : SslMode.require,
    ),
  );
}

Future<void> _migrate(Connection db) async {
  await db.execute('''
    create table if not exists game_content (
      game_id text not null,
      doc text not null,
      body jsonb not null,
      updated_at timestamptz not null default now(),
      primary key (game_id, doc)
    )
  ''');
}

Future<void> _seed(Connection db) async {
  await _insertIfMissing(db, 'config', _defaultConfig);
  await _insertIfMissing(db, 'shop', _defaultShop);
}

Future<void> _insertIfMissing(
  Connection db,
  String doc,
  Object body,
) async {
  await db.execute(
    Sql.named('''
      insert into game_content (game_id, doc, body)
      values (@gameId, @doc, @body::jsonb)
      on conflict (game_id, doc) do nothing
    '''),
    parameters: {
      'gameId': _gameId,
      'doc': doc,
      'body': jsonEncode(body),
    },
  );
}

Future<Map<String, dynamic>> _bootstrap(Connection db) async {
  final rows = await db.execute(
    Sql.named(
      'select doc, body from game_content where game_id = @gameId',
    ),
    parameters: {'gameId': _gameId},
  );
  final docs = <String, dynamic>{};
  for (final row in rows) {
    final doc = row[0] as String;
    final body = row[1];
    docs[doc] = body is String ? jsonDecode(body) : body;
  }
  return {
    'gameId': _gameId,
    'config': docs['config'],
    'shop': docs['shop'] ?? const [],
    'words': docs['words'] ?? const [],
    'daily': docs['daily'] ?? const [],
  };
}

const _defaultConfig = {
  'levelXpThresholds': [0, 500, 1200, 2000, 3000, 4500, 6500, 9000, 12000, 16000],
  'dailyWinXp': 100,
  'dailyWinXpWithHint': 70,
  'perfectBonusXp': 50,
  'noHintBonusXp': 30,
  'endlessXp': 5,
  'endlessCoins': 3,
  'dailyWinCoins': 25,
  'dailyLoseCoins': 5,
  'hint1Cost': 10,
  'hint2Cost': 15,
  'adCoinReward': 15,
  'streakBonusXp': {'5': 100, '7': 250, '14': 500, '30': 1500},
  'dailyRewardCycle': [
    {'day': 1, 'coins': 10, 'hintLevel1': 0, 'hintLevel2': 0, 'shield': 0},
    {'day': 2, 'coins': 10, 'hintLevel1': 0, 'hintLevel2': 0, 'shield': 0},
    {'day': 3, 'coins': 0, 'hintLevel1': 1, 'hintLevel2': 0, 'shield': 0},
    {'day': 4, 'coins': 15, 'hintLevel1': 0, 'hintLevel2': 0, 'shield': 0},
    {'day': 5, 'coins': 20, 'hintLevel1': 0, 'hintLevel2': 0, 'shield': 0},
    {'day': 6, 'coins': 0, 'hintLevel1': 0, 'hintLevel2': 1, 'shield': 0},
    {'day': 7, 'coins': 25, 'hintLevel1': 0, 'hintLevel2': 0, 'shield': 1},
  ],
};

const _defaultShop = [
  {
    'id': 'coins_100',
    'coins': 100,
    'shields': 0,
    'priceTry': '₺19,99',
    'priceUsd': '\$0.99',
    'badge': null,
    'popular': false,
    'sortOrder': 10,
    'active': true,
  },
  {
    'id': 'coins_550',
    'coins': 550,
    'shields': 0,
    'priceTry': '₺69,99',
    'priceUsd': '\$2.99',
    'badge': 'populer',
    'popular': true,
    'sortOrder': 20,
    'active': true,
  },
  {
    'id': 'coins_1400',
    'coins': 1400,
    'shields': 0,
    'priceTry': '₺149,99',
    'priceUsd': '\$5.99',
    'badge': 'avantaj',
    'popular': false,
    'sortOrder': 30,
    'active': true,
  },
  {
    'id': 'coins_4000',
    'coins': 4000,
    'shields': 0,
    'priceTry': '₺349,99',
    'priceUsd': '\$14.99',
    'badge': 'en_iyi',
    'popular': false,
    'sortOrder': 40,
    'active': true,
  },
  {
    'id': 'streak_shield_1',
    'coins': 0,
    'shields': 1,
    'priceTry': '₺29,99',
    'priceUsd': '\$1.49',
    'badge': 'kalkan',
    'popular': false,
    'sortOrder': 50,
    'active': true,
  },
];
