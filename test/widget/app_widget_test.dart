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
import 'package:kelimelig/core/router/app_router.dart';
import 'package:kelimelig/features/auth/presentation/login_screen.dart';
import 'package:kelimelig/features/game/presentation/game_screen.dart';
import 'package:kelimelig/features/game/presentation/widgets/result_screen.dart';
import 'package:kelimelig/features/game/presentation/widgets/turkish_keyboard.dart';
import 'package:kelimelig/core/widgets/game_logo.dart';
import 'package:kelimelig/features/home/presentation/daily_reward_screen.dart';
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
    await sl<GameServer>().signInWithGoogle(googleId: 'Ömer', displayName: 'Ömer');
    await sl<GameServer>().completeOnboarding();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(GameLogo), findsOneWidget);
    expect(find.text('GÜNLÜK OYNA'), findsOneWidget);
    expect(find.text('KELİME MARATONU'), findsOneWidget);
    expect(find.text('Kayıtlı hesap gerekir'), findsNothing);
  });

  testWidgets('home enables daily and league for a guest', (tester) async {
    await sl<GameServer>().signInAnonymously();
    await sl<GameServer>().completeOnboarding();
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('GÜNLÜK OYNA'), findsOneWidget);
    expect(find.text('KELİME MARATONU'), findsOneWidget);
    expect(find.text('DÜELLO'), findsOneWidget);
    expect(find.text('ÖZEL ODA'), findsOneWidget);
    expect(find.text('BRONZ LİG'), findsOneWidget);
    expect(find.text('Diğer ligler için kaydır'), findsNothing);
    expect(find.text('HAFTALIK LİG DURUMU'), findsNothing);
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('Günlük Ödül'), findsOneWidget);
    expect(find.text('Kayıt gerekir'), findsNothing);
    expect(find.text('Kayıtlı hesap gerekir'), findsNothing);
    expect(find.textContaining('Lig için kayıt gerekir'), findsNothing);
    expect(find.textContaining('kayıt gerekir'), findsNothing);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('KAZANDIN!'), findsOneWidget);
    expect(find.textContaining('Öğren'), findsOneWidget);
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('KAYBETTİN'), findsOneWidget);
    expect(find.text('Reklam izle, seriyi koru'), findsOneWidget);
    expect(find.text('Seriyi sıfırla'), findsOneWidget);
    expect(find.textContaining('4 kelimelik serin'), findsOneWidget);
  });

  testWidgets('profile shows display name', (tester) async {
    await sl<GameServer>().signInWithGoogle(googleId: 'Ömer A.', displayName: 'Ömer A.');
    await tester.pumpWidget(const MaterialApp(home: ProfileScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Ömer A.'), findsOneWidget);
    expect(find.textContaining('BRONZ'), findsOneWidget);
  });

  testWidgets('daily game win via keyboard', (tester) async {
    await sl<GameServer>().signInWithGoogle(googleId: 'Oyuncu', displayName: 'Oyuncu');
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
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('KAZANDIN!'), findsOneWidget);
  });

  testWidgets('returning user opens Luno League home', (tester) async {
    await sl<GameServer>().signInWithGoogle(
      googleId: 'home-user',
      displayName: 'Ömer',
    );
    await sl<GameServer>().completeOnboarding();
    await tester.pumpWidget(const KelimeLigApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Game Server'), findsNothing);
    expect(find.text('Luno Fall'), findsNothing);
  });

  testWidgets('hides Apple sign-in on Android', (tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
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
    expect(find.text('Google ile Giriş'), findsOneWidget);
    expect(find.text('Kayıt Ol'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsWidgets);
    expect(find.text('Test olarak gir'), findsNothing);
    expect(find.text('Apple ile giriş'), findsNothing);
    expect(find.text('Apple ile Giriş'), findsNothing);
    expect(
      find.text('Üyelik ek coin, kendi adın ve başka cihazdan devam kazandırır.'),
      findsOneWidget,
    );
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
    expect(find.text('Apple ile Giriş'), findsOneWidget);
    expect(
      find.text('Üyelik ek coin, kendi adın ve başka cihazdan devam kazandırır.'),
      findsOneWidget,
    );
  });

  testWidgets('daily reward page claims day one with a gather motion', (tester) async {
    await sl<GameServer>().signInAnonymously();
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => AuthCubit(sl()),
        child: const MaterialApp(home: DailyRewardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('ÖDÜLÜ AL'), findsOneWidget);
    expect(find.text('Bugünün ödülü'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('JETON'), findsOneWidget);
    expect(find.text('Reklam İzle, Coin Kazan!'), findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsNothing);

    await tester.tap(find.text('ÖDÜLÜ AL'));
    await tester.pump();
    expect(find.byIcon(Icons.attach_money_rounded), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.text('BUGÜN ALINDI'), findsOneWidget);
    expect(find.text('Yarının ödülü'), findsOneWidget);
    expect(find.text('Bugünün ödülü'), findsNothing);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });
}
