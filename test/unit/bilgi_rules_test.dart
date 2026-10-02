import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_csv.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_questions.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_trial_questions.dart';

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
    expect(bilgiCategories, hasLength(71));
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
      expect(count, 2);
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
    expect(easy.round!.questions, hasLength(1));
    final legend = await server.startRound(modeId: 'sakin', categoryId: 'genel', difficulty: 'efsane');
    expect(legend.message, '❓ Bu kategoride yeterli soru yok.');
    final daily = await server.startRound(modeId: 'gunluk', categoryId: tumuKarmaId, questionCount: 1);
    expect(daily.round, isNotNull);
    await server.finish(daily.round!.id);
    final again = await server.startRound(modeId: 'gunluk');
    expect(again.message, 'Günlük oyun hakkınız doldu. Reklamla yeni oyun başlatın');
  });

  test('hidden categories stay hidden and inactive ones leave the game list', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    expect(await server.hideCategory('afet'), isNull);
    final stored = resolveBilgiCategories(await server.catalog());
    expect(stored.where((category) => category.id == 'afet'), isEmpty);
    expect(stored, hasLength(70));
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

  test('group headings have a name in every extra language', () {
    const locales = ['en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl'];
    for (final group in bilgiGroups) {
      expect(bilgiGroupLabel('tr', group), isNull);
      for (final locale in locales) {
        final label = bilgiGroupLabel(locale, group);
        expect(label, isNotNull);
        expect(label!.trim(), isNotEmpty);
        expect(label.startsWith(group.substring(0, 2)), isTrue);
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
        'soru,a,b,c,d,dogru,kategori,altkategori,zorluk,aciklama\n'
        'Osmanlı\'nın kurucusu?,Orhan,Osman,Murat,Bayezid,B,Osmanlı Tarihi,Kuruluş,kolay,"Osman Bey, 1299\'da kurmuştur."\n'
        'Eski satır?,A,B,C,D,A,Osmanlı Tarihi,Kuruluş,orta\n';
    final lines = raw.split('\n').map(parseBilgiCsvLine).toList();
    expect(lines[0].kind, BilgiCsvKind.header);
    expect(lines[1].kind, BilgiCsvKind.row);
    expect(lines[1].fields!.explanation, "Osman Bey, 1299'da kurmuştur.");
    expect(lines[2].fields!.explanation, isEmpty);

    final fields = lines[1].fields!;
    final question = BilgiQuestion(
      id: 'impcsv1',
      categoryId: 'osmanli',
      text: fields.text,
      options: fields.options,
      correct: 1,
      difficulty: 'kolay',
      explanation: fields.explanation,
      status: 'pending',
      tags: const ['Kuruluş'],
    );
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store);
    await server.saveQuestion(question);
    final stored = (await server.questions()).single;
    expect(sameStoredBilgiQuestion(stored, question), isTrue);
    expect(stored.explanation, "Osman Bey, 1299'da kurmuştur.");
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

  test('hint joker stores a clue and does not hide options', () async {
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
    await server.buyJoker('hint');
    final used = await server.useJoker(roundId: started.round!.id, type: 'hint');
    expect(used.message, isNull);
    expect(used.round!.hint, "Fransa'nın başkentidir.");
    expect(used.round!.hint, isNot(contains('Paris')));
    expect(used.round!.hidden, isEmpty);
    expect(used.round!.jokerMax, started.round!.jokerMax);
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
