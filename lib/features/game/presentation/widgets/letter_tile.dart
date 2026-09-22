import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/theme/colors.dart';

class LetterTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: _decoration,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          color: _textColor,
        ),
      ),
    );
    if (!flip) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + delay.inMilliseconds),
      builder: (context, value, _) {
        final angle = value < 0.5 ? value * 3.14 : (1 - value) * 3.14;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle),
          child: child,
        );
      },
    );
  }

  Color get _textColor {
    return switch (status) {
      LetterStatus.correct || LetterStatus.present => AppColors.cosmicBg,
      LetterStatus.absent => const Color(0xFF94A3B8),
      LetterStatus.empty => const Color(0xFFF8FAFC),
    };
  }

  BoxDecoration get _decoration {
    return switch (status) {
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
          border: Border.all(color: const Color(0x80475565), width: 2),
        ),
      LetterStatus.empty when active || letter.isNotEmpty => BoxDecoration(
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }
}
