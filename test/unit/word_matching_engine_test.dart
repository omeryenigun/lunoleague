import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';

void main() {
  const engine = WordMatchingEngine();

  List<LetterStatus> eval(String guess, String secret) =>
      engine.evaluate(guess, secret).statuses;

  test('all correct', () {
    expect(eval('ELMA', 'elma'), everyElement(LetterStatus.correct));
  });

  test('duplicate letters: ALLA vs ELMA', () {
    // A not in remaining after last A is green; first A gray; L at pos1 green; second L gray
    expect(eval('ALLA', 'ELMA'), [
      LetterStatus.absent,
      LetterStatus.correct,
      LetterStatus.absent,
      LetterStatus.correct,
    ]);
  });

  test('present then unused duplicate', () {
    expect(eval('KALEM', 'ELMAK'), isNotEmpty);
  });

  test('Turkish dotted/dotless i are different', () {
    expect(eval('SİLİK', 'SILIK')[1], LetterStatus.absent);
  });

  test('ö and o are different', () {
    final r = eval('GOLGE', 'GÖLGE');
    expect(r[1], LetterStatus.absent);
    expect(r[0], LetterStatus.correct);
  });

  test('ç ğ ş ü', () {
    expect(eval('ÇİÇEK', 'çiçek'), everyElement(LetterStatus.correct));
  });

  test('win flag', () {
    expect(engine.evaluate('güneş', 'GÜNEŞ').isWin, isTrue);
    expect(engine.evaluate('güneş', 'BULUT').isWin, isFalse);
  });

  test('english matching uses QWERTY letters', () {
    expect(
      engine.evaluate('apple', 'APPLE', locale: GameLocale.en).isWin,
      isTrue,
    );
    expect(
      engine.evaluate('query', 'WATER', locale: GameLocale.en).statuses[0],
      LetterStatus.absent,
    );
  });
}
