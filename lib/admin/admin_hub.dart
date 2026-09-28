import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/game_version.dart';

class AdminHubColors {
  static const bg = Color(0xFF0F0E1A);
  static const bar = Color(0xFF15132A);
  static const card = Color(0xFF1A1830);
  static const muted = Color(0xFFA09CB8);
  static const teal = Color(0xFF00D9C0);
  static const error = Color(0xFFFF4D6D);
  static const primary = Color(0xFF6C3CE9);
}

enum AdminHubNav { games, staff }

class AdminHubBar extends StatelessWidget {
  const AdminHubBar({
    super.key,
    required this.active,
    required this.onGames,
    required this.onStaff,
    required this.onSignOut,
  });

  final AdminHubNav active;
  final VoidCallback onGames;
  final VoidCallback onStaff;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AdminHubColors.bar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Row(
          children: [
            const _Wordmark(),
            const Spacer(),
            _NavLink(
              label: 'Oyun kartları',
              active: active == AdminHubNav.games,
              onTap: onGames,
            ),
            const SizedBox(width: 20),
            _NavLink(
              label: 'Yöneticiler',
              active: active == AdminHubNav.staff,
              onTap: onStaff,
            ),
            const SizedBox(width: 20),
            _NavLink(
              label: 'Çıkış',
              color: AdminHubColors.error,
              onTap: onSignOut,
            ),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF8B5CF6), AdminHubColors.teal],
          ).createShader(bounds),
          child: const Text(
            'Luno Ekosistemi',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        Text(
          GameVersion.parse(gameVersionCode).label,
          style: const TextStyle(
            color: AdminHubColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.onTap,
    this.active = false,
    this.color,
  });

  final String label;
  final VoidCallback onTap;
  final bool active;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final resolved = color ??
        (active ? AdminHubColors.teal : AdminHubColors.muted);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Text(
          label,
          style: TextStyle(
            color: resolved,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
