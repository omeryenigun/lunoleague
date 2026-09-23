import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/injection.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});

  final Widget child;

  static const _tabs = ['/home', '/league', '/shop', '/profile', '/settings'];

  int _index(String location) {
    if (location.startsWith('/league')) return 1;
    if (location.startsWith('/shop')) return 2;
    if (location.startsWith('/profile')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<L10n>(),
      builder: (context, _) {
        final location = GoRouterState.of(context).uri.path;
        final selected = _index(location);
        final l10n = sl<L10n>();
        return Scaffold(
          backgroundColor: AppColors.cosmicBg,
          body: child,
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              color: Color(0xE60A0E1A),
              border: Border(
                top: BorderSide(color: Color(0x1A94A3B8)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                child: Row(
                  children: [
                    _NavItem(
                      selected: selected == 0,
                      icon: Icons.home_outlined,
                      activeIcon: Icons.home_rounded,
                      label: l10n.t('home'),
                      onTap: () => context.go(_tabs[0]),
                    ),
                    _NavItem(
                      selected: selected == 1,
                      icon: Icons.emoji_events_outlined,
                      activeIcon: Icons.emoji_events,
                      label: l10n.t('league'),
                      onTap: () => context.go(_tabs[1]),
                    ),
                    _NavItem(
                      selected: selected == 2,
                      icon: Icons.storefront_outlined,
                      activeIcon: Icons.storefront,
                      label: l10n.t('shop'),
                      onTap: () => context.go(_tabs[2]),
                    ),
                    _NavItem(
                      selected: selected == 3,
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: l10n.t('profile'),
                      onTap: () => context.go(_tabs[3]),
                    ),
                    _NavItem(
                      selected: selected == 4,
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings,
                      label: l10n.t('settings'),
                      onTap: () => context.go(_tabs[4]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.selected,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.cosmicGreen : const Color(0xFF64748B);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        AppColors.cosmicGreen.withValues(alpha: 0.15),
                        AppColors.cosmicTeal.withValues(alpha: 0.1),
                      ],
                    )
                  : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AppColors.cosmicGreen.withValues(alpha: 0.18),
                        blurRadius: 16,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 22,
                  color: color,
                  shadows: selected
                      ? const [Shadow(color: Color(0xCC2ECC71), blurRadius: 10)]
                      : null,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
