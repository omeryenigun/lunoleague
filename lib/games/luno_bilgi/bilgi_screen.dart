import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_controller.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_language_page.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_opening_loader.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_profile_name.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_round_loading.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_shop.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';
import 'package:kelimelig/injection.dart';

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
  bool _rewardBurst = false;
  String _rewardBurstIcon = '🪙';
  String _leagueSort = bilgiLeagueSortAlpha;
  String? _linkedDisplayName;
  String? _profileNameKey;
  final _shopGoldKey = GlobalKey();
  int _goldHelpSeen = 0;
  bool _goldDialogOpen = false;
  bool _goldHelpQueued = false;

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

  /// Active categories whose approved count is loaded and at least [bilgiMinPublishedQuestions].
  List<BilgiCategory> get _listedCategories => [
        for (final category in _game.categories)
          if (bilgiCategoryListed(category.id, _game.categoryCounts[category.id])) category,
      ];

  @override
  Widget build(BuildContext context) {
    final user = _game.profile;
    return Theme(
      data: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: BilgiColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: BilgiColors.primary,
          surface: BilgiColors.card,
        ),
        textTheme: const TextTheme(bodyMedium: TextStyle(color: BilgiColors.text, fontSize: 14)),
      ),
      child: Scaffold(
        backgroundColor: BilgiColors.bg,
        body: BilgiChrome(
          child: _openingOrApp(user),
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
                    closeLabel: 'Kapat',
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
      'categories' || 'detail' || 'setup' || 'group' || 'room' => 'play',
      'achievements' => 'profile',
      'league_rewards' => 'league',
      _ => _game.page,
    };
  }

  Widget _page(BilgiProfile? user) {
    if (user == null && _game.page != 'maintenance' && _game.page != 'language') {
      return Center(child: BilgiBootProgress(label: _game.t('loading')));
    }
    return switch (_game.page) {
      'intro' => _intro(),
      'maintenance' => _maintenance(),
      'play' => _modes(),
      'categories' => _categories(),
      'detail' => _detail(),
      'setup' => _setup(),
      'game' => _game.round?.modeId == 'gunluk' ? _daily() : _gamePage(),
      'result' => _result(),
      'league' => _league(user!),
      'league_rewards' => _leagueRewards(),
      'profile' => _profile(user!),
      'shop' => _shop(user!),
      'duel' => _duel(),
      'group' => _group(),
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
  }

  Widget _home(BilgiProfile user) {
    final ready = _game.rewardReady();
    final reward = _game.rewardLabel(_game.rewardIndex());
    final solo = bilgiModes.where((mode) => mode.group == 'solo').toList();
    final listed = _listedCategories;
    final popular = [for (final category in listed) if (category.popular) category];
    final dailyLine = ready
        ? (user.streak > 0 ? _fill('streak_line', {'n': '${user.streak}', 'reward': reward}) : reward)
        : _fill('reward_tomorrow', {'reward': reward});
    const bannerShadow = BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.3), blurRadius: 24, offset: Offset(0, 8));
    const cardShadow = BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.25), blurRadius: 20, offset: Offset(0, 8));
    const hairline = Color.fromRGBO(255, 255, 255, 0.1);
    return Column(
      children: [
            _pageHeader(_game.t('game_name')),
            Expanded(
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 20),
                  children: [
                    if (_game.notice != null) _note(_game.notice!),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF6D4AFF), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: hairline),
                          boxShadow: const [bannerShadow],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ready ? '🎁 ${_game.t('reward_ready')}' : '🎁 ${_game.t('reward_title')}',
                                      style: _homeInter(size: 14, weight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dailyLine,
                                      style: _homeInter(
                                        size: 11,
                                        weight: FontWeight.w500,
                                        color: const Color.fromRGBO(255, 255, 255, 0.85),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              _homePillButton(
                                label: _game.t('claim'),
                                onTap: () => _game.open('reward'),
                                background: const Color.fromRGBO(255, 255, 255, 0.2),
                                foreground: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF059669), Color(0xFF10B981)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: hairline),
                          boxShadow: const [bannerShadow],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _game.t('free_play'),
                                  style: _homeInter(size: 14, weight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _homePillButton(
                                label: _game.t('play_now'),
                                onTap: () {
                                  _game.modeId = 'hizli';
                                  _game.categoryId = tumuKarmaId;
                                  _game.difficulty = 'hepsi';
                                  _game.start();
                                },
                                background: Colors.white,
                                foreground: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    _sectionTitle(_game.t('quick_start'), _game.t('see_all'), () => _game.tab('play')),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.72,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      children: [
                        for (final mode in solo)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: _quickStartGradient(mode.id),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: hairline),
                              boxShadow: const [cardShadow],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => _game.selectMode(mode.id),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: Container(
                                          width: 40,
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: const Color.fromRGBO(255, 255, 255, 0.34),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.72)),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color.fromRGBO(0, 0, 0, 0.18),
                                                blurRadius: 8,
                                                offset: Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Text(mode.emoji, style: const TextStyle(fontSize: 24, height: 1)),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _game.t('mode_${mode.id}'),
                                        style: _homeInter(size: 14, weight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _modeLine(mode),
                                        style: _homeInter(
                                          size: 11,
                                          weight: FontWeight.w500,
                                          color: const Color.fromRGBO(255, 255, 255, 0.85),
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
                    if (popular.isNotEmpty) ...[
                      _sectionTitle(
                        _game.t('popular'),
                        _game.t('see_all'),
                        () => _game.open('categories'),
                        accent: const Color(0xFFE91E63),
                      ),
                      GridView.count(
                        crossAxisCount: 4,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        children: [
                          for (final category in popular)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color.fromRGBO(255, 255, 255, 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
                                boxShadow: const [
                                  BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.15), blurRadius: 12, offset: Offset(0, 4)),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => _game.selectCategory(category.id),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: 32,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            color: Color.fromRGBO(255, 255, 255, 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(category.emoji, style: const TextStyle(fontSize: 14, height: 1)),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          _game.categoryLabel(category.id, category.name),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: _homeInter(
                                            size: 10,
                                            weight: FontWeight.w600,
                                            color: const Color(0xFF8B949E),
                                            height: 1.15,
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
                    ],
                    Padding(
                      padding: EdgeInsets.fromLTRB(20, popular.isNotEmpty ? 24 : 20, 20, 0),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(123, 97, 255, 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color.fromRGBO(123, 97, 255, 0.5)),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _game.open('categories'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                              child: Text(
                                '📚 ${_fill('see_categories', {'n': '${listed.length}'})}',
                                textAlign: TextAlign.center,
                                style: _homeInter(size: 13, weight: FontWeight.w600, color: const Color(0xFF9B85FF)),
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
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFF472B6), Color(0xFFFB923C)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.2)),
                          boxShadow: const [
                            BoxShadow(color: Color.fromRGBO(244, 114, 182, 0.3), blurRadius: 24, offset: Offset(0, 8)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color.fromRGBO(255, 255, 255, 0.25),
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      child: Text(
                                        _game.t('weekly'),
                                        style: _homeInter(size: 10, weight: FontWeight.w700),
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
                                background: Colors.white,
                                foreground: const Color(0xFFBE185D),
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                                fontSize: 13,
                                shadow: const BoxShadow(
                                  color: Color.fromRGBO(0, 0, 0, 0.15),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
    );
  }

  TextStyle _homeInter({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = Colors.white,
    double? height,
  }) {
    return GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, height: height);
  }

  Widget _pageHeader(String title, {VoidCallback? onBack, bool balanceLabels = false}) {
    final user = _game.profile;
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
                if (user != null) ...[
                  const SizedBox(width: 8),
                  _homeStatPills(user, labeled: balanceLabels),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeStatPills(BilgiProfile user, {bool labeled = false}) {
    final items = _balanceItems(user);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Semantics(
            container: true,
            label: '${items[i].name} ${items[i].count}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(items[i].icon, style: const TextStyle(fontSize: 13, height: 1)),
                      const SizedBox(width: 3),
                      Text(items[i].count, maxLines: 1, style: _homeInter(size: 10, weight: FontWeight.w700, height: 1)),
                    ],
                  ),
                  if (labeled) ...[
                    const SizedBox(height: 1),
                    Text(
                      items[i].name,
                      maxLines: 1,
                      style: _homeInter(size: 8, weight: FontWeight.w600, height: 1, color: BilgiColors.muted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _homePillButton({
    required String label,
    required VoidCallback onTap,
    required Color background,
    required Color foreground,
    required EdgeInsets padding,
    double fontSize = 12,
    BoxShadow? shadow,
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
            child: Text(label, style: _homeInter(size: fontSize, weight: FontWeight.w700, color: foreground)),
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
      'hizli' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
      'klasik' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFF6D28D9), Color(0xFF8B5CF6)]),
      'maraton' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFFBE185D), Color(0xFFEC4899)]),
      'sakin' => const LinearGradient(begin: begin, end: end, colors: [Color(0xFFB45309), Color(0xFFF59E0B)]),
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

  Widget _sectionTitle(String title, String action, VoidCallback onTap, {Color accent = const Color(0xFF7B61FF)}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: _homeInter(size: 15, weight: FontWeight.w700)),
          ),
          Material(
            color: const Color.fromRGBO(123, 97, 255, 0.15),
            borderRadius: BorderRadius.circular(50),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(50),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(action, style: _homeInter(size: 12, weight: FontWeight.w600, color: const Color(0xFF9B85FF))),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_rounded, size: 12, color: Color(0xFF9B85FF)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modes() {
    final solo = [for (final mode in bilgiModes) if (mode.group == 'solo') mode];
    final multi = [for (final mode in bilgiModes) if (mode.group == 'multi' && mode.id != 'grup') mode];
    final special = [for (final mode in bilgiModes) if (mode.group == 'special') mode];
    final categoryCount = _listedCategories.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('page_play')),
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
      ],
    );
  }

  Widget _playHeading(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFB7B4C9),
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _modeCard(BilgiMode mode) {
    final badge = switch (mode.id) {
      'hizli' || 'duello' => _game.t('badge_popular'),
      'gunluk' => _game.t('badge_daily'),
      _ => null,
    };
    final badgeColor = mode.id == 'hizli' || mode.id == 'duello' ? const Color(0xFFFF5C93) : BilgiColors.secondary;
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: const Color(0xFF1C1A33),
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
                    color: const Color(0xFF12101C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: icon,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.15)),
                      const SizedBox(height: 3),
                      Text(subtitle, style: const TextStyle(color: Color(0xFF8E8AA3), fontSize: 12, height: 1.2)),
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
              color: BilgiColors.card,
              borderRadius: BorderRadius.circular(12),
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
                      _groupLabel(group),
                      style: const TextStyle(
                        color: BilgiColors.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [for (final category in rows) _categoryCard(category)],
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
    if (named != group) return named;
    const letters = {'i': 'İ', 'ı': 'I', 'ş': 'Ş', 'ğ': 'Ğ', 'ü': 'Ü', 'ö': 'Ö', 'ç': 'Ç'};
    final buffer = StringBuffer();
    for (final char in group.split('')) {
      buffer.write(letters[char] ?? char.toUpperCase());
    }
    return buffer.toString();
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
            gradient: karma
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [BilgiColors.primary, BilgiColors.primaryLight],
                  )
                : null,
            color: karma ? null : BilgiColors.card,
            borderRadius: BorderRadius.circular(bilgiRadius),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 28)),
                const Spacer(),
                Text(_game.categoryLabel(category.id, category.name), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(line, style: TextStyle(fontSize: 11, color: karma ? const Color(0xE6FFFFFF) : BilgiColors.muted)),
                if (!karma) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => _game.playCategoryLeague(category.id),
                    child: Text(
                      _game.joinedCategoryLeague(category.id) ? 'Lige devam et' : 'Lige Katıl',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: BilgiColors.secondary),
                    ),
                  ),
                ],
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
    final countsReady = _game.subCounts.isNotEmpty;
    final subs = !countsReady
        ? allSubs
        : [
            for (final sub in allSubs)
              if ((_game.subCounts['${_game.categoryId}|$sub'] ?? 0) >= bilgiMinPublishedQuestions) sub,
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
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [BilgiColors.primary, BilgiColors.primaryLight],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 56)),
                    const SizedBox(height: 12),
                    Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(heroSub, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: Color(0xE6FFFFFF))),
                  ],
                ),
              ),
              _sectionLabel(_game.t('subcategories')),
              _subRow(
                icon: '🎲',
                title: tumu ? _game.t('all_mix') : _game.categoryLabel(category.id, category.name),
                subtitle: _game.t('mixed_subs'),
                karma: true,
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
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              if (_game.notice != null) _note(_game.notice!),
              _setupSelection(),
              _sectionLabel(_game.t('difficulty').toUpperCase()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: Row(
                  children: [
                    for (final item in diffs)
                      Expanded(
                        child: _setupDiffChip(
                          color: item.$1,
                          label: item.$2,
                          active: highlight == item.$3,
                          onTap: () => _game.selectDifficulty(item.$3),
                        ),
                      ),
                  ],
                ),
              ),
              _sectionLabel(_game.t('question_count').toUpperCase()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: BilgiColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (final count in const [10, 20, 50])
                          Expanded(
                            child: _setupCountSeg(
                              count: count,
                              active: _game.questionChoice == count,
                              onTap: () => _game.selectQuestionChoice(count),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (countMismatch != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 6, 20, 0),
                  child: Text(countMismatch, style: const TextStyle(color: BilgiColors.muted, fontSize: 11)),
                ),
              _sectionLabel(_game.t('mode_section').toUpperCase()),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: BilgiColors.card,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        for (final item in modes)
                          Expanded(
                            child: _setupModeSeg(
                              emoji: item.$1,
                              label: item.$2,
                              active: modeId == item.$3,
                              onTap: () => _game.selectPlayMode(item.$3),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _startButton(_game.busy ? null : _game.start, label: _game.t('start_game')),
        const SizedBox(height: 10),
      ],
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Column(
        children: [
          _setupPick(catIcon, catName),
          const SizedBox(height: 8),
          _setupPick(subIcon, subTitle, color: const Color(0xFF2C2948)),
        ],
      ),
    );
  }

  Widget _setupPick(String icon, String title, {Color color = BilgiColors.card}) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(bilgiRadius)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
          ],
        ),
      ),
    );
  }

  Widget _setupDiffChip({
    required Color color,
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              gradient: active
                  ? const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight])
                  : null,
              color: active ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
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

  Widget _setupCountSeg({
    required int count,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight])
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: active ? Colors.white : BilgiColors.muted,
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
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight])
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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
    );
  }

  Widget _gamePage() {
    final round = _game.round;
    final revealing = _game.revealing;
    final question = round?.current;
    if (round == null || (question == null && !revealing)) {
      return Center(child: BilgiBootProgress(label: _game.t('questions_loading')));
    }
    final letters = ['A', 'B', 'C', 'D'];
    final source = revealing ? _game.revealQuestion : question;
    final shown = source?.shown(_game.locale);
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
                            style: const TextStyle(color: BilgiColors.secondary, fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: ' / $total',
                            style: const TextStyle(color: BilgiColors.text, fontSize: 18, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _game.t('hdr_question'),
                      style: const TextStyle(
                        color: BilgiColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: BilgiColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: BilgiColors.warning, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${round.score}',
                      style: const TextStyle(color: BilgiColors.text, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _questionSegments(current: number, total: total),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _headerChip(
                  label: categoryName.toUpperCase(),
                  dot: BilgiColors.secondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _headerChip(
                  label: difficulty.toUpperCase(),
                  dot: _difficultyDot(difficultyKey),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _headerChip(
                  label: modeName.toUpperCase(),
                  dot: BilgiColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _gameTimerChrome(timed: timed, marathon: marathon, round: round),
          if (round.standings.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  for (final seat in round.standings)
                    Text(
                      '${seat['name']} • ${seat['score'] ?? '0'}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: seat['id'] == round.userId ? BilgiColors.secondary : BilgiColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            )
          else if (round.opponentName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${_game.t('rival')}: ${round.opponentName}${round.opponentScore >= 0 ? ' • ${round.opponentScore}' : ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BilgiColors.muted, fontSize: 12),
              ),
            ),
          if (round.paused) ...[
            const SizedBox(height: 8),
            _note('Süre durdu • ${_game.pauseLeft} sn'),
          ],
          if (round.hint.isNotEmpty) ...[
            const SizedBox(height: 8),
            _note(_hintLine(shown, round.hint)),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(16)),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_game.t('hdr_question')} ${number.toString().padLeft(2, '0')}',
                            style: const TextStyle(
                              color: BilgiColors.secondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.5)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < options.length; i++) ...[
                  _quizOption(
                    letters[i],
                    options[i],
                    hidden: !revealing && round.hidden.contains(i),
                    correct: revealing && i == _game.revealCorrect,
                    wrong: revealing && i == _game.lastPick && i != _game.revealCorrect,
                    onTap: revealing || round.hidden.contains(i) || _game.picked ? null : () => _game.pick(i),
                  ),
                  if (i < options.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          if (revealing && _game.revealQuestion != null) ...[
            const SizedBox(height: 12),
            BilgiPrimaryButton(label: _game.t('continue_btn'), onTap: _game.continueReveal),
            const SizedBox(height: 4),
            _FaultReport(
              key: ValueKey(_game.revealQuestion!.id),
              onSubmit: _game.reportReveal,
            ),
          ],
          const SizedBox(height: 12),
          if (_game.notice != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(_game.notice!, style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w700)),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final item in const [
                  ('half', '✂️'),
                  ('double', '👥'),
                  ('time', '⏸️'),
                  ('change', '🔄'),
                  ('hint', '💡'),
                ])
                  _jokerButton(
                    item.$2,
                    _game.t('joker_${item.$1}'),
                    _game.profile?.jokers[item.$1] ?? 0,
                    round.jokersUsed >= round.jokerMax
                        ? null
                        : () => setState(() {
                              _jokerPrompt = item.$1;
                              _jokerPromptIndex = round.index;
                            }),
                  ),
              ],
            ),
          ),
            ],
          ),
        ),
        if (_jokerPrompt != null)
          Positioned.fill(child: _jokerSpendNote(_jokerPrompt!)),
      ],
    );
  }

  Widget _result() {
    final round = _game.round;
    if (round == null) return const Center(child: Text('📊 Puanın hesaplanıyor...'));
    final mode = bilgiModeById(round.modeId);
    final won = round.correct > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (_game.notice != null) _note(_game.notice!),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [BilgiColors.primary, BilgiColors.primaryLight],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(won ? '🎉' : '🎮', style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(won ? _game.t('result_great') : _game.t('result_done'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(_game.t('mode_${mode.id}'), style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
              if (round.standings.length > 1) ...[
                const SizedBox(height: 12),
                for (final seat in round.standings)
                  Text(
                    '${seat['name']} • ${seat['score'] ?? '0'}',
                    style: const TextStyle(color: Color(0xE6FFFFFF), fontWeight: FontWeight.w700),
                  ),
              ],
              const SizedBox(height: 16),
              Text(_grouped(round.score), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, color: BilgiColors.secondary, height: 1)),
              const SizedBox(height: 6),
              const Text('TOPLAM PUAN', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _statBox(_game.t('correct'), '${round.correct}', BilgiColors.secondary)),
            const SizedBox(width: 10),
            Expanded(child: _statBox(_game.t('wrong'), '${round.wrong}', BilgiColors.error)),
            const SizedBox(width: 10),
            Expanded(child: _statBox('Hız Bonusu', '+${round.timeBonus}', BilgiColors.warning)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [BilgiColors.warning, BilgiColors.error]),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('📺 Puanını 2x Yap!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    SizedBox(height: 4),
                  ],
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: BilgiColors.error,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _game.scoreDoubled || _game.adWatching ? null : _game.doubleResultScore,
                child: const Text('İzle', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 16),
          child: Text(
            _game.scoreDoubled ? 'Puan ikiye katlandı.' : '+${_grouped(round.score)} ekstra puan için reklam izle',
            style: const TextStyle(color: BilgiColors.muted, fontSize: 12),
          ),
        ),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('KAZANILAN ÖDÜLLER', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: BilgiColors.muted)),
              const SizedBox(height: 12),
              Text('🪙 Altın +${round.gold}', style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('✨ Deneyim +${round.xp} XP', style: const TextStyle(fontWeight: FontWeight.w700)),
              for (final badge in bilgiBadges)
                if (_game.newBadgeIds.contains(badge.id))
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${badge.emoji} ${badge.name}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _startButton(_game.replaySetup, label: _game.t('play_again_btn')),
        const SizedBox(height: 16),
        _adBanner(showNoticeAbove: false),
      ],
    );
  }

  Widget _league(BilgiProfile user) {
    final rows = _game.boardRows;
    final podium = rows.take(3).toList();
    final rest = rows.length > 3 ? rows.sublist(3) : const <BilgiBoardEntry>[];
    final categoryOpen = _game.boardScope == 'category' && _game.boardCategoryId != null;
    final showPeriod = _game.boardScope == 'general' || categoryOpen;
    final heading = _leagueHeading();
    final periodScore = bilgiLeaguePeriodScore(
      user,
      weekly: _game.boardWeekly,
      categoryId: categoryOpen ? _game.boardCategoryId : null,
    );
    final periodRank = bilgiMyBoardRank(rows, user.id);
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('page_league')),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              for (final item in const [
                ('Genel Lig', 'general'),
                ('Kategori Ligleri', 'category'),
              ])
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: item.$2 == 'general' ? 8 : 0),
                    child: Material(
                      color: _game.boardScope == item.$2 ? BilgiColors.primary : BilgiColors.card,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          _game.boardScope = item.$2;
                          if (item.$2 == 'category') _game.boardCategoryId = null;
                          _game.loadBoard();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          child: Text(
                            item.$1,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: _game.boardScope == item.$2 ? Colors.white : BilgiColors.muted,
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
              Expanded(
                child: Text(heading, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              ),
              if (heading == 'Kategori Ligleri')
                IconButton(
                  tooltip: 'Lig Ödülleri',
                  onPressed: () => _game.open('league_rewards'),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  icon: const Icon(Icons.emoji_events, color: BilgiColors.secondary),
                ),
            ],
          ),
        ),
        if (showPeriod) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _leaguePeriodChip('Bu hafta', true),
                const SizedBox(width: 8),
                _leaguePeriodChip('Tüm zamanlar', false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              bilgiMyRankLabel(score: periodScore, rank: periodRank),
              style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary),
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
                          _game.selectCategory(categoryId);
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
                              ? 'Lige Katıl'
                              : 'Lige devam et',
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
        if (_game.leagueTitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(_game.leagueTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        if (_game.boardScope == 'category' && _game.boardCategoryId == null)
          ..._leagueCategories()
        else
          ..._leagueRows(user.id, podium, rest, rows.isEmpty),
        const SizedBox(height: 16),
        _adBanner(),
      ],
    );
  }

  String _leagueHeading() {
    if (_game.boardScope != 'category') return 'Genel Lig';
    if (_game.boardCategoryId == null) return 'Kategori Ligleri';
    final name = (bilgiCategoryById(_game.boardCategoryId!)?.name ?? 'Kategori').trim();
    if (name.endsWith('Ligi')) return name;
    return '$name Ligi';
  }

  Widget _leagueRewards() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader('Lig Ödülleri', onBack: _game.back),
        _leagueRewardCard(
          'Doğru cevap',
          [
            _leagueRewardNote('Doğru cevap: zorluk puanı × mod katsayısı, artı süre bonusu, artı seri.'),
            _leagueRewardPay('Kolay', _grouped(10)),
            _leagueRewardPay('Orta', _grouped(15)),
            _leagueRewardPay('Zor', _grouped(25)),
            _leagueRewardPay('Efsane', _grouped(40)),
            _leagueRewardPay('Hızlı', '×1,5'),
            _leagueRewardPay('Klasik, Düello, Grup', '×1'),
            _leagueRewardPay('Özel oda, Luno Ligi', '×1'),
            _leagueRewardPay('Maraton, Günün Sorusu', '×2'),
            _leagueRewardPay('Sakin', '×0,5'),
            _leagueRewardNote('Süre bonusu kalan sürenin payıdır, en fazla 5. Süresiz oyunda yok.'),
            _leagueRewardNote('Üst üste her doğru +2, en fazla 20.'),
          ],
        ),
        _leagueRewardCard(
          'Hangi lige yazılır',
          [
            _leagueRewardNote('Her turun puanı Genel Lig’e yazılır. Tümü ve karma da.'),
            _leagueRewardNote('Gerçek bir kategori oynandıysa aynı puan o kategorinin ligine de yazılır. Tümü ve karma kategori ligine yazılmaz.'),
          ],
        ),
        _leagueRewardCard(
          'Tur bitince',
          [
            _leagueRewardNote('Puan 0’dan büyükse tur bitince hemen:'),
            _leagueRewardPay('Altın', 'puan ÷ 10 × mod katsayısı, aşağı yuvarlanır'),
            _leagueRewardPay('Deneyim', 'puan ÷ 2, aşağı yuvarlanır'),
            _leagueRewardNote('Her 5.000 XP seviye 1 artar. Her 5. seviyede 1 elmas. Seviye 100’de durur.'),
          ],
        ),
        _leagueRewardCard(
          'Pazartesi',
          [
            _leagueRewardNote('İstanbul saatiyle pazartesi 00:00’da biten hafta bir kez ödenir. Tur ödülünün üstüne eklenir. Örnek isimler ödenmez.'),
            _leagueRewardHead('Genel Lig, ilk 100'),
            _leagueRewardPay('1.', '${_grouped(10000)} altın, ${_grouped(1000)} XP'),
            _leagueRewardPay('2.', '${_grouped(5000)} altın, ${_grouped(500)} XP'),
            _leagueRewardPay('3.', '${_grouped(2500)} altın, ${_grouped(250)} XP'),
            _leagueRewardPay('4.–100.', '${_grouped(500)} altın, ${_grouped(50)} XP'),
            _leagueRewardHead('Kategori ligi, ilk 10, genel ödemeye ek'),
            _leagueRewardPay('1.', '${_grouped(1000)} altın, ${_grouped(100)} XP'),
            _leagueRewardPay('2.', '${_grouped(500)} altın, ${_grouped(50)} XP'),
            _leagueRewardPay('3.', '${_grouped(250)} altın, ${_grouped(25)} XP'),
            _leagueRewardPay('4.–10.', '${_grouped(100)} altın, ${_grouped(10)} XP'),
            _leagueRewardNote('Bu yerlerden sonra pazartesi altını ve XP yok. Puanı 0 olan listeye girmez. Yasaklı oyuncu dışarıdadır.'),
          ],
        ),
        _leagueRewardCard(
          'Kademe ve unvan',
          [
            _leagueRewardNote('Bronz, Gümüş, Altın, Elmas ve Efsane ödemeyi değiştirmez.'),
            _leagueRewardNote('“Felsefe Ustası” gibi bir unvan, o kategoride tüm zamanların üst yerinin adıdır. Altın değildir.'),
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
            const SizedBox(height: 8),
            ...lines,
          ],
        ),
      ),
    );
  }

  Widget _leagueRewardHead(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: BilgiColors.secondary)),
    );
  }

  Widget _leagueRewardNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(text, style: const TextStyle(color: BilgiColors.muted, height: 1.35, fontSize: 13)),
    );
  }

  Widget _leagueRewardPay(String place, String payout) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(place, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(width: 12),
          Expanded(child: Text(payout, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  Widget _leaguePeriodChip(String label, bool weekly) {
    final on = _game.boardWeekly == weekly;
    final hue = weekly ? BilgiColors.secondary : BilgiColors.warning;
    return Material(
      color: on ? hue : hue.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(20),
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
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: on ? BilgiColors.bg : hue,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _leagueCategories() {
    final ids = bilgiSortLeagueCatalog(
      bilgiLeagueCatalog(_game.categoryCounts),
      sort: _leagueSort,
      questionCounts: _game.categoryCounts,
      playerCounts: _game.boardCategoryPlayerCounts,
    );
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Row(
          children: [
            _leagueSortChip('Alfabetik', bilgiLeagueSortAlpha),
            _leagueSortChip('Soru sayısı', bilgiLeagueSortQuestions),
            _leagueSortChip('Oyuncu sayısı', bilgiLeagueSortPlayers),
          ],
        ),
      ),
      if (ids.isEmpty)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('60 onaylı sorusu olan kategori yok.'),
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
          color: on ? BilgiColors.primary : BilgiColors.card,
          borderRadius: BorderRadius.circular(20),
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
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  color: on ? Colors.white : BilgiColors.muted,
                ),
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
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            _game.boardCategoryId = id;
            _game.loadBoard();
          },
          borderRadius: BorderRadius.circular(16),
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
                          bilgiCategoryById(id)?.name ?? id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (rank > 0) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$rank.',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary),
                        ),
                      ],
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _game.playCategoryLeague(id),
                  child: Text(
                    joined ? 'Lige devam et' : 'Lige Katıl',
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
      return const [
        Padding(padding: EdgeInsets.all(20), child: Text('Bu kategoride lig yok.')),
      ];
    }
    if (empty) {
      return [
        Padding(
          padding: const EdgeInsets.all(20),
          child: const Text('Henüz sıralama yok.'),
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
    );
    try {
      final picked = await showDialog<BilgiGoldHelpKind>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: BilgiColors.card,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(bilgiRadius)),
            title: const Text(
              'Yeterli altının yok',
              style: TextStyle(color: BilgiColors.text, fontWeight: FontWeight.w800),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Altın kazanabileceğin yollar:',
                    style: TextStyle(color: BilgiColors.muted, fontSize: 13, height: 1.35),
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
                child: const Text('Kapat'),
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
    final field = TextEditingController(text: user.username);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: BilgiColors.card,
          title: Text(_game.t('username'), style: const TextStyle(color: Colors.white)),
          content: TextField(
            controller: field,
            autofocus: true,
            style: const TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    final text = field.text;
    field.dispose();
    if (saved != true || !mounted) return;
    await _game.saveProfile(username: text);
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('page_profile')),
        if (_game.notice != null) _note(_game.notice!),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x4D6C3CE9), Colors.transparent],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BilgiColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: BilgiColors.primary, width: 4),
                    ),
                    child: Text(user.avatar, style: const TextStyle(fontSize: 40)),
                  ),
                  if (crown)
                    const Positioned(top: -8, right: -4, child: Text('👑', style: TextStyle(fontSize: 22))),
                ],
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
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [BilgiColors.warning, BilgiColors.accent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(user.title.toUpperCase(), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800)),
              ),
              if (_game.leagueTitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_game.leagueTitle, style: const TextStyle(fontWeight: FontWeight.w800, color: BilgiColors.secondary)),
              ],
              const SizedBox(height: 16),
              _PlayerBalanceRow(items: _balanceItems(user), showNames: false),
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
                      const ColoredBox(color: BilgiColors.card, child: SizedBox.expand()),
                      FractionallySizedBox(
                        widthFactor: fill.clamp(0.0, 1.0),
                        child: const ColoredBox(color: BilgiColors.primary, child: SizedBox.expand()),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            children: [
              _statBox(_game.t('total_games'), '${user.gamesPlayed}', BilgiColors.text),
              _statBox(ratioLabel == null ? _game.t('correct') : _game.t('correct_ratio'), ratioLabel ?? '${user.correctTotal}', BilgiColors.secondary),
              _statBox(_game.t('best_score'), _grouped(user.bestScore), BilgiColors.warning),
              _statBox(_game.t('login_streak'), _fill('days', {'n': '${user.streak}'}), BilgiColors.accent),
            ],
          ),
        ),
        _sectionLabel(_game.t('badges')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                        Text(badge.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
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
    );
  }

  Widget _shop(BilgiProfile user) {
    const packs = [
      (bilgiGold1000, '1000 altın', '₺29,99', 'assets/images/shop/luno_gold_1000.png'),
      (bilgiGold5000, '5000 altın', '₺99,99', 'assets/images/shop/luno_gold_5000.png'),
    ];
    const plans = [
      (bilgiPlusAylik, 'Luno Plus Aylık', '₺29,99 / ay', 'assets/images/shop/luno_plus_aylik.png'),
      (bilgiPlus6Ay, 'Luno Plus 6 Aylık', '₺129,99 • ayda ₺21,67', 'assets/images/shop/luno_plus_6ay.png'),
      (bilgiPlusYillik, 'Luno Plus Yıllık', '₺199,99 • ayda ₺16,67 • en avantajlı', 'assets/images/shop/luno_plus_yillik.png'),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader(_game.t('page_shop')),
        if (_game.notice != null) _note(_game.notice!),
        _shopSection(
          title: 'Abonelik',
          accent: const Color(0xFFFFB800),
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
            title: 'Ödeme ile satın alma',
            accent: const Color(0xFF7B61FF),
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
          title: 'Luno Altınlarını Dönüştür',
          accent: BilgiColors.warning,
          rows: [
            (
              icon: '❤️',
              asset: '',
              title: 'Can doldur',
              subtitle: '${_game.config.lifePrice} altın',
              onTap: _game.refill,
            ),
            for (final entry in _game.config.jokerPrices.entries)
              (
                icon: _jokerEmoji(entry.key),
                asset: '',
                title: _game.t('joker_${entry.key}'),
                subtitle: '${entry.value} altın',
                onTap: () => _game.buyJoker(entry.key),
              ),
          ],
        ),
        _shopSection(
          title: 'Reklamla kazan',
          accent: const Color(0xFFE91E63),
          rows: [
            (
              icon: '🪙',
              asset: '',
              title: 'Reklamla altın',
              subtitle: '${_game.config.rewardedGold} altın',
              onTap: () => _game.watchFor('gold'),
            ),
            (
              icon: '✂️',
              asset: '',
              title: 'Reklamla joker',
              subtitle: 'Yarım joker',
              onTap: () => _game.watchFor('joker'),
            ),
            (
              icon: '❤️',
              asset: '',
              title: 'Reklamla can',
              subtitle: '+1 can',
              onTap: () => _game.watchFor('life'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _shopSection({
    required String title,
    required Color accent,
    required List<({String icon, String asset, String title, String subtitle, VoidCallback onTap})> rows,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: _homeInter(size: 15, weight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 10),
          DecoratedBox(
            decoration: BoxDecoration(
              color: BilgiColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.1)),
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++)
                  _shopRow(rows[i], first: i == 0, last: i == rows.length - 1),
              ],
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
        top: first ? const Radius.circular(12) : Radius.zero,
        bottom: last ? const Radius.circular(12) : Radius.zero,
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
    return ListView(
      children: [
        _pageHeader(_game.t('page_duel'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Rakip arama yok. Düello bir kod ile kurulur.', textAlign: TextAlign.center),
        ),
        BilgiPrimaryButton(label: 'Kod oluştur', onTap: () => _game.makeRoom('duello')),
      ],
    );
  }

  Widget _group() {
    return ListView(
      children: [
        _pageHeader(_game.t('page_group'), onBack: _game.back),
        _tile('➕', 'Grup kur', 'Kod oluştur • 20 soru', () => _game.makeRoom('grup')),
        _joinForm(),
      ],
    );
  }

  Widget _room() {
    final room = _game.room;
    final title = switch (room?.kind) {
      'grup' => 'Grup',
      'duello' => 'Düello',
      _ => 'Özel oda',
    };
    return ListView(
      children: [
        _pageHeader(title, onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        if (room == null)
          _tile('🔒', 'Oda kur', 'Kod üret', () => _game.makeRoom('oda'))
        else ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kod ${room.code}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const Text('Aynı sorular herkese iner. Puanlar tur boyunca görünür.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${room.players.length} oyuncu', style: const TextStyle(color: BilgiColors.muted)),
                  for (final player in room.players)
                    Text('${player['name']} • ${player['role']}${room.status == 'playing' ? ' • ${player['score'] ?? '0'}' : ''}'),
                  TextButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: room.code)),
                    child: const Text('Kodu kopyala'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (room.hostId == _game.profile?.id)
            BilgiPrimaryButton(label: 'Başlat', onTap: _game.startRoom)
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Oda başlayınca aynı sorular iner.',
                textAlign: TextAlign.center,
                style: TextStyle(color: BilgiColors.muted),
              ),
            ),
        ],
        _joinForm(),
      ],
    );
  }

  Widget _joinForm() {
    return _FormCard(
      title: 'Odaya katıl',
      fields: const ['Kod', 'İsim'],
      submit: 'Katıl',
      onSubmit: (values) => _game.enterRoom(values[0], guestName: values[1]),
    );
  }

  Widget _daily() {
    final used = _game.dailyQuestionUsed;
    return ListView(
      children: [
        _pageHeader(_game.t('page_daily'), onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('1 soru • 30 sn • doğruysa 100 altın ve 50 XP. Can ve joker yok.'),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: _card(
          child: Row(
            children: [
              _iconTile(item.icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(item.description, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Text('🎮 Henüz oyun oynamadın. Hemen başla!'),
          )
        else
          for (final row in _game.past)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
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
        ? 'Düello — $opponent'
        : '${category?.name ?? (row['categoryId'] == tumuKarmaId ? 'Tümü Karma' : mode.name)} — ${mode.name}';
    final icon = category?.emoji ?? mode.emoji;
    final when = _historyWhen('${row['startedAt'] ?? ''}');
    final correct = row['correct'] as int?;
    final questions = (row['questions'] as List?)?.length;
    final bits = <String>[if (when.isNotEmpty) when];
    if (correct != null && questions != null) bits.add('$correct/$questions doğru');
    final status = _historyStatus(row);
    final score = row['score'] as int? ?? 0;
    final gold = row['gold'] as int? ?? 0;
    final right = mode.id == 'duello'
        ? (waiting || gold == 0 ? _grouped(score) : '+$gold')
        : _grouped(score);
    final rightLabel = mode.id == 'duello' && !waiting && gold > 0 ? 'altın' : 'puan';
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
        _pageHeader('Kayıt', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        _FormCard(
          title: 'Hesap oluştur',
          fields: const ['Kullanıcı adı', 'E-posta', 'Şifre'],
          submit: 'Kaydol',
          onSubmit: (values) => _game.register(values[0], values[1], values[2]),
        ),
      ],
    );
  }

  Widget _login() {
    final field = InputDecoration(
      filled: true,
      fillColor: BilgiColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
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
              side: const BorderSide(color: BilgiColors.primaryLight),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(_game.t('login_google')),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: OutlinedButton(
            onPressed: _game.loginApple,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: BilgiColors.primaryLight),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text(_game.t('login_apple')),
          ),
        ),
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
        decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(bilgiRadius)),
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
        _pageHeader('Şifre', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text('Kod e-postana gelir. Şifre bu cihazdaki hesapta güncellenir.'),
        ),
        _FormCard(
          title: 'Şifre sıfırlama',
          fields: const ['E-posta', 'Kod', 'Yeni şifre'],
          submit: 'Şifreyi güncelle',
          secondaryLabel: 'Kod gönder',
          onSecondary: (values) => _game.requestReset(values[0]),
          onSubmit: (values) => _game.confirmReset(values[0], values[1], values[2]),
        ),
      ],
    );
  }

  Widget _invite(BilgiProfile user) {
    return ListView(
      children: [
        _pageHeader('Davet', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(child: Text('Kodun: ${user.inviteCode}\nDavet ${user.invites}\nİki taraf +100 altın. 5 davette +1 can.')),
        ),
        _FormCard(
          title: 'Kod gir',
          fields: const ['Davet kodu'],
          submit: 'Kabul et',
          onSubmit: (values) => _game.claimInvite(values[0]),
        ),
        if (user.friends.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('👥 Henüz arkadaşın yok. Davet et!')),
      ],
    );
  }

  Widget _legal() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _pageHeader('Yasal', onBack: _game.back),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Luno Bilgi hesabı bu cihazda tutulur. Şifre düz metin olarak saklanmaz. '
            'Altın ve elmas Luno League coininden ayrıdır. Mağaza TL paketleri Play makbuzu olmadan yüklenmez. '
            'Reklamlar Chrome oturumunda açılmaz. Destek: destek@lunobilgi.com',
            style: TextStyle(height: 1.45),
          ),
        ),
      ],
    );
  }

  Widget _error() {
    final notice = _game.notice ?? '⚠️ Bir şeyler ters gitti. Tekrar dene.';
    final connection = notice.contains('Bağlantı') || notice.contains('İnternet');
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(connection ? '📡' : '⚠️', style: const TextStyle(fontSize: 80)),
            const SizedBox(height: 16),
            Text(
              connection ? 'Bağlantı Hatası' : 'Bir şeyler ters gitti',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              connection ? 'İnternet bağlantını kontrol et ve tekrar dene.' : notice,
              textAlign: TextAlign.center,
              style: const TextStyle(color: BilgiColors.muted, fontSize: 14, height: 1.4),
            ),
            const SizedBox(height: 24),
            _startButton(_game.retry, label: '🔄 Tekrar Dene'),
          ],
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
        color: BilgiColors.card,
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
                    const Text('Günlük Ödül', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text('7 gün üst üste gir, büyük ödülü kazan', textAlign: TextAlign.center, style: TextStyle(color: BilgiColors.muted, fontSize: 13)),
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
                      decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('BUGÜNÜN ÖDÜLÜ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: BilgiColors.muted)),
                          const SizedBox(height: 8),
                          _rewardCoinChip(today.icon, today.amount, today.unit),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _BilgiWatchAdCard(
                      title: '2x Yap!',
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
                          gradient: ready ? const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight]) : null,
                          color: ready ? null : BilgiColors.bg,
                          borderRadius: BorderRadius.circular(bilgiRadius),
                          boxShadow: ready ? const [BoxShadow(color: Color(0x666C3CE9), blurRadius: 24, offset: Offset(0, 8))] : null,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: ready ? () => _claimWithBurst(doubled: false) : null,
                            borderRadius: BorderRadius.circular(bilgiRadius),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                ready ? 'Ödülü Al' : '📅 Bugünkü hakkını kullandın.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    TextButton(onPressed: _rewardBurst ? null : _game.back, child: const Text('Kapat')),
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
    return ListView(
      children: [
        _pageHeader('Reklam'),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            premium ? 'Premium reklamı geçer.' : 'Oyun öncesi ${_game.adLeft} sn',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        if (premium) BilgiPrimaryButton(label: 'Geç', onTap: () => _game.start(adCleared: true)),
        if (kIsWeb)
          BilgiPrimaryButton(label: 'Kapat', onTap: _game.skipUnplayableAd),
      ],
    );
  }

  Widget _jokerShop(BilgiProfile user) {
    return ListView(
      children: [
        _pageHeader('Joker', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Text('🪙 ${user.gold}', textAlign: TextAlign.center),
        for (final entry in _game.config.jokerPrices.entries)
          _tile(
            _jokerEmoji(entry.key),
            _game.t('joker_${entry.key}'),
            '${entry.value} altın • stok ${user.jokers[entry.key] ?? 0}',
            () => _game.buyJoker(entry.key),
          ),
      ],
    );
  }

  Widget _noLives(BilgiProfile user) {
    return ListView(
      children: [
        _pageHeader('Can', onBack: _game.back),
        Padding(
          padding: const EdgeInsets.only(top: 20),
          child: _note('❤️ Canın bitti! Yenilenmesini bekle veya satın al.'),
        ),
        if (_game.notice != null) _note(_game.notice!),
        _tile(
          '🪙',
          'Luno altınlarınla doldur',
          '${_game.config.lifePrice} altın • şu an ${user.lives}',
          _game.refill,
        ),
        _tile('🎬', 'Reklamla can', 'Günlük sınır ${_game.config.rewardedLifeLimit}', () => _game.watchFor('life')),
      ],
    );
  }

  Widget _intro() {
    final steps = [
      ('1', _game.t('intro_step1_title'), _game.t('intro_step1_body')),
      ('2', _game.t('intro_step2_title'), _game.t('intro_step2_body')),
      ('3', _game.t('intro_step3_title'), _game.t('intro_step3_body')),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          height: constraints.maxHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(child: _BilgiLogo(size: 148, semanticLabel: _game.t('game_name'))),
                        const SizedBox(height: 16),
                        Text(
                          _game.t('game_name'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(_game.t('intro_tagline'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(_game.t('intro_sub'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: BilgiColors.muted)),
                        const SizedBox(height: 40),
                        for (var i = 0; i < steps.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          _introStep(steps[i].$1, steps[i].$2, steps[i].$3),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight]),
                    borderRadius: BorderRadius.circular(bilgiRadius),
                    boxShadow: const [BoxShadow(color: Color(0x666C3CE9), blurRadius: 24, offset: Offset(0, 8))],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _game.finishIntro,
                      borderRadius: BorderRadius.circular(bilgiRadius),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        child: Text(_game.t('intro_start'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _introStep(String number, String title, String body) {
    return DecoratedBox(
      decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(bilgiRadius)),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [BilgiColors.primary, BilgiColors.primaryLight],
                ),
              ),
              child: Text(number, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔧', style: TextStyle(fontSize: 80)),
            SizedBox(height: 16),
            Text('Bakımdayız', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            SizedBox(height: 8),
            Text(
              'Seni daha iyi bir deneyimle buluşturmak için çalışıyoruz. Kısa süre içinde döneceğiz.',
              textAlign: TextAlign.center,
              style: TextStyle(color: BilgiColors.muted, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  String _hintLine(BilgiQuestion? shown, String stored) {
    if (shown != null && shown.explanation.trim().isNotEmpty) {
      return bilgiHintClue(
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

  Widget _tile(String icon, String title, String subtitle, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Material(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(bilgiRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(bilgiRadius),
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
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(subtitle, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
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

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(bilgiRadius),
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
      difficultyColor: diffKey == 'kolay' ? BilgiColors.secondary : BilgiColors.warning,
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
        text,
        style: const TextStyle(color: BilgiColors.muted, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5),
      ),
    );
  }

  Widget _iconTile(String icon) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(12)),
      child: Text(icon, style: const TextStyle(fontSize: 22)),
    );
  }

  Widget _subRow({required String icon, required String title, required String subtitle, required VoidCallback onTap, bool karma = false}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: karma
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [BilgiColors.primary, BilgiColors.primaryLight],
                    )
                  : null,
              color: karma ? null : BilgiColors.card,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(12)),
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(subtitle, style: TextStyle(fontSize: 11, color: karma ? const Color(0xE6FFFFFF) : BilgiColors.muted)),
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

  Widget _startButton(VoidCallback? onTap, {String? label}) {
    final text = label ?? _game.t('start_game');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight]),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [BoxShadow(color: Color(0x666C3CE9), blurRadius: 24, offset: Offset(0, 8))],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Text(text, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _adBanner({bool showNoticeAbove = true}) {
    if (!_game.config.bannerEnabled) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showNoticeAbove && _game.notice != null) _note(_game.notice!),
        _BilgiWatchAdCard(
          title: _game.t('ad_watch_title'),
          subtitle: _fill('ad_watch_sub', {'n': '${_game.config.rewardedGold}'}),
          buttonLabel: _game.t('ad_watch_btn'),
          onWatch: () => _game.watchFor('gold'),
        ),
      ],
    );
  }

  Widget _quitButton() {
    return Material(
      color: BilgiColors.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: _game.endRound,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(width: 40, height: 40, child: Center(child: Text('✕', style: TextStyle(fontWeight: FontWeight.w800)))),
      ),
    );
  }

  Color _difficultyDot(String value) => switch (value) {
        'orta' => BilgiColors.warning,
        'zor' => BilgiColors.error,
        'efsane' => BilgiColors.primaryLight,
        _ => const Color(0xFF22C55E),
      };

  Widget _questionSegments({required int current, required int total}) {
    final count = total.clamp(1, 50);
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: i < current - 1
                    ? BilgiColors.secondary
                    : i == current - 1
                        ? BilgiColors.primary
                        : const Color(0xFF2A2740),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _headerChip({required String label, required Color dot}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1A33),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x332A2740)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4),
            ),
          ),
        ],
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
                  const ColoredBox(color: Color(0xFF2A2740), child: SizedBox.expand()),
                  FractionallySizedBox(
                    widthFactor: factor,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [BilgiColors.secondary, BilgiColors.warning]),
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
              timed || marathon ? Icons.timer_outlined : Icons.all_inclusive_rounded,
              size: 14,
              color: BilgiColors.muted,
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                color: timed || marathon ? BilgiColors.warning : BilgiColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
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
                color: BilgiColors.card,
                borderRadius: BorderRadius.circular(bilgiRadius),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: BilgiColors.text,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () => setState(() {
                              _jokerPrompt = null;
                              _jokerPromptIndex = null;
                            }),
                            style: TextButton.styleFrom(
                              foregroundColor: BilgiColors.text,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: Text(
                              _game.t('joker_cancel'),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [BilgiColors.primary, BilgiColors.primaryLight],
                              ),
                              borderRadius: BorderRadius.circular(bilgiRadius),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _applyPromptedJoker,
                                borderRadius: BorderRadius.circular(bilgiRadius),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  child: Text(
                                    _game.t('joker_confirm'),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: BilgiColors.text,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
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
    await _game.useJoker(type);
  }

  Widget _jokerButton(String emoji, String label, int stock, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 60,
        height: 70,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 60,
              height: 70,
              padding: const EdgeInsets.fromLTRB(2, 6, 2, 10),
              decoration: BoxDecoration(
                color: BilgiColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1AFFFFFF), width: 2),
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
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                      color: BilgiColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: BilgiColors.primary, shape: BoxShape.circle),
                child: Text('$stock', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 72.0;
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: constraints.maxWidth,
                  height: height * 0.55,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
                  ),
                ),
                SizedBox(
                  width: constraints.maxWidth,
                  height: height * 0.32,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: BilgiColors.muted, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            );
          },
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
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
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
            Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              alignment: on ? Alignment.centerRight : Alignment.centerLeft,
              decoration: BoxDecoration(color: on ? BilgiColors.primary : BilgiColors.bg, borderRadius: BorderRadius.circular(12)),
              child: Container(width: 20, height: 20, decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
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
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0x1AFFFFFF)),
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
        gradient: today ? const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight]) : null,
        color: today ? null : (done ? const Color(0x3300D9C0) : BilgiColors.bg),
        borderRadius: BorderRadius.circular(12),
      ),
      transform: today ? (Matrix4.identity()..scaleByDouble(1.08, 1.08, 1.08, 1)) : null,
      child: Column(
        children: [
          Text('${i + 1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
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
              child: Text(user.avatar, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 6),
            Text(
              user.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: mine ? BilgiColors.secondary : Colors.white),
            ),
            Text(_grouped(user.score), style: const TextStyle(color: BilgiColors.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              height: height,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: mine
                    ? null
                    : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [BilgiColors.primary, BilgiColors.primaryLight]),
                color: mine ? BilgiColors.secondary : null,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Text('$rank', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: mine ? BilgiColors.bg : Colors.white)),
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

  Widget _boardRow(int rank, BilgiBoardEntry user, bool me) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: me ? BilgiColors.secondary : BilgiColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text('$rank', style: TextStyle(fontWeight: FontWeight.w800, color: me ? BilgiColors.bg : Colors.white)),
            const SizedBox(width: 10),
            Text(user.avatar, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, style: TextStyle(fontWeight: FontWeight.w700, color: me ? BilgiColors.bg : Colors.white)),
                  if (user.leagueTitle.isNotEmpty)
                    Text(user.leagueTitle, style: TextStyle(color: me ? BilgiColors.bg : BilgiColors.secondary, fontSize: 11, fontWeight: FontWeight.w700))
                  else if (user.city.isNotEmpty)
                    Text(user.city, style: TextStyle(color: me ? BilgiColors.bg : BilgiColors.muted, fontSize: 11)),
                ],
              ),
            ),
            Text(_grouped(user.score), style: TextStyle(color: me ? BilgiColors.bg : BilgiColors.secondary, fontWeight: FontWeight.w800)),
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
    if (day == today) return 'Bugün $hhmm';
    if (day == today.subtract(const Duration(days: 1))) return 'Dün $hhmm';
    final days = today.difference(day).inDays;
    return '$days gün önce';
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
  });

  final String title;
  final List<String> fields;
  final String submit;
  final void Function(List<String> values) onSubmit;
  final List<String> initial;
  final String? secondaryLabel;
  final void Function(List<String> values)? onSecondary;

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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
          for (var i = 0; i < widget.fields.length; i++)
            TextField(
              controller: _fields[i],
              obscureText: widget.fields[i].toLowerCase().contains('şifre'),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: widget.fields[i]),
            ),
          const SizedBox(height: 12),
          BilgiPrimaryButton(
            label: widget.submit,
            onTap: () => widget.onSubmit([for (final field in _fields) field.text]),
          ),
          if (widget.onSecondary != null && widget.secondaryLabel != null)
            TextButton(
              onPressed: () => widget.onSecondary!([for (final field in _fields) field.text]),
              child: Text(widget.secondaryLabel!),
            ),
        ],
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
    Color border = Colors.transparent;
    Color fill = BilgiColors.card;
    Color chip = BilgiColors.bg;
    if (widget.correct) {
      border = BilgiColors.secondary;
      fill = const Color(0x2600D9C0);
      chip = BilgiColors.secondary;
    } else if (widget.wrong) {
      border = BilgiColors.error;
      fill = const Color(0x26FF4D6D);
      chip = BilgiColors.error;
    }
    final row = Material(
      color: widget.hidden ? BilgiColors.bg : fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: widget.hidden ? Colors.transparent : border, width: 2),
      ),
      child: InkWell(
        onTap: widget.hidden ? null : widget.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: chip, borderRadius: BorderRadius.circular(10)),
                child: Text(widget.letter, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.hidden ? '—' : widget.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.hidden ? BilgiColors.muted : BilgiColors.text,
                  ),
                ),
              ),
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
                    color: BilgiColors.secondary.withValues(alpha: 0.32 * bump),
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
                  color: BilgiColors.error.withValues(alpha: 0.28 * bump),
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

class _FaultReport extends StatefulWidget {
  const _FaultReport({super.key, required this.onSubmit});

  final Future<String?> Function(String note) onSubmit;

  @override
  State<_FaultReport> createState() => _FaultReportState();
}

class _FaultReportState extends State<_FaultReport> {
  final _note = TextEditingController();
  var _open = false;
  var _busy = false;
  var _error = '';

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final error = bilgiReportNoteError(_note.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final result = await widget.onSubmit(_note.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = result ?? '';
      if (result == null) {
        _open = false;
        _note.clear();
        _error = 'Bildirim iletildi.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        TextButton(
          onPressed: _busy ? null : () => setState(() => _open = !_open),
          style: TextButton.styleFrom(
            foregroundColor: BilgiColors.muted,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Hatalı soru bildir', style: TextStyle(fontSize: 12)),
        ),
        if (_open) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Sorunun nesi hatalı? Açıklama zorunlu.',
              hintStyle: TextStyle(color: BilgiColors.muted),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _busy ? null : _send,
              child: Text(_busy ? 'Gönderiliyor' : 'Gönder'),
            ),
          ),
        ],
        if (_error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(_error, style: const TextStyle(color: BilgiColors.warning, fontSize: 12)),
          ),
      ],
    );
  }
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
              child: TextButton(
                onPressed: widget.onClose,
                child: Text(widget.closeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.margin,
      child: Material(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _busy || !widget.enabled ? null : _tap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x66FFB800)),
            ),
            child: Row(
              children: [
                const Icon(Icons.card_giftcard_rounded, color: BilgiColors.warning, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      widget.emphasizeSubtitle
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: BilgiColors.bg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0x66FFB800)),
                              ),
                              child: Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  color: BilgiColors.warning,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          : Text(
                              widget.subtitle,
                              style: const TextStyle(
                                color: BilgiColors.muted,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(colors: [BilgiColors.warning, Color(0xFFD97706)]),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: _busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1C1917)),
                          )
                        : Text(
                            widget.buttonLabel,
                            style: const TextStyle(
                              color: Color(0xFF1C1917),
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
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
          style: const TextStyle(color: BilgiColors.text, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: 220,
          child: LinearProgressIndicator(
            minHeight: 6,
            color: BilgiColors.secondary,
            backgroundColor: BilgiColors.card,
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
