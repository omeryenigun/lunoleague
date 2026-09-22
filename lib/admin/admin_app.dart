import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/admin/screens/config_screen.dart';
import 'package:kelimelig/admin/screens/daily_screen.dart';
import 'package:kelimelig/admin/screens/games_screen.dart';
import 'package:kelimelig/admin/screens/league_screen.dart';
import 'package:kelimelig/admin/screens/overview_screen.dart';
import 'package:kelimelig/admin/screens/users_screen.dart';
import 'package:kelimelig/admin/screens/words_screen.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/theme/app_theme.dart';
import 'package:kelimelig/core/theme/colors.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '${AppConstants.appName} Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AdminGate(),
    );
  }
}

class AdminGate extends StatefulWidget {
  const AdminGate({super.key});

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _pass = TextEditingController();
  var _ok = false;
  var _error = false;

  @override
  void dispose() {
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ok) return const AdminShell();
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${AppConstants.appName} Admin',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Şifre',
                  errorText: _error ? 'Hatalı şifre' : null,
                ),
                onSubmitted: (_) => _try(),
              ),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _try, child: const Text('Giriş')),
            ],
          ),
        ),
      ),
    );
  }

  void _try() {
    final ok = _pass.text == AppConstants.adminPassword;
    setState(() {
      _ok = ok;
      _error = !ok;
    });
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  var _index = 0;
  var _locale = GameLocale.tr.id;
  var _league = LeagueTier.bronze;

  static const _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: Text('Özet'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: Text('Kullanıcılar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.sports_esports_outlined),
      selectedIcon: Icon(Icons.sports_esports),
      label: Text('Oyunlar'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: Text('Kelimeler'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.today_outlined),
      selectedIcon: Icon(Icons.today),
      label: Text('Daily'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.emoji_events_outlined),
      selectedIcon: Icon(Icons.emoji_events),
      label: Text('Lig'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.tune_outlined),
      selectedIcon: Icon(Icons.tune),
      label: Text('Ayarlar'),
    ),
  ];

  static const _barDestinations = [
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Özet'),
    NavigationDestination(icon: Icon(Icons.people_outline), label: 'Kullanıcılar'),
    NavigationDestination(
      icon: Icon(Icons.sports_esports_outlined),
      label: 'Oyunlar',
    ),
    NavigationDestination(icon: Icon(Icons.menu_book_outlined), label: 'Kelimeler'),
    NavigationDestination(icon: Icon(Icons.today_outlined), label: 'Daily'),
    NavigationDestination(icon: Icon(Icons.emoji_events_outlined), label: 'Lig'),
    NavigationDestination(icon: Icon(Icons.tune_outlined), label: 'Ayarlar'),
  ];

  Widget get _page => switch (_index) {
        0 => const OverviewScreen(),
        1 => const UsersScreen(),
        2 => const GamesScreen(),
        3 => const WordsScreen(),
        4 => const DailyScreen(),
        5 => const LeagueScreen(),
        _ => const ConfigScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return AdminLocaleScope(
      locale: _locale,
      league: _league,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Yönetim paneli'),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: SegmentedButton<LeagueTier>(
                segments: [
                  for (final tier in LeagueTier.values)
                    ButtonSegment(
                      value: tier,
                      label: Text(tier.label),
                      tooltip: '${tier.label} (${tier.wordLength} harf)',
                    ),
                ],
                selected: {_league},
                onSelectionChanged: (next) {
                  setState(() => _league = next.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SegmentedButton<String>(
                segments: [
                  for (final loc in GameLocale.all)
                    ButtonSegment(
                      value: loc.id,
                      label: Text(loc.id.toUpperCase()),
                    ),
                ],
                selected: {_locale},
                onSelectionChanged: (next) {
                  setState(() => _locale = next.first);
                },
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
        drawer: wide
            ? null
            : Drawer(
                child: ListView(
                  children: [
                    DrawerHeader(
                      child: Text(
                        '${AppConstants.appName} Admin',
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    for (var i = 0; i < _barDestinations.length; i++)
                      ListTile(
                        leading: _barDestinations[i].icon,
                        title: Text(_barDestinations[i].label),
                        selected: _index == i,
                        onTap: () {
                          setState(() => _index = i);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.surface,
                destinations: _destinations,
              ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('$_locale-${_league.name}'),
                child: _page,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
