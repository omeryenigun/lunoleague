import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';

/// Slate glass card with accent-tinted border (Clash-style surfaces).
class CosmicGlassCard extends StatelessWidget {
  const CosmicGlassCard({
    super.key,
    required this.child,
    this.colors = const [
      AppColors.cosmicGold,
      Color(0xFFF59E0B),
      Color(0xFFD97706),
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
    final accent = colors.isNotEmpty ? colors.first : AppColors.cosmicGold;
    final radius = BorderRadius.circular(16);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            color: const Color(0xE61E293B),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.25,
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.18),
                blurRadius: 18,
                spreadRadius: 0.5,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 100,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withValues(alpha: 0.22),
                          accent.withValues(alpha: 0.06),
                          accent.withValues(alpha: 0.0),
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x0DFFFFFF), Color(0x00FFFFFF)],
                        stops: [0.0, 0.55],
                      ),
                    ),
                  ),
                ),
                Padding(padding: padding, child: child),
              ],
            ),
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
        color: const Color(0xCC1E293B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF334155)),
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
        color: const Color(0xCC1E293B),
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFF334155)),
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
