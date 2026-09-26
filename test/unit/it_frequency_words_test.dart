import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/it_frequency_words.dart';
import 'package:kelimelig/data/local/it_glosses.dart';

void main() {
  test('Italian list folds accents and has a real gloss', () {
    expect(itFrequencyWords, contains('CITTA'));
    expect(itFrequencyWords, contains('GRAZIE'));
    expect(itFrequencyWords, isNot(contains('FOTTUTO')));
    expect(itFrequencyWords, isNot(contains('TROIE')));
    expect(itGlosses['ESSERE'], 'to be');
    expect(itGlosses['QUESTO'], 'this, these');
    expect(itGlosses['GRAZIE'], contains('thank'));
    expect(itGlosses['PERCHE'], 'because, why');
    expect(itGlosses['CITTA'], 'town, city');
    expect(itGlosses['VOGLIO'], 'Forma di volere: to want');
    expect(GameLocale.it.toUpper('città'), 'CITTA');
    expect(GameLocale.it.writtenUpper('città'), 'CITTÀ');
    for (final word in itFrequencyWords) {
      expect(GameLocale.it.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.it.letterCount(word), inInclusiveRange(5, 7), reason: word);
      expect(itGlosses[word], isNotNull, reason: word);
      expect(itGlosses[word], isNot('Parola italiana.'), reason: word);
    }
  });
}
