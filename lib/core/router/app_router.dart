import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/app_theme.dart';
import 'package:kelimelig/core/theme/appearance.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/language_screen.dart';
import 'package:kelimelig/features/auth/presentation/login_screen.dart';
import 'package:kelimelig/features/auth/presentation/register_screen.dart';
import 'package:kelimelig/features/auth/presentation/onboarding_screen.dart';
import 'package:kelimelig/features/auth/presentation/splash_screen.dart';
import 'package:kelimelig/features/game/presentation/game_screen.dart';
import 'package:kelimelig/features/match/presentation/duel_screen.dart';
import 'package:kelimelig/features/match/presentation/room_screen.dart';
import 'package:kelimelig/features/home/presentation/home_screen.dart';
import 'package:kelimelig/features/league/presentation/league_screen.dart';
import 'package:kelimelig/features/profile/presentation/achievements_screen.dart';
import 'package:kelimelig/features/profile/presentation/profile_screen.dart';
import 'package:kelimelig/features/profile/presentation/statistics_screen.dart';
import 'package:kelimelig/features/settings/presentation/settings_screen.dart';
import 'package:kelimelig/features/shell/main_shell.dart';
import 'package:kelimelig/features/shop/presentation/shop_screen.dart';
import 'package:kelimelig/features/word_book/presentation/word_book_screen.dart';
import 'package:kelimelig/injection.dart';

class KelimeLigApp extends StatelessWidget {
  const KelimeLigApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(sl())..bootstrap(),
      child: const _AppView(),
    );
  }
}

class _AppView extends StatefulWidget {
  const _AppView();

  @override
  State<_AppView> createState() => _AppViewState();
}

class _AppViewState extends State<_AppView> {
  late final GoRouter _router = _createRouter();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([sl<Appearance>(), sl<L10n>()]),
      builder: (context, _) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark(season: sl<Appearance>().seasonTheme),
          routerConfig: _router,
        );
      },
    );
  }

  GoRouter _createRouter() {
    return GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
        GoRoute(
          path: '/language',
          builder: (_, state) => LanguageScreen(
            fromSettings: state.uri.queryParameters['from'] == 'settings',
          ),
        ),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(path: '/hub', redirect: (_, _) => '/home'),
        GoRoute(path: '/fall', redirect: (_, _) => '/home'),
        GoRoute(path: '/fall/league', redirect: (_, _) => '/home'),
        GoRoute(path: '/fall/shop', redirect: (_, _) => '/home'),
        GoRoute(path: '/fall/profile', redirect: (_, _) => '/home'),
        GoRoute(path: '/fall/play', redirect: (_, _) => '/home'),
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
            GoRoute(path: '/league', builder: (_, _) => const LeagueScreen()),
            GoRoute(path: '/shop', builder: (_, _) => const ShopScreen()),
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
            GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
          ],
        ),
        GoRoute(path: '/duel', builder: (_, _) => const DuelScreen()),
        GoRoute(path: '/room', builder: (_, _) => const RoomScreen()),
        GoRoute(
          path: '/game/:mode',
          builder: (_, state) {
            final param = state.pathParameters['mode'];
            final mode = switch (param) {
              'endless' => GameType.endless,
              'duel' => GameType.duel,
              'room' => GameType.room,
              _ => GameType.daily,
            };
            return GameScreen(type: mode);
          },
        ),
        GoRoute(path: '/statistics', builder: (_, _) => const StatisticsScreen()),
        GoRoute(path: '/achievements', builder: (_, _) => const AchievementsScreen()),
        GoRoute(path: '/word-book', builder: (_, _) => const WordBookScreen()),
      ],
    );
  }
}
