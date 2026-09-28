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
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/data/local/key_value_store.dart';

final sl = GetIt.instance;

Future<void> configureDependencies({
  KeyValueStore? store,
  bool initHive = true,
}) async {
  if (sl.isRegistered<KeyValueStore>()) return;

  sl.registerSingleton<ApiSession>(ApiSession());
  if (initHive && store == null) {
    await Hive.initFlutter();
  }
  final root = store ?? await HiveKeyValueStore.open();

  sl.registerSingleton<KeyValueStore>(root);
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
