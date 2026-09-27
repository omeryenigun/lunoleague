import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';
import 'package:kelimelig/features/game/presentation/widgets/guess_board.dart';
import 'package:kelimelig/features/game/presentation/widgets/turkish_keyboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secret = 'KALEM';
  const engine = WordMatchingEngine();

  testWidgets('mobil oyun kareleri', (tester) async {
    final font = File(r'C:\Windows\Fonts\segoeui.ttf');
    final bytes = ByteData.view(Uint8List.fromList(font.readAsBytesSync()).buffer);
    final loader = FontLoader('Segoe UI')..addFont(Future<ByteData>.value(bytes));
    await loader.load();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final first = engine.evaluate('KELAM', secret, locale: GameLocale.tr);
    final win = engine.evaluate(secret, secret, locale: GameLocale.tr);
    final keys = <String, LetterStatus>{
      for (var i = 0; i < first.guess.length; i++)
        first.guess[i]: first.statuses[i],
    };

    await tester.pumpWidget(
      _frame(
        title: 'DAILY',
        attempt: '2/6',
        guesses: [first],
        input: const ['T', 'A'],
        keys: keys,
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/luno_play.png'),
    );

    await tester.pumpWidget(
      _frame(
        title: 'DAILY',
        attempt: '3/6',
        guesses: [first, win],
        input: const [],
        keys: {
          ...keys,
          for (var i = 0; i < win.guess.length; i++) win.guess[i]: win.statuses[i],
        },
        banner: 'KAZANDIN',
      ),
    );
    await tester.pump();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/luno_win.png'),
    );
  });
}

Widget _frame({
  required String title,
  required String attempt,
  required List<EvaluatedGuess> guesses,
  required List<String> input,
  required Map<String, LetterStatus> keys,
  String? banner,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Segoe UI'),
    home: Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  Text(
                    attempt,
                    style: const TextStyle(
                      color: AppColors.cosmicTeal,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            if (banner != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 4),
                child: Text(
                  banner,
                  style: const TextStyle(
                    color: AppColors.cosmicGreen,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GuessBoard(
                    wordLength: 5,
                    maxAttempts: 6,
                    guesses: guesses,
                    currentInput: input,
                    revealed: const {},
                    currentAttempt: guesses.length,
                    animateLast: false,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
              child: TurkishKeyboard(
                locale: GameLocale.tr,
                states: keys,
                onLetter: (_) {},
                onEnter: () {},
                onBackspace: () {},
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
