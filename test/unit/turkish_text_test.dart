import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';

void main() {
  test('i becomes İ, ı becomes I', () {
    expect(TurkishText.toUpper('istanbul'), 'İSTANBUL');
    expect(TurkishText.toUpper('ılık'), 'ILIK');
  });

  test('dotted pairs stay distinct', () {
    expect(TurkishText.equals('I', 'İ'), isFalse);
    expect(TurkishText.equals('O', 'Ö'), isFalse);
    expect(TurkishText.equals('U', 'Ü'), isFalse);
    expect(TurkishText.equals('C', 'Ç'), isFalse);
    expect(TurkishText.equals('G', 'Ğ'), isFalse);
    expect(TurkishText.equals('S', 'Ş'), isFalse);
  });

  test('letter count uses runes', () {
    expect(TurkishText.letterCount('çiçek'), 5);
    expect(TurkishText.letterCount('öğrenci'), 7);
    expect(TurkishText.letterCount('güneş'), 5);
  });

  test('allowed alphabet', () {
    expect(TurkishText.isAllowedWord('KELİME'), isTrue);
    expect(TurkishText.isAllowedWord('WORD'), isFalse);
    expect(TurkishText.isAllowedWord('Q'), isFalse);
  });
}
