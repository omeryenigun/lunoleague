import 'dart:math';

import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_shop.dart';

const bilgiWalletUsers = 'users';
const bilgiWalletConfig = 'config';

const bilgiWalletReasons = <String>[
  'starter',
  'opening',
  'life_spend',
  'life_regen',
  'round_finish',
  'score_double',
  'joker_buy',
  'joker_use',
  'life_refill',
  'daily',
  'ad_gold',
  'ad_joker',
  'ad_life',
  'play_gold',
  'play_plus',
  'invite',
  'league_monday',
  'admin',
];

/// One immutable wallet movement. [amount] is positive for a credit and negative for a debit.
class BilgiLedgerLine {
  const BilgiLedgerLine({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.asset,
    required this.amount,
    required this.balanceAfter,
    required this.reason,
    this.ref = '',
    this.detail = const {},
  });

  final String id;
  final String userId;
  final DateTime createdAt;
  final String asset;
  final int amount;
  final int balanceAfter;
  final String reason;
  final String ref;
  final Map<String, Object?> detail;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'createdAt': createdAt.toIso8601String(),
        'asset': asset,
        'amount': amount,
        'balanceAfter': balanceAfter,
        'reason': reason,
        'ref': ref,
        'detail': detail,
      };

  factory BilgiLedgerLine.fromMap(Map<String, dynamic> map) {
    final rawDetail = map['detail'];
    return BilgiLedgerLine(
      id: '${map['id'] ?? ''}',
      userId: '${map['userId'] ?? ''}',
      createdAt: DateTime.tryParse('${map['createdAt'] ?? ''}')?.toUtc() ?? DateTime.now().toUtc(),
      asset: '${map['asset'] ?? ''}',
      amount: bilgiInt(map['amount'], 0),
      balanceAfter: bilgiInt(map['balanceAfter'], 0),
      reason: '${map['reason'] ?? ''}',
      ref: '${map['ref'] ?? ''}',
      detail: rawDetail is Map ? Map<String, Object?>.from(rawDetail) : const {},
    );
  }
}

class BilgiWalletReply {
  const BilgiWalletReply({this.profile, this.error, this.livesReported = true});

  final BilgiProfile? profile;
  final String? error;

  /// False when the payload omitted lives. The phone keeps the lives it already shows.
  final bool livesReported;

  bool get ok => error == null && profile != null;
}

abstract class BilgiLedgerRepo {
  Future<bool> seen(String userId, String reason, String ref);
  Future<void> append(List<BilgiLedgerLine> lines);
  Future<List<BilgiLedgerLine>> list(
    String userId, {
    String asset = '',
    String reason = '',
    DateTime? from,
    DateTime? to,
  });
}

class MemoryBilgiLedger implements BilgiLedgerRepo {
  final lines = <BilgiLedgerLine>[];

  @override
  Future<bool> seen(String userId, String reason, String ref) async {
    if (ref.isEmpty) return false;
    return lines.any((line) => line.userId == userId && line.reason == reason && line.ref == ref);
  }

  @override
  Future<void> append(List<BilgiLedgerLine> incoming) async {
    for (final line in incoming) {
      final duplicate = line.ref.isNotEmpty &&
          lines.any((row) => row.userId == line.userId && row.reason == line.reason && row.ref == line.ref && row.asset == line.asset);
      if (duplicate) continue;
      lines.add(line);
    }
  }

  @override
  Future<List<BilgiLedgerLine>> list(
    String userId, {
    String asset = '',
    String reason = '',
    DateTime? from,
    DateTime? to,
  }) async {
    final rows = lines.where((line) {
      if (line.userId != userId) return false;
      if (asset.isNotEmpty && line.asset != asset) return false;
      if (reason.isNotEmpty && line.reason != reason) return false;
      if (from != null && line.createdAt.isBefore(from)) return false;
      if (to != null && line.createdAt.isAfter(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }
}

final _ids = Random();

String bilgiLedgerId(String asset) => 'w${DateTime.now().microsecondsSinceEpoch}${_ids.nextInt(9999)}-$asset';

/// Copies the server wallet onto the phone. Ad-free play counters stay on the device.
/// Locale stays on the device until the server has a chosen locale.
BilgiProfile bilgiApplyWallet(BilgiProfile local, BilgiProfile remote, {bool livesReported = true}) {
  final name = remote.username.trim();
  return local.copyWith(
    id: remote.id,
    username: name.isEmpty ? local.username : name,
    email: remote.email.isNotEmpty ? remote.email : local.email,
    avatar: remote.avatar,
    city: remote.city,
    locale: remote.localeChosen ? remote.locale : local.locale,
    localeChosen: local.localeChosen || remote.localeChosen,
    banned: remote.banned,
    banReason: remote.banReason,
    gold: remote.gold,
    xp: remote.xp,
    level: remote.level,
    diamond: remote.diamond,
    lives: livesReported ? remote.lives : local.lives,
    livesAt: livesReported ? remote.livesAt : local.livesAt,
    jokers: remote.jokers,
    totalScore: remote.totalScore,
    weekId: remote.weekId,
    weekScore: remote.weekScore,
    categoryScores: remote.categoryScores,
    heldWeekId: remote.heldWeekId,
    heldWeekScore: remote.heldWeekScore,
    heldCategoryWeeks: remote.heldCategoryWeeks,
    leagueRewardWeek: remote.leagueRewardWeek,
    leagueRewardText: remote.leagueRewardText,
    title: remote.title,
    premium: remote.premium,
    premiumUntil: remote.premiumUntil,
    clearPremiumUntil: remote.premiumUntil == null,
    gamesPlayed: remote.gamesPlayed,
    correctTotal: remote.correctTotal,
    bestScore: remote.bestScore,
    duelWins: remote.duelWins,
    categoriesPlayed: remote.categoriesPlayed,
    badges: remote.badges,
    adGoldToday: remote.adGoldToday,
    adJokerToday: remote.adJokerToday,
    adLifeToday: remote.adLifeToday,
    adDoubleToday: remote.adDoubleToday,
    adDay: remote.adDay,
    lastReward: remote.lastReward,
    rewardDay: remote.rewardDay,
    streak: remote.streak,
    friends: remote.friends,
    invites: remote.invites,
  );
}

/// A brand-new server row. Identity comes from the phone; stocks are the starter wallet.
BilgiProfile bilgiBornProfile(BilgiProfile incoming) {
  final fresh = bilgiFreshProfile(
    id: incoming.id,
    now: DateTime.now().toUtc(),
    config: const BilgiConfig(),
    username: incoming.username,
  );
  return fresh.copyWith(
    avatar: incoming.avatar,
    city: incoming.city,
    locale: incoming.locale,
    localeChosen: incoming.localeChosen,
    email: incoming.email.trim(),
    passwordHash: incoming.passwordHash,
  );
}

/// Identity may change from the phone. Gold, jokers, XP, lives, and scores stay on the server row.
/// Reward text clears only after this device has the same reward week and dismisses it.
BilgiProfile bilgiKeepServerWallet(BilgiProfile server, BilgiProfile client) {
  final name = client.username.trim();
  final sameReward = client.leagueRewardWeek == server.leagueRewardWeek;
  return server.copyWith(
    username: name.isEmpty ? server.username : name,
    avatar: client.avatar,
    city: client.city,
    locale: client.locale,
    localeChosen: client.localeChosen || server.localeChosen,
    email: server.email.isNotEmpty ? server.email : client.email.trim(),
    passwordHash: server.passwordHash.isNotEmpty ? server.passwordHash : client.passwordHash,
    leagueRewardText: sameReward && client.leagueRewardText.isEmpty ? '' : server.leagueRewardText,
  );
}

/// Writes the geçiş bakiyesi once, before a later delta, so opening is not the post-change stock.
Future<void> bilgiEnsureOpening(BilgiLedgerRepo ledger, BilgiProfile user, {DateTime? at}) async {
  if (await ledger.seen(user.id, 'opening', 'opening')) return;
  if (await ledger.seen(user.id, 'starter', 'starter')) return;
  await ledger.append(bilgiWalletSnapshot(user, reason: 'opening', ref: 'opening', at: at));
}

/// Yesterday's ad counters do not carry into today.
BilgiProfile bilgiRollAdDay(BilgiProfile user, DateTime now) {
  final today = bilgiDayKey(now);
  if (user.adDay == today) return user;
  return user.copyWith(
    adGoldToday: 0,
    adJokerToday: 0,
    adLifeToday: 0,
    adDoubleToday: 0,
    adDay: today,
  );
}

List<BilgiLedgerLine> bilgiLedgerDiff({
  required BilgiProfile before,
  required BilgiProfile after,
  required String reason,
  required String ref,
  Map<String, Object?> detail = const {},
  DateTime? at,
}) {
  final now = at ?? DateTime.now().toUtc();
  final info = <String, Object?>{
    ...detail,
    if (before.level != after.level) 'level': after.level,
  };
  final lines = <BilgiLedgerLine>[];
  void add(String asset, int delta, int balance, [Map<String, Object?>? extra]) {
    if (delta == 0) return;
    lines.add(BilgiLedgerLine(
      id: bilgiLedgerId(asset),
      userId: after.id,
      createdAt: now,
      asset: asset,
      amount: delta,
      balanceAfter: balance,
      reason: reason,
      ref: ref,
      detail: extra == null ? info : {...info, ...extra},
    ));
  }

  add('gold', after.gold - before.gold, after.gold);
  add('diamond', after.diamond - before.diamond, after.diamond);
  add('xp', after.xp - before.xp, after.xp);
  add('life', after.lives - before.lives, after.lives);
  final keys = {...before.jokers.keys, ...after.jokers.keys};
  for (final key in keys) {
    final prev = before.jokers[key] ?? 0;
    final next = after.jokers[key] ?? 0;
    add('joker_$key', next - prev, next);
  }
  add('league_score', after.totalScore - before.totalScore, after.totalScore);
  if (before.premium != after.premium || before.premiumUntil != after.premiumUntil) {
    lines.add(BilgiLedgerLine(
      id: bilgiLedgerId('premium'),
      userId: after.id,
      createdAt: now,
      asset: 'premium',
      amount: after.premium ? 1 : -1,
      balanceAfter: after.premium ? 1 : 0,
      reason: reason,
      ref: ref,
      detail: {
        ...info,
        if (after.premiumUntil != null) 'premiumUntil': after.premiumUntil!.toIso8601String(),
      },
    ));
  }
  return lines;
}

/// Opening or starter snapshot. Gold, XP, lives, and league score are written even when zero.
List<BilgiLedgerLine> bilgiWalletSnapshot(
  BilgiProfile user, {
  required String reason,
  required String ref,
  DateTime? at,
}) {
  final now = at ?? DateTime.now().toUtc();
  final lines = <BilgiLedgerLine>[];
  void add(String asset, int balance) {
    lines.add(BilgiLedgerLine(
      id: bilgiLedgerId(asset),
      userId: user.id,
      createdAt: now,
      asset: asset,
      amount: balance,
      balanceAfter: balance,
      reason: reason,
      ref: ref,
    ));
  }

  add('gold', user.gold);
  add('xp', user.xp);
  add('life', user.lives);
  add('league_score', user.totalScore);
  if (user.diamond != 0) add('diamond', user.diamond);
  for (final entry in user.jokers.entries) {
    if (entry.value == 0) continue;
    add('joker_${entry.key}', entry.value);
  }
  if (user.premium) {
    lines.add(BilgiLedgerLine(
      id: bilgiLedgerId('premium'),
      userId: user.id,
      createdAt: now,
      asset: 'premium',
      amount: 1,
      balanceAfter: 1,
      reason: reason,
      ref: ref,
      detail: {if (user.premiumUntil != null) 'premiumUntil': user.premiumUntil!.toIso8601String()},
    ));
  }
  return lines;
}

BilgiProfile bilgiFreshProfile({
  required String id,
  required DateTime now,
  required BilgiConfig config,
  String username = '',
}) {
  final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
  final guest = 'Misafir${digits.isEmpty ? '1' : digits.substring(max(0, digits.length - 9))}';
  final name = username.trim().isEmpty ? guest : username.trim();
  return BilgiProfile(
    id: id,
    username: name,
    email: '',
    passwordHash: '',
    avatar: '😎',
    level: 1,
    xp: 0,
    gold: 500,
    diamond: 0,
    lives: config.startLives,
    livesAt: now,
    title: 'Çaylak',
    premium: false,
    premiumUntil: null,
    banned: false,
    banReason: '',
    city: '',
    createdAt: now,
    jokers: {
      'half': config.jokerStarts['half'] ?? 2,
      'double': config.jokerStarts['double'] ?? 1,
      'time': config.jokerStarts['time'] ?? 1,
      'change': config.jokerStarts['change'] ?? 0,
      'hint': config.jokerStarts['hint'] ?? 0,
    },
    gamesPlayed: 0,
    correctTotal: 0,
    bestScore: 0,
    totalScore: 0,
    streak: 0,
    lastReward: '',
    rewardDay: 0,
    lastPlayDay: '',
    freePlaysUsed: 0,
    adFreeLeft: config.newUserAdFree,
    inviteCode: 'LB${id.hashCode.abs() % 90 + 10}',
    invites: 0,
    friends: const [],
    badges: const [],
    duelWins: 0,
    categoriesPlayed: const [],
    adGoldToday: 0,
    adJokerToday: 0,
    adLifeToday: 0,
    adDoubleToday: 0,
    adDay: bilgiDayKey(now),
    weekId: bilgiWeekId(now),
    weekScore: 0,
  );
}

BilgiProfile bilgiRegenProfile(BilgiProfile user, BilgiConfig config, DateTime now) {
  final lives = regeneratedLives(
    lives: user.lives,
    livesAt: user.livesAt,
    now: now,
    maxLives: config.maxLives,
    minutesPerLife: config.lifeMinutes,
  );
  if (lives == user.lives) return user;
  final clock = livesClockAfterRegen(
    lives: user.lives,
    livesAt: user.livesAt,
    now: now,
    maxLives: config.maxLives,
    minutesPerLife: config.lifeMinutes,
  );
  return user.copyWith(lives: lives, livesAt: lives >= config.maxLives ? now : clock);
}

BilgiProfile bilgiWithBadges(BilgiProfile user) {
  final earned = {...user.badges};
  for (final badge in bilgiBadges) {
    final value = switch (badge.type) {
      'games' => user.gamesPlayed,
      'correct' => user.correctTotal,
      'level' => user.level,
      'diamond' => user.diamond,
      _ => 0,
    };
    if (value >= badge.value) earned.add(badge.id);
  }
  return user.copyWith(badges: earned.toList());
}

/// Server wallet. The phone asks for an operation; this book changes the stored profile and appends the ledger.
class BilgiWalletBook {
  BilgiWalletBook(this.store, this.ledger, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final KeyValueStore store;
  final BilgiLedgerRepo ledger;
  final DateTime Function() _clock;

  Future<BilgiWalletReply> apply(Map<String, dynamic> body) async {
    final op = '${body['op'] ?? ''}';
    return switch (op) {
      'sync' => _sync(body),
      'bind' => _bind(body),
      'life_spend' => _lifeSpend(body),
      'finish' => _finish(body),
      'score_double' => _scoreDouble(body),
      'joker_use' => _jokerUse(body),
      'joker_buy' => _jokerBuy(body),
      'life_refill' => _lifeRefill(body),
      'daily' => _daily(body),
      'ad' => _ad(body),
      'play' => _play(body),
      'invite' => _invite(body),
      _ => const BilgiWalletReply(error: 'İşlem geçersiz.'),
    };
  }

  Future<BilgiConfig> _config() async {
    final raw = await store.get(bilgiWalletConfig, 'main');
    if (raw == null) return const BilgiConfig();
    return BilgiConfig.fromMap(raw);
  }

  Future<BilgiProfile?> _load(String id) async {
    final raw = await store.get(bilgiWalletUsers, id);
    if (raw == null) return null;
    return BilgiProfile.fromMap(raw);
  }

  Future<void> _put(BilgiProfile user) => store.put(bilgiWalletUsers, user.id, user.toMap());

  Future<bool> _done(String userId, String reason, String ref) async {
    if (ref.isEmpty) return false;
    if (await ledger.seen(userId, reason, ref)) return true;
    return await store.getMeta('wallet:$userId:$reason:$ref') == '1';
  }

  Future<void> _mark(String userId, String reason, String ref) => store.putMeta('wallet:$userId:$reason:$ref', '1');

  Future<BilgiProfile> _ensureLedger(BilgiProfile user, {required bool starter}) async {
    if (starter) {
      if (await ledger.seen(user.id, 'starter', 'starter')) return user;
      await ledger.append(bilgiWalletSnapshot(user, reason: 'starter', ref: 'starter', at: _clock()));
      return user;
    }
    await bilgiEnsureOpening(ledger, user, at: _clock());
    return user;
  }

  Future<BilgiProfile> _rollAds(BilgiProfile user) async {
    final next = bilgiRollAdDay(user, _clock());
    if (next.adDay == user.adDay &&
        next.adGoldToday == user.adGoldToday &&
        next.adJokerToday == user.adJokerToday &&
        next.adLifeToday == user.adLifeToday &&
        next.adDoubleToday == user.adDoubleToday) {
      return user;
    }
    await _put(next);
    return next;
  }

  Future<BilgiProfile> _prepare(BilgiProfile user, {required bool starter}) async {
    await _ensureLedger(user, starter: starter);
    final regenerated = await _regen(user, await _config());
    return _rollAds(regenerated);
  }

  Future<BilgiProfile> _regen(BilgiProfile user, BilgiConfig config) async {
    final next = bilgiRegenProfile(user, config, _clock());
    if (next.lives == user.lives) return user;
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'life_regen',
      ref: '${next.livesAt.toIso8601String()}#${next.lives}',
      detail: {
        'before': user.lives,
        'after': next.lives,
        'livesAt': next.livesAt.toIso8601String(),
      },
      at: _clock(),
    ));
    await _put(next);
    return next;
  }

  Future<BilgiWalletReply> _sync(Map<String, dynamic> body) async {
    final id = '${body['userId'] ?? ''}'.trim();
    if (id.isEmpty || id.length > 80) return const BilgiWalletReply(error: 'Kullanıcı geçersiz.');
    final config = await _config();
    final existing = await _load(id);
    if (existing == null) {
      final created = bilgiFreshProfile(id: id, now: _clock(), config: config);
      await _put(created);
      await _ensureLedger(created, starter: true);
      return BilgiWalletReply(profile: created);
    }
    if (existing.banned) return const BilgiWalletReply(error: '🚫 Hesabın askıya alındı.');
    return BilgiWalletReply(profile: await _prepare(existing, starter: false));
  }

  Future<BilgiWalletReply> _bind(Map<String, dynamic> body) async {
    final email = '${body['email'] ?? ''}'.trim();
    if (!email.contains('@')) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    final mail = email.toLowerCase();
    final userId = '${body['userId'] ?? ''}'.trim();
    final check = '${body['passwordHashCheck'] ?? ''}';
    final givenHash = '${body['passwordHash'] ?? ''}';
    final googleId = '${body['googleId'] ?? ''}'.trim();
    final username = '${body['username'] ?? ''}'.trim();
    final found = await _byEmail(mail);
    if (check.isNotEmpty) {
      if (found == null || found.passwordHash.isEmpty || found.passwordHash != check) {
        return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
      }
      if (found.banned) return const BilgiWalletReply(error: '🚫 Hesabın askıya alındı.');
      final ready = await _prepare(found, starter: false);
      await _link(ready, provider: 'email', email: mail);
      return BilgiWalletReply(profile: ready);
    }
    if (found != null) {
      if (found.banned) return const BilgiWalletReply(error: '🚫 Hesabın askıya alındı.');
      final ready = await _prepare(found, starter: false);
      await _link(ready, provider: googleId.isEmpty ? 'email' : 'google', email: mail, googleId: googleId);
      return BilgiWalletReply(profile: ready);
    }
    final config = await _config();
    var user = userId.isEmpty ? null : await _load(userId);
    final created = user == null;
    user ??= bilgiFreshProfile(id: userId.isEmpty ? 'u${_clock().microsecondsSinceEpoch}' : userId, now: _clock(), config: config);
    final name = username.length >= 2 ? username : user.username;
    if (bilgiUsernameChangeTaken(
      await store.values(bilgiWalletUsers),
      nextName: name,
      currentName: user.username,
      exceptId: user.id,
    )) {
      return const BilgiWalletReply(error: UserMessages.nicknameTaken);
    }
    if (created) await _put(user);
    final next = user.copyWith(
      username: name,
      email: email,
      passwordHash: givenHash.isNotEmpty ? givenHash : user.passwordHash,
    );
    await _put(next);
    final ready = await _prepare(next, starter: created);
    await _link(ready, provider: googleId.isEmpty ? 'email' : 'google', email: mail, googleId: googleId);
    return BilgiWalletReply(profile: ready);
  }

  Future<void> _link(BilgiProfile user, {required String provider, required String email, String googleId = ''}) async {
    try {
      await LunoAccountDirectory(lunoAccountRoot(store)).link(
        gameId: GameIds.lunoBilgi,
        progressId: user.id,
        displayName: user.username,
        provider: provider,
        email: email,
        googleId: googleId,
      );
    } catch (_) {}
  }

  Future<BilgiProfile?> _byEmail(String mail) async {
    for (final row in await store.values(bilgiWalletUsers)) {
      if ('${row['email'] ?? ''}'.trim().toLowerCase() == mail) return BilgiProfile.fromMap(row);
    }
    return null;
  }

  Future<BilgiWalletReply> _lifeSpend(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final ref = '${body['roundId'] ?? ''}'.trim();
    if (ref.isEmpty) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    if (await _done(user.id, 'life_spend', ref)) return BilgiWalletReply(profile: user);
    final config = await _config();
    final mode = config.resolvedMode(bilgiModeById('${body['modeId'] ?? ''}'));
    if (config.livesEnabled && user.lives < mode.lifeCost) {
      return BilgiWalletReply(error: bilgiNoLivesNotice(config.lifeMinutes));
    }
    var next = user.copyWith(gamesPlayed: user.gamesPlayed + 1);
    if (config.livesEnabled && mode.lifeCost > 0) {
      final atFull = user.lives >= config.maxLives;
      next = next.copyWith(
        lives: user.lives - mode.lifeCost,
        livesAt: atFull ? _clock() : user.livesAt,
      );
    }
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'life_spend',
      ref: ref,
      detail: {'modeId': mode.id, 'lifeCost': mode.lifeCost},
      at: _clock(),
    ));
    await _mark(user.id, 'life_spend', ref);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _finish(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final ref = '${body['roundId'] ?? ''}'.trim();
    if (ref.isEmpty) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    if (await _done(user.id, 'round_finish', ref)) return BilgiWalletReply(profile: user);
    final score = bilgiInt(body['score'], 0);
    final multiplier = double.tryParse('${body['multiplier'] ?? ''}') ?? 1;
    final modeId = '${body['modeId'] ?? ''}';
    final correct = bilgiInt(body['correct'], 0);
    final categoryId = '${body['categoryId'] ?? ''}';
    final opponentName = '${body['opponentName'] ?? ''}';
    final opponentScore = bilgiInt(body['opponentScore'], -1);
    var gold = goldForScore(score, multiplier);
    var xp = xpForScore(score);
    if (modeId == 'yarisma') {
      gold = bilgiContestGold(correct);
      xp = bilgiContestXp(correct);
    }
    if (modeId == 'gunluk' && correct > 0) {
      gold = 100;
      xp = 50;
    }
    if (modeId == 'duello' && opponentName.isNotEmpty && opponentScore >= 0) {
      gold = score >= opponentScore ? 50 : 10;
    }
    final level = applyXp(level: user.level, xp: user.xp, gained: xp);
    final scored = modeId == 'yarisma'
        ? user
        : bilgiAddScore(user, points: score, categoryId: categoryId, now: _clock());
    final duelWins = user.duelWins +
        ((modeId == 'duello' && opponentName.isNotEmpty && opponentScore >= 0 && score >= opponentScore) ? 1 : 0);
    final next = bilgiWithBadges(scored.copyWith(
      gold: scored.gold + gold,
      xp: level.xp,
      level: level.level,
      diamond: scored.diamond + level.diamondsGained,
      correctTotal: scored.correctTotal + correct,
      bestScore: score > scored.bestScore ? score : scored.bestScore,
      categoriesPlayed: modeId == 'yarisma' ? user.categoriesPlayed : {...user.categoriesPlayed, categoryId}.toList(),
      duelWins: duelWins,
      title: level.level >= 10 ? 'Bilge' : user.title,
    ));
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'round_finish',
      ref: ref,
      detail: {
        'modeId': modeId,
        'categoryId': categoryId,
        'score': score,
        'multiplier': multiplier,
        'correct': correct,
        if ('${body['difficulty'] ?? ''}'.isNotEmpty) 'difficulty': '${body['difficulty']}',
      },
      at: _clock(),
    ));
    await _mark(user.id, 'round_finish', ref);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _scoreDouble(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = bilgiRollAdDay(loaded.profile!, _clock());
    final ref = '${body['roundId'] ?? ''}'.trim();
    if (ref.isEmpty) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    if (await _done(user.id, 'score_double', ref)) return BilgiWalletReply(profile: user);
    final config = await _config();
    final today = bilgiDayKey(_clock());
    final used = user.adDay == today ? user.adDoubleToday : 0;
    if (used >= config.rewardedDoubleLimit) return const BilgiWalletReply(error: '📅 Bugünkü hakkını kullandın.');
    final extra = bilgiInt(body['score'], 0);
    if (extra <= 0) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    final categoryId = '${body['categoryId'] ?? ''}';
    final scored = bilgiAddScore(user, points: extra, categoryId: categoryId, now: _clock());
    final doubled = extra * 2;
    final next = scored.copyWith(
      bestScore: doubled > scored.bestScore ? doubled : scored.bestScore,
      adDoubleToday: used + 1,
      adDay: today,
    );
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'score_double',
      ref: ref,
      detail: {'categoryId': categoryId, 'score': extra, 'today': used + 1, 'limit': config.rewardedDoubleLimit},
      at: _clock(),
    ));
    await _mark(user.id, 'score_double', ref);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _jokerUse(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final type = '${body['type'] ?? ''}';
    final roundId = '${body['roundId'] ?? ''}'.trim();
    final index = bilgiInt(body['index'], 0);
    final ref = '$roundId#$index';
    if (roundId.isEmpty) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    if (await _done(user.id, 'joker_use', ref)) return BilgiWalletReply(profile: user);
    final stock = user.jokers[type] ?? 0;
    if (stock <= 0) return BilgiWalletReply(error: 'joker', profile: user);
    final jokers = Map<String, int>.from(user.jokers);
    jokers[type] = stock - 1;
    final next = user.copyWith(jokers: jokers);
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'joker_use',
      ref: ref,
      detail: {'type': type, 'roundId': roundId},
      at: _clock(),
    ));
    await _mark(user.id, 'joker_use', ref);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _jokerBuy(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final type = '${body['type'] ?? ''}';
    final config = await _config();
    final price = config.jokerPrices[type] ?? 50;
    if (user.gold < price) return const BilgiWalletReply(error: '🪙 Yeterli altının yok. Mağazadan altın al.');
    final jokers = Map<String, int>.from(user.jokers);
    jokers[type] = (jokers[type] ?? 0) + 1;
    final next = user.copyWith(gold: user.gold - price, jokers: jokers);
    final ref = 'buy-$type-${_clock().microsecondsSinceEpoch}';
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'joker_buy',
      ref: ref,
      detail: {'type': type, 'price': price},
      at: _clock(),
    ));
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _lifeRefill(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final config = await _config();
    if (user.gold < config.lifePrice) return const BilgiWalletReply(error: '🪙 Yeterli altının yok. Mağazadan altın al.');
    final next = user.copyWith(gold: user.gold - config.lifePrice, lives: config.maxLives, livesAt: _clock());
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'life_refill',
      ref: 'life-${_clock().microsecondsSinceEpoch}',
      detail: {'price': config.lifePrice},
      at: _clock(),
    ));
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _daily(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final config = await _config();
    final today = bilgiDayKey(_clock());
    if (user.lastReward == today || await _done(user.id, 'daily', today)) {
      return const BilgiWalletReply(error: '📅 Bugünkü hakkını kullandın.');
    }
    final doubled = body['doubled'] == true;
    final yesterday = bilgiDayKey(_clock().toUtc().subtract(const Duration(days: 1)));
    final index = user.lastReward == yesterday ? user.rewardDay % 7 : 0;
    final gold = dayRewardAmount(config.dailyGold, index) * (doubled ? 2 : 1);
    final diamond = dayRewardAmount(config.dailyDiamond, index) * (doubled ? 2 : 1);
    final joker = dayRewardAmount(config.dailyJoker, index) * (doubled ? 2 : 1);
    final jokers = Map<String, int>.from(user.jokers);
    jokers['half'] = (jokers['half'] ?? 0) + joker;
    final next = user.copyWith(
      gold: user.gold + gold,
      diamond: user.diamond + diamond,
      jokers: jokers,
      lastReward: today,
      rewardDay: (index + 1) % 7,
      streak: user.lastReward == yesterday ? user.streak + 1 : 1,
    );
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'daily',
      ref: today,
      detail: {'day': index + 1, 'doubled': doubled},
      at: _clock(),
    ));
    await _mark(user.id, 'daily', today);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _ad(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = bilgiRollAdDay(loaded.profile!, _clock());
    final kind = '${body['kind'] ?? ''}';
    final config = await _config();
    final today = bilgiDayKey(_clock());
    final sameDay = user.adDay == today;
    final goldUsed = sameDay ? user.adGoldToday : 0;
    final jokerUsed = sameDay ? user.adJokerToday : 0;
    final lifeUsed = sameDay ? user.adLifeToday : 0;
    if (kind == 'gold' && goldUsed >= config.rewardedGoldLimit) {
      return const BilgiWalletReply(error: '📅 Bugünkü hakkını kullandın.');
    }
    if (kind == 'joker' && jokerUsed >= config.rewardedJokerLimit) {
      return const BilgiWalletReply(error: '📅 Bugünkü hakkını kullandın.');
    }
    if (kind == 'life' && lifeUsed >= config.rewardedLifeLimit) {
      return const BilgiWalletReply(error: '📅 Bugünkü hakkını kullandın.');
    }
    final reason = switch (kind) {
      'gold' => 'ad_gold',
      'joker' => 'ad_joker',
      'life' => 'ad_life',
      _ => '',
    };
    if (reason.isEmpty) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    final used = switch (kind) {
      'gold' => goldUsed,
      'joker' => jokerUsed,
      _ => lifeUsed,
    };
    final ref = '$today#$kind#$used';
    if (await _done(user.id, reason, ref)) return BilgiWalletReply(profile: user);
    var next = user.copyWith(adDay: today);
    if (kind == 'gold') {
      next = next.copyWith(gold: user.gold + config.rewardedGold, adGoldToday: goldUsed + 1);
    } else if (kind == 'joker') {
      final jokers = Map<String, int>.from(user.jokers);
      jokers['half'] = (jokers['half'] ?? 0) + 1;
      next = next.copyWith(jokers: jokers, adJokerToday: jokerUsed + 1);
    } else {
      next = next.copyWith(lives: (user.lives + 1).clamp(0, config.maxLives), adLifeToday: lifeUsed + 1);
    }
    final limit = switch (kind) {
      'gold' => config.rewardedGoldLimit,
      'joker' => config.rewardedJokerLimit,
      _ => config.rewardedLifeLimit,
    };
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: reason,
      ref: ref,
      detail: {'kind': kind, 'today': used + 1, 'limit': limit},
      at: _clock(),
    ));
    await _mark(user.id, reason, ref);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _play(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final productId = '${body['productId'] ?? ''}';
    final basePlanId = '${body['basePlanId'] ?? ''}';
    final orderId = '${body['orderId'] ?? ''}'.trim();
    final tokenRef = '${body['tokenRef'] ?? ''}'.trim();
    final ref = orderId.isNotEmpty ? orderId : tokenRef;
    if (ref.isEmpty) return const BilgiWalletReply(error: 'Satın alma doğrulanamadı.');
    final sku = bilgiPlaySku(productId, basePlanId.isEmpty ? null : basePlanId);
    if (sku == null) return const BilgiWalletReply(error: 'Satın alma doğrulanamadı.');
    final reason = sku.gold > 0 ? 'play_gold' : 'play_plus';
    if (await _done(user.id, reason, ref)) return BilgiWalletReply(profile: user);
    final next = applyBilgiPlayReward(user, sku, _clock());
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: reason,
      ref: ref,
      detail: {
        'productId': sku.productId,
        if (sku.basePlanId != null) 'basePlanId': sku.basePlanId,
      },
      at: _clock(),
    ));
    await _mark(user.id, reason, ref);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _invite(Map<String, dynamic> body) async {
    final loaded = await _open(body);
    if (loaded.error != null || loaded.profile == null) return loaded;
    final user = loaded.profile!;
    final code = '${body['code'] ?? ''}'.trim();
    if (code.isEmpty) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    BilgiProfile? host;
    for (final row in await store.values(bilgiWalletUsers)) {
      final candidate = BilgiProfile.fromMap(row);
      if (candidate.inviteCode == code && candidate.id != user.id) {
        host = candidate;
        break;
      }
    }
    if (host == null) return const BilgiWalletReply(error: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    if (user.friends.contains(host.id)) return const BilgiWalletReply(error: '📅 Bugünkü hakkını kullandın.');
    await _ensureLedger(host, starter: false);
    final ref = 'invite-${host.id}';
    if (await _done(user.id, 'invite', ref)) return BilgiWalletReply(profile: user);
    final invites = host.invites + 1;
    final hostNext = host.copyWith(
      gold: host.gold + 100,
      invites: invites,
      lives: invites % 5 == 0 ? host.lives + 1 : host.lives,
      friends: [...host.friends, user.id],
    );
    final next = user.copyWith(gold: user.gold + 100, friends: [...user.friends, host.id]);
    await ledger.append(bilgiLedgerDiff(
      before: host,
      after: hostNext,
      reason: 'invite',
      ref: ref,
      detail: {'role': 'host', 'code': code},
      at: _clock(),
    ));
    await ledger.append(bilgiLedgerDiff(
      before: user,
      after: next,
      reason: 'invite',
      ref: ref,
      detail: {'role': 'guest', 'code': code},
      at: _clock(),
    ));
    await _mark(user.id, 'invite', ref);
    await _put(hostNext);
    await _put(next);
    return BilgiWalletReply(profile: next);
  }

  Future<BilgiWalletReply> _open(Map<String, dynamic> body) async {
    final id = '${body['userId'] ?? ''}'.trim();
    if (id.isEmpty) return const BilgiWalletReply(error: 'Kullanıcı geçersiz.');
    final existing = await _load(id);
    if (existing == null) return const BilgiWalletReply(error: 'Kullanıcı bulunamadı.');
    if (existing.banned) return const BilgiWalletReply(error: '🚫 Hesabın askıya alındı.');
    return BilgiWalletReply(profile: await _prepare(existing, starter: false));
  }
}
