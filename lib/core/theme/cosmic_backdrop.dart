import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';

class CosmicBackdrop extends StatefulWidget {
  const CosmicBackdrop({super.key, required this.child});

  final Widget child;

  @override
  State<CosmicBackdrop> createState() => _CosmicBackdropState();
}

class _CosmicBackdropState extends State<CosmicBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;
  late final List<_Star> _stars;
  late final List<_Orb> _orbs;

  @override
  void initState() {
    super.initState();
    final rng = Random(22);
    _stars = List.generate(70, (_) {
      return _Star(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 0.6 + rng.nextDouble() * 2.4,
        color: AppColors.cosmicStarColors[rng.nextInt(AppColors.cosmicStarColors.length)],
        phase: rng.nextDouble(),
        speed: 0.35 + rng.nextDouble() * 0.7,
      );
    });
    _orbs = const [
      _Orb(dx: 0.92, dy: -0.12, size: 280, color: AppColors.cosmicGreen, period: 9),
      _Orb(dx: -0.18, dy: 1.05, size: 240, color: AppColors.cosmicPurple, period: 11),
      _Orb(dx: -0.2, dy: 0.38, size: 200, color: AppColors.cosmicBlue, period: 13),
      _Orb(dx: 1.05, dy: 0.78, size: 180, color: AppColors.cosmicGold, period: 10),
      _Orb(dx: 0.42, dy: 0.68, size: 160, color: AppColors.cosmicRed, period: 14),
    ];
    _tick = AnimationController(vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cosmicBg,
      child: AnimatedBuilder(
        animation: _tick,
        builder: (context, child) {
          final t = _tick.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.7, -0.85),
                    radius: 1.1,
                    colors: [Color(0x592ECC71), Color(0x000A0E1A)],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.85, -0.7),
                    radius: 1.0,
                    colors: [Color(0x4D3498DB), Color(0x000A0E1A)],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.6, 0.9),
                    radius: 0.95,
                    colors: [Color(0x479B59B6), Color(0x000A0E1A)],
                  ),
                ),
              ),
              for (final orb in _orbs) _orbLayer(orb, t),
              CustomPaint(painter: _StarPainter(stars: _stars, t: t)),
              child!,
            ],
          );
        },
        child: widget.child,
      ),
    );
  }

  Widget _orbLayer(_Orb orb, double t) {
    final wave = 2 * pi * (t * (20 / orb.period));
    return Align(
      alignment: Alignment(orb.dx, orb.dy),
      child: Transform.translate(
        offset: Offset(sin(wave) * 18, cos(wave * 0.8) * 14),
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 46, sigmaY: 46),
          child: Container(
            width: orb.size,
            height: orb.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: orb.color.withValues(alpha: 0.28),
            ),
          ),
        ),
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.size,
    required this.color,
    required this.phase,
    required this.speed,
  });

  final double x, y, size, phase, speed;
  final Color color;
}

class _Orb {
  const _Orb({
    required this.dx,
    required this.dy,
    required this.size,
    required this.color,
    required this.period,
  });

  final double dx, dy, size, period;
  final Color color;
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.stars, required this.t});

  final List<_Star> stars;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final twinkle = (sin((t * 20 * star.speed + star.phase * 8)) + 1) / 2;
      final r = star.size * (0.35 + twinkle * 0.85);
      final center = Offset(star.x * size.width, star.y * size.height);
      final paint = Paint()
        ..color = star.color.withValues(alpha: 0.15 + twinkle * 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 1.6);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) => old.t != t;
}
