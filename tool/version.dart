import 'dart:io';

import 'package:kelimelig/core/constants/game_version.dart';

const _path = 'lib/core/constants/game_version.dart';
final _line = RegExp(r"const gameVersionCode = '(\d+\.\d+\.\d+)';");

void main(List<String> args) {
  final file = File(_path);
  final source = file.readAsStringSync();
  final match = _line.firstMatch(source);
  if (match == null) {
    stderr.writeln('Sürüm satırı bulunamadı.');
    exit(1);
  }
  final current = GameVersion.parse(match.group(1)!);
  if (args.isEmpty) {
    stdout.writeln(current.label);
    _usage();
    return;
  }
  if (args.length != 1) {
    _usage();
    exit(64);
  }
  final next = switch (args.single) {
    'patch' => current.bumpPatch(),
    'minor' => current.bumpMinor(),
    'major' => current.bumpMajor(),
    _ => null,
  };
  if (next == null) {
    stderr.writeln('Bilinmeyen komut: ${args.single}');
    _usage();
    exit(64);
  }
  file.writeAsStringSync(
    source.replaceFirst(
      "const gameVersionCode = '${current.code}';",
      "const gameVersionCode = '${next.code}';",
    ),
  );
  stdout.writeln(next.label);
}

void _usage() {
  stdout.writeln('Orta adım: dart run tool/version.dart minor');
  stdout.writeln('Büyük adım: dart run tool/version.dart major');
}
