import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

const _drop = {'HOSTIA', 'HOSTIAS', 'FOLLON', 'COÑOS'};

void main() {
  final kept = <String>[];
  var dropped = 0;
  var invalid = 0;
  for (final raw in File('wordlists/es.txt').readAsLinesSync()) {
    final word = GameLocale.es.writtenUpper(raw);
    if (word.isEmpty) continue;
    if (_drop.contains(word)) {
      dropped++;
      continue;
    }
    final length = GameLocale.es.letterCount(word);
    if (!GameLocale.es.isAllowedWord(word) || length < 5 || length > 7) {
      invalid++;
      stdout.writeln('skip $word');
      continue;
    }
    kept.add(word);
  }
  final buf = StringBuffer()
    ..writeln('/// Common Spanish words, most frequent first.')
    ..writeln('/// Ñ stays. Vowel accents are already folded to A E I O U.')
    ..writeln('const esFrequencyWords = <String>[');
  for (final word in kept) {
    buf.writeln("  '$word',");
  }
  buf.writeln('];');
  File('lib/data/local/es_frequency_words.dart').writeAsStringSync(buf.toString());
  stdout.writeln('kept=${kept.length} dropped=$dropped invalid=$invalid');
}
