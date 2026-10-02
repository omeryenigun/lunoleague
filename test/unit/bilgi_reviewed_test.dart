import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

void main() {
  test('reviewed defaults to false when the key is missing and toMap writes it back', () {
    final legacy = BilgiQuestion.fromMap({
      'id': 'q1',
      'categoryId': 'genel',
      'text': 'Soru',
      'options': ['A', 'B', 'C', 'D'],
      'correct': 0,
      'difficulty': 'kolay',
      'explanation': '',
      'status': 'approved',
    });
    expect(legacy.reviewed, isFalse);
    expect(legacy.toMap()['reviewed'], isFalse);
    expect(BilgiQuestion.fromMap(legacy.toMap()).reviewed, isFalse);

    final checked = legacy.copyWith(reviewed: true);
    expect(checked.toMap()['reviewed'], isTrue);
    expect(BilgiQuestion.fromMap(checked.toMap()).reviewed, isTrue);
  });
}
