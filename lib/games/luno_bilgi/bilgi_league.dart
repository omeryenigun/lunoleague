import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';

/// Istanbul has no daylight saving. League weeks turn over at Monday 00:00 there.
DateTime bilgiIstanbulWall(DateTime now) {
  final utc = now.toUtc();
  final shifted = utc.add(const Duration(hours: 3));
  return DateTime(shifted.year, shifted.month, shifted.day, shifted.hour, shifted.minute, shifted.second);
}

String bilgiWeekId(DateTime now) => DateKeys.weekId(bilgiIstanbulWall(now));

/// Calendar day in Istanbul, same clock as the league week.
String bilgiDayKey(DateTime now) => DateKeys.dayKey(bilgiIstanbulWall(now));

String bilgiPreviousWeekId(DateTime now) => bilgiWeekId(now.toUtc().subtract(const Duration(days: 7)));

Duration bilgiWeekRemaining(DateTime now) {
  final wall = bilgiIstanbulWall(now);
  final daysToMonday = wall.weekday == DateTime.sunday ? 1 : (DateTime.monday + 7 - wall.weekday);
  final end = DateTime(wall.year, wall.month, wall.day).add(Duration(days: daysToMonday));
  final left = end.difference(wall);
  return left.isNegative ? Duration.zero : left;
}

/// Weeks that still need a payout, oldest first. The first run closes only the week that just ended.
List<String> bilgiWeeksToSettle(String? lastPaid, DateTime now) {
  final previous = bilgiPreviousWeekId(now);
  if (lastPaid != null && lastPaid.isNotEmpty && lastPaid.compareTo(previous) >= 0) return const [];
  if (lastPaid == null || lastPaid.isEmpty) return [previous];
  final pending = <String>[];
  var cursor = now.toUtc();
  for (var i = 0; i < 8; i++) {
    final id = bilgiPreviousWeekId(cursor);
    if (id.compareTo(lastPaid) <= 0) break;
    pending.add(id);
    cursor = cursor.subtract(const Duration(days: 7));
  }
  return pending.reversed.toList();
}

bool bilgiWeekBefore(String left, String right) {
  if (left.isEmpty) return right.isNotEmpty;
  if (right.isEmpty) return false;
  return left.compareTo(right) < 0;
}

String bilgiTier(int weekScore) {
  if (weekScore >= 15000) return 'Efsane';
  if (weekScore >= 6000) return 'Elmas';
  if (weekScore >= 2000) return 'Altın';
  if (weekScore >= 500) return 'Gümüş';
  return 'Bronz';
}

({int gold, int xp}) bilgiGeneralReward(int rank) {
  if (rank == 1) return (gold: 10000, xp: 1000);
  if (rank == 2) return (gold: 5000, xp: 500);
  if (rank == 3) return (gold: 2500, xp: 250);
  if (rank <= 100) return (gold: 500, xp: 50);
  return (gold: 0, xp: 0);
}

({int gold, int xp}) bilgiCategoryReward(int rank) {
  if (rank == 1) return (gold: 1000, xp: 100);
  if (rank == 2) return (gold: 500, xp: 50);
  if (rank == 3) return (gold: 250, xp: 25);
  if (rank <= 10) return (gold: 100, xp: 10);
  return (gold: 0, xp: 0);
}

const bilgiLeagueRealLimit = 100;

int bilgiVisibleWeekScore(BilgiProfile user, DateTime now) {
  if (user.weekId != bilgiWeekId(now)) return 0;
  return user.weekScore;
}

int bilgiVisibleCategoryWeek(BilgiProfile user, String categoryId, DateTime now) {
  if (user.weekId != bilgiWeekId(now)) return 0;
  return user.categoryScores[categoryId]?.week ?? 0;
}

int bilgiScoreForWeek(BilgiProfile user, String week) {
  if (user.heldWeekId == week) return user.heldWeekScore;
  if (user.weekId == week) return user.weekScore;
  return 0;
}

int bilgiCategoryScoreForWeek(BilgiProfile user, String categoryId, String week) {
  if (user.heldWeekId == week) return user.heldCategoryWeeks[categoryId] ?? 0;
  if (user.weekId == week) return user.categoryScores[categoryId]?.week ?? 0;
  return 0;
}

bool bilgiPublicPlayer(BilgiProfile user) => !user.banned && !user.guestHere;

bool bilgiPlayedCategory(BilgiProfile user, String categoryId) {
  if (categoryId == tumuKarmaId || bilgiCategoryById(categoryId) == null) return false;
  if (user.categoriesPlayed.contains(categoryId)) return true;
  final points = user.categoryScores[categoryId];
  return points != null && (points.total > 0 || points.week > 0);
}

Set<String> bilgiPlayedCategoryIds(Iterable<BilgiProfile> users) {
  final ids = <String>{};
  for (final user in users) {
    if (user.banned) continue;
    for (final category in bilgiCategories) {
      if (bilgiPlayedCategory(user, category.id)) ids.add(category.id);
    }
  }
  return ids;
}

List<String> bilgiOpenCategoryIds(Iterable<BilgiProfile> users) {
  final played = bilgiPlayedCategoryIds(users);
  return [for (final category in bilgiCategories) if (played.contains(category.id)) category.id];
}

/// Public players whose all-time total in that category is above zero.
Map<String, int> bilgiCategoryPlayerCounts(Iterable<BilgiProfile> users) {
  final counts = <String, int>{};
  for (final category in bilgiCategories) {
    if (category.id == tumuKarmaId || category.id == 'karma') continue;
    var players = 0;
    for (final user in users) {
      if (!bilgiPublicPlayer(user)) continue;
      if ((user.categoryScores[category.id]?.total ?? 0) > 0) players++;
    }
    if (players > 0) counts[category.id] = players;
  }
  return counts;
}

/// Approved questions a category needs before the player may see it.
const bilgiMinPublishedQuestions = 60;

/// Player lists and category leagues share this rule.
/// [publishedCount] is the approved pool (`categoryCounts`). Null is not loaded yet and stays hidden.
bool bilgiCategoryListed(String categoryId, int? publishedCount) {
  if (categoryId.trim().isEmpty) return false;
  return publishedCount != null && publishedCount >= bilgiMinPublishedQuestions;
}

/// Categories with at least [bilgiMinPublishedQuestions] approved questions.
/// Karma and the mix id stay out. A missing count is not loaded yet and stays hidden.
List<String> bilgiLeagueCatalog(Map<String, int> publishedCounts) {
  return [
    for (final category in bilgiCategories)
      if (category.id != tumuKarmaId &&
          category.id != 'karma' &&
          bilgiCategoryListed(category.id, publishedCounts[category.id]))
        category.id,
  ];
}

const bilgiLeagueSortAlpha = 'alpha';
const bilgiLeagueSortQuestions = 'questions';
const bilgiLeagueSortPlayers = 'players';

/// Turkish letter order: a b c ç d e f g ğ h ı i j k l m n o ö p r s ş t u ü v y z.
int bilgiTurkishCompare(String left, String right) {
  final a = _turkishRanks(left);
  final b = _turkishRanks(right);
  final n = a.length < b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final by = a[i].compareTo(b[i]);
    if (by != 0) return by;
  }
  return a.length.compareTo(b.length);
}

const _turkishAlphabet = 'abcçdefgğhıijklmnoöprsştuüvyz';

List<int> _turkishRanks(String input) {
  final ranks = <int>[];
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    if (ch == '\u0307') continue;
    final lower = switch (ch) {
      'İ' => 'i',
      'I' => 'ı',
      'Ç' => 'ç',
      'Ğ' => 'ğ',
      'Ö' => 'ö',
      'Ş' => 'ş',
      'Ü' => 'ü',
      _ => ch.toLowerCase(),
    };
    for (final part in lower.runes) {
      if (part == 0x0307) continue;
      final letter = String.fromCharCode(part);
      final index = _turkishAlphabet.indexOf(letter);
      ranks.add(index >= 0 ? index : 100 + part);
    }
  }
  return ranks;
}

/// [sort] is [bilgiLeagueSortAlpha], [bilgiLeagueSortQuestions], or [bilgiLeagueSortPlayers].
/// Question and player sorts are high to low, then Turkish category name.
List<String> bilgiSortLeagueCatalog(
  List<String> ids, {
  String sort = bilgiLeagueSortAlpha,
  Map<String, int> questionCounts = const {},
  Map<String, int> playerCounts = const {},
}) {
  final rows = [...ids];
  int byName(String a, String b) {
    final left = bilgiCategoryById(a)?.name ?? a;
    final right = bilgiCategoryById(b)?.name ?? b;
    final by = bilgiTurkishCompare(left, right);
    if (by != 0) return by;
    return a.compareTo(b);
  }

  rows.sort((a, b) {
    if (sort == bilgiLeagueSortQuestions) {
      final byCount = (questionCounts[b] ?? 0).compareTo(questionCounts[a] ?? 0);
      if (byCount != 0) return byCount;
    } else if (sort == bilgiLeagueSortPlayers) {
      final byCount = (playerCounts[b] ?? 0).compareTo(playerCounts[a] ?? 0);
      if (byCount != 0) return byCount;
    }
    return byName(a, b);
  });
  return rows;
}

/// Categories where [user] has an all-time score and at least [bilgiMinPublishedQuestions] approved questions.
List<String> bilgiMyOpenLeagueIds(
  BilgiProfile? user, {
  required Map<String, int> publishedCounts,
}) {
  if (user == null) return const [];
  return [
    for (final category in bilgiCategories)
      if ((user.categoryScores[category.id]?.total ?? 0) > 0 &&
          bilgiCategoryListed(category.id, publishedCounts[category.id]))
        category.id,
  ];
}

BilgiProfile bilgiRollWeek(BilgiProfile user, DateTime now) {
  final current = bilgiWeekId(now);
  if (user.weekId.isEmpty) return user.copyWith(weekId: current);
  if (user.weekId == current) return user;
  final weeks = {for (final entry in user.categoryScores.entries) entry.key: entry.value.week};
  final zeroed = {
    for (final entry in user.categoryScores.entries)
      entry.key: BilgiCategoryPoints(total: entry.value.total, week: 0),
  };
  final archive = user.heldWeekId.isEmpty || user.weekId.compareTo(user.heldWeekId) >= 0;
  return user.copyWith(
    heldWeekId: archive ? user.weekId : user.heldWeekId,
    heldWeekScore: archive ? user.weekScore : user.heldWeekScore,
    heldCategoryWeeks: archive ? weeks : user.heldCategoryWeeks,
    weekId: current,
    weekScore: 0,
    categoryScores: zeroed,
  );
}

/// Adds a finished round. Karma stays on the general scores only.
BilgiProfile bilgiAddScore(
  BilgiProfile user, {
  required int points,
  required String categoryId,
  required DateTime now,
}) {
  final current = bilgiRollWeek(user, now);
  if (points <= 0) return current;
  final scores = Map<String, BilgiCategoryPoints>.from(current.categoryScores);
  if (bilgiCategoryById(categoryId) != null) {
    final prev = scores[categoryId] ?? const BilgiCategoryPoints();
    scores[categoryId] = BilgiCategoryPoints(total: prev.total + points, week: prev.week + points);
  }
  return current.copyWith(
    totalScore: current.totalScore + points,
    weekScore: current.weekScore + points,
    categoryScores: scores,
    weekId: bilgiWeekId(now),
  );
}

class BilgiBoardEntry {
  const BilgiBoardEntry({
    required this.id,
    required this.name,
    required this.avatar,
    required this.score,
    required this.seed,
    this.city = '',
    this.tier = '',
    this.leagueTitle = '',
    this.rank = 0,
  });

  final String id;
  final String name;
  final String avatar;
  final int score;
  final bool seed;
  final String city;
  final String tier;
  final String leagueTitle;

  /// Real place. Zero means the row is shown at its position in the list.
  final int rank;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'score': score,
        'seed': seed,
        'city': city,
        'tier': tier,
        'leagueTitle': leagueTitle,
        'rank': rank,
      };

  factory BilgiBoardEntry.fromMap(Map<String, dynamic> map) {
    return BilgiBoardEntry(
      id: '${map['id'] ?? ''}',
      name: '${map['name'] ?? ''}',
      avatar: '${map['avatar'] ?? '😎'}',
      score: bilgiInt(map['score'], 0),
      seed: map['seed'] == true,
      city: '${map['city'] ?? ''}',
      tier: '${map['tier'] ?? ''}',
      leagueTitle: '${map['leagueTitle'] ?? ''}',
      rank: bilgiInt(map['rank'], 0),
    );
  }
}

class BilgiLeagueSnapshot {
  const BilgiLeagueSnapshot({
    required this.rows,
    required this.seed,
    required this.realCount,
    required this.categoryIds,
    required this.weekId,
    required this.remaining,
    required this.tier,
    required this.title,
    required this.settledWeek,
    required this.closed,
    this.categoryRanks = const {},
    this.categoryPlayerCounts = const {},
  });

  final List<BilgiBoardEntry> rows;
  final bool seed;
  final int realCount;
  final List<String> categoryIds;
  final String weekId;
  final Duration remaining;
  final String tier;
  final String title;
  final String settledWeek;
  final bool closed;
  final Map<String, int> categoryRanks;
  final Map<String, int> categoryPlayerCounts;

  Map<String, dynamic> toMap() => {
        'rows': [for (final row in rows) row.toMap()],
        'seed': seed,
        'realCount': realCount,
        'categoryIds': categoryIds,
        'weekId': weekId,
        'remainingSeconds': remaining.inSeconds,
        'tier': tier,
        'title': title,
        'settledWeek': settledWeek,
        'closed': closed,
        'categoryRanks': categoryRanks,
        'categoryPlayerCounts': categoryPlayerCounts,
      };

  factory BilgiLeagueSnapshot.fromMap(Map<String, dynamic> map) {
    final rows = map['rows'];
    final ids = map['categoryIds'];
    final ranks = map['categoryRanks'];
    final players = map['categoryPlayerCounts'];
    return BilgiLeagueSnapshot(
      rows: [
        for (final row in rows is List ? rows : const [])
          if (row is Map) BilgiBoardEntry.fromMap(Map<String, dynamic>.from(row)),
      ],
      seed: map['seed'] == true,
      realCount: bilgiInt(map['realCount'], 0),
      categoryIds: [for (final id in ids is List ? ids : const []) '$id'],
      weekId: '${map['weekId'] ?? ''}',
      remaining: Duration(seconds: bilgiInt(map['remainingSeconds'], 0)),
      tier: '${map['tier'] ?? ''}',
      title: '${map['title'] ?? ''}',
      settledWeek: '${map['settledWeek'] ?? ''}',
      closed: map['closed'] == true,
      categoryRanks: {
        for (final entry in ranks is Map ? ranks.entries : const [])
          if (bilgiInt(entry.value, 0) > 0) '${entry.key}': bilgiInt(entry.value, 0),
      },
      categoryPlayerCounts: {
        for (final entry in players is Map ? players.entries : const [])
          if (bilgiInt(entry.value, 0) > 0) '${entry.key}': bilgiInt(entry.value, 0),
      },
    );
  }
}

/// Points for the open board. Weekly uses this week's score; all-time uses the lifetime total.
/// A category board reads that category. Genel Lig reads [BilgiProfile.weekScore] or [BilgiProfile.totalScore].
int bilgiLeaguePeriodScore(
  BilgiProfile user, {
  required bool weekly,
  String? categoryId,
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  if (categoryId != null && categoryId.isNotEmpty) {
    if (weekly) return bilgiVisibleCategoryWeek(user, categoryId, clock);
    return user.categoryScores[categoryId]?.total ?? 0;
  }
  if (weekly) return bilgiVisibleWeekScore(user, clock);
  return user.totalScore;
}

/// Real place on this period's board. Zero when the player has no row.
int bilgiMyBoardRank(List<BilgiBoardEntry> rows, String meId) {
  for (final row in rows) {
    if (row.id == meId && row.rank > 0) return row.rank;
  }
  return 0;
}

/// Points stay on their own line: "Lig Puanınız: 40".
/// A real place is a second line, "4. Sıradasınız". No place omits that line.
String bilgiMyRankLabel({required int score, required int rank}) {
  final points = score < 0 ? 0 : score;
  final pointsLine = 'Lig Puanınız: $points';
  if (rank <= 0) return pointsLine;
  return '$pointsLine\n$rank. Sıradasınız';
}

const bilgiSeedNames = <String>[
  'Ada K.', 'Berk T.', 'Cem Y.', 'Deniz A.', 'Ege S.', 'Fatma N.', 'Gizem K.', 'Hakan D.', 'Irmak B.', 'Jale P.',
  'Kaan M.', 'Lara C.', 'Mert H.', 'Nazlı E.', 'Onur F.', 'Pelin G.', 'Rüzgar L.', 'Selin O.', 'Tarık R.', 'Umut V.',
  'Vera Z.', 'Yağmur I.', 'Zeynep U.', 'Arda Q.', 'Burcu W.', 'Canan X.', 'Doruk J.', 'Elif S.', 'Ferhat A.', 'Gülşah B.',
  'Harun C.', 'İpek D.', 'Kerem E.', 'Lale F.', 'Melih G.', 'Nehir H.', 'Okan I.', 'Poyraz J.', 'Reyhan K.', 'Serkan L.',
  'Tuğçe M.', 'Ufuk N.', 'Volkan O.', 'Yasemin P.', 'Zafer R.', 'Aslı S.', 'Baran T.', 'Ceyda U.', 'Demir V.', 'Ebru Y.',
  'Fırat Z.', 'Gamze A.', 'Hüseyin B.', 'İlker C.', 'Jülide D.', 'Koray E.', 'Leyla F.', 'Murat G.', 'Nilüfer H.', 'Orhan I.',
  'Pınar J.', 'Rıza K.', 'Sevgi L.', 'Tolga M.', 'Ülkü N.', 'Vedat O.', 'Yeliz P.', 'Zeki R.', 'Aylin S.', 'Bora T.',
  'Cansu U.', 'Derya V.', 'Emre Y.', 'Funda Z.', 'Gökhan A.', 'Hande B.', 'İsmail C.', 'Janset D.', 'Kuzey E.', 'Melis F.',
  'Nihat G.', 'Oylum H.', 'Peker I.', 'Rana J.', 'Sarp K.', 'Tuna L.', 'Uğur M.', 'Vildan N.', 'Yusuf O.', 'Zara P.',
  'Alper R.', 'Belgin S.', 'Cemil T.', 'Damla U.', 'Eren V.', 'Filiz Y.', 'Güneş Z.', 'Haluk A.', 'İnci B.', 'Kadir C.',
];

const bilgiSeedAvatars = <String>['😎', '🦊', '🐼', '🦁', '🐯', '🐸', '🐙', '🦄', '🐻', '🐨'];

List<BilgiBoardEntry> bilgiSeedBoard() {
  return [
    for (var i = 0; i < bilgiSeedNames.length; i++)
      BilgiBoardEntry(
        id: 'seed-${i + 1}',
        name: bilgiSeedNames[i],
        avatar: bilgiSeedAvatars[i % bilgiSeedAvatars.length],
        score: 15000 - i * 120,
        seed: true,
      ),
  ];
}

int _byScore(BilgiProfile a, BilgiProfile b, int scoreA, int scoreB) {
  final byScore = scoreB.compareTo(scoreA);
  if (byScore != 0) return byScore;
  return a.id.compareTo(b.id);
}

List<BilgiProfile> bilgiRanked(
  List<BilgiProfile> users, {
  required int Function(BilgiProfile user) scoreOf,
  required bool Function(BilgiProfile user) include,
}) {
  final rows = [for (final user in users) if (include(user) && scoreOf(user) > 0) user];
  rows.sort((a, b) => _byScore(a, b, scoreOf(a), scoreOf(b)));
  return rows;
}

Map<String, int> bilgiMyCategoryRanks(BilgiProfile? me, List<BilgiProfile> users) {
  if (me == null) return const {};
  final ranks = <String, int>{};
  for (final id in bilgiOpenCategoryIds(users)) {
    if ((me.categoryScores[id]?.total ?? 0) <= 0) continue;
    final rows = bilgiRanked(
      users,
      scoreOf: (row) => row.categoryScores[id]?.total ?? 0,
      include: (row) => bilgiPublicPlayer(row) && bilgiPlayedCategory(row, id),
    );
    final index = rows.indexWhere((row) => row.id == me.id);
    if (index >= 0) ranks[id] = index + 1;
  }
  return ranks;
}

String bilgiLeagueTitle(BilgiProfile user, List<BilgiProfile> users) {
  String? bestName;
  var bestRank = 11;
  for (final category in bilgiCategories) {
    final rows = bilgiRanked(
      users,
      scoreOf: (row) => row.categoryScores[category.id]?.total ?? 0,
      include: (row) => bilgiPublicPlayer(row) && bilgiPlayedCategory(row, category.id),
    );
    final index = rows.indexWhere((row) => row.id == user.id);
    if (index < 0 || index >= 10) continue;
    final rank = index + 1;
    if (rank < bestRank || (rank == bestRank && (bestName == null || category.name.compareTo(bestName) < 0))) {
      bestRank = rank;
      bestName = category.name;
    }
  }
  if (bestName == null) return '';
  return '$bestName Ustası';
}

BilgiLeagueSnapshot bilgiLeagueSnapshot({
  required List<BilgiProfile> users,
  BilgiProfile? me,
  required String scope,
  String? categoryId,
  bool categoryWeekly = false,
  required DateTime now,
  String settledWeek = '',
  bool seedIfShort = true,
}) {
  final open = bilgiOpenCategoryIds(users);
  final weekId = bilgiWeekId(now);
  final remaining = bilgiWeekRemaining(now);
  final tier = me == null ? '' : bilgiTier(bilgiVisibleWeekScore(me, now));
  final title = me == null ? '' : bilgiLeagueTitle(me, users);
  final categoryRanks = bilgiMyCategoryRanks(me, users);
  final categoryPlayerCounts = bilgiCategoryPlayerCounts(users);
  if (scope == 'category' && (categoryId == null || categoryId.isEmpty)) {
    return BilgiLeagueSnapshot(
      rows: const [],
      seed: false,
      realCount: 0,
      categoryIds: open,
      weekId: weekId,
      remaining: remaining,
      tier: tier,
      title: title,
      settledWeek: settledWeek,
      closed: false,
      categoryRanks: categoryRanks,
      categoryPlayerCounts: categoryPlayerCounts,
    );
  }
  if (scope == 'category' && !open.contains(categoryId)) {
    return BilgiLeagueSnapshot(
      rows: const [],
      seed: false,
      realCount: 0,
      categoryIds: open,
      weekId: weekId,
      remaining: remaining,
      tier: tier,
      title: title,
      settledWeek: settledWeek,
      closed: bilgiCategoryById(categoryId!) == null,
      categoryRanks: categoryRanks,
      categoryPlayerCounts: categoryPlayerCounts,
    );
  }
  final general = scope == 'global' || scope == 'general' || scope == 'weekly';
  final weekly = scope == 'weekly' || (categoryWeekly && (general || scope == 'category'));
  final ranked = bilgiRanked(
    users,
    scoreOf: (user) {
      if (general && weekly) return bilgiVisibleWeekScore(user, now);
      if (scope == 'category') {
        if (weekly) return bilgiVisibleCategoryWeek(user, categoryId!, now);
        return user.categoryScores[categoryId]?.total ?? 0;
      }
      return user.totalScore;
    },
    include: (user) {
      if (!bilgiPublicPlayer(user)) return false;
      if (scope == 'category') return bilgiPlayedCategory(user, categoryId!);
      return true;
    },
  );
  final realCount = ranked.length;
  final showSeed =
      seedIfShort && realCount < bilgiLeagueRealLimit && (scope != 'category' || realCount > 0);
  final category = scope == 'category' ? bilgiCategoryById(categoryId!) : null;
  BilgiBoardEntry entryFor(BilgiProfile user, int place) {
    return BilgiBoardEntry(
      id: user.id,
      name: user.username,
      avatar: user.avatar,
      score: general && weekly
          ? bilgiVisibleWeekScore(user, now)
          : scope == 'category'
              ? (weekly
                  ? bilgiVisibleCategoryWeek(user, categoryId!, now)
                  : (user.categoryScores[categoryId]?.total ?? 0))
              : user.totalScore,
      seed: false,
      city: user.city,
      tier: bilgiTier(bilgiVisibleWeekScore(user, now)),
      leagueTitle: !weekly && category != null && place <= 10 ? '${category.name} Ustası' : '',
      rank: place,
    );
  }

  BilgiBoardEntry? pinnedOutsideTop() {
    if (!seedIfShort || me == null) return null;
    final index = ranked.indexWhere((user) => user.id == me.id);
    if (index < 0) return null;
    if (!showSeed && index < bilgiLeagueRealLimit) return null;
    return entryFor(ranked[index], index + 1);
  }

  final pinned = pinnedOutsideTop();
  final rows = !seedIfShort
      ? [for (var i = 0; i < ranked.length; i++) entryFor(ranked[i], i + 1)]
      : showSeed
          ? [...bilgiSeedBoard().take(bilgiLeagueRealLimit), if (pinned != null) pinned]
          : [
              for (var i = 0; i < ranked.length && i < bilgiLeagueRealLimit; i++) entryFor(ranked[i], i + 1),
              if (pinned != null) pinned,
            ];
  return BilgiLeagueSnapshot(
    rows: rows,
    seed: showSeed,
    realCount: realCount,
    categoryIds: open,
    weekId: weekId,
    remaining: remaining,
    tier: tier,
    title: title,
    settledWeek: settledWeek,
    closed: false,
    categoryRanks: categoryRanks,
    categoryPlayerCounts: categoryPlayerCounts,
  );
}

List<BilgiProfile> applyBilgiSettlement(List<BilgiProfile> users, {required String week, required DateTime now}) {
  final current = bilgiWeekId(now);
  final grants = <String, ({int gold, int xp, List<String> lines})>{};
  void addGrant(String id, int gold, int xp, String line) {
    if (gold <= 0 && xp <= 0) return;
    final prev = grants[id];
    grants[id] = (
      gold: (prev?.gold ?? 0) + gold,
      xp: (prev?.xp ?? 0) + xp,
      lines: [...prev?.lines ?? const <String>[], line],
    );
  }

  final general = bilgiRanked(
    users,
    scoreOf: (user) => bilgiScoreForWeek(user, week),
    include: bilgiPublicPlayer,
  );
  for (var i = 0; i < general.length && i < 100; i++) {
    final pay = bilgiGeneralReward(i + 1);
    addGrant(general[i].id, pay.gold, pay.xp, 'Genel ${i + 1}. sıra');
  }
  for (final categoryId in bilgiOpenCategoryIds(users)) {
    final rows = bilgiRanked(
      users,
      scoreOf: (user) => bilgiCategoryScoreForWeek(user, categoryId, week),
      include: (user) => bilgiPublicPlayer(user) && bilgiPlayedCategory(user, categoryId),
    );
    final name = bilgiCategoryById(categoryId)?.name ?? categoryId;
    for (var i = 0; i < rows.length && i < 10; i++) {
      final pay = bilgiCategoryReward(i + 1);
      addGrant(rows[i].id, pay.gold, pay.xp, '$name ${i + 1}. sıra');
    }
  }

  return [
    for (final user in users) _settleOne(user, week: week, current: current, grant: grants[user.id]),
  ];
}

BilgiProfile _settleOne(
  BilgiProfile user, {
  required String week,
  required String current,
  required ({int gold, int xp, List<String> lines})? grant,
}) {
  var heldId = user.heldWeekId;
  var heldScore = user.heldWeekScore;
  var heldWeeks = user.heldCategoryWeeks;
  var weekId = user.weekId;
  var weekScore = user.weekScore;
  var scores = user.categoryScores;
  if (heldId == week) {
    heldId = '';
    heldScore = 0;
    heldWeeks = const {};
  }
  if (weekId == week) {
    weekId = current;
    weekScore = 0;
    scores = {
      for (final entry in scores.entries) entry.key: BilgiCategoryPoints(total: entry.value.total, week: 0),
    };
  }
  var gold = user.gold;
  var level = user.level;
  var xp = user.xp;
  var diamond = user.diamond;
  var text = user.leagueRewardText;
  var rewardWeek = user.leagueRewardWeek;
  if (grant != null) {
    final step = applyXp(level: level, xp: xp, gained: grant.xp);
    gold += grant.gold;
    level = step.level;
    xp = step.xp;
    diamond += step.diamondsGained;
    text = '${grant.lines.join(' • ')} • ${grant.gold} altın';
    rewardWeek = week;
  }
  return user.copyWith(
    heldWeekId: heldId,
    heldWeekScore: heldScore,
    heldCategoryWeeks: heldWeeks,
    weekId: weekId,
    weekScore: weekScore,
    categoryScores: scores,
    gold: gold,
    level: level,
    xp: xp,
    diamond: diamond,
    leagueRewardWeek: rewardWeek,
    leagueRewardText: text,
    title: level >= 10 ? 'Bilge' : user.title,
  );
}

Map<String, BilgiCategoryPoints> _mergeCategoryScores({
  required Map<String, BilgiCategoryPoints> server,
  required Map<String, BilgiCategoryPoints> client,
  required bool keepServerWeeks,
}) {
  final keys = {...server.keys, ...client.keys};
  return {
    for (final key in keys)
      key: BilgiCategoryPoints(
        total: _max(server[key]?.total ?? 0, client[key]?.total ?? 0),
        week: keepServerWeeks ? (server[key]?.week ?? 0) : _max(server[key]?.week ?? 0, client[key]?.week ?? 0),
      ),
  };
}

int _max(int a, int b) => a > b ? a : b;

/// Copies the league grant from an upsert body onto the device profile.
/// Keys the server did not send stay as they are, so an older API cannot wipe them.
BilgiProfile bilgiTakeLeagueGrant(BilgiProfile local, Map<String, dynamic> server) {
  int field(String key, int fallback) =>
      server.containsKey(key) ? bilgiInt(server[key], fallback) : fallback;
  final level = field('level', local.level);
  return local.copyWith(
    gold: field('gold', local.gold),
    xp: field('xp', local.xp),
    level: level,
    diamond: field('diamond', local.diamond),
    totalScore: field('totalScore', local.totalScore),
    weekId: server.containsKey('weekId') ? '${server['weekId'] ?? ''}' : local.weekId,
    weekScore: field('weekScore', local.weekScore),
    categoryScores: server.containsKey('categoryScores')
        ? bilgiCategoryPointsFrom(server['categoryScores'])
        : local.categoryScores,
    heldWeekId: server.containsKey('heldWeekId') ? '${server['heldWeekId'] ?? ''}' : local.heldWeekId,
    heldWeekScore: field('heldWeekScore', local.heldWeekScore),
    heldCategoryWeeks: server.containsKey('heldCategoryWeeks')
        ? bilgiIntMapFrom(server['heldCategoryWeeks'])
        : local.heldCategoryWeeks,
    leagueRewardWeek: server.containsKey('leagueRewardWeek')
        ? '${server['leagueRewardWeek'] ?? ''}'
        : local.leagueRewardWeek,
    leagueRewardText: server.containsKey('leagueRewardText')
        ? '${server['leagueRewardText'] ?? ''}'
        : local.leagueRewardText,
    title: level >= 10 && server.containsKey('title') ? '${server['title'] ?? local.title}' : local.title,
  );
}

/// Keeps a settled week from coming back, and keeps reward gold if the device has not seen it.
BilgiProfile mergeBilgiLeague(BilgiProfile server, BilgiProfile client, {required String settledWeek}) {
  final rewardBehind = bilgiWeekBefore(client.leagueRewardWeek, server.leagueRewardWeek);
  final clientWeekStale = settledWeek.isNotEmpty &&
      client.weekId.isNotEmpty &&
      client.weekId.compareTo(settledWeek) <= 0 &&
      server.weekId.compareTo(client.weekId) > 0;
  final keepServerWeek = rewardBehind || clientWeekStale;
  var gold = client.gold;
  if (rewardBehind && client.gold < server.gold) gold = server.gold;
  var level = client.level;
  var xp = client.xp;
  var diamond = client.diamond;
  if (rewardBehind) {
    diamond = _max(client.diamond, server.diamond);
    if (server.level > client.level || (server.level == client.level && server.xp > client.xp)) {
      level = server.level;
      xp = server.xp;
    }
  }
  final weekId = keepServerWeek ? server.weekId : (bilgiWeekBefore(client.weekId, server.weekId) ? server.weekId : client.weekId);
  final sameWeek = client.weekId == server.weekId;
  final weekScore = keepServerWeek
      ? server.weekScore
      : sameWeek
          ? _max(client.weekScore, server.weekScore)
          : (weekId == client.weekId ? client.weekScore : server.weekScore);
  final scores = _mergeCategoryScores(
    server: server.categoryScores,
    client: client.categoryScores,
    keepServerWeeks: keepServerWeek || !sameWeek && weekId == server.weekId,
  );
  var heldId = client.heldWeekId;
  var heldScore = client.heldWeekScore;
  var heldWeeks = client.heldCategoryWeeks;
  if (keepServerWeek) {
    heldId = server.heldWeekId;
    heldScore = server.heldWeekScore;
    heldWeeks = server.heldCategoryWeeks;
  } else if (client.heldWeekId == server.heldWeekId && client.heldWeekId.isNotEmpty) {
    heldScore = _max(client.heldWeekScore, server.heldWeekScore);
    final keys = {...client.heldCategoryWeeks.keys, ...server.heldCategoryWeeks.keys};
    heldWeeks = {for (final key in keys) key: _max(client.heldCategoryWeeks[key] ?? 0, server.heldCategoryWeeks[key] ?? 0)};
  } else if (client.heldWeekId.isEmpty &&
      server.heldWeekId.isNotEmpty &&
      (settledWeek.isEmpty || server.heldWeekId.compareTo(settledWeek) > 0)) {
    heldId = server.heldWeekId;
    heldScore = server.heldWeekScore;
    heldWeeks = server.heldCategoryWeeks;
  }
  final rewardWeek = bilgiWeekBefore(client.leagueRewardWeek, server.leagueRewardWeek) ? server.leagueRewardWeek : client.leagueRewardWeek;
  final rewardText = rewardBehind
      ? server.leagueRewardText
      : (client.leagueRewardWeek == server.leagueRewardWeek && client.leagueRewardText.isEmpty)
          ? ''
          : (client.leagueRewardText.isNotEmpty ? client.leagueRewardText : server.leagueRewardText);
  return client.copyWith(
    gold: gold,
    level: level,
    xp: xp,
    diamond: diamond,
    totalScore: _max(server.totalScore, client.totalScore),
    weekId: weekId,
    weekScore: weekScore,
    categoryScores: scores,
    heldWeekId: heldId,
    heldWeekScore: heldScore,
    heldCategoryWeeks: heldWeeks,
    leagueRewardWeek: rewardWeek,
    leagueRewardText: rewardText,
    title: level >= 10 ? 'Bilge' : client.title,
  );
}
