import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/domain/entities/cosmetics.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/local/seed_words.dart';
import 'package:kelimelig/data/local/seed_words_en.dart';
import 'package:kelimelig/domain/entities/game_models.dart';

void main() {
  late LocalGameServer server;

  setUp(() async {
    server = LocalGameServer(MemoryKeyValueStore());
    await server.initialize();
  });

  test('seed words are 5, 6 or 7 letters', () {
    final words = buildSeedWords();
    expect(words, isNotEmpty);
    expect(words.every((w) => w.length == 5 || w.length == 6 || w.length == 7), isTrue);
    expect(words.where((w) => w.length == 5), isNotEmpty);
    expect(words.where((w) => w.length == 6), isNotEmpty);
    expect(words.where((w) => w.length == 7), isNotEmpty);
  });

  test('anonymous can play daily once without league points', () async {
    await server.signInAnonymously();
    var session = await server.startDaily();
    expect(session.wordLength, 5);
    final detail = await server.adminGetSession(session.sessionId);
    session = await server.submitGuess(session.sessionId, detail!.word);
    expect(session.outcome!.won, isTrue);
    expect(session.outcome!.leaguePoints, 0);
    expect(session.outcome!.rankAfter, isNull);
    expect(session.outcome!.streak, 1);
    expect(server.startDaily(), throwsA(isA<AppFailure>()));
    expect(await server.leagueStandings(), isEmpty);
    expect(server.claimDailyReward(), throwsA(isA<AppFailure>()));
  });

  test('unfinished daily resumes same session until midnight', () async {
    await server.signInWithGoogle(displayName: 'Devam');
    var session = await server.startDaily();
    final detail = await server.adminGetSession(session.sessionId);
    final wrong = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .map((w) => w.word)
        .firstWhere((w) => !TurkishText.equals(w, detail!.word));
    session = await server.submitGuess(session.sessionId, wrong);
    expect(session.guesses, hasLength(1));
    expect(session.outcome, isNull);

    final home = await server.homeSnapshot();
    expect(home.dailyStatus, DailyStatus.started);

    final again = await server.startDaily();
    expect(again.sessionId, session.sessionId);
    expect(again.guesses, hasLength(1));
    final now = DateTime.now();
    expect(again.expiresAt, DateTime(now.year, now.month, now.day + 1));
  });

  test('registered user daily once per day', () async {
    final user = await server.signInWithGoogle(displayName: 'Ömer');
    expect(user.isAnonymous, isFalse);
    final session = await server.startDaily();
    expect(session.wordLength, 5);
    final words = await server.adminListWords();
    final secret = words.firstWhere((w) => w.length == 5 && w.playable);
    // Force known daily word
    await server.adminSetDaily(
      dateKey: DateTime.now().toIso8601String().substring(0, 10),
      league: LeagueTier.bronze,
      wordId: secret.id,
    );
  });

  test('wallet hint spend and dictionary reject', () async {
    await server.signInWithGoogle(displayName: 'Test');
    await server.watchRewardedAd();
    await server.watchRewardedAd();
    final session = await server.startEndless();
    expect(
      () => server.submitGuess(session.sessionId, 'XXXXX'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('win grants xp and coins via server', () async {
    await server.signInWithGoogle(displayName: 'Zeynep');
    final words = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await server.adminSetDaily(dateKey: key, league: LeagueTier.bronze, wordId: words.first.id);
    var session = await server.startDaily();
    session = await server.submitGuess(session.sessionId, words.first.word);
    expect(session.outcome, isNotNull);
    expect(session.outcome!.won, isTrue);
    expect(session.outcome!.xpEarned, greaterThan(0));
    expect(session.outcome!.coinEarned, 25);
    expect(server.startDaily(), throwsA(isA<AppFailure>()));
  });

  test('hint reduces xp', () async {
    await server.signInWithGoogle(displayName: 'Ali');
    for (var i = 0; i < 4; i++) {
      await server.watchRewardedAd();
    }
    final words = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await server.adminSetDaily(dateKey: key, league: LeagueTier.bronze, wordId: words[1].id);
    var session = await server.startDaily();
    session = await server.requestHint(session.sessionId, HintLevel.letter);
    expect(session.hintUsed, isTrue);
    session = await server.submitGuess(session.sessionId, words[1].word);
    expect(session.outcome!.xpEarned, lessThan(130));
  });

  test('admin overview splits guests registered banned', () async {
    await server.signInAnonymously();
    await server.signOut();
    final registered = await server.signInWithGoogle(displayName: 'Zeynep');
    await server.adminBanUser(registered.id, true, reason: 'test');
    final overview = await server.adminOverview();
    expect(overview.guestCount, 1);
    expect(overview.registeredCount, 1);
    expect(overview.bannedCount, 1);
    expect(overview.wordPoolByLength[5], greaterThan(0));
    expect(overview.missingDailyLeagues, isNotEmpty);
  });

  test('admin list users filters guests and search', () async {
    await server.signInAnonymously();
    await server.signOut();
    await server.signInWithGoogle(displayName: 'Ömer');
    final guests = await server.adminListUsers(kind: AdminUserKind.guest);
    final registered = await server.adminListUsers(kind: AdminUserKind.registered);
    final search = await server.adminListUsers(query: 'ömer');
    expect(guests, hasLength(1));
    expect(guests.single.isAnonymous, isTrue);
    expect(registered, hasLength(1));
    expect(search.single.displayName, 'Ömer');
  });

  test('admin lists games after a win and can inspect session', () async {
    await server.signInWithGoogle(displayName: 'Zeynep');
    final words = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await server.adminSetDaily(dateKey: key, league: LeagueTier.bronze, wordId: words.first.id);
    var session = await server.startDaily();
    session = await server.submitGuess(session.sessionId, words.first.word);
    expect(session.outcome!.won, isTrue);

    final games = await server.adminListGames(type: GameType.daily, won: true);
    expect(games, hasLength(1));
    expect(games.single.word, words.first.displayWord);

    final overview = await server.adminOverview();
    expect(overview.todayDailyCompleted, 1);
    expect(overview.missingDailyLeagues, isNot(contains(LeagueTier.bronze)));

    final detail = await server.adminGetSession(session.sessionId);
    expect(detail, isNotNull);
    expect(detail!.word, words.first.displayWord);
    expect(detail.session.guesses, isNotEmpty);

    final user = await server.adminUserDetail(games.single.userId);
    expect(user.recentGames, hasLength(1));
  });

  test('admin coin adjust and ban reason', () async {
    final user = await server.signInWithGoogle(displayName: 'Ali');
    expect(user.coin, 0);
    final credited = await server.adminAdjustCoins(user.id, 40);
    expect(credited.coin, 40);
    final clamped = await server.adminAdjustCoins(user.id, -100);
    expect(clamped.coin, 0);
    await server.adminBanUser(user.id, true, reason: 'abuse');
    final banned = await server.adminUserDetail(user.id);
    expect(banned.user.isBanned, isTrue);
    expect(banned.user.banReason, 'abuse');
    await server.adminBanUser(user.id, false);
    final open = await server.adminUserDetail(user.id);
    expect(open.user.isBanned, isFalse);
    expect(open.user.banReason, isNull);
  });

  Future<GameSessionView> winEndless() async {
    var session = await server.startEndless();
    final detail = await server.adminGetSession(session.sessionId);
    expect(detail, isNotNull);
    session = await server.submitGuess(session.sessionId, detail!.word);
    expect(session.outcome, isNotNull);
    expect(session.outcome!.won, isTrue);
    return session;
  }

  Future<GameSessionView> loseEndless() async {
    var session = await server.startEndless();
    final detail = await server.adminGetSession(session.sessionId);
    expect(detail, isNotNull);
    final wrong = (await server.adminListWords())
        .where((w) => w.length == session.wordLength && w.playable && w.language == 'tr')
        .map((w) => w.word)
        .firstWhere((w) => !TurkishText.equals(w, detail!.word));
    for (var i = 0; i < session.maxAttempts; i++) {
      session = await server.submitGuess(session.sessionId, wrong);
    }
    expect(session.outcome, isNotNull);
    expect(session.outcome!.won, isFalse);
    return session;
  }

  test('endless first loss cannot revive', () async {
    await server.signInWithGoogle(displayName: 'Seri');
    final lost = await loseEndless();
    expect(lost.outcome!.canReviveEndlessWithAd, isFalse);
    expect(lost.outcome!.endlessRun, 0);
    expect(lost.outcome!.showEndlessBreakAd, isFalse);
  });

  test('endless win then lose offers revive and ad restores run', () async {
    await server.signInWithGoogle(displayName: 'Seri');
    final won = await winEndless();
    expect(won.outcome!.endlessRun, 1);
    expect(won.outcome!.canReviveEndlessWithAd, isFalse);
    expect(won.outcome!.showEndlessBreakAd, isFalse);

    final lost = await loseEndless();
    expect(lost.outcome!.canReviveEndlessWithAd, isTrue);
    expect(lost.outcome!.endlessRun, 1);

    final before = await server.currentUser();
    await server.restoreEndlessRunAfterAd();
    final after = await server.currentUser();
    expect(after!.coin, before!.coin + 5);

    final recovered = await winEndless();
    expect(recovered.outcome!.endlessRun, 2);
    expect(recovered.outcome!.canReviveEndlessWithAd, isFalse);
  });

  test('third endless win shows break ad', () async {
    await server.signInWithGoogle(displayName: 'Seri');
    expect((await winEndless()).outcome!.showEndlessBreakAd, isFalse);
    expect((await winEndless()).outcome!.showEndlessBreakAd, isFalse);
    final third = await winEndless();
    expect(third.outcome!.showEndlessBreakAd, isTrue);
    expect(third.outcome!.endlessRun, 3);
    expect((await winEndless()).outcome!.showEndlessBreakAd, isFalse);
  });

  Future<GameSessionView> loseDaily() async {
    var session = await server.startDaily();
    final detail = await server.adminGetSession(session.sessionId);
    expect(detail, isNotNull);
    final wrong = (await server.adminListWords())
        .where((w) => w.length == session.wordLength && w.playable && w.language == 'tr')
        .map((w) => w.word)
        .firstWhere((w) => !TurkishText.equals(w, detail!.word));
    for (var i = 0; i < session.maxAttempts; i++) {
      session = await server.submitGuess(session.sessionId, wrong);
    }
    expect(session.outcome, isNotNull);
    expect(session.outcome!.won, isFalse);
    return session;
  }

  test('registered daily loss grants consolation league points', () async {
    await server.signInWithGoogle(displayName: 'Lig');
    final lost = await loseDaily();
    expect(lost.outcome!.leaguePoints, 10);
    expect(lost.outcome!.rankAfter, isNotNull);
    final board = await server.competitionSnapshot();
    expect(board.guest, isFalse);
    expect(board.week, isNotEmpty);
    expect(board.month, isNotEmpty);
    expect(board.season, isNotEmpty);
    expect(board.year, isNotEmpty);
    expect(board.week.any((e) => e.isCurrentUser && e.points == 10), isTrue);
  });

  test('guest competition boards stay empty', () async {
    await server.signInAnonymously();
    final board = await server.competitionSnapshot();
    expect(board.guest, isTrue);
    expect(board.week, isEmpty);
  });

  test('week rollover opens a new daily', () async {
    var now = DateTime(2026, 9, 2);
    final timed = LocalGameServer(MemoryKeyValueStore(), clock: () => now);
    await timed.initialize();
    await timed.signInWithGoogle(displayName: 'Zaman');
    var session = await timed.startDaily();
    final detail = await timed.adminGetSession(session.sessionId);
    session = await timed.submitGuess(session.sessionId, detail!.word);
    expect(session.outcome!.won, isTrue);
    await expectLater(timed.startDaily(), throwsA(isA<AppFailure>()));
    now = DateTime(2026, 9, 9);
    await timed.homeSnapshot();
    final next = await timed.startDaily();
    expect(next.outcome, isNull);
    final board = await timed.competitionSnapshot();
    expect(board.weekId, DateKeys.weekId(now));
  });

  test('equip rejects locked cosmetics', () async {
    await server.signInWithGoogle(displayName: 'Tema');
    expect(server.equipCosmetic(theme: Cosmetics.themeSeason), throwsA(isA<AppFailure>()));
    final user = await server.equipCosmetic(theme: Cosmetics.themeDefault);
    expect(user.equippedTheme, Cosmetics.themeDefault);
  });

  test('english seed words are playable 5-7 letters', () {
    final words = buildSeedWordsEn();
    expect(words, isNotEmpty);
    expect(words.every((w) => w.language == 'en'), isTrue);
    expect(words.every((w) => w.length == 5 || w.length == 6 || w.length == 7), isTrue);
    expect(words.where((w) => w.length == 5), isNotEmpty);
    expect(words.where((w) => w.length == 6), isNotEmpty);
    expect(words.where((w) => w.length == 7), isNotEmpty);
  });

  test('locale splits dictionary daily and league boards', () async {
    await server.signInWithGoogle(displayName: 'Locale');
    expect(await server.hasChosenLocale(), isTrue);
    expect(await server.activeLocale(), 'tr');

    final trWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final enWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'en')
        .toList();
    expect(enWords, isNotEmpty);

    final today = DateKeys.dayKey();
    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: trWords.first.id,
      language: 'tr',
    );
    var trSession = await server.startDaily();
    trSession = await server.submitGuess(trSession.sessionId, trWords.first.word);
    expect(trSession.outcome!.won, isTrue);
    expect(trSession.outcome!.leaguePoints, greaterThan(0));

    final trBoard = await server.leagueStandings();
    expect(trBoard.any((e) => e.isCurrentUser && e.points > 0), isTrue);

    final switched = await server.setLocale('en');
    expect(switched!.locale, 'en');
    expect(await server.activeLocale(), 'en');

    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: enWords.first.id,
      language: 'en',
    );
    var enSession = await server.startDaily();
    expect(enSession.wordLength, 5);
    enSession = await server.submitGuess(enSession.sessionId, enWords.first.word);
    expect(enSession.outcome!.won, isTrue);

    final enBoard = await server.leagueStandings();
    expect(enBoard.any((e) => e.isCurrentUser && e.points > 0), isTrue);
    expect(
      enBoard.where((e) => e.isCurrentUser).single.points,
      enSession.outcome!.leaguePoints,
    );
    expect(
      trBoard.where((e) => e.isCurrentUser).single.points,
      trSession.outcome!.leaguePoints,
    );

    await server.setLocale('tr');
    final trAgain = await server.leagueStandings();
    expect(
      trAgain.where((e) => e.isCurrentUser).single.points,
      trSession.outcome!.leaguePoints,
    );
    expect(enBoard.any((e) => e.displayName.startsWith('Alex')), isTrue);
    expect(trAgain.any((e) => e.displayName.startsWith('Ahmet')), isTrue);
  });

  test('switching locale keeps separate league and stats', () async {
    await server.signInWithGoogle(displayName: 'Split');
    final trWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final enWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'en')
        .toList();
    final today = DateKeys.dayKey();
    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: trWords.first.id,
      language: 'tr',
    );
    var trSession = await server.startDaily();
    trSession = await server.submitGuess(trSession.sessionId, trWords.first.word);
    expect(trSession.outcome!.won, isTrue);

    final afterTr = await server.currentUser();
    expect(afterTr!.gamesWon, 1);
    expect(afterTr.gamesPlayed, 1);
    expect(afterTr.currentLeague, LeagueTier.bronze);
    final sharedXp = afterTr.xp;
    expect(sharedXp, greaterThan(0));

    final enUser = await server.setLocale('en');
    expect(enUser!.locale, 'en');
    expect(enUser.gamesWon, 0);
    expect(enUser.gamesPlayed, 0);
    expect(enUser.currentLeague, LeagueTier.bronze);
    expect(enUser.xp, sharedXp);
    expect(enUser.progressByLocale['tr']!.gamesWon, 1);

    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: enWords.first.id,
      language: 'en',
    );
    var enSession = await server.startDaily();
    enSession = await server.submitGuess(enSession.sessionId, enWords.first.word);
    expect(enSession.outcome!.won, isTrue);

    final afterEn = await server.currentUser();
    expect(afterEn!.gamesWon, 1);
    expect(afterEn.locale, 'en');
    expect(afterEn.xp, greaterThan(sharedXp));

    final backTr = await server.setLocale('tr');
    expect(backTr!.locale, 'tr');
    expect(backTr.gamesWon, 1);
    expect(backTr.gamesPlayed, 1);
    expect(backTr.progressByLocale['en']!.gamesWon, 1);
    expect(backTr.xp, afterEn.xp);
  });

  test('locale switch does not resume other language daily session', () async {
    await server.signInWithGoogle(displayName: 'Resume');
    final trWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final enWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'en')
        .toList();
    final today = DateKeys.dayKey();
    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: trWords.first.id,
      language: 'tr',
    );
    final trOpen = await server.startDaily();
    expect(trOpen.wordLength, 5);

    await server.setLocale('en');
    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: enWords.first.id,
      language: 'en',
    );
    final enSession = await server.startDaily();
    expect(enSession.sessionId, isNot(trOpen.sessionId));
    final enDetail = await server.adminGetSession(enSession.sessionId);
    expect(enWords.any((w) => w.id == enDetail!.wordId), isTrue);

    await server.setLocale('tr');
    final trResume = await server.startDaily();
    expect(trResume.sessionId, trOpen.sessionId);
  });

  test('setLeague is a difficulty picker and keeps word length', () async {
    await server.signInWithGoogle(displayName: 'Difficulty');
    expect((await server.currentUser())!.currentLeague, LeagueTier.bronze);

    final gold = await server.setLeague(LeagueTier.gold);
    expect(gold.currentLeague, LeagueTier.gold);
    expect(gold.progressByLocale['tr']!.league, LeagueTier.gold);

    final endless = await server.startEndless();
    expect(endless.wordLength, 7);
    expect(endless.maxAttempts, 7);

    final silver = await server.setLeague(LeagueTier.silver);
    expect(silver.currentLeague, LeagueTier.silver);
  });
}
