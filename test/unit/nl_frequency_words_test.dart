import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/nl_frequency_words.dart';
import 'package:kelimelig/data/local/nl_glosses.dart';
import 'package:kelimelig/data/local/nl_profanity_words.dart';

const _blocked = {
  'NEUKEN',
  'KLOTEN',
  'FLIKKER',
  'SCHIJT',
  'STRONT',
  'PORNO',
};

void main() {
  test('Dutch list is length 5-7, has glosses, and drops blocked swear tokens', () {
    expect(nlFrequencyWords, contains('GROOT'));
    expect(nlFrequencyWords, contains('VRIEND'));
    expect(nlFrequencyWords, contains('SCHOOL'));
    expect(nlFrequencyWords, contains('WERELD'));
    expect(nlFrequencyWords, contains('FAMILIE'));
    expect(nlFrequencyWords.length, greaterThan(8000));
    for (final bad in {..._blocked, ...nlProfanity}) {
      expect(nlFrequencyWords, isNot(contains(bad)), reason: bad);
    }
    for (final word in nlFrequencyWords) {
      expect(GameLocale.nl.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.nl.letterCount(word), inInclusiveRange(5, 7), reason: word);
      expect(nlGlosses[word], isNotNull, reason: word);
      expect(nlGlosses[word], isNotEmpty, reason: word);
    }
  });
}
