/// Luno League sürümü. Son rakam API yüklemesinde artar.
const gameVersionCode = '0.0.110';

class GameVersion {
  const GameVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');

  factory GameVersion.parse(String raw) {
    final match = _pattern.firstMatch(raw.trim());
    if (match == null) {
      throw FormatException('Sürüm 0.0.0 biçiminde olmalı: $raw');
    }
    return GameVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
    );
  }

  GameVersion bumpPatch() => GameVersion(major, minor, patch + 1);

  GameVersion bumpMinor() => GameVersion(major, minor + 1, 0);

  GameVersion bumpMajor() => GameVersion(major + 1, 0, 0);

  String get code => '$major.$minor.$patch';

  String get label => 'V.$code';
}
