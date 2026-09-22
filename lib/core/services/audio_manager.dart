import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AudioManager {
  bool enabled = true;

  Future<void> play(String id) async {
    if (!enabled || kIsWeb) {
      return;
    }
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  Future<void> keyPress() => play('key_press');
  Future<void> correct() => play('correct_letter');
  Future<void> wrong() => play('wrong_letter');
  Future<void> win() => play('game_win');
  Future<void> lose() => play('game_lose');
  Future<void> click() => play('button_click');
}
