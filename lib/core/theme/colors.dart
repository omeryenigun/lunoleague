import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';

class AppColors {
  static const background = Color(0xFF0F0F1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceHigh = Color(0xFF16213E);
  static const border = Color(0xFF2A2A4A);
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFAAAAAA);
  static const accent = Color(0xFF4CAF50);
  static const cta = Color(0xFF2E7D32);
  static const ctaEnd = Color(0xFF1B5E20);
  static const ctaText = Color(0xFFFFFFFF);
  static const danger = Color(0xFFB71C1C);
  static const warning = Color(0xFFFFD700);
  static const streak = Color(0xFFFF6B35);
  static const level = Color(0xFF4FC3F7);
  static const share = Color(0xFF1A237E);

  static const correct = Color(0xFF4CAF50);
  static const present = Color(0xFFFFC107);
  static const absent = Color(0xFF616161);
  static const tileEmpty = Color(0x00000000);
  static const tileFilled = Color(0xFF1A1A3E);
  static const keyDefault = Color(0xFF2A2A4A);
  static const keyEnter = Color(0xFF4CAF50);
  static const keyDelete = Color(0xFFB71C1C);

  static const bronze = Color(0xFFB45309);
  static const silver = Color(0xFF9CA3AF);
  static const gold = Color(0xFFFFD700);

  static const titleGradient = LinearGradient(
    colors: [Color(0xFF4CAF50), Color(0xFF00BCD4)],
  );

  static const cosmicBg = Color(0xFF0A0E1A);
  static const cosmicGreen = Color(0xFF2ECC71);
  static const cosmicTeal = Color(0xFF1ABC9C);
  static const cosmicBlue = Color(0xFF3498DB);
  static const cosmicPurple = Color(0xFF9B59B6);
  static const cosmicGold = Color(0xFFF1C40F);
  static const cosmicRed = Color(0xFFE74C3C);

  static const cosmicShimmer = LinearGradient(
    colors: [
      cosmicGreen,
      cosmicTeal,
      cosmicBlue,
      cosmicPurple,
      cosmicRed,
      cosmicGold,
      cosmicGreen,
    ],
  );

  static const cosmicStarColors = <Color>[
    cosmicGreen,
    cosmicTeal,
    cosmicBlue,
    cosmicPurple,
    cosmicGold,
    cosmicRed,
    Color(0xFFE67E22),
    Color(0xFFFFFFFF),
    Color(0xFFFF6B9D),
    Color(0xFF00D2FF),
  ];

  static const ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cta, ctaEnd],
  );

  static Color forLetter(LetterStatus status) => switch (status) {
        LetterStatus.correct => correct,
        LetterStatus.present => present,
        LetterStatus.absent => absent,
        LetterStatus.empty => tileEmpty,
      };

  static Color letterText(LetterStatus status) => switch (status) {
        LetterStatus.present => surface,
        LetterStatus.absent => const Color(0xFF888888),
        _ => textPrimary,
      };

  static Color forLeague(LeagueTier tier) => switch (tier) {
        LeagueTier.bronze => bronze,
        LeagueTier.silver => silver,
        LeagueTier.gold => gold,
      };
}
