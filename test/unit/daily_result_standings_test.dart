import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/features/game/presentation/widgets/daily_result_standings.dart';

void main() {
  test('masks every word of another player name', () {
    expect(maskPlayerName('Selim Yılmaz'), 'S** Y**');
    expect(maskPlayerName('ayşe'), 'A**');
    expect(maskPlayerName('  Can  Demir  '), 'C** D**');
  });

  test('keeps the current user name and pads seeds to 50', () {
    final board = fillDailyDisplayBoard(
      apiRows: const [
        ResultPlace(
          rank: 1,
          displayName: 'Ömer Aydın',
          score: '2',
          isCurrentUser: true,
        ),
      ],
      playerName: 'Ömer Aydın',
      playerWon: true,
      playerGuesses: 2,
      seedKey: 'word-verim',
    );
    expect(board, hasLength(50));
    final me = board.singleWhere((row) => row.player.isMe);
    expect(me.player.name, 'Ömer Aydın');
    expect(me.player.guesses, 2);
    expect(dailyBoardDisplayName(me.player), 'Ömer Aydın');
    expect(
      board.where((row) => !row.player.isMe).every(
            (row) => dailyBoardDisplayName(row.player).contains('**'),
          ),
      isTrue,
    );
    expect(
      board.where((row) => !row.player.isMe).any(
            (row) => dailyBoardDisplayName(row.player) == row.player.name,
          ),
      isFalse,
    );
  });

  test('ranks a miss below solves and fewer guesses higher', () {
    final board = fillDailyDisplayBoard(
      apiRows: const [
        ResultPlace(
          rank: 1,
          displayName: 'Hızlı',
          score: '1',
          isCurrentUser: false,
        ),
        ResultPlace(
          rank: 2,
          displayName: 'Oyuncu',
          score: '—',
          isCurrentUser: true,
        ),
      ],
      playerName: 'Oyuncu',
      playerWon: false,
      playerGuesses: 6,
      seedKey: 'word-miss',
    );
    final me = board.singleWhere((row) => row.player.isMe);
    final firstSolve = board.firstWhere((row) => row.player.name == 'Hızlı');
    expect(firstSolve.rank, 1);
    expect(me.player.won, isFalse);
    expect(me.rank, greaterThan(firstSolve.rank));
    final lastSolve = board.lastWhere((row) => row.player.won);
    expect(me.rank, greaterThan(lastSolve.rank));
  });
}
