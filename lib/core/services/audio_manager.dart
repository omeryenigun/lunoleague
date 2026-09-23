import 'package:audioplayers/audioplayers.dart';

class AudioManager {
  bool enabled = true;

  AudioPlayer? _fx;
  AudioPlayer? _keys;
  var _queue = Future<void>.value();

  AudioPlayer get _effects => _fx ??= AudioPlayer();
  AudioPlayer get _taps => _keys ??= AudioPlayer();

  Future<void> play(String id) {
    if (!enabled) return Future<void>.value();
    final next = _queue.then((_) => _play(_effects, id));
    _queue = next.then((_) {}, onError: (_) {});
    return next;
  }

  Future<void> _play(AudioPlayer player, String id) async {
    try {
      await player.stop();
      final done = player.onPlayerComplete.first.timeout(
        const Duration(seconds: 3),
      );
      await player.play(AssetSource('audio/$id.wav'));
      await done;
    } catch (_) {}
  }

  Future<void> keyPress() async {
    if (!enabled) return;
    try {
      await _taps.stop();
      await _taps.play(AssetSource('audio/key.wav'));
    } catch (_) {}
  }

  Future<void> correct() => play('correct');
  Future<void> present() => play('present');
  Future<void> wrong() => play('absent');
  Future<void> win() => play('win');
  Future<void> lose() => play('lose');
  Future<void> click() => keyPress();
}
