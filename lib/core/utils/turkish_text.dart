import 'package:kelimelig/core/constants/app_constants.dart';

class TurkishText {
  static const _alphabetSet = {
    'A', 'B', 'C', 'Ç', 'D', 'E', 'F', 'G', 'Ğ', 'H', 'I', 'İ', 'J', 'K', 'L',
    'M', 'N', 'O', 'Ö', 'P', 'R', 'S', 'Ş', 'T', 'U', 'Ü', 'V', 'Y', 'Z',
  };

  static String normalize(String input) {
    var s = input.trim();
    s = s.replaceAll('\u0307', '').replaceAll('\u0308', '');
    s = s.replaceAll('i\u0307', 'i').replaceAll('I\u0307', 'İ');
    s = s.replaceAll('u\u0308', 'ü').replaceAll('U\u0308', 'Ü');
    s = s.replaceAll('o\u0308', 'ö').replaceAll('O\u0308', 'Ö');
    s = s.replaceAll('g\u0306', 'ğ').replaceAll('G\u0306', 'Ğ');
    s = s.replaceAll('s\u0327', 'ş').replaceAll('S\u0327', 'Ş');
    s = s.replaceAll('c\u0327', 'ç').replaceAll('C\u0327', 'Ç');
    return s;
  }

  static String toUpper(String input) {
    final n = normalize(input);
    final buf = StringBuffer();
    for (final rune in n.runes) {
      final ch = String.fromCharCode(rune);
      buf.write(switch (ch) {
        'i' => 'İ',
        'ı' => 'I',
        'ş' => 'Ş',
        'ğ' => 'Ğ',
        'ü' => 'Ü',
        'ö' => 'Ö',
        'ç' => 'Ç',
        _ => ch.toUpperCase(),
      });
    }
    return buf.toString();
  }

  static List<String> letters(String input) {
    return toUpper(input).characters;
  }

  static int letterCount(String input) => letters(input).length;

  static bool isAllowedLetter(String letter) =>
      _alphabetSet.contains(toUpper(letter));

  static bool isAllowedWord(String word) {
    final ls = letters(word);
    if (ls.isEmpty) return false;
    return ls.every(_alphabetSet.contains);
  }

  static bool equals(String a, String b) => toUpper(a) == toUpper(b);
}

extension on String {
  List<String> get characters =>
      runes.map(String.fromCharCode).toList(growable: false);
}

bool isTurkishAlphabetChar(String letter) =>
    AppConstants.turkishAlphabet.contains(TurkishText.toUpper(letter));
