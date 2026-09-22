import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticManager {
  bool enabled = true;

  Future<void> light() async {
    if (!enabled || kIsWeb) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> medium() async {
    if (!enabled || kIsWeb) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  Future<void> success() async {
    if (!enabled || kIsWeb) return;
    try {
      final has = await Vibration.hasVibrator();
      if (has == true) {
        await Vibration.vibrate(duration: 40);
      } else {
        await HapticFeedback.mediumImpact();
      }
    } catch (_) {}
  }
}
