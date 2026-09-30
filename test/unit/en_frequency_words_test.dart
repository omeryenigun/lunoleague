import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/en_frequency_words.dart';
import 'package:kelimelig/data/local/en_glosses.dart';

const _blocked = {
  'BITCH',
  'FUCKER',
  'ASSHOLE',
  'PORNO',
  'NIGGER',
  'WANKER',
  'FAGGOT',
  'CUNTS',
};

void main() {
  test('English list is length 5-7, has glosses, and drops blocked swear tokens', () {
    expect(enFrequencyWords, contains('ABOUT'));
    expect(enFrequencyWords, contains('WORLD'));
    expect(enFrequencyWords, contains('SCHOOL'));
    expect(enFrequencyWords, contains('FRIEND'));
    expect(enFrequencyWords, contains('FAMILY'));
    expect(enFrequencyWords.length, greaterThan(10000));
    for (final bad in _blocked) {
      expect(enFrequencyWords, isNot(contains(bad)), reason: bad);
    }
    for (final word in enFrequencyWords) {
      expect(GameLocale.en.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.en.letterCount(word), inInclusiveRange(5, 7), reason: word);
      expect(enGlosses[word], isNotNull, reason: word);
      expect(enGlosses[word], isNotEmpty, reason: word);
    }
  });
}
