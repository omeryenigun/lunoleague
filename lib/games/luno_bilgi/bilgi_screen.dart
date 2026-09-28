import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_controller.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
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
          child: Column(
            children: [
              Expanded(child: _page(user)),
              if (_game.showNav) BilgiBottomNav(current: _navId(), onSelect: _game.tab),
            ],
          ),
        ),
      ),
    );
  }

  String _navId() {
    return switch (_game.page) {
      'categories' || 'detail' || 'setup' || 'group' || 'room' => 'play',
      _ => _game.page,
    };
  }

  Widget _page(BilgiProfile? user) {
    if (user == null && _game.page != 'maintenance') {
      return const Center(child: Text('📚 Kategoriler yükleniyor...'));
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
      'settings' => _settings(user!),
      'achievements' => _achievements(user!),
      'history' => _history(),
      'login' => _auth(register: false),
      'register' => _auth(register: true),
      'forgot' => _forgot(),
      'invite' => _invite(user!),
      'legal' => _legal(),
      'error' => _error(),
      'notify' => _notify(),
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
    const popularIds = ['genel', 'turk_tarihi', 'cografya', 'futbol', 'sinema', 'mitoloji'];
    final popular = [
      for (final id in popularIds)
        if (_game.categories.where((category) => category.id == id).firstOrNull case final category?)
          if ((_game.categoryCounts[category.id] ?? 0) > 0) category,
    ];
    final dailyLine = ready
        ? (user.streak > 0 ? '${user.streak} günlük seri — $reward' : reward)
        : 'Yarının ödülü: $reward';
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [BilgiColors.primary, BilgiColors.secondary],
                ).createShader(bounds),
                child: const Text(
                  'Luno Bilgi',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
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
                          ready ? '🎁 Günün Ödülü Hazır!' : '🎁 Günün ödülü',
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
                    child: const Text('Al', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                            const Text('🎮 Bugünkü Ücretsiz Oyunun', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            if (free)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: BilgiColors.secondary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'HAZIR',
                                  style: TextStyle(color: BilgiColors.bg, fontSize: 10, fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          free ? 'Reklamsız oyna — sadece bugün' : 'Sonraki oyun öncesi reklam açılır',
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
                    child: const Text('Oyna', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
        _sectionTitle('Hızlı Başla', 'Tümü →', () => _game.tab('play')),
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
                        Text(mode.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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
          _sectionTitle('Popüler Kategoriler', 'Tümü →', () => _game.open('categories')),
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
                                category.name,
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
                    '📚 Tüm Kategorileri Gör (${_game.categories.where((category) => (_game.categoryCounts[category.id] ?? 0) > 0).length})',
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
                    child: const Text('HAFTALIK ETKİNLİK', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(height: 10),
                  const Text('🏆 Luno Ligi Başladı!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                    'Bu hafta en çok puan topla, 10.000 altın kazan',
                    style: TextStyle(fontSize: 12, color: Color(0xE6FFFFFF)),
                  ),
                  const SizedBox(height: 14),
                  TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: BilgiColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _game.open('event'),
                    child: const Text('Katıl', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: BilgiColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0x26FFFFFF)),
          ),
          child: const Text(
            '📢 Reklam Alanı — Banner',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: BilgiColors.muted, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  String _modeLine(BilgiMode mode) {
    if (mode.totalSeconds > 0) return '${mode.questions} soru • ${mode.totalSeconds ~/ 60} dk';
    if (mode.seconds == 0) return '${mode.questions} soru • Süresiz';
    return '${mode.questions} soru • ${mode.seconds} sn';
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
    return ListView(
      children: [
        const BilgiTopBar(title: 'Oyna'),
        if (_game.notice != null) _note(_game.notice!),
        for (final mode in bilgiModes) _tile(mode.emoji, mode.name, mode.blurb, () => _game.selectMode(mode.id)),
      ],
    );
  }

  Widget _categories() {
    final query = _categoryQuery.text.trim().toLowerCase();
    return Column(
      children: [
        BilgiTopBar(title: 'Kategoriler', onBack: _game.back),
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
                    decoration: const InputDecoration(
                      hintText: 'Kategori ara...',
                      hintStyle: TextStyle(color: BilgiColors.muted, fontSize: 14),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                if (_game.categories.where((category) => category.group == group && (_game.categoryCounts[category.id] ?? 0) > 0 && _matchesCategory(category, query)).toList() case final rows when rows.isNotEmpty) ...[
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
    return category.name.toLowerCase().contains(query) || category.group.toLowerCase().contains(query);
  }

  String _groupLabel(String group) {
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
    final line = karma ? 'Tümü Karma' : (count == null ? '…' : '$count soru');
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
                Text(category.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
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
    final name = tumu ? 'Tümü Karma' : category.name;
    final emoji = tumu ? '🃏' : category.emoji;
    final live = _game.categories.where((item) => item.id == _game.categoryId).firstOrNull;
    final subs = tumu ? const <String>[] : (live?.subs ?? category.subs);
    final approved = _game.categoryCounts[_game.categoryId] ?? _game.poolCount;
    final heroCount = approved > 0 ? '$approved soru' : (_game.poolCount > 0 ? '${_game.poolCount} soru' : '…');
    final heroSub = subs.isEmpty ? heroCount : '$heroCount • ${subs.length} alt kategori';
    final highlight = _playDifficulty(_game.difficulty) ? _game.difficulty : 'kolay';
    return Column(
      children: [
        BilgiTopBar(title: 'Kategori Detay', onBack: _game.back),
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
              _sectionLabel('ALT KATEGORİLER'),
              _subRow(
                icon: '🎲',
                title: tumu ? 'Tümü Karma' : category.karmaName,
                subtitle: 'Tüm alt kategorilerden karışık',
                karma: true,
                onTap: () => _game.selectSub(''),
              ),
              for (final sub in subs)
                _subRow(
                  icon: bilgiSubIcon(sub, _subEmoji(sub, category?.emoji ?? '📌')),
                  title: sub,
                  subtitle: '${_game.subCounts['${_game.categoryId}|$sub'] ?? 0} soru',
                  onTap: () => _game.selectSub(sub),
                ),
              _sectionLabel('ZORLUK SEVİYESİ'),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    for (final item in const [
                      ('Kolay', 'kolay'),
                      ('Orta', 'orta'),
                      ('Zor', 'zor'),
                      ('Efsane', 'efsane'),
                    ])
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
              _startButton(_game.busy ? null : _game.start),
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
    return Column(
      children: [
        BilgiTopBar(title: 'Oyun Ayarları', onBack: _game.back),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              if (_game.notice != null) _note(_game.notice!),
              _sectionLabel('ZORLUK'),
              for (final item in const [
                ('🟢', 'Kolay', 'kolay'),
                ('🟡', 'Orta', 'orta'),
                ('🔴', 'Zor', 'zor'),
                ('⚫', 'Efsane', 'efsane'),
              ])
                _choiceRow(item.$1, item.$2, highlight == item.$3, () => _game.selectDifficulty(item.$3)),
              _sectionLabel('SORU SAYISI'),
              for (final count in const [10, 20, 50])
                _choiceRow(
                  '📝',
                  '$count',
                  _game.questionChoice == count,
                  () => _game.selectQuestionChoice(count),
                  trailing: _game.questionChoice == count && playable != count ? '$playable soru' : null,
                ),
              _sectionLabel('MOD'),
              for (final item in const [
                ('⚡', 'Hızlı Tur (15 sn)', 'hizli'),
                ('🎯', 'Klasik Tur (20 sn)', 'klasik'),
                ('🧘', 'Sakin Mod (Süresiz)', 'sakin'),
              ])
                _choiceRow(item.$1, item.$2, modeId == item.$3, () => _game.selectPlayMode(item.$3)),
              const SizedBox(height: 8),
              _startButton(_game.busy ? null : _game.start),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gamePage() {
    final round = _game.round;
    final revealing = _game.revealing;
    final question = round?.current;
    if (round == null || (question == null && !revealing)) {
      return const Center(child: Text('🎮 Sorular hazırlanıyor...'));
    }
    final letters = ['A', 'B', 'C', 'D'];
    final text = revealing ? _game.revealText : question!.text;
    final options = revealing ? _game.revealOptions : question!.options;
    final difficulty = _difficultyLabel(revealing ? _game.revealDifficulty : question!.difficulty);
    final number = revealing ? _game.revealNumber : round.index + 1;
    final timed = round.seconds > 0;
    final marathon = round.totalSeconds > 0 && !timed;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Row(
          children: [
            _quitButton(),
            Expanded(
              child: Text(
                'Soru $number / ${round.questions.length}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: BilgiColors.muted, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(12)),
              child: Text('⭐ ${round.score}', style: const TextStyle(color: BilgiColors.secondary, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        if (round.opponentName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Rakip: ${round.opponentName}${round.opponentScore >= 0 ? ' • ${round.opponentScore}' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: BilgiColors.muted, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        if (timed || marathon) ...[
          Row(
            children: [
              Text(
                timed ? '⏱️ ${_game.secondsLeft} saniye' : '⏱️ ${_game.marathonLeft ~/ 60}:${(_game.marathonLeft % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(color: BilgiColors.warning, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text('Zorluk: $difficulty', style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
            ],
          ),
          if (timed) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 8,
                child: Stack(
                  children: [
                    const ColoredBox(color: BilgiColors.card, child: SizedBox.expand()),
                    FractionallySizedBox(
                      widthFactor: round.seconds == 0 ? 0 : (_game.secondsLeft / round.seconds).clamp(0.0, 1.0),
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
          ],
          const SizedBox(height: 16),
        ],
        if (round.paused) _note('Süre durdu • ${_game.pauseLeft} sn'),
        if (round.hint.isNotEmpty) _note(round.hint),
        Container(
          constraints: const BoxConstraints(minHeight: 140),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(16)),
          child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, height: 1.5)),
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
        const SizedBox(height: 16),
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
                  _game.profile?.jokers[item.$1] ?? 0,
                  round.jokersUsed >= round.jokerMax ? null : () => _game.useJoker(item.$1),
                ),
            ],
          ),
        ),
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
              Text(won ? 'Harika Oyun!' : 'Tur bitti', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('${mode.name} tamamlandı', style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 13)),
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
            Expanded(child: _statBox('Doğru', '${round.correct}', BilgiColors.secondary)),
            const SizedBox(width: 10),
            Expanded(child: _statBox('Yanlış', '${round.wrong}', BilgiColors.error)),
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
        _startButton(_game.replaySetup, label: '🔄 Tekrar Oyna'),
        const SizedBox(height: 12),
        _secondaryButton('📊 Liderlik Tablosunu Gör', () => _game.tab('league')),
        const SizedBox(height: 12),
        _secondaryButton('🏠 Ana Menü', () => _game.tab('home')),
        const SizedBox(height: 12),
        _secondaryButton('📤 Arkadaşlarınla Paylaş', () {
          Clipboard.setData(ClipboardData(text: '${mode.name} • ${_grouped(round.score)} puan • ${round.correct} doğru'));
          _game.flash('Sonuç panoya kopyalandı.');
        }),
        const SizedBox(height: 16),
        _adBanner(),
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
                  Text('Seviye ${user.level}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
              _statBox('Toplam Oyun', '${user.gamesPlayed}', BilgiColors.text),
              _statBox(ratioLabel == null ? 'Doğru' : 'Doğru Oranı', ratioLabel ?? '${user.correctTotal}', BilgiColors.secondary),
              _statBox('En Yüksek Puan', _grouped(user.bestScore), BilgiColors.warning),
              _statBox('Giriş Serisi', '${user.streak} gün', BilgiColors.accent),
            ],
          ),
        ),
        _sectionLabel('ROZETLER'),
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
        _sectionLabel('HESAP'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _menuRow('📊', 'İstatistikler', 'Geçmiş ve skorlar', () => _game.open('history')),
                _menuRow('🎯', 'Başarılar', 'Görevler', () => _game.open('achievements')),
                _menuRow('📜', 'Oyun Geçmişi', user.gamesPlayed == 0 ? 'Henüz oyun yok' : '${user.gamesPlayed} oyun', () => _game.open('history')),
                _menuRow('⚙️', 'Ayarlar', 'Profil ve bildirim', () => _game.open('settings')),
                _menuRow('👥', 'Davet', user.inviteCode, () => _game.open('invite')),
                _menuRow('🔐', 'Giriş', 'Hesabını bu cihazda aç', () => _game.open('login'), last: true),
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
        const BilgiTopBar(title: 'Mağaza'),
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
        BilgiTopBar(title: 'Düello', onBack: _game.back),
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
        BilgiTopBar(title: 'Grup', onBack: _game.back),
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
                  const Text('Kodu kopyala. Oyuncu bekleme ve eşleştirme henüz yok.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Text('${room.players.length} oyuncu', style: const TextStyle(color: BilgiColors.muted)),
                  for (final player in room.players) Text('${player['name']} • ${player['role']}'),
                  TextButton(
                    onPressed: () => Clipboard.setData(ClipboardData(text: room.code)),
                    child: const Text('Kodu kopyala'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          BilgiPrimaryButton(label: 'Başlat', onTap: _game.startRoom),
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
    return ListView(
      children: [
        BilgiTopBar(title: 'Günün sorusu', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('1 soru • 30 sn • doğruysa 100 altın ve 50 XP. Can ve joker yok.'),
        ),
        BilgiPrimaryButton(
          label: _game.busy ? '🎮 Sorular hazırlanıyor...' : 'Başla',
          onTap: _game.busy
              ? null
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
        BilgiTopBar(title: 'Etkinlikler', onBack: _game.back),
        if (_game.eventRows.isEmpty)
          const Padding(padding: EdgeInsets.all(20), child: Text('Kayıtlı etkinlik yok.'))
        else
          for (final event in _game.eventRows)
            _tile('🎉', '${event['title'] ?? 'Etkinlik'}', '${event['body'] ?? ''}', null),
      ],
    );
  }

  Widget _settings(BilgiProfile user) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        BilgiTopBar(title: 'Ayarlar', onBack: _game.back),
        if (_game.notice != null) _note(_game.notice!),
        _sectionLabel('TERCİHLER'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _toggleRow('🔔', 'Bildirimler', _game.notifyOn, _game.toggleNotify),
                _toggleRow('🔊', 'Ses & Müzik', _game.soundOn, _game.toggleSound),
                _toggleRow('🌙', 'Koyu Tema', true, null, last: true),
              ],
            ),
          ),
        ),
        _sectionLabel('HESAP'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _menuRow('🌐', 'Dil', 'Türkçe ›', () => _game.flash('Bilgi ekranları Türkçe.')),
                _menuRow('👤', 'Hesap Bilgileri', user.username, () => setState(() => _showAccountForm = !_showAccountForm)),
                _menuRow('📄', 'Gizlilik', 'Gizlilik ve koşullar', () => _game.open('legal')),
                _menuRow('👥', 'Davet', user.inviteCode, () => _game.open('invite'), last: true),
              ],
            ),
          ),
        ),
        if (_showAccountForm)
          _FormCard(
            title: 'Profil',
            fields: const ['Kullanıcı adı', 'Şehir'],
            initial: [user.username, user.city],
            submit: 'Kaydet',
            onSubmit: (values) => _game.saveProfile(username: values[0], city: values[1]),
          ),
        _sectionLabel('DESTEK'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _card(
            child: Column(
              children: [
                _menuRow('❓', 'Yardım & SSS', 'Nasıl oynanır', () => _game.flash('Kategori seç, soruları yanıtla, altın kazan.')),
                _menuRow('✉️', 'İletişim', _game.config.supportEmail, () => _game.flash(_game.config.supportEmail)),
                _menuRow('ℹ️', 'Hakkında', gameVersionCode, null, last: true),
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
          BilgiTopBar(title: 'Başarılar', onBack: _game.back),
          const Padding(padding: EdgeInsets.all(20), child: Text('🎯 Henüz başarı tamamlamadın.')),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        BilgiTopBar(title: 'Başarılar', onBack: _game.back),
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
        BilgiTopBar(title: 'Oyun Geçmişi', onBack: _game.back),
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
          child: Text('Şifre yalnızca bu cihazdaki hesap için güncellenir.'),
        ),
        _FormCard(
          title: 'Yeni şifre',
          fields: const ['E-posta', 'Yeni şifre'],
          submit: 'Güncelle',
          onSubmit: (values) => _game.resetPassword(values[0], values[1]),
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

  Widget _notify() {
    return ListView(
      children: [
        BilgiTopBar(title: 'Bildirim', onBack: _game.back),
        const Padding(
          padding: EdgeInsets.all(20),
          child: Text('Günlük ödül ve lig hatırlatması için bildirim izni istenir. Tarayıcıda sistem izni açılmaz.'),
        ),
        BilgiPrimaryButton(label: 'Tamam', onTap: _game.back),
      ],
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
    const steps = [
      ('1', 'Kategori Seç', 'Tarih, bilim, spor, mitoloji... 60 farklı kategoriden istediğini seç'),
      ('2', 'Soruları Cevapla', 'Süreli veya süresiz modda bilgini test et, jokerlerini akıllı kullan'),
      ('3', 'Ödülleri Kazan', 'Altın, rozet, unvan kazan. Liderlik tablosunda zirveye çık'),
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
                        Align(
                          alignment: Alignment.center,
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [BilgiColors.primary, BilgiColors.secondary],
                            ).createShader(bounds),
                            child: const Text(
                              'Luno Bilgi',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text('Bilgiye Luno Kat!', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('60 kategori, 6 mod, binlerce soru', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: BilgiColors.muted)),
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
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Text('🚀 Hemen Başla', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
        'orta' => 'Orta',
        'zor' => 'Zor',
        'efsane' => 'Efsane',
        _ => 'Kolay',
      };

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

  Widget _choiceRow(String icon, String title, bool active, VoidCallback onTap, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Material(
        color: BilgiColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: active ? BilgiColors.primary : const Color(0x33FFFFFF), width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                if (trailing != null) Text(trailing, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: active ? BilgiColors.primary : Colors.transparent,
                    border: active ? null : Border.all(color: const Color(0x33FFFFFF), width: 2),
                  ),
                  child: active ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _startButton(VoidCallback? onTap, {String label = '🚀 Oyunu Başlat'}) {
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
              child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _adBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x40FFFFFF)),
      ),
      child: const Text(
        '📢 Reklam Alanı — Banner',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: BilgiColors.muted, fontWeight: FontWeight.w600),
      ),
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

  Widget _quizOption(String letter, String text, {required bool hidden, required bool correct, required bool wrong, required VoidCallback? onTap}) {
    Color border = Colors.transparent;
    Color fill = BilgiColors.card;
    Color chip = BilgiColors.bg;
    if (correct) {
      border = BilgiColors.secondary;
      fill = const Color(0x2600D9C0);
      chip = BilgiColors.secondary;
    } else if (wrong) {
      border = BilgiColors.error;
      fill = const Color(0x26FF4D6D);
      chip = BilgiColors.error;
    }
    return Material(
      color: hidden ? BilgiColors.bg : fill,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: hidden ? Colors.transparent : border, width: 2)),
      child: InkWell(
        onTap: hidden ? null : onTap,
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
                child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(hidden ? '—' : text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: hidden ? BilgiColors.muted : BilgiColors.text))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _jokerButton(String emoji, int stock, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 60,
        height: 60,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: BilgiColors.bg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1AFFFFFF), width: 2),
              ),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
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
            const Text(' ›', style: TextStyle(color: BilgiColors.muted)),
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

class _FormCard extends StatefulWidget {
  const _FormCard({
    required this.title,
    required this.fields,
    required this.submit,
    required this.onSubmit,
    this.initial = const [],
  });

  final String title;
  final List<String> fields;
  final String submit;
  final void Function(List<String> values) onSubmit;
  final List<String> initial;

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
        ],
      ),
    );
  }
}
