import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/games/luno_fall/fall_copy.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

class FallShell extends StatelessWidget {
  const FallShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final locale = sl<LunoFallServer>();
    return FutureBuilder<String>(
      future: locale.locale(),
      builder: (context, snap) {
        final lang = snap.data ?? 'tr';
        int index = 0;
        if (path.startsWith('/fall/league')) index = 1;
        if (path.startsWith('/fall/shop')) index = 2;
        if (path.startsWith('/fall/profile')) index = 3;
        return Scaffold(
          backgroundColor: const Color(0xFF0A0E1A),
          body: child,
          bottomNavigationBar: NavigationBar(
            backgroundColor: const Color(0xE60A0E1A),
            indicatorColor: const Color(0x332ECC71),
            selectedIndex: index,
            onDestinationSelected: (i) {
              context.go(
                ['/fall', '/fall/league', '/fall/shop', '/fall/profile'][i],
              );
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.play_arrow_outlined),
                label: fallText(lang, 'play'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.emoji_events_outlined),
                label: fallText(lang, 'league'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.storefront_outlined),
                label: fallText(lang, 'shop'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline),
                label: fallText(lang, 'profile'),
              ),
            ],
          ),
        );
      },
    );
  }
}
