import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/theme/colors.dart';

class ShimmerTitle extends StatefulWidget {
  const ShimmerTitle({
    super.key,
    this.text = AppConstants.appName,
    this.fontSize = 40,
    this.textAlign = TextAlign.center,
  });

  final String text;
  final double fontSize;
  final TextAlign textAlign;

  @override
  State<ShimmerTitle> createState() => _ShimmerTitleState();
}

class _ShimmerTitleState extends State<ShimmerTitle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick;

  @override
  void initState() {
    super.initState();
    _tick = AnimationController(vsync: this, duration: const Duration(seconds: 4))
      ..repeat();
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _tick,
      builder: (context, _) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: AppColors.cosmicShimmer.colors,
              begin: Alignment(-1.4 + _tick.value * 2.8, 0),
              end: Alignment(0.2 + _tick.value * 2.8, 0),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            textAlign: widget.textAlign,
            style: TextStyle(
              fontSize: widget.fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.8,
              height: 1.05,
              color: Colors.white,
              shadows: const [
                Shadow(color: Color(0x662ECC71), blurRadius: 22),
                Shadow(color: Color(0x449B59B6), blurRadius: 36),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CosmicContinueButton extends StatelessWidget {
  const CosmicContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.showArrow = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [
            AppColors.cosmicGreen,
            AppColors.cosmicTeal,
            AppColors.cosmicBlue,
            AppColors.cosmicPurple,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.cosmicGreen.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: AppColors.cosmicBlue.withValues(alpha: 0.22),
            blurRadius: 48,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.cosmicBg,
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                if (showArrow) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '→',
                    style: TextStyle(
                      color: AppColors.cosmicBg,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
