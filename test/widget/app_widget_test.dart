import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/haptic_manager.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/features/auth/presentation/login_screen.dart';
import 'package:kelimelig/features/game/presentation/game_screen.dart';
import 'package:kelimelig/features/game/presentation/widgets/result_screen.dart';
import 'package:kelimelig/features/game/presentation/widgets/turkish_keyboard.dart';
import 'package:kelimelig/features/home/presentation/home_screen.dart';
import 'package:kelimelig/features/profile/presentation/profile_screen.dart';
import 'package:kelimelig/injection.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() async {
    await sl.reset();
    await configureDependencies(store: MemoryKeyValueStore(), initHive: false);
    sl<AudioManager>().enabled = false;
    sl<HapticManager>().enabled = false;
  });

  testWidgets('keyboard letters fire callbacks', (tester) async {
    String? letter;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TurkishKeyboard(
            states: const {},
            onLetter: (l) => letter = l,
            onEnter: () {},
            onBackspace: () {},
          ),
        ),
      ),
    );
    await tester.tap(find.text('A'));
    expect(letter, 'A');
    expect(find.text('İ'), findsOneWidget);
    expect(find.text('I'), findsOneWidget);
    expect(find.text('ENTER'), findsOneWidget);
  });

  testWidgets('english keyboard shows Q W X and hides İ', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TurkishKeyboard(
            locale: GameLocale.en,
            states: const {},
            onLetter: (_) {},
            onEnter: () {},
            onBackspace: () {},
          ),
        ),
      ),
    );
    expect(find.text('Q'), findsOneWidget);
    expect(find.text('W'), findsOneWidget);
    expect(find.text('X'), findsOneWidget);
    expect(find.text('İ'), findsNothing);
    expect(find.text('Ğ'), findsNothing);
  });

  testWidgets('home shows daily cta for registered user', (tester) async {
    await sl<GameServer>().signInWithGoogle(displayName: 'Ömer');
    await sl<GameServer>().completeOnboarding();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Luno League'), findsOneWidget);
    expect(find.text('GÜNLÜK OYNA'), findsOneWidget);
    expect(find.text('ENDLESS'), findsOneWidget);
    expect(find.text('Kayıtlı hesap gerekir'), findsNothing);
  });

  testWidgets('home enables daily for guest without league', (tester) async {
    await sl<GameServer>().signInAnonymously();
    await sl<GameServer>().completeOnboarding();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('GÜNLÜK OYNA'), findsOneWidget);
    expect(find.text('MİSAFİR'), findsOneWidget);
    expect(find.text('Kayıtlı hesap gerekir'), findsNothing);
    expect(find.textContaining('Lig için kayıt gerekir'), findsOneWidget);
  });

  testWidgets('result screen shows win state', (tester) async {
    const outcome = GameOutcome(
      won: true,
      word: 'KALEM',
      definition: 'Yazı aracı',
      exampleSentence: 'Kalemini aldı.',
      englishTranslation: 'pen',
      wordId: 'word_002',
      xpEarned: 130,
      coinEarned: 25,
      leaguePoints: 100,
      streak: 1,
      level: 1,
      guesses: 1,
      timeSpentSeconds: 12,
      unlockedAchievements: ['İlk Adım'],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          outcome: outcome,
          guesses: const [
            EvaluatedGuess(
              guess: 'KALEM',
              statuses: [
                LetterStatus.correct,
                LetterStatus.correct,
                LetterStatus.correct,
                LetterStatus.correct,
                LetterStatus.correct,
              ],
            ),
          ],
          maxAttempts: 6,
          isDaily: true,
          onHome: () {},
          onLearn: () {},
          onReplay: () {},
        ),
      ),
    );
    expect(find.text('HARİKA!'), findsOneWidget);
    expect(find.text('Kelimeyi Öğren'), findsOneWidget);
    expect(find.text('Paylaş'), findsOneWidget);
  });

  testWidgets('endless result offers revive after a broken run', (tester) async {
    const outcome = GameOutcome(
      won: false,
      word: 'KALEM',
      definition: 'Yazı aracı',
      exampleSentence: 'Kalemini aldı.',
      englishTranslation: 'pen',
      wordId: 'word_002',
      xpEarned: 0,
      coinEarned: 0,
      leaguePoints: 0,
      streak: 0,
      level: 1,
      guesses: 6,
      timeSpentSeconds: 40,
      unlockedAchievements: [],
      endlessRun: 4,
      canReviveEndlessWithAd: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          outcome: outcome,
          guesses: const [],
          maxAttempts: 6,
          isDaily: false,
          onHome: () {},
          onLearn: () {},
          onReplay: () {},
          onReviveWithAd: () {},
        ),
      ),
    );
    expect(find.text('BU KEZ OLMADI'), findsOneWidget);
    expect(find.text('Reklam izle, seriyi koru'), findsOneWidget);
    expect(find.text('Seriyi sıfırla'), findsOneWidget);
    expect(find.textContaining('4 kelimelik serin'), findsOneWidget);
  });

  testWidgets('profile shows display name', (tester) async {
    await sl<GameServer>().signInWithGoogle(displayName: 'Ömer A.');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Ömer A.'), findsOneWidget);
    expect(find.textContaining('Bronz'), findsOneWidget);
  });

  testWidgets('daily game win via keyboard', (tester) async {
    await sl<GameServer>().signInWithGoogle(displayName: 'Oyuncu');
    final words = await sl<GameServer>().adminListWords();
    final kalem = words.firstWhere((w) => w.word == 'kalem');
    await sl<GameServer>().adminSetDaily(
      dateKey: DateKeys.dayKey(),
      league: LeagueTier.bronze,
      wordId: kalem.id,
    );
    await tester.pumpWidget(const MaterialApp(home: GameScreen(type: GameType.daily)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final kb = find.byType(TurkishKeyboard);
    for (final ch in ['K', 'A', 'L', 'E', 'M']) {
      await tester.tap(find.descendant(of: kb, matching: find.text(ch)));
      await tester.pump();
    }
    await tester.tap(find.descendant(of: kb, matching: find.text('ENTER')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.textContaining('HARİKA'), findsOneWidget);
  });

  testWidgets('hides Apple sign-in on Android', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android, useMaterial3: true),
        home: BlocProvider(
          create: (_) => AuthCubit(sl())..bootstrap(),
          child: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Google ile giriş'), findsOneWidget);
    expect(find.text('Test olarak gir'), findsOneWidget);
    expect(find.text('Apple ile giriş'), findsNothing);
    expect(find.textContaining('Google gerekir'), findsOneWidget);
  });

  testWidgets('shows Apple sign-in on iOS', (tester) async {
    tester.view.physicalSize = const Size(400, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS, useMaterial3: true),
        home: BlocProvider(
          create: (_) => AuthCubit(sl())..bootstrap(),
          child: const LoginScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Apple ile giriş'), findsOneWidget);
    expect(find.textContaining('Google veya Apple'), findsOneWidget);
  });
}
