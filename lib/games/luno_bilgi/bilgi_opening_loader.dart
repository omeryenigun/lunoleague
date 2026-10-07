import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';

const _openBg = Color(0xFF16082C);
const _openGold = Color(0xFFFFC83D);
const _openGoldText = Color(0xFFFFD76A);
const _openMuted = Color(0xFFD4C4E8);

/// Full-screen cold-start loader for Luno Bilgi (not in-game question loading).
class BilgiOpeningLoader extends StatefulWidget {
  const BilgiOpeningLoader({
    super.key,
    required this.progress,
    required this.status,
    required this.message,
    required this.gameName,
    required this.slogan,
    required this.version,
  });

  final double progress;
  final String status;
  final String message;
  final String gameName;
  final String slogan;
  final String version;

  @override
  State<BilgiOpeningLoader> createState() => _BilgiOpeningLoaderState();
}

class _BilgiOpeningLoaderState extends State<BilgiOpeningLoader>
    with TickerProviderStateMixin {
  late final AnimationController _breathe;
  late final AnimationController _ring;
  late final AnimationController _dots;
  late final AnimationController _float;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _ring = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _float = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _breathe.dispose();
    _ring.dispose();
    _dots.dispose();
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.progress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();

    return ColoredBox(
      color: BilgiColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _GlowBackground(),
          AnimatedBuilder(
            animation: _float,
            builder: (context, _) => CustomPaint(
              painter: _FloatingDotsPainter(t: _float.value),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  _LogoBlock(breathe: _breathe, ring: _ring),
                  const SizedBox(height: 28),
                  _GradientTitle(text: widget.gameName),
                  const SizedBox(height: 10),
                  Text(
                    widget.slogan.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.nunito(
                      color: _openMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3.2,
                    ),
                  ),
                  const Spacer(flex: 2),
                  _ProgressBlock(
                    progress: progress,
                    percent: percent,
                    status: widget.status,
                    message: widget.message,
                    dots: _dots,
                  ),
                  const Spacer(flex: 2),
                  Text(
                    'v${widget.version}',
                    style: TextStyle(
                      color: BilgiColors.muted.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowBackground extends StatelessWidget {
  const _GlowBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          top: -120,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF7C3AED).withValues(alpha: 0.35),
                    const Color(0xFF7C3AED).withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _openGold.withValues(alpha: 0.18),
                    _openGold.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoBlock extends StatelessWidget {
  const _LogoBlock({required this.breathe, required this.ring});

  final AnimationController breathe;
  final AnimationController ring;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 168,
      child: AnimatedBuilder(
        animation: Listenable.merge([breathe, ring]),
        builder: (context, child) {
          final scale = 0.96 + (breathe.value * 0.08);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: ring.value * math.pi * 2,
                child: CustomPaint(
                  size: const Size(168, 168),
                  painter: _ConicRingPainter(),
                ),
              ),
              Transform.scale(scale: scale, child: child),
            ],
          );
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: const Color(0xFF3C1468),
            border: Border.all(color: _openGold, width: 2),
            boxShadow: [
              BoxShadow(
                color: _openGold.withValues(alpha: 0.28),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Image.asset(
              'assets/images/luno_bilgi_logo.png',
              width: 120,
              height: 120,
              fit: BoxFit.contain,
              semanticLabel: 'Luno Bilgi',
              errorBuilder: (_, _, _) => const Center(
                child: Text('🧠', style: TextStyle(fontSize: 52)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientTitle extends StatelessWidget {
  const _GradientTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      maxLines: 1,
      softWrap: false,
      style: GoogleFonts.nunito(
        fontSize: 34,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.2,
        height: 1.05,
        color: _openGoldText,
        shadows: const [Shadow(color: Color(0xFF8A4B00), offset: Offset(0, 2), blurRadius: 0)],
      ),
    );
  }
}

class _ProgressBlock extends StatelessWidget {
  const _ProgressBlock({
    required this.progress,
    required this.percent,
    required this.status,
    required this.message,
    required this.dots,
  });

  final double progress;
  final int percent;
  final String status;
  final String message;
  final AnimationController dots;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(
                  color: BilgiColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                color: _openGoldText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final fill = width * progress;
            return SizedBox(
              height: 8,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: width,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    width: fill.clamp(0.0, width),
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(99),
                      gradient: const LinearGradient(
                        colors: [_openGold, _openGoldText],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _openGoldText.withValues(alpha: 0.35),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  if (progress > 0.02)
                    Positioned(
                      left: (fill - 7).clamp(0.0, width - 14),
                      top: -3,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _openGoldText,
                          boxShadow: [
                            BoxShadow(
                              color: _openGoldText.withValues(alpha: 0.7),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 14),
        AnimatedBuilder(
          animation: dots,
          builder: (context, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BilgiColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Transform.translate(
                      offset: Offset(
                        0,
                        -4 *
                            Curves.easeInOut.transform(
                              (((dots.value + i * 0.2) % 1.0) < 0.5)
                                  ? ((dots.value + i * 0.2) % 1.0) * 2
                                  : (1 - ((dots.value + i * 0.2) % 1.0)) * 2,
                            ),
                      ),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i.isOdd
                              ? _openGoldText
                              : _openGold,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _ConicRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..shader = SweepGradient(
        colors: [
          _openGold.withValues(alpha: 0),
          _openGold.withValues(alpha: 0.55),
          _openGoldText.withValues(alpha: 0.35),
          _openGold.withValues(alpha: 0),
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FloatingDotsPainter extends CustomPainter {
  _FloatingDotsPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = <(double, double, double, Color)>[
      (0.18, 0.22, 3.5, _openGoldText),
      (0.78, 0.18, 2.8, _openGold),
      (0.12, 0.62, 2.4, _openGold),
      (0.86, 0.55, 3.2, _openGoldText),
      (0.55, 0.78, 2.6, _openGold),
      (0.42, 0.14, 2.2, _openGoldText),
    ];
    for (var i = 0; i < dots.length; i++) {
      final (nx, ny, r, color) = dots[i];
      final phase = t * math.pi * 2 + i * 0.9;
      final x = nx * size.width + math.sin(phase) * 10;
      final y = ny * size.height + math.cos(phase * 0.8) * 12;
      final paint = Paint()..color = color.withValues(alpha: 0.28 + 0.12 * math.sin(phase));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingDotsPainter oldDelegate) => oldDelegate.t != t;
}
