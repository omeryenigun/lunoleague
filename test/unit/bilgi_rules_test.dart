import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_controller.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_csv.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_questions.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_trial_questions.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';

void main() {
  test('a mixed draw splits the count across four difficulties', () {
    expect(bilgiMixQuotas(10), [3, 3, 2, 2]);
    expect(bilgiMixQuotas(8), [2, 2, 2, 2]);
    expect(bilgiMixQuotas(1), [1, 0, 0, 0]);
  });

  test('score gold xp and lives follow the bilgi rules', () {
    final scored = scoreQuestion(
      difficulty: 'orta',
      modeMultiplier: 1.5,
      timeLeft: 10,
      totalTime: 20,
      streak: 3,
    );
    expect(scored.points, 32);
    expect(scored.timeBonus, 3);
    expect(scored.streakBonus, 6);
    expect(goldForScore(100, 2), 20);
    expect(xpForScore(100), 50);
    final level = applyXp(level: 4, xp: 4900, gained: 200);
    expect(level.level, 5);
    expect(level.diamondsGained, 1);
    final now = DateTime(2026, 9, 28, 12);
    expect(
      regeneratedLives(lives: 2, livesAt: now.subtract(const Duration(minutes: 61)), now: now),
      4,
    );
  });

  test('trial questions are gone and categories stay', () {
    expect(bilgiCategories, hasLength(68));
    expect(bilgiCategoryById('spor')?.subs, contains('Futbol'));
    expect(bilgiCategoryById('futbol'), isNull);
    expect(bilgiCategoryById('mucit'), isNull);
    expect(bilgiQuestionLines, isEmpty);
    expect(seedBilgiQuestions(), isEmpty);
    expect(bilgiTrialQuestions, hasLength(115));
  });

  test('daily reward can be claimed once per day', () async {
    final clock = DateTime(2026, 9, 28, 9);
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => clock);
    final first = await server.claimDaily();
    expect(first.ok, isTrue);
    expect(first.profile!.gold, 600);
    final second = await server.claimDaily();
    expect(second.message, '📅 Bugünkü hakkını kullandın.');
    expect(DateKeys.dayKey(clock), '2026-09-28');
  });

  test('rewarded ad gold is the configured amount', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    final cfg = await server.config();
    final before = (await server.profile()).gold;
    final granted = await server.grantAd(kind: 'gold');
    expect(granted.message, isNull);
    expect(granted.profile!.gold, before + cfg.rewardedGold);
    expect(granted.profile!.adGoldToday, 1);
  });

  test('a finished score doubles only after the rewarded path', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    final question = BilgiQuestion(
      id: 'q1',
      categoryId: 'genel',
      text: 'Soru',
      options: const ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'kolay',
      explanation: 'aciklama',
    );
    final started = await server.startRound(
      modeId: 'sakin',
      categoryId: tumuKarmaId,
      fixedQuestions: [question],
      questionCount: 1,
    );
    expect(started.round, isNotNull);
    final round = started.round!;
    await server.answer(roundId: round.id, option: 0, timeLeft: 10);
    final finished = await server.finish(round.id);
    final score = finished.round!.score;
    final total = finished.profile!.totalScore;
    expect(score, greaterThan(0));
    final doubled = await server.doubleFinishedScore(round.id);
    expect(doubled.message, isNull);
    expect(doubled.round!.score, score * 2);
    expect(doubled.profile!.totalScore, total + score);
    expect(doubled.profile!.gold, finished.profile!.gold);
    expect(doubled.profile!.adDoubleToday, 1);
  });

  test('DEVAM on the last question opens the result while wallet finish is still pending', () async {
    final clock = DateTime(2026, 10, 7, 15);
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store, clock: () => clock);
    final game = BilgiController(server);
    addTearDown(game.dispose);
    final question = BilgiQuestion(
      id: 'q-last',
      categoryId: 'genel',
      text: 'Son soru',
      options: const ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'kolay',
      explanation: 'aciklama',
    );
    final started = await server.startRound(
      modeId: 'hizli',
      categoryId: tumuKarmaId,
      fixedQuestions: [question],
      questionCount: 1,
    );
    final round = started.round!;
    final stale = started.profile!;
    final beforeGold = stale.gold;
    final beforeScore = stale.totalScore;
    game.profile = stale;
    game.round = round;
    game.secondsLeft = round.seconds;
    game.stack
      ..clear()
      ..add('game');

    final hang = Completer<BilgiWalletReply>();
    final finishBodies = <Map<String, dynamic>>[];
    var phase = 'hang';
    server.remoteWallet = ({required String op, required Map<String, dynamic> body}) async {
      if (op == 'finish') {
        finishBodies.add(Map<String, dynamic>.from(body));
        if (phase == 'hang') return hang.future;
        if (phase == 'fail') throw TimeoutException('wallet finish');
        return BilgiWalletReply(profile: await server.profile());
      }
      if (op == 'sync') {
        if (phase == 'ok') return BilgiWalletReply(profile: await server.profile());
        return BilgiWalletReply(profile: stale);
      }
      return BilgiWalletReply(profile: await server.profile());
    };

    final pending = game.pick(0);
    expect(game.revealing, isTrue);
    game.continueReveal();
    expect(game.page, 'game');
    expect(game.revealing, isTrue);
    expect(game.round!.current, isNull);
    expect(game.round!.finished, isFalse);

    await pending;
    await pumpEventQueue();
    expect(game.page, 'result');
    expect(game.round!.finished, isTrue);
    expect(hang.isCompleted, isFalse);
    expect(game.profile!.gold, greaterThan(beforeGold));
    expect(game.profile!.totalScore, greaterThan(beforeScore));
    final gold = game.profile!.gold;
    final score = game.profile!.totalScore;
    expect((await server.profile()).gold, gold);
    expect((await server.profile()).totalScore, score);
    expect(finishBodies, hasLength(1));

    hang.complete(const BilgiWalletReply(error: 'Bağlantı kurulamadı.'));
    await pumpEventQueue();
    expect(game.page, 'result');
    expect(game.notice, isNull);
    expect(game.profile!.gold, gold);
    expect((await server.profile()).gold, gold);
    expect((await server.profile()).totalScore, score);

    phase = 'fail';
    final restarted = LunoBilgiServer(store, clock: () => clock)..remoteWallet = server.remoteWallet;
    final kept = await restarted.pullRemoteProfile();
    expect(kept.gold, gold);
    expect(kept.totalScore, score);
    expect(finishBodies, hasLength(2));
    expect(finishBodies[1], finishBodies.first);

    phase = 'ok';
    final acked = await restarted.pullRemoteProfile();
    expect(acked.gold, gold);
    expect(acked.totalScore, score);
    expect((await server.profile()).gold, gold);
    expect((await server.profile()).totalScore, score);
    expect(game.profile!.gold, gold);
    expect(game.profile!.totalScore, score);
    expect(finishBodies, hasLength(3));
    expect(finishBodies[2], finishBodies.first);
    expect(game.page, 'result');
  });

  test('post-game 2x lock counts only today', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    final game = BilgiController(server);
    addTearDown(game.dispose);
    final today = bilgiDayKey(DateTime.now());
    game.profile = (await server.profile()).copyWith(adDay: today, adDoubleToday: 2);
    expect(game.resultDoubleUsed, isFalse);
    game.profile = game.profile!.copyWith(adDoubleToday: 3);
    expect(game.resultDoubleUsed, isTrue);
    game.profile = game.profile!.copyWith(adDay: '2020-01-01', adDoubleToday: 3);
    expect(game.resultDoubleUsed, isFalse);
  });

  test('ensureSeed removes leftover trial questions and does not put them back', () async {
    final store = MemoryKeyValueStore();
    await store.put('questions', 'tr_din_01', {
      'id': 'tr_din_01',
      'categoryId': 'din',
      'text': 'leftover',
      'options': ['A', 'B', 'C', 'D'],
      'correct': 0,
      'difficulty': 'kolay',
      'explanation': '',
      'status': 'approved',
      'tags': <String>[],
    });
    await store.put('questions', 'custom_keep', {
      'id': 'custom_keep',
      'categoryId': 'genel',
      'text': 'keep',
      'options': ['A', 'B', 'C', 'D'],
      'correct': 0,
      'difficulty': 'kolay',
      'explanation': '',
      'status': 'approved',
      'tags': <String>['Atasözleri'],
    });
    final server = LunoBilgiServer(store);
    await server.ensureSeed();
    final rows = await server.questions();
    expect(rows.map((question) => question.id), ['custom_keep']);
    expect(await server.clearQuestionBankOnce(), 1);
    expect(await server.questions(), isEmpty);
    await server.saveQuestion(
      const BilgiQuestion(
        id: 'kept_after_clear',
        categoryId: 'genel',
        text: 'kalır',
        options: ['A', 'B', 'C', 'D'],
        correct: 0,
        difficulty: 'kolay',
        explanation: '',
        status: 'approved',
        tags: ['Atasözleri'],
      ),
    );
    expect(await server.clearQuestionBankOnce(), 0);
    expect((await server.questions()).map((question) => question.id), ['kept_after_clear']);
  });

  test('bilgi locale stays on the profile and question text falls back to Turkish', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 9, 28));
    final before = await server.profile();
    expect(before.locale, 'tr');
    expect(before.localeChosen, isFalse);
    expect(before.weekScore, 0);
    final next = await server.setLocale('de');
    expect(next.locale, 'de');
    expect(next.localeChosen, isTrue);
    expect(next.weekScore, before.weekScore);
    expect(next.totalScore, before.totalScore);
    const question = BilgiQuestion(
      id: 'q',
      categoryId: 'genel',
      text: 'Türkçe',
      options: ['A', 'B', 'C', 'D'],
      correct: 2,
      difficulty: 'kolay',
      explanation: 'TR',
      tags: ['Atasözleri'],
      translations: {
        'en': BilgiTranslation(text: 'English', options: ['A1', 'B1', 'C1', 'D1'], explanation: 'EN'),
      },
    );
    expect(question.shown('en').text, 'English');
    expect(question.shown('en').correct, 2);
    expect(question.shown('fr').text, 'Türkçe');
    expect(question.shown('tr').options, question.options);
  });

  test('first boot page is language until the player confirms a locale', () {
    expect(
      bilgiBootPage(maintenance: true, localeChosen: false, seenIntro: false),
      'maintenance',
    );
    expect(
      bilgiBootPage(maintenance: false, localeChosen: false, seenIntro: false),
      'language',
    );
    expect(
      bilgiBootPage(maintenance: false, localeChosen: false, seenIntro: true),
      'language',
    );
    expect(
      bilgiBootPage(maintenance: false, localeChosen: true, seenIntro: false),
      'intro',
    );
    expect(
      bilgiBootPage(maintenance: false, localeChosen: true, seenIntro: true),
      'home',
    );
  });

  test('change joker uses the spare question from the opening draw', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 9, 28));
    var draws = 0;
    server.remoteDraw = ({
      required String categoryId,
      required String subcategory,
      required String difficulty,
      required int count,
      required List<String> exclude,
      required String locale,
    }) async {
      draws += 1;
      expect(count, 4);
      return const [
        BilgiQuestion(
          id: 'open',
          categoryId: 'genel',
          text: 'İlk',
          options: ['A', 'B', 'C', 'D'],
          correct: 0,
          difficulty: 'kolay',
          explanation: '',
          tags: ['Atasözleri'],
        ),
        BilgiQuestion(
          id: 'spare',
          categoryId: 'genel',
          text: 'Yedek',
          options: ['A', 'B', 'C', 'D'],
          correct: 1,
          difficulty: 'kolay',
          explanation: '',
          tags: ['Atasözleri'],
        ),
      ];
    };
    final started = await server.startRound(
      modeId: 'hizli',
      categoryId: 'genel',
      subcategory: 'Atasözleri',
      difficulty: 'kolay',
      questionCount: 1,
    );
    expect(draws, 1);
    expect(started.round!.questions.single.id, 'open');
    await server.buyJoker('change');
    final changed = await server.useJoker(roundId: started.round!.id, type: 'change');
    expect(changed.message, isNull);
    expect(changed.round!.questions.single.id, 'spare');
    expect(draws, 1);
    await server.buyJoker('change');
    final again = await server.useJoker(roundId: started.round!.id, type: 'change');
    expect(again.message, '❓ Bu kategoride yeterli soru yok.');
    expect(draws, 1);
  });

  test('contest change joker swaps a spare of the same difficulty', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 10, 3));
    BilgiQuestion question(String id, String difficulty) {
      return BilgiQuestion(
        id: id,
        categoryId: tumuKarmaId,
        text: id,
        options: const ['A', 'B', 'C', 'D'],
        correct: 0,
        difficulty: difficulty,
        explanation: '',
        tags: const ['Deneme'],
      );
    }

    final started = await server.startRound(
      modeId: 'yarisma',
      categoryId: tumuKarmaId,
      difficulty: bilgiMixDifficulty,
      questionCount: 1,
      fixedQuestions: [question('kolay-1', 'kolay')],
      fixedSpares: [question('efsane-yedek', 'efsane'), question('kolay-yedek', 'kolay')],
      adCleared: true,
      chargeLife: false,
    );
    expect(started.round, isNotNull);
    expect(started.round!.questions, hasLength(1));
    await server.buyJoker('change');
    final changed = await server.useJoker(roundId: started.round!.id, type: 'change');
    expect(changed.message, isNull);
    expect(changed.round!.questions.single.id, 'kolay-yedek');
    expect(changed.round!.spares.single.id, 'efsane-yedek');
    await server.buyJoker('change');
    final again = await server.useJoker(roundId: started.round!.id, type: 'change');
    expect(again.message, '❓ Bu kategoride yeterli soru yok.');
    expect(changed.round!.questions.single.id, 'kolay-yedek');
  });

  test('a league shorter than 20 questions does not start', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 10, 3));
    BilgiQuestion question(String id) {
      return BilgiQuestion(
        id: id,
        categoryId: 'felsefe',
        text: id,
        options: const ['A', 'B', 'C', 'D'],
        correct: 0,
        difficulty: 'kolay',
        explanation: '',
        tags: const ['Antik'],
      );
    }

    final short = await server.startRound(
      modeId: 'lig',
      categoryId: 'felsefe',
      difficulty: 'hepsi',
      questionCount: 20,
      fixedQuestions: [question('only')],
      adCleared: true,
      chargeLife: false,
    );
    expect(short.message, '❓ Bu kategoride yeterli soru yok.');
    expect(short.round, isNull);

    final full = await server.startRound(
      modeId: 'lig',
      categoryId: 'felsefe',
      difficulty: 'hepsi',
      questionCount: 20,
      fixedQuestions: [for (var i = 0; i < 20; i++) question('q$i')],
      adCleared: true,
      chargeLife: false,
    );
    expect(full.message, isNull);
    expect(full.round!.questions, hasLength(20));
  });

  test('a category round uses the real pool and efsane stays empty', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 9, 28));
    expect(await server.questionCount('genel'), 0);
    expect(await server.questionCount(tumuKarmaId), 0);
    expect(await server.questionCount('felsefe'), 0);
    expect(await server.questionCount('felsefe', subcategory: 'Antik Yunan Felsefesi'), 0);
    final empty = await server.startRound(modeId: 'hizli', categoryId: 'genel', difficulty: 'kolay');
    expect(empty.message, '❓ Bu kategoride yeterli soru yok.');
    await server.saveQuestion(
      const BilgiQuestion(
        id: 'q-test',
        categoryId: 'genel',
        text: 'Deneme',
        options: ['A', 'B', 'C', 'D'],
        correct: 0,
        difficulty: 'kolay',
        explanation: '',
        status: 'approved',
        tags: ['Atasözleri'],
      ),
    );
    expect(await server.questionCount('genel'), 1);
    expect(await server.questionCount('genel', subcategory: 'Günlük Bilgi'), 0);
    final other = await server.startRound(modeId: 'hizli', categoryId: 'genel', subcategory: 'Günlük Bilgi', difficulty: 'kolay');
    expect(other.message, '❓ Bu kategoride yeterli soru yok.');
    final easy = await server.startRound(modeId: 'hizli', categoryId: 'genel', subcategory: 'Atasözleri', difficulty: 'kolay');
    expect(easy.message, '❓ Bu kategoride yeterli soru yok.');
    expect(easy.round, isNull);
    final legend = await server.startRound(modeId: 'sakin', categoryId: 'genel', difficulty: 'efsane');
    expect(legend.message, '❓ Bu kategoride yeterli soru yok.');
    final daily = await server.startRound(modeId: 'gunluk', categoryId: tumuKarmaId, questionCount: 1);
    expect(daily.round, isNotNull);
    await server.finish(daily.round!.id);
    final again = await server.startRound(modeId: 'gunluk');
    expect(again.message, 'Günlük oyun hakkınız doldu. Reklamla yeni oyun başlatın');
  });

  test('a stale local catalog does not close a category the server still opens', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    await server.saveCatalog({
      'inactive': ['spor'],
    });
    const question = BilgiQuestion(
      id: 'spor-open',
      categoryId: 'spor',
      text: 'Soru',
      options: ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'orta',
      explanation: 'aciklama',
      status: 'approved',
      tags: ['Futbol'],
    );
    final closed = await server.startRound(
      modeId: 'sakin',
      categoryId: 'spor',
      fixedQuestions: [question],
      questionCount: 1,
    );
    expect(closed.message, 'Bu kategori şu an oyunda değil.');
    final opened = await server.startRound(
      modeId: 'sakin',
      categoryId: 'spor',
      openedCatalog: {
        'authoritative': true,
        'custom': [
          {
            'id': 'spor',
            'group': 'F. Spor ve Oyun',
            'name': 'Spor',
            'emoji': '🏆',
            'subs': ['Futbol'],
            'active': true,
          },
          {
            'id': 'genel',
            'group': 'A. Temel Bilgi',
            'name': 'Genel Kültür',
            'emoji': '🧠',
            'subs': ['Spor'],
            'active': true,
          },
        ],
        'inactiveSubs': ['genel|Spor'],
      },
      fixedQuestions: [question],
      questionCount: 1,
    );
    expect(opened.message, isNull);
    expect(opened.round?.categoryId, 'spor');
  });

  test('hidden categories stay hidden and inactive ones leave the game list', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    expect(await server.hideCategory('afet'), isNull);
    final stored = resolveBilgiCategories(await server.catalog());
    expect(stored.where((category) => category.id == 'afet'), isEmpty);
    expect(stored, hasLength(67));
    await server.addCategory(group: 'A. Temel Bilgi', name: 'Deneme', emoji: '📚');
    final added = resolveBilgiCategories(await server.catalog());
    final created = added.last;
    expect(created.name, 'Deneme');
    await server.addSubcategory(created.id, 'Yeni Alt');
    await server.setSubActive('osmanli', 'Kuruluş', false);
    await server.setCategoryActive(created.id, false);
    final admin = resolveBilgiCategories(await server.catalog());
    final game = resolveBilgiCategories(await server.catalog(), playableOnly: true);
    expect(admin.where((category) => category.id == created.id).single.subs, contains('Yeni Alt'));
    expect(admin.where((category) => category.id == 'osmanli').single.subs, contains('Kuruluş'));
    expect(game.where((category) => category.id == created.id), isEmpty);
    expect(game.where((category) => category.id == 'osmanli').single.subs, isNot(contains('Kuruluş')));
    expect(await server.hideCategory('afet'), isNull);
    expect(resolveBilgiCategories(await server.catalog()).where((category) => category.id == 'afet'), isEmpty);
  });

  test('database catalog is the category list and a missing row stays gone', () {
    final catalog = {
      'authoritative': true,
      'custom': [
        {'id': 'felsefe', 'group': 'E. Felsefe ve İnanç', 'name': 'Felsefe', 'emoji': '🤔', 'subs': ['Antik Yunan Felsefesi'], 'active': true, 'popular': true},
      ],
    };
    final resolved = resolveBilgiCategories(catalog);
    expect(resolved, hasLength(1));
    expect(resolved.single.id, 'felsefe');
    expect(resolved.single.subs, ['Antik Yunan Felsefesi']);
    expect(resolved.single.popular, isTrue);
    expect(resolved.single.locales, isNull);
    expect(resolved.single.publishesIn('en'), isTrue);
    final turkishOnly = resolveBilgiCategories({
      'authoritative': true,
      'custom': [
        {
          'id': 'yeni',
          'group': 'A. Temel Bilgi',
          'name': 'Yeni',
          'emoji': '📚',
          'subs': ['Alt'],
          'locales': ['tr'],
        },
      ],
    });
    expect(turkishOnly.single.publishLocales, ['tr']);
    expect(turkishOnly.single.publishesIn('tr'), isTrue);
    expect(turkishOnly.single.publishesIn('en'), isFalse);
    expect(bilgiStoredLocales(''), isNull);
    expect(bilgiStoredLocales('["tr","en"]'), ['tr', 'en']);
    expect(resolveBilgiCategories({'authoritative': true, 'custom': const []}), isEmpty);
    final retired = resolveBilgiCategories({
      'authoritative': true,
      'custom': [
        {
          'id': 'mucit',
          'group': 'C. Bilim ve Teknoloji',
          'name': 'Mucitler ve İcatlar',
          'emoji': '🔧',
          'subs': ['Mucitler', 'İcatlar'],
        },
        {'id': 'bilim', 'group': 'C. Bilim ve Teknoloji', 'name': 'Bilim', 'emoji': '🔬', 'subs': ['Yöntem']},
      ],
    });
    expect(retired.map((category) => category.id), ['bilim']);
  });

  test('special event questions stay out unless that category is chosen', () {
    const event = BilgiCategory(
      id: 'etkinlik-ozel',
      group: bilgiSpecialEventGroup,
      name: 'Sonbahar',
      emoji: '🍂',
      subs: ['Tur'],
    );
    const normal = BilgiCategory(
      id: 'felsefe',
      group: 'E. Felsefe ve İnanç',
      name: 'Felsefe',
      emoji: '🤔',
      subs: ['Antik'],
    );
    const eventQuestion = BilgiQuestion(
      id: 'q1',
      categoryId: 'etkinlik-ozel',
      text: 'Soru',
      options: ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'kolay',
      explanation: '',
      tags: ['Tur'],
    );
    const normalQuestion = BilgiQuestion(
      id: 'q2',
      categoryId: 'felsefe',
      text: 'Soru',
      options: ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'kolay',
      explanation: '',
      tags: ['Antik'],
    );
    final categories = [event, normal];
    expect(bilgiPlayableQuestion(eventQuestion, categories, categoryId: tumuKarmaId), isFalse);
    expect(bilgiPlayableQuestion(eventQuestion, categories, categoryId: 'felsefe'), isFalse);
    expect(bilgiPlayableQuestion(eventQuestion, categories, categoryId: 'etkinlik-ozel'), isTrue);
    expect(bilgiPlayableQuestion(eventQuestion, categories, categoryId: 'etkinlik-ozel', subcategory: 'Tur'), isTrue);
    expect(bilgiPlayableQuestion(normalQuestion, categories, categoryId: tumuKarmaId), isTrue);
  });

  test('group headings have a name in every extra language', () {
    const locales = ['en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl'];
    for (final group in bilgiGroups) {
      expect(bilgiGroupLabel('tr', group), isNull);
      final prefixed = group.length > 2 && group[1] == '.';
      for (final locale in locales) {
        final label = bilgiGroupLabel(locale, group);
        expect(label, isNotNull);
        expect(label!.trim(), isNotEmpty);
        if (prefixed) expect(label.startsWith(group.substring(0, 2)), isTrue);
      }
    }
  });

  test('stored question fields round-trip into the edit model', () async {
    const question = BilgiQuestion(
      id: 'imp123',
      categoryId: 'osmanli',
      text: "Osmanlı'nın kurucusu?",
      options: ['Orhan', 'Osman', 'Murat', 'Bayezid'],
      correct: 1,
      difficulty: 'kolay',
      explanation: 'Osman Bey kurmuştur.',
      hint: 'Bir kuruluş adı.',
      status: 'pending',
      tags: ['Kuruluş', 'tarih'],
    );
    final category = bilgiCategoryById('osmanli')!;
    final edit = BilgiQuestionFormData.fromQuestion(question, categorySubs: category.subs);
    expect(edit.id, 'imp123');
    expect(edit.text, question.text);
    expect(edit.options, question.options);
    expect(edit.correct, 1);
    expect(edit.categoryId, 'osmanli');
    expect(edit.subcategory, 'Kuruluş');
    expect(edit.difficulty, 'kolay');
    expect(edit.explanation, 'Osman Bey kurmuştur.');
    expect(edit.hint, 'Bir kuruluş adı.');
    expect(edit.status, 'pending');
    expect(edit.tags, ['tarih']);
    final saved = edit.toQuestion(asDraft: false);
    expect(saved.id, question.id);
    expect(saved.text, question.text);
    expect(saved.options, question.options);
    expect(saved.correct, question.correct);
    expect(saved.categoryId, question.categoryId);
    expect(saved.difficulty, question.difficulty);
    expect(saved.explanation, question.explanation);
    expect(saved.hint, question.hint);
    expect(saved.status, 'pending');
    expect(saved.tags, containsAll(['Kuruluş', 'tarih']));

    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store);
    await server.saveQuestion(question);
    await server.saveQuestion(saved.copyWith(text: "Osmanlı'nın kurucusu kimdir?"));
    final rows = await server.questions();
    expect(rows, hasLength(1));
    expect(rows.single.id, 'imp123');
    expect(rows.single.text, "Osmanlı'nın kurucusu kimdir?");
    expect(rows.single.categoryId, 'osmanli');
    expect(rows.single.tags, contains('Kuruluş'));
    expect(rows.single.status, 'pending');

    await server.saveQuestion(
      const BilgiQuestion(
        id: 'imp124',
        categoryId: 'osmanli',
        text: 'İkinci soru',
        options: ['A', 'B', 'C', 'D'],
        correct: 0,
        difficulty: 'kolay',
        explanation: '',
        status: 'pending',
        tags: ['Kuruluş'],
      ),
    );
    final both = await server.questions();
    expect(both.map((question) => question.id), containsAll(['imp123', 'imp124']));
  });

  test('a faulty question report requires an explanation', () {
    expect(bilgiReportNoteError(''), 'Açıklama zorunlu.');
    expect(bilgiReportNoteError('   '), 'Açıklama zorunlu.');
    expect(bilgiReportNoteError('Şık B de doğru.'), isNull);
  });

  test('csv explanation and every question field survive the save', () async {
    const raw =
        'soru,a,b,c,d,dogru,kategori,altkategori,zorluk,aciklama,ipucu\n'
        'Osmanlı\'nın kurucusu?,Orhan,Osman,Murat,Bayezid,B,Osmanlı Tarihi,Kuruluş,kolay,"Osman Bey, 1299\'da kurmuştur.",Beylik sınırında kurulmuştur.\n'
        'Eski satır?,A,B,C,D,A,Osmanlı Tarihi,Kuruluş,orta\n'
        'Açıklamalı?,A,B,C,D,A,Osmanlı Tarihi,Kuruluş,kolay,Kısa açıklama\n';
    final lines = raw.split('\n').map(parseBilgiCsvLine).toList();
    expect(lines[0].kind, BilgiCsvKind.header);
    expect(lines[1].kind, BilgiCsvKind.row);
    expect(lines[1].fields!.explanation, "Osman Bey, 1299'da kurmuştur.");
    expect(lines[1].fields!.hint, 'Beylik sınırında kurulmuştur.');
    expect(lines[2].fields!.explanation, isEmpty);
    expect(lines[2].fields!.hint, isEmpty);
    expect(lines[3].fields!.explanation, 'Kısa açıklama');
    expect(lines[3].fields!.hint, isEmpty);

    final fields = lines[1].fields!;
    final question = BilgiQuestion(
      id: 'impcsv1',
      categoryId: 'osmanli',
      text: fields.text,
      options: fields.options,
      correct: 1,
      difficulty: 'kolay',
      explanation: fields.explanation,
      hint: fields.hint,
      status: 'pending',
      tags: const ['Kuruluş'],
    );
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store);
    await server.saveQuestion(question);
    final stored = (await server.questions()).single;
    expect(sameStoredBilgiQuestion(stored, question), isTrue);
    expect(stored.explanation, "Osman Bey, 1299'da kurmuştur.");
    expect(stored.hint, 'Beylik sınırında kurulmuştur.');
    expect(stored.options, ['Orhan', 'Osman', 'Murat', 'Bayezid']);
    expect(stored.correct, 1);
    expect(stored.categoryId, 'osmanli');
    expect(stored.difficulty, 'kolay');
    expect(stored.status, 'pending');
    expect(stored.tags, ['Kuruluş']);

    final dropping = LunoBilgiServer(_DropFieldStore(MemoryKeyValueStore(), 'explanation'));
    expect(dropping.saveQuestion(question), throwsStateError);
  });

  test('daily rewards and ad rewards load even from a partial config', () {
    final fresh = BilgiConfig.fromMap(null);
    expect(fresh.dailyGold, [100, 200, 0, 300, 0, 500, 1000]);
    expect(fresh.dailyDiamond, [0, 0, 1, 0, 0, 0, 0]);
    expect(fresh.dailyJoker, [0, 0, 0, 0, 1, 0, 0]);
    expect(fresh.rewardedGold, 50);
    expect(fresh.rewardedGoldLimit, 10);

    final messy = BilgiConfig.fromMap({
      'rewardedGold': 40.0,
      'dailyGold': ['10', 20],
    });
    expect(messy.rewardedGold, 40);
    expect(messy.dailyGold, [10, 20, 0, 300, 0, 500, 1000]);
    expect(messy.dailyDiamond, [0, 0, 1, 0, 0, 0, 0]);
    expect(dayRewardAmount(messy.dailyGold, 0), 10);
    expect(dayRewardAmount(messy.dailyGold, 6), 1000);
    expect(rewardConfigStored(fresh.toMap()), isTrue);
    expect(rewardConfigStored({'dailyGold': [1]}), isFalse);
  });

  test('approval and category switches need every language filled', () {
    const bare = BilgiQuestion(
      id: 'q1',
      categoryId: 'genel',
      text: 'Soru',
      options: ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'kolay',
      explanation: 'Çünkü',
      status: 'pending',
      tags: ['Atasözleri'],
    );
    expect(
      bilgiApproveTranslationsJson(keepStored: true, submitted: '{}', stored: '{"en":{}}'),
      '{"en":{}}',
    );
    expect(
      bilgiApproveTranslationsJson(keepStored: false, submitted: '{}', stored: '{"en":{}}'),
      '{}',
    );
    expect(bilgiApproveTranslationsJson(keepStored: true, submitted: '{}', stored: '  '), '{}');
    expect(bilgiQuestionLanguagesReady(bare), isFalse);
    final full = bare.copyWith(translations: {
      for (final id in ['en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl'])
        id: const BilgiTranslation(text: 'Q', options: ['A', 'B', 'C', 'D'], explanation: 'Because'),
    });
    expect(bilgiQuestionLanguagesReady(full), isTrue);
    expect(bilgiQuestionLanguagesReady(bare, locales: const ['tr']), isTrue);
    expect(bilgiNamesReady(const {}, 'category', 'genel', locales: const ['tr']), isTrue);
    expect(bilgiExtraLocales(const ['tr', 'de']), ['de']);
    final shifted = bilgiMoveCorrectOption(
      const BilgiQuestion(
        id: 'capital',
        categoryId: 'cografya',
        text: 'Başkent?',
        options: ['Ankara', 'İstanbul', 'İzmir', 'Bursa'],
        correct: 0,
        difficulty: 'kolay',
        explanation: 'Çünkü',
        translations: {
          'en': BilgiTranslation(
            text: 'Capital?',
            options: ['Ankara', 'Istanbul', 'Izmir', 'Bursa'],
            explanation: 'Because',
          ),
        },
      ),
      2,
    );
    expect(shifted, isNotNull);
    expect(shifted!.correct, 2);
    expect(shifted.options[2], 'Ankara');
    expect(shifted.translations['en']!.options[2], 'Ankara');
    expect(shifted.text, 'Başkent?');
    expect(shifted.explanation, 'Çünkü');
    expect(shifted.translations['en']!.text, 'Capital?');
    expect(
      bilgiMoveCorrectOption(
        const BilgiQuestion(
          id: 'short',
          categoryId: 'cografya',
          text: 'Başkent?',
          options: ['Ankara', 'İstanbul', 'İzmir', 'Bursa'],
          correct: 0,
          difficulty: 'kolay',
          explanation: 'Çünkü',
          translations: {
            'en': BilgiTranslation(text: 'Capital?', options: ['Ankara', 'Istanbul', 'Izmir'], explanation: 'Because'),
          },
        ),
        2,
      ),
      isNull,
    );
    final balanced = bilgiBalanceAnswerLetters([
      for (var i = 0; i < 4; i++)
        BilgiQuestion(
          id: 'q$i',
          categoryId: 'felsefe',
          text: 'Soru $i',
          options: ['Doğru $i', 'Yanlış', 'Başka', 'Son'],
          correct: 0,
          difficulty: 'kolay',
          explanation: 'Çünkü',
        ),
    ]);
    expect(balanced, hasLength(3));
    expect(balanced.map((question) => question.correct).toList(), [1, 2, 3]);
    expect(balanced.every((question) => question.options[question.correct] == 'Doğru ${question.id.substring(1)}'), isTrue);
    final bySub = bilgiBalanceAnswerLetters([
      for (final tag in ['Antik', 'Modern'])
        for (var i = 0; i < 4; i++)
          BilgiQuestion(
            id: '$tag$i',
            categoryId: 'felsefe',
            text: 'Soru $tag $i',
            options: ['Doğru', 'Yanlış', 'Başka', 'Son'],
            correct: 0,
            difficulty: 'kolay',
            explanation: 'Çünkü',
            tags: [tag],
          ),
    ]);
    for (final tag in ['Antik', 'Modern']) {
      final letters = bySub.where((question) => question.tags.contains(tag)).map((question) => question.correct).toList();
      expect(letters, [1, 2, 3]);
    }
    expect(bilgiPendingApprovalReady(bare), isFalse);
    expect(bilgiPendingApprovalReady(full), isTrue);
    final approved = bilgiQuestionWithReviewStatus(full, 'approved');
    expect(approved.status, 'approved');
    expect(approved.rejectReason, '');
    final rejected = bilgiQuestionWithReviewStatus(
      full.copyWith(rejectReason: ''),
      'rejected',
    );
    expect(rejected.status, 'rejected');
    expect(rejected.rejectReason, 'Reddedildi');
    expect(bilgiNamesReady(const {}, 'category', 'genel'), isFalse);
    expect(
      bilgiNamesReady(
        {for (final id in ['en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl']) '$id|category|genel': 'General'},
        'category',
        'genel',
      ),
      isTrue,
    );
    final closed = resolveBilgiCategories(bilgiCatalogClosedUnless(null, const {}, const {}), playableOnly: true);
    expect(closed, isEmpty);
  });

  test('hint clue hides the correct option and its letter', () {
    const options = ['Paris', 'Lyon', 'Nice', 'Lille'];
    final clue = bilgiHintClue(
      explanation: "Doğru cevap Paris'tir. Fransa'nın başkentidir.",
      options: options,
      correct: 0,
    );
    expect(clue, "Fransa'nın başkentidir.");
    expect(clue.toLowerCase(), isNot(contains('paris')));
    expect(clue.toLowerCase(), isNot(contains('doğru cevap')));
    expect(clue, isNot(contains('Bir şıkkı ele')));

    expect(
      bilgiHintClue(
        explanation: 'Doğru cevap: Paris',
        options: options,
        correct: 0,
      ),
      bilgiHintWithheld,
    );
    expect(
      bilgiHintClue(
        explanation: "Osmanlı Devleti'nin kurucusu Osman Bey'dir.",
        options: const ['Osman', 'Orhan', 'Murat', 'Bayezid'],
        correct: 0,
      ),
      bilgiHintWithheld,
    );
    final lettered = bilgiHintClue(
      explanation: "A şıkkı Paris'tir. Fransa'nın başkentidir.",
      options: options,
      correct: 0,
    );
    expect(lettered, "Fransa'nın başkentidir.");
    expect(lettered, isNot(contains('Paris')));
    expect(lettered.contains(RegExp(r'\bA\b')), isFalse);
    expect(
      bilgiHintClue(explanation: '', options: options, correct: 0),
      bilgiHintWithheld,
    );
    expect(
      bilgiHintClue(
        explanation: "Bu antlaşma 1923'te imzalandı.",
        options: const ['Lozan', 'Versay', 'Sevr', 'Mondros'],
        correct: 0,
      ),
      "Bu antlaşma 1923'te imzalandı.",
    );
  });

  test('hint joker stays unused when the question has no hint', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 9, 28));
    server.remoteDraw = ({
      required String categoryId,
      required String subcategory,
      required String difficulty,
      required int count,
      required List<String> exclude,
      required String locale,
    }) async {
      return const [
        BilgiQuestion(
          id: 'hint-q',
          categoryId: 'genel',
          text: 'Fransa’nın başkenti?',
          options: ['Paris', 'Lyon', 'Nice', 'Lille'],
          correct: 0,
          difficulty: 'kolay',
          explanation: "Doğru cevap Paris'tir. Fransa'nın başkentidir.",
          tags: ['Atasözleri'],
        ),
      ];
    };
    final started = await server.startRound(
      modeId: 'hizli',
      categoryId: 'genel',
      subcategory: 'Atasözleri',
      difficulty: 'kolay',
      questionCount: 1,
    );
    final bought = await server.buyJoker('hint');
    final stock = bought.profile!.jokers['hint'];
    final used = await server.useJoker(roundId: started.round!.id, type: 'hint');
    expect(used.message, isNull);
    expect(used.round!.hint, isEmpty);
    expect(used.round!.hidden, isEmpty);
    expect(used.round!.jokersUsed, started.round!.jokersUsed);
    expect(used.profile!.jokers['hint'], stock);
  });

  test('hint joker uses the stored hint and does not hide options', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 9, 28));
    server.remoteDraw = ({
      required String categoryId,
      required String subcategory,
      required String difficulty,
      required int count,
      required List<String> exclude,
      required String locale,
    }) async {
      return const [
        BilgiQuestion(
          id: 'hint-q',
          categoryId: 'genel',
          text: 'Fransa’nın başkenti?',
          options: ['Paris', 'Lyon', 'Nice', 'Lille'],
          correct: 0,
          difficulty: 'kolay',
          explanation: "Doğru cevap Paris'tir. Fransa'nın başkentidir.",
          hint: 'Sen nehri bu kentten geçer.',
          tags: ['Atasözleri'],
          translations: {
            'en': BilgiTranslation(
              text: 'Capital of France?',
              options: ['Paris', 'Lyon', 'Nice', 'Lille'],
              explanation: 'Paris is the capital.',
              hint: 'The Seine runs through this city.',
            ),
          },
        ),
      ];
    };
    final started = await server.startRound(
      modeId: 'hizli',
      categoryId: 'genel',
      subcategory: 'Atasözleri',
      difficulty: 'kolay',
      questionCount: 1,
    );
    await server.buyJoker('hint');
    final usedBefore = started.round!.jokersUsed;
    final used = await server.useJoker(roundId: started.round!.id, type: 'hint', locale: 'en');
    expect(used.message, isNull);
    expect(used.round!.hint, 'The Seine runs through this city.');
    expect(used.round!.hidden, isEmpty);
    expect(used.round!.jokersUsed, usedBefore + 1);
    expect(used.profile!.jokers['hint'], 0);
  });

  test('a stored hint is used before the explanation', () {
    const options = ['Paris', 'Lyon', 'Nice', 'Lille'];
    expect(
      bilgiPlayHint(
        hint: 'Sen nehri bu kentten geçer.',
        explanation: "Doğru cevap Paris'tir. Fransa'nın başkentidir.",
        options: options,
        correct: 0,
      ),
      'Sen nehri bu kentten geçer.',
    );
    expect(
      bilgiPlayHint(
        hint: '  ',
        explanation: "Doğru cevap Paris'tir. Fransa'nın başkentidir.",
        options: options,
        correct: 0,
      ),
      isEmpty,
    );
    final question = BilgiQuestion(
      id: 'q',
      categoryId: 'genel',
      text: 'Başkent?',
      options: options,
      correct: 0,
      difficulty: 'kolay',
      explanation: 'Paris başkenttir.',
      hint: 'Bir Avrupa başkenti.',
      translations: {
        'en': BilgiTranslation(
          text: 'Capital?',
          options: options,
          explanation: 'Paris is the capital.',
          hint: 'A European capital.',
        ),
        'de': BilgiTranslation(
          text: 'Hauptstadt?',
          options: options,
          explanation: 'Paris ist die Hauptstadt.',
        ),
      },
    );
    expect(question.shown('en').hint, 'A European capital.');
    expect(question.shown('de').hint, 'Bir Avrupa başkenti.');
    expect(bilgiTranslatedHintReady('', ''), isTrue);
    expect(bilgiTranslatedHintReady('ipucu', ''), isFalse);
    expect(bilgiTranslatedHintReady('ipucu', 'clue'), isTrue);
    expect(bilgiHintTranslateRule(''), isEmpty);
    expect(bilgiHintTranslateRule('   '), isEmpty);
    final rule = bilgiHintTranslateRule('ipucu');
    expect(rule, contains('non-empty hint'));
    expect(rule, contains('500'));
    expect(rule, contains('A, B, C, or D'));
    expect(rule, contains('include the wording'));
    expect(rule, contains('An empty hint is not allowed'));
    expect(rule, isNot(contains('Do not name the correct option')));
    final longHint = 'a' * 501;
    expect(bilgiClipTranslatedHint(longHint).length, 500);
    expect(bilgiClipTranslatedHint(' kısa '), 'kısa');
    expect(bilgiTranslatedHintReady('ipucu', bilgiClipTranslatedHint(longHint)), isTrue);
  });

  test('gold help lists ad, shop, and claimable daily gold only', () {
    final ready = bilgiGoldHelpOptions(
      rewardedGold: 50,
      shopGoldA: 1000,
      shopGoldB: 5000,
      dailyGoldReady: true,
      dailyGold: 200,
    );
    expect(ready.map((option) => option.kind).toList(), [
      BilgiGoldHelpKind.ad,
      BilgiGoldHelpKind.shop,
      BilgiGoldHelpKind.daily,
    ]);
    expect(ready[0].subtitle, '50 altın');
    expect(ready[1].subtitle, '1000 veya 5000 altın');
    expect(ready[2].subtitle, '200 altın');
    expect(ready.any((option) => '${option.title} ${option.subtitle}'.toLowerCase().contains('bekle')), isFalse);

    final diamondDay = bilgiGoldHelpOptions(
      rewardedGold: 50,
      shopGoldA: 1000,
      shopGoldB: 5000,
      dailyGoldReady: true,
      dailyGold: 0,
    );
    expect(diamondDay.map((option) => option.kind).toList(), [
      BilgiGoldHelpKind.ad,
      BilgiGoldHelpKind.shop,
    ]);

    final claimed = bilgiGoldHelpOptions(
      rewardedGold: 50,
      shopGoldA: 1000,
      shopGoldB: 5000,
      dailyGoldReady: false,
      dailyGold: 100,
    );
    expect(claimed.map((option) => option.kind).toList(), [
      BilgiGoldHelpKind.ad,
      BilgiGoldHelpKind.shop,
    ]);
    expect(bilgiNoticeIsGoldShort('🪙 Yeterli altının yok. Mağazadan altın al.'), isTrue);
    expect(bilgiNoticeIsGoldShort('Yeterli altının yok.'), isTrue);
    expect(bilgiNoticeIsGoldShort('Canın bitti'), isFalse);
  });

  test('shared noun phrase does not make options inseparable', () {
    const marx = [
      'Üretim araçlarını reddeden sınıf',
      'Üretim araçlarını yok sayan sınıf',
      'Üretim araçlarına sahip olmayan sınıf',
      'Üretim araçlarına sahip sınıf',
    ];
    expect(bilgiSimilarOptionsIssue(marx), isNull);
    expect(bilgiOptionsInseparable(marx[0], marx[2]), isFalse);
    expect(bilgiOptionsInseparable(marx[2], marx[3]), isFalse);
    expect(bilgiOptionsInseparable('göze göz', 'kısasa kısas'), isFalse);
    expect(bilgiOptionsInseparable('Paris.', 'Paris'), isTrue);
    expect(bilgiOptionsInseparable('Paris', 'Paris ve'), isTrue);
    expect(bilgiOptionsInseparable('Roma', 'Roma ile'), isTrue);
    expect(bilgiOptionsInseparable('kedi ve köpek', 'kedi ile köpek'), isTrue);
    expect(
      bilgiSimilarOptionsIssue(['Paris.', 'Lyon', 'Paris', 'Nice']),
      bilgiSimilarOptionWarning,
    );
  });
}

class _DropFieldStore implements KeyValueStore {
  _DropFieldStore(this._inner, this._field);

  final MemoryKeyValueStore _inner;
  final String _field;

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) {
    final copy = Map<String, dynamic>.from(value);
    if (copy.containsKey(_field)) copy[_field] = '';
    return _inner.put(box, key, copy);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) => _inner.get(box, key);

  @override
  Future<void> delete(String box, String key) => _inner.delete(box, key);

  @override
  Future<List<Map<String, dynamic>>> values(String box) => _inner.values(box);

  @override
  Future<void> putMeta(String key, String value) => _inner.putMeta(key, value);

  @override
  Future<String?> getMeta(String key) => _inner.getMeta(key);
}
