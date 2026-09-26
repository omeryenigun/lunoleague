import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

const _drop = {
  'PUTES',
  'SALAUDS',
  'MERDES',
  'MERDER',
  'EMMERDE',
  'DEMERDE',
  'BAISERS',
  'BAISERA',
  'BITES',
  'COUILLE',
  'COUILLU',
  'CHIOTTE',
  'BORDELS',
};

void main() {
  final kept = <String>[];
  var dropped = 0;
  var invalid = 0;
  for (final raw in File('wordlists/fr.txt').readAsLinesSync()) {
    final word = GameLocale.fr.writtenUpper(raw);
    if (word.isEmpty) continue;
    if (_drop.contains(word)) {
      dropped++;
      continue;
    }
    final length = GameLocale.fr.letterCount(word);
    if (!GameLocale.fr.isAllowedWord(word) || length < 5 || length > 7) {
      invalid++;
      stdout.writeln('skip $word');
      continue;
    }
    kept.add(word);
  }
  final buf = StringBuffer()
    ..writeln('/// Common French words, most frequent first.')
    ..writeln('/// Accents are already folded, so école is stored as ECOLE.')
    ..writeln('const frFrequencyWords = <String>[')
  ;
  for (final word in kept) {
    buf.writeln("  '$word',");
  }
  buf.writeln('];');
  File('lib/data/local/fr_frequency_words.dart').writeAsStringSync(buf.toString());
  stdout.writeln('kept=${kept.length} dropped=$dropped invalid=$invalid');
}
