import 'package:flutter/material.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/injection.dart';

class GameBootProgress extends StatelessWidget {
  const GameBootProgress({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          sl<L10n>().t('game_starting'),
          style: const TextStyle(
            color: Color(0xFFE2E8F0),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 220,
          child: LinearProgressIndicator(
            minHeight: 6,
            color: AppColors.cosmicGreen,
            backgroundColor: Color(0xFF1E293B),
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ],
    );
  }
}
