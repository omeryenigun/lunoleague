import 'dart:math';

import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/motion_manager.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/injection.dart';

class LetterTile extends StatefulWidget {
  const LetterTile({
    super.key,
    required this.letter,
    required this.status,
    this.size = 48,
    this.delay = Duration.zero,
    this.flip = false,
    this.active = false,
  });

  final String letter;
  final LetterStatus status;
  final double size;
  final Duration delay;
  final bool flip;
  final bool active;

  @override
  State<LetterTile> createState() => _LetterTileState();
}

class _LetterTileState extends State<LetterTile>
    with TickerProviderStateMixin {
  late final AnimationController _flip;
  late final AnimationController _pop;
  late final AnimationController _fx;
  var _fxSeed = 0;

  bool get _motionOn =>
      !sl.isRegistered<MotionManager>() || sl<MotionManager>().enabled;

  bool get _shouldCelebrate =>
      widget.flip &&
      _motionOn &&
      (widget.status == LetterStatus.correct ||
          widget.status == LetterStatus.present);

  @override
  void initState() {
    super.initState();
    _flip = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 280 + widget.delay.inMilliseconds),
    );
    _pop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fx = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _kickOff();
  }

  @override
  void didUpdateWidget(covariant LetterTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.flip &&
        (!oldWidget.flip ||
            oldWidget.status != widget.status ||
            oldWidget.letter != widget.letter)) {
      _flip.duration =
          Duration(milliseconds: 280 + widget.delay.inMilliseconds);
      _kickOff();
    }
  }

  void _playReveal() {
    if (!sl.isRegistered<AudioManager>()) return;
    final audio = sl<AudioManager>();
    switch (widget.status) {
      case LetterStatus.correct:
        audio.correct();
      case LetterStatus.present:
        audio.present();
      case LetterStatus.absent:
        audio.wrong();
      case LetterStatus.empty:
        break;
    }
  }

  void _kickOff() {
    _flip.stop();
    _pop.stop();
    _fx.stop();
    _flip.value = 0;
    _pop.value = 0;
    _fx.value = 0;
    if (widget.flip) _playReveal();
    if (!_motionOn || !widget.flip) {
      _flip.value = 1;
      return;
    }
    _fxSeed = DateTime.now().microsecondsSinceEpoch;
    _flip.forward().then((_) async {
      if (!mounted || !_shouldCelebrate) return;
      _pop.forward(from: 0);
      _fx.forward(from: 0);
    });
  }

  @override
  void dispose() {
    _flip.dispose();
    _pop.dispose();
    _fx.dispose();
    super.dispose();
  }

  Color get _textColor {
    return switch (widget.status) {
      LetterStatus.correct || LetterStatus.present => AppColors.cosmicBg,
      LetterStatus.absent => const Color(0xFF94A3B8),
      LetterStatus.empty => const Color(0xFFF8FAFC),
    };
  }

  BoxDecoration get _decoration {
    return switch (widget.status) {
      LetterStatus.correct => BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cosmicGreen, AppColors.cosmicTeal],
          ),
          border: Border.all(color: AppColors.cosmicGreen, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.cosmicGreen.withValues(alpha: 0.55),
              blurRadius: 18,
            ),
          ],
        ),
      LetterStatus.present => BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cosmicGold, Color(0xFFF39C12)],
          ),
          border: Border.all(color: AppColors.cosmicGold, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.cosmicGold.withValues(alpha: 0.5),
              blurRadius: 18,
            ),
          ],
        ),
      LetterStatus.absent => BoxDecoration(
          color: const Color(0xB3475565),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x80475569), width: 2),
        ),
      LetterStatus.empty when widget.active || widget.letter.isNotEmpty =>
        BoxDecoration(
          color: const Color(0xE60F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x992ECC71), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.cosmicGreen.withValues(alpha: 0.22),
              blurRadius: 16,
            ),
          ],
        ),
      LetterStatus.empty => BoxDecoration(
          color: const Color(0x9910172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x2694A3B8), width: 2),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final tile = AnimatedBuilder(
      animation: Listenable.merge([_flip, _pop]),
      builder: (context, _) {
        final flipT = _motionOn && widget.flip ? _flip.value : 1.0;
        final showFace = flipT >= 0.5;
        final angle = flipT < 0.5 ? flipT * pi : (1 - flipT) * pi;
        final popT = _pop.value;
        var scale = 1.0;
        var rot = 0.0;
        if (popT > 0 && popT < 1) {
          if (popT < 0.3) {
            final t = popT / 0.3;
            scale = 1 + 0.25 * t;
            rot = -0.1 * t;
          } else if (popT < 0.5) {
            final t = (popT - 0.3) / 0.2;
            scale = 1.25 - 0.3 * t;
            rot = -0.1 + 0.17 * t;
          } else if (popT < 0.7) {
            final t = (popT - 0.5) / 0.2;
            scale = 0.95 + 0.15 * t;
            rot = 0.07 - 0.1 * t;
          } else {
            final t = (popT - 0.7) / 0.3;
            scale = 1.1 - 0.1 * t;
            rot = -0.03 + 0.03 * t;
          }
        }

        final face = Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: showFace
              ? _decoration
              : BoxDecoration(
                  color: const Color(0xE60F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0x992ECC71),
                    width: 2,
                  ),
                ),
          child: Text(
            widget.letter,
            style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w900,
              color: showFace ? _textColor : const Color(0xFFF8FAFC),
            ),
          ),
        );

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(_motionOn && widget.flip ? angle : 0)
            ..rotateZ(rot)
            ..scaleByDouble(scale, scale, 1, 1),
          child: face,
        );
      },
    );

    if (!_shouldCelebrate) {
      return SizedBox(width: size, height: size, child: tile);
    }

    final accent = widget.status == LetterStatus.correct
        ? AppColors.cosmicGreen
        : AppColors.cosmicGold;
    final label = widget.status == LetterStatus.correct ? '✓' : '·';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned(
            left: -size * 0.7,
            top: -size * 0.7,
            width: size * 2.4,
            height: size * 2.4,
            child: AnimatedBuilder(
              animation: _fx,
              builder: (context, _) {
                return CustomPaint(
                  painter: _TileFxPainter(
                    progress: _fx.value,
                    accent: accent,
                    seed: _fxSeed,
                    strong: widget.status == LetterStatus.correct,
                  ),
                );
              },
            ),
          ),
          tile,
          AnimatedBuilder(
            animation: _fx,
            builder: (context, _) {
              final t = _fx.value;
              if (t <= 0 || t >= 1) return const SizedBox.shrink();
              final opacity = t < 0.2
                  ? t / 0.2
                  : (1 - ((t - 0.2) / 0.8)).clamp(0.0, 1.0);
              final dy = -6.0 - t * 34;
              return Transform.translate(
                offset: Offset(0, dy),
                child: Opacity(
                  opacity: opacity,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      fontSize: size * 0.28,
                      shadows: [
                        Shadow(
                          color: accent.withValues(alpha: 0.8),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TileFxPainter extends CustomPainter {
  _TileFxPainter({
    required this.progress,
    required this.accent,
    required this.seed,
    required this.strong,
  });

  final double progress;
  final Color accent;
  final int seed;
  final bool strong;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final rng = Random(seed);
    final cx = size.width / 2;
    final cy = size.height / 2;
    final colors = strong
        ? [
            AppColors.cosmicGreen,
            AppColors.cosmicTeal,
            AppColors.cosmicGold,
            Colors.white,
            AppColors.cosmicBlue,
          ]
        : [
            AppColors.cosmicGold,
            const Color(0xFFF39C12),
            Colors.white,
            AppColors.cosmicTeal,
          ];

    // Expanding ring
    final ringT = (progress / 0.7).clamp(0.0, 1.0);
    if (ringT > 0 && ringT < 1) {
      final r = 6 + ringT * (strong ? 52 : 40);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = accent.withValues(alpha: (1 - ringT) * 0.85);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }

    // Sparks
    final count = strong ? 12 : 8;
    for (var i = 0; i < count; i++) {
      final local = ((progress - 0.05) / 0.85).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final angle = (pi * 2 * i) / count + (rng.nextDouble() - 0.5) * 0.5;
      final dist = (30 + rng.nextDouble() * 45) * local;
      final px = cx + cos(angle) * dist;
      final py = cy + sin(angle) * dist;
      final s = (3 + rng.nextDouble() * 5) * (1 - local * 0.7);
      final c = colors[i % colors.length]
          .withValues(alpha: (1 - local) * 0.95);
      canvas.drawCircle(
        Offset(px, py),
        s,
        Paint()
          ..color = c
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
      );
    }

    // Flow dots downward
    final dots = strong ? 6 : 4;
    for (var i = 0; i < dots; i++) {
      final start = 0.12 + i * 0.08;
      final local = ((progress - start) / 0.7).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final dx = (rng.nextDouble() - 0.5) * 28;
      final dy = 12 + local * 90;
      final c = colors[i % colors.length]
          .withValues(alpha: (1 - local) * 0.85);
      canvas.drawCircle(
        Offset(cx + dx, cy + dy),
        2 * (1 - local * 0.6),
        Paint()..color = c,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TileFxPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.seed != seed;
}

class StatChip extends StatelessWidget {
  const StatChip({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
