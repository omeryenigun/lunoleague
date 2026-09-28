import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/games/luno_grid/grid_home_screen.dart';
import 'package:kelimelig/games/luno_grid/register_grid_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await registerGridServer();
  runApp(const LunoGridApp());
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
}

class LunoGridApp extends StatelessWidget {
  const LunoGridApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Luno Grid',
      debugShowCheckedModeBanner: false,
      home: GridHomeScreen(),
    );
  }
}
