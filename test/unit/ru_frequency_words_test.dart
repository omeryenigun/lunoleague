import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/data/local/ru_frequency_words.dart';
import 'package:kelimelig/data/local/ru_glosses.dart';

void main() {
  test('Russian list keeps yo and skips swears', () {
    expect(ruFrequencyWords, contains('ГОРОД'));
    expect(ruFrequencyWords, contains('РОССИЯ'));
    expect(ruFrequencyWords, contains('СЕЙЧАС'));
    expect(ruFrequencyWords, contains('СЕРДЦЕ'));
    expect(ruFrequencyWords, contains('РЕБЁНОК'));
    expect(ruFrequencyWords, contains('ПЕДИКЮР'));
    expect(ruFrequencyWords, isNot(contains('ХУЙ')));
    expect(ruFrequencyWords, isNot(contains('БЛЯДЬ')));
    expect(ruFrequencyWords, isNot(contains('ПИЗДА')));
    expect(ruFrequencyWords, isNot(contains('МУДАК')));
    expect(ruFrequencyWords, isNot(contains('ЕБАНЫЙ')));
    expect(ruFrequencyWords, isNot(contains('ПЕДИК')));
    expect(ruFrequencyWords, isNot(contains('ПОРНО')));
    expect(ruGlosses['ГОРОД'], contains('пункт'));
    expect(ruGlosses['СЕЙЧАС'], contains('момент'));
    expect(GameLocale.ru.toUpper('ёлка'), 'ЁЛКА');
    expect(GameLocale.ru.toUpper('ребёнок'), 'РЕБЁНОК');
    expect(GameLocale.ru.toUpper('елка'), 'ЕЛКА');
    for (final word in ruFrequencyWords) {
      expect(GameLocale.ru.isAllowedWord(word), isTrue, reason: word);
      expect(GameLocale.ru.letterCount(word), inInclusiveRange(5, 7), reason: word);
      if (word.contains('Ё')) {
        expect(word.replaceAll('Ё', 'Е'), isNot(word), reason: word);
      }
      final gloss = ruGlosses[word];
      expect(gloss, isNotNull, reason: word);
      expect(gloss!.trim(), isNotEmpty, reason: word);
      expect(gloss, isNot(contains('Русское слово')));
    }
  });
}
