import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/pl_frequency_words.dart';
import 'package:kelimelig/data/local/pl_glosses.dart';

/// Tokens from LDNOOBW (pl) plus extra vulgar forms filtered at import.
const _blocked = {
  'CHUJ',
  'CHUJOWO',
  'CIPA',
  'DEBIL',
  'DUPA',
  'DUPEK',
  'FIUT',
  'GÓWNO',
  'GOWNO',
  'HUJ',
  'JEBAĆ',
  'JEBAC',
  'JEBANY',
  'KURWA',
  'KURWY',
  'KUTAS',
  'PIERDOL',
  'PIZDA',
  'POJEB',
  'POJEBIE',
  'RUCHAĆ',
  'SKURWY',
  'SRAĆ',
  'SUKA',
  'SYF',
  'ZAJEBIE',
  'ZJEBIE',
};

void main() {
  test('Polish list is length 5-7, has glosses, and drops blocked swear tokens', () {
    expect(plFrequencyWords, contains('SZKOŁA'));
    expect(plFrequencyWords, contains('RODZINA'));
    expect(plFrequencyWords, contains('SŁOŃCE'));
    expect(plFrequencyWords, contains('BARDZO'));
    expect(plFrequencyWords, contains('KSIĄŻKA'));
    expect(plFrequencyWords, isNot(contains('PORNO')));
    for (final bad in _blocked) {
      expect(plFrequencyWords, isNot(contains(bad)), reason: bad);
    }
    for (final word in plFrequencyWords) {
      expect(GameLocale.pl.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.pl.letterCount(word), inInclusiveRange(5, 7), reason: word);
      expect(plGlosses[word], isNotNull, reason: word);
      expect(plGlosses[word], isNotEmpty, reason: word);
    }
  });
}
