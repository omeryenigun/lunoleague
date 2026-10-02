import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_contest.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';

BilgiBoardEntry _player(String id, int score) => BilgiBoardEntry(
      id: id,
      name: id,
      avatar: '😎',
      score: score,
      seed: false,
    );

void main() {
  test('daily board keeps real scores above zero-point seeds', () {
    final board = bilgiDailyBoard([
      _player('low', 10),
      _player('high', 80),
    ]);
    expect(board, hasLength(100));
    expect(board.first.id, 'high');
    expect(board.first.rank, 1);
    expect(board[1].id, 'low');
    expect(board[1].score, 10);
    expect(board[2].seed, isTrue);
    expect(board[2].score, 0);
    expect(board.last.seed, isTrue);
  });

  test('a full real board does not add seeds', () {
    final board = bilgiDailyBoard([
      for (var i = 0; i < 100; i++) _player('p$i', 100 - i),
    ]);
    expect(board, hasLength(100));
    expect(board.every((row) => !row.seed), isTrue);
    expect(board.first.score, 100);
  });

  test('contest gold and xp stay capped', () {
    expect(bilgiContestGold(0), 0);
    expect(bilgiContestGold(10), 100);
    expect(bilgiContestGold(20), 200);
    expect(bilgiContestGold(40), 200);
    expect(bilgiContestXp(0), 0);
    expect(bilgiContestXp(20), 100);
    expect(bilgiContestXp(40), 100);
  });

  test('a month lists every calendar day', () {
    expect(bilgiContestMonthDays('2026-02'), hasLength(28));
    expect(bilgiContestMonthDays('2024-02'), hasLength(29));
    expect(bilgiContestMonthDays('2026-10').first, '2026-10-01');
    expect(bilgiContestMonthDays('2026-10').last, '2026-10-31');
    expect(bilgiContestMonthDays('nope'), isEmpty);
  });

  test('a daily question must be filled in every published language', () {
    const english = BilgiTranslation(text: 'Q', options: ['A', 'B', 'C', 'D'], explanation: 'Because');
    const question = BilgiQuestion(
      id: 'q1',
      categoryId: 'felsefe',
      text: 'Soru',
      options: ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'kolay',
      explanation: 'Çünkü',
      translations: {'en': english},
    );
    const englishOnly = BilgiCategory(
      id: 'felsefe',
      group: 'kultur',
      name: 'Felsefe',
      emoji: '🧘',
      subs: const ['Etik'],
      locales: ['tr', 'en'],
    );
    const everyLanguage = BilgiCategory(
      id: 'felsefe',
      group: 'kultur',
      name: 'Felsefe',
      emoji: '🧘',
      subs: const ['Etik'],
    );
    expect(bilgiQuestionLanguagesReady(question, locales: englishOnly.publishLocales), isTrue);
    expect(bilgiQuestionLanguagesReady(question, locales: everyLanguage.publishLocales), isFalse);
  });

  test('countdown reaches the next Istanbul midnight', () {
    final now = DateTime.utc(2026, 10, 2, 20, 30);
    final left = bilgiContestRemaining(now);
    expect(left, const Duration(minutes: 30));
    expect(bilgiContestClock(left), '00:30:00');
  });
}
