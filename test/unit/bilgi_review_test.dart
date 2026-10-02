import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_review.dart';

void main() {
  test('keep decision reads the difficulty and clears the reason', () {
    final decision = bilgiParseReview('{"verdict":"keep","difficulty":"orta","reason":""}');
    expect(decision, isNotNull);
    expect(decision!.keep, isTrue);
    expect(decision.difficulty, 'orta');
    expect(decision.reason, isEmpty);
    final applied = bilgiApplyReview(currentDifficulty: 'kolay', currentStatus: 'approved', decision: decision);
    expect(applied.difficulty, 'orta');
    expect(applied.status, 'approved');
    expect(applied.rejectReason, isEmpty);
  });

  test('reject decision keeps the difficulty and stores the reason', () {
    final decision = bilgiParseReview(
      '{"verdict":"reject","difficulty":"efsane","reason":"Doğru şık metinle uyuşmuyor."}',
    );
    expect(decision, isNotNull);
    expect(decision!.keep, isFalse);
    expect(decision.reason, 'Doğru şık metinle uyuşmuyor.');
    final applied = bilgiApplyReview(currentDifficulty: 'orta', currentStatus: 'approved', decision: decision);
    expect(applied.difficulty, 'orta');
    expect(applied.status, 'rejected');
    expect(applied.rejectReason, 'Doğru şık metinle uyuşmuyor.');
  });

  test('broken JSON is not a decision', () {
    expect(bilgiParseReview('karar verilemedi'), isNull);
    expect(bilgiParseReview('{"verdict":"keep"'), isNull);
    expect(bilgiParseReview('{"verdict":"maybe","difficulty":"kolay","reason":""}'), isNull);
  });

  test('a difficulty outside the four levels is not a decision', () {
    expect(
      bilgiParseReview('{"verdict":"keep","difficulty":"imkansiz","reason":""}'),
      isNull,
    );
    expect(
      bilgiParseReview('{"verdict":"reject","difficulty":"cok zor","reason":"Bozuk."}'),
      isNull,
    );
  });
}
