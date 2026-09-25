import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';
import 'package:kelimelig/features/game/presentation/widgets/result_screen.dart';

void main() {
  const win = GameOutcome(
    won: true,
    word: 'KALEM',
    definition: 'Yazı aracı',
    exampleSentence: 'Kalemini aldı.',
    englishTranslation: 'pen',
    wordId: 'word_002',
    xpEarned: 130,
    coinEarned: 25,
    leaguePoints: 100,
    streak: 3,
    level: 1,
    guesses: 6,
    timeSpentSeconds: 84,
    unlockedAchievements: ['İlk Adım'],
    rankAfter: 4,
  );
  const guesses = [
    EvaluatedGuess(
      guess: 'KALEM',
      statuses: [
        LetterStatus.correct,
        LetterStatus.present,
        LetterStatus.absent,
        LetterStatus.correct,
        LetterStatus.correct,
      ],
    ),
  ];

  ResultPlace place(int rank, {bool mine = false}) => ResultPlace(
        rank: rank,
        displayName: mine ? 'Ben' : 'Oyuncu $rank',
        score: '$rank',
        isCurrentUser: mine,
      );

  test('result board shows top 10, then the player through 20, else a rank line', () {
    final inside = resultBoardLines([
      for (var rank = 1; rank <= 12; rank++) place(rank, mine: rank == 12),
    ]);
    expect(inside.rows.map((row) => row.rank), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12]);
    expect(inside.rankOnly, isNull);
    expect(inside.rows.last.isCurrentUser, isTrue);

    final outside = resultBoardLines([
      for (var rank = 1; rank <= 10; rank++) place(rank),
      place(47, mine: true),
    ]);
    expect(outside.rows, hasLength(10));
    expect(outside.rows.any((row) => row.isCurrentUser), isFalse);
    expect(outside.rankOnly, 47);

    final top = resultBoardLines([
      for (var rank = 1; rank <= 10; rank++) place(rank, mine: rank == 3),
    ]);
    expect(top.rows, hasLength(10));
    expect(top.rankOnly, isNull);
  });

  test('share text includes the win, score, and rewards', () {
    final text = buildShareText(
      l10n: L10n(),
      outcome: win,
      guesses: guesses,
      maxAttempts: 6,
      isDaily: true,
    );
    expect(text, contains('KAZANDIN!'));
    expect(text, contains('Kelimeyi 6. tahminde buldun'));
    expect(text, contains('Skor 6/6 · Süre 01:24'));
    expect(text, contains('XP +130 · Coin +25'));
    expect(text, contains('Lig puanı +100'));
    expect(text, contains('🔥 3 gün'));
    expect(text, contains('Lig #4'));
    expect(text, contains('Başarım: İlk Adım'));
    expect(text, contains('🟩🟨⬜🟩🟩'));
    expect(text, isNot(contains('KALEM')));
  });

  test('share text includes the loss', () {
    final text = buildShareText(
      l10n: L10n(),
      outcome: const GameOutcome(
        won: false,
        word: 'KALEM',
        definition: 'Yazı aracı',
        exampleSentence: 'Kalemini aldı.',
        englishTranslation: 'pen',
        wordId: 'word_002',
        xpEarned: 0,
        coinEarned: 0,
        leaguePoints: 10,
        streak: 0,
        level: 1,
        guesses: 6,
        timeSpentSeconds: 9,
        unlockedAchievements: [],
      ),
      guesses: guesses,
      maxAttempts: 6,
      isDaily: true,
    );
    expect(text, contains('KAYBETTİN'));
    expect(text, contains('Bu sefer olmadı, yarın tekrar dene'));
    expect(text, contains('Skor 6/6 · Süre 00:09'));
    expect(text, contains('Lig puanı +10'));
    expect(text, isNot(contains('KALEM')));
  });
}
