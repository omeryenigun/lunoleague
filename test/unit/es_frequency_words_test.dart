import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/es_frequency_words.dart';
import 'package:kelimelig/data/local/es_glosses.dart';

void main() {
  test('Spanish list keeps ñ and has a real gloss', () {
    expect(esFrequencyWords, contains('MAÑANA'));
    expect(esFrequencyWords, contains('CAÑON'));
    expect(esFrequencyWords, isNot(contains('HOSTIA')));
    expect(esGlosses['ESTOY'], 'Forma de estar');
    expect(esGlosses['MAÑANA'], 'tomorrow');
    expect(esGlosses['GRACIAS'], contains('thank'));
    expect(GameLocale.es.toUpper('cañón'), 'CAÑON');
    expect(GameLocale.es.writtenUpper('cañón'), 'CAÑÓN');
    for (final word in esFrequencyWords) {
      expect(GameLocale.es.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.es.letterCount(word), inInclusiveRange(5, 7), reason: word);
      expect(esGlosses[word], isNotNull, reason: word);
      expect(esGlosses[word], isNot('Palabra española.'), reason: word);
    }
  });
}
