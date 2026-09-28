import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_screen.dart';
import 'package:kelimelig/games/luno_bilgi/register_bilgi_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await registerBilgiServer();
  runApp(const LunoBilgiApp());
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
}

class LunoBilgiApp extends StatelessWidget {
  const LunoBilgiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Luno Bilgi',
      debugShowCheckedModeBanner: false,
      home: BilgiScreen(),
    );
  }
}
