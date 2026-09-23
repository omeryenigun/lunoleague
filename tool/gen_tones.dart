import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const _rate = 22050;

void main() {
  final dir = Directory('assets/audio');
  dir.createSync(recursive: true);
  _write(dir, 'key', [_Note(1400, 0.028, 0.12)]);
  _write(dir, 'correct', [
    _Note(784, 0.07, 0.42),
    _Note(1175, 0.09, 0.28, at: 0.045),
  ]);
  _write(dir, 'present', [_Note(587, 0.13, 0.34)]);
  _write(dir, 'absent', [_Note(165, 0.07, 0.22, square: true)]);
  _write(dir, 'win', [
    _Note(523, 0.12, 0.36),
    _Note(659, 0.12, 0.38, at: 0.13),
    _Note(784, 0.12, 0.4, at: 0.26),
    _Note(1047, 0.2, 0.42, at: 0.39),
  ]);
  _write(dir, 'lose', [
    _Note(392, 0.18, 0.32),
    _Note(262, 0.28, 0.3, at: 0.2),
  ]);
}

void _write(Directory dir, String name, List<_Note> notes) {
  final end = notes.map((n) => n.at + n.seconds).reduce(max);
  final count = (end * _rate).ceil();
  final samples = List<double>.filled(count, 0);
  for (final note in notes) {
    final start = (note.at * _rate).floor();
    final length = (note.seconds * _rate).floor();
    for (var i = 0; i < length; i++) {
      final t = i / _rate;
      final env = _envelope(i, length);
      final wave = note.square
          ? (sin(2 * pi * note.hz * t) >= 0 ? 1.0 : -1.0) * 0.35
          : sin(2 * pi * note.hz * t);
      final index = start + i;
      if (index < samples.length) {
        samples[index] += wave * env * note.gain;
      }
    }
  }
  File('${dir.path}/$name.wav').writeAsBytesSync(_wav(samples));
}

double _envelope(int i, int length) {
  final attack = min(180, length ~/ 5);
  final release = min(400, length ~/ 3);
  if (i < attack) return i / attack;
  if (i > length - release) return (length - i) / release;
  return 1;
}

Uint8List _wav(List<double> samples) {
  final dataBytes = samples.length * 2;
  final bytes = ByteData(44 + dataBytes);
  void str(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes.setUint8(offset + i, value.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  bytes.setUint32(4, 36 + dataBytes, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  bytes.setUint32(16, 16, Endian.little);
  bytes.setUint16(20, 1, Endian.little);
  bytes.setUint16(22, 1, Endian.little);
  bytes.setUint32(24, _rate, Endian.little);
  bytes.setUint32(28, _rate * 2, Endian.little);
  bytes.setUint16(32, 2, Endian.little);
  bytes.setUint16(34, 16, Endian.little);
  str(36, 'data');
  bytes.setUint32(40, dataBytes, Endian.little);
  for (var i = 0; i < samples.length; i++) {
    final sample = samples[i].clamp(-1.0, 1.0);
    bytes.setInt16(44 + i * 2, (sample * 32767).round(), Endian.little);
  }
  return bytes.buffer.asUint8List();
}

class _Note {
  const _Note(this.hz, this.seconds, this.gain, {this.at = 0, this.square = false});

  final double hz;
  final double seconds;
  final double gain;
  final double at;
  final bool square;
}
