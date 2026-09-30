import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_controller.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_language_page.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_opening_loader.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_round_loading.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
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
  bool _showAccountForm = false;

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
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _categoryQuery.dispose();
    _game.removeListener(_onChange);
    _game.dispose();
    super.dispose();
  }

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
            settings: _game.t('settings'),
            profile: _game.t('profile'),
            shop: _game.t('shop'),
          ),
      ],
    );
  }

  String _navId() {
    return switch (_game.page) {
      'categories' || 'detail' || 'setup' || 'group' || 'room' => 'play',
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
      'profile' => _profile(user!),
      'shop' => _shop(user!),
      'duel' => _duel(),
      'group' => _group(),
      'room' => _room(),
      'daily' => _daily(),
      'event' => _events(),
      'language' => _language(),
      'settings' => _settings(user!),
      'achievements' => _achievements(user!),
      'history' => _history(),
      'login' => _auth(register: false),
      'register' => _auth(register: true),
      'forgot' => _forgot(),
      'invite' => _invite(user!),
      'legal' => _legal(),
      'error' => _error(),
      'reward' => _reward(user!),
      'ad' => _ad(),
      'joker' => _jokerShop(user!),
      'nolives' => _noLives(user!),
      _ => _home(user!),
    };
  }

  Widget _home(BilgiProfile user) {
    final ready = _game.rewardReady();
    final reward = _game.rewardLabel(_game.rewardIndex());
    final free = !_game.server.needsAd(user, _game.config);
    final solo = bilgiModes.where((mode) => mode.group == 'solo').toList();
    final popular = [for (final category in _game.categories) if (category.popular) category];
    final dailyLine = ready
        ? (user.streak > 0 ? _fill('streak_line', {'n': '${user.streak}', 'reward': reward}) : reward)
        : _fill('reward_tomorrow', {'reward': reward});
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              _BilgiLogo(size: 44, semanticLabel: _game.t('game_name')),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _game.t('game_name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              const Spacer(),
              BilgiStatChip(icon: '🪙', value: _grouped(user.gold)),
              const SizedBox(width: 10),
              BilgiStatChip(icon: '💎', value: _grouped(user.diamond)),
            ],
          ),
        ),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BilgiColors.primary, BilgiColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(bilgiRadius),
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
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(dailyLine, style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF))),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0x40FFFFFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _game.open('reward'),
                    child: Text(_game.t('claim'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: BilgiColors.card,
              borderRadius: BorderRadius.circular(bilgiRadius),
              border: Border.all(color: BilgiColors.secondary, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            Text('🎮 ${_game.t('free_play')}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            if (free)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BilgiColors.secondary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _game.t('ready_badge'),
                                  style: const TextStyle(color: BilgiColors.bg, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          free ? _game.t('free_today') : _game.t('free_ad'),
                          style: const TextStyle(fontSize: 12, color: BilgiColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: BilgiColors.secondary,
                      foregroundColor: BilgiColors.bg,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      _game.modeId = 'hizli';
                      _game.categoryId = tumuKarmaId;
                      _game.difficulty = 'hepsi';
                      _game.start();
                    },
                    child: Text(_game.t('play'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
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
          childAspectRatio: 1.55,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            for (final mode in solo)
              Material(
                color: BilgiColors.card,
                borderRadius: BorderRadius.circular(bilgiRadius),
                child: InkWell(
                  onTap: () => _game.selectMode(mode.id),
                  borderRadius: BorderRadius.circular(bilgiRadius),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(mode.emoji, style: const TextStyle(fontSize: 28)),
                        const Spacer(),
                        Text(_game.t('mode_${mode.id}'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(_modeLine(mode), style: const TextStyle(fontSize: 11, color: BilgiColors.muted)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (popular.isNotEmpty) ...[
          _sectionTitle(_game.t('popular'), _game.t('see_all'), () => _game.open('categories')),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                for (final category in popular)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Material(
                      color: BilgiColors.card,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        onTap: () => _game.selectCategory(category.id),
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 90,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(category.emoji, style: const TextStyle(fontSize: 24)),
                              const SizedBox(height: 6),
                              Text(
                                _game.categoryLabel(category.id, category.name),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BilgiColors.primary, BilgiColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(bilgiRadius),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _game.open('categories'),
                borderRadius: BorderRadius.circular(bilgiRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    '📚 ${_fill('see_categories', {'n': '${_game.categories.length}'})}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [BilgiColors.accent, Color(0xFFFF8FAB)],
              ),
              borderRadius: BorderRadius.circular(bilgiRadius),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0x40FFFFFF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_game.t('weekly'), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  Text('🏆 ${_game.t('league_started')}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(
                    _game.t('league_prize'),
                    style: const TextStyle(fontSize: 12, color: Color(0xE6FFFFFF)),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BilgiColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _game.tab('league'),
                    child: Text(_game.t('join'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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

  Widget _wallet(BilgiProfile? user) {
    if (user == null) return const SizedBox(width: 40);
    final jokers = user.jokers.values.fold<int>(0, (sum, count) => sum + count);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BilgiStatChip(icon: '🪙', value: _grouped(user.gold)),
        const SizedBox(width: 6),
        BilgiStatChip(icon: '💎', value: _grouped(user.diamond)),
        const SizedBox(width: 6),
        if (_game.config.livesEnabled) ...[
          BilgiStatChip(icon: '❤️', value: '${user.lives}'),
          const SizedBox(width: 6),
        ],
        BilgiStatChip(icon: '🃏', value: '$jokers'),
      ],
    );
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

  Widget _sectionTitle(String title, String action, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        children: [
          Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          TextButton(
            onPressed: onTap,
            child: Text(action, style: const TextStyle(color: BilgiColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _modes() {
    final solo = [for (final mode in bilgiModes) if (mode.group == 'solo') mode];
    final multi = [for (final mode in bilgiModes) if (mode.group == 'multi' && mode.id != 'grup') mode];
    final special = [for (final mode in bilgiModes) if (mode.group == 'special') mode];
    final categoryCount = _game.categories.isEmpty ? bilgiCategories.length : _game.categories.length;
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        BilgiTopBar(
          title: _game.t('page_play'),
          titleAlign: TextAlign.left,
          onHome: () => _game.tab('home'),
          trailing: _wallet(_game.profile),
        ),
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
      'hizli' => _game.t('badge_free'),
      'duello' => _game.t('badge_popular'),
      'gunluk' => _game.t('badge_daily'),
      _ => null,
    };
    final badgeColor = mode.id == 'duello' ? const Color(0xFFFF5C93) : BilgiColors.secondary;
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
        BilgiTopBar(title: _game.t('page_categories'), onBack: _game.back),
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
                if (_game.categories.where((category) => category.group == group && _matchesCategory(category, query)).toList() case final rows when rows.isNotEmpty) ...[
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
                    childAspectRatio: 1.35,
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
    final subs = tumu ? const <String>[] : (live?.subs ?? category.subs);
    final known = _game.categoryCounts[_game.categoryId];
    final heroCount = known != null
        ? _fill('q_count', {'n': '$known'})
        : (_game.poolCount > 0 ? _fill('q_count', {'n': '${_game.poolCount}'}) : '…');
    final heroSub = subs.isEmpty ? heroCount : '$heroCount • ${_fill('subs_n', {'n': '${subs.length}'})}';
    final highlight = _playDifficulty(_game.difficulty) ? _game.difficulty : 'kolay';
    final diffs = [
      (_game.t('diff_easy'), 'kolay'),
      (_game.t('diff_medium'), 'orta'),
      (_game.t('diff_hard'), 'zor'),
      (_game.t('diff_legend'), 'efsane'),
    ];
    return Column(
      children: [
        BilgiTopBar(title: _game.t('page_detail'), onBack: _game.back),
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
              _sectionLabel(_game.t('difficulty_level')),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    for (final item in diffs)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: item.$2 == 'efsane' ? 0 : 8),
                          child: Material(
                            color: highlight == item.$2 ? BilgiColors.primary : BilgiColors.card,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: () => _game.selectDifficulty(item.$2),
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                  item.$1,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _startButton(_game.busy ? null : _game.start, label: _game.t('start_game')),
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
    ];
    final modes = [
      ('⚡', _game.t('mode_compact_hizli'), 'hizli'),
      ('🎯', _game.t('mode_compact_klasik'), 'klasik'),
      ('🧘', _game.t('mode_compact_sakin'), 'sakin'),
    ];
    final countMismatch = playable != _game.questionChoice ? _fill('q_count', {'n': '$playable'}) : null;
    return Column(
      children: [
        BilgiTopBar(title: _game.t('page_setup'), onBack: _game.back),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (_game.notice != null) _note(_game.notice!),
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
              const SizedBox(height: 20),
              _startButton(_game.busy ? null : _game.start, label: _game.t('start_game')),
            ],
          ),
        ),
      ],
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
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: BilgiColors.info,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : BilgiColors.muted,
                ),
              ),
            ],
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
    return Padding(
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
            _note(shown?.explanation.isNotEmpty == true ? shown!.explanation : round.hint),
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
                    round.jokersUsed >= round.jokerMax ? null : () => _game.useJoker(item.$1),
                  ),
              ],
            ),
          ),
        ],
      ),
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
                onPressed: _game.scoreDoubled ? null : _game.doubleResultScore,
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
    final board = _game.board;
    final weekly = _game.boardScope == 'weekly';
    int scoreOf(BilgiProfile row) => weekly ? row.weekScore : row.totalScore;
    final podium = board.take(3).toList();
    final rest = board.length > 3 ? board.sublist(3) : const <BilgiProfile>[];
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              const Text('🏆 Lig', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              BilgiStatChip(icon: '🪙', value: _grouped(user.gold)),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Row(
            children: [
              for (final item in const [
                ('Genel', 'global'),
                ('Haftalık', 'weekly'),
                ('Kategoriler', 'category'),
                ('Arkadaşlar', 'friends'),
                ('Şehir', 'city'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: _game.boardScope == item.$2 ? BilgiColors.primary : BilgiColors.card,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      onTap: () {
                        _game.boardScope = item.$2;
                        _game.loadBoard();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        child: Text(
                          item.$1,
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
            ],
          ),
        ),
        if (_game.boardScope == 'category')
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text('Kategori sırası ayrı puan tutmuyor.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
          ),
        if (board.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _game.boardScope == 'friends'
                  ? '👥 Arkadaş ekleyince burada görünecek.'
                  : _game.boardScope == 'city'
                      ? 'Şehir ekleyince burada görünecek.'
                      : 'Henüz sıralama yok.',
            ),
          )
        else ...[
          if (podium.isNotEmpty) _podium(podium, scoreOf, user.id),
          for (var i = 0; i < rest.length; i++)
            _boardRow(i + 4, rest[i], scoreOf(rest[i]), rest[i].id == user.id),
        ],
        const SizedBox(height: 16),
        _adBanner(),
      ],
    );
  }

  Widget _profile(BilgiProfile user) {
    final crown = user.premium || user.badges.contains('king');
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
              Text(user.username, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [BilgiColors.warning, BilgiColors.accent]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(user.title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
              ),
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
        SizedBox(
          height: 88,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              for (final badge in bilgiBadges)
                Opacity(
                  opacity: user.badges.contains(badge.id) ? 1 : 0.4,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Column(
                      children: [
                        Text(badge.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 6),
                        Text(badge.name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        _sectionLabel(_game.t('account')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _menuRow('📊', _game.t('stats'), _game.t('stats_sub'), () => _game.open('history')),
                _menuRow('🎯', _game.t('page_achievements'), _game.t('tasks'), () => _game.open('achievements')),
                _menuRow('📜', _game.t('page_history'), user.gamesPlayed == 0 ? _game.t('no_games') : _fill('games_n', {'n': '${user.gamesPlayed}'}), () => _game.open('history')),
                _menuRow('👥', _game.t('invite'), user.inviteCode, () => _game.open('invite')),
                _menuRow('🔐', _game.t('sign_in'), _game.t('sign_in_sub'), () => _game.open('login'), last: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _adBanner(),
      ],
    );
  }

  Widget _shop(BilgiProfile user) {
    const packs = [
      ('1000 altın', '₺29,99'),
      ('5000 altın', '₺99,99'),
      ('Luno Plus', '₺79,99 / ay'),
    ];
    return ListView(
      children: [
        BilgiTopBar(title: _game.t('page_shop')),
        if (_game.notice != null) _note(_game.notice!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text('🪙 ${user.gold}   💎 ${user.diamond}', style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        for (final pack in packs)
          _tile('💳', pack.$1, '${pack.$2} • Play makbuzu gerekir', () {
            _game.notice = pack.$1 == 'Luno Plus'
                ? '👑 Bu özellik Premium\'a özel.'
                : 'Play makbuzu olmadan bu paket yüklenmez.';
            _game.open('error');
          }),
        _tile('❤️', 'Can doldur', '${_game.config.lifePrice} altın', _game.refill),
        _tile('🎬', 'Reklamla altın', '${_game.config.rewardedGold} altın', () => _game.watchFor('gold')),
        _tile('🎬', 'Reklamla joker', 'Yarım joker', () => _game.watchFor('joker')),
        _tile('🎬', 'Reklamla can', '+1 can', () => _game.watchFor('life')),
        for (final entry in _game.config.jokerPrices.entries)
          _tile('🃏', entry.key, '${entry.value} altın', () => _game.buyJoker(entry.key)),
      ],
    );
  }

  Widget _duel() {
    return ListView(
      children: [
        BilgiTopBar(title: _game.t('page_duel'), onBack: _game.back),
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
        BilgiTopBar(title: _game.t('page_group'), onBack: _game.back),
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
        BilgiTopBar(title: title, onBack: _game.back),
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
        BilgiTopBar(title: _game.t('page_daily'), onBack: _game.back),
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
        BilgiTopBar(title: _game.t('page_events'), onBack: _game.back),
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
      continueLabel: _game.t('continue'),
      fromSettings: fromSettings,
      onPreview: _game.previewLocale,
      onConfirm: _game.confirmLocale,
      onBack: fromSettings ? _game.back : null,
    );
  }

  Widget _settings(BilgiProfile user) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        BilgiTopBar(title: _game.t('settings')),
        if (_game.notice != null) _note(_game.notice!),
        _sectionLabel(_game.t('language')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: _menuRow(
              '🌐',
              _game.t('language'),
              '${GameLocale.resolve(user.locale).nativeName} ›',
              () => _game.open('language'),
              last: true,
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
        _sectionLabel(_game.t('account')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _menuRow('👤', _game.t('account_info'), user.username, () => setState(() => _showAccountForm = !_showAccountForm)),
                _menuRow('📄', _game.t('privacy'), _game.t('privacy_sub'), () => _game.open('legal')),
                _menuRow('👥', _game.t('invite'), user.inviteCode, () => _game.open('invite'), last: true),
              ],
            ),
          ),
        ),
        if (_showAccountForm)
          _FormCard(
            title: _game.t('profile'),
            fields: [_game.t('username'), _game.t('city')],
            initial: [user.username, user.city],
            submit: _game.t('save'),
            onSubmit: (values) => _game.saveProfile(username: values[0], city: values[1]),
          ),
        _sectionLabel(_game.t('support')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _menuRow('❓', _game.t('help'), _game.t('how_to'), () => _game.flash(_game.t('how_to'))),
                _menuRow('✉️', _game.t('contact'), _game.config.supportEmail, () => _game.flash(_game.config.supportEmail)),
                _menuRow('ℹ️', _game.t('about'), gameVersionCode, null, last: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _achievements(BilgiProfile user) {
    if (bilgiAchievements.isEmpty) {
      return ListView(
        children: [
          BilgiTopBar(title: _game.t('page_achievements'), onBack: _game.back),
          Padding(padding: const EdgeInsets.all(20), child: Text(_game.t('no_achievements'))),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        BilgiTopBar(title: _game.t('page_achievements'), onBack: _game.back),
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
        BilgiTopBar(title: _game.t('page_history'), onBack: _game.back),
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
    return ListView(
      children: [
        BilgiTopBar(title: register ? 'Kayıt' : 'Giriş', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        _FormCard(
          title: register ? 'Hesap oluştur' : 'Giriş yap',
          fields: register ? const ['Kullanıcı adı', 'E-posta', 'Şifre'] : const ['E-posta', 'Şifre'],
          submit: register ? 'Kaydol' : 'Giriş',
          onSubmit: (values) {
            if (register) {
              _game.register(values[0], values[1], values[2]);
            } else {
              _game.login(values[0], values[1]);
            }
          },
        ),
        if (!register) TextButton(onPressed: () => _game.open('forgot'), child: const Text('Şifremi unuttum')),
        if (!register) TextButton(onPressed: () => _game.open('register'), child: const Text('Kayıt ol')),
      ],
    );
  }

  Widget _forgot() {
    return ListView(
      children: [
        BilgiTopBar(title: 'Şifre', onBack: _game.back),
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
        BilgiTopBar(title: 'Davet', onBack: _game.back),
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
        BilgiTopBar(title: 'Yasal', onBack: _game.back),
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

  Widget _reward(BilgiProfile user) {
    final ready = _game.rewardReady();
    final index = _game.rewardIndex();
    final todayLabel = _game.rewardLabel(index);
    return ColoredBox(
      color: BilgiColors.bg,
      child: Center(
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
                    const SizedBox(height: 6),
                    Text(todayLabel, style: const TextStyle(color: BilgiColors.warning, fontSize: 20, fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _card(
                child: Row(
                  children: [
                    Expanded(
                      child: Text('📺 2x Yap!\n${_doubleRewardLabel(index)}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.3)),
                    ),
                    TextButton(
                      onPressed: ready ? _game.doubleDailyReward : null,
                      child: const Text('İzle', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _startButton(ready ? () => _game.claimDaily() : null, label: ready ? 'Ödülü Al' : '📅 Bugünkü hakkını kullandın.'),
              TextButton(onPressed: _game.back, child: const Text('Kapat')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ad() {
    final premium = _game.profile?.premium == true;
    return ListView(
      children: [
        const BilgiTopBar(title: 'Reklam'),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            premium ? 'Premium reklamı geçer.' : 'Oyun öncesi ${_game.adLeft} sn',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
        ),
        if (premium) BilgiPrimaryButton(label: 'Geç', onTap: () => _game.start(adCleared: true)),
      ],
    );
  }

  Widget _jokerShop(BilgiProfile user) {
    return ListView(
      children: [
        BilgiTopBar(title: 'Joker', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        Text('🪙 ${user.gold}', textAlign: TextAlign.center),
        for (final entry in _game.config.jokerPrices.entries)
          _tile('🃏', entry.key, '${entry.value} altın • stok ${user.jokers[entry.key] ?? 0}', () => _game.buyJoker(entry.key)),
      ],
    );
  }

  Widget _noLives(BilgiProfile user) {
    return ListView(
      children: [
        BilgiTopBar(title: 'Can', onBack: _game.back),
        _note('❤️ Canın bitti! Yenilenmesini bekle veya satın al.'),
        _tile('🪙', 'Doldur', '${_game.config.lifePrice} altın • şu an ${user.lives}', _game.refill),
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

  bool _playDifficulty(String value) => value == 'kolay' || value == 'orta' || value == 'zor' || value == 'efsane';

  String _difficultyLabel(String value) => switch (value) {
        'orta' => _game.t('diff_medium'),
        'zor' => _game.t('diff_hard'),
        'efsane' => _game.t('diff_legend'),
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(color: BilgiColors.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _menuRow(String icon, String title, String subtitle, VoidCallback? onTap, {bool last = false}) {
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
            Text(subtitle, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
            if (onTap != null) const Text(' ›', style: TextStyle(color: BilgiColors.muted)),
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

  String _doubleRewardLabel(int index) {
    final label = _game.rewardLabel(index);
    final gold = index < _game.config.dailyGold.length ? _game.config.dailyGold[index] : 0;
    final diamond = index < _game.config.dailyDiamond.length ? _game.config.dailyDiamond[index] : 0;
    final joker = index < _game.config.dailyJoker.length ? _game.config.dailyJoker[index] : 0;
    if (diamond > 0) return '${diamond * 2} elmas';
    if (joker > 0) return '${joker * 2} joker';
    if (gold > 0) return '${gold * 2} altın';
    return label;
  }

  Widget _podium(List<BilgiProfile> top, int Function(BilgiProfile) scoreOf, String meId) {
    Widget place(BilgiProfile user, int rank) {
      final ring = rank == 1 ? const Color(0xFFFFB800) : (rank == 2 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32));
      final height = rank == 1 ? 90.0 : (rank == 2 ? 60.0 : 40.0);
      return Expanded(
        child: Column(
          children: [
            Container(
              width: rank == 1 ? 64 : 52,
              height: rank == 1 ? 64 : 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: ring, width: 3), color: BilgiColors.card),
              child: Text(user.avatar, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 6),
            Text(user.username, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            Text(_grouped(scoreOf(user)), style: const TextStyle(color: BilgiColors.secondary, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Container(
              height: height,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [BilgiColors.primary, BilgiColors.primaryLight]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
              ),
              child: Text('$rank', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
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

  Widget _boardRow(int rank, BilgiProfile user, int score, bool me) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: me ? const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight]) : null,
          color: me ? null : BilgiColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 10),
            Text(user.avatar, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.username, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (user.city.isNotEmpty) Text(user.city, style: TextStyle(color: me ? const Color(0xE6FFFFFF) : BilgiColors.muted, fontSize: 11)),
                ],
              ),
            ),
            Text(_grouped(score), style: TextStyle(color: me ? Colors.white : BilgiColors.secondary, fontWeight: FontWeight.w800)),
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

class _BilgiWatchAdCard extends StatefulWidget {
  const _BilgiWatchAdCard({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onWatch,
  });

  final String title;
  final String subtitle;
  final String buttonLabel;
  final Future<void> Function() onWatch;

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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Material(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _busy ? null : _tap,
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
                      Text(
                        widget.subtitle,
                        style: const TextStyle(color: BilgiColors.muted, fontSize: 12.5, fontWeight: FontWeight.w500),
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
