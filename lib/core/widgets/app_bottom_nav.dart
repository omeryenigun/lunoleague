import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/injection.dart';

/// Shared Clash-style bottom nav used by [MainShell] and full-screen pages
/// like the daily game board so menus stay consistent.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, this.selectedIndex});

  /// Active tab index (0–4). Pass `null` when the current route is not a tab
  /// (e.g. `/game/daily`) so no pill is highlighted.
  final int? selectedIndex;

  static const tabs = ['/home', '/league', '/shop', '/profile', '/settings'];

  static int? indexForPath(String location) {
    if (location.startsWith('/league')) return 1;
    if (location.startsWith('/shop')) return 2;
    if (location.startsWith('/profile')) return 3;
    if (location.startsWith('/settings')) return 4;
    if (location.startsWith('/home')) return 0;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sl<L10n>(),
      builder: (context, _) {
        final l10n = sl<L10n>();
        final selected = selectedIndex;
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Color(0xF20B1120),
            border: Border(
              top: BorderSide(color: Color(0x1A64748B)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 8),
              child: Row(
                children: [
                  _NavItem(
                    selected: selected == 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: l10n.t('home'),
                    onTap: () => context.go(tabs[0]),
                  ),
                  _NavItem(
                    selected: selected == 1,
                    icon: Icons.emoji_events_outlined,
                    activeIcon: Icons.emoji_events,
                    label: l10n.t('league'),
                    onTap: () => context.go(tabs[1]),
                  ),
                  _NavItem(
                    selected: selected == 2,
                    icon: Icons.storefront_outlined,
                    activeIcon: Icons.storefront,
                    label: l10n.t('shop'),
                    onTap: () => context.go(tabs[2]),
                  ),
                  _NavItem(
                    selected: selected == 3,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: l10n.t('profile'),
                    onTap: () => context.go(tabs[3]),
                  ),
                  _NavItem(
                    selected: selected == 4,
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings,
                    label: l10n.t('settings'),
                    onTap: () => context.go(tabs[4]),
                  ),
                ],
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
    const active = AppColors.cosmicGreen;
    const inactive = Color(0xFF6B728A);
    final color = selected ? active : inactive;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: selected ? active.withValues(alpha: 0.14) : null,
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: active.withValues(alpha: 0.28),
                        blurRadius: 14,
                        spreadRadius: 0.5,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 20,
                  color: color,
                  shadows: selected
                      ? const [Shadow(color: Color(0xCC2ECC71), blurRadius: 12)]
                      : null,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
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
