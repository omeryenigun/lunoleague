import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/google_auth.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_l10n.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_mail.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_question_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/injection.dart';

const _countsNotice = '📡 Bağlantı hatası. İnternetini kontrol et.';

class BilgiController extends ChangeNotifier {
  BilgiController(this.server, {this.ads});

  final LunoBilgiServer server;
  final AdService? ads;
  final List<String> stack = ['home'];
  Timer? _timer;
  int _syncBeat = 0;
  BilgiRoomSync? _pendingShared;

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
  bool booting = true;
  String bootLabel = 'Oyun açılıyor...';
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
  BilgiQuestion? revealQuestion;
  List<String> _badgesBeforePick = const [];
  bool scoreDoubled = false;
  List<String> newBadgeIds = const [];
  bool notifyOn = true;
  bool soundOn = true;
  String? localePreview;
  final Map<String, String> labels = {};

  String get page => stack.last;
  String get locale => localePreview ?? profile?.locale ?? 'tr';
  String t(String key) => bilgiT(locale, key);

  String categoryLabel(String id, String fallback) => labels['$locale|category|$id'] ?? fallback;

  String subLabel(String categoryId, String name) => labels['$locale|sub|$categoryId|$name'] ?? name;

  String groupLabel(String name) {
    final stored = labels['$locale|group|$name'];
    if (stored != null && stored.trim().isNotEmpty) return stored;
    return bilgiGroupLabel(locale, name) ?? name;
  }
  bool get showNav => const {
        'home',
        'play',
        'categories',
        'detail',
        'setup',
        'league',
        'settings',
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
    final showNow = profile != null;
    booting = true;
    bootLabel = t('boot_open');
    if (showNow) notifyListeners();
    config = await server.config();
    profile = await server.profile();
    stack
      ..clear()
      ..add(
        bilgiBootPage(
          maintenance: config.maintenance,
          localeChosen: profile?.localeChosen == true,
          seenIntro: await server.seenIntro(),
        ),
      );
    bootLabel = t('loading');
    notifyListeners();
    await loadLabels();
    await loadCategoryCounts();
    await refreshPool();
    booting = false;
    notifyListeners();
  }

  void previewLocale(String localeId) {
    localePreview = GameLocale.resolve(localeId).id;
    notifyListeners();
  }

  Future<void> confirmLocale() async {
    final fromSettings = profile?.localeChosen == true;
    final id = GameLocale.resolve(localePreview ?? profile?.locale).id;
    profile = await server.setLocale(id);
    localePreview = null;
    if (fromSettings) {
      if (stack.length > 1) {
        stack.removeLast();
      } else {
        stack
          ..clear()
          ..add('settings');
      }
      notifyListeners();
      return;
    }
    stack
      ..clear()
      ..add(
        bilgiBootPage(
          maintenance: config.maintenance,
          localeChosen: true,
          seenIntro: await server.seenIntro(),
        ),
      );
    notifyListeners();
  }

  Future<void> loadLabels() async {
    final rows = await BilgiQuestionApi.loadLabels();
    labels
      ..clear()
      ..addAll(rows);
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
    if (id == 'language') localePreview ??= profile?.locale ?? 'tr';
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
    _syncBeat = 0;
    if (stack.length > 1) stack.removeLast();
    notice = null;
    notifyListeners();
  }

  void tab(String id) {
    _timer?.cancel();
    _syncBeat = 0;
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

  Future<Map<String, dynamic>> _visibleCatalog() async {
    final remote = await BilgiQuestionApi.loadCatalog();
    final catalog = remote ?? await server.catalog();
    final active = await BilgiQuestionApi.loadActive();
    if (active == null) return catalog;
    return bilgiCatalogClosedUnless(catalog, active.categories, active.subs);
  }

  Future<void> loadCategoryCounts() async {
    final playable = resolveBilgiCategories(await _visibleCatalog(), playableOnly: true);
    final remote = await BilgiQuestionApi.loadCounts();
    if (remote == null) {
      categories = playable;
      notice = _countsNotice;
      notifyListeners();
      return;
    }
    if (notice == _countsNotice) notice = null;
    categoryCounts = {
      for (final category in playable) category.id: remote.categories[category.id] ?? 0,
      tumuKarmaId: remote.categories[tumuKarmaId] ?? 0,
    };
    subCounts = remote.subs;
    categories = playable;
    notifyListeners();
  }

  Future<void> refreshPool() async {
    final remote = await BilgiQuestionApi.loadCounts();
    if (remote == null) {
      notice = _countsNotice;
      notifyListeners();
      return;
    }
    if (notice == _countsNotice) notice = null;
    poolCount = remote.pool(categoryId, subName, difficulty);
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
    revealQuestion = null;
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
    if (live.seconds > 0 && !revealing) {
      secondsLeft = (secondsLeft - 1).clamp(0, live.seconds);
      if (secondsLeft == 0 && !picked) {
        unawaited(pick(-1));
      }
    }
    if (live.roomCode.isNotEmpty) {
      _syncBeat += 1;
      if (_syncBeat % 2 == 0) unawaited(syncRoom());
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
      final pending = _pendingShared;
      if (pending != null) {
        _pendingShared = null;
        await _startShared(pending, adCleared: true);
        return;
      }
      await start(adCleared: true);
    });
  }

  void _playAnswerSound(bool right) {
    if (!soundOn || !sl.isRegistered<AudioManager>()) return;
    final audio = sl<AudioManager>();
    unawaited(right ? audio.playCue('correct') : audio.playCue('absent'));
  }

  Future<void> pick(int option) async {
    final live = round;
    if (live == null || live.finished || picked) return;
    if (option >= 0 && live.hidden.contains(option)) return;
    final question = live.current;
    if (question == null) return;
    final beforeBadges = [...?profile?.badges];
    final right = option == question.correct;
    picked = true;
    lastPick = option;
    revealCorrect = question.correct;
    revealOptions = question.options;
    revealText = question.text;
    revealDifficulty = question.difficulty;
    revealQuestion = question;
    revealNumber = live.index + 1;
    _badgesBeforePick = beforeBadges;
    revealing = true;
    _playAnswerSound(right);
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
      revealQuestion = null;
      notifyListeners();
      return;
    }
    final retry = option >= 0 && (round?.hidden.contains(option) ?? false) && round?.finished != true;
    if (retry) {
      revealing = false;
      revealQuestion = null;
      lastPick = null;
      picked = false;
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  void continueReveal() {
    if (!revealing) return;
    revealing = false;
    revealQuestion = null;
    if (round?.finished == true) {
      _timer?.cancel();
      newBadgeIds = (profile?.badges ?? const []).where((id) => !_badgesBeforePick.contains(id)).toList();
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

  Future<String?> reportReveal(String note) {
    final question = revealQuestion;
    if (question == null) return Future.value('Soru bulunamadı.');
    return BilgiReportApi.send(question: question, note: note);
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
    final goldBefore = user.gold;
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
    if (kind == 'gold' && result.message == null) {
      final added = (profile?.gold ?? goldBefore) - goldBefore;
      if (added > 0) {
        notice = t('ad_loaded').replaceAll('{n}', '$added');
      }
    }
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
      _armRoom();
    }
    notifyListeners();
  }

  Future<void> makeRoom(String kind) async {
    room = await server.createRoom(
      kind: kind,
      categoryId: categoryId,
      subcategory: subName,
      difficulty: difficulty,
    );
    if (room == null) {
      notice = 'Oda açılamadı. Bağlantını kontrol et.';
      notifyListeners();
      return;
    }
    modeId = kind == 'grup' ? 'grup' : kind == 'duello' ? 'duello' : 'oda';
    open('room');
    _armRoom();
  }

  Future<void> enterRoom(String code, {String? guestName}) async {
    final result = await server.joinRoom(code, guestName: guestName);
    notice = result.message;
    room = result.room ?? room;
    if (result.room != null) {
      if (page != 'room') open('room');
      _armRoom();
    }
    notifyListeners();
  }

  Future<void> startRoom() async {
    final current = room;
    if (current == null) return;
    final hooks = server.remoteRooms;
    if (hooks != null) {
      if (profile?.id != current.hostId) {
        notice = 'Odayı kuran başlatır.';
        notifyListeners();
        return;
      }
      busy = true;
      notice = null;
      notifyListeners();
      final sync = await hooks.start(code: current.code, playerId: profile!.id);
      busy = false;
      if (!sync.ok || sync.questions.isEmpty) {
        notice = sync.message ?? '❓ Bu kategoride yeterli soru yok.';
        room = sync.room ?? room;
        notifyListeners();
        return;
      }
      await _startShared(sync);
      return;
    }
    categoryId = current.categoryId;
    difficulty = current.difficulty;
    modeId = switch (current.kind) {
      'grup' => 'grup',
      'duello' => 'duello',
      _ => 'oda',
    };
    await start(count: current.questionCount, forcedMode: modeId);
  }

  void _armRoom() {
    _timer?.cancel();
    _syncBeat = 0;
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(syncRoom()));
  }

  Future<void> syncRoom() async {
    final hooks = server.remoteRooms;
    final code = round?.roomCode.isNotEmpty == true ? round!.roomCode : (room?.code ?? '');
    if (hooks == null || code.isEmpty) return;
    final liveNow = round;
    if (liveNow != null && liveNow.roomCode == code) {
      await hooks.score(
        code: code,
        playerId: liveNow.userId,
        score: liveNow.score,
        index: liveNow.index,
      );
    }
    final sync = await hooks.poll(code);
    if (sync.room == null) return;
    room = sync.room;
    final live = round;
    if (live != null && live.roomCode == sync.room!.code) {
      _applyStandings(live, sync.room!);
      notifyListeners();
      return;
    }
    if (live == null && page == 'room' && sync.room!.status == 'playing' && sync.questions.isNotEmpty) {
      await _startShared(sync);
    } else {
      notifyListeners();
    }
  }

  Future<void> _startShared(BilgiRoomSync sync, {bool adCleared = false}) async {
    final current = sync.room;
    if (current == null || busy) return;
    busy = true;
    categoryId = current.categoryId;
    subName = current.subcategory;
    difficulty = current.difficulty.isEmpty ? 'hepsi' : current.difficulty;
    modeId = switch (current.kind) {
      'grup' => 'grup',
      'duello' => 'duello',
      _ => 'oda',
    };
    notice = null;
    notifyListeners();
    final result = await server.startRound(
      modeId: modeId,
      categoryId: categoryId,
      subcategory: subName,
      difficulty: difficulty,
      questionCount: sync.questions.length,
      fixedQuestions: sync.questions,
      fixedSpare: sync.spare,
      roomCode: current.code,
      adCleared: adCleared,
    );
    busy = false;
    profile = result.profile ?? profile;
    if (result.message == 'ad') {
      _pendingShared = sync;
      adLeft = config.preGameAdSeconds;
      open('ad');
      _armAd();
      return;
    }
    if (result.message != null || result.round == null) {
      notice = result.message ?? '⚠️ Bir şeyler ters gitti. Tekrar dene.';
      notifyListeners();
      return;
    }
    _applyStandings(result.round!, current);
    _begin(result.round!);
  }

  void _applyStandings(BilgiRound live, BilgiRoom current) {
    live.standings = [
      for (final player in current.players)
        if (player['id'] == live.userId) {...player, 'score': '${live.score}'} else Map<String, String>.from(player),
    ];
    final others = live.standings.where((player) => player['id'] != live.userId);
    if (others.isEmpty) return;
    final rival = others.first;
    live.opponentName = rival['name'] ?? '';
    live.opponentScore = int.tryParse(rival['score'] ?? '') ?? live.opponentScore;
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
    if (!result.ok) {
      notice = result.message;
      notifyListeners();
      return;
    }
    notice = await BilgiMailApi.sendReset(email);
    notifyListeners();
  }

  Future<void> confirmReset(String email, String code, String password) async {
    final local = await server.requestPasswordReset(email);
    if (!local.ok) {
      notice = local.message;
      notifyListeners();
      return;
    }
    final error = await BilgiMailApi.confirm(email, code);
    if (error != null) {
      notice = error;
      notifyListeners();
      return;
    }
    final result = await server.resetPassword(email: email, password: password);
    notice = result.ok ? 'Şifre güncellendi.' : result.message;
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
    final gold = dayRewardAmount(config.dailyGold, index);
    final diamond = dayRewardAmount(config.dailyDiamond, index);
    final joker = dayRewardAmount(config.dailyJoker, index);
    if (diamond > 0) return '$diamond ${t('diamond')}';
    if (joker > 0) return '$joker ${t('joker')}';
    return '$gold ${t('gold')}';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
