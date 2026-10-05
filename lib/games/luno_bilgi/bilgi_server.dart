import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_shop.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_trial_questions.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';

class BilgiResult {
  const BilgiResult({this.profile, this.round, this.room, this.message});

  final BilgiProfile? profile;
  final BilgiRound? round;
  final BilgiRoom? room;
  final String? message;

  bool get ok => message == null;
}

/// A playable question belongs to one subcategory of its category.
bool bilgiPlayableQuestion(
  BilgiQuestion question,
  List<BilgiCategory> categories, {
  required String categoryId,
  String subcategory = '',
  String difficulty = '',
  String locale = '',
}) {
  if (question.status != 'approved') return false;
  if (difficulty.isNotEmpty && difficulty != 'hepsi' && question.difficulty != difficulty) return false;
  final owner = categories.where((category) => category.id == question.categoryId).firstOrNull;
  if (owner == null || !question.tags.any(owner.subs.contains)) return false;
  if (locale.isNotEmpty && !owner.publishesIn(locale)) return false;
  if (bilgiSpecialEventCategory(owner) && categoryId != owner.id) return false;
  if (categoryId == tumuKarmaId) return true;
  if (question.categoryId != categoryId) return false;
  if (subcategory.isEmpty) return true;
  return owner.subs.contains(subcategory) && question.tags.contains(subcategory);
}

/// Profile-store meta: one-shot gunluk start after a completed rewarded ad.
const dailyQuestionAdPassMeta = 'dailyQuestionAdPass';

/// Server reject when gunluk is locked and no ad pass is set.
const dailyQuestionQuotaMessage =
    'Günlük oyun hakkınız doldu. Reklamla yeni oyun başlatın';

/// Generic label stored before a device has a real display name.
const bilgiGenericUsername = 'Oyuncu';

/// Same character rule as the app nickname check: letters, numbers, single spaces.
final bilgiUsernamePattern = RegExp(r'^[\p{L}\p{N}]+(?: [\p{L}\p{N}]+)*$', unicode: true);

bool bilgiPlaceholderUsername(String name) {
  final trimmed = name.trim();
  return trimmed.isEmpty || trimmed.toLowerCase() == bilgiGenericUsername.toLowerCase();
}

/// Length, charset, and shape already used for nicknames. Null when the name is acceptable.
String? bilgiUsernameIssue(String raw) {
  final name = bilgiUsernameNormalized(raw);
  if (name.length < 2) return UserMessages.nicknameShort;
  if (name.length > 20) return UserMessages.nicknameLong;
  if (!bilgiUsernamePattern.hasMatch(name)) return UserMessages.nicknameBad;
  return null;
}

/// Stable guest label. Suffix is the profile id's digits, last 9 when the id is longer.
/// A longer slice (still within 13 digits) is used only when that short name is already taken.
String bilgiGuestUsername(String id, [Set<String> takenLower = const {}]) {
  final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
  final body = digits.isEmpty ? '1' : digits;
  final shortest = min(9, body.length);
  final longest = min(13, body.length);
  String? first;
  for (var length = shortest; length <= longest; length++) {
    final name = 'Misafir${body.substring(body.length - length)}';
    first ??= name;
    if (!takenLower.contains(name.toLowerCase())) return name;
  }
  return first ?? 'Misafir$body';
}

class LunoBilgiServer {
  LunoBilgiServer(this._store, {DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final KeyValueStore _store;
  final DateTime Function() _clock;
  final Random _random;
  final Map<String, BilgiRound> _rounds = {};

  /// When set, a round asks the API for only the questions it needs.
  Future<List<BilgiQuestion>?> Function({
    required String categoryId,
    required String subcategory,
    required String difficulty,
    required int count,
    required List<String> exclude,
    required String locale,
  })? remoteDraw;

  /// Günün sorusu: sunucunun o gün için seçtiği tek soru.
  Future<List<BilgiQuestion>?> Function({required String locale})? remoteDaily;

  /// Düello, grup ve özel oda sunucuda durur. Boşsa odalar telefon deposunda kalır.
  BilgiRoomHooks? remoteRooms;

  /// Registered accounts are mirrored to the API. The map is the saved public profile.
  Future<Map<String, dynamic>?> Function(BilgiProfile user)? remoteUpsert;

  /// When set, gold, jokers, XP, and lives change on the server. The phone shows the reply.
  Future<BilgiWalletReply> Function({required String op, required Map<String, dynamic> body})? remoteWallet;

  static const _users = 'users';
  static const _playPurchases = 'play_purchases';
  static const _questions = 'questions';
  static const _games = 'games';
  static const _rooms = 'rooms';
  static const _duel = 'duels';
  static const _active = 'activeUser';
  static const _config = 'config';
  static const _catalog = 'catalog';

  Future<void> ensureSeed() async {
    for (final category in bilgiCategories) {
      for (var n = 1; n <= 3; n++) {
        await _store.delete(_questions, '${category.id}_$n');
      }
    }
    for (final question in bilgiTrialQuestions) {
      await _store.delete(_questions, question.id);
    }
    final stored = await _store.get(_config, 'main');
    if (stored == null || !rewardConfigStored(stored)) {
      final loaded = stored == null ? const BilgiConfig() : BilgiConfig.fromMap(stored);
      await _store.put(_config, 'main', loaded.toMap());
    }
    if (await _store.getMeta(_active) == null) {
      final seedCfg = await config();
      var guest = _newProfile(jokers: await _starterJokers(), lives: seedCfg.startLives);
      guest = guest.copyWith(username: await _uniqueGuestUsername(guest.id));
      await _save(guest);
      await _store.putMeta(_active, guest.id);
    }
  }

  /// Drops every stored Bilgi question so a leftover browser Hive bank is empty.
  Future<int> clearQuestionBank() async {
    final rows = await _store.values(_questions);
    for (final row in rows) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      await _store.delete(_questions, id);
    }
    return rows.length;
  }

  /// Clears the bank a single time. Later admin opens keep questions added after that.
  Future<int> clearQuestionBankOnce() async {
    if (await _store.getMeta('questionsClearedOnce') == '1') return 0;
    final removed = await clearQuestionBank();
    await _store.putMeta('questionsClearedOnce', '1');
    return removed;
  }

  Future<BilgiConfig> config() async {
    final stored = await _store.get(_config, 'main');
    if (stored != null && stored['dailyFreeGames'] == 1) {
      final map = Map<String, dynamic>.from(stored);
      map['dailyFreeGames'] = 3;
      await _store.put(_config, 'main', map);
      return BilgiConfig.fromMap(map);
    }
    return BilgiConfig.fromMap(stored);
  }

  Future<void> saveConfig(BilgiConfig value) async {
    await _store.put(_config, 'main', value.toMap());
  }

  Future<BilgiProfile> profile() async {
    await ensureSeed();
    final id = await _store.getMeta(_active) ?? 'me';
    final raw = await _store.get(_users, id);
    var user = raw == null ? _newProfile(jokers: await _starterJokers(), lives: (await config()).startLives) : BilgiProfile.fromMap(raw);
    final cfg = await config();
    final now = _clock();
    final walletOwnsLives = remoteWallet != null;
    final lives = walletOwnsLives
        ? user.lives
        : regeneratedLives(
            lives: user.lives,
            livesAt: user.livesAt,
            now: now,
            maxLives: cfg.maxLives,
            minutesPerLife: cfg.lifeMinutes,
          );
    final clock = walletOwnsLives
        ? user.livesAt
        : livesClockAfterRegen(
            lives: user.lives,
            livesAt: user.livesAt,
            now: now,
            maxLives: cfg.maxLives,
            minutesPerLife: cfg.lifeMinutes,
          );
    final today = DateKeys.dayKey(now);
    user = user.copyWith(
      lives: lives,
      livesAt: walletOwnsLives ? user.livesAt : (lives >= cfg.maxLives ? now : clock),
      adGoldToday: user.adDay == today ? user.adGoldToday : 0,
      adJokerToday: user.adDay == today ? user.adJokerToday : 0,
      adLifeToday: user.adDay == today ? user.adLifeToday : 0,
      adDoubleToday: user.adDay == today ? user.adDoubleToday : 0,
      adDay: today,
      freePlaysUsed: user.lastPlayDay == today ? user.freePlaysUsed : 0,
      lastPlayDay: user.lastPlayDay == today ? user.lastPlayDay : '',
    );
    if (user.jokers.isEmpty) {
      user = user.copyWith(jokers: await _starterJokers());
    }
    if (!_registered(user) && bilgiPlaceholderUsername(user.username)) {
      final chosen = await _store.getMeta(_usernameChosenKey(user.id));
      if (chosen != '1') {
        user = user.copyWith(username: await _uniqueGuestUsername(user.id));
      }
    }
    await _save(user);
    return user;
  }

  /// Linked Luno account name, when this profile is attached to one.
  Future<String?> accountDisplayNameFor(BilgiProfile user) async {
    final accounts = await LunoAccountDirectory(lunoAccountRoot(_store)).all();
    final accountId = user.accountId?.trim() ?? '';
    if (accountId.isNotEmpty) {
      for (final account in accounts) {
        if (account.id == accountId && account.displayName.trim().isNotEmpty) return account.displayName;
      }
    }
    for (final account in accounts) {
      if (account.progressIds[GameIds.lunoBilgi] == user.id && account.displayName.trim().isNotEmpty) {
        return account.displayName;
      }
    }
    final mail = user.email.trim().toLowerCase();
    if (mail.isEmpty) return null;
    for (final account in accounts) {
      if (account.email == mail && account.displayName.trim().isNotEmpty) return account.displayName;
    }
    return null;
  }

  bool _registered(BilgiProfile user) => user.email.trim().isNotEmpty || user.passwordHash.isNotEmpty;

  String _usernameChosenKey(String id) => 'bilgiUsernameChosen:$id';

  Future<String> _uniqueGuestUsername(String id) async {
    final taken = <String>{};
    for (final row in await _store.values(_users)) {
      if ('${row['id'] ?? ''}' == id) continue;
      final name = '${row['username'] ?? ''}'.trim().toLowerCase();
      if (name.isNotEmpty) taken.add(name);
    }
    return bilgiGuestUsername(id, taken);
  }

  Future<bool> _usernameTaken(String name, {required String exceptId}) async {
    return bilgiUsernameTaken(await _store.values(_users), name, exceptId: exceptId);
  }

  Future<Map<String, int>> _starterJokers() async {
    final cfg = await config();
    return {
      'half': cfg.jokerStarts['half'] ?? 2,
      'double': cfg.jokerStarts['double'] ?? 1,
      'time': cfg.jokerStarts['time'] ?? 1,
      'change': cfg.jokerStarts['change'] ?? 0,
      'hint': cfg.jokerStarts['hint'] ?? 0,
    };
  }

  BilgiProfile _newProfile({
    String username = '',
    String email = '',
    String passwordHash = '',
    Map<String, int>? jokers,
    int? lives,
  }) {
    final now = _clock();
    final id = 'u${now.microsecondsSinceEpoch}${_random.nextInt(999)}';
    final given = username.trim();
    return BilgiProfile(
      id: id,
      username: given.isEmpty ? bilgiGuestUsername(id) : given,
      email: email,
      passwordHash: passwordHash,
      avatar: '😎',
      level: 1,
      xp: 0,
      gold: 500,
      diamond: 0,
      lives: lives ?? 5,
      livesAt: now,
      title: 'Çaylak',
      premium: false,
      premiumUntil: null,
      banned: false,
      banReason: '',
      city: '',
      createdAt: now,
      jokers: jokers ?? const {'half': 2, 'double': 1, 'time': 1, 'change': 0, 'hint': 0},
      gamesPlayed: 0,
      correctTotal: 0,
      bestScore: 0,
      totalScore: 0,
      streak: 0,
      lastReward: '',
      rewardDay: 0,
      lastPlayDay: '',
      freePlaysUsed: 0,
      adFreeLeft: 3,
      inviteCode: 'LB${_random.nextInt(90) + 10}',
      invites: 0,
      friends: const [],
      badges: const [],
      duelWins: 0,
      categoriesPlayed: const [],
      adGoldToday: 0,
      adJokerToday: 0,
      adLifeToday: 0,
      adDoubleToday: 0,
      adDay: DateKeys.dayKey(now),
      weekId: bilgiWeekId(now),
      weekScore: 0,
    );
  }

  Future<void> _save(BilgiProfile user) => _store.put(_users, user.id, user.toMap());

  Future<BilgiProfile> _pushRemote(BilgiProfile user) async {
    final push = remoteUpsert;
    if (push == null) return user;
    try {
      final saved = await push(user);
      if (saved == null) return user;
      final next = saved['lives'] != null
          ? bilgiApplyWallet(user, BilgiProfile.fromMap(saved))
          : bilgiTakeLeagueGrant(user, saved);
      await _save(next);
      return next;
    } on BilgiUsernameTaken {
      rethrow;
    } catch (_) {
      return user;
    }
  }

  /// Loads the server wallet when [remoteWallet] is set. Otherwise mirrors the local profile.
  Future<BilgiProfile> pullRemoteProfile() async {
    final user = await profile();
    final hook = remoteWallet;
    if (hook == null) return _pushRemote(user);
    try {
      final reply = await hook(op: 'sync', body: {'userId': user.id});
      if (reply.profile == null) return user;
      final next = bilgiApplyWallet(user, reply.profile!, livesReported: reply.livesReported);
      await _save(next);
      return next;
    } catch (_) {
      return user;
    }
  }

  /// Null when this phone still owns the wallet. A reply means the server decided.
  Future<BilgiResult?> _serverWallet(String op, Map<String, dynamic> body, {BilgiRound? round}) async {
    final hook = remoteWallet;
    if (hook == null) return null;
    try {
      final reply = await hook(op: op, body: body);
      if (reply.profile == null) {
        return BilgiResult(message: reply.error ?? 'Bağlantı kurulamadı.', round: round);
      }
      final local = await profile();
      final next = bilgiApplyWallet(local, reply.profile!, livesReported: reply.livesReported);
      if (reply.profile!.id != local.id) {
        await _store.putMeta(_active, next.id);
        await _save(next);
        return BilgiResult(profile: next, round: round);
      }
      await _save(next);
      return BilgiResult(profile: next, round: round);
    } catch (_) {
      return BilgiResult(message: 'Bağlantı kurulamadı.', round: round);
    }
  }

  Future<List<BilgiQuestion>> questions() async {
    await ensureSeed();
    final rows = await _store.values(_questions);
    return rows.map(BilgiQuestion.fromMap).toList();
  }

  Future<int> questionCount(String categoryId, {String subcategory = ''}) async {
    final categories = resolveBilgiCategories(await catalog(), playableOnly: true);
    final all = await questions();
    return all.where((question) => bilgiPlayableQuestion(question, categories, categoryId: categoryId, subcategory: subcategory)).length;
  }

  Future<List<BilgiProfile>> users() async {
    await ensureSeed();
    final rows = await _store.values(_users);
    return rows.map(BilgiProfile.fromMap).toList();
  }

  /// Shared accounts, plus this game's registered profiles. Device-only guests stay out.
  Future<List<BilgiProfile>> listedUsers() async {
    final accounts = await LunoAccountDirectory(lunoAccountRoot(_store)).all();
    return annotateBilgiAccounts(await users(), accounts);
  }

  Future<BilgiResult> register({
    required String username,
    required String email,
    required String password,
  }) async {
    final cfg = await config();
    if (!cfg.registrationsOpen) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    if (username.trim().length < 3 || password.length < 6 || !email.contains('@')) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    return _bindRegistered(
      email: email,
      provider: 'email',
      username: username.trim(),
      passwordHash: hashBilgiPassword(password),
      replaceName: true,
    );
  }

  Future<BilgiResult> loginSocial({
    required String email,
    String? username,
    String? googleId,
  }) async {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    return _bindRegistered(
      email: trimmed,
      provider: (googleId ?? '').trim().isEmpty ? 'email' : 'google',
      googleId: googleId,
      username: username,
      replaceName: false,
    );
  }

  bool _guestLooking(String name) =>
      bilgiPlaceholderUsername(name) || RegExp(r'^Misafir\d+$').hasMatch(name.trim());

  /// Upgrades the open guest, or opens the progress this account already has.
  Future<BilgiResult> _bindRegistered({
    required String email,
    required String provider,
    String? googleId,
    String? username,
    String? passwordHash,
    required bool replaceName,
  }) async {
    final current = await profile();
    final mail = email.trim();
    if (current.email.isNotEmpty && current.email.toLowerCase() != mail.toLowerCase()) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    if (remoteWallet != null) {
      final reply = await remoteWallet!(
        op: 'bind',
        body: {
          'userId': current.id,
          'email': mail,
          'username': username ?? '',
          'passwordHash': passwordHash ?? '',
          'googleId': googleId ?? '',
        },
      );
      if (reply.profile == null) {
        return BilgiResult(message: reply.error ?? '⚠️ Bir şeyler ters gitti. Tekrar dene.');
      }
      await _store.putMeta(_active, reply.profile!.id);
      await _save(reply.profile!);
      return BilgiResult(profile: reply.profile);
    }
    final directory = LunoAccountDirectory(lunoAccountRoot(_store));
    final account = await directory.find(email: mail, googleId: googleId);
    final otherId = account?.progressIds[GameIds.lunoBilgi];
    if (otherId != null && otherId.isNotEmpty && otherId != current.id) {
      final row = await _store.get(_users, otherId);
      if (row == null) {
        return const BilgiResult(message: 'Bu hesabın bu oyundaki kaydı bulunamadı.');
      }
      final other = BilgiProfile.fromMap(row);
      if (other.banned) return const BilgiResult(message: '🚫 Hesabın askıya alındı.');
      await _store.putMeta(_active, other.id);
      final linked = await _stampAccount(other, provider: provider, email: mail, googleId: googleId);
      return BilgiResult(profile: await _pushRemote(linked));
    }
    final local = (await users()).where(
      (user) => user.id != current.id && user.email.toLowerCase() == mail.toLowerCase(),
    );
    if (local.isNotEmpty) {
      final other = local.first;
      if (other.banned) return const BilgiResult(message: '🚫 Hesabın askıya alındı.');
      await _store.putMeta(_active, other.id);
      final linked = await _stampAccount(other, provider: provider, email: mail, googleId: googleId);
      return BilgiResult(profile: await _pushRemote(linked));
    }
    final typed = username?.trim() ?? '';
    final canReplace = replaceName || _guestLooking(current.username);
    final nextName = canReplace && typed.length >= 2 ? typed : current.username;
    if (await _usernameTaken(nextName, exceptId: current.id)) {
      return const BilgiResult(message: UserMessages.nicknameTaken);
    }
    final upgraded = current.copyWith(
      username: nextName,
      email: mail,
      passwordHash: passwordHash ?? current.passwordHash,
    );
    final linked = await _stampAccount(upgraded, provider: provider, email: mail, googleId: googleId);
    await _store.putMeta(_active, linked.id);
    try {
      return BilgiResult(profile: await _pushRemote(linked));
    } on BilgiUsernameTaken {
      await _save(current);
      await _store.putMeta(_active, current.id);
      return const BilgiResult(message: UserMessages.nicknameTaken);
    }
  }

  Future<BilgiProfile> _stampAccount(
    BilgiProfile user, {
    required String provider,
    String? email,
    String? googleId,
  }) async {
    final link = await LunoAccountDirectory(lunoAccountRoot(_store)).link(
      gameId: GameIds.lunoBilgi,
      progressId: user.id,
      displayName: user.username,
      provider: provider,
      email: email ?? user.email,
      googleId: googleId,
    );
    if (link.otherProgressId != null && link.otherProgressId != user.id) {
      final row = await _store.get(_users, link.otherProgressId!);
      if (row != null) {
        final other = BilgiProfile.fromMap(row).copyWith(
          accountId: link.account.id,
          accountFirstGame: link.account.firstGameId,
          accountGames: link.account.activatedGames,
        );
        await _save(other);
        await _store.putMeta(_active, other.id);
        return other;
      }
    }
    final stamped = user.copyWith(
      accountId: link.account.id,
      accountFirstGame: link.account.firstGameId,
      accountGames: link.account.activatedGames,
      guestHere: false,
    );
    await _save(stamped);
    return stamped;
  }

  Future<BilgiResult> login({required String email, required String password}) async {
    if (remoteWallet != null) {
      final current = await profile();
      final reply = await remoteWallet!(
        op: 'bind',
        body: {
          'userId': current.id,
          'email': email.trim(),
          'password': password,
        },
      );
      if (reply.profile == null) {
        return BilgiResult(message: reply.error ?? '⚠️ Bir şeyler ters gitti. Tekrar dene.');
      }
      await _store.putMeta(_active, reply.profile!.id);
      await _save(reply.profile!);
      return BilgiResult(profile: reply.profile);
    }
    final all = await users();
    final hash = hashBilgiPassword(password);
    final match = all.where((u) => u.email == email.trim() && u.passwordHash == hash);
    if (match.isEmpty) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final user = match.first;
    if (user.banned) return const BilgiResult(message: '🚫 Hesabın askıya alındı.');
    await _store.putMeta(_active, user.id);
    final linked = await _stampAccount(user, provider: 'email', email: user.email);
    return BilgiResult(profile: await _pushRemote(linked));
  }

  Future<String?> startGate(BilgiProfile user, BilgiMode mode, {bool spendLife = true}) async {
    final cfg = await config();
    if (cfg.maintenance) return '🔧 Bakımdayız';
    if (user.banned) return '🚫 Hesabın askıya alındı.';
    if (spendLife && cfg.livesEnabled && user.lives < mode.lifeCost) {
      return bilgiNoLivesNotice(cfg.lifeMinutes);
    }
    return null;
  }

  bool needsAd(BilgiProfile user, BilgiConfig cfg) {
    if (bilgiPlusActive(user, _clock())) return false;
    if (user.adFreeLeft > 0) return false;
    final today = DateKeys.dayKey(_clock());
    final played = user.lastPlayDay == today ? user.freePlaysUsed : 0;
    final next = played + 1;
    if (next <= cfg.dailyFreeGames) return false;
    return (next - cfg.dailyFreeGames) % 3 == 0;
  }

  Future<BilgiResult> startRound({
    required String modeId,
    String categoryId = tumuKarmaId,
    String subcategory = '',
    String difficulty = '',
    int? questionCount,
    bool adCleared = false,
    List<BilgiQuestion>? fixedQuestions,
    BilgiQuestion? fixedSpare,
    List<BilgiQuestion> fixedSpares = const [],
    String roomCode = '',
    bool chargeLife = true,
    int startIndex = 0,
    int startScore = 0,
    int startCorrect = 0,
    int startWrong = 0,
    int startStreak = 0,
    int startJokersUsed = 0,
    int startDoubleLeft = 0,
    List<int> startHidden = const [],
    String startHint = '',
    Map<String, dynamic>? openedCatalog,
  }) async {
    final user = await profile();
    final cfg = await config();
    final mode = cfg.resolvedMode(bilgiModeById(modeId));
    if (mode.id == 'gunluk') {
      final today = DateKeys.dayKey(_clock());
      final played = await _store.getMeta('dailyQuestion');
      if (played == today) {
        final pass = await _store.getMeta(dailyQuestionAdPassMeta);
        if (pass == today) {
          // One-shot ad pass: consume when the round actually starts.
          await _store.putMeta(dailyQuestionAdPassMeta, '');
        } else {
          return const BilgiResult(message: dailyQuestionQuotaMessage);
        }
      }
    }
    final blocked = await startGate(user, mode, spendLife: chargeLife);
    if (blocked != null) return BilgiResult(message: blocked, profile: user);
    if (needsAd(user, cfg) && !adCleared) {
      return BilgiResult(message: 'ad', profile: user);
    }
    final visible = resolveBilgiCategories(openedCatalog ?? await catalog(), playableOnly: true).where((category) => category.publishesIn(user.locale));
    if (categoryId != tumuKarmaId && visible.every((category) => category.id != categoryId)) {
      return const BilgiResult(message: 'Bu kategori şu an oyunda değil.');
    }
    final wanted = questionCount ?? mode.questions;
    final drawn = await _openingQuestions(
      mode: mode,
      categoryId: categoryId,
      subcategory: subcategory,
      difficulty: difficulty,
      wanted: wanted,
      locale: user.locale,
      fixedQuestions: fixedQuestions,
      fixedSpare: fixedSpare,
      fixedSpares: fixedSpares,
    );
    if (drawn == null) {
      return const BilgiResult(message: 'Sorular alınamadı. Bağlantını kontrol et.');
    }
    if (drawn.questions.isEmpty || drawn.questions.length < wanted) {
      return const BilgiResult(message: '❓ Bu kategoride yeterli soru yok.');
    }
    final pool = drawn.questions;
    final spare = drawn.spare;
    final spares = List<BilgiQuestion>.of(drawn.spares);
    final today = DateKeys.dayKey(_clock());
    final roundId = 'g${_clock().microsecondsSinceEpoch}';
    var next = user;
    if (chargeLife) {
      next = user.copyWith(
        lives: cfg.livesEnabled ? user.lives - mode.lifeCost : user.lives,
        livesAt: user.lives >= cfg.maxLives ? _clock() : user.livesAt,
        gamesPlayed: user.gamesPlayed + 1,
        adFreeLeft: user.adFreeLeft > 0 ? user.adFreeLeft - 1 : 0,
        lastPlayDay: today,
        freePlaysUsed: user.adFreeLeft > 0
            ? user.freePlaysUsed
            : (user.lastPlayDay == today ? user.freePlaysUsed : 0) + 1,
      );
      if (mode.lifeCost > 0 && user.lives == cfg.maxLives) {
        next = next.copyWith(livesAt: _clock());
      }
      if (remoteWallet != null) {
        final remote = await _serverWallet('life_spend', {
          'userId': user.id,
          'modeId': mode.id,
          'roundId': roundId,
        });
        if (remote == null || remote.profile == null) {
          return remote ?? BilgiResult(message: 'Bağlantı kurulamadı.', profile: user);
        }
        next = bilgiApplyWallet(next, remote.profile!).copyWith(
          adFreeLeft: next.adFreeLeft,
          lastPlayDay: next.lastPlayDay,
          freePlaysUsed: next.freePlaysUsed,
        );
      }
      await _save(next);
    }
    final round = BilgiRound(
      id: roundId,
      userId: next.id,
      modeId: mode.id,
      categoryId: categoryId,
      subcategory: subcategory,
      difficulty: difficulty,
      questions: pool,
      multiplier: mode.multiplier,
      seconds: mode.seconds,
      totalSeconds: mode.totalSeconds,
      jokerMax: mode.jokerMax,
      lifeCost: mode.lifeCost,
      roomCode: roomCode,
      spare: spare,
      spares: spares,
      startedAt: _clock(),
      index: startIndex.clamp(0, pool.length),
      score: startScore,
      correct: startCorrect,
      wrong: startWrong,
      streak: startStreak,
      jokersUsed: startJokersUsed,
      hidden: startHidden,
      doubleLeft: startDoubleLeft,
      hint: startHint,
    );
    _rounds[round.id] = round;
    await _store.put(_games, round.id, round.toMap());
    return BilgiResult(profile: next, round: round);
  }

  Future<({List<BilgiQuestion> questions, BilgiQuestion? spare, List<BilgiQuestion> spares})?> _openingQuestions({
    required BilgiMode mode,
    required String categoryId,
    required String subcategory,
    required String difficulty,
    required int wanted,
    required String locale,
    List<BilgiQuestion>? fixedQuestions,
    BilgiQuestion? fixedSpare,
    List<BilgiQuestion> fixedSpares = const [],
  }) async {
    if (fixedQuestions != null) {
      return (questions: fixedQuestions, spare: fixedSpare, spares: fixedSpares);
    }
    if (mode.id == 'gunluk') {
      final daily = remoteDaily;
      if (daily != null) {
        final one = await daily(locale: locale);
        if (one == null) return null;
        return (questions: one, spare: null, spares: const <BilgiQuestion>[]);
      }
    }
    final ask = mode.jokerMax > 0 && wanted > 0 ? wanted + mode.jokerMax : wanted;
    final pool = await _draw(
      categoryId: categoryId,
      subcategory: subcategory,
      difficulty: difficulty,
      count: ask < 1 ? 1 : ask,
      locale: locale,
    );
    if (pool == null) return null;
    if (pool.length < wanted) return (questions: pool, spare: null, spares: const <BilgiQuestion>[]);
    final extra = pool.length > wanted ? pool.sublist(wanted) : const <BilgiQuestion>[];
    return (questions: pool.sublist(0, wanted), spare: null, spares: extra);
  }

  Future<List<BilgiQuestion>?> _draw({
    required String categoryId,
    required String difficulty,
    required int count,
    String subcategory = '',
    List<String> exclude = const [],
    String locale = '',
  }) async {
    final remote = remoteDraw;
    if (remote != null) {
      return remote(
        categoryId: categoryId,
        subcategory: subcategory,
        difficulty: difficulty,
        count: count,
        exclude: exclude,
        locale: locale,
      );
    }
    if (difficulty == bilgiMixDifficulty) {
      return _drawMixed(
        categoryId: categoryId,
        subcategory: subcategory,
        count: count,
        exclude: exclude,
        locale: locale,
      );
    }
    final blocked = exclude.toSet();
    final categories = resolveBilgiCategories(await catalog(), playableOnly: true);
    final all = (await questions())
        .where((question) => !blocked.contains(question.id))
        .where((question) => bilgiPlayableQuestion(
              question,
              categories,
              categoryId: categoryId,
              subcategory: subcategory,
              difficulty: difficulty,
              locale: locale,
            ))
        .toList();
    all.shuffle(_random);
    if (all.length > count) return all.sublist(0, count);
    return all;
  }

  Future<List<BilgiQuestion>> _drawMixed({
    required String categoryId,
    required String subcategory,
    required int count,
    required List<String> exclude,
    required String locale,
  }) async {
    final blocked = exclude.toSet();
    final categories = resolveBilgiCategories(await catalog(), playableOnly: true);
    final buckets = {for (final level in bilgiDifficultyLevels) level: <BilgiQuestion>[]};
    for (final question in await questions()) {
      if (blocked.contains(question.id) || !buckets.containsKey(question.difficulty)) continue;
      if (!bilgiPlayableQuestion(
        question,
        categories,
        categoryId: categoryId,
        subcategory: subcategory,
        locale: locale,
      )) {
        continue;
      }
      buckets[question.difficulty]!.add(question);
    }
    for (final bucket in buckets.values) {
      bucket.shuffle(_random);
    }
    final cursor = {for (final level in bilgiDifficultyLevels) level: 0};
    final picked = <BilgiQuestion>[];
    final quotas = bilgiMixQuotas(count);
    for (var i = 0; i < bilgiDifficultyLevels.length; i++) {
      final level = bilgiDifficultyLevels[i];
      final bucket = buckets[level]!;
      final take = quotas[i] < bucket.length ? quotas[i] : bucket.length;
      picked.addAll(bucket.take(take));
      cursor[level] = take;
    }
    var guard = 0;
    while (picked.length < count && guard < count) {
      guard += 1;
      var added = false;
      final order = [...bilgiDifficultyLevels]..sort((a, b) {
          final aCount = picked.where((question) => question.difficulty == a).length;
          final bCount = picked.where((question) => question.difficulty == b).length;
          return aCount.compareTo(bCount);
        });
      for (final level in order) {
        final bucket = buckets[level]!;
        final index = cursor[level]!;
        if (index >= bucket.length) continue;
        picked.add(bucket[index]);
        cursor[level] = index + 1;
        added = true;
        break;
      }
      if (!added) break;
    }
    return picked;
  }

  Future<void> _publishScore(BilgiRound round) async {
    final remote = remoteRooms;
    if (remote == null || round.roomCode.isEmpty) return;
    try {
      await remote.score(
        code: round.roomCode,
        playerId: round.userId,
        score: round.score,
        index: round.index,
      );
    } catch (_) {}
  }

  BilgiRound? roundById(String id) => _rounds[id];

  Future<BilgiResult> answer({
    required String roundId,
    required int option,
    required int timeLeft,
  }) async {
    final round = _rounds[roundId];
    if (round == null || round.finished) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final question = round.current;
    if (question == null) return const BilgiResult(message: '❓ Bu kategoride yeterli soru yok.');
    final right = option == question.correct;
    if (!right && round.doubleLeft > 0) {
      round.doubleLeft -= 1;
      round.hidden = {...round.hidden, option}.toList();
      return BilgiResult(round: round);
    }
    final totalTime = round.totalSeconds > 0 ? round.totalSeconds : round.seconds;
    if (right) {
      final scored = scoreQuestion(
        difficulty: question.difficulty,
        modeMultiplier: round.multiplier,
        timeLeft: timeLeft,
        totalTime: totalTime,
        streak: round.streak,
      );
      round.score += scored.points;
      round.timeBonus += scored.timeBonus;
      round.correct += 1;
      round.streak += 1;
    } else {
      round.wrong += 1;
      round.streak = 0;
    }
    round.hidden = const [];
    round.doubleLeft = 0;
    round.hint = '';
    round.paused = false;
    round.index += 1;
    await _publishScore(round);
    if (round.index >= round.questions.length) {
      return finish(roundId);
    }
    await _store.put(_games, round.id, round.toMap());
    return BilgiResult(round: round);
  }

  Future<BilgiResult> timeout(String roundId) {
    final round = _rounds[roundId];
    if (round == null) return Future.value(const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.'));
    return answer(roundId: roundId, option: -1, timeLeft: 0);
  }

  Future<BilgiResult> useJoker({
    required String roundId,
    required String type,
  }) async {
    final round = _rounds[roundId];
    final user = await profile();
    if (round == null || round.finished) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    if (round.jokersUsed >= round.jokerMax) {
      return BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.', profile: user);
    }
    final stock = user.jokers[type] ?? 0;
    if (stock <= 0) return BilgiResult(message: 'joker', profile: user);
    final question = round.current;
    if (question == null) return const BilgiResult(message: '❓ Bu kategoride yeterli soru yok.');
    if (type == 'change' && _takeSpare(round, question.difficulty, remove: false) == null) {
      return BilgiResult(message: '❓ Bu kategoride yeterli soru yok.', profile: user);
    }
    BilgiProfile saved;
    if (remoteWallet != null) {
      final remote = await _serverWallet('joker_use', {
        'userId': user.id,
        'type': type,
        'roundId': roundId,
        'index': round.jokersUsed,
      });
      if (remote == null || remote.profile == null) {
        return remote ?? BilgiResult(message: 'Bağlantı kurulamadı.', profile: user);
      }
      saved = remote.profile!;
    } else {
      final nextJokers = Map<String, int>.from(user.jokers);
      nextJokers[type] = stock - 1;
      saved = user.copyWith(jokers: nextJokers);
    }
    round.jokersUsed += 1;
    if (type == 'half') {
      final wrong = <int>[for (var i = 0; i < question.options.length; i++) i]
        ..remove(question.correct);
      wrong.shuffle(_random);
      round.hidden = wrong.take(2).toList();
    } else if (type == 'double') {
      round.doubleLeft = 1;
    } else if (type == 'time') {
      round.paused = true;
    } else if (type == 'hint') {
      round.hint = bilgiHintClue(
        explanation: question.explanation,
        options: question.options,
        correct: question.correct,
      );
    } else if (type == 'change') {
      final next = _takeSpare(round, question.difficulty, remove: true);
      round.questions[round.index] = next!;
      round.hidden = const [];
      round.hint = '';
    }
    if (remoteWallet == null) await _save(saved);
    return BilgiResult(profile: saved, round: round);
  }

  /// Aynı zorluktaki yedeği alır. Yarışmada başka zorluk kullanılmaz.
  BilgiQuestion? _takeSpare(BilgiRound round, String difficulty, {required bool remove}) {
    final index = round.spares.indexWhere((question) => question.difficulty == difficulty);
    if (index >= 0) {
      return remove ? round.spares.removeAt(index) : round.spares[index];
    }
    if (round.modeId != 'yarisma' && round.spares.isNotEmpty) {
      return remove ? round.spares.removeAt(0) : round.spares.first;
    }
    if (round.spares.isEmpty && round.spare != null) {
      final next = round.spare;
      if (remove) round.spare = null;
      return next;
    }
    return null;
  }

  Future<BilgiResult> finish(String roundId) async {
    final round = _rounds[roundId];
    if (round == null) return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    if (!round.finished) {
      final user = await profile();
      var gold = goldForScore(round.score, round.multiplier);
      var xp = xpForScore(round.score);
      if (round.modeId == 'yarisma') {
        gold = bilgiContestGold(round.correct);
        xp = bilgiContestXp(round.correct);
      }
      if (round.modeId == 'gunluk' && round.correct > 0) {
        gold = 100;
        xp = 50;
      }
      if (round.modeId == 'duello' && round.opponentName.isNotEmpty && round.opponentScore >= 0) {
        gold = round.score >= round.opponentScore ? 50 : 10;
      }
      if (remoteWallet != null) {
        final remote = await _serverWallet('finish', {
          'userId': user.id,
          'roundId': round.id,
          'score': round.score,
          'multiplier': round.multiplier,
          'modeId': round.modeId,
          'correct': round.correct,
          'categoryId': round.categoryId,
          'opponentName': round.opponentName,
          'opponentScore': round.opponentScore,
          'difficulty': round.difficulty,
        }, round: round);
        if (remote == null || remote.profile == null) {
          return remote ?? BilgiResult(message: 'Bağlantı kurulamadı.', round: round);
        }
        round.finished = true;
        round.gold = gold;
        round.xp = xp;
        await _publishScore(round);
        await _store.put(_games, round.id, round.toMap());
        if (round.modeId == 'gunluk') {
          await _store.putMeta('dailyQuestion', DateKeys.dayKey(_clock()));
        }
        return BilgiResult(profile: remote.profile, round: round);
      }
      round.finished = true;
      final level = applyXp(level: user.level, xp: user.xp, gained: xp);
      final cats = round.modeId == 'yarisma'
          ? user.categoriesPlayed
          : {...user.categoriesPlayed, round.categoryId}.toList();
      final scored = round.modeId == 'yarisma'
          ? user
          : bilgiAddScore(user, points: round.score, categoryId: round.categoryId, now: _clock());
      final duelWins = user.duelWins +
          ((round.modeId == 'duello' &&
                  round.opponentName.isNotEmpty &&
                  round.opponentScore >= 0 &&
                  round.score >= round.opponentScore)
              ? 1
              : 0);
      var next = scored.copyWith(
        gold: scored.gold + gold,
        xp: level.xp,
        level: level.level,
        diamond: scored.diamond + level.diamondsGained,
        correctTotal: scored.correctTotal + round.correct,
        bestScore: round.score > scored.bestScore ? round.score : scored.bestScore,
        categoriesPlayed: cats,
        duelWins: duelWins,
        title: level.level >= 10 ? 'Bilge' : user.title,
      );
      next = _withBadges(next);
      round.gold = gold;
      round.xp = xp;
      await _publishScore(round);
      await _save(next);
      await _store.put(_games, round.id, round.toMap());
      if (round.modeId == 'gunluk') {
        await _store.putMeta('dailyQuestion', DateKeys.dayKey(_clock()));
      }
      return BilgiResult(profile: next, round: round);
    }
    return BilgiResult(profile: await profile(), round: round);
  }

  /// Adds the finished round's score again after a completed rewarded ad.
  /// Gold and XP stay as [finish] wrote them.
  Future<BilgiResult> doubleFinishedScore(String roundId) async {
    final round = _rounds[roundId];
    if (round == null || !round.finished) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final user = await profile();
    final cfg = await config();
    if (user.adDoubleToday >= cfg.rewardedDoubleLimit) {
      return const BilgiResult(message: '📅 Bugünkü hakkını kullandın.');
    }
    final extra = round.score;
    if (extra <= 0) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    if (remoteWallet != null) {
      final remote = await _serverWallet('score_double', {
        'userId': user.id,
        'roundId': round.id,
        'score': extra,
        'categoryId': round.categoryId,
      }, round: round);
      if (remote == null || remote.profile == null) {
        return remote ?? BilgiResult(message: 'Bağlantı kurulamadı.', round: round);
      }
      round.score = extra * 2;
      await _publishScore(round);
      await _store.put(_games, round.id, round.toMap());
      return BilgiResult(profile: remote.profile, round: round);
    }
    round.score = extra * 2;
    final scored = bilgiAddScore(user, points: extra, categoryId: round.categoryId, now: _clock());
    final next = scored.copyWith(
      bestScore: round.score > scored.bestScore ? round.score : scored.bestScore,
      adDoubleToday: scored.adDoubleToday + 1,
    );
    await _publishScore(round);
    await _save(next);
    await _store.put(_games, round.id, round.toMap());
    return BilgiResult(profile: next, round: round);
  }

  BilgiProfile _withBadges(BilgiProfile user) {
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

  Future<BilgiResult> claimDaily({bool doubled = false}) async {
    final user = await profile();
    if (remoteWallet != null) {
      final remote = await _serverWallet('daily', {'userId': user.id, 'doubled': doubled});
      if (remote != null) return remote;
    }
    final cfg = await config();
    final today = DateKeys.dayKey(_clock());
    if (user.lastReward == today) {
      return const BilgiResult(message: '📅 Bugünkü hakkını kullandın.');
    }
    final yesterday = DateKeys.dayKey(_clock().subtract(const Duration(days: 1)));
    final index = user.lastReward == yesterday ? user.rewardDay % 7 : 0;
    final gold = dayRewardAmount(cfg.dailyGold, index) * (doubled ? 2 : 1);
    final diamond = dayRewardAmount(cfg.dailyDiamond, index) * (doubled ? 2 : 1);
    final joker = dayRewardAmount(cfg.dailyJoker, index) * (doubled ? 2 : 1);
    final jokers = Map<String, int>.from(user.jokers);
    jokers['half'] = (jokers['half'] ?? 0) + joker;
    final streak = user.lastReward == yesterday ? user.streak + 1 : 1;
    final next = user.copyWith(
      gold: user.gold + gold,
      diamond: user.diamond + diamond,
      jokers: jokers,
      lastReward: today,
      rewardDay: (index + 1) % 7,
      streak: streak,
    );
    await _save(next);
    return BilgiResult(profile: next);
  }

  Future<BilgiResult> buyJoker(String type) async {
    final user = await profile();
    if (remoteWallet != null) {
      final remote = await _serverWallet('joker_buy', {'userId': user.id, 'type': type});
      if (remote != null) return remote;
    }
    final cfg = await config();
    final price = cfg.jokerPrices[type] ?? 50;
    if (user.gold < price) return const BilgiResult(message: '🪙 Yeterli altının yok. Mağazadan altın al.');
    final jokers = Map<String, int>.from(user.jokers);
    jokers[type] = (jokers[type] ?? 0) + 1;
    final next = user.copyWith(gold: user.gold - price, jokers: jokers);
    await _save(next);
    return BilgiResult(profile: next);
  }

  Future<BilgiResult> refillLives() async {
    final user = await profile();
    if (remoteWallet != null) {
      final remote = await _serverWallet('life_refill', {'userId': user.id});
      if (remote != null) return remote;
    }
    final cfg = await config();
    if (user.lives >= cfg.maxLives) {
      return const BilgiResult(message: 'Canın zaten dolu.');
    }
    if (user.gold < cfg.lifePrice) {
      return const BilgiResult(message: '🪙 Yeterli altının yok. Mağazadan altın al.');
    }
    final next = user.copyWith(gold: user.gold - cfg.lifePrice, lives: cfg.maxLives, livesAt: _clock());
    await _save(next);
    return BilgiResult(profile: next);
  }

  /// Grants gold or Plus for one verified Play purchase. The same receipt is applied once.
  /// A subscription renewal (new order id) extends [BilgiProfile.premiumUntil] forward.
  Future<BilgiResult> grantPlayPurchase({
    required String productId,
    String? basePlanId,
    required String purchaseToken,
    String? orderId,
  }) async {
    final token = purchaseToken.trim();
    final order = orderId?.trim() ?? '';
    if (token.isEmpty) {
      return const BilgiResult(message: UserMessages.billingUnavailable);
    }
    final sku = bilgiPlaySku(productId, basePlanId);
    if (sku == null) {
      return const BilgiResult(message: UserMessages.billingUnavailable);
    }
    final user = await profile();
    if (await _playPurchaseSeen(subscription: sku.plus, token: token, orderId: order)) {
      return BilgiResult(profile: user);
    }
    if (remoteWallet != null) {
      final remote = await _serverWallet('play', {
        'userId': user.id,
        'productId': productId,
        'basePlanId': basePlanId ?? '',
        'orderId': order,
        'tokenRef': sha256.convert(utf8.encode(token)).toString(),
      });
      if (remote == null || remote.profile == null) {
        return remote ?? const BilgiResult(message: UserMessages.billingUnavailable);
      }
      final record = {
        'productId': sku.productId,
        'basePlanId': sku.basePlanId ?? '',
        'purchaseOptionId': sku.purchaseOptionId ?? '',
        'userId': user.id,
        'createdAt': _clock().toIso8601String(),
      };
      await _store.put(_playPurchases, 'tok:$token', record);
      if (order.isNotEmpty) await _store.put(_playPurchases, 'ord:$order', record);
      return remote;
    }
    final now = _clock();
    final next = applyBilgiPlayReward(user, sku, now);
    await _save(next);
    final record = {
      'productId': sku.productId,
      'basePlanId': sku.basePlanId ?? '',
      'purchaseOptionId': sku.purchaseOptionId ?? '',
      'userId': user.id,
      'createdAt': now.toIso8601String(),
    };
    await _store.put(_playPurchases, 'tok:$token', record);
    if (order.isNotEmpty) await _store.put(_playPurchases, 'ord:$order', record);
    return BilgiResult(profile: await _pushRemote(next));
  }

  Future<bool> _playPurchaseSeen({
    required bool subscription,
    required String token,
    required String orderId,
  }) async {
    if (subscription && orderId.isNotEmpty) {
      return await _store.get(_playPurchases, 'ord:$orderId') != null;
    }
    return await _store.get(_playPurchases, 'tok:$token') != null;
  }

  Future<BilgiResult> grantAd({required String kind}) async {
    final user = await profile();
    if (remoteWallet != null) {
      final remote = await _serverWallet('ad', {'userId': user.id, 'kind': kind});
      if (remote != null) return remote;
    }
    final cfg = await config();
    if (kind == 'gold' && user.adGoldToday >= cfg.rewardedGoldLimit) {
      return const BilgiResult(message: '📅 Bugünkü hakkını kullandın.');
    }
    if (kind == 'joker' && user.adJokerToday >= cfg.rewardedJokerLimit) {
      return const BilgiResult(message: '📅 Bugünkü hakkını kullandın.');
    }
    if (kind == 'life' && user.adLifeToday >= cfg.rewardedLifeLimit) {
      return const BilgiResult(message: '📅 Bugünkü hakkını kullandın.');
    }
    var next = user;
    if (kind == 'gold') {
      next = user.copyWith(gold: user.gold + cfg.rewardedGold, adGoldToday: user.adGoldToday + 1);
    } else if (kind == 'joker') {
      final jokers = Map<String, int>.from(user.jokers);
      jokers['half'] = (jokers['half'] ?? 0) + 1;
      next = user.copyWith(jokers: jokers, adJokerToday: user.adJokerToday + 1);
    } else if (kind == 'life') {
      next = user.copyWith(
        lives: (user.lives + 1).clamp(0, cfg.maxLives),
        adLifeToday: user.adLifeToday + 1,
      );
    }
    await _save(next);
    return BilgiResult(profile: next);
  }

  Future<BilgiProfile> setLocale(String localeId) async {
    final user = await profile();
    final next = user.copyWith(locale: GameLocale.resolve(localeId).id, localeChosen: true);
    await _save(next);
    return _pushRemote(next);
  }

  Future<BilgiResult> updateProfile({String? username, String? city, String? avatar}) async {
    final user = await profile();
    var next = user;
    var markChosen = false;
    String? chosenBefore;
    if (username != null) {
      final issue = bilgiUsernameIssue(username);
      if (issue != null) return BilgiResult(message: issue, profile: user);
      final name = bilgiUsernameNormalized(username);
      if (await _usernameTaken(name, exceptId: user.id)) {
        return BilgiResult(message: UserMessages.nicknameTaken, profile: user);
      }
      next = next.copyWith(username: name);
      markChosen = true;
      chosenBefore = await _store.getMeta(_usernameChosenKey(user.id));
    }
    next = next.copyWith(city: city, avatar: avatar);
    await _save(next);
    if (markChosen) await _store.putMeta(_usernameChosenKey(user.id), '1');
    try {
      return BilgiResult(profile: await _pushRemote(next));
    } on BilgiUsernameTaken {
      await _save(user);
      if (markChosen && chosenBefore != '1') {
        await _store.putMeta(_usernameChosenKey(user.id), chosenBefore ?? '');
      }
      return BilgiResult(message: UserMessages.nicknameTaken, profile: user);
    }
  }

  Future<BilgiResult> claimInvite(String code) async {
    final user = await profile();
    if (remoteWallet != null) {
      final remote = await _serverWallet('invite', {'userId': user.id, 'code': code});
      if (remote != null) return remote;
    }
    final all = await users();
    final host = all.where((u) => u.inviteCode == code.trim() && u.id != user.id);
    if (host.isEmpty) return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    final friend = host.first;
    if (user.friends.contains(friend.id)) {
      return const BilgiResult(message: '📅 Bugünkü hakkını kullandın.');
    }
    final invites = friend.invites + 1;
    final friendLives = invites % 5 == 0 ? friend.lives + 1 : friend.lives;
    await _save(friend.copyWith(
      gold: friend.gold + 100,
      invites: invites,
      lives: friendLives,
      friends: [...friend.friends, user.id],
    ));
    final next = user.copyWith(gold: user.gold + 100, friends: [...user.friends, friend.id]);
    await _save(next);
    return BilgiResult(profile: next);
  }

  Future<List<Map<String, dynamic>>> games() async {
    final rows = await _store.values(_games);
    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<List<Map<String, dynamic>>> history() async {
    final user = await profile();
    final rows = await games();
    final mine = rows.where((row) => row['userId'] == user.id).toList();
    mine.sort((a, b) => '${b['startedAt']}'.compareTo('${a['startedAt']}'));
    return mine;
  }

  Future<List<BilgiProfile>> leaderboard({String scope = 'global', String? categoryId}) async {
    final snap = await leagueSnapshot(scope: scope, categoryId: categoryId);
    if (snap.seed) return const [];
    final all = await users();
    final byId = {for (final user in all) user.id: user};
    return [for (final row in snap.rows) if (byId[row.id] != null) byId[row.id]!];
  }

  Future<BilgiLeagueSnapshot> leagueSnapshot({
    required String scope,
    String? categoryId,
    bool categoryWeekly = false,
  }) async {
    final all = await users();
    final me = await profile();
    final settled = await _store.getMeta('bilgi_league_settlement') ?? '';
    return bilgiLeagueSnapshot(
      users: all,
      me: me,
      scope: scope,
      categoryId: categoryId,
      categoryWeekly: categoryWeekly,
      now: _clock(),
      settledWeek: settled,
    );
  }

  Future<BilgiProfile> clearLeagueReward() async {
    final user = await profile();
    if (user.leagueRewardText.isEmpty) return user;
    final next = user.copyWith(leagueRewardText: '');
    await _save(next);
    return _pushRemote(next);
  }

  Future<BilgiResult> findDuel() async {
    final user = await profile();
    final waiting = await _store.values(_duel);
    final open = waiting.where((row) => row['userId'] != user.id && row['status'] == 'waiting');
    if (open.isEmpty) {
      final id = 'd${_clock().microsecondsSinceEpoch}';
      await _store.put(_duel, id, {
        'id': id,
        'userId': user.id,
        'name': user.username,
        'status': 'waiting',
      });
      return BilgiResult(
        profile: user,
        message: '🔍 Rakip aranıyor...',
        round: BilgiRound(
          id: id,
          userId: user.id,
          modeId: 'duello',
          categoryId: tumuKarmaId,
          difficulty: '',
          questions: const [],
          multiplier: 1,
          seconds: 10,
          totalSeconds: 0,
          jokerMax: 2,
          lifeCost: 1,
          waiting: true,
        ),
      );
    }
    final seat = open.first;
    await _store.put(_duel, seat['id'] as String, {...seat, 'status': 'matched', 'opponentId': user.id});
    final started = await startRound(modeId: 'duello', categoryId: tumuKarmaId);
    if (started.round != null) {
      started.round!.opponentName = seat['name'] as String? ?? '';
      started.round!.opponentScore = -1;
    }
    return started;
  }

  Future<BilgiRoom?> createRoom({
    String kind = 'oda',
    String categoryId = tumuKarmaId,
    String subcategory = '',
    String difficulty = 'orta',
  }) async {
    final user = await profile();
    final remote = remoteRooms;
    if (remote != null) {
      final sync = await remote.create(
        kind: kind,
        playerId: user.id,
        name: user.username,
        categoryId: categoryId,
        subcategory: subcategory,
        difficulty: difficulty,
      );
      return sync.room;
    }
    final code = _random.nextInt(1000000).toString().padLeft(6, '0');
    final room = BilgiRoom(
      code: code,
      hostId: user.id,
      hostName: user.username,
      categoryId: categoryId,
      questionCount: kind == 'duello' ? 10 : 20,
      seconds: kind == 'duello' ? 10 : 15,
      difficulty: difficulty,
      subcategory: subcategory,
      players: [
        {'id': user.id, 'name': user.username, 'role': 'host'},
      ],
      kind: kind,
    );
    await _store.put(_rooms, code, room.toMap());
    return room;
  }

  Future<BilgiResult> joinRoom(String code, {String? guestName}) async {
    final remote = remoteRooms;
    final user = await profile();
    final name = guestName?.trim().isNotEmpty == true ? guestName!.trim() : user.username;
    if (remote != null) {
      final sync = await remote.join(code: code.trim(), playerId: user.id, name: name);
      if (sync.room == null) {
        return BilgiResult(message: sync.message ?? 'Oda açılamadı. Bağlantını kontrol et.', profile: user);
      }
      return BilgiResult(room: sync.room, profile: user);
    }
    final raw = await _store.get(_rooms, code.trim());
    if (raw == null) return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    final room = BilgiRoom.fromMap(raw);
    if (room.players.length >= 10) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final players = [
      ...room.players,
      {'id': '${user.id}_${room.players.length}', 'name': name, 'role': 'player'},
    ];
    final next = BilgiRoom(
      code: room.code,
      hostId: room.hostId,
      hostName: room.hostName,
      categoryId: room.categoryId,
      questionCount: room.questionCount,
      seconds: room.seconds,
      difficulty: room.difficulty,
      players: players,
      kind: room.kind,
    );
    await _store.put(_rooms, room.code, next.toMap());
    return BilgiResult(room: next, profile: user);
  }

  Future<bool> leaveRoom(String code) async {
    final user = await profile();
    final raw = await _store.get(_rooms, code.trim());
    if (raw == null) return true;
    final room = BilgiRoom.fromMap(raw);
    if (room.status != 'lobby') return false;
    if (user.id == room.hostId) {
      await _store.delete(_rooms, room.code);
      return true;
    }
    final mine = user.id;
    final players = [
      for (final player in room.players)
        if (player['id'] != mine && player['id']?.startsWith('${mine}_') != true) player,
    ];
    await _store.put(
      _rooms,
      room.code,
      BilgiRoom(
        code: room.code,
        hostId: room.hostId,
        hostName: room.hostName,
        categoryId: room.categoryId,
        questionCount: room.questionCount,
        seconds: room.seconds,
        difficulty: room.difficulty,
        players: players,
        kind: room.kind,
        status: room.status,
        subcategory: room.subcategory,
      ).toMap(),
    );
    return true;
  }

  Future<BilgiRoom?> room(String code) async {
    final raw = await _store.get(_rooms, code);
    return raw == null ? null : BilgiRoom.fromMap(raw);
  }

  Future<void> cancelDuel(String? id) async {
    if (id == null || id.isEmpty) return;
    await _store.delete(_duel, id);
  }

  Future<void> replaceQuestionBank(List<BilgiQuestion> questions) async {
    await clearQuestionBank();
    for (final question in questions) {
      if (question.id.isEmpty) continue;
      await _store.put(_questions, question.id, question.toMap());
    }
  }

  Future<String?> readMeta(String key) => _store.getMeta(key);

  Future<void> writeMeta(String key, String value) => _store.putMeta(key, value);

  /// True when today's free gunluk round was already finished (day key locked).
  Future<bool> dailyQuestionUsedToday() async {
    final played = await _store.getMeta('dailyQuestion');
    return played == DateKeys.dayKey(_clock());
  }

  /// Grants a one-shot gunluk start. Call only after a completed rewarded ad.
  /// Does not grant gold, joker, or life.
  Future<void> grantDailyQuestionAdPass() async {
    await _store.putMeta(dailyQuestionAdPassMeta, DateKeys.dayKey(_clock()));
  }

  Future<BilgiResult> saveQuestion(BilgiQuestion question) async {
    await _store.put(_questions, question.id, question.toMap());
    final raw = await _store.get(_questions, question.id);
    if (raw == null || !sameStoredBilgiQuestion(BilgiQuestion.fromMap(raw), question)) {
      throw StateError('Soru kaydedilemedi.');
    }
    return const BilgiResult();
  }

  Future<void> deleteQuestion(String id) => _store.delete(_questions, id);

  Future<Map<String, dynamic>> catalog() async {
    final raw = await _store.get(_catalog, 'main');
    if (raw == null) return {};
    final encoded = raw['json'];
    if (encoded is String && encoded.isNotEmpty) {
      final decoded = jsonDecode(encoded);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<void> saveCatalog(Map<String, dynamic> value) async {
    await _store.put(_catalog, 'main', {'json': jsonEncode(value)});
  }

  Future<void> _changeCatalog(void Function(Map<String, dynamic> doc) change) async {
    final doc = await catalog();
    change(doc);
    await saveCatalog(doc);
  }

  List<Map<String, dynamic>> _customCategories(Map<String, dynamic> doc) => [
        for (final item in doc['custom'] as List? ?? const [])
          if (item is Map) Map<String, dynamic>.from(item),
      ];

  Future<void> editCategory({required String id, required String name, required String emoji, required String group}) async {
    await _changeCatalog((doc) {
      final custom = _customCategories(doc);
      final index = custom.indexWhere((item) => '${item['id']}' == id);
      if (index >= 0) {
        custom[index] = {
          ...custom[index],
          'name': name.trim(),
          'emoji': emoji.trim(),
          'group': group.trim(),
        };
        doc['custom'] = custom;
        return;
      }
      final edits = doc['edits'] is Map ? Map<String, dynamic>.from(doc['edits'] as Map) : <String, dynamic>{};
      final previous = edits[id] is Map ? Map<String, dynamic>.from(edits[id] as Map) : <String, dynamic>{};
      edits[id] = {...previous, 'name': name.trim(), 'emoji': emoji.trim(), 'group': group.trim()};
      doc['edits'] = edits;
    });
  }

  Future<void> addCategory({required String group, required String name, required String emoji}) async {
    await _changeCatalog((doc) {
      final custom = _customCategories(doc);
      custom.add({
        'id': 'c${_clock().microsecondsSinceEpoch}',
        'group': group.trim(),
        'name': name.trim(),
        'emoji': emoji.trim().isEmpty ? '📚' : emoji.trim(),
        'subs': <String>[],
        'active': true,
      });
      doc['custom'] = custom;
    });
  }

  Future<void> addSubcategory(String categoryId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    await _changeCatalog((doc) {
      final custom = _customCategories(doc);
      final index = custom.indexWhere((item) => '${item['id']}' == categoryId);
      if (index >= 0) {
        final subs = [for (final item in custom[index]['subs'] as List? ?? const []) '$item'];
        subs.add(trimmed);
        custom[index]['subs'] = subs;
        doc['custom'] = custom;
        return;
      }
      final extra = doc['extraSubs'] is Map ? Map<String, dynamic>.from(doc['extraSubs'] as Map) : <String, dynamic>{};
      final subs = [for (final item in extra[categoryId] as List? ?? const []) '$item'];
      subs.add(trimmed);
      extra[categoryId] = subs;
      doc['extraSubs'] = extra;
    });
  }

  Future<void> setCategoryActive(String id, bool active) async {
    await _changeCatalog((doc) {
      final custom = _customCategories(doc);
      final index = custom.indexWhere((item) => '${item['id']}' == id);
      if (index >= 0) {
        custom[index]['active'] = active;
        doc['custom'] = custom;
      }
      final inactive = <String>{for (final item in doc['inactive'] as List? ?? const []) '$item'};
      if (active) {
        inactive.remove(id);
      } else {
        inactive.add(id);
      }
      doc['inactive'] = inactive.toList();
    });
  }

  Future<void> setSubActive(String categoryId, String name, bool active) async {
    final key = '$categoryId|${name.trim()}';
    await _changeCatalog((doc) {
      final inactive = <String>{for (final item in doc['inactiveSubs'] as List? ?? const []) '$item'};
      if (active) {
        inactive.remove(key);
      } else {
        inactive.add(key);
      }
      doc['inactiveSubs'] = inactive.toList();
    });
  }

  Future<String?> deleteSubcategory(String categoryId, String name) async {
    final trimmed = name.trim();
    final rows = await questions();
    if (rows.any((question) => question.tags.contains(trimmed))) return 'Bu alt kategoride soru var.';
    await _changeCatalog((doc) {
      final custom = _customCategories(doc);
      final index = custom.indexWhere((item) => '${item['id']}' == categoryId);
      if (index >= 0) {
        final subs = [for (final item in custom[index]['subs'] as List? ?? const []) '$item']..remove(trimmed);
        custom[index]['subs'] = subs;
        doc['custom'] = custom;
      } else {
        final extra = doc['extraSubs'] is Map ? Map<String, dynamic>.from(doc['extraSubs'] as Map) : <String, dynamic>{};
        final subs = [for (final item in extra[categoryId] as List? ?? const []) '$item']..remove(trimmed);
        extra[categoryId] = subs;
        doc['extraSubs'] = extra;
        final source = _sourceSubName(doc, categoryId, trimmed);
        final removed = <String>{for (final item in doc['removedSubs'] as List? ?? const []) '$item'}
          ..add('$categoryId|$source')
          ..add('$categoryId|$trimmed');
        doc['removedSubs'] = removed.toList();
      }
      final inactive = <String>{for (final item in doc['inactiveSubs'] as List? ?? const []) '$item'}..remove('$categoryId|$trimmed');
      doc['inactiveSubs'] = inactive.toList();
    });
    return null;
  }

  Future<void> renameSubcategory(String categoryId, String from, String to, {String? emoji}) async {
    final next = to.trim();
    final previous = from.trim();
    if (next.isEmpty || previous.isEmpty || next == previous) {
      if (emoji != null) await _setSubEmoji(previous, emoji);
      return;
    }
    await _changeCatalog((doc) {
      final custom = _customCategories(doc);
      final index = custom.indexWhere((item) => '${item['id']}' == categoryId);
      if (index >= 0) {
        final subs = [for (final item in custom[index]['subs'] as List? ?? const []) item.toString() == previous ? next : '$item'];
        custom[index]['subs'] = subs;
        doc['custom'] = custom;
      } else {
        final extra = doc['extraSubs'] is Map ? Map<String, dynamic>.from(doc['extraSubs'] as Map) : <String, dynamic>{};
        final subs = [for (final item in extra[categoryId] as List? ?? const []) '$item'];
        final extraIndex = subs.indexOf(previous);
        if (extraIndex >= 0) {
          subs[extraIndex] = next;
          extra[categoryId] = subs;
          doc['extraSubs'] = extra;
        } else {
          final source = _sourceSubName(doc, categoryId, previous);
          final renames = doc['subRenames'] is Map ? Map<String, dynamic>.from(doc['subRenames'] as Map) : <String, dynamic>{};
          renames['$categoryId|$source'] = next;
          doc['subRenames'] = renames;
        }
      }
      final inactive = <String>{for (final item in doc['inactiveSubs'] as List? ?? const []) '$item'};
      if (inactive.remove('$categoryId|$previous')) inactive.add('$categoryId|$next');
      doc['inactiveSubs'] = inactive.toList();
      if (emoji != null && emoji.trim().isNotEmpty) {
        final icons = doc['subEmoji'] is Map ? Map<String, dynamic>.from(doc['subEmoji'] as Map) : <String, dynamic>{};
        icons.remove(previous);
        icons[next] = emoji.trim();
        doc['subEmoji'] = icons;
      }
    });
    final rows = await questions();
    for (final question in rows) {
      if (!question.tags.contains(previous)) continue;
      await saveQuestion(question.copyWith(tags: [for (final tag in question.tags) tag == previous ? next : tag]));
    }
  }

  Future<void> _setSubEmoji(String name, String emoji) async {
    if (emoji.trim().isEmpty) return;
    await _changeCatalog((doc) {
      final icons = doc['subEmoji'] is Map ? Map<String, dynamic>.from(doc['subEmoji'] as Map) : <String, dynamic>{};
      icons[name] = emoji.trim();
      doc['subEmoji'] = icons;
    });
  }

  String _sourceSubName(Map<String, dynamic> doc, String categoryId, String display) {
    final renames = doc['subRenames'];
    if (renames is Map) {
      for (final entry in renames.entries) {
        if ('${entry.key}'.startsWith('$categoryId|') && '${entry.value}' == display) {
          return '${entry.key}'.substring(categoryId.length + 1);
        }
      }
    }
    return display;
  }

  Future<String?> hideCategory(String id) async {
    final rows = await questions();
    if (rows.any((question) => question.categoryId == id)) return 'Bu kategoride soru var.';
    await _changeCatalog((doc) {
      final custom = _customCategories(doc);
      final index = custom.indexWhere((item) => '${item['id']}' == id);
      if (index >= 0) {
        custom.removeAt(index);
        doc['custom'] = custom;
        return;
      }
      final hidden = <String>{for (final item in doc['hidden'] as List? ?? const []) '$item'}..add(id);
      doc['hidden'] = hidden.toList();
    });
    return null;
  }

  int achievementProgress(BilgiProfile user, String id) {
    return switch (id) {
      'first' => user.gamesPlayed,
      'aim' => user.correctTotal,
      'streak' => user.streak,
      'duel' => user.duelWins,
      'cats' => user.categoriesPlayed.where((c) => c != tumuKarmaId).length,
      'peak' => user.level,
      _ => 0,
    };
  }

  Future<BilgiResult> requestPasswordReset(String email) async {
    final all = await users();
    final match = all.where((u) => u.email.toLowerCase() == email.trim().toLowerCase());
    if (match.isEmpty) {
      return const BilgiResult(message: 'Bu e-posta bu cihazda kayıtlı değil.');
    }
    return const BilgiResult();
  }

  Future<BilgiResult> resetPassword({required String email, required String password}) async {
    if (password.length < 6) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final all = await users();
    final match = all.where((u) => u.email == email.trim());
    if (match.isEmpty) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final next = match.first.copyWith(passwordHash: hashBilgiPassword(password));
    await _save(next);
    return BilgiResult(profile: await _pushRemote(next));
  }

  Future<List<Map<String, dynamic>>> staff() async {
    return (await _store.values('staff')).map(Map<String, dynamic>.from).toList();
  }

  Future<void> saveStaff(String email) async {
    final id = email.trim().toLowerCase();
    if (!id.contains('@')) return;
    await _store.put('staff', id, {'id': id, 'email': id});
  }

  Future<bool> seenIntro() async => (await _store.getMeta('intro')) == '2';

  Future<void> markIntro() => _store.putMeta('intro', '2');

  Future<bool> seenNotify() async => (await _store.getMeta('notifyAsked')) == '1';

  Future<void> markNotify({required bool enabled}) async {
    await _store.putMeta('notifyAsked', '1');
    await _store.putMeta('notifyOn', enabled ? '1' : '0');
  }

  Future<BilgiResult> requestReset(String email) => requestPasswordReset(email);

  Future<List<Map<String, dynamic>>> events() async {
    final rows = await _store.values('events');
    return rows.map(Map<String, dynamic>.from).toList();
  }

  Future<void> saveEvent(Map<String, dynamic> event) async {
    final id = event['id'] as String? ?? 'e${_clock().microsecondsSinceEpoch}';
    await _store.put('events', id, {...event, 'id': id});
  }

  Future<void> deleteEvent(String id) => _store.delete('events', id);

  Future<void> setBan(String userId, {required bool banned, String reason = ''}) async {
    final raw = await _store.get(_users, userId);
    if (raw == null) return;
    final user = BilgiProfile.fromMap(raw).copyWith(banned: banned, banReason: reason);
    await _save(user);
    await _pushRemote(user);
  }
}

String hashBilgiPassword(String password) {
  var hash = 2166136261;
  for (final unit in password.codeUnits) {
    hash ^= unit;
    hash = (hash * 16777619) & 0x7fffffff;
  }
  return hash.toRadixString(16);
}
