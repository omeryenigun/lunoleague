import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/pt_frequency_words.dart';
import 'package:kelimelig/data/local/pt_glosses.dart';

void main() {
  test('Portuguese list folds accents and skips swears', () {
    expect(ptFrequencyWords, contains('NOITE'));
    expect(ptFrequencyWords, contains('CIDADE'));
    expect(ptFrequencyWords, contains('CORACAO'));
    expect(ptFrequencyWords, isNot(contains('CARALHO')));
    expect(ptFrequencyWords, isNot(contains('MERDA')));
    expect(ptFrequencyWords, isNot(contains('PORRA')));
    expect(ptFrequencyWords, isNot(contains('FODER')));
    expect(ptFrequencyWords, isNot(contains('BOCETA')));
    expect(ptGlosses['NOITE'], contains('dia'));
    expect(ptGlosses['CORACAO'], contains('sangue'));
    expect(GameLocale.pt.toUpper('coração'), 'CORACAO');
    expect(GameLocale.pt.toUpper('ação'), 'ACAO');
    for (final word in ptFrequencyWords) {
      expect(GameLocale.pt.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.pt.letterCount(word), inInclusiveRange(5, 7), reason: word);
      final gloss = ptGlosses[word];
      expect(gloss, isNotNull, reason: word);
      expect(gloss!.trim(), isNotEmpty, reason: word);
    }
  });
}
