import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';

class EvaluatedGuess {
  const EvaluatedGuess({
    required this.guess,
    required this.statuses,
  });

  final String guess;
  final List<LetterStatus> statuses;

  bool get isWin => statuses.every((s) => s == LetterStatus.correct);
}

class WordMatchingEngine {
  const WordMatchingEngine();

  EvaluatedGuess evaluate(
    String guess,
    String secret, {
    GameLocale locale = GameLocale.tr,
  }) {
    final g = locale.letters(guess);
    final s = locale.letters(secret);
    if (g.length != s.length) {
      throw ArgumentError('Guess and secret must have the same length.');
    }

    final result = List<LetterStatus>.filled(g.length, LetterStatus.absent);
    final remaining = <String, int>{};
    for (final letter in s) {
      remaining[letter] = (remaining[letter] ?? 0) + 1;
    }

    for (var i = 0; i < g.length; i++) {
      if (g[i] == s[i]) {
        result[i] = LetterStatus.correct;
        remaining[g[i]] = remaining[g[i]]! - 1;
      }
    }

    for (var i = 0; i < g.length; i++) {
      if (result[i] == LetterStatus.correct) continue;
      final count = remaining[g[i]] ?? 0;
      if (count > 0) {
        result[i] = LetterStatus.present;
        remaining[g[i]] = count - 1;
      } else {
        result[i] = LetterStatus.absent;
      }
    }

    return EvaluatedGuess(guess: locale.toUpper(guess), statuses: result);
  }
}
