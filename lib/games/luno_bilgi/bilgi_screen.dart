import 'dart:async' show Timer, unawaited;
import 'dart:math' as math;

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_avatars.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_contest.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_controller.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_l10n.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_language_page.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_opening_loader.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_profile_name.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_round_loading.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_shop.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';
import 'package:kelimelig/injection.dart';

/// Single-line A/B/C/D row on the quiz play screen.
const _quizOptionRowMinHeight = 52.0;

/// Space between two answer options on the quiz play screen.
const _quizOptionGap = 8.0;

/// Shared height for setup difficulty, question-count, and mode chips.
const _setupChoiceHeight = 40.0;

const _homeBg = Color(0xFF16082C);
const _homeCard = Color(0xFF3C1468);
const _homeGold = Color(0xFFFFC83D);
const _homeGoldText = Color(0xFFFFD76A);
const _platedDim = Color(0xFF2A0E48);
const _platedTray = Color(0xFF321055);
const _quizGreen = Color(0xFF16A34A);
const _quizRed = Color(0xFFDC2626);
const _quizBlue = Color(0xFF3B82F6);

class _SetupBranchPainter extends CustomPainter {
  const _SetupBranchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _homeGold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(1, 0)
      ..lineTo(1, size.height - 1)
      ..lineTo(size.width, size.height - 1);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BilgiScreen extends StatefulWidget {
  const BilgiScreen({super.key});

  @override
  State<BilgiScreen> createState() => _BilgiScreenState();
}

class _BilgiScreenState extends State<BilgiScreen> {
  late final BilgiController _game;
  final _categoryQuery = TextEditingController();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  bool _loginObscure = true;
  String? _jokerPrompt;
  int? _jokerPromptIndex;
  String? _jokerBurst;
  bool _rewardBurst = false;
  String _rewardBurstIcon = '🪙';
  String _leagueSort = bilgiLeagueSortAlpha;
  String? _linkedDisplayName;
  String? _profileNameKey;
  final _shopGoldKey = GlobalKey();
  bool _shopSpendBusy = false;
  BilgiRewardLoad? _shopExchange;
  int _goldHelpSeen = 0;
  bool _goldDialogOpen = false;
  bool _goldHelpQueued = false;
  bool _duelJoin = false;
  bool _roomJoin = false;
  bool _duelForm = false;
  bool _roomForm = false;
  String _inviteCategory = tumuKarmaId;
  String _inviteSub = '';
  String _inviteDifficulty = 'hepsi';
  int _inviteCount = 10;
  int _inviteSeconds = 10;

  @override
  void initState() {
    super.initState();
    _game = BilgiController(
      sl<LunoBilgiServer>(),
      ads: sl.isRegistered<AdService>() ? sl<AdService>() : null,
    );
    _game.addListener(_onChange);
    _game.boot();
  }

  void _onChange() {
    final index = _game.round?.index;
    if (_jokerPromptIndex != null && index != _jokerPromptIndex) {
      _jokerPrompt = null;
      _jokerPromptIndex = null;
    }
    if (bilgiNoticeIsGoldShort(_game.notice)) {
      _game.notice = null;
      _game.goldHelpSerial++;
    }
    final help = _game.goldHelpSerial;
    final focusGold = _game.pendingShopGold && _game.page == 'shop';
    if (_game.page != 'duel') {
      _duelJoin = false;
      _duelForm = false;
    }
    if (_game.page != 'room') {
      _roomJoin = false;
      _roomForm = false;
    }
    _refreshProfileName();
    if (mounted) setState(() {});
    if (help != _goldHelpSeen) {
      _goldHelpSeen = help;
      if (!_goldHelpQueued && !_goldDialogOpen) {
        _goldHelpQueued = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _goldHelpQueued = false;
          if (mounted) unawaited(_showGoldHelp());
        });
      }
    }
    if (focusGold) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollShopGold());
    }
  }

  void _refreshProfileName() {
    final user = _game.profile;
    if (user == null) return;
    final key = '${user.id}|${user.accountId}|${user.email}|${user.username}';
    if (_profileNameKey == key) return;
    _profileNameKey = key;
    final ticket = key;
    _game.server.accountDisplayNameFor(user).then((name) {
      if (!mounted || _profileNameKey != ticket) return;
      setState(() => _linkedDisplayName = name);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _categoryQuery.dispose();
    _loginEmail.dispose();
    _loginPassword.dispose();
    _game.removeListener(_onChange);
    _game.dispose();
    super.dispose();
  }

  /// Active categories with at least [bilgiMinPublishedPerDifficulty] approved questions in every difficulty.
  List<BilgiCategory> get _listedCategories => [
        for (final category in _game.categories)
          if (!bilgiSpecialEventCategory(category) && bilgiCategoryListed(category.id, _game.difficultySlices)) category,
      ];

  @override
  Widget build(BuildContext context) {
    final user = _game.profile;
    final nunito = GoogleFonts.nunitoTextTheme(ThemeData(brightness: Brightness.dark).textTheme);
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _homeGold, width: 1.5),
    );
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: _homeBg,
        colorScheme: const ColorScheme.dark(
          primary: _homeGold,
          onPrimary: Color(0xFF3A2200),
          surface: _homeCard,
        ),
        textTheme: nunito.apply(bodyColor: Colors.white, displayColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A1048),
          labelStyle: GoogleFonts.nunito(color: _homeGoldText, fontWeight: FontWeight.w700),
          hintStyle: GoogleFonts.nunito(color: BilgiColors.muted),
          border: fieldBorder,
          enabledBorder: fieldBorder,
          focusedBorder: fieldBorder,
        ),
      ),
      child: Scaffold(
        backgroundColor: _homeBg,
        body: BilgiChrome(
          child: SafeArea(
            child: _openingOrApp(user),
          ),
        ),
      ),
    );
  }

  Widget _openingOrApp(BilgiProfile? user) {
    if (_game.resolvingLocale) {
      // Dark frame only — no spinner before language or opening loader.
      return const SizedBox.expand();
    }
    if (_game.awaitingLocale) {
      return _language();
    }
    if (_game.booting) {
      return BilgiOpeningLoader(
        progress: _game.bootProgress,
        status: _game.t(_game.bootStatusKey),
        message: _game.t(_game.bootMessageKey),
        gameName: _game.t('boot_brand'),
        slogan: _game.t('boot_slogan'),
        version: gameVersionCode,
      );
    }
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              _page(user),
              if (_game.roundLoading)
                Positioned.fill(child: _roundLoadingOverlay())
              else if (_game.busy)
                Positioned.fill(
                  child: ColoredBox(
                    color: const Color(0xE60F0E1A),
                    child: Center(child: BilgiBootProgress(label: _game.t('questions_loading'))),
                  ),
                ),
              if (_game.rewardLoad != null)
                Positioned.fill(
                  child: _AdRewardOverlay(
                    icon: _game.rewardLoad!.icon,
                    amount: _game.rewardLoad!.amount,
                    caption: _game.rewardLoad!.caption,
                    loading: _game.rewardLoad!.loading,
                    closeLabel: _game.t('close'),
                    onClose: _game.dismissRewardLoad,
                  ),
                ),
            ],
          ),
        ),
        if (_game.showNav && !_game.busy)
          BilgiBottomNav(
            current: _navId(),
            onSelect: _game.tab,
            home: _game.t('home'),
            play: _game.t('play'),
            league: _game.t('league'),
            profile: _game.t('profile'),
            shop: _game.t('shop'),
          ),
      ],
    );
  }

  String _navId() {
    return switch (_game.page) {
      'categories' || 'detail' || 'setup' || 'room' => 'play',
      'achievements' => 'profile',
      'league_rewards' => 'league',
      _ => _game.page,
    };
  }

  Widget _page(BilgiProfile? user) {
    if (user == null && _game.page != 'maintenance' && _game.page != 'language') {
      return Center(child: BilgiBootProgress(label: _game.t('loading')));
    }
    final page = switch (_game.page) {
      'intro' => _intro(),
      'maintenance' => _maintenance(),
      'play' => _modes(),
      'categories' => _categories(),
      'detail' => _detail(),
      'setup' => _setup(),
      'game' => _gamePage(),
      'result' => _result(),
      'league' => _league(user!),
      'contest_board' => _contestBoard(user!),
      'league_rewards' => _leagueRewards(),
      'profile' => _profile(user!),
      'shop' => _shop(user!),
      'duel' => _duel(),
      'room' => _room(),
      'daily' => _daily(),
      'event' => _events(),
      'language' => _language(),
      'settings' => _settings(),
      'achievements' => _achievements(user!),
      'history' => _history(),
      'login' => _auth(register: false),
      'register' => _auth(register: true),
      'forgot' => _forgot(),
      'invite' => _invite(user!),
      'legal' => _legal(),
      'howto' => _howTo(),
      'error' => _error(),
      'reward' => _reward(),
      'ad' => _ad(),
      'joker' => _jokerShop(user!),
      'nolives' => _noLives(user!),
      _ => _home(user!),
    };
    if (_game.page == 'language' || _game.page == 'maintenance' || _game.page == 'game') return page;
    return ColoredBox(color: _homeBg, child: page);
  }

  Widget _home(BilgiProfile user) {
    final ready = _game.rewardReady();
    final reward = _game.rewardLabel(_game.rewardIndex());
    final solo = bilgiModes.where((mode) => mode.group == 'solo').toList();
    final multi = bilgiModes.where((mode) => mode.id == 'duello' || mode.id == 'oda').toList();
    final listed = _listedCategories;
    final popular = [for (final category in listed) if (category.popular) category];
    final dailyLine = ready
        ? (user.streak > 0 ? _fill('streak_line', {'n': '${user.streak}', 'reward': reward}) : reward)
        : _fill('reward_tomorrow', {'reward': reward});
    void openContest() {
      if (_game.contestPhase == 'done') {
        _game.openDailyBoard();
        return;
      }
      unawaited(_game.playDailyContest());
    }
    final contestHeading = _game.contestTitle.trim().isNotEmpty ? _game.contestTitle.trim() : _game.t('mode_yarisma');
    final showJoined = _game.contestJoined >= 29;
    final joinedLabel = _display(_fill('contest_joined', {'n': '${_game.contestJoined}'}));
    final notice = _game.notice;
    final payout = notice == null ? null : bilgiLeagueRewardNote(notice);
    return ColoredBox(
      color: _homeBg,
      child: Column(
      children: [
            _homeBrand(_game.t('game_name')),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    if (payout != null) _leaguePayoutCard(payout) else if (notice != null) _note(notice),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _homeCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _homeGold, width: 2),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _game.open('reward'),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFF8A3D),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text('🎁', style: TextStyle(fontSize: 20, height: 1)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _display(_game.t('reward_title')),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _homeGoldTitle(size: 13),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          dailyLine,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: _homeInter(size: 11, weight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _homePillButton(
                                    label: ready ? _game.t('claim') : '✓ ${_game.t('reward_claimed')}',
                                    onTap: () => _game.open('reward'),
                                    background: ready ? _homeGold : const Color(0xFF22C55E),
                                    foreground: ready ? const Color(0xFF3A2500) : Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
                          ),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: _homeGold, width: 3),
                          boxShadow: const [
                            BoxShadow(color: Color(0x663B82F6), blurRadius: 18, offset: Offset(0, 8)),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: openContest,
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      const Text('🏆', style: TextStyle(fontSize: 16, height: 1)),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          _display(contestHeading),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                          style: _homeGoldTitle(size: 15, height: 1.05),
                                        ),
                                      ),
                                      if (showJoined) ...[
                                        const SizedBox(width: 8),
                                        DecoratedBox(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [Color(0xFFFF6B86), Color(0xFFE11D48)],
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(color: Colors.white, width: 1.5),
                                            boxShadow: const [
                                              BoxShadow(color: Color(0x33000000), blurRadius: 0, offset: Offset(0, 2)),
                                            ],
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
                                            child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                                const Icon(Icons.people_alt_rounded, size: 14, color: Colors.white),
                                                const SizedBox(width: 4),
                                          Text(
                                                  joinedLabel,
                                                  maxLines: 1,
                                                  style: _homeInter(size: 11, weight: FontWeight.w900, height: 1),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const _ContestClock(),
                                  const SizedBox(height: 12),
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD08A12),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _homeGold,
                                          borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (_game.contestPhase != 'open' && _game.contestPhase != 'done') ...[
                                                const Icon(Icons.play_arrow_rounded, color: Color(0xFF3A2500), size: 22),
                                            const SizedBox(width: 4),
                                          ],
                                          Flexible(
                                            child: Text(
                                              switch (_game.contestPhase) {
                                                    'open' => _display(_game.t('contest_btn_open')),
                                                    'done' => _display(_game.t('contest_btn_done')),
                                                    _ => _display(_game.t('contest_btn_ready')),
                                              },
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                                  style: _homeInter(size: 16, weight: FontWeight.w900, color: const Color(0xFF3A2500)),
                                            ),
                                          ),
                                        ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    _sectionTitle(_game.t('quick_start'), _game.t('see_all'), () => _game.tab('play')),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: _twoColumn(
                        gap: 12,
                        runGap: 10,
                        [for (final mode in solo) _quickStartCard(mode, _modeLine(mode))],
                      ),
                    ),
                    _sectionTitle(_game.t('multiplayer'), '', null, icon: Icons.groups_rounded),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: _twoColumn(
                        gap: 12,
                        runGap: 10,
                        [
                          for (final mode in multi)
                            _quickStartCard(mode, _game.t('mode_blurb_${mode.id}'), maxLines: 2),
                        ],
                      ),
                    ),
                    if (popular.isNotEmpty) ...[
                      _sectionTitle(
                        _game.t('popular'),
                        _game.t('see_all'),
                        () => _game.open('categories'),
                      ),
                      SizedBox(
                        height: 112,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                          itemCount: popular.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final category = popular[index];
                            return Align(
                              alignment: Alignment.topCenter,
                              child: SizedBox(
                              width: 96,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: _homeCard,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(color: _homeGold, width: 2),
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  borderRadius: BorderRadius.circular(18),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => _game.selectCategory(category.id),
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: 44,
                                            height: 44,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: _homeGold,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(category.emoji, style: const TextStyle(fontSize: 22, height: 1)),
                                          ),
                                          const SizedBox(height: 8),
                                          SizedBox(
                                            width: double.infinity,
                                            height: 11 * 1.15 * 2,
                                            child: Text(
                                              _display(_game.categoryLabel(category.id, category.name)),
                                              maxLines: 2,
                                              textAlign: TextAlign.center,
                                              style: _homeInter(
                                                size: 11,
                                                weight: FontWeight.w800,
                                                color: Colors.white,
                                                height: 1.15,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, popular.isNotEmpty ? 12 : 20, 20, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFC026D3)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0x66FFC83D)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _game.open('categories'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.grid_view_rounded, size: 16, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _display(_fill('see_categories', {'n': '${listed.length}'})),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _homeInter(size: 14, weight: FontWeight.w900),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C7F86),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _homeGold, width: 2),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _homeGold,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        _display(_game.t('weekly')),
                                        style: _homeInter(size: 10, weight: FontWeight.w800, color: const Color(0xFF3A2500)),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      '🏆 ${_game.t('league_started')}',
                                      style: _homeInter(size: 16, weight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      _game.t('league_prize'),
                                      style: _homeInter(
                                        size: 11,
                                        weight: FontWeight.w500,
                                        color: const Color.fromRGBO(255, 255, 255, 0.95),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _homePillButton(
                                label: _game.t('join'),
                                onTap: () => _game.tab('league'),
                                background: _homeGold,
                                foreground: const Color(0xFF3A2500),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _adBanner(
                      showNoticeAbove: false,
                      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    ),
                  ],
                ),
              ),
            ),
          ],
      ),
    );
  }

  TextStyle _homeInter({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = Colors.white,
    double? height,
  }) {
    return GoogleFonts.nunito(fontSize: size, fontWeight: weight, color: color, height: height);
  }

  /// Gold display face. Nunito covers Turkish letters (ğüşıöç).
  TextStyle _homeGoldTitle({double size = 15, double height = 1.05}) {
    return _homeInter(size: size, weight: FontWeight.w900, color: _homeGoldText, height: height).copyWith(
      shadows: const [Shadow(color: Color(0xFF8A4B00), offset: Offset(0, 2), blurRadius: 0)],
    );
  }

  String _display(String value) {
    if (_game.locale != 'tr') return value;
    return value.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
  }

  Widget _homeBrand(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Row(
        children: [
          const _BilgiLogo(size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                style: _homeGoldTitle(size: 20, height: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pageHeader(String title, {VoidCallback? onBack}) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Color.fromRGBO(11, 14, 20, 0.45),
            border: Border(bottom: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.08))),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(onBack == null ? 20 : 8, 16, 20, 16),
            child: Row(
              children: [
                if (onBack != null)
                  IconButton(
                    onPressed: onBack,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                  ),
                if (onBack != null) const SizedBox(width: 4),
                _BilgiLogo(size: 44, semanticLabel: title),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: BilgiHeaderTitle(title, align: TextAlign.left),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _homePillButton({
    required String label,
    required VoidCallback onTap,
    required Color background,
    required Color foreground,
    required EdgeInsets padding,
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w700,
    BoxShadow? shadow,
    int? maxLines,
    TextAlign textAlign = TextAlign.start,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(50),
        boxShadow: shadow == null ? null : [shadow],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(50),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: Text(
              label,
              maxLines: maxLines,
              softWrap: maxLines == 1 ? false : null,
              overflow: maxLines == null ? null : TextOverflow.ellipsis,
              textAlign: textAlign,
              style: _homeInter(size: fontSize, weight: fontWeight, color: foreground),
            ),
          ),
        ),
      ),
    );
  }

  String _fill(String key, Map<String, String> values) {
    var text = _game.t(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }

  Widget _quickStartCard(BilgiMode mode, String line, {int maxLines = 1}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _game.selectMode(mode.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _quickStartMark(mode.id),
                    const Spacer(),
                    const Icon(Icons.north_east_rounded, size: 16, color: _homeGold),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _display(_game.t('mode_${mode.id}')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _homeInter(size: 14, weight: FontWeight.w900, height: 1.15),
                ),
                const SizedBox(height: 2),
                Text(
                  line,
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                  style: _homeInter(size: 11, weight: FontWeight.w700, height: 1.15, color: const Color(0xFFD4C4E8)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickStartMark(String id) {
    final (color, icon) = switch (id) {
      'hizli' => (const Color(0xFF22C55E), Icons.bolt_rounded),
      'klasik' => (const Color(0xFFA78BFA), Icons.psychology_alt_rounded),
      'maraton' => (const Color(0xFFFB7185), Icons.near_me_rounded),
      'sakin' => (const Color(0xFF38BDF8), Icons.all_inclusive_rounded),
      'duello' => (const Color(0xFFFF5C93), Icons.sports_mma),
      'oda' => (const Color(0xFFF59E0B), Icons.meeting_room_rounded),
      _ => (BilgiColors.primaryLight, Icons.play_arrow_rounded),
    };
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  String _modeLine(BilgiMode mode) {
    final count = _fill('q_count', {'n': '${mode.questions}'});
    if (mode.totalSeconds > 0) return '$count • ${_fill('minutes', {'n': '${mode.totalSeconds ~/ 60}'})}';
    if (mode.seconds == 0) return '$count • ${_game.t('untimed')}';
    return '$count • ${_fill('seconds', {'n': '${mode.seconds}'})}';
  }

  LinearGradient _quickStartGradient(String id) {
    const begin = Alignment.topLeft;
    const end = Alignment.bottomRight;
    return switch (id) {
      'hizli' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFF134E4A), Color(0xFF0F766E)]),
      'klasik' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)]),
      'maraton' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFF831843), Color(0xFF9D174D)]),
      'sakin' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFF78350F), Color(0xFF92400E)]),
      _ => const LinearGradient(begin: begin, end: end, colors: [BilgiColors.card, BilgiColors.card]),
    };
  }

  List<_BalanceStat> _balanceItems(BilgiProfile user, {bool shop = false}) {
    final jokers = user.jokers.values.fold<int>(0, (sum, count) => sum + count);
    final gold = _BalanceStat('🪙', _grouped(user.gold), _game.t('bal_gold'));
    final diamond = _BalanceStat('💎', _grouped(user.diamond), _game.t('bal_diamond'));
    final lives = _BalanceStat('❤️', _grouped(user.lives), _game.t('bal_lives'));
    final joker = _BalanceStat('🃏', _grouped(jokers), _game.t('bal_joker'));
    if (shop) return [lives, gold, joker, diamond];
    return [gold, diamond, lives, joker];
  }

  String _grouped(int value) {
    final text = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) out.write('.');
      out.write(text[i]);
    }
    return out.toString();
  }

  Widget _sectionTitle(String title, String action, VoidCallback? onTap, {Color accent = _homeGold, IconData icon = Icons.flash_on_rounded}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(_display(title), maxLines: 1, overflow: TextOverflow.ellipsis, style: _homeGoldTitle(size: 15)),
          ),
          if (onTap != null)
            InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Text(_display(action), style: _homeInter(size: 12, weight: FontWeight.w800, color: _homeGoldText)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modes() {
    final solo = [for (final mode in bilgiModes) if (mode.group == 'solo') mode];
    final multi = [for (final mode in bilgiModes) if (mode.group == 'multi') mode];
    final special = [for (final mode in bilgiModes) if (mode.group == 'special') mode];
    final categoryCount = _listedCategories.length;
    return Column(
      children: [
        _pageHeader(_game.t('page_play')),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (_game.notice != null) _note(_game.notice!),
                _playHeading(_game.t('play_solo')),
                for (final mode in solo) _modeCard(mode),
                _playHeading(_game.t('play_multi')),
                for (final mode in multi) _modeCard(mode),
                _playHeading(_game.t('play_special')),
                for (final mode in special) _modeCard(mode),
                _playRow(
                  title: _game.t('mode_pick'),
                  subtitle: _fill('mode_blurb_pick', {'n': '$categoryCount'}),
                  onTap: () {
                    _game.modeId = 'klasik';
                    _game.open('categories');
                  },
                  icon: const _CategoryStackIcon(),
                ),
                _adBanner(showNoticeAbove: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _playHeading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Text(
        _display(text),
        style: _homeInter(size: 13, weight: FontWeight.w800, color: _homeGold, height: 1.1).copyWith(letterSpacing: 1.2),
      ),
    );
  }

  Widget _modeCard(BilgiMode mode) {
    final badge = switch (mode.id) {
      'hizli' => _game.t('badge_popular'),
      'gunluk' => _game.t('badge_daily'),
      _ => null,
    };
    final badgeColor = mode.id == 'hizli' ? const Color(0xFFFF5C93) : BilgiColors.secondary;
    return _playRow(
      title: _game.t('mode_${mode.id}'),
      subtitle: _game.t('mode_blurb_${mode.id}'),
      onTap: () => _game.selectMode(mode.id),
      icon: Text(mode.emoji, style: const TextStyle(fontSize: 20)),
      badge: badge,
      badgeColor: badge == null ? null : badgeColor,
    );
  }

  Widget _playRow({
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required Widget icon,
    String? badge,
    Color? badgeColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _homeCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _homeGold, width: 2),
        ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _platedDim,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: icon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _homeInter(size: 16, weight: FontWeight.w800, height: 1.15)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: _homeInter(size: 12, weight: FontWeight.w600, height: 1.2, color: const Color(0xFFD4C4E8))),
                    ],
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.3),
                    ),
                  ),
                ],
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categories() {
    final query = _categoryQuery.text.trim().toLowerCase();
    return Column(
      children: [
        _pageHeader(_game.t('page_categories'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _homeCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _homeGold, width: 2),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Text('🔍', style: TextStyle(fontSize: 16)),
                ),
                Expanded(
                  child: TextField(
                    controller: _categoryQuery,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _game.t('search_category'),
                      hintStyle: const TextStyle(color: BilgiColors.muted, fontSize: 14),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              for (final group in bilgiGroups)
                if (_listedCategories.where((category) => category.group == group && _matchesCategory(category, query)).toList() case final rows when rows.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Text(
                      _display(_groupLabel(group)),
                      style: _homeInter(size: 13, weight: FontWeight.w800, color: _homeGold, height: 1.1).copyWith(letterSpacing: 1.2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _twoColumn([for (final category in rows) _categoryCard(category)]),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  bool _matchesCategory(BilgiCategory category, String query) {
    if (query.isEmpty) return true;
    final name = _game.categoryLabel(category.id, category.name);
    final group = _game.groupLabel(category.group);
    return name.toLowerCase().contains(query) ||
        category.name.toLowerCase().contains(query) ||
        group.toLowerCase().contains(query) ||
        category.group.toLowerCase().contains(query);
  }

  String _groupLabel(String group) {
    final named = _game.groupLabel(group);
    return named.replaceFirst(RegExp(r'^[A-Za-z]\.\s+'), '');
  }

  Widget _twoColumn(List<Widget> items, {double gap = 12, double runGap = 12, int columns = 2}) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i += columns)
          Padding(
            padding: EdgeInsets.only(bottom: i + columns < items.length ? runGap : 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var column = 0; column < columns; column++) ...[
                  if (column > 0) SizedBox(width: gap),
                  Expanded(child: i + column < items.length ? items[i + column] : const SizedBox.shrink()),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _categoryCard(BilgiCategory category) {
    final karma = category.id == 'karma';
    final count = _game.categoryCounts[category.id];
    final line = karma ? _game.t('all_mix') : (count == null ? '…' : _fill('q_count', {'n': '$count'}));
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _game.selectCategory(karma ? tumuKarmaId : category.id),
        borderRadius: BorderRadius.circular(bilgiRadius),
        child: Ink(
          decoration: BoxDecoration(
            color: _homeCard,
            borderRadius: BorderRadius.circular(bilgiRadius),
            border: Border.all(color: _homeGold, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Two-line slot: a one-line name keeps the same card height.
                      SizedBox(
                        width: double.infinity,
                        height: 13 * 1.15 * 2,
                        child: Text(
                          _game.categoryLabel(category.id, category.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, height: 1.15),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: BilgiColors.muted)),
                      if (!karma) ...[
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () => _game.playCategoryLeague(category.id),
                          child: Text(
                            _game.joinedCategoryLeague(category.id) ? _game.t('league_continue') : _game.t('league_join'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _homeInter(size: 10, weight: FontWeight.w800, color: _homeGoldText),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail() {
    final category = _game.categories.where((item) => item.id == _game.categoryId).firstOrNull ?? bilgiCategoryById(_game.categoryId);
    final tumu = _game.categoryId == tumuKarmaId || category == null;
    final name = tumu ? _game.t('all_mix') : _game.categoryLabel(category.id, category.name);
    final emoji = tumu ? '🃏' : category.emoji;
    final live = _game.categories.where((item) => item.id == _game.categoryId).firstOrNull;
    final allSubs = tumu ? const <String>[] : (live?.subs ?? category.subs);
    final subs = [
      for (final sub in allSubs)
        if (bilgiSubListed(_game.categoryId, sub, _game.difficultySlices)) sub,
    ];
    final known = _game.categoryCounts[_game.categoryId];
    final heroCount = known != null
        ? _fill('q_count', {'n': '$known'})
        : (_game.poolCount > 0 ? _fill('q_count', {'n': '${_game.poolCount}'}) : '…');
    final heroSub = subs.isEmpty ? heroCount : '$heroCount • ${_fill('subs_n', {'n': '${subs.length}'})}';
    return Column(
      children: [
        _pageHeader(_game.t('page_detail'), onBack: _game.back),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (_game.notice != null) _note(_game.notice!),
              Container(
                margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: _homeCard,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _homeGold, width: 2),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 36)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(heroSub, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _sectionLabel(_game.t('subcategories')),
              _subRow(
                icon: '🎲',
                title: _game.t('mix_row'),
                subtitle: heroCount,
                onTap: () => _game.selectSub(''),
              ),
              for (final sub in subs)
                _subRow(
                  icon: bilgiSubIcon(sub, _subEmoji(sub, category?.emoji ?? '📌')),
                  title: _game.subLabel(_game.categoryId, sub),
                  subtitle: _fill('q_count', {'n': '${_game.subCounts['${_game.categoryId}|$sub'] ?? 0}'}),
                  onTap: () => _game.selectSub(sub),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _setup() {
    final highlight = _playDifficulty(_game.difficulty) ? _game.difficulty : 'kolay';
    final playable = _game.playableCount();
    final modeId = const {'hizli', 'klasik', 'sakin'}.contains(_game.modeId) ? _game.modeId : 'hizli';
    final diffs = [
      (const Color(0xFF3DDC97), _game.t('diff_easy'), 'kolay'),
      (const Color(0xFFFFB800), _game.t('diff_medium'), 'orta'),
      (const Color(0xFFFF4D6D), _game.t('diff_hard'), 'zor'),
      (const Color(0xFF8A879E), _game.t('diff_legend'), 'efsane'),
      (const Color(0xFFB388FF), _game.t('diff_mix'), bilgiMixDifficulty),
    ];
    final modes = [
      ('⚡', _game.t('mode_compact_hizli'), 'hizli'),
      ('🎯', _game.t('mode_compact_klasik'), 'klasik'),
      ('🧘', _game.t('mode_compact_sakin'), 'sakin'),
    ];
    final countMismatch = playable != _game.questionChoice ? _fill('q_count', {'n': '$playable'}) : null;
    return Column(
      children: [
        _pageHeader(_game.t('page_setup'), onBack: _game.back),
        Expanded(
          child: ColoredBox(
            color: _homeBg,
            child: Column(
              children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              if (_game.notice != null) _note(_game.notice!),
              _setupSelection(),
                      _setupHeading(_game.t('difficulty')),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: _setupTray(
                          plated: true,
                  child: Column(
                    children: [
                        Row(
                          children: [
                                  for (final item in diffs.take(4))
                              Expanded(
                                child: _setupDiffChip(
                                  color: item.$1,
                                  label: item.$2,
                                  active: highlight == item.$3,
                                        plated: true,
                                        compact: true,
                                  onTap: () => _game.selectDifficulty(item.$3),
                                ),
                              ),
                          ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Expanded(
                                    child: _setupDiffChip(
                                      color: diffs[4].$1,
                                      label: diffs[4].$2,
                                      active: highlight == diffs[4].$3,
                                      plated: true,
                                      compact: true,
                                      onTap: () => _game.selectDifficulty(diffs[4].$3),
                                    ),
                                  ),
                                ],
                              ),
                    ],
                  ),
                ),
              ),
                      _setupHeading(_game.t('question_count')),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _setupTray(
                          plated: true,
                  child: Row(
                    children: [
                      for (final count in const [10, 20, 50])
                        Expanded(
                          child: _setupCountSeg(
                            count: count,
                            active: _game.questionChoice == count,
                                    plated: true,
                            onTap: () => _game.selectQuestionChoice(count),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (countMismatch != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 20, 0),
                          child: Text(countMismatch, style: _homeInter(size: 11, weight: FontWeight.w700, color: _homeGoldText)),
                ),
                      _setupHeading(_game.t('mode_section')),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: _setupTray(
                          plated: true,
                  child: Row(
                    children: [
                      for (final item in modes)
                        Expanded(
                          child: _setupModeSeg(
                            emoji: item.$1,
                            label: item.$2,
                            active: modeId == item.$3,
                                    plated: true,
                            onTap: () => _game.selectPlayMode(item.$3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
                _startButton(
                  _game.busy ? null : _game.start,
                  label: _display(_game.t('start_game')),
                  fill: const Color(0xFF22C55E),
                  icon: Icons.play_arrow_rounded,
                  goldBorder: true,
                ),
        const SizedBox(height: 10),
        _adBanner(showNoticeAbove: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _setupHeading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Text(
        _display(text),
        style: _homeInter(size: 13, weight: FontWeight.w800, color: _homeGold, height: 1.1).copyWith(letterSpacing: 1.2),
      ),
    );
  }

  Widget _setupSelection() {
    final category = _game.categories.where((item) => item.id == _game.categoryId).firstOrNull ?? bilgiCategoryById(_game.categoryId);
    final tumu = _game.categoryId == tumuKarmaId || category == null;
    final catIcon = tumu ? '🃏' : category.emoji;
    final catName = tumu ? _game.t('all_mix') : _game.categoryLabel(category.id, category.name);
    final mixed = _game.subName.isEmpty;
    final subIcon = mixed ? '🎲' : bilgiSubIcon(_game.subName, _subEmoji(_game.subName, category?.emoji ?? '📌'));
    final subTitle = mixed ? _game.t('mixed_subs') : _game.subLabel(_game.categoryId, _game.subName);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _setupPick(catIcon, catName),
          const Padding(
            padding: EdgeInsets.only(left: 31),
            child: Align(
              alignment: Alignment.centerLeft,
              child: CustomPaint(size: Size(18, 14), painter: _SetupBranchPainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 31),
            child: _setupPick(subIcon, subTitle, nested: true),
          ),
        ],
      ),
    );
  }

  Widget _setupPick(String icon, String title, {bool nested = false}) {
    final box = nested ? 32.0 : 40.0;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(nested ? 22 : 28),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: nested ? 10 : 12, vertical: nested ? 4 : 6),
        child: Row(
          children: [
            Container(
              width: box,
              height: box,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFFF5C45), borderRadius: BorderRadius.circular(nested ? 11 : 14)),
              child: Text(icon, style: TextStyle(fontSize: nested ? 18 : 22, height: 1)),
            ),
            SizedBox(width: nested ? 10 : 12),
            Expanded(
              child: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _homeInter(size: nested ? 14 : 16, weight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _setupTray({required Widget child, bool plated = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: plated ? _platedTray : _homeCard,
        borderRadius: BorderRadius.circular(plated ? 22 : 18),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: Padding(
        padding: EdgeInsets.all(plated ? 6 : 4),
        child: child,
      ),
    );
  }

  BoxDecoration _platedChoice(bool active, {double radius = 18}) {
    return BoxDecoration(
      color: active ? _homeGold : _platedDim,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: _homeGold, width: active ? 2 : 1.5),
    );
  }

  Widget _setupDiffChip({
    required Color color,
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool plated = false,
    bool compact = false,
  }) {
    final radius = plated ? 18.0 : 20.0;
    final labelStyle = plated
        ? _homeInter(
            size: compact ? 11 : 12,
            weight: FontWeight.w800,
            color: active ? const Color(0xFF3A2200) : Colors.white,
          )
        : _homeInter(
            size: 12,
            weight: FontWeight.w700,
            color: active ? const Color(0xFF3A2200) : BilgiColors.muted,
          );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : (plated ? 3 : 2)),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: plated ? _setupChoiceHeight : null,
            alignment: plated ? Alignment.center : null,
            padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8, vertical: plated ? 0 : 8),
            decoration: plated
                ? _platedChoice(active, radius: radius)
                : BoxDecoration(
                    color: active ? _homeGold : const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: active ? _homeGold : const Color(0x66FFC83D)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                SizedBox(width: compact ? 3 : 5),
                Flexible(
                  child: compact
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(label, maxLines: 1, softWrap: false, style: labelStyle),
                        )
                      : Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                          style: labelStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _setupCountSeg({
    required int count,
    required bool active,
    required VoidCallback onTap,
    bool plated = false,
  }) {
    final radius = plated ? 16.0 : 12.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: plated ? 3 : 0),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
            height: plated ? _setupChoiceHeight : null,
            alignment: plated ? Alignment.center : null,
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: plated ? 0 : 8),
            decoration: plated
                ? _platedChoice(active, radius: radius)
                : BoxDecoration(
                    color: active ? _homeGold : const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: active ? _homeGold : const Color(0x66FFC83D)),
          ),
          child: Text(
            '$count',
            textAlign: TextAlign.center,
              style: plated
                  ? _homeInter(size: 16, weight: FontWeight.w800, color: Colors.white)
                  : TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : BilgiColors.muted,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _setupModeSeg({
    required String emoji,
    required String label,
    required bool active,
    required VoidCallback onTap,
    bool plated = false,
  }) {
    final radius = plated ? 16.0 : 12.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: plated ? 3 : 0),
      child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
            height: plated ? _setupChoiceHeight : null,
            alignment: plated ? Alignment.center : null,
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: plated ? 0 : 10),
            decoration: plated
                ? _platedChoice(active, radius: radius)
                : BoxDecoration(
                    color: active ? _homeGold : const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: active ? _homeGold : const Color(0x66FFC83D)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                    style: plated
                        ? _homeInter(size: 11, weight: FontWeight.w800, color: Colors.white)
                        : TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : BilgiColors.muted,
                  ),
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _gamePage() {
    final round = _game.round;
    final revealing = _game.revealing;
    final question = round?.current;
    if (round == null || (question == null && !revealing)) {
      return ColoredBox(
        color: _homeBg,
        child: Center(child: BilgiBootProgress(label: _game.t('questions_loading'))),
      );
    }
    final letters = ['A', 'B', 'C', 'D'];
    final source = revealing ? _game.revealQuestion : question;
    final reportQuestion = _game.revealQuestion ?? question;
    final shown = source?.shown(_game.locale);
    final quizNote = shown?.explanation.trim() ?? '';
    final hasQuizNote = revealing && quizNote.isNotEmpty;
    final text = shown?.text ?? (revealing ? _game.revealText : question!.text);
    final options = shown?.options ?? (revealing ? _game.revealOptions : question!.options);
    final difficultyKey = revealing ? _game.revealDifficulty : question!.difficulty;
    final difficulty = _difficultyLabel(difficultyKey);
    final number = revealing ? _game.revealNumber : round.index + 1;
    final total = round.questions.length;
    final timed = round.seconds > 0;
    final marathon = round.totalSeconds > 0 && !timed;
    final mode = bilgiModeById(round.modeId);
    final category = _game.categories.where((c) => c.id == round.categoryId).firstOrNull ??
        bilgiCategoryById(round.categoryId);
    final categoryName = round.categoryId == tumuKarmaId
        ? _game.t('all_mix')
        : _game.categoryLabel(round.categoryId, category?.name ?? round.categoryId);
    final modeName = _game.t('mode_${mode.id}');
    return ColoredBox(
      color: _homeBg,
      child: Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _quitButton(),
              Expanded(
                child: Column(
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$number',
                            style: _homeInter(size: 20, weight: FontWeight.w900, color: const Color(0xFF4ADE80), height: 1),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: _homeInter(size: 18, weight: FontWeight.w800, height: 1),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    if (category != null && bilgiSpecialEventCategory(category)) ...[
                      const SizedBox(height: 4),
                      const Center(child: _SpecialEventTag()),
                    ],
                    Text(
                      _game.t('hdr_question'),
                      style: _homeInter(size: 10, weight: FontWeight.w800, color: _homeGold, height: 1.1).copyWith(letterSpacing: 1.4),
                    ),
                    if (round.modeId == 'yarisma' && _game.contestTitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0x1A10B981),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _game.contestTitle.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: BilgiColors.secondary, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _homeCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _homeGold, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 16, height: 1)),
                    const SizedBox(width: 4),
                    Text(
                      _grouped(_game.profile?.diamond ?? 0),
                      style: _homeInter(size: 14, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _homeCard,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _homeGold, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: _roundWalletStrip(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$categoryName • $difficulty • $modeName',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: _homeInter(size: 12, weight: FontWeight.w700, color: const Color(0xFFD4C4E8)),
          ),
          const SizedBox(height: 6),
          _gameTimerChrome(timed: timed, marathon: marathon, round: round),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  const ColoredBox(color: Color(0xFF2A0E48), child: SizedBox.expand()),
                  FractionallySizedBox(
                    widthFactor: total == 0 ? 0 : (number / total).clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF22C55E), _homeGold]),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _playerStrip(round),
          if (round.paused) ...[
            const SizedBox(height: 8),
            _note(_fill('quiz_paused', {'n': '${_game.pauseLeft}'})),
          ],
          if (round.hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            _note(_hintLine(shown, round.hint)),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: _quizBoard(
              question: _QuizQuestionCard(
                key: ValueKey(reportQuestion?.id ?? text),
                text: text,
                reportHint: _game.t('report_hint'),
                reportSend: _game.t('report_send'),
                reportSending: _game.t('load_status_sending'),
                onReport: reportQuestion == null ? null : _game.reportReveal,
              ),
              options: [
                for (var i = 0; i < options.length; i++)
                  _quizOption(
                    letters[i],
                    options[i],
                    hidden: !revealing && round.hidden.contains(i),
                    correct: revealing && i == _game.revealCorrect,
                    wrong: revealing && i == _game.lastPick && i != _game.revealCorrect,
                    onTap: revealing || round.hidden.contains(i) || _game.picked ? null : () => _game.pick(i),
                  ),
              ],
            ),
          ),
          if (round.jokerMax > 0) ...[
            const SizedBox(height: _quizOptionGap),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (final item in const [
                  ('half', '✂️'),
                  ('double', '👥'),
                  ('time', '⏸️'),
                  ('change', '🔄'),
                  ('hint', '💡'),
                ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _jokerButton(
                    item.$2,
                    _game.t('joker_${item.$1}'),
                    _game.profile?.jokers[item.$1] ?? 0,
                    round.jokersUsed >= round.jokerMax || (item.$1 == 'hint' && (shown?.hint.trim().isEmpty ?? true))
                        ? null
                        : () => setState(() {
                              _jokerPrompt = item.$1;
                              _jokerPromptIndex = round.index;
                            }),
                    dim: item.$1 == 'hint' && (shown?.hint.trim().isEmpty ?? true),
                        ),
                      ),
                  ),
              ],
            ),
          ),
          ],
          if (_game.notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _game.notice!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 8),
          _quizContinue(
            label: _display(_game.t('continue_btn')),
            onTap: revealing ? _game.continueReveal : null,
            onInfo: hasQuizNote ? () => _openExplanation(quizNote) : null,
          ),
        ],
          ),
        ),
        if (_jokerPrompt != null)
          Positioned.fill(child: _jokerSpendNote(_jokerPrompt!)),
        if (_jokerBurst != null)
          Positioned.fill(
            child: _JokerSpendBurst(
              emoji: _jokerEmoji(_jokerBurst!),
              onDone: () {
                if (mounted) setState(() => _jokerBurst = null);
              },
            ),
          ),
      ],
      ),
    );
  }

  Widget _playerStrip(BilgiRound round) {
    final seats = round.standings;
    if (seats.length > 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: SizedBox(
          height: 28,
          child: seats.length == 2
              ? Row(
                  children: [
                    for (var i = 0; i < seats.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: _seatChip(seats[i], mine: seats[i]['id'] == round.userId, onTap: () => _openStandings(seats, round.userId)),
                      ),
                    ],
                  ],
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: seats.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => _seatChip(
                    seats[i],
                    mine: seats[i]['id'] == round.userId,
                    maxWidth: 168,
                    onTap: () => _openStandings(seats, round.userId),
                  ),
                ),
        ),
      );
    }
    if (round.opponentName.isEmpty) return const SizedBox.shrink();
    final score = round.opponentScore >= 0 ? ' • ${round.opponentScore}' : '';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${_game.t('rival')}: ${round.opponentName}$score',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(color: BilgiColors.muted, fontSize: 12),
      ),
    );
  }

  Widget _seatChip(Map<String, String> seat, {required bool mine, double? maxWidth, VoidCallback? onTap}) {
    return Material(
      color: _homeCard,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: maxWidth,
          height: 28,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: mine ? BilgiColors.secondary : _homeGold, width: 1.5),
          ),
          child: Text(
            '${seat['name']} • ${seat['score'] ?? '0'}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _homeInter(size: 12, weight: FontWeight.w700, color: mine ? BilgiColors.secondary : const Color(0xFFD4C4E8)),
          ),
        ),
      ),
    );
  }

  void _openStandings(List<Map<String, String>> seats, String userId) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _homeBg,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(_game.t('room_players'), textAlign: TextAlign.center, style: _homeGoldTitle(size: 16)),
                const SizedBox(height: 10),
                for (final seat in seats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _seatChip(seat, mine: seat['id'] == userId),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _quizBoard({required Widget question, required List<Widget> options}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context).scale(1);
        final optionHeight = (14 * 1.3 * 2 + 20) * math.max(1.0, scaler) + 4;
        final optionBlock = options.length * optionHeight + math.max(0, options.length - 1) * _quizOptionGap + 10;
        final optionList = <Widget>[
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: _quizOptionGap),
            options[i],
          ],
        ];
        if (constraints.maxHeight - optionBlock >= 64) {
          return ClipRect(
            child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    return SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: box.maxHeight),
                        child: Center(child: question),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
              ...optionList,
            ],
            ),
          );
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            question,
            const SizedBox(height: 10),
            ...optionList,
          ],
        );
      },
    );
  }

  Widget _quizContinue({required String label, required VoidCallback? onTap, VoidCallback? onInfo}) {
    final enabled = onTap != null;
    return Row(
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: enabled ? _homeGold : _homeCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: enabled ? _homeGold : const Color(0x99FFC83D), width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(18),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _quizOptionRowMinHeight),
                  child: Center(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: _homeInter(
                        size: 16,
                        weight: FontWeight.w900,
                        color: enabled ? const Color(0xFF3A2200) : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 40,
          height: _quizOptionRowMinHeight,
          child: onInfo == null
              ? null
              : IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: onInfo,
                  icon: const Icon(Icons.info_outline_rounded, color: _homeGold, size: 26),
                ),
        ),
      ],
    );
  }

  void _openExplanation(String body) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC0F0E1A),
      builder: (context) => _QuizPopup(
        child: Text(
          body,
          textAlign: TextAlign.center,
          style: _homeInter(size: 16, weight: FontWeight.w700, height: 1.4),
        ),
      ),
    );
  }

  Widget _result() {
    final round = _game.round;
    if (round == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _card(
            child: Text(
              '📊 ${_game.t('result_calculating')}',
              textAlign: TextAlign.center,
              style: _homeInter(size: 14, weight: FontWeight.w700, color: BilgiColors.muted),
            ),
          ),
        ),
      );
    }
    final mode = bilgiModeById(round.modeId);
    final won = round.correct > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (_game.notice != null) _note(_game.notice!),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
          decoration: BoxDecoration(
            color: _homeCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _homeGold, width: 2),
          ),
          child: Column(
            children: [
              Text(won ? '🎉' : '🎮', style: const TextStyle(fontSize: 20, height: 1)),
              const SizedBox(height: 2),
              Text(
                won ? _game.t('result_great') : _game.t('result_done'),
                style: _homeInter(size: 18, weight: FontWeight.w900, height: 1.05),
              ),
              const SizedBox(height: 2),
              Text(_game.t('mode_${mode.id}'), style: _homeInter(size: 13, weight: FontWeight.w700, color: const Color(0xE6FFFFFF), height: 1.1)),
              if (round.standings.length > 1) ...[
                const SizedBox(height: 4),
                for (final seat in round.standings)
                  Text(
                    '${seat['name']} • ${seat['score'] ?? '0'}',
                    style: const TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w700, height: 1.1),
                  ),
              ],
              const SizedBox(height: 4),
              Text(_grouped(round.score), style: _homeInter(size: 34, weight: FontWeight.w900, color: _homeGoldText, height: 1)),
              const SizedBox(height: 2),
              Text(
                _game.t('result_league_score'),
                textAlign: TextAlign.center,
                style: _homeInter(size: 13, weight: FontWeight.w800, color: const Color(0xCCFFFFFF), height: 1.1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _statBox(_game.t('correct'), '${round.correct}', BilgiColors.secondary)),
            const SizedBox(width: 10),
            Expanded(child: _statBox(_game.t('wrong'), '${round.wrong}', BilgiColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _statBox(_game.t('result_speed'), '+${round.timeBonus}', BilgiColors.warning)),
          ],
        ),
        const SizedBox(height: 12),
        if (!_game.scoreDoubled) _resultDoubleCard(),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 12),
          child: Text(
            _game.scoreDoubled
                ? _game.t('result_doubled')
                : _game.resultDoubleUsed
                    ? _game.t('err_quota')
                    : _fill('result_watch_extra', {'n': _grouped(round.score)}),
            style: const TextStyle(color: BilgiColors.muted, fontSize: 12),
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_game.t('result_rewards'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: BilgiColors.muted)),
              const SizedBox(height: 12),
              Text('🪙 ${_fill('result_gold_plus', {'n': '${round.gold}'})}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('✨ ${_fill('result_xp_plus', {'n': '${round.xp}'})}', style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final badge in bilgiBadges)
                if (_game.newBadgeIds.contains(badge.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${badge.emoji} ${bilgiBadgeLabel(_game.locale, badge.id, badge.name)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _startButton(_game.replaySetup, label: _game.t('play_again_btn'), horizontalPadding: 0),
        const SizedBox(height: 12),
        _adBanner(showNoticeAbove: false, margin: const EdgeInsets.fromLTRB(0, 0, 0, 16)),
      ],
    );
  }

  Widget _resultDoubleCard() {
    final locked = _game.resultDoubleUsed;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: locked ? null : const LinearGradient(colors: [BilgiColors.warning, BilgiColors.error]),
        color: locked ? const Color(0xFF3A3848) : null,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '📺 ${_game.t('result_double_cta')}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: locked ? BilgiColors.muted : Colors.white,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: locked ? const Color(0xFF5C5870) : Colors.white,
              disabledBackgroundColor: locked ? const Color(0xFF5C5870) : Colors.white,
              foregroundColor: locked ? BilgiColors.muted : BilgiColors.error,
              disabledForegroundColor: locked ? BilgiColors.muted : BilgiColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: locked || _game.adWatching ? null : _game.doubleResultScore,
            child: Text(_game.t('result_watch'), style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _contestBoard(BilgiProfile user) {
    final rows = _game.contestRows;
    final podium = rows.take(3).toList();
    final rest = rows.length > 3 ? rows.sublist(3) : const <BilgiBoardEntry>[];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('contest_rank_title'), onBack: _game.back),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Text(
            _fill('league_competitors', {'n': '${_game.contestJoined}'}),
            style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary),
          ),
        ),
        if (rows.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text(_game.t('league_empty')))
        else ...[
          if (podium.isNotEmpty) _podium(podium, user.id),
          for (final row in rest) _boardRow(row.rank > 0 ? row.rank : 0, row, row.id == user.id),
        ],
      ],
    );
  }

  Widget _league(BilgiProfile user) {
    final daily = _game.boardScope == 'daily';
    final rows = daily ? _game.contestRows : _game.boardRows;
    final podium = rows.take(3).toList();
    final rest = rows.length > 3 ? rows.sublist(3) : const <BilgiBoardEntry>[];
    final categoryOpen = _game.boardScope == 'category' && _game.boardCategoryId != null;
    final categoryList = _game.boardScope == 'category' && _game.boardCategoryId == null;
    final showPeriod = _game.boardScope == 'general' || categoryOpen;
    final heading = _leagueHeading();
    final periodScore = bilgiLeaguePeriodScore(
      user,
      weekly: _game.boardWeekly,
      categoryId: categoryOpen ? _game.boardCategoryId : null,
    );
    final periodRank = bilgiMyBoardRank(rows, user.id);
    return Column(
      children: [
        _pageHeader(_game.t('page_league')),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              for (final item in [
                (_game.t('league_tab_daily'), 'daily', true),
                (_game.t('league_tab_general'), 'general', true),
                (_game.t('league_tab_categories'), 'category', false),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: item.$3 ? 8 : 0),
                    child: Material(
                      color: _game.boardScope == item.$2 ? _homeGold : _platedDim,
                      shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                        side: const BorderSide(color: _homeGold, width: 2),
                      ),
                      child: InkWell(
                        onTap: () => _game.selectBoard(item.$2),
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                          child: Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _homeInter(
                              size: 12,
                              weight: FontWeight.w800,
                              color: _game.boardScope == item.$2 ? const Color(0xFF3A2200) : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (daily)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _fill('league_competitors', {'n': '${_game.contestJoined}'}),
              style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary),
            ),
          )
        else if (categoryOpen || categoryList)
          Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              if (categoryOpen)
                IconButton(
                  onPressed: () {
                    _game.boardCategoryId = null;
                    _game.loadBoard();
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              if (categoryList)
                const Spacer()
              else
                Expanded(
                  child: Text(heading, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                ),
              if (categoryList) _leagueRewardButton(),
            ],
          ),
        ),
        if (showPeriod) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 40),
                const Spacer(),
                _leaguePeriodChip(_game.t('league_period_week'), true),
                const SizedBox(width: 8),
                _leaguePeriodChip(_game.t('league_period_all'), false),
                const Spacer(),
                _leagueRewardButton(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Wrap(
              spacing: 16,
              runSpacing: 2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final line in bilgiMyRankLabel(score: periodScore, rank: periodRank, locale: _game.locale).split('\n'))
                  Text(
                    line,
                    style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: _quickStartGradient('hizli'),
                    borderRadius: BorderRadius.circular(bilgiRadius),
                    boxShadow: const [BoxShadow(color: Color(0x660F766E), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        final categoryId = _game.boardCategoryId;
                        if (categoryOpen && categoryId != null) {
                          unawaited(_game.playCategoryLeague(categoryId));
                        } else {
                          _game.open('categories');
                        }
                      },
                      borderRadius: BorderRadius.circular(bilgiRadius),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(
                          categoryOpen &&
                                  _game.boardCategoryId != null &&
                                  !_game.joinedCategoryLeague(_game.boardCategoryId!)
                              ? _game.t('league_join')
                              : _game.t('league_continue'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
              if (!daily && _game.leagueTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(_game.leagueTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        if (daily)
          ..._rankedRows(user.id, podium, rest, rows.isEmpty)
        else if (_game.boardScope == 'category' && _game.boardCategoryId == null)
          ..._leagueCategories()
        else
          ..._leagueRows(user.id, podium, rest, rows.isEmpty),
        const SizedBox(height: 16),
        _adBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _leagueCategoryName(String id) {
    final catalog = bilgiCategoryById(id);
    return _game.categoryLabel(id, catalog?.name ?? id);
  }

  String _leagueHeading() {
    if (_game.boardScope != 'category') return _game.t('league_tab_general');
    if (_game.boardCategoryId == null) return _game.t('league_tab_categories');
    final name = _leagueCategoryName(_game.boardCategoryId!).trim();
    if (_game.locale == 'tr' && name.endsWith('Ligi')) return name;
    return _fill('league_named', {'name': name.isEmpty ? _game.t('league_category') : name});
  }

  String _goldXp(int gold, int xp) => _fill('lr_gold_xp', {'gold': _grouped(gold), 'xp': _grouped(xp)});

  Widget _leagueRewards() {
    final t = _game.t;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(t('league_rewards'), onBack: _game.back),
        _leagueRewardCard(
          t('lr_correct'),
          [
            _leagueRewardRows([
              (t('lr_formula'), t('lr_formula_v')),
            ]),
            _leagueRewardHead(t('lr_diff_points')),
            _leagueRewardRows([
              (t('diff_easy'), _grouped(10)),
              (t('diff_medium'), _grouped(15)),
              (t('diff_hard'), _grouped(25)),
              (t('diff_legend'), _grouped(40)),
            ]),
            _leagueRewardHead(t('lr_mode_factor')),
            _leagueRewardRows([
              (t('mode_hizli'), '×1,5'),
              (t('mode_klasik'), '×1'),
              (t('mode_duello'), '×1'),
              (t('mode_grup'), '×1'),
              (t('mode_oda'), '×1'),
              (t('mode_lig'), '×1'),
              (t('mode_sakin'), '×0,5'),
              (t('mode_maraton'), '×2'),
              (t('mode_gunluk'), '×2'),
            ]),
            _leagueRewardHead(t('lr_extra')),
            _leagueRewardRows([
              (t('lr_time_bonus'), t('lr_time_bonus_v')),
              (t('lr_time_cap'), '5'),
              (t('lr_untimed'), t('lr_no_time_bonus')),
              (t('lr_streak'), t('lr_streak_v')),
              (t('lr_streak_cap'), '20'),
              (t('wrong'), t('lr_wrong_reset')),
            ]),
          ],
        ),
        _leagueRewardCard(
          t('lr_which'),
          [
            _leagueRewardRows([
              (t('league_tab_general'), t('lr_general_v')),
              (t('lr_mix'), t('lr_mix_writes')),
              (t('lr_cat_league'), t('lr_picked')),
              (t('lr_mix_cat'), t('lr_not_written')),
              (t('mode_yarisma'), t('lr_contest_skip')),
              (t('lr_zero'), t('lr_not_written')),
            ]),
          ],
        ),
        _leagueRewardCard(
          t('lr_after'),
          [
            _leagueRewardRows([
              (t('bal_gold'), t('lr_gold_rule')),
              (t('lr_xp_name'), t('lr_xp_rule')),
              (t('lr_round'), t('lr_down')),
              (t('lr_zero'), t('lr_no_gold_xp')),
            ]),
            _leagueRewardHead(t('lr_separate')),
            _leagueRewardRows([
              (t('lr_daily_right'), t('lr_daily_pay')),
              (t('lr_duel_rival'), t('lr_duel_pay')),
              (t('lr_contest_right'), t('lr_contest_pay')),
              (t('lr_contest_cap'), t('lr_contest_cap_v')),
            ]),
            _leagueRewardHead(t('lr_level_name')),
            _leagueRewardRows([
              (t('lr_level_name'), t('lr_level_v')),
              (t('bal_diamond'), t('lr_diamond_v')),
              (t('lr_cap'), t('lr_cap_v')),
            ]),
          ],
        ),
        _leagueRewardCard(
          t('lr_monday'),
          [
            _leagueRewardRows([
              (t('lr_clock'), t('lr_clock_v')),
              (t('lr_pay'), t('lr_weekly')),
              (t('lr_round_reward'), t('lr_stacks')),
              (t('lr_sample_name'), t('lr_unpaid')),
            ]),
            _leagueRewardHead(t('lr_top100')),
            _leagueRewardRows([
              ('1.', _goldXp(10000, 1000)),
              ('2.', _goldXp(5000, 500)),
              ('3.', _goldXp(2500, 250)),
              ('4.–100.', _goldXp(500, 50)),
            ]),
            _leagueRewardHead(t('lr_top10')),
            _leagueRewardRows([
              (t('lr_general_pay'), t('lr_stacks')),
              ('1.', _goldXp(1000, 100)),
              ('2.', _goldXp(500, 50)),
              ('3.', _goldXp(250, 25)),
              ('4.–10.', _goldXp(100, 10)),
            ]),
            _leagueRewardHead(t('lr_outside')),
            _leagueRewardRows([
              (t('lr_later'), t('lr_no_monday')),
              (t('lr_zero'), t('lr_not_listed')),
              (t('lr_banned'), t('lr_not_listed')),
            ]),
          ],
        ),
        _leagueRewardCard(
          t('lr_tier'),
          [
            _leagueRewardHead(t('lr_week_points')),
            _leagueRewardRows([
              (t('lr_bronze'), '0'),
              (t('lr_silver'), _grouped(500)),
              (t('bal_gold'), _grouped(2000)),
              (t('bal_diamond'), _grouped(6000)),
              (t('diff_legend'), _grouped(15000)),
              (t('lr_pay'), t('lr_pay_same')),
            ]),
            _leagueRewardHead(t('lr_title')),
            _leagueRewardRows([
              (t('lr_cond'), t('lr_top10_all')),
              (t('lr_example'), t('lr_example_title')),
              (t('bal_gold'), t('lr_not_gold')),
            ]),
          ],
        ),
      ],
    );
  }

  Widget _leagueRewardCard(String title, List<Widget> lines) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            ...lines,
          ],
        ),
      ),
    );
  }

  Widget _leagueRewardHead(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Text(
        text,
        style: _homeInter(size: 12, weight: FontWeight.w800, color: _homeGold).copyWith(letterSpacing: 0.6),
      ),
    );
  }

  Widget _leagueRewardRows(List<(String, String)> rows) {
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1, thickness: 1, color: Color(0x1AF4F1FB)),
          _leagueRewardPay(rows[i].$1, rows[i].$2),
        ],
      ],
    );
  }

  Widget _leagueRewardPay(String place, String payout) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(place, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.25)),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 6,
            child: Text(
              payout,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.25, color: BilgiColors.secondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leagueRewardButton() {
    return IconButton(
      tooltip: _game.t('league_rewards'),
      onPressed: () => _game.open('league_rewards'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: const Icon(Icons.emoji_events, color: _homeGold),
    );
  }

  Widget _leaguePeriodChip(String label, bool weekly) {
    final on = _game.boardWeekly == weekly;
    return Material(
      color: on ? _homeGold : _platedDim,
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: _homeGold, width: 2),
      ),
      child: InkWell(
        onTap: () {
          _game.boardWeekly = weekly;
          _game.loadBoard();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: _homeInter(size: 12, weight: FontWeight.w800, color: on ? const Color(0xFF3A2200) : Colors.white),
          ),
        ),
      ),
    );
  }

  List<Widget> _leagueCategories() {
    final catalog = bilgiLeagueCatalog(_game.difficultySlices);
    final ids = bilgiSortLeagueCatalog(
      catalog,
      sort: _leagueSort,
      questionCounts: _game.categoryCounts,
      playerCounts: _game.boardCategoryPlayerCounts,
      names: {for (final id in catalog) id: _leagueCategoryName(id)},
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            _leagueSortChip(_game.t('league_sort_alpha'), bilgiLeagueSortAlpha),
            _leagueSortChip(_game.t('league_sort_questions'), bilgiLeagueSortQuestions),
            _leagueSortChip(_game.t('league_sort_players'), bilgiLeagueSortPlayers),
          ],
        ),
      ),
      if (ids.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _card(
            child: Text(
              _fill('league_none_ready', {'n': '$bilgiMinPublishedPerDifficulty'}),
              style: _homeInter(size: 14, weight: FontWeight.w700, color: BilgiColors.muted),
            ),
          ),
        )
      else
        for (final id in ids) _leagueCategoryRow(id),
    ];
  }

  Widget _leagueSortChip(String label, String sort) {
    final on = _leagueSort == sort;
    return Expanded(
      child: Padding(
        padding: EdgeInsets.only(right: sort == bilgiLeagueSortPlayers ? 0 : 8),
        child: Material(
          color: on ? _homeGold : _platedDim,
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _homeGold, width: 2),
          ),
          child: InkWell(
            onTap: () => setState(() => _leagueSort = sort),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _homeInter(size: 12, weight: FontWeight.w800, color: on ? const Color(0xFF3A2200) : Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _leagueCategoryRow(String id) {
    final rank = _game.boardCategoryRanks[id] ?? 0;
    final joined = _game.joinedCategoryLeague(id);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Material(
        color: _homeCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _homeGold, width: 2),
        ),
        child: InkWell(
          onTap: () {
            _game.boardCategoryId = id;
            _game.loadBoard();
          },
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Text(bilgiCategoryById(id)?.emoji ?? '🏆'),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          _leagueCategoryName(id),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (rank > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          _game.t('league_rank').replaceAll('{n}', '$rank'),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _game.playCategoryLeague(id),
                  child: Text(
                    joined ? _game.t('league_continue') : _game.t('league_join'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _leagueRows(String meId, List<BilgiBoardEntry> podium, List<BilgiBoardEntry> rest, bool empty) {
    if (_game.boardClosed) {
      return [
        Padding(padding: const EdgeInsets.all(20), child: Text(_game.t('league_closed'))),
      ];
    }
    return _rankedRows(meId, podium, rest, empty);
  }

  List<Widget> _rankedRows(String meId, List<BilgiBoardEntry> podium, List<BilgiBoardEntry> rest, bool empty) {
    if (empty) {
      return [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: _card(
            child: Text(
              _game.t('league_empty'),
              style: _homeInter(size: 14, weight: FontWeight.w700, color: BilgiColors.muted),
            ),
          ),
        ),
      ];
    }
    return [
      if (podium.isNotEmpty) _podium(podium, meId),
      for (var i = 0; i < rest.length; i++)
        _boardRow(rest[i].rank > 0 ? rest[i].rank : i + 4, rest[i], rest[i].id == meId),
    ];
  }

  Future<void> _showGoldHelp() async {
    if (!mounted || _goldDialogOpen) return;
    _goldDialogOpen = true;
    final index = _game.rewardIndex();
    final options = bilgiGoldHelpOptions(
      rewardedGold: _game.config.rewardedGold,
      shopGoldA: bilgiGold1000.gold,
      shopGoldB: bilgiGold5000.gold,
      dailyGoldReady: _game.rewardReady(),
      dailyGold: dayRewardAmount(_game.config.dailyGold, index),
      locale: _game.locale,
    );
    try {
      final picked = await showDialog<BilgiGoldHelpKind>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: _homeCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: _homeGold, width: 2),
            ),
            title: Text(
              _game.t('gold_short_title'),
              style: const TextStyle(color: BilgiColors.text, fontWeight: FontWeight.w800),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _game.t('gold_short_ways'),
                    style: const TextStyle(color: BilgiColors.muted, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  for (var i = 0; i < options.length; i++)
                    Padding(
                      padding: EdgeInsets.only(bottom: i == options.length - 1 ? 0 : 8),
                      child: _goldHelpRow(dialogContext, options[i]),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(_game.t('close')),
              ),
            ],
          );
        },
      );
      if (!mounted || picked == null) return;
      switch (picked) {
        case BilgiGoldHelpKind.ad:
          await _game.watchFor('gold');
        case BilgiGoldHelpKind.shop:
          _game.openShopGold();
        case BilgiGoldHelpKind.daily:
          _game.open('reward');
      }
    } finally {
      _goldDialogOpen = false;
    }
  }

  Widget _goldHelpRow(BuildContext dialogContext, BilgiGoldHelpOption option) {
    final icon = switch (option.kind) {
      BilgiGoldHelpKind.ad => '🎬',
      BilgiGoldHelpKind.shop => '🪙',
      BilgiGoldHelpKind.daily => '🎁',
    };
    return Material(
      color: BilgiColors.bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => Navigator.pop(dialogContext, option.kind),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.title,
                      style: const TextStyle(color: BilgiColors.text, fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.subtitle,
                      style: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: BilgiColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  void _scrollShopGold({int attempt = 0}) {
    if (!mounted || !_game.pendingShopGold || _game.page != 'shop') return;
    final target = _shopGoldKey.currentContext;
    if (target == null) {
      if (attempt < 8) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollShopGold(attempt: attempt + 1));
      } else {
        _game.pendingShopGold = false;
      }
      return;
    }
    _game.pendingShopGold = false;
    Scrollable.ensureVisible(
      target,
      alignment: 0.05,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _editUsername(BilgiProfile user) async {
    _game.clearNicknameNotice();
    final field = TextEditingController(text: user.username);
    var error = '';
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            Future<void> save() async {
              if (busy) return;
              final issue = bilgiUsernameIssue(field.text);
              if (issue != null) {
                setLocal(() => error = issue);
                return;
              }
              setLocal(() {
                busy = true;
                error = '';
              });
              final message = await _game.saveUsername(field.text);
              if (!dialogContext.mounted) return;
              if (message == null) {
                Navigator.pop(dialogContext);
                return;
              }
              setLocal(() {
                busy = false;
                error = message;
              });
            }

            return AlertDialog(
              backgroundColor: _homeCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: const BorderSide(color: _homeGold, width: 2),
              ),
              title: Text(_game.t('username'), style: _homeInter(size: 18, weight: FontWeight.w900, color: _homeGoldText)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: field,
                    autofocus: true,
                    enabled: !busy,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => save(),
                  ),
                  if (error.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      error,
                      style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: busy ? null : () => Navigator.pop(dialogContext),
                  child: Text(_game.t('joker_cancel')),
                ),
                TextButton(
                  onPressed: busy ? null : save,
                  child: Text(_game.t('save')),
                ),
              ],
            );
          },
        );
      },
    );
    field.dispose();
  }

  Future<void> _pickAvatar(BilgiProfile user) async {
    final emoji = await showBilgiAvatarPicker(context, current: user.avatar);
    if (emoji == null || !mounted) return;
    await _game.saveProfile(avatar: emoji);
  }

  Widget _profile(BilgiProfile user) {
    final crown = bilgiPlusActive(user, DateTime.now()) || user.badges.contains('king');
    final intoLevel = user.xp % 5000;
    final fill = user.level >= 100 ? 1.0 : intoLevel / 5000;
    var histCorrect = 0;
    var histWrong = 0;
    for (final row in _game.past) {
      histCorrect += (row['correct'] as int?) ?? 0;
      histWrong += (row['wrong'] as int?) ?? 0;
    }
    final answered = histCorrect + histWrong;
    final ratioLabel = answered > 0 ? '%${((histCorrect / answered) * 100).round()}' : null;
    return Column(
      children: [
        _pageHeader(_game.t('page_profile')),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _homeCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _homeGold, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.5),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33FFC83D), Colors.transparent],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    children: [
                      MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => _pickAvatar(user),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _homeCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _homeGold, width: 4),
                                ),
                                child: Text(user.avatar, style: const TextStyle(fontSize: 40)),
                              ),
                              if (crown)
                                const Positioned(top: -8, right: -4, child: Text('👑', style: TextStyle(fontSize: 22))),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _editUsername(user),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                bilgiProfileHeading(username: user.username, displayName: _linkedDisplayName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.edit_outlined, size: 16, color: BilgiColors.muted),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [BilgiColors.warning, BilgiColors.accent]),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(bilgiRankTitle(_game.locale, user.title).toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                      if (_game.leagueTitle.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(_game.leagueTitle, style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary)),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(_fill('level', {'n': '${user.level}'}), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const Spacer(),
                          Text('${_grouped(intoLevel)} / 5.000 XP', style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          height: 8,
                          child: Stack(
                            children: [
                              const ColoredBox(color: BilgiColors.bg, child: SizedBox.expand()),
                              FractionallySizedBox(
                                widthFactor: fill.clamp(0.0, 1.0),
                                child: const ColoredBox(color: _homeGold, child: SizedBox.expand()),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _homeCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _homeGold, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: _roundWalletStrip(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _statBox(_game.t('total_games'), '${user.gamesPlayed}', BilgiColors.text)),
                  const SizedBox(width: 12),
                  Expanded(child: _statBox(ratioLabel == null ? _game.t('correct') : _game.t('correct_ratio'), ratioLabel ?? '${user.correctTotal}', _homeGoldText)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _statBox(_game.t('best_score'), _grouped(user.bestScore), BilgiColors.warning)),
                  const SizedBox(width: 12),
                  Expanded(child: _statBox(_game.t('login_streak'), _fill(user.streak == 1 ? 'day_one' : 'days', {'n': '${user.streak}'}), BilgiColors.accent)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _sectionLabel(_game.t('badges')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _homeCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _homeGold, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
              child: SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceEvenly,
                  runSpacing: 12,
                  children: [
                    for (final badge in bilgiBadges)
                      Opacity(
                        opacity: user.badges.contains(badge.id) ? 1 : 0.4,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(badge.emoji, style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 6),
                            Text(bilgiBadgeLabel(_game.locale, badge.id, badge.name), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _sectionLabel(_game.t('account')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _menuRow('✏️', _game.t('username'), user.username, () => _editUsername(user)),
                _menuRow('📊', _game.t('stats'), _game.t('stats_sub'), () => _game.open('history')),
                _menuRow('🎯', _game.t('page_achievements'), _game.t('tasks'), () => _game.open('achievements')),
                _menuRow('📜', _game.t('page_history'), user.gamesPlayed == 0 ? _game.t('no_games') : _fill('games_n', {'n': '${user.gamesPlayed}'}), () => _game.open('history')),
                _menuRow('👥', _game.t('invite'), user.inviteCode, () => _game.open('invite')),
                _menuRow('🔐', _game.t('sign_in'), _game.t('sign_in_sub'), () => _game.open('login'), last: true),
              ],
            ),
          ),
        ),
        ..._settingsSections(),
        const SizedBox(height: 16),
        _adBanner(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmShopLife() async {
    if (_shopSpendBusy) return;
    final user = _game.profile;
    if (user == null) return;
    if (user.lives >= _game.config.maxLives) {
      await _game.refill();
      return;
    }
    final preview = bilgiShopLifeExchange(price: _game.config.lifePrice, livesAfter: _game.config.maxLives, locale: _game.locale);
    await _runShopSpend(
      preview: preview,
      buy: _game.refill,
      granted: (before, after) => after.lives > before.lives,
      result: (spent, after) => bilgiShopLifeExchange(price: spent, livesAfter: after.lives, locale: _game.locale),
    );
  }

  Future<void> _confirmShopJoker(String type) async {
    if (_shopSpendBusy) return;
    final user = _game.profile;
    if (user == null) return;
    final price = _game.config.jokerPrices[type] ?? 50;
    final preview = bilgiShopJokerExchange(
      name: _game.t('joker_$type'),
      price: price,
      stockAfter: (user.jokers[type] ?? 0) + 1,
      icon: _jokerEmoji(type),
      locale: _game.locale,
    );
    await _runShopSpend(
      preview: preview,
      buy: () => _game.buyJoker(type),
      granted: (before, after) => (after.jokers[type] ?? 0) > (before.jokers[type] ?? 0),
      result: (spent, after) => bilgiShopJokerExchange(
        name: _game.t('joker_$type'),
        price: spent,
        stockAfter: after.jokers[type] ?? 0,
        icon: _jokerEmoji(type),
        locale: _game.locale,
      ),
    );
  }

  Future<void> _runShopSpend({
    required BilgiShopExchangeCopy preview,
    required Future<void> Function() buy,
    required bool Function(BilgiProfile before, BilgiProfile after) granted,
    required BilgiShopExchangeCopy Function(int spent, BilgiProfile after) result,
  }) async {
    if (_shopSpendBusy) return;
    final before = _game.profile;
    if (before == null) return;
    _shopSpendBusy = true;
    try {
      final ok = await showBilgiShopSpendPrompt(
        context,
        message: preview.confirm,
        confirmLabel: _game.t('ok'),
        cancelLabel: _game.t('joker_cancel'),
      );
      if (ok != true || !mounted) return;
      await buy();
      if (!mounted) return;
      final after = _game.profile;
      if (after == null || !granted(before, after)) return;
      final spent = before.gold - after.gold;
      if (spent <= 0) return;
      _game.notice = null;
      await _playShopExchange(result(spent, after));
    } finally {
      _shopSpendBusy = false;
    }
  }

  Future<void> _playShopExchange(BilgiShopExchangeCopy exchange) async {
    final loading = BilgiRewardLoad(
      icon: exchange.icon,
      amount: exchange.amount,
      caption: _game.t('ad_reward_loading'),
      loading: true,
    );
    _shopExchange = loading;
    _game.rewardLoad = loading;
    _game.notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted || !identical(_game.rewardLoad, _shopExchange)) return;
    final done = BilgiRewardLoad(
      icon: exchange.icon,
      amount: exchange.amount,
      caption: exchange.caption,
      loading: false,
    );
    _shopExchange = done;
    _game.rewardLoad = done;
    _game.notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted || !identical(_game.rewardLoad, _shopExchange)) return;
    _shopExchange = null;
    _game.dismissRewardLoad();
  }

  Widget _shop(BilgiProfile user) {
    String goldN(Object n) => _fill('shop_gold_n', {'n': '$n'});
    final packs = [
      (bilgiGold1000, goldN(1000), '₺29,99', 'assets/images/shop/luno_gold_1000.png'),
      (bilgiGold5000, goldN(5000), '₺99,99', 'assets/images/shop/luno_gold_5000.png'),
    ];
    final plans = [
      (bilgiPlusAylik, _game.t('shop_plus_month'), _game.t('shop_plus_month_sub'), 'assets/images/shop/luno_plus_aylik.png'),
      (bilgiPlus6Ay, _game.t('shop_plus_6'), _game.t('shop_plus_6_sub'), 'assets/images/shop/luno_plus_6ay.png'),
      (bilgiPlusYillik, _game.t('shop_plus_year'), _game.t('shop_plus_year_sub'), 'assets/images/shop/luno_plus_yillik.png'),
    ];
    return Column(
      children: [
        _pageHeader(_game.t('page_shop')),
        Expanded(
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
        if (_game.notice != null) _note(_game.notice!),
        _shopSection(
          title: _game.t('shop_subs'),
          rows: [
            for (final plan in plans)
              (
                icon: '',
                asset: plan.$4,
                title: plan.$2,
                subtitle: plan.$3,
                onTap: () => _game.buyPlay(plan.$1),
              ),
          ],
        ),
        KeyedSubtree(
          key: _shopGoldKey,
          child: _shopSection(
            title: _game.t('shop_pay'),
            rows: [
              for (final pack in packs)
                (
                  icon: '',
                  asset: pack.$4,
                  title: pack.$2,
                  subtitle: pack.$3,
                  onTap: () => _game.buyPlay(pack.$1),
                ),
            ],
          ),
        ),
        _shopSection(
          title: _game.t('shop_convert'),
          note: _game.notice,
          trailing: Text(
            _fill('shop_gold_n', {'n': _grouped(user.gold)}),
            style: _homeInter(size: 13, weight: FontWeight.w700, color: BilgiColors.warning),
          ),
          rows: [
            (
              icon: '❤️',
              asset: '',
              title: _game.t('shop_refill'),
              subtitle: _fill('shop_now_lives', {'price': goldN(_game.config.lifePrice), 'n': '${user.lives}'}),
              onTap: () => unawaited(_confirmShopLife()),
            ),
            for (final entry in _game.config.jokerPrices.entries)
              (
                icon: _jokerEmoji(entry.key),
                asset: '',
                title: _game.t('joker_${entry.key}'),
                subtitle: _fill('shop_stock_line', {'price': goldN(entry.value), 'n': '${user.jokers[entry.key] ?? 0}'}),
                onTap: () => unawaited(_confirmShopJoker(entry.key)),
              ),
          ],
        ),
        _shopSection(
          title: _game.t('shop_ads'),
          rows: [
            (
              icon: '🪙',
              asset: '',
              title: _game.t('shop_ad_gold'),
              subtitle: goldN(_game.config.rewardedGold),
              onTap: () => _game.watchFor('gold'),
            ),
            (
              icon: '✂️',
              asset: '',
              title: _game.t('shop_ad_joker'),
              subtitle: _game.t('shop_ad_joker_sub'),
              onTap: () => _game.watchFor('joker'),
            ),
            (
              icon: '❤️',
              asset: '',
              title: _game.t('shop_ad_life'),
              subtitle: _game.t('shop_ad_life_sub'),
              onTap: () => _game.watchFor('life'),
            ),
          ],
        ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _shopSection({
    required String title,
    required List<({String icon, String asset, String title, String subtitle, VoidCallback onTap})> rows,
    String? note,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(_display(title), style: _homeInter(size: 13, weight: FontWeight.w800, color: _homeGold, height: 1.1).copyWith(letterSpacing: 1.2))),
              if (trailing != null) trailing,
            ],
          ),
          if (note != null && note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(note, style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: _homeCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _homeGold, width: 2),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    _shopRow(rows[i], first: i == 0, last: i == rows.length - 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _shopRow(({String icon, String asset, String title, String subtitle, VoidCallback onTap}) row, {required bool first, required bool last}) {
    return InkWell(
      onTap: row.onTap,
      borderRadius: BorderRadius.vertical(
        top: first ? const Radius.circular(16) : Radius.zero,
        bottom: last ? const Radius.circular(16) : Radius.zero,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: Color.fromRGBO(255, 255, 255, 0.08))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: row.asset.isEmpty
                  ? Text(row.icon, style: const TextStyle(fontSize: 18))
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(row.asset, width: 36, height: 36, fit: BoxFit.cover),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.title, style: _homeInter(size: 14, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(row.subtitle, style: _homeInter(size: 12, weight: FontWeight.w500, color: BilgiColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: BilgiColors.muted, size: 20),
          ],
        ),
      ),
    );
  }

  String _jokerEmoji(String type) => switch (type) {
        'half' => '✂️',
        'double' => '👥',
        'time' => '⏸️',
        'change' => '🔄',
        'hint' => '💡',
        _ => '🃏',
      };

  Widget _duel() {
    final room = _game.room;
    final lobby = room != null && room.kind == 'duello';
    return ListView(
      children: [
        _pageHeader(
          _game.t('page_duel'),
          onBack: _duelForm && !lobby
              ? () => setState(() => _duelForm = false)
              : _duelJoin && !lobby
                  ? () => setState(() => _duelJoin = false)
                  : _game.back,
        ),
        if (_game.notice != null) _note(_game.notice!),
        if (lobby)
          _roomLobby(room)
        else if (_duelForm)
          ..._inviteForm('duello')
        else if (_duelJoin)
          _codeJoin(
            title: _game.t('duel_join_title'),
            onSubmit: (code) => _game.enterRoom(code),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(_game.t('duel_blurb'), textAlign: TextAlign.center),
          ),
          BilgiPrimaryButton(
            label: _game.t('duel_create'),
            onTap: () => _openInviteForm('duello'),
          ),
          const SizedBox(height: 12),
          BilgiPrimaryButton(
            label: _game.t('duel_join_btn'),
            onTap: () => setState(() {
              _duelForm = false;
              _duelJoin = true;
            }),
          ),
        ],
      ],
    );
  }

  Widget _room() {
    final room = _game.room;
    final lobby = room != null && room.kind != 'duello';
    final title = switch (room?.kind) {
      'grup' => _game.t('page_group'),
      'duello' => _game.t('page_duel'),
      _ => _game.t('mode_oda'),
    };
    return ListView(
      children: [
        _pageHeader(
          lobby ? title : _game.t('mode_oda'),
          onBack: _roomForm && !lobby
              ? () => setState(() => _roomForm = false)
              : _roomJoin && !lobby
                  ? () => setState(() => _roomJoin = false)
                  : _game.back,
        ),
        if (_game.notice != null) _note(_game.notice!),
        if (lobby)
          _roomLobby(room)
        else if (_roomForm)
          ..._inviteForm('oda')
        else if (_roomJoin)
          _codeJoin(
            title: _game.t('room_join_title'),
            onSubmit: (code) => _game.enterRoom(code),
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(_game.t('room_blurb'), textAlign: TextAlign.center),
          ),
          BilgiPrimaryButton(
            label: _game.t('room_create'),
            onTap: () => _openInviteForm('oda'),
          ),
          const SizedBox(height: 12),
          BilgiPrimaryButton(
            label: _game.t('room_join_btn'),
            onTap: () => setState(() {
              _roomForm = false;
              _roomJoin = true;
            }),
          ),
        ],
      ],
    );
  }

  void _openInviteForm(String kind) {
    setState(() {
      _inviteCategory = tumuKarmaId;
      _inviteSub = '';
      _inviteDifficulty = 'hepsi';
      _inviteCount = kind == 'duello' ? 10 : 20;
      _inviteSeconds = kind == 'duello' ? 10 : 15;
      if (kind == 'duello') {
        _duelJoin = false;
        _duelForm = true;
      } else {
        _roomJoin = false;
        _roomForm = true;
      }
    });
  }

  List<Widget> _inviteForm(String kind) {
    final subs = _inviteSubs();
    final diffs = [
      (const Color(0xFF3DDC97), _game.t('diff_easy'), 'kolay'),
      (const Color(0xFFFFB800), _game.t('diff_medium'), 'orta'),
      (const Color(0xFFFF4D6D), _game.t('diff_hard'), 'zor'),
      (const Color(0xFF8A879E), _game.t('diff_legend'), 'efsane'),
      (const Color(0xFFB388FF), _game.t('diff_mix'), bilgiMixDifficulty),
      (const Color(0xFF7EB6FF), _game.t('diff_all'), 'hepsi'),
    ];
    final categories = <(String, String)>[
      (tumuKarmaId, _game.t('all_mix')),
      for (final category in _listedCategories) (category.id, _game.categoryLabel(category.id, category.name)),
    ];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        child: Text(
          _game.t('invite_blurb'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: BilgiColors.muted, fontSize: 13),
        ),
      ),
      _sectionLabel(_game.t('invite_category')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _inviteMenu(
          value: _inviteCategory,
          options: categories,
          onChanged: (value) => setState(() {
            _inviteCategory = value;
            _inviteSub = '';
          }),
        ),
      ),
      if (_inviteCategory != tumuKarmaId && subs.isNotEmpty) ...[
        _sectionLabel(_game.t('invite_sub')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _inviteMenu(
            value: _inviteSub,
            options: [
              ('', _game.t('invite_all_subs')),
              for (final sub in subs) (sub, _game.subLabel(_inviteCategory, sub)),
            ],
            onChanged: (value) => setState(() => _inviteSub = value),
          ),
        ),
      ],
      _sectionLabel(_game.t('invite_diff')),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: _setupTray(
          plated: true,
          child: Column(
            children: [
              for (var row = 0; row < 2; row++) ...[
                if (row > 0) const SizedBox(height: 4),
                Row(
                  children: [
                    for (final item in (row == 0 ? diffs.take(3) : diffs.skip(3)))
                      Expanded(
                        child: _setupDiffChip(
                          color: item.$1,
                          label: item.$2,
                          active: _inviteDifficulty == item.$3,
                          plated: true,
                          onTap: () => setState(() => _inviteDifficulty = item.$3),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      _sectionLabel(_game.t('invite_questions')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _setupTray(
          plated: true,
          child: Row(
            children: [
              for (final count in bilgiInviteCounts)
                Expanded(
                  child: _setupCountSeg(
                    count: count,
                    active: _inviteCount == count,
                    plated: true,
                    onTap: () => setState(() => _inviteCount = count),
                  ),
                ),
            ],
          ),
        ),
      ),
      _sectionLabel(_game.t('invite_time')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _setupTray(
          plated: true,
          child: Row(
            children: [
              for (final pace in bilgiInviteSeconds)
                Expanded(
                  child: _setupCountSeg(
                    count: pace,
                    active: _inviteSeconds == pace,
                    plated: true,
                    onTap: () => setState(() => _inviteSeconds = pace),
                  ),
                ),
            ],
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 20, 0),
        child: Text(_game.t('invite_seconds_hint'), style: const TextStyle(color: BilgiColors.muted, fontSize: 11)),
      ),
      const SizedBox(height: 16),
      BilgiPrimaryButton(
        label: kind == 'duello' ? _game.t('duel_create') : _game.t('room_create'),
        onTap: () {
          final category = _inviteCategory;
          final sub = category == tumuKarmaId ? '' : _inviteSub;
          _game.makeRoom(
            kind,
            categoryId: category,
            subcategory: sub,
            difficulty: _inviteDifficulty,
            questionCount: _inviteCount,
            seconds: _inviteSeconds,
          );
        },
      ),
      const SizedBox(height: 24),
    ];
  }

  List<String> _inviteSubs() {
    if (_inviteCategory == tumuKarmaId) return const [];
    final live = _game.categories.where((item) => item.id == _inviteCategory).firstOrNull;
    final all = live?.subs ?? const <String>[];
    return [
      for (final sub in all)
        if (bilgiSubListed(_inviteCategory, sub, _game.difficultySlices)) sub,
    ];
  }

  Widget _inviteMenu({
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) {
    final selected = options.any((item) => item.$1 == value) ? value : options.first.$1;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selected,
            dropdownColor: _homeCard,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            items: [
              for (final item in options)
                DropdownMenuItem(
                  value: item.$1,
                  child: Text(item.$2, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (next) {
              if (next != null) onChanged(next);
            },
          ),
        ),
      ),
    );
  }

  String _inviteSummary(BilgiRoom room) {
    final category = _game.categories.where((item) => item.id == room.categoryId).firstOrNull;
    final name = room.categoryId == tumuKarmaId || category == null
        ? _game.t('all_mix')
        : _game.categoryLabel(category.id, category.name);
    final sub = room.subcategory.trim();
    final where = sub.isEmpty ? name : '$name • ${_game.subLabel(room.categoryId, sub)}';
    final level = switch (room.difficulty) {
      'kolay' => _game.t('diff_easy'),
      'orta' => _game.t('diff_medium'),
      'zor' => _game.t('diff_hard'),
      'efsane' => _game.t('diff_legend'),
      'karisik' => _game.t('diff_mix'),
      _ => _game.t('diff_all'),
    };
    return '$where • $level • ${_fill('q_count', {'n': '${room.questionCount}'})} • ${_fill('seconds', {'n': '${room.seconds}'})}';
  }

  Widget _roomLobby(BilgiRoom room) {
    final host = _game.hostsRoom(room);
    final playing = room.status == 'playing';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fill('room_code', {'code': room.code}), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(_inviteSummary(room), style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                const SizedBox(height: 4),
                Text(_game.t('room_same'), style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                TextButton(
                  onPressed: () => Clipboard.setData(ClipboardData(text: room.code)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(_game.t('room_copy')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_game.canStartRoom(room))
          BilgiPrimaryButton(label: _game.t('room_start'), green: true, onTap: _game.startRoom)
        else if (host && room.kind == 'duello')
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _game.t('room_wait_rival'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: BilgiColors.muted),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              _game.t('room_wait_questions'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: BilgiColors.muted),
            ),
          ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              Text(_game.t('room_players'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                '${room.players.length}',
                style: const TextStyle(color: BilgiColors.muted, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        for (final player in room.players) _roomPlayer(player, playing: playing),
        if (!playing) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _game.leaveRoom,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: _homeGold, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(bilgiRadius)),
                ),
                child: Text(
                  host ? (room.players.length > 1 ? _game.t('room_close') : _game.t('joker_cancel')) : _game.t('room_leave'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _roomPlayer(Map<String, dynamic> player, {required bool playing}) {
    final name = '${player['name'] ?? ''}'.trim();
    final shown = name.isEmpty ? _game.t('room_player') : name;
    final initial = shown[0].toUpperCase();
    final role = player['role'] == 'host' ? _game.t('room_host') : _game.t('room_player');
    final score = '${player['score'] ?? '0'}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _homeCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _homeGold, width: 2),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _homeGold.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(shown, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(role, style: const TextStyle(color: BilgiColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            if (playing)
              Text(score, style: const TextStyle(color: BilgiColors.secondary, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  Widget _codeJoin({required String title, required ValueChanged<String> onSubmit}) {
    return _FormCard(
      title: title,
      fields: [_game.t('field_code')],
      numeric: const {0},
      submit: _game.t('room_join_go'),
      onSubmit: (values) => onSubmit(values.first.trim()),
    );
  }

  Widget _daily() {
    final used = _game.dailyQuestionUsed;
    return ListView(
      children: [
        _pageHeader(_game.t('page_daily'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(_game.t('daily_blurb')),
        ),
        if (used)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              _game.t('daily_quota_ad'),
              style: const TextStyle(color: BilgiColors.muted, height: 1.35),
            ),
          ),
        BilgiPrimaryButton(
          green: true,
          label: _game.busy
              ? _game.t('preparing')
              : (used ? _game.t('daily_ad_start') : _game.t('start')),
          onTap: _game.busy
              ? null
              : used
                  ? _game.startGunlukWithAd
                  : () {
                      _game.modeId = 'gunluk';
                      _game.categoryId = tumuKarmaId;
                      _game.difficulty = 'hepsi';
                      _game.start(forcedMode: 'gunluk', count: 1);
                    },
        ),
      ],
    );
  }

  Widget _events() {
    return ListView(
      children: [
        _pageHeader(_game.t('page_events'), onBack: _game.back),
        if (_game.eventRows.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text(_game.t('no_events')))
        else
          for (final event in _game.eventRows)
            _tile('🎉', '${event['title'] ?? _game.t('event')}', '${event['body'] ?? ''}', null),
      ],
    );
  }

  Widget _language() {
    final fromSettings = _game.profile?.localeChosen == true;
    if (_game.localePreview == null && !fromSettings) {
      final code = View.of(context).platformDispatcher.locale.languageCode;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _game.localePreview != null) return;
        _game.previewLocale(GameLocale.known(code) ? code : 'tr');
      });
    }
    return BilgiLanguagePage(
      selectedId: _game.locale,
      fromSettings: fromSettings,
      onPreview: _game.previewLocale,
      onConfirm: _game.confirmLocale,
      onBack: fromSettings ? _game.back : null,
    );
  }

  Widget _settings() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('settings')),
        if (_game.notice != null) _note(_game.notice!),
        ..._settingsSections(heading: false),
      ],
    );
  }

  List<Widget> _settingsSections({bool heading = true}) {
    final user = _game.profile;
    return [
      if (heading)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Text(
            _game.t('settings'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
      _sectionLabel(_game.t('language')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _card(
          child: _menuRow(
            '🌐',
            _game.t('language'),
            GameLocale.resolve(user?.locale).nativeName,
            () => _game.open('language'),
            last: true,
            valueSize: 14,
          ),
        ),
      ),
      _sectionLabel(_game.t('preferences')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _card(
          child: Column(
            children: [
              _toggleRow('🔔', _game.t('notifications'), _game.notifyOn, _game.toggleNotify),
              _toggleRow('🔊', _game.t('sound'), _game.soundOn, _game.toggleSound),
              _toggleRow('🌙', _game.t('dark'), true, null, last: true),
            ],
          ),
        ),
      ),
      _sectionLabel(_game.t('support')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: _card(
          child: Column(
            children: [
              _menuRow('❓', _game.t('help'), _game.t('how_to'), () => _game.open('howto')),
              _menuRow('ℹ️', _game.t('about'), gameVersionCode, null, last: true),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _achievements(BilgiProfile user) {
    if (bilgiAchievements.isEmpty) {
      return ListView(
        children: [
          _pageHeader(_game.t('page_achievements'), onBack: _game.back),
          Padding(padding: const EdgeInsets.all(20), child: Text(_game.t('no_achievements'))),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('page_achievements'), onBack: _game.back),
        for (final item in bilgiAchievements)
          _achievementRow(user, item),
      ],
    );
  }

  Widget _achievementRow(BilgiProfile user, BilgiAchievement item) {
    final current = _game.server.achievementProgress(user, item.id);
    final done = current >= item.target;
    final fill = item.target <= 0 ? 0.0 : (current / item.target).clamp(0.0, 1.0);
    return Opacity(
      opacity: done ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: _card(
          child: Row(
            children: [
              _iconTile(item.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_game.t('ach_${item.id}'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(_game.t('ach_${item.id}_body'), style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        height: 6,
                        child: Stack(
                          children: [
                            const ColoredBox(color: BilgiColors.bg, child: SizedBox.expand()),
                            FractionallySizedBox(
                              widthFactor: fill,
                              child: const ColoredBox(color: BilgiColors.secondary, child: SizedBox.expand()),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                done ? '✅' : (item.rewardGold > 0 ? '🪙 ${item.rewardGold}' : ''),
                style: TextStyle(
                  color: done ? BilgiColors.secondary : BilgiColors.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _history() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
      children: [
        _pageHeader(_game.t('page_history'), onBack: _game.back),
        if (_game.past.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('🎮 ${_game.t('history_empty')}'),
          )
        else
          for (final row in _game.past)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _historyRow(row),
            ),
        const SizedBox(height: 12),
        _adBanner(),
      ],
    );
  }

  String _historyStatus(Map<String, dynamic> row) {
    if (row['finished'] == true) return _game.t('status_done');
    final waiting = row['waiting'] == true;
    final questions = (row['questions'] as List?)?.length ?? 0;
    final index = bilgiInt(row['index'], 0);
    final correct = bilgiInt(row['correct'], 0);
    final wrong = bilgiInt(row['wrong'], 0);
    final started = questions > 0 && (index > 0 || correct > 0 || wrong > 0);
    if (waiting || !started) return _game.t('status_new');
    return _game.t('status_live');
  }

  Widget _historyRow(Map<String, dynamic> row) {
    final mode = bilgiModeById('${row['modeId'] ?? ''}');
    final categoryId = '${row['categoryId'] ?? ''}';
    final category = _game.categories.where((item) => item.id == categoryId).firstOrNull ?? bilgiCategoryById(categoryId);
    final opponent = '${row['opponentName'] ?? ''}';
    final waiting = row['waiting'] == true;
    final title = mode.id == 'duello' && opponent.isNotEmpty
        ? _fill('history_duel', {'name': opponent})
        : '${category == null ? (row['categoryId'] == tumuKarmaId ? _game.t('all_mix') : _game.t('mode_${mode.id}')) : _game.categoryLabel(category.id, category.name)} — ${_game.t('mode_${mode.id}')}';
    final icon = category?.emoji ?? mode.emoji;
    final when = _historyWhen('${row['startedAt'] ?? ''}');
    final correct = row['correct'] as int?;
    final questions = (row['questions'] as List?)?.length;
    final bits = <String>[if (when.isNotEmpty) when];
    if (correct != null && questions != null) {
      bits.add(_fill('history_correct', {'correct': '$correct', 'total': '$questions'}));
    }
    final status = _historyStatus(row);
    final score = row['score'] as int? ?? 0;
    final gold = row['gold'] as int? ?? 0;
    final right = mode.id == 'duello'
        ? (waiting || gold == 0 ? _grouped(score) : '+$gold')
        : _grouped(score);
    final rightLabel = mode.id == 'duello' && !waiting && gold > 0 ? _game.t('gold') : _game.t('score_word');
    return _card(
      child: Row(
        children: [
          _iconTile(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                if (bits.isNotEmpty)
                  Text(bits.join(' • '), style: const TextStyle(color: BilgiColors.muted, fontSize: 11)),
                Text(status, style: const TextStyle(color: BilgiColors.secondary, fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(right, style: const TextStyle(color: BilgiColors.secondary, fontWeight: FontWeight.w800)),
              Text(rightLabel, style: const TextStyle(color: BilgiColors.muted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _auth({required bool register}) {
    if (!register) return _login();
    return ListView(
      children: [
        _pageHeader(_game.t('register_page'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        _FormCard(
          title: _game.t('register_create'),
          fields: [_game.t('username'), _game.t('login_email'), _game.t('login_password')],
          secret: const {2},
          submit: _game.t('register_submit'),
          onSubmit: (values) => _game.register(values[0], values[1], values[2]),
        ),
      ],
    );
  }

  Widget _login() {
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _homeGold, width: 1.5),
    );
    const field = InputDecoration(
      filled: true,
      fillColor: Color(0xFF2A1048),
      border: fieldBorder,
      enabledBorder: fieldBorder,
      focusedBorder: fieldBorder,
    );
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('sign_in'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(_game.t('sign_in_sub'), textAlign: TextAlign.center, style: const TextStyle(color: BilgiColors.muted, fontSize: 14)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _loginEmail,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: field.copyWith(labelText: _game.t('login_email')),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _loginPassword,
            obscureText: _loginObscure,
            decoration: field.copyWith(
              labelText: _game.t('login_password'),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _loginObscure = !_loginObscure),
                icon: Icon(_loginObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _startButton(() => _game.login(_loginEmail.text, _loginPassword.text), label: _game.t('sign_in')),
        TextButton(onPressed: () => _game.open('forgot'), child: Text(_game.t('login_forgot'))),
        TextButton(onPressed: () => _game.open('register'), child: Text(_game.t('login_register'))),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Row(
            children: [
              const Expanded(child: Divider(color: Color(0xFF334155))),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(_game.t('login_or'), style: const TextStyle(color: BilgiColors.muted, fontWeight: FontWeight.w700)),
              ),
              const Expanded(child: Divider(color: Color(0xFF334155))),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton(
            onPressed: _game.loginGoogle,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: _homeGold, width: 1.5),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(_game.t('login_google')),
          ),
        ),
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: OutlinedButton(
              onPressed: _game.loginApple,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: _homeGold, width: 1.5),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(_game.t('login_apple')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _howTo() {
    final cfg = _game.config;
    final prices = cfg.jokerPrices;
    final days = [for (var i = 0; i < 7; i++) _game.rewardLabel(i)].join(', ');
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('how_to'), onBack: _game.back),
        _howtoBlock(_game.t('howto_play_h'), _game.t('howto_play')),
        _howtoBlock(
          _game.t('howto_gold_h'),
          _fill('howto_gold', {
            'gold': '${cfg.rewardedGold}',
            'half': '${prices['half'] ?? 50}',
            'double': '${prices['double'] ?? 75}',
            'time': '${prices['time'] ?? 60}',
            'change': '${prices['change'] ?? 100}',
            'hint': '${prices['hint'] ?? 80}',
            'life': '${cfg.lifePrice}',
          }),
        ),
        _howtoBlock(_game.t('howto_reward_h'), _fill('howto_reward', {'days': days})),
      ],
    );
  }

  Widget _howtoBlock(String title, String body) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _homeCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _homeGold, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 8),
              Text(body, style: const TextStyle(color: BilgiColors.muted, height: 1.4, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _forgot() {
    return ListView(
      children: [
        _pageHeader(_game.t('forgot_page'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(_game.t('forgot_body')),
        ),
        _FormCard(
          title: _game.t('forgot_title'),
          fields: [_game.t('login_email'), _game.t('field_code'), _game.t('field_new_password')],
          numeric: const {1},
          secret: const {2},
          submit: _game.t('forgot_submit'),
          secondaryLabel: _game.t('forgot_send'),
          onSecondary: (values) => _game.requestReset(values[0]),
          onSubmit: (values) => _game.confirmReset(values[0], values[1], values[2]),
        ),
      ],
    );
  }

  Widget _invite(BilgiProfile user) {
    return ListView(
      children: [
        _pageHeader(_game.t('invite_page'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(child: Text(_fill('invite_body', {'code': user.inviteCode, 'n': '${user.invites}'}))),
        ),
        _FormCard(
          title: _game.t('invite_enter'),
          fields: [_game.t('field_invite')],
          submit: _game.t('invite_accept'),
          onSubmit: (values) => _game.claimInvite(values[0]),
        ),
        if (user.friends.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text('👥 ${_game.t('invite_none')}')),
      ],
    );
  }

  Widget _legal() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('legal_page'), onBack: _game.back),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _game.t('legal_body'),
            style: const TextStyle(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _error() {
    final notice = _game.notice ?? _game.t('err_generic');
    final connection = notice == _game.t('err_offline') ||
        notice == _game.t('ad_fail') ||
        notice == _game.t('err_connection') ||
        notice.contains('Bağlantı') ||
        notice.contains('İnternet') ||
        notice.contains('Internet') ||
        notice.contains('internet');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              Text(connection ? '📡' : '⚠️', style: const TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
            Text(
                connection ? _game.t('err_connection') : _game.t('err_title'),
              textAlign: TextAlign.center,
                style: _homeInter(size: 22, weight: FontWeight.w900),
            ),
              const SizedBox(height: 10),
            Text(
                connection ? _game.t('err_connection_body') : notice,
              textAlign: TextAlign.center,
                style: _homeInter(size: 14, weight: FontWeight.w700, color: BilgiColors.muted, height: 1.4),
            ),
              const SizedBox(height: 16),
              _startButton(_game.retry, label: _game.t('retry'), horizontalPadding: 0),
          ],
          ),
        ),
      ),
    );
  }

  ({String icon, String amount, String unit}) _rewardParts(int index, {bool doubled = false}) {
    final mult = doubled ? 2 : 1;
    final gold = dayRewardAmount(_game.config.dailyGold, index) * mult;
    final diamond = dayRewardAmount(_game.config.dailyDiamond, index) * mult;
    final joker = dayRewardAmount(_game.config.dailyJoker, index) * mult;
    if (diamond > 0) return (icon: '💎', amount: '$diamond', unit: _game.t('diamond'));
    if (joker > 0) return (icon: '🎯', amount: '$joker', unit: _game.t('joker'));
    return (icon: '🪙', amount: '$gold', unit: _game.t('gold'));
  }

  Future<void> _claimWithBurst({required bool doubled}) async {
    if (_rewardBurst || _game.adWatching) return;
    if (doubled) {
      await _game.doubleDailyReward();
      return;
    }
    final icon = _rewardParts(_game.rewardIndex()).icon;
    final ok = await _game.claimDaily();
    if (!mounted || !ok) return;
    setState(() {
      _rewardBurst = true;
      _rewardBurstIcon = icon;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    if (_game.page == 'reward') _game.back();
    if (mounted) setState(() => _rewardBurst = false);
  }

  Widget _rewardCoinChip(String icon, String amount, String unit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x66FFB800)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(amount, style: const TextStyle(color: BilgiColors.warning, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text(unit, style: const TextStyle(color: BilgiColors.warning, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _reward() {
    final ready = _game.rewardReady() && !_rewardBurst;
    final index = _game.rewardIndex();
    final today = _rewardParts(index);
    final doubled = _rewardParts(index, doubled: true);
    return SizedBox.expand(
      child: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _modalCard(
                  children: [
                    if (_game.notice != null) _note(_game.notice!),
                    const Text('🎁', style: TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(_game.t('daily_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(_game.t('daily_sub'), textAlign: TextAlign.center, style: const TextStyle(color: BilgiColors.muted, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: _rewardDay(i, today: ready && i == index, done: i < index),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: _platedDim, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          Text(_game.t('daily_today'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: BilgiColors.muted)),
                          const SizedBox(height: 8),
                          _rewardCoinChip(today.icon, today.amount, today.unit),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BilgiWatchAdCard(
                      title: _game.t('daily_double'),
                      subtitle: '${doubled.icon} ${doubled.amount} ${doubled.unit}',
                      emphasizeSubtitle: true,
                      margin: EdgeInsets.zero,
                      buttonLabel: _game.t('ad_watch_btn'),
                      enabled: ready,
                      onWatch: () => _claimWithBurst(doubled: true),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: ready ? _homeGold : _homeCard,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _homeGold, width: ready ? 2 : 1.5),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: ready ? () => _claimWithBurst(doubled: false) : null,
                            borderRadius: BorderRadius.circular(bilgiRadius),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                ready ? _game.t('daily_claim') : _game.t('err_quota'),
                                textAlign: TextAlign.center,
                                style: _homeInter(
                                  size: 16,
                                  weight: FontWeight.w900,
                                  color: ready ? const Color(0xFF3A2200) : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    ),
                    TextButton(onPressed: _rewardBurst ? null : _game.back, child: Text(_game.t('close'))),
                  ],
                ),
              ),
            ),
          if (_rewardBurst) Positioned.fill(child: _RewardCoinBurst(icon: _rewardBurstIcon)),
        ],
      ),
    );
  }

  Widget _ad() {
    final premium = _game.profile != null && bilgiPlusActive(_game.profile!, DateTime.now());
    final busy = _game.adWatching;
    return ListView(
      children: [
        _pageHeader(_game.t('ad_gate_title'), onBack: busy ? null : _game.declinePreGameAd),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Text(
            premium ? _game.t('ad_gate_premium') : _game.t('ad_gate_body'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.35),
          ),
        ),
        if (premium)
          BilgiPrimaryButton(label: _game.t('ad_gate_pass'), onTap: busy ? null : () => _game.start(adCleared: true))
        else
          BilgiPrimaryButton(
            label: _game.t('ad_gate_watch'),
            onTap: busy ? null : () => unawaited(_game.watchPreGameAd()),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: busy ? null : _game.declinePreGameAd,
              child: Text(
                _game.t('ad_gate_wait'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: BilgiColors.info),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _jokerShop(BilgiProfile user) {
    return ListView(
      children: [
        _pageHeader(_game.t('bal_joker'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Text('🪙 ${user.gold}', textAlign: TextAlign.center),
        for (final entry in _game.config.jokerPrices.entries)
          _tile(
            _jokerEmoji(entry.key),
            _game.t('joker_${entry.key}'),
            _fill('joker_stock_line', {'price': '${entry.value}', 'n': '${user.jokers[entry.key] ?? 0}'}),
            () => _game.buyJoker(entry.key),
          ),
      ],
    );
  }

  Widget _noLives(BilgiProfile user) {
    return ListView(
      children: [
        _pageHeader(_game.t('bal_lives'), onBack: _game.back),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _note(bilgiNoLivesNotice(_game.config.lifeMinutes, locale: _game.locale)),
        ),
        if (_game.notice != null && !_game.notice!.contains('Canın bitti') && _game.notice != _game.t('err_lives_full')) _note(_game.notice!),
        _tile(
          '🪙',
          _game.t('nolives_fill'),
          _fill('nolives_now', {'price': '${_game.config.lifePrice}', 'n': '${user.lives}'}),
          _game.refill,
        ),
        _tile('🎬', _game.t('shop_ad_life'), _fill('nolives_limit', {'n': '${_game.config.rewardedLifeLimit}'}), () => _game.watchFor('life')),
      ],
    );
  }

  Widget _intro() {
    final steps = [
      ('1', _game.t('intro_step1_title'), _game.t('intro_step1_body')),
      ('2', _game.t('intro_step2_title'), _game.t('intro_step2_body')),
      ('3', _game.t('intro_step3_title'), _game.t('intro_step3_body')),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                    child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                Center(child: _BilgiLogo(size: 112, semanticLabel: _game.t('game_name'))),
                const SizedBox(height: 8),
                        Text(
                          _game.t('game_name'),
                          textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(
                  _game.t('intro_tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.1),
                ),
                const SizedBox(height: 4),
                Text(
                  _game.t('intro_sub'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: BilgiColors.muted, height: 1.2),
                ),
                const SizedBox(height: 16),
                        for (var i = 0; i < steps.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                          _introStep(steps[i].$1, steps[i].$2, steps[i].$3),
                        ],
                      ],
                    ),
                  ),
          const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _homeGold, width: 2.5),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _game.finishIntro,
                borderRadius: BorderRadius.circular(28),
                      child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    _game.t('intro_start'),
                    textAlign: TextAlign.center,
                    style: _homeInter(size: 16, weight: FontWeight.w900),
                  ),
                      ),
                    ),
                  ),
                ),
              ],
          ),
    );
  }

  Widget _introStep(String number, String title, String body) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _homeGold,
                ),
              child: Text(number, style: _homeInter(size: 16, weight: FontWeight.w900, color: const Color(0xFF3A2200))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(body, style: const TextStyle(fontSize: 12, color: BilgiColors.muted, height: 1.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _maintenance() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: _card(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              const Text('🔧', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 12),
              Text(_game.t('maint_title'), textAlign: TextAlign.center, style: _homeInter(size: 22, weight: FontWeight.w900)),
              const SizedBox(height: 10),
            Text(
                _game.t('maint_body'),
              textAlign: TextAlign.center,
                style: _homeInter(size: 14, weight: FontWeight.w700, color: BilgiColors.muted, height: 1.4),
            ),
          ],
          ),
        ),
      ),
    );
  }

  String _hintLine(BilgiQuestion? shown, String stored) {
    if (shown != null) {
      return bilgiPlayHint(
        hint: shown.hint,
        explanation: shown.explanation,
        options: shown.options,
        correct: shown.correct,
      );
    }
    return stored;
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(text, style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w700)),
    );
  }

  Widget _leaguePayoutCard(BilgiLeagueRewardNote reward) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_game.t('league_payout_title'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              _fill('league_payout_added', {'n': _grouped(reward.gold)}),
              style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (final line in reward.lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(line, style: const TextStyle(color: BilgiColors.muted)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  _game.notice = null;
                  _game.notifyListeners();
                },
                child: const Text('Tamam'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(String icon, String title, String subtitle, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _homeCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _homeGold, width: 2),
        ),
      child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
            borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Text(title, style: _homeInter(size: 15, weight: FontWeight.w800)),
                        Text(subtitle, style: _homeInter(size: 12, weight: FontWeight.w700, color: BilgiColors.muted)),
                    ],
                  ),
                ),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: child,
    );
  }

  bool _playDifficulty(String value) =>
      value == 'kolay' || value == 'orta' || value == 'zor' || value == 'efsane' || value == bilgiMixDifficulty;

  String _difficultyLabel(String value) => switch (value) {
        'orta' => _game.t('diff_medium'),
        'zor' => _game.t('diff_hard'),
        'efsane' => _game.t('diff_legend'),
        bilgiMixDifficulty => _game.t('diff_mix'),
        _ => _game.t('diff_easy'),
      };

  Widget _roundLoadingOverlay() {
    final mode = bilgiModeById(_game.modeId);
    final count = _game.playableCount() > 0 ? _game.playableCount() : _game.questionChoice;
    final category = _game.categories.where((item) => item.id == _game.categoryId).firstOrNull ??
        bilgiCategoryById(_game.categoryId);
    final tumu = _game.categoryId == tumuKarmaId || category == null;
    final categoryName = tumu
        ? _game.t('all_mix')
        : _game.categoryLabel(category.id, category.name);
    final categoryValue = tumu || _game.subName.isEmpty
        ? categoryName
        : '$categoryName · ${_game.subLabel(_game.categoryId, _game.subName)}';
    final diffKey = _playDifficulty(_game.difficulty) ? _game.difficulty : 'kolay';
    final timeValue = mode.totalSeconds > 0
        ? _fill('minutes', {'n': '${mode.totalSeconds ~/ 60}'})
        : mode.seconds == 0
            ? _game.t('untimed')
            : _fill('seconds', {'n': '${mode.seconds}'});
    final subtitle = '${_fill('q_count', {'n': '$count'})} · $timeValue';
    return BilgiRoundLoading(
      progress: _game.loadProgress,
      status: _game.t(_game.loadStatusKey),
      message: _game.t('questions_loading'),
      modeEmoji: mode.emoji,
      modeName: _game.t('mode_${mode.id}'),
      subtitle: subtitle,
      categoryLabel: _game.t('categories'),
      categoryValue: categoryValue,
      difficultyLabel: _game.t('difficulty'),
      difficultyValue: _difficultyLabel(diffKey),
      difficultyColor: const Color(0xFFFFD76A),
      questionsLabel: _game.t('question_count'),
      questionsValue: '$count',
      timeLabel: mode.totalSeconds > 0 ? _game.t('total_time') : _game.t('time_remaining'),
      timeValue: timeValue,
      questionCount: count,
      tip: _game.t(_game.loadTipKey),
      onCancel: _game.cancelRoundLoad,
    );
  }

  String _subEmoji(String sub, String fallback) {
    return switch (sub) {
      'İlk Türk Devletleri' => '🏹',
      'Selçuklu' => '⚔️',
      'Beylikler' => '🏰',
      'Kültür ve Medeniyet' => '📜',
      'Ünlü Türk Komutanlar' => '🎖️',
      _ => fallback.isEmpty ? '📌' : fallback,
    };
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Text(
        _display(text),
        style: _homeInter(size: 13, weight: FontWeight.w800, color: _homeGold, height: 1.1).copyWith(letterSpacing: 1.2),
      ),
    );
  }

  Widget _iconTile(String icon) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: _platedDim, borderRadius: BorderRadius.circular(12)),
      child: Text(icon, style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _subRow({required String icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            decoration: BoxDecoration(
              color: _homeCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _homeGold, width: 2),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _platedDim, borderRadius: BorderRadius.circular(12)),
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  subtitle,
                  maxLines: 1,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: BilgiColors.muted),
                ),
                const Icon(Icons.chevron_right_rounded, color: BilgiColors.muted, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _startButton(
    VoidCallback? onTap, {
    String? label,
    double horizontalPadding = 20,
    Color? fill,
    IconData? icon,
    bool goldBorder = false,
  }) {
    final text = label ?? _game.t('start_game');
    final gold = fill == null;
    final accent = fill ?? _homeGold;
    final radius = BorderRadius.circular(goldBorder ? 28 : 18);
    final labelColor = gold ? const Color(0xFF3A2200) : Colors.white;
    final labelStyle = _homeInter(size: 16, weight: FontWeight.w900, color: labelColor);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: gold ? _homeGold : null,
            gradient: gold
                ? null
                : LinearGradient(colors: [accent, Color.lerp(accent, Colors.white, 0.16)!]),
            borderRadius: radius,
            border: Border.all(color: _homeGold, width: goldBorder ? 2.5 : 2),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: goldBorder ? 16 : 18, horizontal: goldBorder ? 12 : 0),
                child: icon == null
                    ? Text(text, textAlign: TextAlign.center, style: labelStyle)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: labelColor, size: 26),
                          const SizedBox(width: 6),
                          Flexible(child: Text(text, textAlign: TextAlign.center, style: labelStyle)),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _adBanner({
    bool showNoticeAbove = true,
    EdgeInsets margin = const EdgeInsets.fromLTRB(20, 0, 20, 16),
  }) {
    if (!_game.config.bannerEnabled) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showNoticeAbove && _game.notice != null) _note(_game.notice!),
        _BilgiWatchAdCard(
          title: _game.t('ad_watch_title'),
          subtitle: _fill('ad_watch_sub', {'n': '${_game.config.rewardedGold}'}),
          buttonLabel: _game.t('ad_watch_btn'),
          margin: margin,
          onWatch: () => _game.watchFor('gold'),
        ),
      ],
    );
  }

  Widget _roundWalletStrip() {
    final profile = _game.profile;
    final items = profile == null
        ? const [
            _BalanceStat('🪙', '0', ''),
            _BalanceStat('💎', '0', ''),
            _BalanceStat('❤️', '0', ''),
            _BalanceStat('🃏', '0', ''),
          ]
        : _balanceItems(profile);
    return Row(
      children: [
        for (final item in items)
          Expanded(
            child: Text(
              '${item.icon} ${item.count}',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: BilgiColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
      ],
    );
  }

  Widget _quitButton() {
    return Material(
      color: _homeCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: _homeGold, width: 2),
      ),
      child: InkWell(
        onTap: _game.leaveRound,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Center(child: Text('✕', style: _homeInter(size: 16, weight: FontWeight.w800))),
        ),
      ),
    );
  }

  Widget _gameTimerChrome({required bool timed, required bool marathon, required BilgiRound round}) {
    final String label;
    final String value;
    final double? factor;
    if (timed) {
      label = _game.t('time_remaining');
      value = _fill('seconds', {'n': '${_game.secondsLeft}'});
      factor = round.seconds == 0 ? 0.0 : (_game.secondsLeft / round.seconds).clamp(0.0, 1.0);
    } else if (marathon) {
      label = _game.t('total_time');
      final m = _game.marathonLeft ~/ 60;
      final s = (_game.marathonLeft % 60).toString().padLeft(2, '0');
      value = '$m:$s';
      factor = round.totalSeconds == 0 ? 0.0 : (_game.marathonLeft / round.totalSeconds).clamp(0.0, 1.0);
    } else {
      label = _game.t('time_remaining');
      value = _game.t('untimed');
      factor = null;
    }
    final clock = timed || marathon;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (factor != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  const ColoredBox(color: Color(0xFF2A0E48), child: SizedBox.expand()),
                  FractionallySizedBox(
                    widthFactor: factor,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [_homeGold, Color(0xFF22C55E)]),
                      ),
                      child: SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Row(
          children: [
            Icon(
              clock ? Icons.timer_outlined : Icons.all_inclusive_rounded,
              size: 14,
              color: _homeGold,
            ),
            const SizedBox(width: 6),
            Text(label, style: _homeInter(size: 12, weight: FontWeight.w700, color: const Color(0xFFD4C4E8))),
            const Spacer(),
            Text(
              value,
              style: _homeInter(size: 13, weight: FontWeight.w800, color: clock ? _homeGold : const Color(0xFFD4C4E8)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _quizOption(String letter, String text, {required bool hidden, required bool correct, required bool wrong, required VoidCallback? onTap}) {
    return _BilgiQuizOption(
      letter: letter,
      text: text,
      hidden: hidden,
      correct: correct,
      wrong: wrong,
      onTap: onTap,
    );
  }

  Widget _jokerSpendNote(String type) {
    final stock = _game.profile?.jokers[type] ?? 0;
    final name = _game.t('joker_$type');
    final price = _game.config.jokerPrices[type] ?? 50;
    final text = stock > 0
        ? _fill('joker_spend_stock', {'name': name})
        : _fill('joker_spend_gold', {'n': '$price', 'name': name});
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(dismissible: false, color: Color(0xCC0F0E1A)),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _homeCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _homeGold, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: _homeInter(size: 16, weight: FontWeight.w700, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _jokerPrompt = null;
                              _jokerPromptIndex = null;
                            }),
                            style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFD4C4E8),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text(
                              _game.t('joker_cancel'),
                                style: _homeInter(size: 15, weight: FontWeight.w700, color: const Color(0xFFD4C4E8)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: _homeGold,
                                borderRadius: BorderRadius.circular(14),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _applyPromptedJoker,
                                  borderRadius: BorderRadius.circular(14),
                                  child: Center(
                                  child: Text(
                                    _game.t('joker_confirm'),
                                    textAlign: TextAlign.center,
                                      style: _homeInter(size: 15, weight: FontWeight.w900, color: const Color(0xFF3A2200)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _applyPromptedJoker() async {
    final type = _jokerPrompt;
    final index = _jokerPromptIndex;
    if (type == null) return;
    setState(() {
      _jokerPrompt = null;
      _jokerPromptIndex = null;
    });
    final stock = _game.profile?.jokers[type] ?? 0;
    if (stock <= 0) {
      await _game.buyJoker(type);
      if ((_game.profile?.jokers[type] ?? 0) <= 0) return;
    }
    final live = _game.round;
    if (live == null || live.finished || live.index != index) return;
    final beforeUse = _game.profile?.jokers[type] ?? 0;
    await _game.useJoker(type);
    if (!mounted) return;
    final afterUse = _game.profile?.jokers[type] ?? 0;
    if (afterUse < beforeUse) setState(() => _jokerBurst = type);
  }

  Widget _jokerButton(String emoji, String label, int stock, VoidCallback? onTap, {bool dim = false}) {
    return Opacity(
      opacity: dim ? 0.35 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 78,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
                width: double.infinity,
                height: 70,
                padding: const EdgeInsets.fromLTRB(2, 6, 2, 12),
              decoration: BoxDecoration(
                  color: _homeCard,
                borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _homeGold, width: 2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18, height: 1)),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                      style: _homeInter(size: 8, weight: FontWeight.w800, color: Colors.white, height: 1.05),
                  ),
                ],
              ),
            ),
            Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(child: _JokerConsumeBadge(stock: stock)),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ColoredBox(color: color, child: const SizedBox(height: 3, width: double.infinity)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: color, fontSize: 28, height: 1, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: BilgiColors.muted, fontSize: 14, height: 1, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuRow(String icon, String title, String subtitle, VoidCallback? onTap, {bool last = false, double? valueSize}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14FFFFFF)))),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: _homeInter(size: 14, weight: FontWeight.w700))),
            Text(
              subtitle,
              style: TextStyle(
                color: BilgiColors.muted,
                fontSize: valueSize ?? 12,
                fontWeight: valueSize == null ? FontWeight.w500 : FontWeight.w600,
              ),
            ),
            if (onTap != null) const Text(' ›', style: TextStyle(color: BilgiColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _toggleRow(String icon, String title, bool on, VoidCallback? onTap, {bool last = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14FFFFFF)))),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: _homeInter(size: 14, weight: FontWeight.w700))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(color: on ? _homeGold : const Color(0xFF2A1048), borderRadius: BorderRadius.circular(12)),
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(color: on ? const Color(0xFF3A2200) : Colors.white, shape: BoxShape.circle),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _homeCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _homeGold, width: 2),
      ),
      child: Column(children: children),
    );
  }

  Widget _rewardDay(int i, {required bool today, required bool done}) {
    final cfg = _game.config;
    final diamond = i < cfg.dailyDiamond.length ? cfg.dailyDiamond[i] : 0;
    final joker = i < cfg.dailyJoker.length ? cfg.dailyJoker[i] : 0;
    final icon = i == 6 ? '👑' : (diamond > 0 ? '💎' : (joker > 0 ? '🎯' : '🪙'));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: today ? _homeGold : (done ? const Color(0xFF3C1468) : _platedDim),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _homeGold, width: today ? 2 : 1.5),
      ),
      transform: today ? (Matrix4.identity()..scaleByDouble(1.08, 1.08, 1.08, 1)) : null,
      child: Column(
        children: [
          Text('${i + 1}', style: _homeInter(size: 11, weight: FontWeight.w800, color: today ? const Color(0xFF3A2200) : Colors.white)),
          Text(icon, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _podium(List<BilgiBoardEntry> top, String meId) {
    Widget place(BilgiBoardEntry user, int rank) {
      final mine = user.id == meId;
      final ring = mine
          ? BilgiColors.secondary
          : rank == 1
              ? const Color(0xFFFFB800)
              : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
      final height = rank == 1 ? 90.0 : (rank == 2 ? 60.0 : 40.0);
      return Expanded(
        child: Column(
          children: [
            Container(
              width: rank == 1 ? 64 : 52,
              height: rank == 1 ? 64 : 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: mine ? 4 : 3),
                color: mine ? BilgiColors.secondary.withValues(alpha: 0.22) : BilgiColors.card,
              ),
              child: Text(_boardAvatar(user, mine), style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 6),
            Text(
              _boardLabel(user, mine),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _homeInter(size: 12, weight: FontWeight.w700, color: mine ? _homeGoldText : Colors.white),
            ),
            Text(_grouped(user.score), style: _homeInter(size: 11, weight: FontWeight.w700, color: _homeGoldText)),
            const SizedBox(height: 6),
            Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: mine ? _homeGoldText : _homeGold,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Text('$rank', style: _homeInter(size: 20, weight: FontWeight.w900, color: const Color(0xFF3A2200))),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (top.length > 1) place(top[1], 2) else const Spacer(),
          if (top.isNotEmpty) place(top[0], 1) else const Spacer(),
          if (top.length > 2) place(top[2], 3) else const Spacer(),
        ],
      ),
    );
  }

  String _boardLabel(BilgiBoardEntry entry, bool mine) {
    if (!mine) return entry.name;
    final name = _game.profile?.username.trim() ?? '';
    return name.isEmpty ? entry.name : name;
  }

  String _boardAvatar(BilgiBoardEntry entry, bool mine) {
    if (!mine) return entry.avatar;
    final avatar = _game.profile?.avatar.trim() ?? '';
    return avatar.isEmpty ? entry.avatar : avatar;
  }

  Widget _boardRow(int rank, BilgiBoardEntry user, bool me) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: me ? _homeGold : _homeCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _homeGold, width: 2),
        ),
        child: Row(
          children: [
            Text('$rank', style: _homeInter(size: 14, weight: FontWeight.w900, color: me ? const Color(0xFF3A2200) : Colors.white)),
            const SizedBox(width: 10),
            Text(_boardAvatar(user, me), style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_boardLabel(user, me), style: _homeInter(size: 14, weight: FontWeight.w800, color: me ? const Color(0xFF3A2200) : Colors.white)),
                  if (user.leagueTitle.isNotEmpty)
                    Text(user.leagueTitle, style: _homeInter(size: 11, weight: FontWeight.w700, color: me ? const Color(0xFF5C3B00) : _homeGoldText))
                  else if (user.city.isNotEmpty)
                    Text(user.city, style: _homeInter(size: 11, weight: FontWeight.w700, color: me ? const Color(0xFF5C3B00) : const Color(0xFFD4C4E8))),
                ],
              ),
            ),
            Text(_grouped(user.score), style: TextStyle(color: me ? Colors.white : _homeGoldText, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  String _historyWhen(String raw) {
    final stamp = DateTime.tryParse(raw);
    if (stamp == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(stamp.year, stamp.month, stamp.day);
    final hhmm = '${stamp.hour.toString().padLeft(2, '0')}:${stamp.minute.toString().padLeft(2, '0')}';
    if (day == today) return _fill('when_today', {'time': hhmm});
    if (day == today.subtract(const Duration(days: 1))) return _fill('when_yesterday', {'time': hhmm});
    final days = today.difference(day).inDays;
    return _fill('when_days', {'n': '$days'});
  }
}

class _BalanceStat {
  const _BalanceStat(this.icon, this.count, this.name);

  final String icon;
  final String count;
  final String name;
}

class _PlayerBalanceRow extends StatelessWidget {
  const _PlayerBalanceRow({
    required this.items,
    this.dense = false,
    this.compactText = false,
    this.showNames = true,
    this.expand = true,
  });

  final List<_BalanceStat> items;
  final bool dense;
  final bool compactText;
  final bool showNames;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final iconSize = dense ? 14.0 : 15.0;
    final countSize = compactText ? 10.0 : (dense ? 12.0 : 12.0);
    final nameSize = compactText ? 9.0 : (dense ? 10.0 : 11.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(dense ? 0 : 8, 0, dense ? 0 : 8, dense ? 0 : 12),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              _balanceTile(items[i], iconSize, countSize, nameSize),
            ],
          ],
        ),
      ),
    );
  }

  Widget _balanceTile(_BalanceStat item, double iconSize, double countSize, double nameSize) {
    return Semantics(
      container: true,
      label: '${item.name} ${item.count}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(item.icon, style: TextStyle(fontSize: iconSize, height: 1)),
            const SizedBox(width: 4),
            Text(
              item.count,
              maxLines: 1,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: countSize, height: 1),
            ),
            if (showNames) ...[
              const SizedBox(width: 4),
              Text(
                item.name,
                maxLines: 1,
                style: TextStyle(color: BilgiColors.muted, fontWeight: FontWeight.w600, fontSize: nameSize, height: 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BilgiLogo extends StatelessWidget {
  const _BilgiLogo({required this.size, this.semanticLabel});

  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/luno_bilgi_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: semanticLabel ?? 'Luno Bilgi',
    );
  }
}

class _FormCard extends StatefulWidget {
  const _FormCard({
    required this.title,
    required this.fields,
    required this.submit,
    required this.onSubmit,
    this.initial = const [],
    this.secondaryLabel,
    this.onSecondary,
    this.secret = const {},
    this.numeric = const {},
  });

  final String title;
  final List<String> fields;
  final String submit;
  final void Function(List<String> values) onSubmit;
  final List<String> initial;
  final String? secondaryLabel;
  final void Function(List<String> values)? onSecondary;
  final Set<int> secret;
  final Set<int> numeric;

  @override
  State<_FormCard> createState() => _FormCardState();
}

class _FormCardState extends State<_FormCard> {
  late final List<TextEditingController> _fields = [
    for (var i = 0; i < widget.fields.length; i++)
      TextEditingController(text: i < widget.initial.length ? widget.initial[i] : ''),
  ];

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: _homeGold, width: 1.5),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _homeCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _homeGold, width: 2),
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: GoogleFonts.nunito(fontWeight: FontWeight.w900, fontSize: 16, color: _homeGoldText)),
          const SizedBox(height: 10),
          for (var i = 0; i < widget.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
              controller: _fields[i],
                keyboardType: widget.numeric.contains(i) ? TextInputType.number : null,
                obscureText: widget.secret.contains(i),
                style: GoogleFonts.nunito(color: Colors.white, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  labelText: widget.fields[i],
                  filled: true,
                  fillColor: const Color(0xFF2A1048),
                  border: fieldBorder,
                  enabledBorder: fieldBorder,
                  focusedBorder: fieldBorder,
                ),
              ),
            ),
          const SizedBox(height: 12),
          BilgiPrimaryButton(
            label: widget.submit,
            horizontalPadding: 0,
            onTap: () => widget.onSubmit([for (final field in _fields) field.text]),
          ),
          if (widget.onSecondary != null && widget.secondaryLabel != null)
            TextButton(
              onPressed: () => widget.onSecondary!([for (final field in _fields) field.text]),
              child: Text(widget.secondaryLabel!),
            ),
        ],
        ),
      ),
    );
  }
}

class _BilgiQuizOption extends StatefulWidget {
  const _BilgiQuizOption({
    required this.letter,
    required this.text,
    required this.hidden,
    required this.correct,
    required this.wrong,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool hidden;
  final bool correct;
  final bool wrong;
  final VoidCallback? onTap;

  @override
  State<_BilgiQuizOption> createState() => _BilgiQuizOptionState();
}

class _BilgiQuizOptionState extends State<_BilgiQuizOption> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
    if (widget.correct || widget.wrong) {
      _pulse.forward(from: 0);
    }
  }

  @override
  void didUpdateWidget(covariant _BilgiQuizOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    final became =
        (widget.correct && !oldWidget.correct) || (widget.wrong && !oldWidget.wrong);
    if (became) {
      _pulse.forward(from: 0);
    } else if (!widget.correct && !widget.wrong && _pulse.value != 0) {
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var border = _homeGold;
    var fill = _homeCard;
    var chip = _quizBlue;
    var letterColor = Colors.white;
    var textColor = Colors.white;
    var borderWidth = 2.0;
    if (widget.correct) {
      border = const Color(0xFF86EFAC);
      fill = _quizGreen;
      chip = _quizBlue;
    } else if (widget.wrong) {
      border = const Color(0xFFFECACA);
      fill = _quizRed;
      chip = _quizBlue;
    } else if (widget.hidden) {
      border = const Color(0x66FFC83D);
      fill = const Color(0xFF241038);
      chip = const Color(0xFF1E3A8A);
      textColor = BilgiColors.muted;
      borderWidth = 1.5;
    }
    final row = Material(
      color: fill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: border, width: borderWidth),
        ),
        child: InkWell(
          onTap: widget.hidden ? null : widget.onTap,
          borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 14 * 1.3 * 2 + 20),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: chip, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  widget.letter,
                  style: GoogleFonts.nunito(fontWeight: FontWeight.w800, color: letterColor),
                ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.hidden ? '—' : widget.text,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: textColor,
                    ),
                  ),
                ),
              const SizedBox(width: 44),
              ],
          ),
        ),
      ),
    );
    if (!widget.correct && !widget.wrong) return row;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeOutCubic.transform(_pulse.value);
        final bump = t < 0.5 ? t * 2 : (1 - t) * 2;
        if (widget.correct) {
          final scale = 1 + 0.04 * bump;
          return Transform.scale(
            scale: scale,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _quizGreen.withValues(alpha: 0.32 * bump),
                    blurRadius: 12 + 6 * bump,
                    spreadRadius: 0.5 * bump,
                  ),
                ],
              ),
              child: child,
            ),
          );
        }
        final dx = math.sin(t * math.pi * 5) * 5.5 * (1 - t);
        return Transform.translate(
          offset: Offset(dx, 0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: _quizRed.withValues(alpha: 0.28 * bump),
                  blurRadius: 10 + 4 * bump,
                  spreadRadius: 0.4 * bump,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: row,
    );
  }
}

class _JokerConsumeBadge extends StatelessWidget {
  const _JokerConsumeBadge({required this.stock});

  final int stock;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: _homeGold, shape: BoxShape.circle),
      child: Text(
        '$stock',
        style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF3A2500), height: 1),
      ),
    );
  }
}

/// Rising spend mark over the question after a joker is consumed.
class _JokerSpendBurst extends StatefulWidget {
  const _JokerSpendBurst({required this.emoji, required this.onDone});

  final String emoji;
  final VoidCallback onDone;

  @override
  State<_JokerSpendBurst> createState() => _JokerSpendBurstState();
}

class _JokerSpendBurstState extends State<_JokerSpendBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

  @override
  void initState() {
    super.initState();
    _motion.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, child) {
          final t = Curves.easeOut.transform(_motion.value);
          return Align(
            alignment: const Alignment(0, -0.15),
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, -48 * t), child: child),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.emoji, style: const TextStyle(fontSize: 36, height: 1)),
            const SizedBox(height: 4),
            const Text('−1', style: TextStyle(color: BilgiColors.error, fontSize: 42, fontWeight: FontWeight.w800, height: 1)),
          ],
        ),
      ),
    );
  }
}


class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    super.key,
    required this.text,
    this.onReport,
    required this.reportHint,
    required this.reportSend,
    required this.reportSending,
  });

  final String text;
  final Future<String?> Function(String note)? onReport;
  final String reportHint;
  final String reportSend;
  final String reportSending;

  @override
  Widget build(BuildContext context) {
    final report = onReport != null;
    return Stack(
      children: [
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 15 * 1.3 * 3 + 28),
          padding: EdgeInsets.fromLTRB(16, 14, report ? 40 : 16, 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _homeCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _homeGold, width: 2),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, height: 1.3, color: Colors.white),
          ),
        ),
        if (report)
          Positioned(
            right: 2,
            bottom: 2,
            child: IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: () {
                final send = onReport;
                if (send == null) return;
                showDialog<void>(
                  context: context,
                  barrierColor: const Color(0xCC0F0E1A),
                  builder: (context) => _ReportDialog(
                    onReport: send,
                    hint: reportHint,
                    sendLabel: reportSend,
                    sendingLabel: reportSending,
                  ),
                );
              },
              icon: const Icon(Icons.outlined_flag_rounded, color: _homeGold, size: 20),
            ),
          ),
      ],
    );
  }
}

class _QuizPopup extends StatelessWidget {
  const _QuizPopup({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: _homeCard,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: _homeGold, width: 2),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: height * 0.7),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 48, 18, 18),
              child: child,
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: _homeGold, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({
    required this.onReport,
    required this.hint,
    required this.sendLabel,
    required this.sendingLabel,
  });

  final Future<String?> Function(String note) onReport;
  final String hint;
  final String sendLabel;
  final String sendingLabel;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _note = TextEditingController();
  var _busy = false;
  var _message = '';
  var _sent = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _sent) return;
    final error = bilgiReportNoteError(_note.text);
    if (error != null) {
      setState(() => _message = error);
      return;
    }
    setState(() {
      _busy = true;
      _message = '';
    });
    final result = await widget.onReport(_note.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result == null) {
        _sent = true;
        _message = 'Bildiriminiz iletildi';
        _note.clear();
      } else {
        _message = result;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: _homeGold, width: 1.5),
    );
    return _QuizPopup(
      child: _sent
          ? Text(
              _message,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(color: _homeGoldText, fontSize: 16, fontWeight: FontWeight.w800, height: 1.35),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _note,
                  enabled: !_busy,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  cursorColor: _homeGold,
                  style: GoogleFonts.nunito(color: Colors.white, fontSize: 15, height: 1.35, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFF2A1048),
                    hintText: widget.hint,
                    hintStyle: const TextStyle(color: BilgiColors.muted, fontSize: 15, height: 1.35),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: fieldBorder,
                    enabledBorder: fieldBorder,
                    focusedBorder: fieldBorder,
                    disabledBorder: fieldBorder,
                  ),
                ),
                if (_message.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    _message,
                    style: GoogleFonts.nunito(color: BilgiColors.warning, fontSize: 13, fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  height: 44,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _busy ? const Color(0xFF8A7340) : _homeGold,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _busy ? null : _send,
                        borderRadius: BorderRadius.circular(14),
                        child: Center(
                          child: Text(
                            _busy ? widget.sendingLabel : widget.sendLabel,
                            style: GoogleFonts.nunito(color: const Color(0xFF3A2200), fontSize: 15, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Shop gold conversion question. True only when the player taps [confirmLabel].
Future<bool> showBilgiShopSpendPrompt(
  BuildContext context, {
  required String message,
  String confirmLabel = 'Tamam',
  String cancelLabel = 'Vazgeç',
}) async {
  final answer = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierColor: const Color(0xCC0F0E1A),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: _homeCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _homeGold, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
              ),
              const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
                    child: SizedBox(
                      height: 48,
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFD4C4E8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFD4C4E8)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _homeGold,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(dialogContext, true),
                            borderRadius: BorderRadius.circular(14),
                            child: Center(
                              child: Text(
                                confirmLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF3A2200)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ],
          ),
        ),
    );
    },
  );
  return answer == true;
}

class _AdRewardOverlay extends StatefulWidget {
  const _AdRewardOverlay({
    required this.icon,
    required this.amount,
    required this.caption,
    required this.loading,
    required this.closeLabel,
    required this.onClose,
  });

  final String icon;
  final String amount;
  final String caption;
  final bool loading;
  final String closeLabel;
  final VoidCallback onClose;

  @override
  State<_AdRewardOverlay> createState() => _AdRewardOverlayState();
}

class _AdRewardOverlayState extends State<_AdRewardOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xCC0F0E1A),
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: widget.closeLabel,
                onPressed: widget.onClose,
                iconSize: 36,
                padding: const EdgeInsets.all(12),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
            const Spacer(),
            AnimatedBuilder(
              animation: _motion,
              builder: (context, _) {
                final t = widget.loading ? _motion.value : 1.0;
                return SizedBox(
                  width: 220,
                  height: 160,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 6; i++)
                        Transform.translate(
                          offset: Offset(
                            math.cos((i / 6) * math.pi * 2 + t * math.pi * 2) * (widget.loading ? 72 : 78 * t),
                            math.sin((i / 6) * math.pi * 2 + t * math.pi * 2) * (widget.loading ? 48 : 56 * t),
                          ),
                          child: Text(widget.icon, style: const TextStyle(fontSize: 26)),
                        ),
                      if (widget.loading)
                        const SizedBox(
                          width: 42,
                          height: 42,
                          child: CircularProgressIndicator(strokeWidth: 3, color: BilgiColors.warning),
                        )
                      else
                        Text(widget.amount, style: const TextStyle(color: BilgiColors.warning, fontSize: 36, fontWeight: FontWeight.w900)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                widget.caption,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class _RewardCoinBurst extends StatefulWidget {
  const _RewardCoinBurst({required this.icon});

  final String icon;

  @override
  State<_RewardCoinBurst> createState() => _RewardCoinBurstState();
}

class _RewardCoinBurstState extends State<_RewardCoinBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOutCubic.transform(_controller.value);
          final fade = _controller.value < 0.72 ? 1.0 : (1 - (_controller.value - 0.72) / 0.28).clamp(0.0, 1.0);
          return ColoredBox(
            color: const Color(0x660F0E1A),
            child: Center(
              child: SizedBox(
                width: 220,
                height: 180,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (var i = 0; i < 8; i++)
                      Transform.translate(
                        offset: Offset(math.cos(i * math.pi / 4) * 78 * t, math.sin(i * math.pi / 4) * 62 * t - 18 * t),
                        child: Opacity(
                          opacity: fade,
                          child: Text(widget.icon, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BilgiWatchAdCard extends StatefulWidget {
  const _BilgiWatchAdCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onWatch,
    this.emphasizeSubtitle = false,
    this.enabled = true,
    this.margin = const EdgeInsets.fromLTRB(20, 0, 20, 16),
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final Future<void> Function() onWatch;
  final bool emphasizeSubtitle;
  final bool enabled;
  final EdgeInsets margin;

  @override
  State<_BilgiWatchAdCard> createState() => _BilgiWatchAdCardState();
}

class _BilgiWatchAdCardState extends State<_BilgiWatchAdCard> {
  var _busy = false;

  Future<void> _tap() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onWatch();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _watchButton() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFC83D),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF3A2500)),
              )
            : Text(
                widget.buttonLabel,
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.nunito(
                  color: const Color(0xFF3A2500),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  height: 1,
                ),
              ),
      ),
    );
  }

  Widget _emphasizedRewardChip(String subtitle) {
    final parts = subtitle.split(' ');
    final icon = parts.isEmpty ? '' : parts.first;
    final amount = parts.length > 1 ? parts[1] : '';
    final unit = parts.length > 2 ? parts.sublist(2).join(' ') : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: BilgiColors.bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x66FFB800)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Text(amount, style: const TextStyle(color: BilgiColors.warning, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(width: 6),
          Text(unit, style: const TextStyle(color: BilgiColors.warning, fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin,
      child: Material(
        color: const Color(0xFF3C1468),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: _busy || !widget.enabled ? null : _tap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFFFC83D), width: 2),
            ),
            child: widget.emphasizeSubtitle
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.card_giftcard_rounded, color: BilgiColors.warning, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.title,
                              style: GoogleFonts.nunito(color: const Color(0xFFFFD76A), fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          const SizedBox(width: 12),
                          _watchButton(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Center(child: _emphasizedRewardChip(widget.subtitle)),
                    ],
                  )
                : Row(
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: BilgiColors.warning, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: GoogleFonts.nunito(color: const Color(0xFFFFD76A), fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                            Text(
                              widget.subtitle,
                              style: GoogleFonts.nunito(
                                color: Colors.white,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _watchButton(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class BilgiBootProgress extends StatelessWidget {
  const BilgiBootProgress({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.nunito(color: _homeGoldText, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 220,
          child: LinearProgressIndicator(
            minHeight: 6,
            color: _homeGold,
            backgroundColor: _homeCard,
            borderRadius: BorderRadius.all(Radius.circular(6)),
          ),
        ),
      ],
    );
  }
}

class _CategoryStackIcon extends StatelessWidget {
  const _CategoryStackIcon();

  @override
  Widget build(BuildContext context) {
    Widget card(Color color, double left, double top) {
      return Positioned(
        left: left,
        top: top,
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      );
    }

    return SizedBox(
      width: 22,
      height: 22,
      child: Stack(
        children: [
          card(const Color(0xFF3DDC97), 0, 6),
          card(const Color(0xFF5B8CFF), 4, 3),
          card(const Color(0xFFFF6B9D), 8, 0),
        ],
      ),
    );
  }
}

class _ContestClock extends StatefulWidget {
  const _ContestClock();

  @override
  State<_ContestClock> createState() => _ContestClockState();
}

class _SpecialEventTag extends StatelessWidget {
  const _SpecialEventTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x33F59E0B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x66F59E0B)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.celebration, size: 14, color: Color(0xFFFBBF24)),
          SizedBox(width: 4),
          Text(
            bilgiSpecialEventGroup,
            style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ContestClockState extends State<_ContestClock> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      bilgiContestClock(bilgiContestRemaining(DateTime.now())),
      style: GoogleFonts.nunito(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.w900,
        height: 1,
        shadows: const [Shadow(color: Color(0xFF1E3A8A), offset: Offset(2, 3), blurRadius: 0)],
      ),
    );
  }
}
