import 'dart:io';

import 'package:kelimelig/api/admob_ssv.dart';
import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/game_http.dart';
import 'package:kelimelig/api/privacy_page.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/data/remote/postgres_kv.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';

Future<void> main() async {
  final databaseUrl = Platform.environment['DATABASE_URL'];
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('DATABASE_URL is required');
    exit(1);
  }
  final db = await _open(databaseUrl);
  await PostgresKv.migrate(db);
  await migrateAdmin(db);
  final scoped = ScopedKeyValueStore(PostgresKv(db), GameIds.lunoLeague);
  final rules = LocalGameServer(scoped);
  await rules.initialize();

  final router = Router()
    ..get('/health', (_) => jsonResponse({'ok': true}))
    ..get(
      '/v1/version',
      (_) => jsonResponse({
        'version': GameVersion.parse(gameVersionCode).label,
      }),
    )
    ..get('/v1/games/${GameIds.lunoLeague}/bootstrap', (_) async {
      return jsonResponse(await liveBootstrap(scoped));
    })
    ..post('/v1/game', (request) => handleGame(request, db, scoped))
    ..get('/v1/admob/reward', (request) => handleAdmobReward(request, rules))
    ..get('/privacy', privacyPolicyPage)
    ..get('/privacy/', privacyPolicyPage);
  mountAdminApi(router, db);
  _mountAdminWeb(router);

  final handler = const Pipeline().addMiddleware(_cors).addHandler(router.call);
  final port = int.parse(Platform.environment['PORT'] ?? '8080');
  final server = await serve(handler, InternetAddress.anyIPv4, port);
  stdout.writeln('luno api listening on ${server.port}');
}

void _mountAdminWeb(Router router) {
  final root = Platform.environment['ADMIN_WEB_ROOT'] ?? '/admin_web';
  if (!Directory(root).existsSync()) {
    router
      ..get('/admin', (_) => Response.notFound('Admin web build is missing'))
      ..get('/admin/', (_) => Response.notFound('Admin web build is missing'));
    return;
  }
  final files = createStaticHandler(root, defaultDocument: 'index.html');
  router
    ..get('/admin', (_) => Response.found('/admin/'))
    ..mount('/admin/', (Request request) async {
      final response = await files(request);
      final type = response.headers['content-type'] ?? '';
      if (type.contains('text/html')) {
        return response.change(headers: {'cache-control': 'no-store'});
      }
      return response;
    });
}

Middleware get _cors => (Handler inner) {
      return (Request request) async {
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
