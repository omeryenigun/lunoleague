import 'package:kelimelig/core/utils/turkish_text.dart';

class GameLocale {
  const GameLocale({
    required this.id,
    required this.nativeName,
    required this.englishName,
    required this.alphabet,
    required this.keyboard,
  });

  final String id;
  final String nativeName;
  final String englishName;
  final String alphabet;
  final List<List<String>> keyboard;

  Set<String> get alphabetSet => alphabet.split('').toSet();

  static const tr = GameLocale(
    id: 'tr',
    nativeName: 'Türkçe',
    englishName: 'Turkish',
    alphabet: 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ',
    keyboard: [
      ['E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P', 'Ğ', 'Ü'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ş', 'İ'],
      ['Z', 'C', 'V', 'B', 'N', 'M', 'Ö', 'Ç'],
    ],
  );

  static const en = GameLocale(
    id: 'en',
    nativeName: 'English',
    englishName: 'English',
    alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    keyboard: [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ],
  );

  static const all = <GameLocale>[tr, en];

  static GameLocale resolve(String? id) {
    for (final locale in all) {
      if (locale.id == id) return locale;
    }
    return tr;
  }

  String toUpper(String input) {
    if (id == 'tr') return TurkishText.toUpper(input);
    return input.trim().toUpperCase();
  }

  List<String> letters(String input) =>
      toUpper(input).runes.map(String.fromCharCode).toList(growable: false);

  int letterCount(String input) => letters(input).length;

  bool isAllowedLetter(String letter) => alphabetSet.contains(toUpper(letter));

  bool isAllowedWord(String word) {
    final ls = letters(word);
    return ls.isNotEmpty && ls.every(alphabetSet.contains);
  }

  bool equals(String a, String b) => toUpper(a) == toUpper(b);
}
