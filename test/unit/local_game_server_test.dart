import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/domain/entities/cosmetics.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/data/local/en_common_words.dart';
import 'package:kelimelig/data/local/en_extra_words.dart';
import 'package:kelimelig/data/local/en_batch_words.dart';
import 'package:kelimelig/data/local/en_next_words.dart';
import 'package:kelimelig/data/local/en_plus_words.dart';
import 'package:kelimelig/data/local/en_flow_words.dart';
import 'package:kelimelig/data/local/en_wave_words.dart';
import 'package:kelimelig/data/local/en_more_words.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/remote/session_kv.dart';
import 'package:kelimelig/data/local/seed_words.dart';
import 'package:kelimelig/data/local/seed_words_en.dart';
import 'package:kelimelig/data/local/word_csv.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';
import 'package:kelimelig/domain/entities/shop_product.dart';

void main() {
  late LocalGameServer server;

  setUp(() async {
    server = LocalGameServer(MemoryKeyValueStore());
    await server.initialize();
  });

  test('exact turkish profanity is drafted and lookalikes stay', () async {
    final store = MemoryKeyValueStore();
    final now = DateTime.utc(2026, 1, 1);
    Future<void> put(String id, String word) {
      return store.put(
        'words',
        id,
        WordEntity(
          id: id,
          word: word,
          language: 'tr',
          length: word.length,
          difficulty: 2,
          frequency: 3,
          category: 'genel',
          definition: 'deneme',
          exampleSentence: '',
          englishTranslation: '',
          status: WordStatus.active,
          isActive: true,
          usedCount: 4,
          createdAt: now,
          updatedAt: now,
        ).toMap(),
      );
    }

    await put('swear', 'sikmek');
    await put('coin', 'sikke');
    await put('uncle', 'amca');
    final checker = LocalGameServer(store, clock: () => now);
    await checker.initialize();
    final words = await checker.adminListWords();
    final swear = words.firstWhere((w) => w.id == 'swear');
    final coin = words.firstWhere((w) => w.id == 'coin');
    final uncle = words.firstWhere((w) => w.id == 'uncle');
    expect(swear.word, 'sikmek');
    expect(swear.definition, 'deneme');
    expect(swear.usedCount, 4);
    expect(swear.isActive, isFalse);
    expect(swear.status, WordStatus.draft);
    expect(coin.isActive, isTrue);
    expect(coin.status, WordStatus.active);
    expect(uncle.isActive, isTrue);
  });

  test('starter english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importStarterEnglishWords();
    expect(first.imported, 15);
    expect(first.skipped, 0);
    expect(first.invalid, 0);
    final words = await importer.adminListWords();
    expect(words, hasLength(15));
    expect(words.every((w) => w.language == 'en' && w.playable), isTrue);
    expect(words.map((w) => w.word.toLowerCase()), containsAll(const [
      'about',
      'search',
      'other',
      'which',
      'their',
      'there',
      'contact',
      'online',
      'first',
      'would',
      'these',
      'click',
      'service',
      'price',
      'people',
    ]));
    final second = await importer.importStarterEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(15));
  });

  test('common english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importCommonEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enCommonWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enCommonWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['state', 'email', 'videos']));
    final second = await importer.importCommonEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enCommonWordRows.length));
  });

  test('more english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importMoreEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enMoreWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enMoreWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['percent', 'false', 'diego']));
    final second = await importer.importMoreEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enMoreWordRows.length));
  });

  test('extra english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importExtraEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enExtraWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enExtraWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['truck', 'ocean', 'viewing']));
    final second = await importer.importExtraEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enExtraWordRows.length));
  });

  test('next english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importNextEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enNextWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enNextWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['christ', 'baties', 'stereo']));
    final second = await importer.importNextEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enNextWordRows.length));
  });

  test('batch english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importBatchEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enBatchWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enBatchWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['taste', 'jacket', 'falling']));
    final second = await importer.importBatchEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enBatchWordRows.length));
  });

  test('plus english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importPlusEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enPlusWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enPlusWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['basics', 'titten', 'ecology']));
    final second = await importer.importPlusEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enPlusWordRows.length));
  });

  test('wave english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importWaveEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enWaveWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enWaveWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['oliver', 'rabbit', 'magnet']));
    final second = await importer.importWaveEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enWaveWordRows.length));
  });

  test('flow english words import once and stay active', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    final first = await importer.importFlowEnglishWords();
    expect(first.invalid, 0);
    expect(first.skipped, 0);
    expect(first.imported, enFlowWordRows.length);
    final words = await importer.adminListWords();
    expect(words, hasLength(enFlowWordRows.length));
    expect(
      words.every(
        (w) =>
            w.language == 'en' &&
            w.playable &&
            w.definition.isNotEmpty &&
            (w.length == 5 || w.length == 6 || w.length == 7),
      ),
      isTrue,
    );
    expect(words.map((w) => w.word), containsAll(['porsche', 'tions', 'poison']));
    final second = await importer.importFlowEnglishWords();
    expect(second.imported, 0);
    expect((await importer.adminListWords()), hasLength(enFlowWordRows.length));
  });

  test('noise english words are deleted once', () async {
    final store = MemoryKeyValueStore();
    final importer = LocalGameServer(store);
    const csv = '''
word,language,definition,example,english,category,difficulty,frequency,status
thehun,en,Noise.,,,abstract,3,1,active
ampland,en,Noise.,,,abstract,3,1,active
gratuit,en,Noise.,,,abstract,3,1,active
andale,en,Noise.,,,abstract,3,1,active
msgid,en,Noise.,,,abstract,3,1,active
msgstr,en,Noise.,,,abstract,3,1,active
magnet,en,A piece of metal that attracts iron.,,,object,1,5,active
''';
    final imported = await importer.adminImportWords(csv);
    expect(imported.imported, 7);
    final removed = await importer.dropNoiseEnglishWords();
    expect(removed, 6);
    final words = await importer.adminListWords();
    expect(words.map((w) => w.word), ['magnet']);
    expect(await importer.dropNoiseEnglishWords(), 0);
    expect((await importer.adminListWords()).map((w) => w.word), ['magnet']);
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
    final review = await server.startDaily();
    expect(review.sessionId, session.sessionId);
    expect(review.isFinished, isTrue);
    expect(review.guesses.map((guess) => guess.guess), [detail.word]);
    expect(review.outcome, isNull);
    expect(review.solved, isTrue);
    expect(review.answer, detail.word);
    expect(await server.leagueStandings(), isEmpty);
    expect(server.claimDailyReward(), throwsA(isA<AppFailure>()));
  });

  test('unfinished daily resumes same session until midnight', () async {
    await server.signInWithGoogle(googleId: 'Devam', displayName: 'Devam');
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

  test('daily result board ranks today and keeps the player past 10', () async {
    final root = MemoryKeyValueStore();
    final host = LocalGameServer(SessionKv(root));
    final guest = LocalGameServer(SessionKv(root));
    await host.initialize();
    await host.signInWithGoogle(googleId: 'host', displayName: 'Ayse');
    await guest.signInWithGoogle(googleId: 'guest', displayName: 'Berk');
    final words = (await host.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await host.adminSetDaily(
      dateKey: key,
      league: LeagueTier.bronze,
      wordId: words.first.id,
    );
    var fast = await host.startDaily();
    var slow = await guest.startDaily();
    fast = await host.submitGuess(fast.sessionId, words.first.word);
    final wrong = words
        .map((w) => w.word)
        .firstWhere((w) => !TurkishText.equals(w, words.first.word));
    slow = await guest.submitGuess(slow.sessionId, wrong);
    slow = await guest.submitGuess(slow.sessionId, words.first.word);

    final board = await guest.resultBoard(
      type: GameType.daily,
      wordId: fast.outcome!.wordId,
    );
    expect(board.map((row) => row.displayName), ['Ayse', 'Berk']);
    expect(board.first.score, '1');
    expect(board.last.isCurrentUser, isTrue);
    expect(board.last.rank, 2);
    expect(board.last.score, '2');
    expect(board.last.firstSolved, 1);
    expect(board.last.secondSolved, 1);
    expect(resultBoardLines(board).rankOnly, isNull);
  });

  test('registered user daily once per day', () async {
    final user = await server.signInWithGoogle(googleId: 'Ömer', displayName: 'Ömer');
    expect(user.isAnonymous, isFalse);
    final session = await server.startDaily();
    expect(session.wordLength, 5);
    final words = await server.adminListWords();
    final secret = words.firstWhere(
      (w) => w.length == 5 && w.playable && w.language == 'tr',
    );
    // Force known daily word
    await server.adminSetDaily(
      dateKey: DateTime.now().toIso8601String().substring(0, 10),
      league: LeagueTier.bronze,
      wordId: secret.id,
    );
  });

  test('wallet hint spend and dictionary reject', () async {
    await server.signInWithGoogle(googleId: 'Test', displayName: 'Test');
    await server.watchRewardedAd();
    await server.watchRewardedAd();
    final session = await server.startEndless();
    expect(
      () => server.submitGuess(session.sessionId, 'XXXXX'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('win grants xp and coins via server', () async {
    await server.signInWithGoogle(googleId: 'Zeynep', displayName: 'Zeynep');
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
    final review = await server.startDaily();
    expect(review.sessionId, session.sessionId);
    expect(review.isFinished, isTrue);
  });

  test('hint reduces xp', () async {
    await server.signInWithGoogle(googleId: 'Ali', displayName: 'Ali');
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
    expect(session.currentAttempt, 0);
    expect(session.letterHintsOnRow, 1);
    expect(session.revealedLetters, hasLength(1));
    session = await server.requestHint(session.sessionId, HintLevel.letter);
    expect(session.currentAttempt, 1);
    expect(session.letterHintsOnRow, 1);
    expect(session.revealedLetters, hasLength(2));
    session = await server.submitGuess(session.sessionId, words[1].word);
    expect(session.outcome!.xpEarned, lessThan(130));
  });

  test('admin overview splits guests registered banned', () async {
    await server.signInAnonymously();
    await server.signOut();
    final registered = await server.signInWithGoogle(googleId: 'Zeynep', displayName: 'Zeynep');
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
    await server.signInWithGoogle(googleId: 'Ömer', displayName: 'Ömer');
    final guests = await server.adminListUsers(kind: AdminUserKind.guest);
    final registered = await server.adminListUsers(kind: AdminUserKind.registered);
    final search = await server.adminListUsers(query: 'ömer');
    expect(guests, hasLength(1));
    expect(guests.single.isAnonymous, isTrue);
    expect(registered, hasLength(1));
    expect(search.single.displayName, 'Ömer');
  });

  test('admin lists games after a win and can inspect session', () async {
    await server.signInWithGoogle(googleId: 'Zeynep', displayName: 'Zeynep');
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
    final user = await server.signInWithGoogle(googleId: 'Ali', displayName: 'Ali');
    expect(user.coin, 350);
    final credited = await server.adminAdjustCoins(user.id, 40);
    expect(credited.coin, 390);
    final clamped = await server.adminAdjustCoins(user.id, -1000);
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
    await server.signInWithGoogle(googleId: 'Seri', displayName: 'Seri');
    final lost = await loseEndless();
    expect(lost.outcome!.canReviveEndlessWithAd, isFalse);
    expect(lost.outcome!.endlessRun, 0);
    expect(lost.outcome!.showEndlessBreakAd, isFalse);
  });

  test('endless win then lose offers revive and ad restores run', () async {
    await server.signInWithGoogle(googleId: 'Seri', displayName: 'Seri');
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
    expect(after!.coin, before!.coin + 15);

    final recovered = await winEndless();
    expect(recovered.outcome!.endlessRun, 2);
    expect(recovered.outcome!.canReviveEndlessWithAd, isFalse);
  });

  test('third endless win shows break ad', () async {
    await server.signInWithGoogle(googleId: 'Seri', displayName: 'Seri');
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
    await server.signInWithGoogle(googleId: 'Lig', displayName: 'Lig');
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
    await timed.signInWithGoogle(googleId: 'Zaman', displayName: 'Zaman');
    var session = await timed.startDaily();
    final detail = await timed.adminGetSession(session.sessionId);
    session = await timed.submitGuess(session.sessionId, detail!.word);
    expect(session.outcome!.won, isTrue);
    final review = await timed.startDaily();
    expect(review.sessionId, session.sessionId);
    expect(review.isFinished, isTrue);
    now = DateTime(2026, 9, 9);
    await timed.homeSnapshot();
    final next = await timed.startDaily();
    expect(next.outcome, isNull);
    final board = await timed.competitionSnapshot();
    expect(board.weekId, DateKeys.weekId(now));
  });

  test('equip rejects locked cosmetics', () async {
    await server.signInWithGoogle(googleId: 'Tema', displayName: 'Tema');
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
    await server.signInWithGoogle(googleId: 'Locale', displayName: 'Locale');
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
    await server.signInWithGoogle(googleId: 'Split', displayName: 'Split');
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
    await server.signInWithGoogle(googleId: 'Resume', displayName: 'Resume');
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

  test('playing EN daily does not lock TR daily same day', () async {
    await server.signInWithGoogle(googleId: 'Bilingual', displayName: 'Bilingual');
    final trWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .toList();
    final enWords = (await server.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'en')
        .toList();
    final today = DateKeys.dayKey();

    await server.setLocale('en');
    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: enWords.first.id,
      language: 'en',
    );
    var enSession = await server.startDaily();
    enSession =
        await server.submitGuess(enSession.sessionId, enWords.first.word);
    expect(enSession.outcome!.won, isTrue);

    final afterEn = await server.currentUser();
    expect(afterEn!.playedDailyOn(today), isTrue);
    expect(afterEn.playedDailyOn(today, language: 'tr'), isFalse);

    await server.setLocale('tr');
    final home = await server.homeSnapshot();
    expect(home.dailyStatus, isNot(DailyStatus.completed));

    await server.adminSetDaily(
      dateKey: today,
      league: LeagueTier.bronze,
      wordId: trWords.first.id,
      language: 'tr',
    );
    var trSession = await server.startDaily();
    trSession =
        await server.submitGuess(trSession.sessionId, trWords.first.word);
    expect(trSession.outcome!.won, isTrue);
    expect((await server.currentUser())!.playedDailyOn(today), isTrue);
  });

  test('setLeague is a difficulty picker and keeps word length', () async {
    await server.signInWithGoogle(googleId: 'Difficulty', displayName: 'Difficulty');
    expect((await server.currentUser())!.currentLeague, LeagueTier.bronze);

    final gold = await server.setLeague(LeagueTier.gold);
    expect(gold.currentLeague, LeagueTier.gold);
    expect(gold.progressByLocale['tr']!.league, LeagueTier.gold);

    final endless = await server.startEndless();
    expect(endless.wordLength, 7);

    final silver = await server.setLeague(LeagueTier.silver);
    expect(silver.currentLeague, LeagueTier.silver);
  });

  test('shop purchase grants coins from catalog', () async {
    await server.signInWithGoogle(googleId: 'Buyer', displayName: 'Buyer');
    final products = await server.listShopProducts();
    expect(products, isNotEmpty);
    final pack = products.firstWhere((p) => p.id == 'coins_550');
    expect(pack.coins, 550);
    expect(pack.priceTry, '₺69,99');

    final before = (await server.currentUser())!.coin;
    expect(
      () => server.purchaseShopProduct(pack.id, purchaseToken: ''),
      throwsA(isA<AppFailure>()),
    );
    expect((await server.currentUser())!.coin, before);
    final after = await server.purchaseShopProduct(
      pack.id,
      purchaseToken: 'play-coins-550',
    );
    expect(after.coin, before + 550);
    final replay = await server.purchaseShopProduct(
      pack.id,
      purchaseToken: 'play-coins-550',
    );
    expect(replay.coin, after.coin);
  });

  test('shop purchase grants streak shield', () async {
    await server.signInWithGoogle(googleId: 'ShieldBuyer', displayName: 'ShieldBuyer');
    final products = await server.listShopProducts();
    final shield = products.firstWhere((p) => p.id == 'streak_shield_1');
    expect(shield.shields, 1);
    expect(shield.coins, 0);

    final before = (await server.currentUser())!;
    expect(before.shields, 0);
    final after = await server.purchaseShopProduct(
      shield.id,
      purchaseToken: 'play-shield-1',
    );
    expect(after.shields, 1);
    expect(after.coin, before.coin);

    await server.purchaseShopProduct(shield.id, purchaseToken: 'play-shield-2');
    expect((await server.currentUser())!.shields, 2);
    expect(
      () => server.purchaseShopProduct(shield.id, purchaseToken: 'play-shield-3'),
      throwsA(isA<AppFailure>()),
    );
  });

  test('admin can update shop product prices', () async {
    await server.signInWithGoogle(googleId: 'AdminShop', displayName: 'AdminShop');
    final updated = await server.adminUpsertShopProduct(
      const ShopProduct(
        id: 'coins_550',
        coins: 600,
        priceTry: '₺74,99',
        priceUsd: '\$3.49',
        badge: 'populer',
        popular: true,
        sortOrder: 20,
      ),
    );
    expect(updated.coins, 600);
    final listed = await server.listShopProducts();
    expect(listed.firstWhere((p) => p.id == 'coins_550').priceTry, '₺74,99');

    await server.adminUpsertShopProduct(
      updated.copyWith(active: false),
    );
    expect(
      (await server.listShopProducts()).any((p) => p.id == 'coins_550'),
      isFalse,
    );
    expect(
      (await server.adminListShopProducts())
          .firstWhere((p) => p.id == 'coins_550')
          .active,
      isFalse,
    );

    final reset = await server.adminResetShopCatalog();
    expect(reset.any((p) => p.id == 'coins_550' && p.coins == 550), isTrue);
  });

  test('email register and sign in', () async {
    final registered = await server.registerWithEmail(
      email: 'oyuncu@example.com',
      password: 'secret1',
      displayName: 'Oyuncu',
    );
    expect(registered.isAnonymous, isFalse);
    expect(registered.authProvider, AuthProvider.email);
    expect(registered.email, 'oyuncu@example.com');
    expect(registered.canJoinLeague, isTrue);

    expect(
      () => server.registerWithEmail(
        email: 'oyuncu@example.com',
        password: 'secret1',
      ),
      throwsA(isA<AppFailure>()),
    );

    await server.signOut();
    expect(await server.currentUser(), isNull);

    final signedIn = await server.signInWithEmail(
      email: 'Oyuncu@Example.com',
      password: 'secret1',
    );
    expect(signedIn.id, registered.id);
    expect(signedIn.email, 'oyuncu@example.com');

    expect(
      () => server.signInWithEmail(
        email: 'oyuncu@example.com',
        password: 'wrong!!',
      ),
      throwsA(isA<AppFailure>()),
    );
  });

  test('finished daily stays closed after the completion flag is cleared', () async {
    final store = MemoryKeyValueStore();
    final locked = LocalGameServer(store);
    await locked.initialize();
    final user = await locked.signInAnonymously();
    var session = await locked.startDaily();
    final detail = await locked.adminGetSession(session.sessionId);
    session = await locked.submitGuess(session.sessionId, detail!.word);
    expect(session.outcome, isNotNull);

    final saved = await store.get('users', user.id);
    saved!['lastDailyDate'] = null;
    saved['lastDailyByLocale'] = <String, String>{};
    await store.put('users', user.id, saved);
    await store.putMeta('daily_done_${user.id}_tr', 'cleared');

    final review = await locked.startDaily();
    expect(review.sessionId, session.sessionId);
    expect(review.isFinished, isTrue);
    expect((await locked.homeSnapshot()).dailyStatus, DailyStatus.completed);
  });

  test('guest upgrades to email on register', () async {
    final guest = await server.signInAnonymously();
    expect(guest.isAnonymous, isTrue);
    final upgraded = await server.registerWithEmail(
      email: 'guest@example.com',
      password: 'secret1',
      displayName: 'Yeni',
    );
    expect(upgraded.id, guest.id);
    expect(upgraded.isAnonymous, isFalse);
    expect(upgraded.displayName, 'Yeni');
    expect(upgraded.authProvider, AuthProvider.email);
  });

  test('nickname is unique regardless of case and avatar is stored', () async {
    final first = await server.registerWithEmail(
      email: 'bir@example.com',
      password: 'secret1',
      displayName: 'Aylin',
      avatar: 'abc',
    );
    expect(first.displayName, 'Aylin');
    expect(first.avatar, 'abc');

    await server.signOut();
    expect(
      () => server.registerWithEmail(
        email: 'iki@example.com',
        password: 'secret1',
        displayName: '  aylin ',
      ),
      throwsA(
        isA<AppFailure>().having((error) => error.code, 'code', 'NICK_TAKEN'),
      ),
    );
  });

  test('google sign-in without an id does not create a user', () async {
    expect(
      () => server.signInWithGoogle(googleId: '  '),
      throwsA(isA<AppFailure>()),
    );
    expect(await server.currentUser(), isNull);
  });

  test('the same google id reopens the local profile', () async {
    final first = await server.signInWithGoogle(
      googleId: 'sub-1',
      email: 'a@gmail.com',
      displayName: 'Aylin',
    );
    await server.signOut();
    final again = await server.signInWithGoogle(
      googleId: 'sub-1',
      displayName: 'Aylin',
    );
    expect(again.id, first.id);
    expect(again.isAnonymous, isFalse);
    expect(again.email, 'a@gmail.com');
  });

  test('csv import skips words already stored', () async {
    const header =
        'word,language,definition,example,english,category,difficulty,frequency,status';
    const csv = '''
$header
kalem,tr,Yeni anlam,Yeni cümle.,pen,okul,1,5,active
zurna,tr,Üflemeli çalgı,Zurna çaldı.,zurna,müzik,,,
elma,tr,Meyve,Elma kırmızı.,apple,meyve,,,
zurna,tr,İkinci,Tekrar.,zurna,müzik,,,
''';
    final before = (await server.adminListWords())
        .firstWhere((word) => word.word == 'kalem');
    final first = await server.adminImportWords(csv);
    expect(first.imported, 1);
    expect(first.skipped, 2);
    expect(first.invalid, 1);

    final kalem = (await server.adminListWords())
        .firstWhere((word) => word.word == 'kalem');
    expect(kalem.definition, before.definition);
    expect(kalem.usedCount, before.usedCount);
    expect(
      (await server.adminListWords()).where((word) => word.word == 'zurna'),
      hasLength(1),
    );

    final again = await server.adminImportWords(csv);
    expect(again.imported, 0);
    expect(again.skipped, 3);
    expect(again.invalid, 1);
  });

  test('csv keeps a quoted comma and rejects a bad header', () async {
    final doc = parseWordCsv(
      'word;language;definition;example;english;category;difficulty;frequency;status\n'
      'zurna;tr;"Üflemeli, nefesli çalgı";Zurna çaldı.;zurna;müzik;;;\n',
    );
    expect(doc.headerError, isNull);
    expect(doc.rows.single[2], 'Üflemeli, nefesli çalgı');

    final count = (await server.adminListWords()).length;
    expect(
      () => server.adminImportWords('kelime,dil\nzurna,tr\n'),
      throwsA(
        isA<AppFailure>().having((error) => error.code, 'code', 'CSV_HEADER'),
      ),
    );
    expect((await server.adminListWords()).length, count);
  });

  test('auto assign refills a day whose word was deleted', () async {
    final words = (await server.adminListWords())
        .where((w) => w.playable && w.language == 'tr' && w.length == 5)
        .toList();
    final gone = words.first;
    final kept = words[1];
    await server.adminSetDaily(
      dateKey: '2026-09-01',
      league: LeagueTier.bronze,
      wordId: gone.id,
    );
    await server.adminSetDaily(
      dateKey: '2026-09-02',
      league: LeagueTier.bronze,
      wordId: kept.id,
    );
    await server.adminDeleteWord(gone.id);

    final assigned = await server.adminAutoAssignMonth(
      year: 2026,
      month: 9,
      league: LeagueTier.bronze,
      locale: 'tr',
    );
    final map = await server.adminDailyMap();
    final replacement = map['2026-09-01_tr_bronze'];
    expect(map['2026-09-02_tr_bronze'], kept.id);
    expect(replacement, isNotNull);
    expect(replacement, isNot(gone.id));
    expect(
      (await server.adminListWords()).any((word) => word.id == replacement),
      isTrue,
    );
    expect(assigned, 29);
  });

  test('a guest starts with 175 coins and registration adds 350 once', () async {
    final guest = await server.signInAnonymously();
    expect(guest.coin, 175);
    expect((await server.signInAnonymously()).coin, 175);

    final member = await server.registerWithEmail(
      email: 'ada@luno.test',
      password: 'secret1',
      displayName: 'Ada',
    );
    expect(member.coin, 525);
    expect(
      (await server.signInWithEmail(email: 'ada@luno.test', password: 'secret1')).coin,
      525,
    );
  });

  test('shared extra daily stays in order and skips marathon', () async {
    final root = MemoryKeyValueStore();
    final host = LocalGameServer(SessionKv(root), random: Random(3));
    final guest = LocalGameServer(SessionKv(root), random: Random(9));
    await host.initialize();
    final player = await host.signInWithGoogle(googleId: 'host-daily', displayName: 'Ayse');
    final other = await guest.signInWithGoogle(googleId: 'guest-daily', displayName: 'Berk');

    var run = await host.startEndless();
    final endlessWord = (await host.adminGetSession(run.sessionId))!.word;
    run = await host.submitGuess(run.sessionId, endlessWord);
    expect(run.outcome!.endlessRun, 1);

    var first = await host.startDaily();
    expect(first.dailyIndex, 1);
    final secret = (await host.adminGetSession(first.sessionId))!.word;
    final coinsBefore = (await host.currentUser())!.coin;
    first = await host.submitGuess(first.sessionId, secret);
    expect(first.outcome!.won, isTrue);
    expect(first.outcome!.streak, 1);
    expect(first.outcome!.leaguePoints, greaterThan(0));
    expect((await host.currentUser())!.coin, coinsBefore + 25);

    var guestFirst = await guest.startDaily();
    expect(guestFirst.dailyIndex, 1);
    expect((await guest.adminGetSession(guestFirst.sessionId))!.word, secret);
    expect(
      await guest.grantDailyNextProof(userId: other.id, transactionId: 'before-finish'),
      isFalse,
    );
    guestFirst = await guest.submitGuess(guestFirst.sessionId, secret);
    expect(guestFirst.outcome!.won, isTrue);

    final waiting = await host.homeSnapshot();
    expect(waiting.dailyStatus, DailyStatus.completed);
    expect(waiting.dailyNeedsAd, isTrue);
    expect(waiting.dailyIndex, 2);
    expect((await host.startDaily()).sessionId, first.sessionId);

    final day = DateKeys.dayKey(DateTime.now());
    final coinsAtAd = (await host.currentUser())!.coin;
    final guestCoinsAtAd = (await guest.currentUser())!.coin;
    await Future.wait([
      host.grantDailyNextProof(userId: player.id, transactionId: 'race-a'),
      guest.grantDailyNextProof(userId: other.id, transactionId: 'race-b'),
    ]);
    expect((await host.currentUser())!.coin, coinsAtAd);
    expect((await guest.currentUser())!.coin, guestCoinsAtAd);
    expect(await root.get('daily_games', '${day}_tr_bronze_2'), isNotNull);
    expect(await root.get('daily_games', '${day}_tr_bronze_3'), isNull);

    final opened = await host.homeSnapshot();
    expect(opened.dailyNeedsAd, isFalse);
    expect(opened.dailyIndex, 2);
    expect((await guest.homeSnapshot()).dailyNeedsAd, isFalse);

    var second = await host.startDaily();
    var guestSecond = await guest.startDaily();
    expect(second.dailyIndex, 2);
    expect(guestSecond.dailyIndex, 2);
    expect(second.sessionId, isNot(guestSecond.sessionId));
    final hostWord = (await host.adminGetSession(second.sessionId))!.word;
    final guestWord = (await guest.adminGetSession(guestSecond.sessionId))!.word;
    expect(hostWord, guestWord);
    expect(hostWord, isNot(secret));

    final beforeSecond = (await host.currentUser())!.coin;
    second = await host.submitGuess(second.sessionId, hostWord);
    expect(second.outcome!.won, isTrue);
    expect(second.outcome!.streak, 1);
    expect(second.outcome!.xpEarned, greaterThan(0));
    expect(second.outcome!.leaguePoints, greaterThan(0));
    expect(second.outcome!.coinEarned, 25);
    expect((await host.currentUser())!.coin, beforeSecond + 25);
    expect((await host.currentUser())!.endlessBest, 1);
    expect(await root.getMeta('endless_finished_${player.id}_tr'), '1');
    expect(await root.getMeta('endless_run_${player.id}_tr'), '1');
    expect(await root.getMeta('endless_wins_${player.id}_tr'), '1');

    final listed = await host.adminDailyMap();
    final firstId = (await root.get('game_sessions', first.sessionId))!['wordId'];
    final secondId = (await root.get('game_sessions', second.sessionId))!['wordId'];
    expect(listed['${day}_tr_bronze'], firstId);
    expect(listed['${day}_tr_bronze_2'], secondId);
    expect(DateTime.tryParse(listed['${day}_tr_bronze_2_at'] ?? ''), isNotNull);
  });

  test('losing daily 1 still requires an ad before daily 2', () async {
    final root = MemoryKeyValueStore();
    final host = LocalGameServer(SessionKv(root), random: Random(4));
    await host.initialize();
    final player = await host.signInWithGoogle(googleId: 'lose-daily', displayName: 'Kayip');
    var session = await host.startDaily();
    final secret = (await host.adminGetSession(session.sessionId))!.word;
    final wrongs = (await host.adminListWords())
        .where(
          (word) =>
              word.length == 5 &&
              word.playable &&
              word.language == 'tr' &&
              !TurkishText.equals(word.word, secret),
        )
        .map((word) => word.word)
        .take(6)
        .toList();
    for (final guess in wrongs) {
      session = await host.submitGuess(session.sessionId, guess);
    }
    expect(session.outcome!.won, isFalse);
    expect(session.outcome!.coinEarned, 5);
    final afterLoss = (await host.currentUser())!.coin;
    expect((await host.homeSnapshot()).dailyNeedsAd, isTrue);
    expect((await host.startDaily()).sessionId, session.sessionId);
    expect(
      await host.grantDailyNextProof(userId: player.id, transactionId: 'lose-ad'),
      isTrue,
    );
    expect((await host.currentUser())!.coin, afterLoss);
    final next = await host.startDaily();
    expect(next.dailyIndex, 2);
    expect(next.isFinished, isFalse);
    expect(next.sessionId, isNot(session.sessionId));
  });

  test('a stored extra daily still needs each player to watch an ad', () async {
    final root = MemoryKeyValueStore();
    final host = LocalGameServer(SessionKv(root), random: Random(5));
    final guest = LocalGameServer(SessionKv(root), random: Random(6));
    await host.initialize();
    final player = await host.signInWithGoogle(googleId: 'host-permit', displayName: 'Ayse');
    final other = await guest.signInWithGoogle(googleId: 'guest-permit', displayName: 'Berk');

    var first = await host.startDaily();
    final secret = (await host.adminGetSession(first.sessionId))!.word;
    first = await host.submitGuess(first.sessionId, secret);
    var guestFirst = await guest.startDaily();
    guestFirst = await guest.submitGuess(guestFirst.sessionId, secret);

    final day = DateKeys.dayKey(DateTime.now());
    expect(await host.prepareNextDaily(), isTrue);
    expect(await root.get('daily_games', '${day}_tr_bronze_2'), isNotNull);
    expect((await host.startDaily()).sessionId, first.sessionId);
    expect(await guest.prepareNextDaily(), isTrue);
    expect(await root.get('daily_games', '${day}_tr_bronze_3'), isNull);
    expect((await guest.startDaily()).sessionId, guestFirst.sessionId);

    final coins = (await host.currentUser())!.coin;
    expect(
      await host.grantDailyNextProof(userId: player.id, transactionId: 'host-only'),
      isTrue,
    );
    expect((await host.currentUser())!.coin, coins);
    expect((await host.homeSnapshot()).dailyNeedsAd, isFalse);
    expect((await guest.homeSnapshot()).dailyNeedsAd, isTrue);
    final second = await host.startDaily();
    expect(second.dailyIndex, 2);
    expect((await guest.startDaily()).sessionId, guestFirst.sessionId);

    expect(
      await guest.grantDailyNextProof(userId: other.id, transactionId: 'guest-own'),
      isTrue,
    );
    final guestSecond = await guest.startDaily();
    expect(guestSecond.dailyIndex, 2);
    expect(
      (await guest.adminGetSession(guestSecond.sessionId))!.word,
      (await host.adminGetSession(second.sessionId))!.word,
    );
  });

  test('starting a daily queues the next shared word', () async {
    final root = MemoryKeyValueStore();
    final host = LocalGameServer(SessionKv(root), random: Random(7));
    final guest = LocalGameServer(SessionKv(root), random: Random(8));
    await host.initialize();
    final player = await host.signInWithGoogle(googleId: 'queue-host', displayName: 'Ayse');
    await guest.signInWithGoogle(googleId: 'queue-guest', displayName: 'Berk');
    final day = DateKeys.dayKey(DateTime.now());

    var session = await host.startDaily();
    expect(session.dailyIndex, 1);
    final firstSlot = await root.get('daily_games', '${day}_tr_bronze');
    final secondSlot = await root.get('daily_games', '${day}_tr_bronze_2');
    expect(firstSlot, isNotNull);
    expect(secondSlot, isNotNull);
    expect(secondSlot!['wordId'], isNot(firstSlot!['wordId']));
    expect(await root.get('daily_games', '${day}_tr_bronze_3'), isNull);
    expect(
      (await host.adminDailyMap())['${day}_tr_bronze_2'],
      secondSlot['wordId'],
    );

    var guestSession = await guest.startDaily();
    expect(
      (await guest.adminGetSession(guestSession.sessionId))!.word,
      (await host.adminGetSession(session.sessionId))!.word,
    );
    expect(
      (await root.get('daily_games', '${day}_tr_bronze_2'))!['wordId'],
      secondSlot['wordId'],
    );

    final secret = (await host.adminGetSession(session.sessionId))!.word;
    session = await host.submitGuess(session.sessionId, secret);
    expect((await host.startDaily()).sessionId, session.sessionId);
    guestSession = await guest.submitGuess(guestSession.sessionId, secret);
    expect((await guest.startDaily()).sessionId, guestSession.sessionId);

    expect(
      await host.grantDailyNextProof(userId: player.id, transactionId: 'queue-host'),
      isTrue,
    );
    final second = await host.startDaily();
    expect(second.dailyIndex, 2);
    expect(await root.get('daily_games', '${day}_tr_bronze_3'), isNotNull);
    expect((await guest.startDaily()).sessionId, guestSession.sessionId);
  });

  test('daily sequence stops after 30', () async {
    final root = MemoryKeyValueStore();
    final host = LocalGameServer(SessionKv(root), random: Random(11));
    await host.initialize();
    final player = await host.signInWithGoogle(googleId: 'cap-daily', displayName: 'Sinir');
    final day = DateKeys.dayKey(DateTime.now());

    for (var index = 1; index <= AppConstants.maxDailySlots; index++) {
      var session = await host.startDaily();
      expect(session.dailyIndex, index, reason: 'index $index');
      expect(session.isFinished, isFalse);
      if (index < AppConstants.maxDailySlots) {
        expect(
          await root.get('daily_games', '${day}_tr_bronze_${index + 1}'),
          isNotNull,
        );
      }
      expect(await root.get('daily_games', '${day}_tr_bronze_31'), isNull);
      final secret = (await host.adminGetSession(session.sessionId))!.word;
      session = await host.submitGuess(session.sessionId, secret);
      expect(session.outcome!.won, isTrue);
      if (index < AppConstants.maxDailySlots) {
        expect(
          await host.grantDailyNextProof(
            userId: player.id,
            transactionId: 'cap-$index',
          ),
          isTrue,
        );
      }
    }

    expect(
      await host.grantDailyNextProof(userId: player.id, transactionId: 'cap-past'),
      isFalse,
    );
    final stuck = await host.startDaily();
    expect(stuck.dailyIndex, AppConstants.maxDailySlots);
    expect(stuck.isFinished, isTrue);
  });
}
