import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/core/services/google_auth.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';

class BilgiController extends ChangeNotifier {
  BilgiController(this.server, {this.ads});

  final LunoBilgiServer server;
  final AdService? ads;
  final List<String> stack = ['home'];
  Timer? _timer;

  BilgiProfile? profile;
  BilgiConfig config = const BilgiConfig();
  BilgiRound? round;
  BilgiRoom? room;
  String? notice;
  String categoryId = tumuKarmaId;
  String modeId = 'hizli';
  String difficulty = 'hepsi';
  String subName = '';
  int questionChoice = 10;
  bool busy = false;
  int secondsLeft = 0;
  int marathonLeft = 0;
  int pauseLeft = 0;
  int adLeft = 0;
  int poolCount = 0;
  Map<String, int> categoryCounts = const {};
  Map<String, int> subCounts = const {};
  List<BilgiCategory> categories = bilgiCategories;
  String boardScope = 'global';
  List<BilgiProfile> board = const [];
  List<Map<String, dynamic>> past = const [];
  List<Map<String, dynamic>> eventRows = const [];
  bool picked = false;
  bool revealing = false;
  int? lastPick;
  int? revealCorrect;
  int revealNumber = 1;
  List<String> revealOptions = const [];
  String revealText = '';
  String revealDifficulty = '';
  bool scoreDoubled = false;
  List<String> newBadgeIds = const [];
  bool notifyOn = true;
  bool soundOn = true;

  String get page => stack.last;
  bool get showNav => const {
        'home',
        'play',
        'categories',
        'detail',
        'setup',
        'league',
        'profile',
        'shop',
        'group',
        'room',
      }.contains(page);

  Future<void> retry() async {
    notice = null;
    await boot();
  }

  Future<void> boot() async {
    config = await server.config();
    profile = await server.profile();
    if (config.maintenance) {
      stack
        ..clear()
        ..add('maintenance');
    } else if (!await server.seenIntro()) {
      stack
        ..clear()
        ..add('intro');
    } else if (!await server.seenNotify()) {
      stack
        ..clear()
        ..add('notify');
    }
    await loadCategoryCounts();
    await refreshPool();
    notifyListeners();
  }

  void open(String id) {
    notice = null;
    if (id == 'detail' || id == 'setup') _preparePlaySettings();
    stack.add(id);
    notifyListeners();
    if (id == 'league') unawaited(loadBoard());
    if (id == 'history' || id == 'profile') unawaited(loadHistory());
    if (id == 'event') unawaited(loadEvents());
    if (id == 'setup' || id == 'detail') unawaited(refreshPool());
    if (id == 'categories') unawaited(loadCategoryCounts());
  }

  void flash(String text) {
    notice = text;
    notifyListeners();
  }

  void toggleNotify() {
    notifyOn = !notifyOn;
    notifyListeners();
  }

  void toggleSound() {
    soundOn = !soundOn;
    notifyListeners();
  }

  void back() {
    _timer?.cancel();
    if (stack.length > 1) stack.removeLast();
    notice = null;
    notifyListeners();
  }

  void tab(String id) {
    _timer?.cancel();
    stack
      ..clear()
      ..add(id);
    notice = null;
    notifyListeners();
    if (id == 'league') unawaited(loadBoard());
    if (id == 'profile') unawaited(loadHistory());
    if (id == 'play' || id == 'home') unawaited(_reloadProfile());
  }

  bool _playDifficulty(String value) {
    return value == 'kolay' || value == 'orta' || value == 'zor' || value == 'efsane';
  }

  void _preparePlaySettings() {
    if (!_playDifficulty(difficulty)) difficulty = 'kolay';
    final questions = bilgiModeById(modeId).questions;
    if (questions == 10 || questions == 20 || questions == 50) {
      questionChoice = questions;
    }
  }

  Future<void> _reloadProfile() async {
    profile = await server.profile();
    notifyListeners();
  }

  Future<void> loadCategoryCounts() async {
    final all = await server.questions();
    final playable = resolveBilgiCategories(await server.catalog(), playableOnly: true);
    final counts = <String, int>{};
    final subs = <String, int>{};
    var approved = 0;
    for (final question in all) {
      if (!bilgiPlayableQuestion(question, playable, categoryId: tumuKarmaId)) continue;
      approved += 1;
      counts[question.categoryId] = (counts[question.categoryId] ?? 0) + 1;
      final owner = playable.where((category) => category.id == question.categoryId).firstOrNull;
      if (owner == null) continue;
      for (final tag in question.tags) {
        if (!owner.subs.contains(tag)) continue;
        final key = '${question.categoryId}|$tag';
        subs[key] = (subs[key] ?? 0) + 1;
      }
    }
    counts[tumuKarmaId] = approved;
    categoryCounts = counts;
    subCounts = subs;
    categories = playable;
    notifyListeners();
  }

  Future<void> refreshPool() async {
    final playable = resolveBilgiCategories(await server.catalog(), playableOnly: true);
    final all = await server.questions();
    poolCount = all.where((question) => bilgiPlayableQuestion(question, playable, categoryId: categoryId, subcategory: subName, difficulty: difficulty)).length;
    notifyListeners();
  }

  void selectMode(String id) {
    modeId = id;
    if (id == 'duello') {
      open('duel');
      return;
    }
    if (id == 'grup') {
      open('group');
      return;
    }
    if (id == 'oda') {
      open('room');
      return;
    }
    if (id == 'gunluk') {
      categoryId = tumuKarmaId;
      open('daily');
      return;
    }
    open('categories');
  }

  void selectCategory(String id) {
    categoryId = id;
    subName = '';
    open('detail');
  }

  void selectSub(String name) {
    subName = name;
    open('setup');
  }

  void selectDifficulty(String value) {
    difficulty = value;
    notifyListeners();
    unawaited(refreshPool());
  }

  void selectQuestionChoice(int value) {
    questionChoice = value;
    notifyListeners();
  }

  void selectPlayMode(String id) {
    modeId = id;
    final questions = bilgiModeById(id).questions;
    if (questions == 10 || questions == 20 || questions == 50) {
      questionChoice = questions;
    }
    notifyListeners();
  }

  int playableCount() {
    if (poolCount <= 0) return 0;
    return poolCount < questionChoice ? poolCount : questionChoice;
  }

  Future<void> start({bool adCleared = false, int? count, String? forcedMode}) async {
    if (busy) return;
    busy = true;
    notice = null;
    notifyListeners();
    final result = await server.startRound(
      modeId: forcedMode ?? modeId,
      categoryId: categoryId,
      subcategory: subName,
      difficulty: difficulty,
      questionCount: count ?? questionChoice,
      adCleared: adCleared,
    );
    busy = false;
    profile = result.profile ?? profile;
    if (result.message == 'ad') {
      adLeft = config.preGameAdSeconds;
      open('ad');
      _armAd();
      return;
    }
    if (result.message != null) {
      notice = result.message;
      if (result.message!.contains('Canın')) open('nolives');
      notifyListeners();
      return;
    }
    final started = result.round;
    if (started == null) {
      notice = '⚠️ Bir şeyler ters gitti. Tekrar dene.';
      notifyListeners();
      return;
    }
    if (started.waiting) {
      round = started;
      open('duel');
      return;
    }
    _begin(started);
  }

  void _begin(BilgiRound started) {
    round = started;
    picked = false;
    revealing = false;
    lastPick = null;
    revealCorrect = null;
    revealOptions = const [];
    revealText = '';
    revealDifficulty = '';
    revealNumber = 1;
    scoreDoubled = false;
    newBadgeIds = const [];
    secondsLeft = started.seconds;
    marathonLeft = started.totalSeconds;
    pauseLeft = 0;
    stack
      ..clear()
      ..add('game');
    _armPlay();
    notifyListeners();
  }

  void _armPlay() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final live = round;
    if (live == null || live.finished || page != 'game') return;
    if (live.paused) {
      pauseLeft = (pauseLeft - 1).clamp(0, 10);
      if (pauseLeft <= 0) live.paused = false;
      notifyListeners();
      return;
    }
    if (live.totalSeconds > 0) {
      marathonLeft = (marathonLeft - 1).clamp(0, live.totalSeconds);
      if (marathonLeft == 0) {
        unawaited(endRound());
        return;
      }
    }
    if (live.seconds > 0) {
      secondsLeft = (secondsLeft - 1).clamp(0, live.seconds);
      if (secondsLeft == 0 && !picked) {
        unawaited(pick(-1));
      }
    }
    notifyListeners();
  }

  void _armAd() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (page != 'ad') return;
      adLeft -= 1;
      if (adLeft > 0) {
        notifyListeners();
        return;
      }
      _timer?.cancel();
      final user = profile;
      final played = user == null ? false : await (ads?.showRewarded(user.id) ?? Future.value(false));
      if (!played) {
        notice = '📡 Bağlantı hatası. İnternetini kontrol et.';
        if (stack.isNotEmpty && stack.last == 'ad') stack.removeLast();
        notifyListeners();
        return;
      }
      if (stack.isNotEmpty && stack.last == 'ad') stack.removeLast();
      await start(adCleared: true);
    });
  }

  Future<void> pick(int option) async {
    final live = round;
    if (live == null || live.finished || picked) return;
    if (option >= 0 && live.hidden.contains(option)) return;
    final question = live.current;
    if (question == null) return;
    final beforeBadges = [...?profile?.badges];
    picked = true;
    lastPick = option;
    revealCorrect = question.correct;
    revealOptions = question.options;
    revealText = question.text;
    revealDifficulty = question.difficulty;
    revealNumber = live.index + 1;
    revealing = true;
    notifyListeners();
    final result = await server.answer(
      roundId: live.id,
      option: option,
      timeLeft: secondsLeft,
    );
    profile = result.profile ?? profile;
    round = result.round ?? live;
    if (result.message != null && result.round == null) {
      notice = result.message;
      picked = false;
      revealing = false;
      notifyListeners();
      return;
    }
    final retry = option >= 0 && (round?.hidden.contains(option) ?? false) && round?.finished != true;
    if (retry) {
      revealing = false;
      lastPick = null;
      picked = false;
      notifyListeners();
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 700));
    revealing = false;
    if (round?.finished == true) {
      _timer?.cancel();
      newBadgeIds = (profile?.badges ?? const []).where((id) => !beforeBadges.contains(id)).toList();
      stack
        ..clear()
        ..add('result');
      picked = false;
      notifyListeners();
      return;
    }
    secondsLeft = round?.seconds ?? secondsLeft;
    picked = false;
    lastPick = null;
    notifyListeners();
  }

  Future<void> useJoker(String type) async {
    final live = round;
    if (live == null) return;
    final result = await server.useJoker(roundId: live.id, type: type);
    profile = result.profile ?? profile;
    round = result.round ?? live;
    if (result.message == 'joker') {
      open('joker');
      return;
    }
    if (type == 'time' && result.message == null) pauseLeft = 10;
    notice = result.message;
    notifyListeners();
  }

  Future<void> endRound() async {
    final live = round;
    if (live == null) return;
    _timer?.cancel();
    final beforeBadges = [...?profile?.badges];
    final result = await server.finish(live.id);
    profile = result.profile ?? profile;
    round = result.round ?? live;
    newBadgeIds = (profile?.badges ?? const []).where((id) => !beforeBadges.contains(id)).toList();
    revealing = false;
    stack
      ..clear()
      ..add('result');
    notifyListeners();
  }

  Future<void> doubleResultScore() async {
    if (scoreDoubled) return;
    final user = profile;
    if (user == null) return;
    final played = await (ads?.showRewarded(user.id) ?? Future.value(false));
    if (!played) {
      notice = '📡 Bağlantı hatası. İnternetini kontrol et.';
      notifyListeners();
      return;
    }
    final live = round;
    if (live == null || scoreDoubled) return;
    live.score *= 2;
    scoreDoubled = true;
    notice = null;
    notifyListeners();
  }

  void replaySetup() {
    notice = null;
    stack
      ..clear()
      ..add('setup');
    _preparePlaySettings();
    notifyListeners();
    unawaited(refreshPool());
  }

  Future<void> loadBoard() async {
    final scope = boardScope == 'category' ? 'global' : boardScope;
    board = await server.leaderboard(scope: scope);
    notifyListeners();
  }

  Future<void> doubleDailyReward() async {
    if (!rewardReady()) return;
    final user = profile;
    if (user == null) return;
    final played = await (ads?.showRewarded(user.id) ?? Future.value(false));
    if (!played) {
      notice = '📡 Bağlantı hatası. İnternetini kontrol et.';
      notifyListeners();
      return;
    }
    await claimDaily(doubled: true);
  }

  Future<void> buyJokerSet() async {
    final prices = config.jokerPrices;
    final cost = (prices['half'] ?? 50) + (prices['double'] ?? 75) + (prices['time'] ?? 60);
    if ((profile?.gold ?? 0) < cost) {
      notice = '🪙 Yeterli altının yok. Mağazadan altın al.';
      notifyListeners();
      return;
    }
    await buyJoker('half');
    await buyJoker('double');
    await buyJoker('time');
  }

  Future<void> claimDaily({bool doubled = false}) async {
    final result = await server.claimDaily(doubled: doubled);
    profile = result.profile ?? profile;
    notice = result.message;
    if (result.ok) {
      if (page == 'reward') back();
    } else {
      open('reward');
    }
    notifyListeners();
  }

  Future<void> buyJoker(String type) async {
    final result = await server.buyJoker(type);
    profile = result.profile ?? profile;
    notice = result.message;
    notifyListeners();
  }

  Future<void> refill() async {
    final result = await server.refillLives();
    profile = result.profile ?? profile;
    notice = result.message;
    if (result.ok && page == 'nolives') back();
    notifyListeners();
  }

  Future<void> watchFor(String kind) async {
    final user = profile;
    if (user == null) return;
    final played = await (ads?.showRewarded(user.id) ?? Future.value(false));
    if (!played) {
      notice = kIsWeb
          ? '📡 Bağlantı hatası. İnternetini kontrol et.'
          : '⚠️ Bir şeyler ters gitti. Tekrar dene.';
      notifyListeners();
      return;
    }
    final result = await server.grantAd(kind: kind);
    profile = result.profile ?? profile;
    notice = result.message;
    notifyListeners();
  }

  Future<void> findDuel() async {
    busy = true;
    notifyListeners();
    final result = await server.findDuel();
    busy = false;
    profile = result.profile ?? profile;
    round = result.round;
    if (result.message == 'ad') {
      adLeft = config.preGameAdSeconds;
      open('ad');
      _armAd();
      return;
    }
    notice = result.round?.waiting == true ? '🔍 Rakip aranıyor...' : result.message;
    if (result.round != null && !result.round!.waiting && result.round!.questions.isNotEmpty) {
      _begin(result.round!);
      return;
    }
    if (page != 'duel') open('duel');
    notifyListeners();
  }

  Future<void> cancelDuel() async {
    final live = round;
    if (live != null && live.waiting) {
      await server.cancelDuel(live.id);
    }
    if (round?.waiting == true) round = null;
    back();
  }

  Future<void> findGroupMatch() async {
    final found = await server.openGroupRoom();
    if (found == null) {
      notice = 'Açık grup odası yok.';
      notifyListeners();
      return;
    }
    final result = await server.joinRoom(found.code);
    notice = result.message;
    room = result.room ?? room;
    if (room != null) {
      modeId = 'grup';
      if (page != 'room') open('room');
    }
    notifyListeners();
  }

  Future<void> makeRoom(String kind) async {
    room = await server.createRoom(kind: kind);
    modeId = kind == 'grup' ? 'grup' : 'oda';
    open('room');
  }

  Future<void> enterRoom(String code, {String? guestName}) async {
    final result = await server.joinRoom(code, guestName: guestName);
    notice = result.message;
    room = result.room ?? room;
    notifyListeners();
  }

  Future<void> startRoom() async {
    final current = room;
    if (current == null) return;
    categoryId = current.categoryId;
    difficulty = current.difficulty;
    modeId = switch (current.kind) {
      'grup' => 'grup',
      'duello' => 'duello',
      _ => 'oda',
    };
    await start(count: current.questionCount, forcedMode: modeId);
  }

  Future<void> loadHistory() async {
    past = await server.history();
    notifyListeners();
  }

  Future<void> loadEvents() async {
    eventRows = await server.events();
    notifyListeners();
  }

  Future<void> register(String username, String email, String password) async {
    final result = await server.register(username: username, email: email, password: password);
    profile = result.profile ?? profile;
    notice = result.message;
    if (result.ok) tab('home');
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final result = await server.login(email: email, password: password);
    profile = result.profile ?? await server.profile();
    notice = result.message;
    if (result.ok) tab('profile');
    notifyListeners();
  }

  Future<void> loginGoogle() async {
    try {
      final account = await GoogleAuth().signIn();
      final email = account?.email?.trim() ?? '';
      if (account == null || email.isEmpty) {
        notice = '⚠️ Bir şeyler ters gitti. Tekrar dene.';
        notifyListeners();
        return;
      }
      final result = await server.loginSocial(email: email, username: account.displayName);
      profile = result.profile ?? profile;
      notice = result.message;
      if (result.ok) tab('home');
      notifyListeners();
    } catch (_) {
      notice = '⚠️ Bir şeyler ters gitti. Tekrar dene.';
      notifyListeners();
    }
  }

  void socialUnavailable() {
    notice = '⚠️ Bir şeyler ters gitti. Tekrar dene.';
    notifyListeners();
  }

  Future<void> requestReset(String email) async {
    final result = await server.requestPasswordReset(email);
    notice = result.message;
    notifyListeners();
  }

  Future<void> resetPassword(String email, String password) async {
    final result = await server.resetPassword(email: email, password: password);
    notice = result.ok ? 'Şifre güncellendi.' : result.message;
    notifyListeners();
  }

  Future<void> saveProfile({String? username, String? city, String? avatar}) async {
    final result = await server.updateProfile(username: username, city: city, avatar: avatar);
    profile = result.profile ?? profile;
    notifyListeners();
  }

  Future<void> claimInvite(String code) async {
    final result = await server.claimInvite(code);
    profile = result.profile ?? profile;
    notice = result.ok ? 'Davet kabul edildi. +100 altın.' : result.message;
    notifyListeners();
  }

  Future<void> finishIntro() async {
    await server.markIntro();
    if (!await server.seenNotify()) {
      stack
        ..clear()
        ..add('notify');
      notifyListeners();
      return;
    }
    tab('home');
  }

  Future<void> answerNotify(bool enabled) async {
    notifyOn = enabled;
    await server.markNotify(enabled: enabled);
    tab('home');
  }

  bool rewardReady() {
    final user = profile;
    if (user == null) return false;
    return user.rewardReady(DateKeys.dayKey(), DateKeys.dayKey(DateTime.now().subtract(const Duration(days: 1))));
  }

  int rewardIndex() {
    final user = profile;
    if (user == null) return 0;
    return user.nextRewardIndex(DateKeys.dayKey(), DateKeys.dayKey(DateTime.now().subtract(const Duration(days: 1))));
  }

  String rewardLabel(int index) {
    final gold = config.dailyGold[index % 7];
    final diamond = config.dailyDiamond[index % 7];
    final joker = config.dailyJoker[index % 7];
    if (diamond > 0) return '$diamond elmas';
    if (joker > 0) return '$joker joker';
    return '$gold altın';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
