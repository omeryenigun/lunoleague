import 'package:flutter/material.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';

class GridPalette {
  const GridPalette(this.top, this.bottom);

  final Color top;
  final Color bottom;
}

const gridPalettes = <GridPalette>[
  GridPalette(Color(0xFF241447), Color(0xFF4A2068)),
  GridPalette(Color(0xFF0E1C38), Color(0xFF16324E)),
  GridPalette(Color(0xFF1A1030), Color(0xFF3A1848)),
  GridPalette(Color(0xFF102028), Color(0xFF1A3048)),
  GridPalette(Color(0xFF2A1238), Color(0xFF123048)),
  GridPalette(Color(0xFF14102A), Color(0xFF2E2458)),
];

class GridRules {
  static const difficulties = ['starter', 'easy', 'normal', 'hard', 'master'];

  static String difficultyLabel(String id) => switch (id) {
        'starter' => 'Starter',
        'easy' => 'Easy',
        'normal' => 'Normal',
        'hard' => 'Hard',
        _ => 'Master',
      };

  static int lengthScore(int length) => switch (length) {
        <= 3 => 30,
        4 => 50,
        5 => 80,
        6 => 120,
        _ => 180,
      };

  static int speedBonus(Duration elapsed) {
    final seconds = elapsed.inSeconds;
    if (seconds <= 45) return 200;
    if (seconds <= 75) return 150;
    if (seconds <= 120) return 100;
    if (seconds <= 180) return 50;
    return 0;
  }

  static int comboAfter(int current, Duration gap) {
    if (gap.inSeconds >= 8) return 1;
    if (current >= 4) return 4;
    return current + 1;
  }

  static bool canSpell(String word, List<String> circle) {
    final pool = <String, int>{};
    for (final letter in circle) {
      pool[letter] = (pool[letter] ?? 0) + 1;
    }
    for (final letter in TurkishText.letters(word)) {
      final left = pool[letter] ?? 0;
      if (left <= 0) return false;
      pool[letter] = left - 1;
    }
    return true;
  }
}
