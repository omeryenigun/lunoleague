import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';

class CosmicGlassCard extends StatelessWidget {
  const CosmicGlassCard({
    super.key,
    required this.child,
    this.colors = const [
      AppColors.cosmicGold,
      Color(0xFFF39C12),
      Color(0xFFE67E22),
    ],
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  final Widget child;
  final List<Color> colors;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.18),
            blurRadius: 22,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1.6),
        child: Material(
          color: const Color(0xB30F172A),
          borderRadius: BorderRadius.circular(18.4),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18.4),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class CosmicGlassIconButton extends StatelessWidget {
  const CosmicGlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: const Color(0x99301E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0x2694A3B8)),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: const Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }
}

class CosmicCircleButton extends StatelessWidget {
  const CosmicCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: const Color(0xB31E293B),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0x3394A3B8)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(icon, size: 20, color: const Color(0xFFCBD5E1)),
          ),
        ),
      ),
    );
  }
}
