import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/appearance.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/haptic_manager.dart';
import 'package:kelimelig/core/services/logger_service.dart';
import 'package:kelimelig/core/services/notification_service.dart';
import 'package:kelimelig/data/local/hive_store.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/domain/game/game_server.dart';

final sl = GetIt.instance;

Future<void> configureDependencies({
  KeyValueStore? store,
  bool initHive = true,
}) async {
  if (sl.isRegistered<GameServer>()) return;

  if (initHive && store == null) {
    await Hive.initFlutter();
  }
  final kv = store ?? await HiveKeyValueStore.open();
  final server = LocalGameServer(kv);
  await server.initialize();

  sl.registerSingleton<GameServer>(server);
  sl.registerSingleton<L10n>(L10n());
  sl.registerSingleton<Appearance>(Appearance());
  sl.registerSingleton<LoggerService>(LoggerService());
  sl.registerSingleton<AnalyticsService>(AnalyticsService(sl()));
  sl.registerSingleton<AudioManager>(AudioManager());
  sl.registerSingleton<HapticManager>(HapticManager());
  sl.registerSingleton<AdService>(AdService());
  sl.registerSingleton<NotificationService>(NotificationService());
  await sl<NotificationService>().init();
}

Future<void> resetDependencies() async {
  await sl.reset();
}
