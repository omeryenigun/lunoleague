import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
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

void main() {
  test('Istanbul Monday opens the new Bilgi week', () {
    final monday = DateTime.utc(2026, 10, 4, 21);
    final sunday = DateTime.utc(2026, 10, 4, 20);
    expect(bilgiWeekId(monday), DateKeys.weekId(DateTime(2026, 10, 5)));
    expect(bilgiWeekId(sunday), DateKeys.weekId(DateTime(2026, 10, 4)));
    expect(bilgiWeekId(monday), isNot(bilgiWeekId(sunday)));
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
    expect(snap.rows.first.seed, isTrue);
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
    expect(shown.rows.every((row) => row.seed), isTrue);
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
    expect(shown.rows.last.id, 'c9');
    expect(shown.rows.last.rank, 10);
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
    expect(opened.rows.where((row) => row.seed), hasLength(100));
    expect(opened.rows.last.id, 'me');
    expect(opened.rows.last.rank, 2);
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
}
