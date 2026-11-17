import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/theme/colors.dart';

/// Page / brand title for Clash-style dark screens.
/// Brand name uses a green wash; other titles stay bold white with a soft glow.
class ShimmerTitle extends StatelessWidget {
  const ShimmerTitle({
    super.key,
    this.text = AppConstants.appName,
    this.fontSize = 40,
    this.textAlign = TextAlign.center,
    this.compact = false,
  });

  final String text;
  final double fontSize;
  final TextAlign textAlign;

  /// Header size: one line, tighter tracking, lighter glow.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isBrand = text == AppConstants.appName;
    final style = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: compact ? -0.3 : -0.8,
      height: compact ? 1 : 1.05,
      color: Colors.white,
      shadows: compact
          ? const [
              Shadow(color: Color(0x662ECC71), blurRadius: 12),
            ]
          : const [
              Shadow(color: Color(0x662ECC71), blurRadius: 18),
            ],
    );

    final label = Text(
      text,
      textAlign: textAlign,
      maxLines: compact ? 1 : null,
      softWrap: !compact,
      style: style,
    );

    if (!isBrand) return label;

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF6EE7B7),
          AppColors.cosmicGreen,
          AppColors.cosmicTeal,
        ],
      ).createShader(bounds),
      child: label,
    );
  }
}

/// Amber 3D primary CTA (Clash / language-screen style).
class CosmicContinueButton extends StatefulWidget {
  const CosmicContinueButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.showArrow = true,
  });

  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final bool showArrow;

  @override
  State<CosmicContinueButton> createState() => _CosmicContinueButtonState();
}

class _CosmicContinueButtonState extends State<CosmicContinueButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depth = _pressed ? 2.0 : 6.0;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled
            ? (_) {
                _setPressed(false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF92400E),
                offset: Offset(0, depth),
                blurRadius: 0,
              ),
            ],
          ),
          child: Container(
            constraints: const BoxConstraints(minHeight: 54),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFBBF24),
                  Color(0xFFF59E0B),
                  Color(0xFFD97706),
                ],
                stops: [0.0, 0.45, 1.0],
              ),
              border: Border.all(color: const Color(0x66FFF7ED), width: 1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.label.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF1A1205),
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1.1,
                        ),
                      ),
                      if (widget.subtitle != null)
                        Text(
                          widget.subtitle!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xCC1A1205),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            height: 1.2,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.showArrow) ...[
                  const SizedBox(width: 8),
                  const Text(
                    '→',
                    style: TextStyle(
                      color: Color(0xFF1A1205),
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
