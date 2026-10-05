import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';

BilgiProfile _player(
  String id, {
  int total = 0,
  int week = 0,
  String weekId = '2026-W40',
  String category = 'genel',
  int categoryTotal = 0,
  int categoryWeek = 0,
  bool played = true,
  int gold = 100,
  String rewardWeek = '',
  String email = 'yes',
}) {
  return BilgiProfile.fromMap({
    'id': id,
    'username': id,
    'email': email == 'yes' ? '$id@luno.test' : email,
    'gold': gold,
    'totalScore': total,
    'weekScore': week,
    'weekId': weekId,
    'leagueRewardWeek': rewardWeek,
    'categoriesPlayed': played ? [category] : <String>[],
    if (categoryTotal > 0 || categoryWeek > 0)
      'categoryScores': {
        category: {'total': categoryTotal, 'week': categoryWeek},
      },
  });
}

Map<String, int> _enoughPublished() => {
      for (final category in bilgiCategories) category.id: bilgiMinPublishedQuestions,
    };

void main() {
  test('Istanbul Monday opens the new Bilgi week', () {
    final monday = DateTime.utc(2026, 10, 4, 21);
    final sunday = DateTime.utc(2026, 10, 4, 20);
    expect(bilgiWeekId(monday), DateKeys.weekId(DateTime(2026, 10, 5)));
    expect(bilgiWeekId(sunday), DateKeys.weekId(DateTime(2026, 10, 4)));
    expect(bilgiWeekId(monday), isNot(bilgiWeekId(sunday)));
    expect(bilgiDayKey(DateTime.utc(2026, 10, 1, 22)), '2026-10-02');
    expect(bilgiDayKey(DateTime.utc(2026, 10, 1, 20)), '2026-10-01');
  });

  test('a round writes only that category, and karma stays general', () {
    final start = _player('ada', weekId: bilgiWeekId(DateTime.utc(2026, 10, 1)));
    final now = DateTime.utc(2026, 10, 1, 12);
    final played = bilgiAddScore(start, points: 40, categoryId: 'genel', now: now);
    expect(played.totalScore, 40);
    expect(played.weekScore, 40);
    expect(played.categoryScores['genel']?.total, 40);
    expect(played.categoryScores['genel']?.week, 40);
    expect(played.categoryScores.containsKey('tarih'), isFalse);
    final karma = bilgiAddScore(played, points: 15, categoryId: tumuKarmaId, now: now);
    expect(karma.totalScore, 55);
    expect(karma.weekScore, 55);
    expect(karma.categoryScores['genel']?.total, 40);
    expect(karma.categoryScores.keys, ['genel']);
    final doubled = bilgiAddScore(karma, points: 15, categoryId: 'genel', now: now);
    expect(doubled.categoryScores['genel']?.total, 55);
    expect(doubled.categoryScores['genel']?.week, 55);
  });

  test('a category league is listed only where this player has points', () {
    final scored = _player('ada', category: 'genel', categoryTotal: 40, total: 40);
    final playedEmpty = _player('ada', category: 'felsefe', categoryTotal: 0, played: true, total: 40);
    final counts = _enoughPublished();
    expect(bilgiMyOpenLeagueIds(scored, publishedCounts: counts), ['genel']);
    expect(bilgiPlayedCategory(playedEmpty, 'felsefe'), isTrue);
    expect(bilgiMyOpenLeagueIds(playedEmpty, publishedCounts: counts), isEmpty);
    final open = bilgiOpenCategoryIds([
      scored,
      _player('berk', category: 'felsefe', categoryTotal: 10, total: 10),
    ]);
    expect(open, contains('felsefe'));
    expect(bilgiMyOpenLeagueIds(scored, publishedCounts: counts), isNot(contains('felsefe')));
  });

  test('a category under 60 published questions is hidden from player leagues', () {
    final user = _player('ada', category: 'genel', categoryTotal: 40, total: 40).copyWith(
      categoryScores: const {
        'genel': BilgiCategoryPoints(total: 40),
        'felsefe': BilgiCategoryPoints(total: 15),
        'karma': BilgiCategoryPoints(total: 8),
      },
    );
    expect(bilgiCategoryListed('felsefe', null), isFalse);
    expect(bilgiCategoryListed('felsefe', 0), isFalse);
    expect(bilgiCategoryListed('felsefe', bilgiMinPublishedQuestions - 1), isFalse);
    expect(bilgiCategoryListed('felsefe', bilgiMinPublishedQuestions), isTrue);
    expect(bilgiCategoryListed('karma', 12), isFalse);
    expect(bilgiCategoryListed('karma', bilgiMinPublishedQuestions), isTrue);
    expect(bilgiMinPublishedQuestions, 60);
    expect(bilgiMixQuotas(bilgiMinPublishedQuestions), [15, 15, 15, 15]);
    final thin = {
      'mitoloji|Mezopotamya Mitolojisi|kolay': 7,
      'mitoloji|Mezopotamya Mitolojisi|orta': 187,
      'mitoloji|Mezopotamya Mitolojisi|zor': 80,
      'mitoloji|Mezopotamya Mitolojisi|efsane': 8,
    };
    expect(bilgiSubListed('mitoloji', 'Mezopotamya Mitolojisi', thin), isFalse);
    expect(bilgiCategoryListed('mitoloji', 7 + 187 + 80 + 8), isTrue);
    final ready = {
      for (final level in bilgiDifficultyLevels) 'mitoloji|Yunan Mitolojisi|$level': 15,
    };
    expect(bilgiSubListed('mitoloji', 'Yunan Mitolojisi', ready), isTrue);
    ready['mitoloji|Yunan Mitolojisi|efsane'] = 14;
    expect(bilgiSubListed('mitoloji', 'Yunan Mitolojisi', ready), isFalse);
    expect(bilgiPublishedSubReady('mitoloji', 'Yunan Mitolojisi', [15, 15, 15, 15]), isTrue);
    expect(bilgiPublishedSubReady('mitoloji', 'Yunan Mitolojisi', [172, 103, 14, 69]), isFalse);
    final counts = _enoughPublished()
      ..['felsefe'] = 59
      ..['karma'] = 12;
    final mine = bilgiMyOpenLeagueIds(user, publishedCounts: counts);
    expect(mine, contains('genel'));
    expect(mine, isNot(contains('felsefe')));
    expect(mine, isNot(contains('karma')));
    final unknown = Map<String, int>.from(counts)..remove('genel');
    expect(bilgiMyOpenLeagueIds(user, publishedCounts: unknown), isNot(contains('genel')));
  });

  test('a guest with points ranks in general and only in a category they played', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final week = bilgiWeekId(now);
    final guest = _player(
      'misafir',
      email: '',
      total: 40,
      week: 40,
      weekId: week,
      categoryTotal: 40,
      categoryWeek: 40,
      gold: 100,
    );
    final other = _player(
      'ada',
      category: 'tarih',
      total: 10,
      week: 10,
      weekId: week,
      categoryTotal: 10,
      categoryWeek: 10,
    );
    final banned = _player('ban', email: '', total: 99, week: 99, weekId: week).copyWith(banned: true);
    final shell = _player('shell', total: 80, week: 80, weekId: week).copyWith(guestHere: true, email: '');
    final users = [guest, other, banned, shell];
    final general = bilgiLeagueSnapshot(
      users: users,
      scope: 'global',
      categoryWeekly: true,
      now: now,
      seedIfShort: false,
    );
    expect(general.rows.map((row) => row.id), ['misafir', 'ada']);
    final played = bilgiLeagueSnapshot(
      users: users,
      scope: 'category',
      categoryId: 'genel',
      categoryWeekly: true,
      now: now,
      seedIfShort: false,
    );
    expect(played.rows.map((row) => row.id), ['misafir']);
    final unplayed = bilgiLeagueSnapshot(
      users: users,
      scope: 'category',
      categoryId: 'tarih',
      now: now,
      seedIfShort: false,
    );
    expect(unplayed.rows.any((row) => row.id == 'misafir'), isFalse);
    final paid = applyBilgiSettlement(users, week: week, now: DateTime.utc(2026, 10, 8, 12));
    expect(paid.firstWhere((user) => user.id == 'misafir').gold, greaterThan(100));
    expect(paid.firstWhere((user) => user.id == 'ban').gold, banned.gold);
  });

  test('a player is listed only in a category they have played', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final played = _player('ada', categoryTotal: 20, total: 20);
    final other = _player('berk', category: 'tarih', played: false, total: 90);
    final snap = bilgiLeagueSnapshot(
      users: [played, other],
      me: played,
      scope: 'category',
      categoryId: 'genel',
      now: now,
    );
    expect(snap.closed, isFalse);
    expect(snap.realCount, 1);
    expect(snap.seed, isTrue);
    expect(snap.rows.first.id, 'ada');
    expect(snap.rows.first.seed, isFalse);
    expect(snap.rows.any((row) => row.id == 'berk'), isFalse);
    final missing = bilgiLeagueSnapshot(
      users: [played],
      scope: 'category',
      categoryId: 'tarih',
      now: now,
    );
    expect(missing.closed, isTrue);
    expect(missing.rows, isEmpty);
    expect(missing.seed, isFalse);
    expect(bilgiOpenCategoryIds([played]), ['genel']);
  });

  test('under 100 real players the public board is the sample and admin keeps the real order', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final users = [for (var i = 0; i < 99; i++) _player('p$i', total: 1000 - i)];
    final shown = bilgiLeagueSnapshot(users: users, scope: 'global', now: now);
    expect(shown.realCount, 99);
    expect(shown.seed, isTrue);
    expect(shown.rows, hasLength(100));
    expect(shown.rows.first.id, 'p0');
    expect(shown.rows[98].id, 'p98');
    expect(shown.rows[98].rank, 99);
    expect(shown.rows.where((row) => row.seed), hasLength(1));
    expect(shown.rows.last.score, 0);
    final admin = bilgiLeagueSnapshot(users: users, scope: 'global', now: now, seedIfShort: false);
    expect(admin.seed, isFalse);
    expect(admin.rows, hasLength(99));
    expect(admin.rows.first.id, 'p0');
    expect(admin.rows.last.id, 'p98');
    final full = bilgiLeagueSnapshot(
      users: [...users, _player('p99', total: 1)],
      scope: 'global',
      now: now,
    );
    expect(full.seed, isFalse);
    expect(full.realCount, 100);
    expect(full.rows.first.seed, isFalse);
  });

  test('a sample row takes no title and the 11th real player loses the title', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final users = [
      for (var i = 0; i < 11; i++) _player('c$i', categoryTotal: 500 - i, total: 500 - i),
    ];
    expect(bilgiLeagueTitle(users[9], users), 'Genel Kültür Ustası');
    expect(bilgiLeagueTitle(users[10], users), isEmpty);
    final shown = bilgiLeagueSnapshot(users: users, me: users[9], scope: 'category', categoryId: 'genel', now: now);
    expect(shown.title, 'Genel Kültür Ustası');
    expect(shown.rows.where((row) => row.seed).every((row) => row.leagueTitle.isEmpty), isTrue);
    expect(shown.rows[9].id, 'c9');
    expect(shown.rows[9].rank, 10);
    expect(shown.rows[9].leagueTitle, 'Genel Kültür Ustası');
    expect(shown.rows[10].id, 'c10');
    expect(shown.rows[10].leagueTitle, isEmpty);
    final real = bilgiLeagueSnapshot(
      users: users,
      scope: 'category',
      categoryId: 'genel',
      now: now,
      seedIfShort: false,
    );
    expect(real.rows[9].leagueTitle, 'Genel Kültür Ustası');
    expect(real.rows.length, 11);
    expect(real.rows[10].leagueTitle, isEmpty);
  });

  test('tiers follow the live weekly score', () {
    expect(bilgiTier(0), 'Bronz');
    expect(bilgiTier(499), 'Bronz');
    expect(bilgiTier(500), 'Gümüş');
    expect(bilgiTier(2000), 'Altın');
    expect(bilgiTier(6000), 'Elmas');
    expect(bilgiTier(15000), 'Efsane');
  });

  test('league reward note splits ranks and gold', () {
    const text =
        'Genel 2. sıra • Genel Kültür 2. sıra • Uzay ve Astronomi 4. sıra • Doğal Afetler 2. sıra • Felsefe 1. sıra • Mitoloji 1. sıra • 8100 altın';
    final note = bilgiLeagueRewardNote(text);
    expect(note, isNotNull);
    expect(note!.gold, 8100);
    expect(note.lines, [
      'Genel 2. sıra',
      'Genel Kültür 2. sıra',
      'Uzay ve Astronomi 4. sıra',
      'Doğal Afetler 2. sıra',
      'Felsefe 1. sıra',
      'Mitoloji 1. sıra',
    ]);
    expect(bilgiLeagueRewardNote('Bağlantı kurulamadı.'), isNull);
    expect(bilgiLeagueRewardNote('Yeterli altının yok'), isNull);
  });

  test('Monday settlement pays once, then wipes weekly points', () {
    final now = DateTime.utc(2026, 10, 5, 12);
    final week = bilgiPreviousWeekId(now);
    final users = [
      for (var i = 0; i < 11; i++)
        _player(
          'c$i',
          week: 0,
          weekId: week,
          categoryTotal: 500 - i,
          categoryWeek: 500 - i,
          gold: 100,
        ),
    ];
    final paid = applyBilgiSettlement(users, week: week, now: now);
    final first = paid.firstWhere((user) => user.id == 'c0');
    final tenth = paid.firstWhere((user) => user.id == 'c9');
    final eleventh = paid.firstWhere((user) => user.id == 'c10');
    expect(first.gold, 100 + 1000);
    expect(first.weekScore, 0);
    expect(first.categoryScores['genel']?.week, 0);
    expect(first.categoryScores['genel']?.total, 500);
    expect(first.totalScore, 0);
    expect(first.leagueRewardText, contains('Genel Kültür'));
    expect(first.leagueRewardWeek, week);
    expect(tenth.gold, 100 + 100);
    expect(eleventh.gold, 100);
    expect(eleventh.leagueRewardText, isEmpty);
    final again = applyBilgiSettlement(paid, week: week, now: now);
    expect(again.firstWhere((user) => user.id == 'c0').gold, first.gold);
    expect(bilgiWeeksToSettle(week, now), isEmpty);
    expect(bilgiWeeksToSettle(null, now), [week]);
  });

  test('a stale upload cannot restore a settled week or erase reward gold', () {
    final server = _player('ada', weekId: '2026-W41', week: 0, gold: 11100, rewardWeek: '2026-W40', categoryTotal: 20);
    final client = _player('ada', weekId: '2026-W40', week: 800, gold: 100, categoryTotal: 20, categoryWeek: 800);
    final merged = mergeBilgiLeague(server, client, settledWeek: '2026-W40');
    expect(merged.weekId, '2026-W41');
    expect(merged.weekScore, 0);
    expect(merged.gold, 11100);
    expect(merged.categoryScores['genel']?.week, 0);
    expect(merged.categoryScores['genel']?.total, 20);
  });

  test('profile keeps last week score until the server settles it', () async {
    final store = MemoryKeyValueStore();
    final early = LunoBilgiServer(store, clock: () => DateTime.utc(2026, 10, 1, 12));
    final user = await early.profile();
    final week = bilgiWeekId(DateTime.utc(2026, 10, 1, 12));
    await store.put('users', user.id, user.copyWith(weekScore: 400, weekId: week).toMap());
    final later = LunoBilgiServer(store, clock: () => DateTime.utc(2026, 10, 8, 12));
    final next = await later.profile();
    expect(next.id, user.id);
    expect(next.weekScore, 400);
    expect(next.weekId, week);
    expect(bilgiVisibleWeekScore(next, DateTime.utc(2026, 10, 8, 12)), 0);
  });

  test('an upsert reply writes the reward and a missing key does not wipe the device', () async {
    final local = _player('ada', gold: 100, week: 800, weekId: '2026-W40', categoryTotal: 800, categoryWeek: 800);
    final partial = bilgiTakeLeagueGrant(local, {'gold': 50});
    expect(partial.gold, 50);
    expect(partial.weekScore, 800);
    expect(partial.categoryScores['genel']?.total, 800);

    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store, clock: () => DateTime.utc(2026, 10, 8, 12));
    final registered = await server.register(username: 'Ada', email: 'ada@luno.test', password: 'secret1');
    final user = registered.profile!;
    await store.put(
      'users',
      user.id,
      user.copyWith(
        gold: 100,
        weekScore: 800,
        weekId: '2026-W40',
        totalScore: 800,
        categoryScores: const {'genel': BilgiCategoryPoints(total: 800, week: 800)},
      ).toMap(),
    );
    var granted = false;
    server.remoteUpsert = (incoming) async {
      final text = granted ? incoming.leagueRewardText : 'Genel 1. sıra • 10000 altın';
      granted = true;
      return {
        'gold': 11100,
        'xp': incoming.xp,
        'level': incoming.level,
        'diamond': incoming.diamond,
        'totalScore': 800,
        'weekId': '2026-W41',
        'weekScore': 0,
        'categoryScores': {
          'genel': {'total': 800, 'week': 0},
        },
        'heldWeekId': '',
        'heldWeekScore': 0,
        'heldCategoryWeeks': <String, int>{},
        'leagueRewardWeek': '2026-W40',
        'leagueRewardText': text,
      };
    };
    final pulled = await server.pullRemoteProfile();
    expect(pulled.gold, 11100);
    expect(pulled.weekId, '2026-W41');
    expect(pulled.weekScore, 0);
    expect(pulled.categoryScores['genel']?.week, 0);
    expect(pulled.categoryScores['genel']?.total, 800);
    expect(pulled.leagueRewardText, 'Genel 1. sıra • 10000 altın');
    expect(pulled.passwordHash, user.passwordHash);
    final cleared = await server.clearLeagueReward();
    expect(cleared.leagueRewardText, isEmpty);
    expect(cleared.gold, 11100);
    expect((await server.profile()).gold, 11100);
    expect((await server.profile()).weekScore, 0);
  });

  test('an email-less upsert reply keeps the guest profile', () async {
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store, clock: () => DateTime.utc(2026, 10, 1, 12));
    final user = await server.profile();
    final week = bilgiWeekId(DateTime.utc(2026, 10, 1, 12));
    await store.put(
      'users',
      user.id,
      user.copyWith(
        username: 'Misafir',
        email: '',
        passwordHash: '',
        gold: 40,
        totalScore: 40,
        weekScore: 40,
        weekId: week,
      ).toMap(),
    );
    server.remoteUpsert = (incoming) async => {'gold': incoming.gold};
    final pulled = await server.pullRemoteProfile();
    expect(pulled.email, isEmpty);
    expect(pulled.username, 'Misafir');
    expect(pulled.totalScore, 40);
    expect(pulled.weekScore, 40);
    expect(pulled.gold, 40);
  });

  test('a full profile reply writes lives and jokers back', () async {
    final store = MemoryKeyValueStore();
    final now = DateTime.utc(2026, 10, 2, 12);
    final server = LunoBilgiServer(store, clock: () => now);
    final user = await server.profile();
    await store.put(
      'users',
      user.id,
      user.copyWith(
        lives: 1,
        livesAt: now.subtract(const Duration(hours: 5)),
        adFreeLeft: 1,
        jokers: const {'half': 0, 'double': 0, 'time': 0, 'change': 0, 'hint': 0},
      ).toMap(),
    );
    server.remoteUpsert = (incoming) async => incoming.copyWith(
      lives: 1,
      livesAt: now,
      gold: 800,
      jokers: const {'half': 0, 'double': 0, 'time': 0, 'change': 0, 'hint': 3},
    ).toPublicMap();
    final pulled = await server.pullRemoteProfile();
    expect(pulled.lives, 1);
    expect(pulled.gold, 800);
    expect(pulled.jokers['hint'], 3);
    expect(pulled.adFreeLeft, 1);
    expect(pulled.id, user.id);
    expect(pulled.passwordHash, user.passwordHash);
  });

  test('category list rank is the real all-time place, not a seed row', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final me = _player('me', category: 'felsefe', categoryTotal: 30, total: 30);
    final higher = _player('hi', category: 'felsefe', categoryTotal: 80, total: 80);
    final lower = _player('lo', category: 'felsefe', categoryTotal: 10, total: 10);
    final zero = _player('zero', category: 'felsefe', played: true, total: 5);
    final other = _player('tarih', category: 'tarih', categoryTotal: 50, total: 50);
    final list = bilgiLeagueSnapshot(
      users: [me, higher, lower, zero, other],
      me: me,
      scope: 'category',
      now: now,
    );
    expect(list.rows, isEmpty);
    expect(list.categoryRanks['felsefe'], 2);
    expect(list.categoryRanks.containsKey('tarih'), isFalse);
    final opened = bilgiLeagueSnapshot(
      users: [me, higher, lower, zero, other],
      me: me,
      scope: 'category',
      categoryId: 'felsefe',
      now: now,
    );
    expect(opened.seed, isTrue);
    expect(opened.rows.first.id, 'hi');
    expect(opened.rows[1].id, 'me');
    expect(opened.rows[1].rank, 2);
    expect(opened.rows[2].id, 'lo');
    expect(opened.rows.where((row) => row.seed), hasLength(97));
    expect(opened.categoryRanks['felsefe'], 2);
  });

  test('player at 40 stays in the top 100 and player at 140 is pinned with that rank', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final week = bilgiWeekId(now);
    final users = [
      for (var i = 0; i < 200; i++) _player('p$i', total: 2000 - i, week: 2000 - i, weekId: week),
    ];
    final inside = bilgiLeagueSnapshot(users: users, me: users[39], scope: 'global', now: now);
    expect(inside.seed, isFalse);
    expect(inside.rows, hasLength(100));
    expect(inside.rows[39].id, 'p39');
    expect(inside.rows[39].rank, 40);
    expect(inside.rows.any((row) => row.rank > 100), isFalse);
    expect(inside.rows.any((row) => row.id == 'p100'), isFalse);

    final outside = bilgiLeagueSnapshot(users: users, me: users[139], scope: 'global', now: now);
    expect(outside.rows, hasLength(101));
    expect(outside.rows.take(100).map((row) => row.id).toList(), [for (var i = 0; i < 100; i++) 'p$i']);
    expect(outside.rows.last.id, 'p139');
    expect(outside.rows.last.rank, 140);
    expect(outside.rows.any((row) => row.id == 'p100'), isFalse);
    expect(outside.rows.any((row) => row.id == 'p138'), isFalse);
    expect(outside.rows.any((row) => row.id == 'p140'), isFalse);
    expect(outside.rows.any((row) => row.id == 'p199'), isFalse);

    final admin = bilgiLeagueSnapshot(users: users, scope: 'global', now: now, seedIfShort: false);
    expect(admin.rows, hasLength(200));
  });

  test('a category with 60 approved questions is in the league catalog without points', () {
    final counts = <String, int>{
      'felsefe': bilgiMinPublishedQuestions,
      'genel': bilgiMinPublishedQuestions - 1,
      'karma': bilgiMinPublishedQuestions,
      tumuKarmaId: bilgiMinPublishedQuestions,
    };
    final catalog = bilgiLeagueCatalog(counts);
    final idle = _player('ada', category: 'felsefe', played: false, total: 0);
    expect(idle.categoryScores, isEmpty);
    expect(catalog, contains('felsefe'));
    expect(catalog, isNot(contains('genel')));
    expect(catalog, isNot(contains('karma')));
    expect(catalog, isNot(contains(tumuKarmaId)));
    expect(bilgiLeagueCatalog(const {}), isEmpty);
  });

  test('category player counts ignore a zero-point played row', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final a = _player('ada', category: 'felsefe', categoryTotal: 10, total: 10);
    final b = _player('berk', category: 'felsefe', categoryTotal: 4, total: 4);
    final zero = _player('zero', category: 'felsefe', played: true, total: 5);
    final counts = bilgiCategoryPlayerCounts([a, b, zero]);
    expect(counts['felsefe'], 2);
    final snap = bilgiLeagueSnapshot(users: [a, b, zero], scope: 'category', now: now);
    expect(snap.categoryPlayerCounts['felsefe'], 2);
    final restored = BilgiLeagueSnapshot.fromMap(snap.toMap());
    expect(restored.categoryPlayerCounts['felsefe'], 2);
    expect(BilgiLeagueSnapshot.fromMap(const {}).categoryPlayerCounts, isEmpty);
  });

  test('a category board stays empty until someone has a positive score', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final week = bilgiWeekId(now);
    final zero = _player('ada', category: 'felsefe', played: true, weekId: week, total: 0);
    final empty = bilgiLeagueSnapshot(
      users: [zero],
      me: zero,
      scope: 'category',
      categoryId: 'felsefe',
      now: now,
    );
    expect(empty.seed, isFalse);
    expect(empty.rows, isEmpty);
    expect(empty.closed, isFalse);
    final scored = _player('ada', category: 'felsefe', categoryTotal: 12, weekId: week, total: 12);
    final opened = bilgiLeagueSnapshot(
      users: [scored],
      me: scored,
      scope: 'category',
      categoryId: 'felsefe',
      now: now,
    );
    expect(opened.seed, isTrue);
    expect(opened.closed, isFalse);
    expect(opened.rows.first.id, 'ada');
    expect(opened.rows.first.rank, 1);
    expect(opened.rows.where((row) => row.seed), hasLength(99));
    final weekOnly = _player(
      'cem',
      category: 'felsefe',
      categoryWeek: 8,
      week: 8,
      weekId: week,
      total: 8,
    );
    final weekly = bilgiLeagueSnapshot(
      users: [weekOnly],
      me: weekOnly,
      scope: 'category',
      categoryId: 'felsefe',
      categoryWeekly: true,
      now: now,
    );
    expect(weekly.realCount, 1);
    expect(weekly.seed, isTrue);
    expect(weekly.rows.first.id, 'cem');
    expect(weekly.rows.first.rank, 1);
    expect(weekly.rows.where((row) => row.seed), hasLength(99));
  });

  test('league catalog sorts by Turkish name, question count, and player count', () {
    expect(bilgiTurkishCompare('C', 'Ç'), lessThan(0));
    expect(bilgiTurkishCompare('Ç', 'D'), lessThan(0));
    expect(bilgiTurkishCompare('g', 'ğ'), lessThan(0));
    expect(bilgiTurkishCompare('Işık', 'İstanbul'), lessThan(0));
    expect(bilgiTurkishCompare('o', 'ö'), lessThan(0));
    expect(bilgiTurkishCompare('s', 'ş'), lessThan(0));
    expect(bilgiTurkishCompare('u', 'ü'), lessThan(0));
    const ids = ['unlu', 'mantik_cikarim', 'cografya', 'din', 'internet'];
    expect(
      bilgiSortLeagueCatalog(ids, sort: bilgiLeagueSortAlpha),
      ['cografya', 'mantik_cikarim', 'din', 'internet', 'unlu'],
    );
    expect(
      bilgiSortLeagueCatalog(
        const ['felsefe', 'genel', 'cografya'],
        sort: bilgiLeagueSortQuestions,
        questionCounts: const {'genel': 120, 'felsefe': 80, 'cografya': 80},
      ),
      ['genel', 'cografya', 'felsefe'],
    );
    expect(
      bilgiSortLeagueCatalog(
        const ['genel', 'felsefe', 'cografya'],
        sort: bilgiLeagueSortPlayers,
        playerCounts: const {'genel': 1, 'felsefe': 4, 'cografya': 4},
      ),
      ['cografya', 'felsefe', 'genel'],
    );
  });

  test('my rank label follows the selected period', () {
    final now = DateTime.utc(2026, 10, 1, 12);
    final week = bilgiWeekId(now);
    final me = _player(
      'ada',
      category: 'felsefe',
      categoryTotal: 10,
      week: 0,
      categoryWeek: 0,
      weekId: week,
      total: 10,
    );
    final higher = _player(
      'berk',
      category: 'felsefe',
      categoryTotal: 40,
      week: 0,
      categoryWeek: 0,
      weekId: week,
      total: 40,
    );
    final weekly = bilgiLeagueSnapshot(
      users: [me, higher],
      me: me,
      scope: 'category',
      categoryId: 'felsefe',
      categoryWeekly: true,
      now: now,
    );
    expect(
      bilgiMyRankLabel(
        score: bilgiLeaguePeriodScore(me, weekly: true, categoryId: 'felsefe', now: now),
        rank: bilgiMyBoardRank(weekly.rows, me.id),
      ),
      'Lig Puanınız: 0',
    );
    final allTime = bilgiLeagueSnapshot(
      users: [me, higher],
      me: me,
      scope: 'category',
      categoryId: 'felsefe',
      now: now,
    );
    expect(
      bilgiMyRankLabel(
        score: bilgiLeaguePeriodScore(me, weekly: false, categoryId: 'felsefe', now: now),
        rank: bilgiMyBoardRank(allTime.rows, me.id),
      ),
      'Lig Puanınız: 10\n2. Sıradasınız',
    );
    expect(allTime.rows[1].id, 'ada');
    expect(allTime.rows[1].rank, 2);
    final generalWeek = bilgiLeagueSnapshot(
      users: [me],
      me: me,
      scope: 'global',
      categoryWeekly: true,
      now: now,
    );
    expect(
      bilgiMyRankLabel(
        score: bilgiLeaguePeriodScore(me, weekly: true, now: now),
        rank: bilgiMyBoardRank(generalWeek.rows, me.id),
      ),
      'Lig Puanınız: 0',
    );
    final generalAll = bilgiLeagueSnapshot(
      users: [me],
      me: me,
      scope: 'global',
      now: now,
    );
    expect(
      bilgiMyRankLabel(
        score: bilgiLeaguePeriodScore(me, weekly: false, now: now),
        rank: bilgiMyBoardRank(generalAll.rows, me.id),
      ),
      'Lig Puanınız: 10\n1. Sıradasınız',
    );
    expect(bilgiMyRankLabel(score: 80, rank: 1), 'Lig Puanınız: 80\n1. Sıradasınız');
    expect(bilgiMyRankLabel(score: 40, rank: 4), 'Lig Puanınız: 40\n4. Sıradasınız');
    expect(bilgiMyRankLabel(score: 80, rank: 0), 'Lig Puanınız: 80');
  });
}
