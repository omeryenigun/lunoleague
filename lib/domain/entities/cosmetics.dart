import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';

class Cosmetics {
  static const themeDefault = 'theme_default';
  static const themeSeason = 'theme_season';
  static const frameDefault = 'frame_default';
  static const frameMonth = 'frame_month';
  static const frameSeason = 'frame_season';
  static const frameHonor = 'frame_honor';

  static const defaults = [themeDefault, frameDefault];

  static String themeLabel(String id) => switch (id) {
        themeSeason => 'Sezon teması',
        _ => 'Varsayılan tema',
      };

  static String frameLabel(String id) => switch (id) {
        frameMonth => 'Aylık çerçeve',
        frameSeason => 'Sezon çerçevesi',
        frameHonor => 'Onur çerçevesi',
        _ => 'Varsayılan çerçeve',
      };

  static Color frameColor(String id) => switch (id) {
        frameMonth => AppColors.gold,
        frameSeason => AppColors.accent,
        frameHonor => const Color(0xFFE8D5A3),
        _ => AppColors.border,
      };
}
