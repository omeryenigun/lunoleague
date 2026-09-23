import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/features/word_book/presentation/word_card_screen.dart';

void main() {
  testWidgets('save button sits above the system navigation bar', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(bottom: 48);
    tester.view.viewPadding = const FakeViewPadding(bottom: 48);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);

    await tester.pumpWidget(
      MaterialApp(
        home: WordCardScreen(
          outcome: GameOutcome(
            won: true,
            word: 'KİRAZ',
            definition: 'Küçük kırmızı meyve.',
            exampleSentence: 'Kiraz mevsimi gelmişti.',
            englishTranslation: 'cherry',
            wordId: 'word_001',
            xpEarned: 0,
            coinEarned: 0,
            leaguePoints: 0,
            streak: 0,
            level: 1,
            guesses: 1,
            timeSpentSeconds: 1,
            unlockedAchievements: const [],
          ),
        ),
      ),
    );

    final button = tester.getRect(find.text('KELİME DEFTERİNE EKLE'));
    expect(button.bottom, lessThanOrEqualTo(800 - 48));
  });
}
