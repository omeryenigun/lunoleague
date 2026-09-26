import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/de_frequency_words.dart';
import 'package:kelimelig/data/local/de_glosses.dart';

void main() {
  test('German list keeps umlauts and eszett as one letter', () {
    expect(deFrequencyWords, isNotEmpty);
    expect(deFrequencyWords, contains('HEIẞT'));
    expect(GameLocale.de.letterCount('HEIẞT'), 5);
    expect(GameLocale.de.letterCount('STRAßE'.replaceAll('ß', 'ẞ')), 6);
    for (final word in deFrequencyWords) {
      expect(GameLocale.de.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.de.letterCount(word), inInclusiveRange(5, 7), reason: word);
      expect(word, GameLocale.de.writtenUpper(word), reason: word);
    }
  });

  test('German glosses are real senses', () {
    expect(deGlosses['HEIẞT'], 'Form von heißen: to have a name');
    expect(deGlosses['STRAẞE'], 'street');
    expect(deGlosses['HABEN'], 'to have');
    expect(deGlosses['NICHT'], contains('not'));
    expect(deGlosses.values, isNot(contains('Deutsches Wort.')));
    expect(deFrequencyWords, isNot(contains('CAPTAIN')));
    expect(deFrequencyWords, isNot(contains('BAELISH')));
    for (final word in deFrequencyWords) {
      expect(deGlosses[word], isNotNull, reason: word);
    }
  });
}
