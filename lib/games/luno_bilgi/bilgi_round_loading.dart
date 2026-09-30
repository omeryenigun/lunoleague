import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';

/// Full-screen loader shown after Start while that round's questions draw.
/// Not the app-open splash ([BilgiOpeningLoader]).
class BilgiRoundLoading extends StatefulWidget {
  const BilgiRoundLoading({
    super.key,
    required this.progress,
    required this.status,
    required this.message,
    required this.modeEmoji,
    required this.modeName,
    required this.subtitle,
    required this.categoryLabel,
    required this.categoryValue,
    required this.difficultyLabel,
    required this.difficultyValue,
    required this.difficultyColor,
    required this.questionsLabel,
    required this.questionsValue,
    required this.timeLabel,
    required this.timeValue,
    required this.questionCount,
    required this.tip,
    required this.onCancel,
  });

  final double progress;
  final String status;
  final String message;
  final String modeEmoji;
  final String modeName;
  final String subtitle;
  final String categoryLabel;
  final String categoryValue;
  final String difficultyLabel;
  final String difficultyValue;
  final Color difficultyColor;
  final String questionsLabel;
  final String questionsValue;
  final String timeLabel;
  final String timeValue;
  final int questionCount;
  final String tip;
  final VoidCallback onCancel;

  @override
  State<BilgiRoundLoading> createState() => _BilgiRoundLoadingState();
}

class _BilgiRoundLoadingState extends State<BilgiRoundLoading>
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
    final dotCount = widget.questionCount.clamp(1, 20);

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _CancelButton(onTap: widget.onCancel),
                  ),
                  const Spacer(flex: 2),
                  _ModeBadge(
                    emoji: widget.modeEmoji,
                    breathe: _breathe,
                    ring: _ring,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widget.modeName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BilgiColors.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: BilgiColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _SettingsCard(
                    categoryLabel: widget.categoryLabel,
                    categoryValue: widget.categoryValue,
                    difficultyLabel: widget.difficultyLabel,
                    difficultyValue: widget.difficultyValue,
                    difficultyColor: widget.difficultyColor,
                    questionsLabel: widget.questionsLabel,
                    questionsValue: widget.questionsValue,
                    timeLabel: widget.timeLabel,
                    timeValue: widget.timeValue,
                  ),
                  const SizedBox(height: 22),
                  _ProgressBlock(
                    progress: progress,
                    percent: percent,
                    status: widget.status,
                    message: widget.message,
                    dots: _dots,
                  ),
                  const SizedBox(height: 16),
                  _QuestionDots(count: dotCount, progress: progress),
                  const Spacer(flex: 2),
                  Text(
                    widget.tip,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: BilgiColors.muted.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CancelButton extends StatelessWidget {
  const _CancelButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BilgiColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 40,
          height: 40,
          child: Icon(Icons.close_rounded, size: 18, color: BilgiColors.text),
        ),
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({
    required this.emoji,
    required this.breathe,
    required this.ring,
  });

  final String emoji;
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
          width: 128,
          height: 128,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BilgiColors.primary, BilgiColors.primaryLight],
            ),
            boxShadow: [
              BoxShadow(
                color: BilgiColors.primary.withValues(alpha: 0.55),
                blurRadius: 28,
                spreadRadius: 2,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 56)),
          ),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.categoryLabel,
    required this.categoryValue,
    required this.difficultyLabel,
    required this.difficultyValue,
    required this.difficultyColor,
    required this.questionsLabel,
    required this.questionsValue,
    required this.timeLabel,
    required this.timeValue,
  });

  final String categoryLabel;
  final String categoryValue;
  final String difficultyLabel;
  final String difficultyValue;
  final Color difficultyColor;
  final String questionsLabel;
  final String questionsValue;
  final String timeLabel;
  final String timeValue;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: BilgiColors.card.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        label: categoryLabel,
                        value: categoryValue,
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: difficultyLabel,
                        value: difficultyValue,
                        valueColor: difficultyColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _StatCell(
                        label: questionsLabel,
                        value: questionsValue,
                      ),
                    ),
                    Expanded(
                      child: _StatCell(
                        label: timeLabel,
                        value: timeValue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: BilgiColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor ?? BilgiColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
                color: BilgiColors.secondary,
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
                        colors: [BilgiColors.primary, BilgiColors.secondary],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: BilgiColors.secondary.withValues(alpha: 0.35),
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
                          color: BilgiColors.secondary,
                          boxShadow: [
                            BoxShadow(
                              color: BilgiColors.secondary.withValues(alpha: 0.7),
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
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: BilgiColors.secondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(width: 8),
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
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QuestionDots extends StatelessWidget {
  const _QuestionDots({required this.count, required this.progress});

  final int count;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final filled = (progress * count).floor().clamp(0, count);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? BilgiColors.secondary
                  : Colors.white.withValues(alpha: 0.14),
            ),
          ),
      ],
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
                    BilgiColors.primary.withValues(alpha: 0.35),
                    BilgiColors.primary.withValues(alpha: 0),
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
                    BilgiColors.secondary.withValues(alpha: 0.22),
                    BilgiColors.secondary.withValues(alpha: 0),
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
          BilgiColors.primary.withValues(alpha: 0),
          BilgiColors.primaryLight.withValues(alpha: 0.55),
          BilgiColors.secondary.withValues(alpha: 0.35),
          BilgiColors.primary.withValues(alpha: 0),
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
      (0.18, 0.22, 3.5, BilgiColors.secondary),
      (0.78, 0.18, 2.8, BilgiColors.primaryLight),
      (0.12, 0.62, 2.4, BilgiColors.primary),
      (0.86, 0.55, 3.2, BilgiColors.secondary),
      (0.55, 0.78, 2.6, BilgiColors.primaryLight),
      (0.42, 0.14, 2.2, BilgiColors.secondary),
    ];
    for (var i = 0; i < dots.length; i++) {
      final (nx, ny, r, color) = dots[i];
      final phase = t * math.pi * 2 + i * 0.9;
      final x = nx * size.width + math.sin(phase) * 10;
      final y = ny * size.height + math.cos(phase * 0.8) * 12;
      final paint = Paint()
        ..color = color.withValues(alpha: 0.28 + 0.12 * math.sin(phase));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _FloatingDotsPainter oldDelegate) =>
      oldDelegate.t != t;
}
