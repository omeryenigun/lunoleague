import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/core/router/app_router.dart';
import 'package:kelimelig/injection.dart';
import 'package:kelimelig/league_injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await registerLeagueServer(syncRemote: true);
  runApp(const KelimeLigApp());
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
}
