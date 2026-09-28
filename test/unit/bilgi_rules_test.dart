import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_questions.dart';
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

  test('a category round uses the real pool and efsane stays empty', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime(2026, 9, 28));
    expect(await server.questionCount('genel'), 0);
    expect(await server.questionCount(tumuKarmaId), 15);
    expect(await server.questionCount('felsefe'), 15);
    expect(await server.questionCount('felsefe', subcategory: 'Antik Yunan Felsefesi'), 3);
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
}
