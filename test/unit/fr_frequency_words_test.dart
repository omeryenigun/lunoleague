import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/fr_frequency_words.dart';
import 'package:kelimelig/data/local/fr_glosses.dart';

void main() {
  test('French list folds accents and has a real gloss', () {
    expect(frFrequencyWords, contains('ECOLE'));
    expect(frFrequencyWords, contains('MERCI'));
    expect(frFrequencyWords, isNot(contains('PUTES')));
    expect(frFrequencyWords, isNot(contains('MERDES')));
    expect(frGlosses['ETAIT'], 'Forme de être: to be');
    expect(frGlosses['FAIRE'], 'to do');
    expect(frGlosses['AVOIR'], 'to have');
    expect(frGlosses['MERCI'], 'thank you');
    expect(frGlosses['ECOLE'], 'school');
    expect(GameLocale.fr.toUpper('école'), 'ECOLE');
    expect(GameLocale.fr.writtenUpper('école'), 'ÉCOLE');
    for (final word in frFrequencyWords) {
      expect(GameLocale.fr.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.fr.letterCount(word), inInclusiveRange(5, 7), reason: word);
      expect(frGlosses[word], isNotNull, reason: word);
      expect(frGlosses[word], isNot('Mot français.'), reason: word);
    }
  });
}
