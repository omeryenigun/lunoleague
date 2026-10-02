import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/core/services/audio_manager.dart';
import 'package:kelimelig/core/services/google_auth.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/services/billing_gateway.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_l10n.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_mail.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_question_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_shop.dart';
import 'package:kelimelig/injection.dart';

const _countsNotice = '📡 Bağlantı hatası. İnternetini kontrol et.';
const _adFailNotice = '📡 Bağlantı hatası. İnternetini kontrol et.';
const _adRetryNotice = '⚠️ Bir şeyler ters gitti. Tekrar dene.';

/// Shown after a completed watch: first while the reward is applied, then with the loaded amount.
class BilgiRewardLoad {
  const BilgiRewardLoad({
    required this.icon,
    required this.amount,
    required this.caption,
    required this.loading,
  });

  final String icon;
  final String amount;
  final String caption;
  final bool loading;
}

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
  /// Bumps when a gold spend is refused so the screen opens the options dialog.
  int goldHelpSerial = 0;
  /// Shop should scroll to the gold packs on the next shop build.
  bool pendingShopGold = false;
  String categoryId = tumuKarmaId;
  String modeId = 'hizli';
  String difficulty = 'hepsi';
  String subName = '';
  int questionChoice = 10;
  bool busy = false;
  /// True while [start] is drawing questions for the chosen round settings.
  bool roundLoading = false;
  double loadProgress = 0;
  String loadStatusKey = 'load_status_sending';
  String loadTipKey = 'load_tip_speed';
  int _startEpoch = 0;
  static const _loadTips = ['load_tip_speed', 'load_tip_joker', 'load_tip_streak'];
  /// True while reading local profile to decide language vs opening loader.
  bool resolvingLocale = true;
  /// First-launch language picker; no opening loader in front of it.
  bool awaitingLocale = false;
  bool booting = false;
  double bootProgress = 0;
  String bootStatusKey = 'boot_status_starting';
  String bootMessageKey = 'boot_msg_connecting';
  String bootLabel = 'Oyun açılıyor...';
  int secondsLeft = 0;
  int marathonLeft = 0;
  int pauseLeft = 0;
  int adLeft = 0;
  int poolCount = 0;
  Map<String, int> categoryCounts = const {};
  Map<String, int> subCounts = const {};
  List<BilgiCategory> categories = bilgiCategories;
  String boardScope = 'general';
  String? boardCategoryId;
  bool boardWeekly = true;
  List<BilgiBoardEntry> boardRows = const [];
  bool boardSeed = false;
  int boardRealCount = 0;
  List<String> boardCategoryIds = const [];
  Map<String, int> boardCategoryRanks = const {};
  Map<String, int> boardCategoryPlayerCounts = const {};
  bool boardClosed = false;
  String leagueTier = '';
  String leagueTitle = '';
  Duration leagueRemaining = Duration.zero;
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
  bool adWatching = false;
  BilgiRewardLoad? rewardLoad;
  int _rewardEpoch = 0;
  bool _alive = true;
  bool _adLaunching = false;
  bool _shopBuying = false;
  List<String> newBadgeIds = const [];
  bool notifyOn = true;
  bool soundOn = true;
  String? localePreview;
  final Map<String, String> labels = {};
  /// True when today's free Günün Sorusu was finished (day key locked).
  bool dailyQuestionUsed = false;

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
        'league_rewards',
        'settings',
        'profile',
        'shop',
        'group',
        'room',
        'result',
        'history',
        'login',
        'achievements',
      }.contains(page);

  Future<void> retry() async {
    notice = null;
    await boot();
  }

  void _setBootPhase(double progress, String statusKey, String messageKey) {
    bootProgress = progress.clamp(0.0, 1.0);
    bootStatusKey = statusKey;
    bootMessageKey = messageKey;
    bootLabel = t(messageKey);
  }

  Future<void> boot() async {
    resolvingLocale = true;
    awaitingLocale = false;
    booting = false;
    bootProgress = 0;
    _setBootPhase(0.08, 'boot_status_starting', 'boot_msg_connecting');
    notifyListeners();

    config = await server.config();
    profile = await server.pullRemoteProfile();
    resolvingLocale = false;
    await _showLeagueReward();

    if (config.maintenance) {
      stack
        ..clear()
        ..add('maintenance');
      booting = false;
      awaitingLocale = false;
      notifyListeners();
      return;
    }

    if (profile?.localeChosen != true) {
      awaitingLocale = true;
      booting = false;
      stack
        ..clear()
        ..add('language');
      notifyListeners();
      return;
    }

    await _runOpeningLoad();
  }

  Future<void> _runOpeningLoad() async {
    awaitingLocale = false;
    booting = true;
    _setBootPhase(0.15, 'boot_status_starting', 'boot_msg_connecting');
    notifyListeners();

    profile ??= await server.profile();
    _setBootPhase(0.30, 'boot_status_connected', 'boot_msg_verifying');
    notifyListeners();

    _setBootPhase(0.50, 'boot_status_verified', 'boot_msg_categories');
    notifyListeners();
    await loadLabels();

    _setBootPhase(0.70, 'boot_status_categories', 'boot_msg_counts');
    notifyListeners();
    await loadCategoryCounts();

    _setBootPhase(0.85, 'boot_status_preparing', 'boot_msg_preparing');
    notifyListeners();
    await refreshPool();

    _setBootPhase(1.0, 'boot_status_ready', 'boot_msg_enjoy');
    stack
      ..clear()
      ..add(
        bilgiBootPage(
          maintenance: config.maintenance,
          localeChosen: profile?.localeChosen == true,
          seenIntro: await server.seenIntro(),
        ),
      );
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (booting) {
      booting = false;
      notifyListeners();
    }
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
          ..add('profile');
      }
      notifyListeners();
      await loadCategoryCounts();
      return;
    }
    await _runOpeningLoad();
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
    if (id == 'league' || id == 'profile') unawaited(loadBoard());
    if (id == 'history' || id == 'profile') unawaited(loadHistory());
    if (id == 'event') unawaited(loadEvents());
    if (id == 'setup' || id == 'detail') unawaited(refreshPool());
    if (id == 'categories') unawaited(loadCategoryCounts());
    if (id == 'daily') unawaited(refreshDailyQuestionStatus());
    if (id == 'language') localePreview ??= profile?.locale ?? 'tr';
  }

  Future<void> refreshDailyQuestionStatus() async {
    dailyQuestionUsed = await server.dailyQuestionUsedToday();
    notifyListeners();
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
    return value == 'kolay' || value == 'orta' || value == 'zor' || value == 'efsane' || value == bilgiMixDifficulty;
  }

  void _preparePlaySettings() {
    if (!_playDifficulty(difficulty)) difficulty = 'kolay';
    final questions = bilgiModeById(modeId).questions;
    if (questions == 10 || questions == 20 || questions == 50) {
      questionChoice = questions;
    }
  }

  Future<void> _reloadProfile() async {
    profile = await server.pullRemoteProfile();
    await _showLeagueReward();
    notifyListeners();
  }

  Future<void> _showLeagueReward() async {
    final user = profile;
    if (user == null || user.leagueRewardText.isEmpty) return;
    notice = user.leagueRewardText;
    profile = await server.clearLeagueReward();
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
      categories = _publishedForLocale(playable);
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
    categories = _publishedForLocale(playable);
    notifyListeners();
  }

  List<BilgiCategory> _publishedForLocale(List<BilgiCategory> playable) =>
      [for (final category in playable) if (category.publishesIn(locale)) category];

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

  bool joinedCategoryLeague(String id) {
    final user = profile;
    if (user == null) return false;
    return bilgiPlayedCategory(user, id);
  }

  Future<void> playCategoryLeague(String id) async {
    if (id.isEmpty || id == tumuKarmaId || id == 'karma') return;
    categoryId = id;
    subName = '';
    final mode = bilgiModeById(modeId);
    final solo = mode.group == 'solo' || mode.id == 'lig' ? mode.id : 'lig';
    await start(forcedMode: solo);
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

  void _setLoadPhase(double progress, String statusKey) {
    loadProgress = progress.clamp(0.0, 1.0);
    loadStatusKey = statusKey;
  }

  void _clearRoundLoading() {
    busy = false;
    roundLoading = false;
    loadProgress = 0;
  }

  /// Cancel an in-flight [start] draw and leave setup via the normal back path.
  void cancelRoundLoad() {
    if (!roundLoading) return;
    _startEpoch++;
    _clearRoundLoading();
    notice = null;
    back();
  }

  Future<void> start({bool adCleared = false, int? count, String? forcedMode}) async {
    if (busy) return;
    final epoch = ++_startEpoch;
    busy = true;
    roundLoading = true;
    notice = null;
    loadTipKey = _loadTips[epoch % _loadTips.length];
    _setLoadPhase(0.12, 'load_status_sending');
    notifyListeners();

    _setLoadPhase(0.28, 'load_status_sending');
    notifyListeners();
    final result = await server.startRound(
      modeId: forcedMode ?? modeId,
      categoryId: categoryId,
      subcategory: subName,
      difficulty: difficulty,
      questionCount: count ?? questionChoice,
      adCleared: adCleared,
    );
    if (epoch != _startEpoch) return;

    _setLoadPhase(0.72, 'load_status_received');
    notifyListeners();

    profile = result.profile ?? profile;
    if (result.message == 'ad') {
      _clearRoundLoading();
      _openPreGameAd();
      return;
    }
    if (result.message != null) {
      _clearRoundLoading();
      notice = result.message == dailyQuestionQuotaMessage
          ? t('daily_quota_ad')
          : result.message;
      if (result.message!.contains('Canın')) open('nolives');
      if (result.message == dailyQuestionQuotaMessage) {
        dailyQuestionUsed = true;
      }
      notifyListeners();
      return;
    }
    final started = result.round;
    if (started == null) {
      _clearRoundLoading();
      notice = '⚠️ Bir şeyler ters gitti. Tekrar dene.';
      notifyListeners();
      return;
    }
    if (started.waiting) {
      _clearRoundLoading();
      round = started;
      open('duel');
      return;
    }

    _setLoadPhase(1.0, 'load_status_ready');
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (epoch != _startEpoch) return;
    _clearRoundLoading();
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

  void _openPreGameAd() {
    if (kIsWeb) {
      unawaited(_startAfterUnplayableWebAd());
      return;
    }
    if (_adLaunching) return;
    _adLaunching = true;
    unawaited(_playPreGameAd());
  }

  /// Web cannot play the pre-game ad, so the round starts without it.
  Future<void> _startAfterUnplayableWebAd() async {
    if (stack.isNotEmpty && stack.last == 'ad') stack.removeLast();
    _adLaunching = false;
    final pending = _pendingShared;
    if (pending != null) {
      _pendingShared = null;
      await _startShared(pending, adCleared: true);
      return;
    }
    await start(adCleared: true);
  }

  /// Web and other surfaces with no playable ad leave the countdown. No reward is granted.
  void skipUnplayableAd() {
    if (!kIsWeb) return;
    _leaveUnplayableAd();
  }

  void _leaveUnplayableAd() {
    _pendingShared = null;
    _adLaunching = false;
    notice = _adFailNotice;
    if (stack.isNotEmpty && stack.last == 'ad') stack.removeLast();
    notifyListeners();
  }

  Future<void> _playPreGameAd() async {
    final user = profile;
    var played = false;
    try {
      played = user == null ? false : await _playAd();
    } catch (_) {
      played = false;
    } finally {
      _adLaunching = false;
    }
    if (!_alive) return;
    if (!played) {
      _leaveUnplayableAd();
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
  }

  Future<bool> _playAd() async {
    final user = profile;
    if (user == null || user.id.isEmpty) return false;
    final service = ads;
    if (service == null) return false;
    try {
      return await service.showRewarded(user.id);
    } catch (_) {
      return false;
    }
  }

  void _adFailed({bool connection = false}) {
    notice = kIsWeb || connection ? _adFailNotice : _adRetryNotice;
    notifyListeners();
  }

  Future<void> _showRewardLoad({
    required String icon,
    required String Function() amount,
    required String Function() caption,
    required Future<bool> Function() grant,
    bool leaveRewardPage = false,
  }) async {
    final epoch = ++_rewardEpoch;
    rewardLoad = BilgiRewardLoad(icon: icon, amount: amount(), caption: t('ad_reward_loading'), loading: true);
    notifyListeners();
    final pending = grant();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final ok = await pending;
    if (!_alive || epoch != _rewardEpoch) return;
    if (!ok) {
      rewardLoad = null;
      notifyListeners();
      return;
    }
    rewardLoad = BilgiRewardLoad(icon: icon, amount: amount(), caption: caption(), loading: false);
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!_alive || epoch != _rewardEpoch) return;
    rewardLoad = null;
    if (leaveRewardPage && page == 'reward') {
      back();
      return;
    }
    notifyListeners();
  }

  void dismissRewardLoad() {
    _rewardEpoch++;
    rewardLoad = null;
    if (_alive) notifyListeners();
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
    if (live.modeId == 'gunluk' && (round?.finished ?? false)) {
      dailyQuestionUsed = true;
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
      notice = null;
      notifyListeners();
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
    if (live.modeId == 'gunluk') dailyQuestionUsed = true;
    newBadgeIds = (profile?.badges ?? const []).where((id) => !beforeBadges.contains(id)).toList();
    revealing = false;
    stack
      ..clear()
      ..add('result');
    notifyListeners();
  }

  Future<void> doubleResultScore() async {
    if (scoreDoubled || adWatching) return;
    final user = profile;
    final live = round;
    if (user == null || live == null) return;
    if (user.adDoubleToday >= config.rewardedDoubleLimit) {
      notice = '📅 Bugünkü hakkını kullandın.';
      notifyListeners();
      return;
    }
    final extra = live.score;
    if (extra <= 0) return;
    adWatching = true;
    notifyListeners();
    final played = await _playAd();
    adWatching = false;
    if (!_alive) return;
    if (!played) {
      _adFailed(connection: true);
      return;
    }
    await _showRewardLoad(
      icon: '⭐',
      amount: () => '$extra',
      caption: () => '+$extra',
      grant: () async {
        final result = await server.doubleFinishedScore(live.id);
        profile = result.profile ?? profile;
        if (result.round != null) round = result.round;
        if (result.message != null || result.round == null) {
          notice = result.message ?? _adRetryNotice;
          return false;
        }
        scoreDoubled = true;
        notice = null;
        return true;
      },
    );
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
    if (boardScope != 'general' && boardScope != 'category') {
      boardScope = 'general';
      boardCategoryId = null;
    }
    final selected = boardCategoryId;
    if (boardScope == 'category' &&
        selected != null &&
        (selected == tumuKarmaId || !bilgiCategoryListed(selected, categoryCounts[selected]))) {
      boardCategoryId = null;
    }
    final scope = boardScope == 'general' ? 'global' : boardScope;
    final categoryId = boardCategoryId;
    final weekly = boardWeekly;
    profile = await server.pullRemoteProfile();
    final remote = await BilgiLeagueApi.load(
      scope: scope,
      categoryId: categoryId,
      categoryWeekly: weekly,
      me: profile?.id,
    );
    final local = await server.leagueSnapshot(
      scope: scope,
      categoryId: categoryId,
      categoryWeekly: weekly,
    );
    final snap = remote ?? local;
    final ranks = <String, int>{
      for (final entry in snap.categoryRanks.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    boardRows = snap.rows;
    boardSeed = snap.seed;
    boardRealCount = snap.realCount;
    boardCategoryIds = bilgiLeagueCatalog(categoryCounts);
    boardCategoryRanks = ranks;
    boardCategoryPlayerCounts = remote != null ? remote.categoryPlayerCounts : local.categoryPlayerCounts;
    boardClosed = snap.closed;
    leagueTier = snap.tier.isNotEmpty ? snap.tier : (profile == null ? '' : bilgiTier(bilgiVisibleWeekScore(profile!, DateTime.now())));
    leagueTitle = snap.title;
    leagueRemaining = snap.remaining;
    await _showLeagueReward();
    notifyListeners();
  }

  Future<bool> doubleDailyReward() async {
    if (!rewardReady() || adWatching) return false;
    final user = profile;
    if (user == null) return false;
    final parts = _doubledReward();
    adWatching = true;
    notifyListeners();
    final played = await _playAd();
    adWatching = false;
    if (!_alive) return false;
    if (!played) {
      _adFailed(connection: true);
      return false;
    }
    var claimed = false;
    await _showRewardLoad(
      icon: parts.icon,
      amount: () => parts.amount,
      caption: () => '${parts.amount} ${parts.unit}',
      leaveRewardPage: true,
      grant: () async {
        claimed = await claimDaily(doubled: true);
        return claimed;
      },
    );
    return claimed;
  }

  ({String icon, String amount, String unit}) _doubledReward() {
    final index = rewardIndex();
    final gold = dayRewardAmount(config.dailyGold, index) * 2;
    final diamond = dayRewardAmount(config.dailyDiamond, index) * 2;
    final joker = dayRewardAmount(config.dailyJoker, index) * 2;
    if (diamond > 0) return (icon: '💎', amount: '$diamond', unit: t('diamond'));
    if (joker > 0) return (icon: '🎯', amount: '$joker', unit: t('joker'));
    return (icon: '🪙', amount: '$gold', unit: t('gold'));
  }

  Future<void> buyJokerSet() async {
    final prices = config.jokerPrices;
    final cost = (prices['half'] ?? 50) + (prices['double'] ?? 75) + (prices['time'] ?? 60);
    if ((profile?.gold ?? 0) < cost) {
      requestGoldHelp();
      return;
    }
    await buyJoker('half');
    await buyJoker('double');
    await buyJoker('time');
  }

  Future<bool> claimDaily({bool doubled = false}) async {
    final result = await server.claimDaily(doubled: doubled);
    profile = result.profile ?? profile;
    notice = result.message;
    if (!result.ok && page != 'reward') open('reward');
    notifyListeners();
    return result.ok;
  }

  Future<void> buyJoker(String type) async {
    final result = await server.buyJoker(type);
    _applyGoldSpend(result);
  }

  bool get plusActive {
    final user = profile;
    if (user == null) return false;
    return bilgiPlusActive(user, DateTime.now());
  }

  /// Starts a Play purchase. Web and desktop only show [bilgiPlayAndroidNotice].
  Future<void> buyPlay(BilgiPlaySku sku) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      notice = bilgiPlayAndroidNotice;
      notifyListeners();
      return;
    }
    if (_shopBuying) return;
    _shopBuying = true;
    notice = null;
    notifyListeners();
    try {
      final billing = sl<BillingGateway>();
      final purchase = await billing.buyOffer(
        productId: sku.productId,
        basePlanId: sku.basePlanId,
        consumable: sku.consumable,
      );
      if (purchase.productId != sku.productId || purchase.purchaseToken.trim().isEmpty) {
        notice = UserMessages.billingUnavailable;
        return;
      }
      final result = await server.grantPlayPurchase(
        productId: sku.productId,
        basePlanId: sku.basePlanId,
        purchaseToken: purchase.purchaseToken,
        orderId: purchase.orderId,
      );
      if (!result.ok || result.profile == null) {
        notice = result.message ?? UserMessages.billingUnavailable;
        return;
      }
      profile = result.profile;
      final acknowledge = purchase.acknowledge;
      if (acknowledge != null) await acknowledge();
      notice = sku.gold > 0 ? '${sku.gold} altın eklendi.' : 'Luno Plus açıldı.';
    } on AppFailure catch (error) {
      notice = error.message;
    } catch (_) {
      notice = UserMessages.billingUnavailable;
    } finally {
      _shopBuying = false;
      notifyListeners();
    }
  }

  void requestGoldHelp() {
    notice = null;
    goldHelpSerial++;
    notifyListeners();
  }

  /// Opens the shop on the gold packs. Does not change prices or product ids.
  void openShopGold() {
    pendingShopGold = true;
    if (page == 'shop') {
      notifyListeners();
      return;
    }
    open('shop');
  }

  void _applyGoldSpend(BilgiResult result, {bool closeNoLives = false}) {
    profile = result.profile ?? profile;
    if (bilgiNoticeIsGoldShort(result.message)) {
      requestGoldHelp();
      return;
    }
    notice = result.message;
    if (closeNoLives && result.ok && page == 'nolives') back();
    notifyListeners();
  }

  Future<void> refill() async {
    final user = profile;
    if (user != null && user.gold < config.lifePrice) {
      requestGoldHelp();
      return;
    }
    final result = await server.refillLives();
    _applyGoldSpend(result, closeNoLives: true);
  }

  Future<void> watchFor(String kind) async {
    if (adWatching) return;
    final user = profile;
    if (user == null) return;
    final blocked = _adLimitMessage(kind);
    if (blocked != null) {
      notice = blocked;
      notifyListeners();
      return;
    }
    final goldBefore = user.gold;
    final icon = switch (kind) {
      'joker' => '🎯',
      'life' => '❤️',
      _ => '🪙',
    };
    var amount = switch (kind) {
      'joker' => '1',
      'life' => '1',
      _ => '${config.rewardedGold}',
    };
    var caption = switch (kind) {
      'joker' => 'Yarım joker',
      'life' => '+1 can',
      _ => t('ad_loaded').replaceAll('{n}', amount),
    };
    adWatching = true;
    notifyListeners();
    final played = await _playAd();
    adWatching = false;
    if (!_alive) return;
    if (!played) {
      _adFailed();
      return;
    }
    await _showRewardLoad(
      icon: icon,
      amount: () => amount,
      caption: () => caption,
      grant: () async {
        final result = await server.grantAd(kind: kind);
        profile = result.profile ?? profile;
        notice = result.message;
        if (result.message != null) return false;
        if (kind == 'gold') {
          final added = (profile?.gold ?? goldBefore) - goldBefore;
          if (added <= 0) return false;
          amount = '$added';
          caption = t('ad_loaded').replaceAll('{n}', amount);
          notice = caption;
        }
        return true;
      },
    );
  }

  String? _adLimitMessage(String kind) {
    final user = profile;
    if (user == null) return _adRetryNotice;
    final hit = switch (kind) {
      'gold' => user.adGoldToday >= config.rewardedGoldLimit,
      'joker' => user.adJokerToday >= config.rewardedJokerLimit,
      'life' => user.adLifeToday >= config.rewardedLifeLimit,
      _ => false,
    };
    if (!hit) return null;
    return '📅 Bugünkü hakkını kullandın.';
  }

  /// Watch the Bilgi rewarded interstitial, then start one gunluk round.
  /// Completing the ad only grants a start pass — not gold, joker, or life.
  Future<void> startGunlukWithAd() async {
    if (busy || adWatching) return;
    final user = profile;
    if (user == null) return;
    adWatching = true;
    notifyListeners();
    final played = await _playAd();
    adWatching = false;
    if (!_alive) return;
    if (!played) {
      // Stay on daily with the same quota message; do not start.
      notifyListeners();
      return;
    }
    await server.grantDailyQuestionAdPass();
    modeId = 'gunluk';
    categoryId = tumuKarmaId;
    difficulty = 'hepsi';
    await start(forcedMode: 'gunluk', count: 1);
  }

  Future<void> findDuel() async {
    busy = true;
    notifyListeners();
    final result = await server.findDuel();
    busy = false;
    profile = result.profile ?? profile;
    round = result.round;
    if (result.message == 'ad') {
      _openPreGameAd();
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
      _openPreGameAd();
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
      final account = await sl<GoogleAuth>().signIn();
      final email = account?.email?.trim() ?? '';
      if (account == null || email.isEmpty) {
        notice = account == null ? null : '⚠️ Bir şeyler ters gitti. Tekrar dene.';
        notifyListeners();
        return;
      }
      final result = await server.loginSocial(
        email: email,
        username: account.displayName,
        googleId: account.id,
      );
      profile = result.profile ?? profile;
      notice = result.message;
      if (result.ok) tab('home');
      notifyListeners();
    } catch (_) {
      notice = '⚠️ Bir şeyler ters gitti. Tekrar dene.';
      notifyListeners();
    }
  }

  void loginApple() {
    notice = UserMessages.appleNotReady;
    notifyListeners();
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
    notice = result.message;
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
    _alive = false;
    _rewardEpoch++;
    _timer?.cancel();
    super.dispose();
  }
}
