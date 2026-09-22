import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/theme/colors.dart';

class TurkishKeyboard extends StatelessWidget {
  const TurkishKeyboard({
    super.key,
    required this.states,
    required this.onLetter,
    required this.onEnter,
    required this.onBackspace,
    this.locale = GameLocale.tr,
  });

  final Map<String, LetterStatus> states;
  final ValueChanged<String> onLetter;
  final VoidCallback onEnter;
  final VoidCallback onBackspace;
  final GameLocale locale;

  List<String> get row1 => locale.keyboard[0];
  List<String> get row2 => locale.keyboard[1];
  List<String> get row3 => locale.keyboard[2];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(row1),
        const SizedBox(height: 6),
        _row(row2),
        const SizedBox(height: 6),
        Row(
          children: [
            _special('ENTER', onEnter, flex: 14, enter: true),
            ...row3.map((l) => Expanded(flex: 10, child: _key(l))),
            _special('⌫', onBackspace, flex: 12, enter: false),
          ],
        ),
      ],
    );
  }

  Widget _row(List<String> letters) {
    return Row(
      children: letters.map((l) => Expanded(child: _key(l))).toList(),
    );
  }

  Widget _key(String letter) {
    final status = states[letter] ?? LetterStatus.empty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onLetter(letter),
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            height: 50,
            decoration: _keyDecoration(status),
            child: Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: _keyText(status),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _special(
    String label,
    VoidCallback onTap, {
    required int flex,
    required bool enter,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: enter
                      ? const [AppColors.cosmicGreen, Color(0xFF27AE60)]
                      : const [AppColors.cosmicRed, Color(0xFFC0392B)],
                ),
                border: Border.all(
                  color: enter ? AppColors.cosmicGreen : AppColors.cosmicRed,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (enter ? AppColors.cosmicGreen : AppColors.cosmicRed)
                        .withValues(alpha: 0.4),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: enter ? 11 : 16,
                    letterSpacing: 0.2,
                    color: enter ? AppColors.cosmicBg : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _keyDecoration(LetterStatus status) {
    return switch (status) {
      LetterStatus.correct => BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [AppColors.cosmicGreen, AppColors.cosmicTeal],
          ),
          border: Border.all(color: AppColors.cosmicGreen),
          boxShadow: [
            BoxShadow(
              color: AppColors.cosmicGreen.withValues(alpha: 0.45),
              blurRadius: 12,
            ),
          ],
        ),
      LetterStatus.present => BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(
            colors: [AppColors.cosmicGold, Color(0xFFF39C12)],
          ),
          border: Border.all(color: AppColors.cosmicGold),
          boxShadow: [
            BoxShadow(
              color: AppColors.cosmicGold.withValues(alpha: 0.45),
              blurRadius: 12,
            ),
          ],
        ),
      LetterStatus.absent => BoxDecoration(
          color: const Color(0x80301E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x4D475569)),
        ),
      LetterStatus.empty => BoxDecoration(
          color: const Color(0xCC1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0x1F94A3B8)),
        ),
    };
  }

  Color _keyText(LetterStatus status) {
    return switch (status) {
      LetterStatus.correct || LetterStatus.present => AppColors.cosmicBg,
      LetterStatus.absent => const Color(0xFF475569),
      LetterStatus.empty => const Color(0xFFE2E8F0),
    };
  }
}
