import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/api/admob_ssv.dart';
import 'package:kelimelig/api/app_ads_txt.dart';
import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/coming_soon_page.dart';
import 'package:kelimelig/api/site_cards.dart';
import 'package:kelimelig/api/game_http.dart';
import 'package:kelimelig/api/bilgi_questions_http.dart';
import 'package:kelimelig/api/bilgi_catalog_http.dart';
import 'package:kelimelig/api/bilgi_translate_http.dart';
import 'package:kelimelig/api/bilgi_review_http.dart';
import 'package:kelimelig/api/bilgi_rooms_http.dart';
import 'package:kelimelig/api/bilgi_reports_http.dart';
import 'package:kelimelig/api/bilgi_league_http.dart';
import 'package:kelimelig/api/bilgi_users_http.dart';
import 'package:kelimelig/api/bilgi_wallet_http.dart';
import 'package:kelimelig/api/bilgi_contest_http.dart';
import 'package:kelimelig/api/bilgi_league_run_http.dart';
import 'package:kelimelig/api/mail_http.dart';
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
  await migrateMail(db);
  await migrateBilgiReports(db);
  await migrateBilgiQuestions(db);
  await migrateBilgiCatalog(db);
  await migrateBilgiRooms(db);
  await migrateAdmin(db);
  await migrateBilgiWallet(db);
  await migrateSiteCards(db);
  await seedSiteCards(db);
  await seedSiteCardCopy(db);
  await seedSiteCardSlogans(db);
  await seedSiteCardShots(db);
  await seedSiteCardGrid(db);
  await seedSiteCardBilgi(db);
  await classifySiteCardMedia(db);
  final scoped = ScopedKeyValueStore(PostgresKv(db), GameIds.lunoLeague);
  final rules = LocalGameServer(scoped);
  await rules.initialize();
  await rules.importStarterEnglishWords();
  final common = await rules.importCommonEnglishWords();
  stdout.writeln(
    'en common words imported=${common.imported} skipped=${common.skipped} invalid=${common.invalid}',
  );
  final more = await rules.importMoreEnglishWords();
  stdout.writeln(
    'en more words imported=${more.imported} skipped=${more.skipped} invalid=${more.invalid}',
  );
  final extra = await rules.importExtraEnglishWords();
  stdout.writeln(
    'en extra words imported=${extra.imported} skipped=${extra.skipped} invalid=${extra.invalid}',
  );
  final next = await rules.importNextEnglishWords();
  stdout.writeln(
    'en next words imported=${next.imported} skipped=${next.skipped} invalid=${next.invalid}',
  );
  final batch = await rules.importBatchEnglishWords();
  stdout.writeln(
    'en batch words imported=${batch.imported} skipped=${batch.skipped} invalid=${batch.invalid}',
  );
  final plus = await rules.importPlusEnglishWords();
  stdout.writeln(
    'en plus words imported=${plus.imported} skipped=${plus.skipped} invalid=${plus.invalid}',
  );
  final wave = await rules.importWaveEnglishWords();
  stdout.writeln(
    'en wave words imported=${wave.imported} skipped=${wave.skipped} invalid=${wave.invalid}',
  );
  final flow = await rules.importFlowEnglishWords();
  stdout.writeln(
    'en flow words imported=${flow.imported} skipped=${flow.skipped} invalid=${flow.invalid}',
  );
  final german = await rules.importGermanFrequencyWords();
  stdout.writeln(
    'de frequency words imported=${german.imported} skipped=${german.skipped} invalid=${german.invalid}',
  );
  final germanGlosses = await rules.fillGermanDefinitions();
  stdout.writeln(
    'de definitions updated=${germanGlosses.updated} missing=${germanGlosses.missing}',
  );
  final droppedGerman = await rules.dropUndefinedGermanWords();
  stdout.writeln('de undefined words removed=$droppedGerman');
  final spanish = await rules.importSpanishFrequencyWords();
  stdout.writeln(
    'es frequency words imported=${spanish.imported} skipped=${spanish.skipped} invalid=${spanish.invalid}',
  );
  final french = await rules.importFrenchFrequencyWords();
  stdout.writeln(
    'fr frequency words imported=${french.imported} skipped=${french.skipped} invalid=${french.invalid}',
  );
  final italian = await rules.importItalianFrequencyWords();
  stdout.writeln(
    'it frequency words imported=${italian.imported} skipped=${italian.skipped} invalid=${italian.invalid}',
  );
  final portuguese = await rules.importPortugueseFrequencyWords();
  stdout.writeln(
    'pt frequency words imported=${portuguese.imported} skipped=${portuguese.skipped} invalid=${portuguese.invalid}',
  );
  final russian = await rules.importRussianFrequencyWords();
  stdout.writeln(
    'ru frequency words imported=${russian.imported} skipped=${russian.skipped} invalid=${russian.invalid}',
  );
  final polish = await rules.importPolishFrequencyWords();
  stdout.writeln(
    'pl frequency words imported=${polish.imported} skipped=${polish.skipped} invalid=${polish.invalid}',
  );
  final english = await rules.importEnglishFrequencyWords();
  stdout.writeln(
    'en frequency words imported=${english.imported} skipped=${english.skipped} invalid=${english.invalid}',
  );
  final dutch = await rules.importDutchFrequencyWords();
  stdout.writeln(
    'nl frequency words imported=${dutch.imported} skipped=${dutch.skipped} invalid=${dutch.invalid}',
  );
  final droppedProfanity = await rules.dropListedProfanity();
  stdout.writeln('profanity words removed=$droppedProfanity');
  final adCoins = await rules.raiseAdCoinReward();
  stdout.writeln('ad coin reward=$adCoins');
  final dropped = await rules.dropNoiseEnglishWords();
  stdout.writeln('en noise words removed=$dropped');

  final router = Router()
    ..get('/', comingSoonPage)
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
    ..get('/privacy/', privacyPolicyPage)
    ..get('/app-ads.txt', appAdsTxtPage);
  mountAdminApi(router, db);
  mountMailApi(router, db);
  mountBilgiReports(router, db);
  mountBilgiQuestions(router, db);
  mountBilgiCatalog(router, db);
  mountBilgiTranslate(router, db);
  mountBilgiReview(router, db);
  mountBilgiRooms(router, db);
  mountBilgiUsers(router, db);
  final bilgiStore = ScopedKeyValueStore(PostgresKv(db), GameIds.lunoBilgi);
  final bilgiLedger = PostgresBilgiLedger(db);
  mountBilgiWallet(router, db, bilgiStore);
  mountBilgiContest(router, db, bilgiStore);
  mountBilgiLeagueRun(router, bilgiStore);
  mountBilgiLeague(router, bilgiStore);
  watchBilgiLeague(bilgiStore, ledger: bilgiLedger);
  mountSiteCards(router, db);
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
      return response.change(headers: {'cache-control': 'no-store'});
    });
}

Middleware get _cors => (Handler inner) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        try {
          final response = await inner(request);
          return response.change(headers: _corsHeaders);
        } catch (error, stack) {
          stderr.writeln('api error: $error');
          stderr.writeln(stack);
          return Response.internalServerError(
            body: jsonEncode({'error': 'Sunucu hatası.'}),
            headers: {'content-type': 'application/json', ..._corsHeaders},
          );
        }
      };
    };

const _corsHeaders = {
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'content-type, authorization',
  'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
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
