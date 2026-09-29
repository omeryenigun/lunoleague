import 'dart:convert';
import 'dart:math';

import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_trial_questions.dart';

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
}) {
  if (question.status != 'approved') return false;
  if (difficulty.isNotEmpty && difficulty != 'hepsi' && question.difficulty != difficulty) return false;
  final owner = categories.where((category) => category.id == question.categoryId).firstOrNull;
  if (owner == null || !question.tags.any(owner.subs.contains)) return false;
  if (categoryId == tumuKarmaId) return true;
  if (question.categoryId != categoryId) return false;
  if (subcategory.isEmpty) return true;
  return owner.subs.contains(subcategory) && question.tags.contains(subcategory);
}

class LunoBilgiServer {
  LunoBilgiServer(this._store, {DateTime Function()? clock, Random? random})
      : _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final KeyValueStore _store;
  final DateTime Function() _clock;
  final Random _random;
  final Map<String, BilgiRound> _rounds = {};

  static const _users = 'users';
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
      final guest = _newProfile(username: 'Oyuncu', jokers: await _starterJokers(), lives: seedCfg.startLives);
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
    return BilgiConfig.fromMap(await _store.get(_config, 'main'));
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
    final lives = regeneratedLives(
      lives: user.lives,
      livesAt: user.livesAt,
      now: now,
      maxLives: cfg.maxLives,
      minutesPerLife: cfg.lifeMinutes,
    );
    final clock = livesClockAfterRegen(
      lives: user.lives,
      livesAt: user.livesAt,
      now: now,
      maxLives: cfg.maxLives,
      minutesPerLife: cfg.lifeMinutes,
    );
    final today = DateKeys.dayKey(now);
    final week = DateKeys.weekId(now);
    user = user.copyWith(
      lives: lives,
      livesAt: lives >= cfg.maxLives ? now : clock,
      weekId: user.weekId == week ? user.weekId : week,
      weekScore: user.weekId == week ? user.weekScore : 0,
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
    await _save(user);
    return user;
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
    String username = 'Oyuncu',
    String email = '',
    String passwordHash = '',
    Map<String, int>? jokers,
    int? lives,
  }) {
    final now = _clock();
    final id = 'u${now.microsecondsSinceEpoch}${_random.nextInt(999)}';
    return BilgiProfile(
      id: id,
      username: username,
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
      weekId: DateKeys.weekId(now),
      weekScore: 0,
    );
  }

  Future<void> _save(BilgiProfile user) => _store.put(_users, user.id, user.toMap());

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
    final all = await users();
    if (all.any((u) => u.username.toLowerCase() == username.trim().toLowerCase())) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final user = _newProfile(
      username: username.trim(),
      email: email.trim(),
      passwordHash: hashBilgiPassword(password),
      jokers: await _starterJokers(),
      lives: cfg.startLives,
    );
    await _save(user);
    await _store.putMeta(_active, user.id);
    return BilgiResult(profile: user);
  }

  Future<BilgiResult> loginSocial({required String email, String? username}) async {
    final trimmed = email.trim();
    if (!trimmed.contains('@')) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final all = await users();
    final match = all.where((u) => u.email.toLowerCase() == trimmed.toLowerCase());
    if (match.isNotEmpty) {
      final user = match.first;
      if (user.banned) return const BilgiResult(message: '🚫 Hesabın askıya alındı.');
      await _store.putMeta(_active, user.id);
      return BilgiResult(profile: user);
    }
    final name = username?.trim();
    final user = _newProfile(
      username: name != null && name.length >= 3 ? name : trimmed.split('@').first,
      email: trimmed,
      passwordHash: '',
      jokers: await _starterJokers(),
      lives: (await config()).startLives,
    );
    await _save(user);
    await _store.putMeta(_active, user.id);
    return BilgiResult(profile: user);
  }

  Future<BilgiResult> login({required String email, required String password}) async {
    final all = await users();
    final hash = hashBilgiPassword(password);
    final match = all.where((u) => u.email == email.trim() && u.passwordHash == hash);
    if (match.isEmpty) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final user = match.first;
    if (user.banned) return const BilgiResult(message: '🚫 Hesabın askıya alındı.');
    await _store.putMeta(_active, user.id);
    return BilgiResult(profile: user);
  }

  Future<String?> startGate(BilgiProfile user, BilgiMode mode) async {
    final cfg = await config();
    if (cfg.maintenance) return '🔧 Bakımdayız';
    if (user.banned) return '🚫 Hesabın askıya alındı.';
    if (cfg.livesEnabled && user.lives < mode.lifeCost) {
      return '❤️ Canın bitti! Yenilenmesini bekle veya satın al.';
    }
    return null;
  }

  bool needsAd(BilgiProfile user, BilgiConfig cfg) {
    if (user.premium) return false;
    if (user.adFreeLeft > 0) return false;
    final today = DateKeys.dayKey(_clock());
    final used = user.lastPlayDay == today ? user.freePlaysUsed : 0;
    return used >= cfg.dailyFreeGames;
  }

  Future<BilgiResult> startRound({
    required String modeId,
    String categoryId = tumuKarmaId,
    String subcategory = '',
    String difficulty = '',
    int? questionCount,
    bool adCleared = false,
  }) async {
    final user = await profile();
    final cfg = await config();
    final mode = cfg.resolvedMode(bilgiModeById(modeId));
    if (mode.id == 'gunluk') {
      final played = await _store.getMeta('dailyQuestion');
      if (played == DateKeys.dayKey(_clock())) {
        return const BilgiResult(message: '📅 Bugünkü hakkını kullandın.');
      }
    }
    final blocked = await startGate(user, mode);
    if (blocked != null) return BilgiResult(message: blocked, profile: user);
    if (needsAd(user, cfg) && !adCleared) {
      return BilgiResult(message: 'ad', profile: user);
    }
    if (categoryId != tumuKarmaId && resolveBilgiCategories(await catalog(), playableOnly: true).every((category) => category.id != categoryId)) {
      return const BilgiResult(message: 'Bu kategori şu an oyunda değil.');
    }
    final pool = await _draw(
      categoryId: categoryId,
      subcategory: subcategory,
      difficulty: difficulty,
      count: questionCount ?? mode.questions,
    );
    if (pool.isEmpty) {
      return const BilgiResult(message: '❓ Bu kategoride yeterli soru yok.');
    }
    final today = DateKeys.dayKey(_clock());
    var next = user.copyWith(
      lives: cfg.livesEnabled ? user.lives - mode.lifeCost : user.lives,
      livesAt: user.lives >= cfg.maxLives ? _clock() : user.livesAt,
      gamesPlayed: user.gamesPlayed + 1,
      adFreeLeft: user.adFreeLeft > 0 ? user.adFreeLeft - 1 : 0,
      lastPlayDay: today,
      freePlaysUsed: user.adFreeLeft > 0
          ? user.freePlaysUsed
          : (user.lastPlayDay == today ? user.freePlaysUsed : 0) + (needsAd(user, cfg) ? 0 : 1),
    );
    if (mode.lifeCost > 0 && user.lives == cfg.maxLives) {
      next = next.copyWith(livesAt: _clock());
    }
    await _save(next);
    final round = BilgiRound(
      id: 'g${_clock().microsecondsSinceEpoch}',
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
      startedAt: _clock(),
    );
    _rounds[round.id] = round;
    return BilgiResult(profile: next, round: round);
  }

  Future<List<BilgiQuestion>> _draw({
    required String categoryId,
    required String difficulty,
    required int count,
    String subcategory = '',
  }) async {
    final categories = resolveBilgiCategories(await catalog(), playableOnly: true);
    final all = (await questions())
        .where((question) => bilgiPlayableQuestion(question, categories, categoryId: categoryId, subcategory: subcategory, difficulty: difficulty))
        .toList();
    all.shuffle(_random);
    if (all.length > count) return all.sublist(0, count);
    return all;
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
      return BilgiResult(round: round, profile: await profile());
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
    if (round.index >= round.questions.length) {
      return finish(roundId);
    }
    return BilgiResult(round: round, profile: await profile());
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
    final nextJokers = Map<String, int>.from(user.jokers);
    nextJokers[type] = stock - 1;
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
      round.hint = question.explanation;
    } else if (type == 'change') {
      final spare = await _draw(categoryId: round.categoryId, subcategory: round.subcategory, difficulty: round.difficulty, count: 8);
      final replacement = spare.where((q) => !round.questions.any((have) => have.id == q.id)).toList();
      if (replacement.isEmpty) {
        round.jokersUsed -= 1;
        return BilgiResult(message: '❓ Bu kategoride yeterli soru yok.', profile: user);
      }
      round.questions[round.index] = replacement.first;
      round.hidden = const [];
      round.hint = '';
    }
    final saved = user.copyWith(jokers: nextJokers);
    await _save(saved);
    return BilgiResult(profile: saved, round: round);
  }

  Future<BilgiResult> finish(String roundId) async {
    final round = _rounds[roundId];
    if (round == null) return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    if (!round.finished) {
      round.finished = true;
      final user = await profile();
      var gold = goldForScore(round.score, round.multiplier);
      var xp = xpForScore(round.score);
      if (round.modeId == 'gunluk' && round.correct > 0) {
        gold = 100;
        xp = 50;
      }
      if (round.modeId == 'duello' && round.opponentName.isNotEmpty && round.opponentScore >= 0) {
        gold = round.score >= round.opponentScore ? 50 : 10;
      }
      final level = applyXp(level: user.level, xp: user.xp, gained: xp);
      final cats = {...user.categoriesPlayed, round.categoryId}.toList();
      final duelWins = user.duelWins +
          ((round.modeId == 'duello' &&
                  round.opponentName.isNotEmpty &&
                  round.opponentScore >= 0 &&
                  round.score >= round.opponentScore)
              ? 1
              : 0);
      var next = user.copyWith(
        gold: user.gold + gold,
        xp: level.xp,
        level: level.level,
        diamond: user.diamond + level.diamondsGained,
        correctTotal: user.correctTotal + round.correct,
        bestScore: round.score > user.bestScore ? round.score : user.bestScore,
        totalScore: user.totalScore + round.score,
        weekScore: user.weekScore + round.score,
        categoriesPlayed: cats,
        duelWins: duelWins,
        title: level.level >= 10 ? 'Bilge' : user.title,
      );
      next = _withBadges(next);
      round.gold = gold;
      round.xp = xp;
      await _save(next);
      await _store.put(_games, round.id, round.toMap());
      if (round.modeId == 'gunluk') {
        await _store.putMeta('dailyQuestion', DateKeys.dayKey(_clock()));
      }
      return BilgiResult(profile: next, round: round);
    }
    return BilgiResult(profile: await profile(), round: round);
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
    final cfg = await config();
    if (user.gold < cfg.lifePrice) {
      return const BilgiResult(message: '🪙 Yeterli altının yok. Mağazadan altın al.');
    }
    final next = user.copyWith(gold: user.gold - cfg.lifePrice, lives: cfg.maxLives, livesAt: _clock());
    await _save(next);
    return BilgiResult(profile: next);
  }

  Future<BilgiResult> grantAd({required String kind}) async {
    final user = await profile();
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

  Future<BilgiResult> updateProfile({String? username, String? city, String? avatar}) async {
    final user = await profile();
    final next = user.copyWith(username: username, city: city, avatar: avatar);
    await _save(next);
    return BilgiResult(profile: next);
  }

  Future<BilgiResult> claimInvite(String code) async {
    final user = await profile();
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
    final all = await users();
    final me = await profile();
    var list = all.where((u) => !u.banned).toList();
    if (scope == 'weekly') {
      list.sort((a, b) => b.weekScore.compareTo(a.weekScore));
    } else if (scope == 'friends') {
      list = list.where((u) => u.id == me.id || me.friends.contains(u.id)).toList();
      list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    } else if (scope == 'city') {
      if (me.city.isEmpty) return const [];
      list = list.where((u) => u.city == me.city).toList();
      list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    } else {
      list.sort((a, b) => b.totalScore.compareTo(a.totalScore));
    }
    return list;
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

  Future<BilgiRoom> createRoom({String kind = 'oda'}) async {
    final user = await profile();
    final code = 'LB${_random.nextInt(90) + 10}';
    final room = BilgiRoom(
      code: code,
      hostId: user.id,
      hostName: user.username,
      categoryId: tumuKarmaId,
      questionCount: kind == 'duello' ? 10 : 20,
      seconds: kind == 'duello' ? 10 : 15,
      difficulty: 'orta',
      players: [
        {'id': user.id, 'name': user.username, 'role': 'host'},
      ],
      kind: kind,
    );
    await _store.put(_rooms, code, room.toMap());
    return room;
  }

  Future<BilgiResult> joinRoom(String code, {String? guestName}) async {
    final raw = await _store.get(_rooms, code.trim());
    if (raw == null) return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    final room = BilgiRoom.fromMap(raw);
    final user = await profile();
    if (room.players.length >= 10) {
      return const BilgiResult(message: '⚠️ Bir şeyler ters gitti. Tekrar dene.');
    }
    final name = guestName?.trim().isNotEmpty == true ? guestName!.trim() : user.username;
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

  Future<BilgiRoom?> room(String code) async {
    final raw = await _store.get(_rooms, code);
    return raw == null ? null : BilgiRoom.fromMap(raw);
  }

  Future<BilgiRoom?> openGroupRoom() async {
    final rows = await _store.values(_rooms);
    for (final raw in rows) {
      final room = BilgiRoom.fromMap(raw);
      if (room.kind == 'grup' && room.players.length < 10) return room;
    }
    return null;
  }

  Future<void> cancelDuel(String? id) async {
    if (id == null || id.isEmpty) return;
    await _store.delete(_duel, id);
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
        return;
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
    return BilgiResult(profile: next);
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
