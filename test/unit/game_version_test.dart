import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/game_version.dart';

void main() {
  test('version starts at V.0.0.0 and patch is the only automatic step', () {
    final start = GameVersion.parse(gameVersionCode);
    expect(start.label, 'V.0.0.0');

    final patch = start.bumpPatch();
    expect(patch.label, 'V.0.0.1');
    expect(patch.bumpPatch().label, 'V.0.0.2');

    expect(GameVersion.parse('0.0.4').bumpMinor().label, 'V.0.1.0');
    expect(GameVersion.parse('0.1.3').bumpMajor().label, 'V.1.0.0');
    expect(GameVersion.parse('1.4.9').bumpMinor().code, '1.5.0');
  });
}
