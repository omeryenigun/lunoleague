import 'dart:math';

import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_fall/fall_rules.dart';
import 'package:kelimelig/games/luno_fall/fall_words.dart';

class FallProfile {
  const FallProfile({
    required this.locale,
    required this.coins,
    required this.xp,
    required this.premium,
    required this.tier,
    required this.weeksInTier,
    required this.bestScore,
    required this.wordsCaught,
    required this.runsToday,
    required this.bannerToday,
    required this.rewardToday,
    required this.weekScores,
    required this.hints,
    required this.shields,
    required this.jokers,
    required this.extraLives,
    required this.extraTimes,
    required this.displayName,
  });

  final String locale;
  final int coins;
  final int xp;
  final bool premium;
  final FallTier tier;
  final int weeksInTier;
  final int bestScore;
  final int wordsCaught;
  final int runsToday;
  final int bannerToday;
  final int rewardToday;
  final List<int> weekScores;
  final int hints;
  final int shields;
  final int jokers;
  final int extraLives;
  final int extraTimes;
  final String displayName;

  int get weeklyPoints => FallRules.weeklyPoints(weekScores);
}

class FallProduct {
  const FallProduct({
    required this.id,
    required this.coins,
    required this.priceLabel,
    required this.kind,
  });

  final String id;
  final int coins;
  final String priceLabel;
  final String kind;
}

class FallRunRecord {
  const FallRunRecord({
    required this.id,
    required this.locale,
    required this.difficulty,
    required this.score,
    required this.words,
    required this.maxCombo,
    required this.createdAt,
  });

  final String id;
  final String locale;
  final String difficulty;
  final int score;
  final int words;
  final int maxCombo;
  final DateTime createdAt;
}

class FallStanding {
  const FallStanding({
    required this.name,
    required this.points,
    required this.isPlayer,
  });

  final String name;
  final int points;
  final bool isPlayer;
}

class FallLeagueBoard {
  const FallLeagueBoard({
    required this.locale,
    required this.tier,
    required this.weekId,
    required this.standings,
    required this.rule,
  });

  final String locale;
  final FallTier tier;
  final String weekId;
  final List<FallStanding> standings;
  final String rule;
}

class FallRunEnd {
  const FallRunEnd({
    required this.profile,
    required this.waitSeconds,
    required this.coinsEarned,
  });

  final FallProfile profile;
  final int waitSeconds;
  final int coinsEarned;
}

class LunoFallServer {
  LunoFallServer(this._store, {DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final KeyValueStore _store;
  final DateTime Function() _clock;
  final Random _random;

  static const _localeKey = 'active_locale';

  Future<void> initialize() async {
    final locale = await _store.getMeta(_localeKey);
    if (locale == null) await _store.putMeta(_localeKey, 'tr');
    for (final id in ['tr', 'en']) {
      if (await _store.get('profiles', id) == null) {
        await _store.put('profiles', id, _fresh(id));
      }
    }
  }

  Future<String> locale() async =>
      (await _store.getMeta(_localeKey)) ?? 'tr';

  Future<FallProfile> setLocale(String locale) async {
    final id = locale == 'en' ? 'en' : 'tr';
    await _store.putMeta(_localeKey, id);
    return profile();
  }

  Future<FallProfile> profile() async {
    await _rollDay(await locale());
    return _read(await locale());
  }

  Future<FallWord> nextWord(FallDifficulty difficulty, {String? avoid}) async {
    final pool = wordsFor(await locale(), difficulty);
    var pick = pool[_random.nextInt(pool.length)];
    var guard = 0;
    while (avoid != null && pick.word == avoid && guard < 8 && pool.length > 1) {
      pick = pool[_random.nextInt(pool.length)];
      guard++;
    }
    return pick;
  }

  Future<FallRunEnd> finishRun({
    required FallDifficulty difficulty,
    required int score,
    required int words,
    required int maxCombo,
  }) async {
    final id = await locale();
    await _rollDay(id);
    final map = await _map(id);
    final coins = words * 5 + (maxCombo >= 20 ? 75 : maxCombo >= 10 ? 25 : maxCombo >= 5 ? 10 : 0);
    final scores = _ints(map['weekScores']);
    scores.add(score);
    map['coins'] = (map['coins'] as int) + coins;
    map['xp'] = (map['xp'] as int) + words * 10 + maxCombo * 5;
    map['wordsCaught'] = (map['wordsCaught'] as int) + words;
    map['runsToday'] = (map['runsToday'] as int) + 1;
    map['bestScore'] = max(map['bestScore'] as int, score);
    map['weekScores'] = scores;
    await _store.put('profiles', id, map);
    await _store.put('runs', '${id}_${_clock().microsecondsSinceEpoch}', {
      'locale': id,
      'difficulty': difficulty.name,
      'score': score,
      'words': words,
      'maxCombo': maxCombo,
      'createdAt': _clock().toIso8601String(),
    });
    final runsToday = map['runsToday'] as int;
    return FallRunEnd(
      profile: _profileFrom(id, map),
      waitSeconds: FallRules.waitSeconds(
        difficulty: difficulty,
        runsToday: runsToday,
        premium: map['premium'] == true,
      ),
      coinsEarned: coins,
    );
  }

  Future<bool> noteBannerShown() async {
    final id = await locale();
    await _rollDay(id);
    final map = await _map(id);
    final shown = map['bannerToday'] as int;
    if (!FallRules.bannerAllowed(now: _clock(), shownToday: shown)) return false;
    map['bannerToday'] = shown + 1;
    await _store.put('profiles', id, map);
    return true;
  }

  Future<FallProfile?> claimCoinAd() async {
    final id = await locale();
    await _rollDay(id);
    final map = await _map(id);
    final claimed = map['rewardToday'] as int;
    if (!FallRules.coinAdAllowed(claimedToday: claimed)) return null;
    if (FallRules.isNight(_clock())) {
      // Night keeps rewarded ads and drops banners.
    }
    map['rewardToday'] = claimed + 1;
    map['coins'] = (map['coins'] as int) + 5;
    await _store.put('profiles', id, map);
    return _profileFrom(id, map);
  }

  Future<FallProfile> setPremium(bool value) async {
    final id = await locale();
    final map = await _map(id);
    map['premium'] = value;
    await _store.put('profiles', id, map);
    return _profileFrom(id, map);
  }

  Future<FallProfile?> buy(String productId) async {
    FallProduct? product;
    for (final item in _catalog()) {
      if (item.id == productId) product = item;
    }
    if (product == null) return null;
    final id = await locale();
    final map = await _map(id);
    if (product.kind == 'coins') {
      map['coins'] = (map['coins'] as int) + product.coins;
    } else {
      final price = product.coins;
      if ((map['coins'] as int) < price) return null;
      map['coins'] = (map['coins'] as int) - price;
      final field = switch (product.kind) {
        'hint' => 'hints',
        'shield' => 'shields',
        'joker' => 'jokers',
        'life' => 'extraLives',
        'time' => 'extraTimes',
        _ => null,
      };
      if (field == null) return null;
      map[field] = (map[field] as int) + 1;
    }
    await _store.put('profiles', id, map);
    return _profileFrom(id, map);
  }

  Future<bool> consume(String field) async {
    final id = await locale();
    final map = await _map(id);
    final have = (map[field] as int?) ?? 0;
    if (have <= 0) return false;
    map[field] = have - 1;
    await _store.put('profiles', id, map);
    return true;
  }

  List<FallProduct> shop() {
    return _catalog();
  }

  Future<List<FallRunRecord>> recentRuns() async {
    final id = await locale();
    final rows = await _store.values('runs');
    final list = rows
        .where((row) => row['locale'] == id)
        .map(
          (row) => FallRunRecord(
            id: row['createdAt'] as String,
            locale: id,
            difficulty: row['difficulty'] as String,
            score: row['score'] as int,
            words: row['words'] as int,
            maxCombo: row['maxCombo'] as int,
            createdAt: DateTime.parse(row['createdAt'] as String),
          ),
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.take(40).toList();
  }

  Future<FallLeagueBoard> league() async {
    final id = await locale();
    await _settleWeek(id);
    final current = _readSync(await _map(id), id);
    final seed = Object.hash(DateKeys.weekId(_clock()), id, current.tier.name);
    final random = Random(seed);
    final names = id == 'en' ? _enNpc : _trNpc;
    final standings = <FallStanding>[
      FallStanding(
        name: current.displayName,
        points: current.weeklyPoints,
        isPlayer: true,
      ),
      for (var i = 0; i < 19; i++)
        FallStanding(
          name: names[i % names.length],
          points: 80 + random.nextInt(420 + current.tier.index * 80),
          isPlayer: false,
        ),
    ]..sort((a, b) => b.points.compareTo(a.points));
    final rule = id == 'en'
        ? 'Weekly points are your best 3 runs. Turkish and English boards never mix. No demotion in your first week on a tier.'
        : 'Haftalık puan, en iyi 3 koşunun toplamı. Türkçe ve İngilizce tablolar karışmaz. Bir kademedeki ilk haftanda düşmezsin.';
    return FallLeagueBoard(
      locale: id,
      tier: current.tier,
      weekId: DateKeys.weekId(_clock()),
      standings: standings,
      rule: rule,
    );
  }

  Future<Map<String, dynamic>> adminOverview() async {
    final runs = await _store.values('runs');
    final profiles = await _store.values('profiles');
    return {
      'runs': runs.length,
      'profiles': profiles.length,
      'trCoins': _coins(profiles, 'tr'),
      'enCoins': _coins(profiles, 'en'),
    };
  }

  int _coins(List<Map<String, dynamic>> profiles, String locale) {
    for (final row in profiles) {
      if (row['locale'] == locale) return row['coins'] as int? ?? 0;
    }
    return 0;
  }

  Future<void> _settleWeek(String id) async {
    final map = await _map(id);
    final week = DateKeys.weekId(_clock());
    final stored = map['weekId'] as String?;
    if (stored == null) {
      map['weekId'] = week;
      await _store.put('profiles', id, map);
      return;
    }
    if (stored == week) return;
    final points = FallRules.weeklyPoints(_ints(map['weekScores']));
    final tier = FallTier.values.firstWhere((t) => t.name == map['tier']);
    final group = _npcPoints(id, tier, stored);
    group.add(points);
    group.sort((a, b) => b.compareTo(a));
    final rank = group.indexOf(points);
    final size = group.length;
    final top = (size * 0.2).ceil();
    final bottom = size - top;
    var next = tier;
    final weeks = (map['weeksInTier'] as int) + 1;
    if (rank < top && tier.index < FallTier.legend.index) {
      next = FallTier.values[tier.index + 1];
    } else if (weeks > 1 && rank >= bottom && tier.index > 0) {
      next = FallTier.values[tier.index - 1];
    }
    var coins = map['coins'] as int;
    if (next != tier) coins += FallRules.tierReward(next);
    map['coins'] = coins;
    map['tier'] = next.name;
    map['weeksInTier'] = next == tier ? weeks : 1;
    map['weekId'] = week;
    map['weekScores'] = <int>[];
    await _store.put('profiles', id, map);
  }

  List<int> _npcPoints(String locale, FallTier tier, String week) {
    final random = Random(Object.hash(week, locale, tier.name));
    return [for (var i = 0; i < 19; i++) 80 + random.nextInt(420 + tier.index * 80)];
  }

  Future<void> _rollDay(String id) async {
    final map = await _map(id);
    final day = DateKeys.dayKey(_clock());
    if (map['day'] != day) {
      map['day'] = day;
      map['runsToday'] = 0;
      map['bannerToday'] = 0;
      map['rewardToday'] = 0;
      await _store.put('profiles', id, map);
    }
  }

  Future<Map<String, dynamic>> _map(String id) async {
    return Map<String, dynamic>.from((await _store.get('profiles', id)) ?? _fresh(id));
  }

  Future<FallProfile> _read(String id) async => _profileFrom(id, await _map(id));

  FallProfile _readSync(Map<String, dynamic> map, String id) => _profileFrom(id, map);

  FallProfile _profileFrom(String id, Map<String, dynamic> map) {
    return FallProfile(
      locale: id,
      coins: map['coins'] as int,
      xp: map['xp'] as int,
      premium: map['premium'] == true,
      tier: FallTier.values.firstWhere((t) => t.name == map['tier']),
      weeksInTier: map['weeksInTier'] as int,
      bestScore: map['bestScore'] as int,
      wordsCaught: map['wordsCaught'] as int,
      runsToday: map['runsToday'] as int,
      bannerToday: map['bannerToday'] as int,
      rewardToday: map['rewardToday'] as int,
      weekScores: _ints(map['weekScores']),
      hints: map['hints'] as int,
      shields: map['shields'] as int,
      jokers: map['jokers'] as int,
      extraLives: map['extraLives'] as int,
      extraTimes: map['extraTimes'] as int,
      displayName: map['displayName'] as String,
    );
  }

  List<int> _ints(Object? raw) {
    if (raw is! List) return [];
    return raw.map((e) => e as int).toList();
  }

  Map<String, dynamic> _fresh(String locale) => {
        'locale': locale,
        'coins': 100,
        'xp': 0,
        'premium': false,
        'tier': FallTier.stone.name,
        'weeksInTier': 1,
        'bestScore': 0,
        'wordsCaught': 0,
        'runsToday': 0,
        'bannerToday': 0,
        'rewardToday': 0,
        'day': DateKeys.dayKey(_clock()),
        'weekId': DateKeys.weekId(_clock()),
        'weekScores': <int>[],
        'hints': 1,
        'shields': 0,
        'jokers': 0,
        'extraLives': 0,
        'extraTimes': 0,
        'displayName': locale == 'en' ? 'Guest' : 'Misafir',
      };

  List<FallProduct> _catalog() => const [
        FallProduct(id: 'coins_100', coins: 100, priceLabel: '₺19,99', kind: 'coins'),
        FallProduct(id: 'coins_500', coins: 500, priceLabel: '₺79,99', kind: 'coins'),
        FallProduct(id: 'coins_1200', coins: 1200, priceLabel: '₺149,99', kind: 'coins'),
        FallProduct(id: 'hint', coins: 10, priceLabel: '10', kind: 'hint'),
        FallProduct(id: 'shield', coins: 50, priceLabel: '50', kind: 'shield'),
        FallProduct(id: 'joker', coins: 75, priceLabel: '75', kind: 'joker'),
        FallProduct(id: 'life', coins: 100, priceLabel: '100', kind: 'life'),
        FallProduct(id: 'time', coins: 30, priceLabel: '30', kind: 'time'),
      ];
}

const _trNpc = [
  'Ege', 'Deniz', 'Ada', 'Poyraz', 'Yıldız', 'Nehir', 'Toprak', 'Mercan',
  'Rüzgar', 'Defne', 'Kuzey', 'Lara', 'Aras', 'Melisa', 'Doruk', 'Su',
  'Atlas', 'Mina', 'Kerem',
];

const _enNpc = [
  'Nova', 'Reed', 'Wren', 'Jules', 'Sky', 'Quinn', 'Rowan', 'Eden',
  'Blair', 'Sage', 'Remy', 'Drew', 'Harper', 'Lane', 'Rio', 'Ash',
  'Parker', 'Shay', 'Kit',
];
