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

  static const de = GameLocale(
    id: 'de',
    nativeName: 'Deutsch',
    englishName: 'German',
    alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜẞ',
    keyboard: [
      ['Q', 'W', 'E', 'R', 'T', 'Z', 'U', 'I', 'O', 'P', 'Ü'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ö', 'Ä'],
      ['Y', 'X', 'C', 'V', 'B', 'N', 'M', 'ẞ'],
    ],
  );

  static const es = GameLocale(
    id: 'es',
    nativeName: 'Español',
    englishName: 'Spanish',
    alphabet: 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ',
    keyboard: [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ñ'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ],
  );

  static const fr = GameLocale(
    id: 'fr',
    nativeName: 'Français',
    englishName: 'French',
    alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    keyboard: [
      ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M'],
      ['W', 'X', 'C', 'V', 'B', 'N'],
    ],
  );

  static const it = GameLocale(
    id: 'it',
    nativeName: 'Italiano',
    englishName: 'Italian',
    alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    keyboard: [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ],
  );

  static const ru = GameLocale(
    id: 'ru',
    nativeName: 'Русский',
    englishName: 'Russian',
    alphabet: 'АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ',
    keyboard: [
      ['Й', 'Ц', 'У', 'К', 'Е', 'Н', 'Г', 'Ш', 'Щ', 'З', 'Х', 'Ъ'],
      ['Ф', 'Ы', 'В', 'А', 'П', 'Р', 'О', 'Л', 'Д', 'Ж', 'Э'],
      ['Я', 'Ч', 'С', 'М', 'И', 'Т', 'Ь', 'Б', 'Ю', 'Ё'],
    ],
  );

  static const nl = GameLocale(
    id: 'nl',
    nativeName: 'Nederlands',
    englishName: 'Dutch',
    alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    keyboard: [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ],
  );

  static const pt = GameLocale(
    id: 'pt',
    nativeName: 'Português',
    englishName: 'Portuguese',
    alphabet: 'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    keyboard: [
      ['Q', 'W', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
      ['A', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L'],
      ['Z', 'X', 'C', 'V', 'B', 'N', 'M'],
    ],
  );

  static const pl = GameLocale(
    id: 'pl',
    nativeName: 'Polski',
    englishName: 'Polish',
    alphabet: 'AĄBCĆDEĘFGHIJKLŁMNŃOÓPRSŚTUWXYZŹŻ',
    keyboard: [
      ['W', 'E', 'Ę', 'R', 'T', 'Y', 'U', 'I', 'O', 'Ó', 'P'],
      ['A', 'Ą', 'S', 'Ś', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'Ł'],
      ['Z', 'Ź', 'Ż', 'C', 'Ć', 'B', 'N', 'Ń', 'M'],
    ],
  );

  static const all = <GameLocale>[tr, en, de, es, fr, it, ru, nl, pt, pl];

  static bool known(String? id) => all.any((locale) => locale.id == id);

  static GameLocale resolve(String? id) {
    for (final locale in all) {
      if (locale.id == id) return locale;
    }
    return tr;
  }

  String get guestPrefix => switch (id) {
        'en' => 'Guest',
        'de' => 'Gast',
        'es' => 'Invitado',
        'fr' => 'Invite',
        'it' => 'Ospite',
        'ru' => 'Гость',
        'nl' => 'Gast',
        'pt' => 'Convidado',
        'pl' => 'Gość',
        _ => 'Misafir',
      };

  String get playerName => switch (id) {
        'en' => 'Player',
        'de' => 'Spieler',
        'es' => 'Jugador',
        'fr' => 'Joueur',
        'it' => 'Giocatore',
        'ru' => 'Игрок',
        'nl' => 'Speler',
        'pt' => 'Jogador',
        'pl' => 'Gracz',
        _ => 'Oyuncu',
      };

  /// Letters used for guesses, coloring and dictionary match.
  /// Stress marks fold. Alphabet letters stay: ñ, ä, ö, ü, ł, ё, ß.
  String toUpper(String input) {
    final text = writtenUpper(input);
    if (id == 'tr' || id == 'de' || id == 'pl' || id == 'ru') return text;
    final keep = id == 'es' ? 'Ñ' : null;
    final buffer = StringBuffer();
    for (final ch in text.runes.map(String.fromCharCode)) {
      if (ch == keep) {
        buffer.write(ch);
      } else {
        buffer.write(_folded[ch] ?? ch);
      }
    }
    return buffer.toString();
  }

  /// Spelling shown after the game. Accents stay. Case is still normalized.
  String writtenUpper(String input) {
    if (id == 'tr') return TurkishText.toUpper(input);
    var text = input.trim();
    if (id == 'de') text = text.replaceAll('ß', 'ẞ');
    return text.toUpperCase();
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

const _folded = <String, String>{
  'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
  'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
  'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
  'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O',
  'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
  'Ç': 'C', 'Ñ': 'N', 'Ý': 'Y', 'Ÿ': 'Y',
};
