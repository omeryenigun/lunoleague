import 'package:flutter/material.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/cosmetics.dart';

Color frameColor(String id) => switch (id) {
      Cosmetics.frameMonth => AppColors.gold,
      Cosmetics.frameSeason => AppColors.accent,
      Cosmetics.frameHonor => const Color(0xFFE8D5A3),
      _ => AppColors.border,
    };
