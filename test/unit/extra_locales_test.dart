import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/data/local/seed_words_extra.dart';

void main() {
  test('new languages keep their own letters', () {
    expect(GameLocale.de.letterCount('straße'), 6);
    expect(GameLocale.de.isAllowedWord('bäckerei'), isTrue);
    expect(GameLocale.es.toUpper('montaña'), 'MONTAÑA');
    expect(GameLocale.es.letterCount('montaña'), 7);
    expect(GameLocale.fr.toUpper('école'), 'ECOLE');
    expect(GameLocale.it.toUpper('città'), 'CITTA');
    expect(GameLocale.ru.toUpper('ёлка'), 'ЁЛКА');
    expect(GameLocale.ru.letterCount('солнце'), 6);
    expect(GameLocale.pt.toUpper('coração'), 'CORACAO');
    expect(GameLocale.pt.writtenUpper('coração'), 'CORAÇÃO');
    expect(GameLocale.fr.writtenUpper('école'), 'ÉCOLE');
    expect(GameLocale.it.writtenUpper('città'), 'CITTÀ');
    expect(GameLocale.es.writtenUpper('cañón'), 'CAÑÓN');
    expect(GameLocale.es.toUpper('cañón'), 'CAÑON');
    expect(GameLocale.de.toUpper('straße'), 'STRAẞE');
    expect(GameLocale.de.toUpper('äöü'), 'ÄÖÜ');
    expect(GameLocale.pl.toUpper('łódź'), 'ŁÓDŹ');
    expect(GameLocale.ru.toUpper('ё'), 'Ё');
    expect(GameLocale.nl.isAllowedWord('school'), isTrue);
    expect(GameLocale.known('ru'), isTrue);
    expect(GameLocale.resolve('xx').id, 'tr');
    for (final locale in [GameLocale.ru, GameLocale.nl, GameLocale.pt, GameLocale.pl]) {
      final keys = locale.keyboard.expand((row) => row);
      for (final key in keys) {
        expect(locale.alphabetSet.contains(key), isTrue, reason: '${locale.id} $key');
      }
    }
  });

  test('starter words are playable in each new language', () {
    final words = buildExtraLocaleWords();
    for (final id in ['de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl']) {
      final mine = words.where((word) => word.language == id).toList();
      expect(mine, isNotEmpty);
      for (final length in [5, 6, 7]) {
        expect(mine.where((word) => word.length == length), isNotEmpty);
      }
      for (final word in mine) {
        final locale = GameLocale.resolve(id);
        expect(locale.isAllowedWord(word.word), isTrue);
        expect(word.length, inInclusiveRange(5, 7));
      }
    }
  });

  test('new language screens use their own copy', () {
    final l10n = L10n()..id = 'de';
    expect(l10n.t('endless'), 'Wortmarathon');
    l10n.id = 'es';
    expect(l10n.t('endless'), 'Maratón de palabras');
    l10n.id = 'fr';
    expect(l10n.t('home'), 'Accueil');
    l10n.id = 'it';
    expect(l10n.t('league'), 'Lega');
    l10n.id = 'ru';
    expect(l10n.t('endless'), 'Словесный марафон');
    l10n.id = 'nl';
    expect(l10n.t('home'), 'Home');
    l10n.id = 'pt';
    expect(l10n.t('league'), 'Liga');
    l10n.id = 'pl';
    expect(l10n.t('endless'), 'Maraton słów');
    l10n.id = 'tr';
    expect(l10n.t('endless'), 'Kelime Maratonu');
    expect(l10n.t('endless_home'), 'KELİME MARATONU');
  });
}
