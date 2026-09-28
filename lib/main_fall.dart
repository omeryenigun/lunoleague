import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/games/luno_fall/fall_game_screen.dart';
import 'package:kelimelig/games/luno_fall/fall_home_screen.dart';
import 'package:kelimelig/games/luno_fall/fall_league_screen.dart';
import 'package:kelimelig/games/luno_fall/fall_profile_screen.dart';
import 'package:kelimelig/games/luno_fall/fall_rules.dart';
import 'package:kelimelig/games/luno_fall/fall_shell.dart';
import 'package:kelimelig/games/luno_fall/fall_shop_screen.dart';
import 'package:kelimelig/games/luno_fall/register_fall_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await registerFallServer();
  runApp(const LunoFallApp());
  if (!kIsWeb) {
    try {
      await MobileAds.instance.initialize();
    } catch (_) {}
  }
}

class LunoFallApp extends StatefulWidget {
  const LunoFallApp({super.key});

  @override
  State<LunoFallApp> createState() => _LunoFallAppState();
}

class _LunoFallAppState extends State<LunoFallApp> {
  late final GoRouter _router = GoRouter(
    initialLocation: '/fall',
    routes: [
      ShellRoute(
        builder: (_, _, child) => FallShell(child: child),
        routes: [
          GoRoute(path: '/fall', builder: (_, _) => const FallHomeScreen()),
          GoRoute(path: '/fall/league', builder: (_, _) => const FallLeagueScreen()),
          GoRoute(path: '/fall/shop', builder: (_, _) => const FallShopScreen()),
          GoRoute(path: '/fall/profile', builder: (_, _) => const FallProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/fall/play',
        builder: (_, state) {
          final name = state.uri.queryParameters['d'] ?? FallDifficulty.normal.name;
          final difficulty = FallDifficulty.values.byName(name);
          return FallGameScreen(difficulty: difficulty);
        },
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Luno Fall',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0E1A),
        colorScheme: const ColorScheme.dark(primary: Color(0xFF2ECC71)),
      ),
      routerConfig: _router,
    );
  }
}
