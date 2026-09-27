import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/appearance.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/core/services/device_link.dart';
import 'package:kelimelig/core/services/billing_gateway.dart';
import 'package:kelimelig/core/services/google_auth.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/haptic_manager.dart';
import 'package:kelimelig/core/services/motion_manager.dart';
import 'package:kelimelig/core/services/logger_service.dart';
import 'package:kelimelig/core/services/notification_service.dart';
import 'package:kelimelig/data/local/hive_store.dart';
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/data/remote/league_remote_sync.dart';
import 'package:kelimelig/data/remote/remote_game_server.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/games/luno_grid/luno_grid_server.dart';

final sl = GetIt.instance;

Future<void> configureDependencies({
  KeyValueStore? store,
  bool initHive = true,
  bool syncRemote = false,
}) async {
  if (sl.isRegistered<GameServer>()) return;

  final session = ApiSession();
  sl.registerSingleton<ApiSession>(session);
  final remote = store == null && initHive;
  if (initHive && store == null) {
    await Hive.initFlutter();
  }
  final root = store ?? await HiveKeyValueStore.open();
  if (root is HiveKeyValueStore) {
    await root.adoptLegacyBoxes(GameIds.lunoLeague);
  }
  final fall = LunoFallServer(ScopedKeyValueStore(root, GameIds.lunoFall));
  await fall.initialize();
  final grid = LunoGridServer(
    ScopedKeyValueStore(root, GameIds.lunoGrid),
    words: () => gridDictionary(ScopedKeyValueStore(root, GameIds.lunoLeague)),
  );

  final GameServer server;
  if (remote) {
    await restorePlayerToken(session);
    server = RemoteGameServer(ApiConfig.baseUrl, session);
  } else {
    final kv = ScopedKeyValueStore(root, GameIds.lunoLeague);
    final local = LocalGameServer(kv);
    await local.initialize();
    if (syncRemote) {
      await syncLunoLeagueContent(kv);
    }
    server = local;
  }

  sl.registerSingleton<KeyValueStore>(root);
  sl.registerSingleton<GameServer>(server);
  sl.registerSingleton<LunoFallServer>(fall);
  sl.registerSingleton<LunoGridServer>(grid);
  sl.registerSingleton<DeviceLink>(DeviceLink());
  sl.registerSingleton<L10n>(L10n());
  sl.registerSingleton<Appearance>(Appearance());
  sl.registerSingleton<LoggerService>(LoggerService());
  sl.registerSingleton<AnalyticsService>(AnalyticsService(sl()));
  sl.registerSingleton<AudioManager>(AudioManager());
  sl.registerSingleton<HapticManager>(HapticManager());
  sl.registerSingleton<MotionManager>(MotionManager());
  sl.registerSingleton<AdService>(AdService());
  sl.registerSingleton<GoogleAuth>(GoogleAuth());
  sl.registerSingleton<BillingGateway>(
    store == null && initHive
        ? PlayBillingGateway()
        : const UnavailableBillingGateway(),
  );
  sl.registerSingleton<NotificationService>(NotificationService());
  await sl<NotificationService>().init();
}

Future<void> resetDependencies() async {
  await sl.reset();
}
