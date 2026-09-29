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
    expect(bilgiCategories, hasLength(72));
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
    expect(again.message, '📅 Bugünkü hakkını kullandın.');
  });

  test('hidden categories stay hidden and inactive ones leave the game list', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    expect(await server.hideCategory('afet'), isNull);
    final stored = resolveBilgiCategories(await server.catalog());
    expect(stored.where((category) => category.id == 'afet'), isEmpty);
    expect(stored, hasLength(71));
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
