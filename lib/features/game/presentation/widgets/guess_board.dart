import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';
import 'package:kelimelig/features/game/presentation/widgets/letter_tile.dart';

class GuessBoard extends StatelessWidget {
  const GuessBoard({
    super.key,
    required this.wordLength,
    required this.maxAttempts,
    required this.guesses,
    required this.currentInput,
    required this.revealed,
    this.currentAttempt = 0,
    this.animateLast = false,
  });

  final int wordLength;
  final int maxAttempts;
  final List<EvaluatedGuess> guesses;
  final List<String> currentInput;
  final Map<int, String> revealed;
  final int currentAttempt;
  final bool animateLast;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 32;
        final gap = wordLength >= 7 ? 4.0 : (wordLength >= 6 ? 5.0 : 6.0);
        final size = ((maxW - gap * (wordLength - 1)) / wordLength)
            .clamp(26.0, 58.0)
            .toDouble();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(maxAttempts, (row) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: wordLength >= 7 ? 3 : 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var col = 0; col < wordLength; col++) ...[
                    if (col > 0) SizedBox(width: gap),
                    _tile(row, col, size),
                  ],
                ],
              ),
            );
          }),
        );
      },
    );
  }

  Widget _tile(int row, int col, double size) {
    var letter = '';
    var status = LetterStatus.empty;
    var flip = false;
    var active = false;
    var hinted = false;
    final activeRow = currentAttempt.clamp(guesses.length, maxAttempts);
    if (row < guesses.length) {
      letter = _charAt(guesses[row].guess, col);
      status = guesses[row].statuses[col];
      flip = animateLast && row == guesses.length - 1;
    } else if (row == activeRow && col < currentInput.length) {
      letter = currentInput[col];
      active = true;
    } else if (row == activeRow && revealed[col] != null) {
      letter = revealed[col]!;
      hinted = true;
    }
    return LetterTile(
      letter: letter,
      status: status,
      size: size,
      flip: flip,
      active: active,
      hinted: hinted,
      delay: Duration(milliseconds: 70 * col),
    );
  }

  String _charAt(String word, int index) {
    final runes = word.runes.map(String.fromCharCode).toList();
    if (index >= runes.length) return '';
    return runes[index];
  }
}
