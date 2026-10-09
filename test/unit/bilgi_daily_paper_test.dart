import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_daily_paper.dart';

void main() {
  test('AI papers start on 9 October 2026', () {
    expect(bilgiContestAiDay('2026-10-08'), isFalse);
    expect(bilgiContestAiDay('2026-10-09'), isTrue);
    expect(bilgiContestAiDay('2026-10-10'), isTrue);
  });

  test('a balanced paper is accepted and stamped', () {
    final parsed = bilgiDailyPaperFromModel(
      {
        'questions': _rows(_paperPlan, 'k'),
        'spares': _rows(const ['kolay', 'kolay', 'kolay', 'orta', 'orta', 'orta', 'zor', 'zor', 'zor', 'efsane', 'efsane'], 'y'),
      },
      day: '2026-10-09',
    );
    expect(parsed.error, isNull, reason: parsed.error);
    expect(parsed.questions, hasLength(20));
    expect(parsed.spares, hasLength(11));
    expect(parsed.questions.first['id'], 'gun20261009p01');
    expect(parsed.questions.last['difficulty'], 'efsane');
    expect(parsed.spares.first['id'], 'gun20261009y01');
    expect(parsed.questions.first['tags'], ['Günlük', 'bilim']);
  });

  test('a leaked hint and a missing finale are rejected', () {
    final questions = _rows(_paperPlan, 'k');
    questions[0]['hint'] = 'Doğru şık Pasifik Okyanusu diye bilinir.';
    questions[0]['options'] = ['Pasifik Okyanusu', 'Atlas Okyanusu', 'Hint Okyanusu', 'Arktik Okyanus'];
    questions[0]['correct'] = 0;
    expect(
      bilgiDailyPaperError(questions: questions, spares: _rows(_sparePlan, 'y')),
      contains('ipucu doğru şıkkı'),
    );

    final early = _rows(_paperPlan, 'f');
    early[19]['difficulty'] = 'zor';
    early[5]['difficulty'] = 'efsane';
    expect(
      bilgiDailyPaperError(questions: early, spares: _rows(_sparePlan, 'z')),
      '20. soru efsane olmalı.',
    );
  });

  test('a scrambled paper is repaired before it is rejected', () {
    final questions = _rows(_paperPlan.reversed.toList(), 'k');
    for (final row in questions) {
      row['correct'] = 0;
      row['hint'] = 'Doğru cevap ${row['options'][0]} diye geçer.';
    }
    final parsed = bilgiDailyPaperFromModel(
      {'questions': questions, 'spares': _rows(_sparePlan, 'y')},
      day: '2026-10-09',
    );
    expect(parsed.error, isNull, reason: parsed.error);
    expect(parsed.questions.first['difficulty'], isNot('zor'));
    expect(parsed.questions.first['difficulty'], isNot('efsane'));
    expect(parsed.questions[19]['difficulty'], 'efsane');
    final other = parsed.questions.indexWhere((row) => row['difficulty'] == 'efsane');
    expect(other, greaterThanOrEqualTo(10));
    for (final row in [...parsed.questions, ...parsed.spares]) {
      final answer = bilgiDailyFold('${(row['options'] as List)[row['correct']]}');
      expect(bilgiDailyFold('${row['hint']}').contains(answer), isFalse);
    }
  });

  test('a fact already used in the month is rejected', () {
    final questions = _rows(_paperPlan, 'k');
    final key = bilgiDailyFold('${questions[4]['text']}');
    expect(
      bilgiDailyPaperError(
        questions: questions,
        spares: _rows(_sparePlan, 'y'),
        avoid: {key},
      ),
      contains('zaten kullanıldı'),
    );
  });

  test('a repeated fact is dropped and the paper still has 20 questions', () {
    final questions = _rows(_paperPlan, 'k');
    final key = bilgiDailyFold('${questions[4]['text']}');
    final parsed = bilgiDailyPaperFromModel(
      {'questions': questions, 'spares': _rows(_sparePlan, 'y')},
      day: '2026-10-10',
      avoid: {key},
    );
    expect(parsed.error, isNull, reason: parsed.error);
    expect(parsed.questions, hasLength(20));
    expect(parsed.questions.any((row) => bilgiDailyFold('${row['text']}') == key), isFalse);
  });
}

const _paperPlan = bilgiDailyPlayOrder;

const _sparePlan = ['kolay', 'kolay', 'kolay', 'orta', 'orta', 'orta', 'zor', 'zor', 'zor', 'efsane', 'efsane'];

List<Map<String, dynamic>> _rows(List<String> plan, String prefix) {
  final used = <String, int>{};
  return [
    for (var i = 0; i < plan.length; i++)
      {
        'text': '$prefix soru ${i + 1} hangi olguyu anlatır?',
        'options': [
          '$prefix alfa ${i + 1}',
          '$prefix beta ${i + 1}',
          '$prefix gama ${i + 1}',
          '$prefix delta ${i + 1}',
        ],
        'correct': ((used[plan[i]] = (used[plan[i]] ?? 0) + 1) - 1) % 4,
        'difficulty': plan[i],
        'topic': i.isEven ? 'bilim' : 'tarih',
        'hint': '$prefix ipucu ${i + 1} doğru seçeneğin konusunu açar.',
        'explanation': '$prefix açıklama ${i + 1} bu olgunun nedenini söyler.',
      },
  ];
}
