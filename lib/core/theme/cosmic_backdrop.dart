import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';

/// Navy Clash-style backdrop: solid #0B1120 with soft green/blue radials.
/// No stars or floating orbs — matches home / language screens.
class CosmicBackdrop extends StatelessWidget {
  const CosmicBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cosmicBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.85, -0.95),
                radius: 1.05,
                colors: [Color(0x332ECC71), Color(0x000B1120)],
                stops: [0.0, 0.55],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.95, 1.05),
                radius: 1.1,
                colors: [Color(0x333498DB), Color(0x000B1120)],
                stops: [0.0, 0.55],
              ),
            ),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(1.05, 0.2),
                radius: 0.95,
                colors: [Color(0x22E11D48), Color(0x000B1120)],
                stops: [0.0, 0.55],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
