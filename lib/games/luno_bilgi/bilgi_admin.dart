import 'dart:async';

import 'package:flutter/material.dart';
import 'package:kelimelig/admin/word_csv_pick.dart';
import 'package:kelimelig/api/bilgi_bank_query.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/core/mail/mail_template.dart';
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_contest.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_daily_paper.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_csv.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_mail.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_question_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_sub_counts.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_user_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';
import 'package:kelimelig/injection.dart';

Widget _specialEventTag({bool compact = false}) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0x33F59E0B),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0x66F59E0B)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.celebration, size: compact ? 12 : 14, color: const Color(0xFFFBBF24)),
        const SizedBox(width: 4),
        Text(
          bilgiSpecialEventGroup,
          style: TextStyle(color: const Color(0xFFFBBF24), fontSize: compact ? 10 : 11, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class BilgiAdminScreen extends StatefulWidget {
  const BilgiAdminScreen({super.key, required this.onLeave});

  final VoidCallback onLeave;

  @override
  State<BilgiAdminScreen> createState() => _BilgiAdminScreenState();
}

class _BilgiAdminScreenState extends State<BilgiAdminScreen> {
  var _index = 0;
  var _note = '';
  DateTime _contestMonth = DateTime(DateTime.now().year, DateTime.now().month);
  List<BilgiContestDay> _contestDays = const [];
  var _contestBusy = false;
  var _contestPoll = 0;
  var _contestGeneratingDay = '';
  DateTime? _contestSince;
  Timer? _contestTimer;
  final _contestTitles = <String, TextEditingController>{};
  List<BilgiProfile> _users = const [];
  List<BilgiProfile> _leagueUsers = const [];
  BilgiConfig _config = const BilgiConfig();
  Map<String, dynamic> _catalog = const {};
  List<Map<String, dynamic>> _events = const [];
  var _leagueBoard = 'all';
  var _settledWeek = '';
  List<Map<String, dynamic>> _staff = const [];
  List<Map<String, dynamic>> _games = const [];
  final _rewardAmounts = List.generate(7, (_) => TextEditingController());
  final _topSearch = TextEditingController();
  final _dailyFree = TextEditingController();
  final _preRoll = TextEditingController();
  final _firstFree = TextEditingController();
  final _rewardGold = TextEditingController();
  final _goldLimit = TextEditingController();
  final _jokerLimit = TextEditingController();
  final _lifeLimit = TextEditingController();
  final _doubleLimit = TextEditingController();
  final _appName = TextEditingController();
  final _supportMail = TextEditingController();
  var _bankCat = '';
  var _bankSub = '';
  var _distCat = '';
  var _distSub = '';
  var _bankDiff = '';
  var _bankStatus = '';
  var _bankLang = '';
  var _bankReviewed = '';
  var _bankDetail = '';
  var _bankPage = 0;
  var _bankPageSize = bilgiBankPageSize;
  BilgiBankSummary _bankSummary = BilgiBankSummary.empty;
  List<BilgiQuestion> _bankRows = const [];
  int _bankTotal = 0;
  var _bankLoading = false;
  var _bankSerial = 0;
  var _bankSearchQuiet = false;
  Timer? _bankTimer;
  final _readyById = <String, bool>{};
  final _selectedQuestions = <String, BilgiQuestion>{};
  List<BilgiQuestion> _pendingRows = const [];
  List<BilgiQuestion> _rejectedRows = const [];
  List<int> _distLetters = const [0, 0, 0, 0];
  List<int> _distDiffs = const [0, 0, 0, 0];
  var _distOther = 0;
  Map<BilgiPublishedKey, int> _distMatrix = const {};
  var _labels = const <String, String>{};
  var _moveCat = '';
  var _moveSub = '';
  final _selectedIds = <String>{};
  var _bulkBusy = false;
  var _bulkMenu = '';
  var _formSerial = 0;
  final _translatingIds = <String>{};
  static const _translateLanes = 3;
  static const _translateGap = Duration(seconds: 1);
  String? _reviewingId;
  BilgiQuestion? _editing;
  var _csvName = '';
  final _csvText = TextEditingController();
  final _newSub = TextEditingController();
  final _subSearch = TextEditingController();
  final _bankSearch = TextEditingController();
  final _mailSubject = TextEditingController();
  final _mailHtml = TextEditingController();
  final _mailText = TextEditingController();
  final _mailTestTo = TextEditingController(text: 'omeryenigun@gmail.com');
  var _mailLoaded = false;
  var _reportsLoaded = false;
  List<BilgiQuestionReport> _reports = const [];
  var _reportsError = '';
  final _reportEditMisses = <String, String>{};
  final _reportStatusErrors = <String, String>{};
  final _reportStatusBusy = <String>{};
  var _subCat = 'turk_tarihi';
  var _userFirstGame = '';
  var _userActiveGame = '';
  var _userStatus = '';
  var _userPeriod = '';
  var _userPlays = '';
  BilgiProfile? _ledgerUser;
  List<BilgiLedgerLine> _ledgerLines = const [];
  var _ledgerAsset = '';
  var _ledgerReason = '';
  var _ledgerFlow = '';
  var _ledgerError = '';
  final _ledgerFrom = TextEditingController();
  final _ledgerTo = TextEditingController();

  LunoBilgiServer get _server => sl<LunoBilgiServer>();

  int get _pendingCount => _bankSummary.pendingReady;
  int get _bannedCount => _users.where((u) => u.banned).length;
  int get _bankBadge => _bankSummary.bankBadge;

  static const _nav = <({String group, String emoji, String label})>[
    (group: 'GENEL', emoji: '📊', label: 'Dashboard'),
    (group: 'İÇERİK', emoji: '📚', label: 'Soru Bankası'),
    (group: 'İÇERİK', emoji: '📊', label: 'Soru şık dağılımı'),
    (group: 'İÇERİK', emoji: '🚩', label: 'Hatalı soru bildirimleri'),
    (group: 'İÇERİK', emoji: '➕', label: 'Soru Ekle'),
    (group: 'İÇERİK', emoji: '⏳', label: 'Onay Bekleyenler'),
    (group: 'İÇERİK', emoji: '🚫', label: 'Reddedilenler'),
    (group: 'İÇERİK', emoji: '📥', label: 'Toplu İçe Aktar'),
    (group: 'İÇERİK', emoji: '📂', label: 'Kategoriler'),
    (group: 'İÇERİK', emoji: '📁', label: 'Alt Kategoriler'),
    (group: 'İÇERİK', emoji: '🏷️', label: 'Etiketler'),
    (group: 'İÇERİK', emoji: '🎲', label: 'Karma Ayarları'),
    (group: 'KULLANICILAR', emoji: '👤', label: 'Kullanıcılar'),
    (group: 'KULLANICILAR', emoji: '🔨', label: 'Banlılar'),
    (group: 'KULLANICILAR', emoji: '👑', label: 'Premium'),
    (group: 'OYUN', emoji: '⚙️', label: 'Oyun Ayarları'),
    (group: 'OYUN', emoji: '🎮', label: 'Mod Ayarları'),
    (group: 'OYUN', emoji: '📅', label: 'Günlük Oyun'),
    (group: 'OYUN', emoji: '🃏', label: 'Joker Ayarları'),
    (group: 'OYUN', emoji: '❤️', label: 'Can Sistemi'),
    (group: 'EKONOMİ', emoji: '🪙', label: 'Ekonomi'),
    (group: 'EKONOMİ', emoji: '💎', label: 'Premium Paketler'),
    (group: 'EKONOMİ', emoji: '🎁', label: 'Günlük Ödüller'),
    (group: 'REKLAM', emoji: '📺', label: 'Reklam Ayarları'),
    (group: 'ETKİNLİKLER', emoji: '🎉', label: 'Etkinlikler'),
    (group: 'ANALİZ', emoji: '📈', label: 'İstatistikler'),
    (group: 'SİSTEM', emoji: '🔧', label: 'Ayarlar'),
    (group: 'SİSTEM', emoji: '🛡️', label: 'Yöneticiler'),
    (group: 'SİSTEM', emoji: '✉️', label: 'E-posta'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final field in _rewardAmounts) {
      field.dispose();
    }
    _topSearch.dispose();
    _dailyFree.dispose();
    _preRoll.dispose();
    _firstFree.dispose();
    _rewardGold.dispose();
    _goldLimit.dispose();
    _jokerLimit.dispose();
    _lifeLimit.dispose();
    _doubleLimit.dispose();
    _appName.dispose();
    _supportMail.dispose();
    _csvText.dispose();
    _newSub.dispose();
    _subSearch.dispose();
    _bankTimer?.cancel();
    _contestTimer?.cancel();
    _bankSearch.dispose();
    _mailSubject.dispose();
    _mailHtml.dispose();
    _mailText.dispose();
    _mailTestTo.dispose();
    for (final field in _contestTitles.values) {
      field.dispose();
    }
    _ledgerFrom.dispose();
    _ledgerTo.dispose();
    super.dispose();
  }

  Future<void> _saveRemote(List<BilgiQuestion> questions) async {
    final error = await BilgiQuestionApi.save(sl<ApiSession>().adminToken ?? '', questions);
    if (error != null) throw StateError(error);
    for (final question in questions) {
      await _server.saveQuestion(question);
    }
  }

  void _rememberSaved(List<BilgiQuestion> questions) {
    if (!mounted || questions.isEmpty) return;
    setState(() {
      for (final question in questions) {
        _selectedQuestions[question.id] = question;
        _bankRows = [for (final row in _bankRows) row.id == question.id ? question : row];
        _pendingRows = [for (final row in _pendingRows) row.id == question.id ? question : row];
        _rejectedRows = [for (final row in _rejectedRows) row.id == question.id ? question : row];
      }
    });
  }

  List<BilgiQuestion> _chosenSelected() => [
        for (final id in _selectedIds)
          if (_selectedQuestions[id] != null) _selectedQuestions[id]!,
      ];

  BilgiQuestion? _questionById(String id) {
    final selected = _selectedQuestions[id];
    if (selected != null) return selected;
    for (final row in _bankRows) {
      if (row.id == id) return row;
    }
    for (final row in _pendingRows) {
      if (row.id == id) return row;
    }
    for (final row in _rejectedRows) {
      if (row.id == id) return row;
    }
    return null;
  }

  bool _rowReady(BilgiQuestion question) {
    if (question.translations.isNotEmpty) return _questionReady(question);
    return _readyById[question.id] ?? false;
  }

  void _storePage(BilgiBankPage page) {
    for (var i = 0; i < page.questions.length; i++) {
      final question = page.questions[i];
      _readyById[question.id] = i < page.ready.length && page.ready[i];
      if (_selectedIds.contains(question.id)) _selectedQuestions[question.id] = question;
    }
  }

  Future<void> _deleteRemote(String id) async {
    final error = await BilgiQuestionApi.delete(sl<ApiSession>().adminToken ?? '', id);
    if (error != null) throw StateError(error);
  }

  Future<void> _pushLocalBankOnce() async {
    if (await _server.readMeta('questionsPushedToApi') == '1') return;
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) return;
    final local = await _server.questions();
    if (local.isEmpty) {
      await _server.writeMeta('questionsPushedToApi', '1');
      return;
    }
    final error = await BilgiQuestionApi.save(token, local);
    if (error != null) return;
    await _server.writeMeta('questionsPushedToApi', '1');
  }

  Future<void> _refreshQuestionViews() async {
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isNotEmpty) {
      final summary = await BilgiQuestionApi.loadSummary(token);
      if (mounted && summary != null) setState(() => _bankSummary = summary);
    }
    await _loadBankPage();
    if (_index == 2) await _loadDistribution();
    if (_index == 5) await _loadPending();
    if (_index == 6) await _loadRejected();
  }

  Future<void> _loadBankPage() async {
    final serial = ++_bankSerial;
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) {
      if (!mounted || serial != _bankSerial) return;
      final local = await _server.questions();
      final category = _categories.where((item) => item.id == _bankCat).firstOrNull;
      final rows = bilgiFilterBankQuestions(
        local,
        categoryId: _bankCat,
        subcategory: _bankSub,
        difficulty: _bankDiff,
        status: _bankStatus,
        translation: _bankLang,
        reviewed: _bankReviewed,
        detail: _bankDetail,
        search: _bankSearch.text,
        categorySubs: category?.subs ?? const <String>[],
        isTranslated: _questionReady,
      );
      final window = bilgiBankWindow(rows, _bankPage, pageSize: _bankPageSize);
      setState(() {
        _bankRows = window.slice;
        _bankTotal = window.total;
        _bankPage = window.page;
        _bankLoading = false;
      });
      return;
    }
    if (mounted) setState(() => _bankLoading = true);
    final page = await BilgiQuestionApi.loadPage(
      token,
      category: _bankCat,
      sub: _bankSub,
      difficulty: _bankDiff,
      status: _bankStatus,
      translation: _bankLang,
      reviewed: _bankReviewed,
      detail: _bankDetail,
      search: _bankSearch.text,
      page: _bankPage,
      size: _bankPageSize,
    );
    if (!mounted || serial != _bankSerial) return;
    if (page == null) {
      setState(() => _bankLoading = false);
      return;
    }
    setState(() {
      _storePage(page);
      _bankRows = page.questions;
      _bankTotal = page.total;
      _bankPage = page.page;
      _bankLoading = false;
    });
  }

  Future<List<BilgiQuestion>> _collectPages({
    String status = '',
    String translation = '',
    int limit = 1000,
  }) async {
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) return const [];
    final first = await BilgiQuestionApi.loadPage(
      token,
      category: status.isEmpty ? _bankCat : '',
      sub: status.isEmpty ? _bankSub : '',
      difficulty: status.isEmpty ? _bankDiff : '',
      status: status.isEmpty ? _bankStatus : status,
      translation: translation.isEmpty ? (status.isEmpty ? _bankLang : translation) : translation,
      reviewed: status.isEmpty ? _bankReviewed : '',
      detail: status.isEmpty ? _bankDetail : '',
      search: status.isEmpty ? _bankSearch.text : '',
      page: 0,
      size: 200,
      select: true,
    );
    if (first == null) return const [];
    final out = [...first.questions];
    _storePage(first);
    var page = 1;
    while (out.length < first.total && out.length < limit && page < first.pages) {
      final next = await BilgiQuestionApi.loadPage(
        token,
        category: status.isEmpty ? _bankCat : '',
        sub: status.isEmpty ? _bankSub : '',
        difficulty: status.isEmpty ? _bankDiff : '',
        status: status.isEmpty ? _bankStatus : status,
        translation: translation.isEmpty ? (status.isEmpty ? _bankLang : translation) : translation,
        reviewed: status.isEmpty ? _bankReviewed : '',
        detail: status.isEmpty ? _bankDetail : '',
        search: status.isEmpty ? _bankSearch.text : '',
        page: page,
        size: 200,
        select: true,
      );
      if (next == null || next.questions.isEmpty) break;
      _storePage(next);
      out.addAll(next.questions);
      page++;
    }
    return out;
  }

  Future<void> _selectAllFiltered() async {
    if (_bulkBusy) return;
    final rows = await _collectPages();
    if (!mounted) return;
    setState(() {
      for (final question in rows) {
        _selectedIds.add(question.id);
        _selectedQuestions[question.id] = question;
      }
      if (_bankTotal > rows.length) {
        _note = 'Filtrede $_bankTotal soru var. ${rows.length} tanesi seçildi.';
      }
    });
  }

  Future<void> _loadPending() async {
    final rows = await _collectPages(status: 'pending', translation: 'ready');
    if (!mounted) return;
    setState(() => _pendingRows = rows);
  }

  Future<void> _loadRejected() async {
    final rows = await _collectPages(status: 'rejected');
    if (!mounted) return;
    setState(() => _rejectedRows = rows);
  }

  Future<void> _loadDistribution() async {
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) return;
    final result = await BilgiQuestionApi.loadDistribution(token, category: _distCat, sub: _distSub);
    if (!mounted || result == null) return;
    setState(() {
      _distLetters = result.letters;
      _distDiffs = result.difficulties;
      _distOther = result.other;
      _distMatrix = result.matrix;
    });
  }

  void _scheduleBank() {
    _bankTimer?.cancel();
    _bankTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _loadBankPage();
    });
  }

  void _retuneBank() {
    _bankTimer?.cancel();
    _bankPage = 0;
    _selectedIds.clear();
    _selectedQuestions.clear();
    _loadBankPage();
  }

  Future<void> _applyRemoteActive() async {
    final active = await BilgiQuestionApi.loadActive();
    if (active == null) return;
    final catalog = await _server.catalog();
    await _server.saveCatalog(bilgiCatalogClosedUnless(catalog, active.categories, active.subs));
  }

  Future<({List<BilgiProfile> listed, List<BilgiProfile> players})> _usersBank() async {
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) {
      return (listed: await _server.listedUsers(), players: await _server.users());
    }
    final remote = await BilgiUserApi.loadAll(token);
    if (remote == null) {
      return (listed: await _server.listedUsers(), players: await _server.users());
    }
    return remote;
  }

  Future<void> _load() async {
    await _pushLocalBankOnce();
    final token = sl<ApiSession>().adminToken ?? '';
    final summary = token.isEmpty ? null : await BilgiQuestionApi.loadSummary(token);
    final labels = await BilgiQuestionApi.loadLabels();
    final bank = await _usersBank();
    final config = await _server.config();
    final events = await _server.events();
    final league = await BilgiLeagueApi.load(scope: 'global');
    final staff = await _server.staff();
    final games = await _server.games();
    final remote = await BilgiQuestionApi.loadCatalog();
    final Map<String, dynamic> catalog;
    if (remote != null) {
      final active = await BilgiQuestionApi.loadActive();
      catalog = active == null ? remote : bilgiCatalogClosedUnless(remote, active.categories, active.subs);
    } else {
      await _applyRemoteActive();
      catalog = await _server.catalog();
    }
    if (!mounted) return;
    setState(() {
      if (summary != null) _bankSummary = summary;
      _labels = labels;
      _selectedIds.clear();
      _users = bank.listed;
      _leagueUsers = bank.players;
      _config = config;
      _catalog = catalog;
      _events = events;
      _settledWeek = league?.settledWeek ?? '';
      _staff = staff;
      _games = games;
      for (var i = 0; i < 7; i++) {
        _rewardAmounts[i].text = '${_rewardAmount(i)}';
      }
      _dailyFree.text = '${config.dailyFreeGames}';
      _preRoll.text = '${config.preGameAdSeconds}';
      _firstFree.text = '${config.newUserAdFree}';
      _rewardGold.text = '${config.rewardedGold}';
      _goldLimit.text = '${config.rewardedGoldLimit}';
      _jokerLimit.text = '${config.rewardedJokerLimit}';
      _lifeLimit.text = '${config.rewardedLifeLimit}';
      _doubleLimit.text = '${config.rewardedDoubleLimit}';
      _appName.text = config.appName;
      _supportMail.text = config.supportEmail;
    });
    await _loadBankPage();
  }

  int _rewardAmount(int i) {
    if (_config.dailyDiamond.length > i && _config.dailyDiamond[i] > 0) return _config.dailyDiamond[i];
    if (_config.dailyJoker.length > i && _config.dailyJoker[i] > 0) return _config.dailyJoker[i];
    if (_config.dailyGold.length > i) return _config.dailyGold[i];
    return 0;
  }

  String _rewardKind(int i) {
    if (_config.dailyDiamond.length > i && _config.dailyDiamond[i] > 0) return 'Elmas';
    if (_config.dailyJoker.length > i && _config.dailyJoker[i] > 0) return 'Joker';
    if (i == 6) return 'Büyük Ödül';
    return 'Altın';
  }

  Future<void> _patch(void Function(Map<String, dynamic> map) edit) async {
    final map = Map<String, dynamic>.from(_config.toMap());
    edit(map);
    final next = BilgiConfig.fromMap(map);
    await _server.saveConfig(next);
    setState(() => _config = next);
  }

  String get _title {
    return switch (_index) {
      0 => 'Dashboard',
      4 => _editing == null ? 'Yeni Soru Ekle' : 'Soruyu Düzenle',
      5 => 'Onay Bekleyen Sorular',
      6 => 'Reddedilen Sorular',
      13 => 'Banlı Kullanıcılar',
      14 => 'Premium Kullanıcılar',
      20 => 'Ekonomi Ayarları',
      26 => 'Genel Ayarlar',
      28 => 'E-posta şablonu',
      _ => _nav[_index].label,
    };
  }

  String get _subtitle {
    return switch (_index) {
      0 => 'Luno Bilgi genel bakış',
      1 => '$_bankTotal soru • $_pendingCount onay bekliyor',
      2 => 'Doğru şıkkın A B C D dağılımı',
      3 => 'Oyuncuların hatalı soru bildirimleri',
      4 => _editing == null ? 'Soru bankasına yeni soru ekle' : 'Kayıtlı soruyu güncelle',
      5 => '$_pendingCount soru onay bekliyor',
      6 => '${_bankSummary.rejected} soru reddedildi',
      7 => 'Yalnızca CSV ile toplu soru yükle',
      8 => '${_categories.length} ana kategori • ${bilgiGroups.length} grup',
      12 => '${_users.length} kullanıcı • ${_users.where((u) => u.premium).length} premium',
      13 => '$_bannedCount kullanıcı banlı',
      14 => '${_users.where((u) => u.premium).length} premium üye',
      17 => 'Ayın her günü için ortak soru seti',
      22 => '7 günlük ödül takvimi',
      23 => 'Reklam stratejisi ve limitleri',
      24 => '${_events.where((e) => e['status'] == 'active').length} aktif • ${_events.where((e) => e['status'] == 'pending').length} bekleyen',
      25 => 'Detaylı analiz ve raporlar',
      26 => 'Uygulama geneli yapılandırma',
      _ => 'Luno Bilgi yönetim',
    };
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Theme(
      data: ThemeData.dark().copyWith(scaffoldBackgroundColor: BilgiColors.bg),
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sidebar(wide),
            Expanded(
              child: ColoredBox(
                color: BilgiColors.bg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _topBar(),
                    if (_note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: Text(_note, style: const TextStyle(color: BilgiColors.warning)),
                      ),
                    Expanded(child: _body()),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupLabel(String group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 6),
      child: Text(
        group,
        style: const TextStyle(color: BilgiColors.muted, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _sidebar(bool wide) {
    return Container(
      width: wide ? 240 : 72,
      decoration: const BoxDecoration(
        color: BilgiColors.sidebar,
        border: Border(right: BorderSide(color: Color(0x0DFFFFFF))),
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(wide ? 20 : 8, 24, wide ? 16 : 8, 8),
            child: wide
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [BilgiColors.primary, BilgiColors.secondary],
                        ).createShader(bounds),
                        child: const Text(
                          'Luno Admin',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'YÖNETİM PANELİ',
                        style: TextStyle(color: BilgiColors.muted, fontSize: 10, letterSpacing: 1.4, fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                : const Icon(Icons.admin_panel_settings, color: BilgiColors.primary),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (var i = 0; i < _nav.length; i++) ...[
                  if (wide && (i == 0 || _nav[i].group != _nav[i - 1].group)) _groupLabel(_nav[i].group),
                  _navTile(i, wide),
                ],
              ],
            ),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.arrow_back, color: Colors.white70, size: 18),
            title: wide ? const Text('Oyunlar', style: TextStyle(color: Colors.white70, fontSize: 13)) : null,
            onTap: widget.onLeave,
          ),
        ],
      ),
    );
  }

  Widget _navTile(int i, bool wide) {
    final active = i == _index;
    final item = _nav[i];
    int? badge;
    var badgeColor = BilgiColors.primary;
    if (i == 1 && _bankBadge > 0) badge = _bankBadge;
    if (i == 5 && _pendingCount > 0) badge = _pendingCount;
    if (i == 13) {
      badge = _bannedCount == 0 ? null : _bannedCount;
      badgeColor = BilgiColors.error;
    }
    return Tooltip(
      message: item.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (i == 4) {
              _openEditor();
              return;
            }
            setState(() => _index = i);
            if (i == 1) _loadBankPage();
            if (i == 2) _loadDistribution();
            if (i == 5) _loadPending();
            if (i == 6) _loadRejected();
            if (i == 17) _loadContest();
          },
          hoverColor: const Color(0x146C3CE9),
          child: Container(
            decoration: BoxDecoration(
              color: active ? const Color(0x266C3CE9) : null,
              border: Border(left: BorderSide(color: active ? BilgiColors.primary : Colors.transparent, width: 3)),
            ),
            padding: EdgeInsets.symmetric(horizontal: wide ? 16 : 8, vertical: 10),
            child: Row(
              children: [
                Text(item.emoji, style: TextStyle(fontSize: 16, color: active ? Colors.white : BilgiColors.muted)),
                if (wide) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(color: active ? Colors.white : BilgiColors.muted, fontSize: 13, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
                    ),
                  ),
                  if (badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: badgeColor, borderRadius: BorderRadius.circular(10)),
                      child: Text('$badge', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14FFFFFF)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_subtitle, style: const TextStyle(color: BilgiColors.muted, fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            width: 240,
            height: 40,
            child: TextField(
              controller: _topSearch,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Ara: soru, kullanıcı, kategori...',
                hintStyle: const TextStyle(color: BilgiColors.muted, fontSize: 12),
                filled: true,
                fillColor: BilgiColors.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () => setState(() => _index = 5),
            icon: const Icon(Icons.notifications_none, color: Colors.white70),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(20)),
            child: const Text('Admin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          if (_index == 1) ...[
            const SizedBox(width: 12),
            _ghost('📥 İçe Aktar', () => setState(() => _index = 7)),
            const SizedBox(width: 12),
            _primary('➕ Yeni Soru', _openEditor),
          ],
          if (_index == 4) ...[
            const SizedBox(width: 12),
            _primary('Toplu Soru Ekle', () => setState(() => _index = 7)),
          ],
          if (_index == 8) ...[
            const SizedBox(width: 12),
            _primary('Yeni Kategori', _addCategory),
          ],
        ],
      ),
    );
  }

  Future<void> _loadMail() async {
    final token = sl<ApiSession>().adminToken;
    if (token == null || token.isEmpty) {
      if (mounted) setState(() => _note = 'E-posta şablonu için yönetici oturumu gerekli.');
      return;
    }
    final template = await BilgiMailApi.load(token);
    if (!mounted || template == null) {
      if (mounted) setState(() => _note = 'E-posta şablonu alınamadı.');
      return;
    }
    setState(() {
      _mailSubject.text = template.subject;
      _mailHtml.text = template.htmlBody;
      _mailText.text = template.textBody;
    });
  }

  Future<void> _saveMail() async {
    final token = sl<ApiSession>().adminToken ?? '';
    final error = await BilgiMailApi.save(
      token,
      MailTemplate(subject: _mailSubject.text, htmlBody: _mailHtml.text, textBody: _mailText.text),
    );
    if (!mounted) return;
    setState(() => _note = error ?? 'E-posta şablonu kaydedildi.');
  }

  Future<void> _sendTestMail() async {
    final token = sl<ApiSession>().adminToken ?? '';
    final message = await BilgiMailApi.sendTest(token, _mailTestTo.text);
    if (!mounted) return;
    setState(() => _note = message);
  }

  Widget _mail() {
    if (!_mailLoaded) {
      _mailLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadMail());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        const Text('Yer tutucular: {{code}} ve {{email}}', style: TextStyle(color: BilgiColors.muted)),
        const SizedBox(height: 12),
        TextField(controller: _mailSubject, decoration: const InputDecoration(labelText: 'Konu')),
        const SizedBox(height: 12),
        TextField(controller: _mailHtml, maxLines: 8, decoration: const InputDecoration(labelText: 'HTML')),
        const SizedBox(height: 12),
        TextField(controller: _mailText, maxLines: 6, decoration: const InputDecoration(labelText: 'Düz metin')),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _primary('Şablonu kaydet', () { _saveMail(); }),
            SizedBox(width: 280, child: TextField(controller: _mailTestTo, decoration: const InputDecoration(labelText: 'Deneme adresi'))),
            _ghost('Deneme maili gönder', () { _sendTestMail(); }),
          ],
        ),
      ],
    );
  }

  Future<void> _loadReports() async {
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) {
      if (mounted) setState(() => _reportsError = 'Bildirimler için yönetici oturumu gerekli.');
      return;
    }
    final rows = await BilgiReportApi.load(token);
    if (!mounted) return;
    setState(() {
      _reports = rows ?? const [];
      _reportsError = rows == null ? 'Bildirimler alınamadı.' : '';
      _reportEditMisses.clear();
      _reportStatusErrors.clear();
      _reportStatusBusy.clear();
    });
  }

  BilgiQuestion? _questionForReport(BilgiQuestionReport report) {
    final id = report.questionId.trim();
    if (id.isNotEmpty) {
      final byId = _questionById(id);
      if (byId != null) return byId;
    }
    final text = report.questionText.trim();
    if (text.isEmpty) return null;
    for (final row in [..._bankRows, ..._pendingRows, ..._rejectedRows]) {
      if (row.text == text) return row;
    }
    return null;
  }

  Future<void> _openReportEditor(BilgiQuestionReport report) async {
    var question = _questionForReport(report);
    final id = report.questionId.trim();
    if (question == null && id.isNotEmpty) {
      question = await BilgiQuestionApi.loadOne(sl<ApiSession>().adminToken ?? '', id);
    }
    if (!mounted) return;
    if (question == null) {
      setState(() => _reportEditMisses[report.id] = 'Soru bankasında bulunamadı.');
      return;
    }
    setState(() => _reportEditMisses.remove(report.id));
    await _openEditor(question);
  }

  Future<void> _setReportStatus(BilgiQuestionReport report, String status) async {
    final next = normalizeBilgiReportStatus(status);
    if (report.status == next || _reportStatusBusy.contains(report.id)) return;
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) {
      if (mounted) {
        setState(() {
          _reportStatusErrors[report.id] = 'Bildirimler için yönetici oturumu gerekli.';
          _note = 'Bildirimler için yönetici oturumu gerekli.';
        });
      }
      return;
    }
    setState(() {
      _reportStatusBusy.add(report.id);
      _reportStatusErrors.remove(report.id);
    });
    final error = await BilgiReportApi.setStatus(token: token, reportId: report.id, status: next);
    if (!mounted) return;
    setState(() {
      _reportStatusBusy.remove(report.id);
      if (error != null) {
        _reportStatusErrors[report.id] = error;
        _note = error;
      } else {
        _reports = [
          for (final row in _reports)
            if (row.id == report.id) row.copyWith(status: next) else row,
        ];
        _note = 'Bildirim durumu: ${bilgiReportStatusLabel(next)}';
      }
    });
  }

  Color _reportStatusColor(String status) {
    return switch (normalizeBilgiReportStatus(status)) {
      bilgiReportStatusDikkateAlindi => BilgiColors.secondary,
      bilgiReportStatusDikkateAlinmadi => BilgiColors.error,
      _ => BilgiColors.warning,
    };
  }

  Widget _reportStatusChip(BilgiQuestionReport report, String status, String label) {
    final active = normalizeBilgiReportStatus(report.status) == status;
    final busy = _reportStatusBusy.contains(report.id);
    final color = _reportStatusColor(status);
    final fg = status == bilgiReportStatusDikkateAlindi ? BilgiColors.bg : Colors.white;
    return Padding(
      padding: const EdgeInsets.only(right: 8, bottom: 8),
      child: active
          ? Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
            )
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: BorderSide(color: color.withValues(alpha: 0.55)),
                minimumSize: const Size(0, 36),
              ),
              onPressed: busy ? null : () => _setReportStatus(report, status),
              child: Text(label),
            ),
    );
  }

  Widget _faultReports() {
    if (!_reportsLoaded) {
      _reportsLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadReports());
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Align(alignment: Alignment.centerLeft, child: _ghost('Yenile', () { _loadReports(); })),
        if (_reportsError.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(_reportsError, style: const TextStyle(color: BilgiColors.warning)),
        ],
        if (_reports.isEmpty && _reportsError.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('Hatalı soru bildirimi yok.', style: TextStyle(color: BilgiColors.muted)),
          ),
        for (final report in _reports) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(12)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(report.questionText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 12),
                    _badge(bilgiReportStatusLabel(report.status), _reportStatusColor(report.status)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${_catLabel(report.categoryId)} • ${report.difficulty} • ${report.createdAt}',
                  style: const TextStyle(color: BilgiColors.muted, fontSize: 12),
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < report.options.length; i++)
                  Text(
                    '${['A', 'B', 'C', 'D'][i.clamp(0, 3)]}. ${report.options[i]}',
                    style: TextStyle(
                      color: i == report.correct ? BilgiColors.secondary : Colors.white70,
                      fontWeight: i == report.correct ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(report.note, style: const TextStyle(color: Colors.white, height: 1.4)),
                const SizedBox(height: 12),
                const Text('Durum', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Wrap(
                  children: [
                    _reportStatusChip(report, bilgiReportStatusBekliyor, 'Bekliyor'),
                    _reportStatusChip(report, bilgiReportStatusDikkateAlindi, 'Dikkate alındı'),
                    _reportStatusChip(report, bilgiReportStatusDikkateAlinmadi, 'Dikkate alınmadı'),
                  ],
                ),
                if (_reportStatusBusy.contains(report.id)) ...[
                  const SizedBox(height: 4),
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: BilgiColors.primary),
                  ),
                ],
                if (_reportStatusErrors[report.id] case final statusError?) ...[
                  const SizedBox(height: 8),
                  Text(statusError, style: const TextStyle(color: BilgiColors.warning)),
                ],
                Align(
                  alignment: Alignment.centerLeft,
                  child: _primary('Soruyu düzenle', () => _openReportEditor(report)),
                ),
                if (_reportEditMisses[report.id] case final miss?) ...[
                  const SizedBox(height: 8),
                  Text(miss, style: const TextStyle(color: BilgiColors.warning)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  String get _contestMonthKey =>
      '${_contestMonth.year}-${_contestMonth.month.toString().padLeft(2, '0')}';

  Future<void> _loadContest() async {
    final loaded = await BilgiContestApi.adminLoad(sl<ApiSession>().adminToken ?? '', _contestMonthKey);
    if (!mounted) return;
    _applyContest(loaded);
  }

  void _applyContest(BilgiContestAdminResult loaded) {
    final month = loaded.month;
    setState(() {
      _note = loaded.error ?? '';
      if (month == null) return;
      _contestDays = month.days;
      for (final day in month.days) {
        _contestTitles.putIfAbsent(day.day, () => TextEditingController(text: day.title));
      }
    });
  }

  Future<void> _shiftContest(int delta) async {
    setState(() {
      _contestMonth = DateTime(_contestMonth.year, _contestMonth.month + delta);
      _contestDays = const [];
    });
    await _loadContest();
  }

  Future<void> _buildContestMonth() async {
    if (_contestBusy) return;
    setState(() => _contestBusy = true);
    final loaded = await BilgiContestApi.adminSave(
      sl<ApiSession>().adminToken ?? '',
      month: _contestMonthKey,
    );
    if (!mounted) return;
    setState(() => _contestBusy = false);
    _applyContest(loaded);
  }

  Future<void> _generateContestDay(String day) async {
    if (_contestBusy) return;
    final ticket = ++_contestPoll;
    var ticks = 0;
    setState(() {
      _contestBusy = true;
      _contestGeneratingDay = day;
      _contestSince = DateTime.now();
    });
    _contestTimer?.cancel();
    _contestTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || ticket != _contestPoll) return;
      ticks += 1;
      setState(() {});
      if (ticks % 4 == 0) _refreshContest(ticket);
    });
    final loaded = await BilgiContestApi.adminGenerate(sl<ApiSession>().adminToken ?? '', day);
    _contestTimer?.cancel();
    _contestPoll++;
    if (!mounted || ticket + 1 != _contestPoll) return;
    setState(() {
      _contestBusy = false;
      _contestGeneratingDay = '';
      _contestSince = null;
    });
    _applyContest(loaded);
  }

  Future<void> _refreshContest(int ticket) async {
    final loaded = await BilgiContestApi.adminLoad(sl<ApiSession>().adminToken ?? '', _contestMonthKey);
    if (!mounted || ticket != _contestPoll) return;
    _applyContest(loaded);
  }

  String _contestElapsedLabel() {
    final start = _contestSince;
    if (start == null) return '00:00';
    final gone = DateTime.now().difference(start);
    final minutes = gone.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = gone.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _contestClock(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return '';
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
  }

  List<String> _contestAiLines(BilgiContestDay day) {
    final lines = <String>[];
    if (day.aiStatus == 'running') {
      final detail = day.aiMessage.trim();
      lines.add(detail.isEmpty || detail == 'Üretiliyor' ? 'Üretiliyor' : 'Üretiliyor · $detail');
    } else if (day.aiStatus == 'ok') {
      final clock = _contestClock(day.aiLastOkAt);
      lines.add(clock.isEmpty ? 'Başarılı' : 'Başarılı · $clock');
    } else if (day.aiStatus == 'failed') {
      final detail = day.aiMessage.trim();
      lines.add(detail.isEmpty ? 'Başarısız' : 'Başarısız · $detail');
    }
    if (day.aiStatus != 'ok' && day.aiLastOkAt.isNotEmpty) {
      final clock = _contestClock(day.aiLastOkAt);
      if (clock.isNotEmpty) lines.add('Son başarılı yükleme · $clock');
    }
    return lines;
  }

  Future<void> _buildContestDay(String day, {bool rebuild = false}) async {
    if (_contestBusy) return;
    setState(() => _contestBusy = true);
    final loaded = await BilgiContestApi.adminSave(
      sl<ApiSession>().adminToken ?? '',
      day: day,
      title: _contestTitles[day]?.text.trim() ?? '',
      rebuild: rebuild,
    );
    if (!mounted) return;
    setState(() => _contestBusy = false);
    _applyContest(loaded);
  }

  Color _contestRowColor(BilgiContestDay day) {
    if (day.locked) return const Color(0xFF7F1D1D);
    if (day.count > 0) return const Color(0xFF166534);
    return BilgiColors.card;
  }

  Future<void> _openContestPaper(BilgiContestDay day, {required bool editing}) async {
    final paper = await BilgiContestApi.adminPaper(sl<ApiSession>().adminToken ?? '', day.day);
    if (!mounted) return;
    if (paper.error != null) {
      setState(() => _note = paper.error!);
      return;
    }
    if (paper.locked && editing) {
      setState(() => _note = 'Bu gün kilitli.');
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _ContestPaperDialog(
        day: day.day,
        questions: paper.questions,
        spares: paper.spares,
        editing: editing && !paper.locked,
      ),
    );
    if (saved == true) await _loadContest();
  }

  Widget _dailyContest() {
    final monthLabel = _contestMonthKey;
    final generating = _contestGeneratingDay;
    return MouseRegion(
      cursor: generating.isEmpty ? SystemMouseCursors.basic : SystemMouseCursors.progress,
      child: ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Row(
          children: [
            _ghost('‹', () => _shiftContest(-1)),
            const SizedBox(width: 12),
            Text(monthLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(width: 12),
            _ghost('›', () => _shiftContest(1)),
            const Spacer(),
            if (generating.isNotEmpty) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFDE68A)),
              ),
              const SizedBox(width: 8),
              Text(
                '$generating · ${_contestElapsedLabel()}',
                style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 16),
            ],
            _primary(
              _contestBusy && generating.isEmpty ? 'Yazılıyor' : 'Ayı oluştur',
              _contestBusy ? () {} : _buildContestMonth,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Soruları oluşan gün yeşil taslaktır. Kilitli gün kırmızıya döner ve değişmez. 9 Ekim 2026 ve sonrası AI ile üretilir; o günler boşken bankadan dolmaz.',
          style: TextStyle(color: BilgiColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (_contestDays.isEmpty)
          _ghost('Ayı yükle', _loadContest)
        else
          for (final day in _contestDays)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: _contestRowColor(day), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(width: 96, child: Text(day.day, style: const TextStyle(fontWeight: FontWeight.w700))),
                        SizedBox(
                          width: 72,
                          child: Text(
                            day.count == 0 ? 'Boş' : '${day.count} soru',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        if (day.locked)
                          const Text('Kilitli', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800))
                        else if (day.count > 0)
                          const Text('Taslak', style: TextStyle(color: Color(0xFF86EFAC), fontWeight: FontWeight.w800))
                        else
                          const Spacer(),
                      ],
                    ),
                    for (final line in _contestAiLines(day))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(line, style: const TextStyle(color: Color(0xFFFDE68A), fontSize: 12)),
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (day.locked)
                          _ghost('Görüntüle', () => _openContestPaper(day, editing: false))
                        else ...[
                          SizedBox(
                            width: 220,
                            child: TextField(
                              controller: _contestTitles[day.day],
                              maxLength: 40,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                hintText: 'Özel ad',
                                counterText: '',
                                isDense: true,
                                filled: true,
                                fillColor: Color(0x66000000),
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          _ghost('Adı kaydet', () => _buildContestDay(day.day)),
                          if (bilgiContestAiDay(day.day))
                            (day.day == generating
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Üretiliyor ${_contestElapsedLabel()}',
                                        style: const TextStyle(color: Color(0xFFFDE68A), fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  )
                                : _ghost('AI ile üret', _contestBusy ? () {} : () => _generateContestDay(day.day)))
                          else
                            _ghost(day.count == 0 ? 'Günü oluştur' : 'Yeniden yaz', () => _buildContestDay(day.day, rebuild: true)),
                          if (day.count > 0) ...[
                            _ghost('Görüntüle', () => _openContestPaper(day, editing: false)),
                            _ghost('Düzenle', () => _openContestPaper(day, editing: true)),
                          ],
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
      ],
    ),
    );
  }

  Widget _body() {
    return switch (_index) {
      0 => _summary(),
      1 => _questionList(null),
      2 => _optionDistribution(),
      3 => _faultReports(),
      4 => _editor(),
      5 => _questionList('pending'),
      6 => _questionList('rejected'),
      7 => _import(),
      8 => _categoryList(),
      9 => _subs(),
      10 => _tags(),
      11 => _karma(),
      12 => _userList(null),
      13 => _userList(true),
      14 => _userList(false, premium: true),
      15 => _toggles(),
      16 => _modes(),
      17 => _dailyContest(),
      18 => _jokers(),
      19 => _lives(),
      20 => _economy(),
      21 => _packs(),
      22 => _rewards(),
      23 => _ads(),
      24 => _eventEditor(),
      25 => _stats(),
      26 => _general(),
      27 => _admins(),
      28 => _mail(),
      _ => _admins(),
    };
  }

  Widget _optionDistribution() {
    final counts = _distLetters;
    final difficultyCounts = _distDiffs;
    final otherDifficulty = _distOther;
    final total = counts.fold<int>(0, (sum, item) => sum + item);
    const letters = ['A', 'B', 'C', 'D'];
    const colors = [BilgiColors.secondary, BilgiColors.primary, BilgiColors.warning, BilgiColors.accent];
    const difficultyLabels = ['Kolay', 'Orta', 'Zor', 'Efsane'];
    const difficultyColors = [BilgiColors.secondary, BilgiColors.warning, BilgiColors.error, BilgiColors.info];
    final subs = _categories.where((item) => item.id == _distCat).firstOrNull?.subs ?? const <String>[];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _SearchCombo(
              hint: 'Ana kategori',
              selected: _distCat,
              options: [for (final category in _categories) (category.id, '${category.emoji} ${category.name}')],
              onChanged: (value) {
                setState(() {
                  _distCat = value;
                  _distSub = '';
                });
                _loadDistribution();
              },
            ),
            _SearchCombo(
              hint: _distCat.isEmpty ? 'Önce ana kategori' : 'Alt kategori',
              selected: _distSub,
              enabled: _distCat.isNotEmpty,
              options: [for (final name in subs) (name, name)],
              onChanged: (value) {
                setState(() => _distSub = value);
                _loadDistribution();
              },
            ),
            Text('${_trInt(total)} soru', style: const TextStyle(color: BilgiColors.muted, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 24),
        if (total == 0)
          const Text('Bu seçimde soru yok.', style: TextStyle(color: BilgiColors.muted))
        else ...[
          _distChart(counts: counts, total: total, labels: letters, colors: colors),
          const SizedBox(height: 28),
          const Text('Zorluk dağılımı', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          _distChart(counts: difficultyCounts, total: total, labels: difficultyLabels, colors: difficultyColors),
          if (otherDifficulty > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Diğer zorluk: ${_trInt(otherDifficulty)}', style: const TextStyle(color: BilgiColors.muted)),
            ),
        ],
        const SizedBox(height: 28),
        _publishedMatrix(),
      ],
    );
  }

  Widget _publishedMatrix() {
    final rows = _publishedMatrixRows();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Yayınlı sorular', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text(
          'Onaylı soru sayısı. Her zorlukta en az $bilgiMinPublishedPerDifficulty soru varsa yeşil, biri eksikse kırmızı.',
          style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: _cardDeco(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 860),
                child: Column(
                  children: [
                    _matrixLine(category: 'Kategori', sub: 'Alt kategori', counts: const [], header: true),
                    if (rows.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('Kayıt yok', style: TextStyle(color: BilgiColors.muted)),
                      )
                    else
                      for (final row in rows)
                        _matrixLine(
                          category: row.category,
                          sub: row.sub,
                          counts: [...row.counts, row.counts.fold<int>(0, (sum, item) => sum + item)],
                          ready: bilgiPublishedSubReady(row.categoryId, row.sub, row.counts),
                          selected: row.categoryId == _distCat && row.sub == _distSub && _distSub.isNotEmpty,
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

  List<({String categoryId, String category, String sub, List<int> counts})> _publishedMatrixRows() {
    const diffs = ['kolay', 'orta', 'zor', 'efsane'];
    final categories = _distCat.isEmpty ? _categories : _categories.where((item) => item.id == _distCat).toList();
    final seen = <String>{};
    final rows = <({String categoryId, String category, String sub, List<int> counts})>[];
    List<int> countsOf(String categoryId, String sub) => [
          for (final difficulty in diffs)
            _distMatrix[(categoryId: categoryId, sub: sub, difficulty: difficulty)] ?? 0,
        ];
    for (final category in categories) {
      final label = '${category.emoji} ${category.name}';
      for (final sub in category.subs) {
        seen.add('${category.id}|$sub');
        rows.add((categoryId: category.id, category: label, sub: sub, counts: countsOf(category.id, sub)));
      }
    }
    final extras = <({String categoryId, String sub})>[];
    for (final key in _distMatrix.keys) {
      if (_distCat.isNotEmpty && key.categoryId != _distCat) continue;
      final id = '${key.categoryId}|${key.sub}';
      if (seen.contains(id)) continue;
      seen.add(id);
      extras.add((categoryId: key.categoryId, sub: key.sub));
    }
    extras.sort((a, b) {
      final byCategory = a.categoryId.compareTo(b.categoryId);
      if (byCategory != 0) return byCategory;
      return a.sub.compareTo(b.sub);
    });
    for (final extra in extras) {
      final category = _categories.where((item) => item.id == extra.categoryId).firstOrNull;
      final label = category == null ? extra.categoryId : '${category.emoji} ${category.name}';
      rows.add((
        categoryId: extra.categoryId,
        category: label,
        sub: extra.sub,
        counts: countsOf(extra.categoryId, extra.sub),
      ));
    }
    return rows;
  }

  Widget _matrixLine({
    required String category,
    required String sub,
    required List<int> counts,
    bool header = false,
    bool selected = false,
    bool ready = false,
  }) {
    const headers = ['Kolay', 'Orta', 'Zor', 'Efsane', 'Toplam'];
    const readyColor = Color(0xFF3DDC97);
    final tone = header ? BilgiColors.muted : (ready ? readyColor : BilgiColors.error);
    final labelStyle = TextStyle(
      color: tone,
      fontSize: header ? 11 : 13,
      fontWeight: FontWeight.w800,
      letterSpacing: header ? 0.4 : 0,
    );
    Widget cell(Widget child, double width, {bool end = false}) => SizedBox(
          width: width,
          child: Align(alignment: end ? Alignment.centerRight : Alignment.centerLeft, child: child),
        );
    return Container(
      decoration: BoxDecoration(
        color: header
            ? const Color(0xFF121022)
            : (ready ? const Color(0x143DDC97) : const Color(0x14FF4D6D)),
        border: Border(
          left: selected ? const BorderSide(color: BilgiColors.primary, width: 3) : BorderSide.none,
          bottom: header ? BorderSide.none : const BorderSide(color: Color(0x08FFFFFF)),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          cell(Text(category, style: labelStyle, overflow: TextOverflow.ellipsis), 220),
          cell(Text(sub, style: labelStyle, overflow: TextOverflow.ellipsis), 220),
          for (var i = 0; i < headers.length; i++)
            cell(
              Text(
                header ? headers[i] : _trInt(i < counts.length ? counts[i] : 0),
                style: header
                    ? labelStyle
                    : TextStyle(
                        color: i < 4 && (i < counts.length ? counts[i] : 0) < bilgiMinPublishedPerDifficulty
                            ? BilgiColors.error
                            : tone,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
              ),
              88,
              end: true,
            ),
        ],
      ),
    );
  }

  Widget _distChart({
    required List<int> counts,
    required int total,
    required List<String> labels,
    required List<Color> colors,
  }) {
    final peak = counts.fold<int>(0, (max, count) => count > max ? count : max);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: _cardDeco(),
      child: SizedBox(
        height: 280,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < counts.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${_trInt(counts[i])}  %${total == 0 ? 0 : (counts[i] * 100 / total).round()}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: peak == 0 ? 0 : counts[i] / peak,
                            widthFactor: 0.55,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors[i],
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(labels[i], style: TextStyle(color: colors[i], fontSize: 18, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _summary() {
    final days = _playsByDay();
    final maxDay = days.fold<int>(0, (max, day) => day.count > max ? day.count : max);
    final userChange = _weekChange(_users.map((user) => user.createdAt));
    final gameChange = _weekChange(_games.map((game) => DateTime.tryParse('${game['startedAt']}')));
    final categories = _categoryStats();
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 860;
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            _metricGrid(narrow, [
              _dashMetric('👥', _trInt(_users.length), 'Toplam Kullanıcı', userChange),
              _dashMetric('🎮', _trInt(_games.length), 'Oynanan Oyun', gameChange),
              _dashMetric('❓', _trInt(_bankSummary.total), 'Toplam Soru', _pendingCount == 0 ? null : (text: '$_pendingCount onay bekliyor', up: true)),
              _dashMetric('💰', '—', 'Bu Ay Gelir', null),
            ]),
            const SizedBox(height: 24),
            _dashSplit(
              narrow,
              _dashPanel(
                title: 'Son 7 Gün — Oyun Oynanma',
                action: 'Detay →',
                onAction: () => setState(() => _index = 24),
                child: SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final day in days)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: maxDay == 0 || day.count == 0 ? 0 : day.count / maxDay,
                                      widthFactor: 1,
                                      child: const DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [BilgiColors.primary, BilgiColors.primaryLight]),
                                        ),
                                        child: SizedBox.expand(),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(day.label, style: const TextStyle(color: BilgiColors.muted, fontSize: 10)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _dashPanel(
                title: 'Bekleyen Onaylar',
                action: 'Tümü →',
                onAction: () {
                  setState(() => _index = 5);
                  _loadPending();
                },
                child: Column(
                  children: [
                    _dashList('❓', '$_pendingCount yeni soru', 'Onay bekliyor', _pendingCount == 0 ? null : 'Bekliyor', BilgiColors.warning),
                    _dashList('🚫', '$_bannedCount ban', 'Askıdaki hesap', _bannedCount == 0 ? null : 'Acil', BilgiColors.error, last: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _dashSplit(
              narrow,
              _dashPanel(
                title: 'En Çok Oynanan Kategoriler',
                action: 'Tümü →',
                onAction: () => setState(() => _index = 8),
                child: categories.isEmpty
                    ? const Text('Oyun kaydı yok.', style: TextStyle(color: BilgiColors.muted, fontSize: 13))
                    : Column(
                        children: [
                          _dashTableHead(const ['Kategori', 'Soru', 'Oyun', 'Ort. Doğru']),
                          for (final row in categories) _dashCategoryRow(row),
                        ],
                      ),
              ),
              _dashPanel(
                title: 'Hızlı İşlemler',
                child: _quickGrid([
                  _dashQuick('➕', 'Soru Ekle', _openEditor),
                  _dashQuick('📥', 'Toplu İçe Aktar', () => setState(() => _index = 7)),
                  _dashQuick('✅', 'Onay Bekleyenler', () {
                    setState(() => _index = 5);
                    _loadPending();
                  }),
                  _dashQuick('📢', 'Duyuru Gönder', () {}),
                  _dashQuick('🏆', 'Etkinlik Oluştur', () => setState(() => _index = 23)),
                  _dashQuick('📊', 'Rapor İndir', () => setState(() => _index = 24)),
                ]),
              ),
            ),
          ],
        );
      },
    );
  }

  List<({String label, int count})> _playsByDay() {
    const names = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final counts = List<int>.filled(7, 0);
    for (final game in _games) {
      final at = DateTime.tryParse('${game['startedAt']}');
      if (at == null) continue;
      final day = DateTime(at.year, at.month, at.day).difference(start).inDays;
      if (day >= 0 && day < 7) counts[day] += 1;
    }
    return [
      for (var i = 0; i < 7; i++) (label: names[start.add(Duration(days: i)).weekday - 1], count: counts[i]),
    ];
  }

  ({String text, bool up})? _weekChange(Iterable<DateTime?> times) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 6));
    final priorStart = start.subtract(const Duration(days: 7));
    var recent = 0;
    var prior = 0;
    for (final at in times) {
      if (at == null) continue;
      final day = DateTime(at.year, at.month, at.day);
      if (!day.isBefore(start)) {
        recent += 1;
      } else if (!day.isBefore(priorStart)) {
        prior += 1;
      }
    }
    if (recent == 0 && prior == 0) return null;
    if (prior == 0) return (text: '↑ $recent bu hafta', up: true);
    final pct = ((recent - prior) / prior * 100).round();
    if (pct == 0) return (text: '→ %0 bu hafta', up: true);
    return (text: '${pct > 0 ? '↑' : '↓'} %${pct.abs()} bu hafta', up: pct > 0);
  }

  List<({String label, int questions, int plays, int correct, int asked})> _categoryStats() {
    final plays = <String, int>{};
    final correct = <String, int>{};
    final asked = <String, int>{};
    for (final game in _games) {
      final id = '${game['categoryId']}';
      if (id.isEmpty) continue;
      plays[id] = (plays[id] ?? 0) + 1;
      correct[id] = (correct[id] ?? 0) + (game['correct'] as int? ?? 0);
      final questions = game['questions'];
      if (questions is List) asked[id] = (asked[id] ?? 0) + questions.length;
    }
    final rows = [
      for (final id in plays.keys)
        (
          label: id == 'tumu' ? '🎲 Tümü' : _catLabel(id),
          questions: _bankSummary.categoryApproved(id),
          plays: plays[id] ?? 0,
          correct: correct[id] ?? 0,
          asked: asked[id] ?? 0,
        ),
    ]..sort((a, b) => b.plays.compareTo(a.plays));
    return rows.take(5).toList();
  }

  Widget _questionList(String? status) {
    if (status == 'pending') return _pendingCards();
    if (status == 'rejected') return _rejectedTable();
    return _bankTable();
  }

  Future<void> _applyBulkCategory() async {
    if (_bulkBusy) return;
    if (_selectedIds.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    if (_moveCat.isEmpty || _moveSub.isEmpty) {
      setState(() => _note = 'Üst kategori ve alt kategori seç.');
      return;
    }
    final category = _categories.where((item) => item.id == _moveCat).firstOrNull;
    if (category == null || !category.subs.contains(_moveSub)) {
      setState(() => _note = 'Alt kategori bu üst kategoriye ait değil.');
      return;
    }
    final chosen = _chosenSelected();
    setState(() => _bulkBusy = true);
    final moved = [
      for (final question in chosen)
        BilgiQuestion(
          id: question.id,
          categoryId: _moveCat,
          text: question.text,
          options: question.options,
          correct: question.correct,
          difficulty: question.difficulty,
          explanation: question.explanation,
          hint: question.hint,
          status: question.status,
          tags: [
            _moveSub,
            ...question.tags.where((tag) {
              final previous = _categories.where((item) => item.id == question.categoryId).firstOrNull;
              return tag != _moveSub && !(previous?.subs.contains(tag) ?? false);
            }),
          ],
          rejectReason: question.rejectReason,
          reviewed: question.reviewed,
        ),
    ];
    var saved = 0;
    var failed = 0;
    try {
      await _saveRemote(moved);
      saved = moved.length;
    } catch (_) {
      failed = moved.length;
    }
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _note = '$saved sorunun kategorisi değişti. $failed kaydedilemedi.';
    });
    await _load();
  }

  Future<void> _deleteSelected() async {
    if (_bulkBusy || _selectedIds.isEmpty) {
      if (_selectedIds.isEmpty) setState(() => _note = 'Önce soru seç.');
      return;
    }
    final ids = _selectedIds.toList();
    setState(() => _bulkBusy = true);
    for (final id in ids) {
      await _deleteRemote(id);
    }
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _selectedIds.removeAll(ids);
      _note = '${ids.length} soru silindi.';
    });
    await _load();
  }

  List<String>? _publishLocales(String categoryId) =>
      _categories.where((item) => item.id == categoryId).firstOrNull?.locales;

  bool _questionReady(BilgiQuestion question) =>
      bilgiQuestionLanguagesReady(question, locales: _publishLocales(question.categoryId));

  Future<void> _applyBulkStatus(String status) async {
    if (_bulkBusy) return;
    if (_selectedIds.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    const labels = {
      'approved': 'Onaylı',
      'pending': 'Bekleyen',
      'draft': 'Taslak',
      'rejected': 'Reddedilen',
    };
    if (!labels.containsKey(status)) return;
    final chosen = _chosenSelected();
    final changed = <BilgiQuestion>[];
    var blocked = 0;
    for (final question in chosen) {
      if (status == 'approved' && !_rowReady(question)) {
        blocked++;
        continue;
      }
      if (question.status == status) continue;
      changed.add(bilgiQuestionWithReviewStatus(question, status));
    }
    if (changed.isEmpty) {
      setState(() {
        _bulkMenu = '';
        _note = blocked == 0
            ? 'Seçili sorular zaten bu durumda.'
            : '$blocked soru tercümesi tamam olmadığı için onaylanmadı.';
      });
      return;
    }
    setState(() => _bulkBusy = true);
    try {
      await _saveRemote(changed);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _bulkBusy = false;
        _note = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bulkBusy = false;
        _note = 'Durum kaydedilemedi.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _bulkMenu = '';
      _note = blocked == 0
          ? '${changed.length} sorunun durumu ${labels[status]} oldu.'
          : '${changed.length} sorunun durumu ${labels[status]} oldu. $blocked soru tercümesi tamam olmadığı için onaylanmadı.';
    });
    await _load();
  }

  Future<void> _applyBulkDifficulty(String difficulty) async {
    if (_bulkBusy) return;
    if (_selectedIds.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    const labels = {
      'kolay': 'Kolay',
      'orta': 'Orta',
      'zor': 'Zor',
      'efsane': 'Efsane',
    };
    if (!labels.containsKey(difficulty)) return;
    final chosen = _chosenSelected();
    final changed = <BilgiQuestion>[
      for (final question in chosen)
        if (question.difficulty != difficulty) question.copyWith(difficulty: difficulty),
    ];
    if (changed.isEmpty) {
      setState(() => _note = 'Seçili sorular zaten bu zorlukta.');
      return;
    }
    setState(() => _bulkBusy = true);
    try {
      await _saveRemote(changed);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _bulkBusy = false;
        _note = error.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bulkBusy = false;
        _note = 'Zorluk kaydedilemedi.';
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _bulkBusy = false;
      _note = '${changed.length} sorunun zorluğu ${labels[difficulty]} oldu.';
    });
    await _load();
  }

  Future<void> _translateSelected() async {
    if (_bulkBusy) return;
    if (_selectedIds.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    final chosen = _chosenSelected();
    if (chosen.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    final queue = List<BilgiQuestion>.from(chosen);
    final total = queue.length;
    var cursor = 0;
    var active = 0;
    var translated = 0;
    var skipped = 0;
    var failed = 0;
    DateTime? lastStart;
    var scheduling = false;
    final idle = Completer<void>();

    void mark(String text) {
      if (!mounted) return;
      setState(() => _note = text);
    }

    void settle() {
      if (active == 0 && (cursor >= total || !mounted)) {
        if (!idle.isCompleted) idle.complete();
        return;
      }
      if (mounted && active > 0) {
        mark('Çevriliyor... ${translated + skipped + failed}/$total · $active açık');
      }
    }

    void schedule() {
      if (scheduling) return;
      scheduling = true;
      unawaited(() async {
        try {
          while (mounted && cursor < total && active < _translateLanes) {
            if (lastStart != null) {
              final wait = _translateGap - DateTime.now().difference(lastStart!);
              if (wait > Duration.zero) {
                await Future<void>.delayed(wait);
                continue;
              }
            }
            if (!mounted || cursor >= total || active >= _translateLanes) break;
            final seed = queue[cursor];
            cursor++;
            active++;
            lastStart = DateTime.now();
            mark('Çevriliyor... ${translated + skipped + failed}/$total · $active açık');
            unawaited(() async {
              final outcome = await _translateBulkItem(seed);
              if (outcome == 'translated') {
                translated++;
              } else if (outcome == 'skipped') {
                skipped++;
              } else if (outcome == 'failed') {
                failed++;
              }
              active--;
              settle();
              schedule();
            }());
          }
        } finally {
          scheduling = false;
          if (mounted && cursor < total && active < _translateLanes) {
            schedule();
          } else {
            settle();
          }
        }
      }());
    }

    setState(() {
      _bulkBusy = true;
      _note = 'Çevriliyor... 0/$total · 0 açık';
    });
    try {
      schedule();
      await idle.future;
    } finally {
      if (mounted) {
        setState(() {
          _bulkBusy = false;
          _translatingIds.clear();
          _note = '$translated soru çevrildi. $skipped atlandı. $failed başarısız.';
        });
      }
    }
  }

  Future<String> _translateBulkItem(BilgiQuestion seed) async {
    final loaded = await BilgiQuestionApi.loadOne(sl<ApiSession>().adminToken ?? '', seed.id);
    if (!mounted) return 'stopped';
    final question = loaded ?? seed;
    if (!bilgiLanguageFieldsReady(question.text, question.options, question.explanation)) {
      return 'skipped';
    }
    final targets = bilgiExtraLocales(_publishLocales(question.categoryId));
    if (targets.isEmpty) return 'skipped';
    setState(() => _translatingIds.add(question.id));
    try {
      final result = await BilgiQuestionApi.translateQuestion(
        sl<ApiSession>().adminToken ?? '',
        text: question.text,
        options: question.options,
        explanation: question.explanation,
        hint: question.hint,
        locales: targets,
      );
      if (!mounted) return 'stopped';
      if (result.error != null) return 'failed';
      final written = question.copyWith(translations: {...question.translations, ...result.translations});
      await _saveRemote([written]);
      if (!mounted) return 'stopped';
      _rememberSaved([written]);
      return 'translated';
    } on StateError {
      return 'failed';
    } catch (_) {
      return 'failed';
    } finally {
      if (mounted) setState(() => _translatingIds.remove(question.id));
    }
  }

  void _clearBankSelection() {
    if (_bulkBusy) return;
    _bankTimer?.cancel();
    _bankSearchQuiet = true;
    setState(() {
      _bankSearch.clear();
      _selectedIds.clear();
      _bankCat = '';
      _bankSub = '';
      _bankDiff = '';
      _bankStatus = '';
      _bankLang = '';
      _bankReviewed = '';
      _bankDetail = '';
      _bankPage = 0;
      _bulkMenu = '';
      _moveCat = '';
      _moveSub = '';
      _selectedQuestions.clear();
    });
    _bankSearchQuiet = false;
    _loadBankPage();
  }

  void _onBulkMenu(String value) {
    if (_bulkBusy) return;
    if (value == 'status' || value == 'difficulty') {
      if (_selectedIds.isEmpty) {
        setState(() {
          _bulkMenu = '';
          _note = 'Önce soru seç.';
        });
        return;
      }
      setState(() => _bulkMenu = value);
      return;
    }
    setState(() => _bulkMenu = '');
    switch (value) {
      case 'category':
        _applyBulkCategory();
      case 'translate':
        _translateSelected();
      case 'review':
        _reviewSelected();
      case 'delete':
        _deleteSelected();
    }
  }

  Future<void> _reviewSelected() async {
    if (_bulkBusy) return;
    if (_selectedIds.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    final chosen = _chosenSelected();
    if (chosen.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    setState(() => _bulkBusy = true);
    var kept = 0;
    var rejected = 0;
    var failed = 0;
    try {
      for (var i = 0; i < chosen.length; i++) {
        if (!mounted) return;
        final question = chosen[i];
        setState(() {
          _reviewingId = question.id;
          _note = 'Kontrol ediliyor... (${i + 1}/${chosen.length})';
        });
        final result = await BilgiQuestionApi.reviewQuestion(sl<ApiSession>().adminToken ?? '', question.id);
        if (!mounted) return;
        if (result.error != null) {
          failed++;
          setState(() => _note = result.error!);
          continue;
        }
        final written = question.copyWith(
          difficulty: result.difficulty,
          status: result.status,
          rejectReason: result.rejectReason,
          reviewed: true,
        );
        try {
          await _server.saveQuestion(written);
        } catch (_) {}
        if (!mounted) return;
        _rememberSaved([written]);
        if (result.verdict == 'reject') {
          rejected++;
        } else {
          kept++;
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _bulkBusy = false;
          _reviewingId = null;
          _note = '$kept soru kontrol edildi. $rejected reddedildi. $failed başarısız.';
        });
      }
    }
  }

  Widget _bankTable() {
    final query = _bankSearch.text.trim();
    final filtering = query.length >= 3;
    final rows = _bankRows;
    final slice = _bankRows;
    final pages = _bankTotal == 0 ? 1 : (_bankTotal / _bankPageSize).ceil();
    final page = _bankPage.clamp(0, pages - 1);
    final from = _bankTotal == 0 ? 0 : page * _bankPageSize + 1;
    final to = _bankTotal == 0 ? 0 : from + slice.length - 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Ara', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _bankSearch,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) {
                  if (_bankSearchQuiet) return;
                  setState(() {
                    _bankPage = 0;
                    _selectedIds.clear();
                    _selectedQuestions.clear();
                  });
                  _scheduleBank();
                },
                decoration: InputDecoration(
                  hintText: 'En az 3 harf yaz',
                  hintStyle: const TextStyle(color: BilgiColors.muted),
                  helperText: query.isEmpty || filtering ? null : 'Arama 3 harfte başlar',
                  helperStyle: const TextStyle(color: BilgiColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _SearchCombo(
                    hint: 'Ana kategori',
                    selected: _bankCat,
                    options: [for (final c in _categories) (c.id, '${c.emoji} ${c.name}')],
                    onChanged: (v) {
                      _bankCat = v;
                      _bankSub = '';
                      _retuneBank();
                    },
                  ),
                  _SearchCombo(
                    hint: _bankCat.isEmpty ? 'Önce ana kategori' : 'Alt kategori',
                    selected: _bankSub,
                    enabled: _bankCat.isNotEmpty,
                    options: [
                      for (final name in _categories.where((item) => item.id == _bankCat).firstOrNull?.subs ?? const <String>[]) (name, name),
                    ],
                    onChanged: (v) {
                      _bankSub = v;
                      _retuneBank();
                    },
                  ),
                  _select(_bankDiff, [('','Tüm Zorluklar'), ('kolay','Kolay'), ('orta','Orta'), ('zor','Zor'), ('efsane','Efsane')], (v) { _bankDiff = v; _retuneBank(); }),
                  _select(_bankStatus, [('','Tüm Durumlar'), ('approved','Onaylı'), ('pending','Bekleyen'), ('draft','Taslak'), ('rejected','Reddedilen')], (v) { _bankStatus = v; _retuneBank(); }),
                  _select(_bankLang, [('','Tüm Tercümeler'), ('ready','Tercüme tamam'), ('missing','Tercüme eksik')], (v) { _bankLang = v; _retuneBank(); }),
                  _select(_bankDetail, [('','Tüm detay'), ('filled','Detay dolu'), ('empty','Boş')], (v) { _bankDetail = v; _retuneBank(); }),
                  _select(_bankReviewed, [('','Tüm Kontroller'), ('yes','Kontrol edildi'), ('no','Kontrol edilmedi')], (v) { _bankReviewed = v; _retuneBank(); }),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _ghost('Tümünü seç', () {
                if (_bankTotal == 0 || _bulkBusy) return;
                _selectAllFiltered();
              }),
              _ghost('Sayfadakileri seç', () {
                if (slice.isEmpty || _bulkBusy) return;
                setState(() {
                  _selectedIds.clear();
                  _selectedQuestions.clear();
                  for (final question in slice) {
                    _selectedIds.add(question.id);
                    _selectedQuestions[question.id] = question;
                  }
                });
              }),
              _ghost('Seçimi temizle', _clearBankSelection),
              Text('${_selectedIds.length} seçili', style: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: _cardDeco(),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _SearchCombo(
                hint: 'Üst kategori',
                selected: _moveCat,
                options: [for (final c in _categories) (c.id, '${c.emoji} ${c.name}')],
                onChanged: (v) => setState(() { _moveCat = v; _moveSub = ''; }),
              ),
              _SearchCombo(
                hint: _moveCat.isEmpty ? 'Önce üst kategori' : 'Alt kategori',
                selected: _moveSub,
                enabled: _moveCat.isNotEmpty,
                options: [
                  for (final name in _categories.where((item) => item.id == _moveCat).firstOrNull?.subs ?? const <String>[]) (name, name),
                ],
                onChanged: (v) => setState(() => _moveSub = v),
              ),
              _primary('Toplu işlem', () {
                if (_bulkBusy) return;
                setState(() => _bulkMenu = _bulkMenu.isEmpty ? 'root' : '');
              }),
              if (_bulkMenu == 'root') ...[
                _ghost('Kategori değiştir', () => _onBulkMenu('category')),
                _ghost('Çevir', () => _onBulkMenu('translate')),
                _ghost('Kontrol', () => _onBulkMenu('review')),
                _ghost('Durum güncelle', () => _onBulkMenu('status')),
                _ghost('Zorluk değiştir', () => _onBulkMenu('difficulty')),
                _solid('Seçimi sil', BilgiColors.error, Colors.white, () => _onBulkMenu('delete')),
              ],
              if (_bulkMenu == 'status') ...[
                _ghost('Onaylı', () { setState(() => _bulkMenu = ''); _applyBulkStatus('approved'); }),
                _ghost('Bekleyen', () { setState(() => _bulkMenu = ''); _applyBulkStatus('pending'); }),
                _ghost('Taslak', () { setState(() => _bulkMenu = ''); _applyBulkStatus('draft'); }),
                _ghost('Reddedilen', () { setState(() => _bulkMenu = ''); _applyBulkStatus('rejected'); }),
              ],
              if (_bulkMenu == 'difficulty') ...[
                _ghost('Kolay', () { setState(() => _bulkMenu = ''); _applyBulkDifficulty('kolay'); }),
                _ghost('Orta', () { setState(() => _bulkMenu = ''); _applyBulkDifficulty('orta'); }),
                _ghost('Zor', () { setState(() => _bulkMenu = ''); _applyBulkDifficulty('zor'); }),
                _ghost('Efsane', () { setState(() => _bulkMenu = ''); _applyBulkDifficulty('efsane'); }),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(_bankLoading ? 'Yükleniyor...' : '$_bankTotal soru', style: const TextStyle(color: BilgiColors.muted, fontSize: 13, fontWeight: FontWeight.w700)),
              const Spacer(),
              const Text('Sayfa başına', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              _select(
                '$_bankPageSize',
                [for (final size in bilgiBankPageSizes) ('$size', '$size')],
                (value) {
                  _bankPageSize = int.parse(value);
                  _bankPage = 0;
                  _loadBankPage();
                },
              ),
            ],
          ),
        ),
        Container(
          decoration: _cardDeco(),
          child: Column(
            children: [
              _bankCells([
                const Text('KONTROL', style: TextStyle(color: BilgiColors.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                Checkbox(
                  tristate: true,
                  value: rows.isEmpty
                      ? false
                      : (rows.every((question) => _selectedIds.contains(question.id))
                          ? true
                          : (rows.any((question) => _selectedIds.contains(question.id)) ? null : false)),
                  onChanged: rows.isEmpty || _bulkBusy
                      ? null
                      : (_) {
                          final all = rows.every((question) => _selectedIds.contains(question.id));
                          setState(() {
                            if (all) {
                              for (final question in rows) {
                                _selectedIds.remove(question.id);
                                _selectedQuestions.remove(question.id);
                              }
                            } else {
                              for (final question in rows) {
                                _selectedIds.add(question.id);
                                _selectedQuestions[question.id] = question;
                              }
                            }
                          });
                        },
                  activeColor: BilgiColors.secondary,
                  side: const BorderSide(color: Colors.white54),
                ),
                for (final label in const ['ID', 'SORU', 'KATEGORİ', 'ALT KATEGORİ', 'DOĞRU\nŞIK', 'ZORLUK', 'DURUM', 'İŞLEM'])
                  Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
              ], header: true),
              if (slice.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Text('Kayıt yok', style: TextStyle(color: BilgiColors.muted)))
              else
                for (final question in slice) _bankRow(question),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('$_bankTotal soru', style: const TextStyle(color: BilgiColors.muted, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 12),
                    Text('$from-$to', style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                    const Spacer(),
                    _pageBtn('‹', page > 0 ? () { _bankPage = page - 1; _loadBankPage(); } : null, false),
                    _pageBtn('${page + 1}', null, true),
                    _pageBtn('›', page + 1 < pages ? () { _bankPage = page + 1; _loadBankPage(); } : null, false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// KONTROL, seçim, ID, SORU, KATEGORİ, ALT KATEGORİ, DOĞRU ŞIK, ZORLUK, DURUM, İŞLEM.
  /// SORU, daraltılan DOĞRU ŞIK genişliğini alır.
  static const _bankFlex = [1, 1, 2, 5, 2, 2, 1, 2, 2, 5];

  Widget _bankCells(List<Widget> cells, {bool header = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: header
          ? const BoxDecoration(color: Color(0xFF121022), borderRadius: BorderRadius.vertical(top: Radius.circular(16)))
          : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(
              flex: _bankFlex[i],
              child: Align(alignment: Alignment.centerLeft, child: cells[i]),
            ),
        ],
      ),
    );
  }

  bool _eventQuestion(BilgiQuestion question) {
    final category = _categories.where((item) => item.id == question.categoryId).firstOrNull;
    return category != null && bilgiSpecialEventCategory(category);
  }

  Widget _questionLine(BilgiQuestion question, {bool wrap = false}) {
    final reason = question.rejectReason.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_eventQuestion(question)) ...[
          _specialEventTag(compact: true),
          const SizedBox(height: 4),
        ],
        Text(
          question.text,
          softWrap: true,
          maxLines: wrap ? null : 1,
          overflow: wrap ? TextOverflow.visible : TextOverflow.ellipsis,
          style: wrap
              ? const TextStyle(color: Colors.white, fontSize: 13, height: 1.35)
              : const TextStyle(color: Colors.white, fontSize: 13),
        ),
        if (reason.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(reason, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BilgiColors.error, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  Widget _reviewedMark(bool reviewed) {
    return Tooltip(
      message: reviewed ? 'Kontrol edildi' : 'Kontrol edilmedi',
      child: Icon(
        reviewed ? Icons.check : Icons.close,
        size: 18,
        color: reviewed ? const Color(0xFF22C55E) : BilgiColors.error,
      ),
    );
  }

  Widget _bankRow(BilgiQuestion question) {
    final pending = question.status == 'pending';
    return _bankCells([
      _reviewedMark(question.reviewed),
      Checkbox(
        value: _selectedIds.contains(question.id),
        onChanged: _bulkBusy
            ? null
            : (checked) => setState(() {
                  if (checked ?? false) {
                    _selectedIds.add(question.id);
                    _selectedQuestions[question.id] = question;
                  } else {
                    _selectedIds.remove(question.id);
                    _selectedQuestions.remove(question.id);
                  }
                }),
        activeColor: BilgiColors.secondary,
        side: const BorderSide(color: Colors.white54),
      ),
      Text(question.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_rowReady(question)) ...[
            _langOk(),
            const SizedBox(width: 6),
          ],
          Expanded(child: _questionLine(question, wrap: true)),
        ],
      ),
      Text(_catLabel(question.categoryId), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      Text(_subLabel(question), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      Text(bilgiCorrectChoiceLetter(question), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      _diffBadge(question.difficulty),
      _statusBadge(question.status),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pending)
            _rowActionBtn(
              icon: Icons.check_box,
              color: const Color(0xFF3DDC84),
              tooltip: 'Onayla',
              onTap: () => _setStatus(question, 'approved'),
            ),
          if (pending)
            _rowActionBtn(
              icon: Icons.close,
              color: BilgiColors.error,
              tooltip: 'Reddet',
              onTap: () => _setStatus(question, 'rejected'),
            ),
          _rowActionBtn(
            icon: Icons.edit,
            color: BilgiColors.warning,
            tooltip: 'Düzenle',
            onTap: () => _openEditor(question),
          ),
          _rowTranslateBtn(question),
          _rowReviewBtn(question),
          if (!pending)
            _rowActionBtn(
              icon: Icons.delete_outline,
              color: BilgiColors.error,
              tooltip: 'Sil',
              onTap: () async {
                await _deleteRemote(question.id);
                await _load();
              },
            ),
        ],
      ),
    ]);
  }

  Widget _rowReviewBtn(BilgiQuestion question) {
    final busy = _reviewingId == question.id;
    return Tooltip(
      message: 'Bu soruyu kontrol et',
      child: InkWell(
        onTap: busy ? null : () => _reviewQuestion(question.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: BilgiColors.secondary),
                )
              : const Text(
                  'Kontrol',
                  style: TextStyle(color: BilgiColors.secondary, fontSize: 11, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }

  Future<({String? error, String difficulty, String status, String rejectReason, String verdict})?> _reviewQuestion(String id) async {
    if (_reviewingId != null) return null;
    final current = _questionById(id);
    if (current == null) {
      setState(() => _note = 'Soru bulunamadı.');
      return null;
    }
    setState(() {
      _reviewingId = id;
      _note = 'Kontrol ediliyor...';
    });
    final result = await BilgiQuestionApi.reviewQuestion(sl<ApiSession>().adminToken ?? '', id);
    if (!mounted) return null;
    if (result.error != null) {
      setState(() {
        _reviewingId = null;
        _note = result.error!;
      });
      return result;
    }
    final written = current.copyWith(
      difficulty: result.difficulty,
      status: result.status,
      rejectReason: result.rejectReason,
      reviewed: true,
    );
    try {
      await _server.saveQuestion(written);
    } catch (_) {}
    if (!mounted) return result;
    _rememberSaved([written]);
    setState(() {
      _reviewingId = null;
      if (_editing?.id == id) _editing = written;
      _note = result.verdict == 'reject'
          ? 'Reddedildi: ${result.rejectReason}'
          : 'Kontrol edildi. Zorluk: ${_diffName(result.difficulty)}';
    });
    return result;
  }

  Widget _rowTranslateBtn(BilgiQuestion question) {
    final busy = _translatingIds.contains(question.id);
    final blocked = _bulkBusy || busy;
    return Tooltip(
      message: 'Seçili dilleri çevir',
      child: InkWell(
        onTap: blocked ? null : () => _translateRow(question),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: BilgiColors.primary),
                )
              : Text(
                  'Çevir',
                  style: TextStyle(
                    color: blocked ? BilgiColors.muted : BilgiColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _translateRow(BilgiQuestion question) async {
    if (_bulkBusy || _translatingIds.contains(question.id)) return;
    final loaded = await BilgiQuestionApi.loadOne(sl<ApiSession>().adminToken ?? '', question.id);
    if (!mounted) return;
    if (loaded != null) question = loaded;
    if (_bulkBusy || _translatingIds.contains(question.id)) return;
    if (!bilgiLanguageFieldsReady(question.text, question.options, question.explanation)) {
      setState(() => _note = 'Türkçe soru, dört şık ve açıklama dolu olmalı.');
      return;
    }
    setState(() {
      _translatingIds.add(question.id);
      _note = 'Çevriliyor...';
    });
    final targets = bilgiExtraLocales(_publishLocales(question.categoryId));
    if (targets.isEmpty) {
      setState(() {
        _translatingIds.remove(question.id);
        _note = 'Bu kategoride başka yayın dili yok.';
      });
      return;
    }
    try {
      final result = await BilgiQuestionApi.translateQuestion(
        sl<ApiSession>().adminToken ?? '',
        text: question.text,
        options: question.options,
        explanation: question.explanation,
        hint: question.hint,
        locales: targets,
      );
      if (!mounted) return;
      if (result.error != null) {
        setState(() => _note = result.error!);
        return;
      }
      final written = question.copyWith(translations: {...question.translations, ...result.translations});
      setState(() => _note = 'Tercüme kaydediliyor...');
      await _saveRemote([written]);
      if (!mounted) return;
      _rememberSaved([written]);
      setState(() => _note = 'Soru çevrildi ve kaydedildi.');
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _note = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _note = 'Soru kaydedilemedi.');
    } finally {
      if (mounted) setState(() => _translatingIds.remove(question.id));
    }
  }

  Widget _pendingCards() {
    final rows = _pendingRows;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (rows.isEmpty) const Text('Onay bekleyen soru yok.', style: TextStyle(color: BilgiColors.muted)),
        for (final question in rows)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(20),
            decoration: _cardDeco(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (_eventQuestion(question)) ...[
                    _specialEventTag(compact: true),
                    const SizedBox(width: 8),
                  ],
                  Text(question.id, style: const TextStyle(color: BilgiColors.muted, fontWeight: FontWeight.w700)),
                  if (_rowReady(question)) ...[
                    const SizedBox(width: 8),
                    _langOk(),
                  ],
                  const Spacer(),
                  _statusBadge('pending'),
                ]),
                const SizedBox(height: 12),
                Text(question.text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < question.options.length && i < 4; i++)
                      Container(
                        width: 280,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: i == question.correct ? const Color(0x2600D9C0) : BilgiColors.bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: i == question.correct ? BilgiColors.secondary : Colors.transparent),
                        ),
                        child: Text('${['A','B','C','D'][i]}  ${question.options[i]}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('${_catLabel(question.categoryId)}  •  ${_diffName(question.difficulty)}', style: const TextStyle(color: BilgiColors.muted, fontSize: 11)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _ghost('✏️ Düzenle', () => _openEditor(question)),
                    const SizedBox(width: 8),
                    _solid('Reddet', BilgiColors.error, Colors.white, () => _setStatus(question, 'rejected')),
                    const SizedBox(width: 8),
                    _solid('Onayla', BilgiColors.secondary, BilgiColors.bg, () => _setStatus(question, 'approved')),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _rejectedTable() {
    final rows = _rejectedRows;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          decoration: _cardDeco(),
          child: Column(
            children: [
              _tableHead(const ['ID', 'Soru', 'Kategori', 'Red Nedeni', 'İşlem']),
              if (rows.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Text('Reddedilen soru yok.', style: TextStyle(color: BilgiColors.muted)))
              else
                for (final question in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
                    child: Row(
                      children: [
                        SizedBox(width: 90, child: Text(question.id, style: const TextStyle(color: BilgiColors.muted, fontSize: 12), overflow: TextOverflow.ellipsis)),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              if (_rowReady(question)) ...[
                                _langOk(),
                                const SizedBox(width: 6),
                              ],
                              Expanded(child: _questionLine(question)),
                            ],
                          ),
                        ),
                        Expanded(flex: 2, child: Text(_catLabel(question.categoryId), maxLines: 1, overflow: TextOverflow.ellipsis)),
                        SizedBox(width: 120, child: _badge(question.rejectReason.isEmpty ? 'Reddedildi' : question.rejectReason, BilgiColors.error)),
                        _rowActionBtn(
                          icon: Icons.edit,
                          color: BilgiColors.warning,
                          tooltip: 'Düzenle',
                          onTap: () => _openEditor(question),
                        ),
                        _rowActionBtn(
                          icon: Icons.check_box,
                          color: const Color(0xFF3DDC84),
                          tooltip: 'Onayla',
                          onTap: () => _setStatus(question, 'approved'),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _setStatus(BilgiQuestion question, String status) async {
    final latest = _questionById(question.id) ?? question;
    if (status == 'approved' && !_rowReady(latest)) {
      setState(() => _note = bilgiApproveBlocked);
      return;
    }
    final updated = bilgiQuestionWithReviewStatus(latest, status);
    try {
      await _saveRemote([updated]);
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() => _note = error.message);
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() => _note = 'Durum kaydedilemedi.');
      return;
    }
    if (!mounted) return;
    _rememberSaved([updated]);
    setState(() {
      _note = status == 'approved'
          ? 'Soru onaylandı.'
          : status == 'rejected'
              ? 'Soru reddedildi.'
              : 'Durum güncellendi.';
    });
    await _refreshQuestionViews();
  }

  Future<void> _openEditor([BilgiQuestion? question]) async {
    var current = question;
    if (current != null) {
      final full = await BilgiQuestionApi.loadOne(sl<ApiSession>().adminToken ?? '', current.id);
      if (full != null) current = full;
    }
    if (!mounted) return;
    setState(() {
      _editing = current;
      _formSerial += 1;
      _index = 4;
    });
  }

  Widget _editor() {
    final known = <String>{
      for (final tag in _bankSummary.tagCounts.keys)
        if (tag.isNotEmpty && bilgiCategoryById(tag) == null) tag,
      ..._config.adminTags.where((tag) => tag.isNotEmpty),
    }.toList()
      ..sort();
    final existing = _editing;
    final category = existing == null
        ? null
        : _categories.where((item) => item.id == existing.categoryId).firstOrNull ?? bilgiCategoryById(existing.categoryId);
    final initial = existing == null
        ? null
        : BilgiQuestionFormData.fromQuestion(existing, categorySubs: category?.subs ?? const []);
    return _QuestionForm(
      key: ValueKey('$_formSerial-${existing?.id ?? 'new'}'),
      categories: _categories,
      knownTags: known,
      initial: initial,
      rejectReason: existing?.rejectReason ?? '',
      onReview: existing == null ? null : () => _reviewQuestion(existing.id),
      onCancel: () => setState(() {
        _editing = null;
        _index = 1;
      }),
      onSave: (draft) async {
        final id = existing?.id ?? 'q${DateTime.now().microsecondsSinceEpoch}';
        final written = BilgiQuestion(
          id: id,
          categoryId: draft.categoryId,
          text: draft.text,
          options: draft.options,
          correct: draft.correct,
          difficulty: draft.difficulty,
          explanation: draft.explanation,
          hint: draft.hint,
          status: draft.asDraft ? 'draft' : (existing == null ? 'pending' : draft.status),
          tags: draft.tags,
          rejectReason: existing?.rejectReason ?? '',
          translations: draft.translations,
          reviewed: draft.reviewed,
        );
        if (written.status == 'approved' && !_questionReady(written)) {
          setState(() => _note = bilgiApproveBlocked);
          throw StateError(bilgiApproveBlocked);
        }
        try {
          await _saveRemote([written]);
          if (!mounted) return;
          _rememberSaved([written]);
        } on StateError catch (error) {
          setState(() => _note = error.message);
          rethrow;
        } catch (_) {
          setState(() => _note = 'Soru kaydedilemedi.');
          rethrow;
        }
        setState(() {
          _formSerial += 1;
          _editing = null;
          _note = existing == null
              ? (draft.asDraft ? 'Taslak kaydedildi.' : 'Soru beklemeye alındı.')
              : (draft.asDraft ? 'Taslak güncellendi.' : 'Soru güncellendi.');
          if (existing != null) _index = 1;
        });
      },
    );
  }

  Widget _import() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomPaint(
                  painter: const _DashedPainter(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                    child: Column(
                      children: [
                        const Text('📥', style: TextStyle(fontSize: 42)),
                        const SizedBox(height: 16),
                        const Text('Dosyayı Seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        const Text('Yalnızca CSV (maks. 10MB)', style: TextStyle(color: BilgiColors.muted, fontSize: 13)),
                        if (_csvName.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(_csvName, style: const TextStyle(color: BilgiColors.secondary, fontSize: 12, fontWeight: FontWeight.w700)),
                        ],
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            _primary('Dosya Seç', _pickCsv),
                            _ghost('Şablonu İndir', () => downloadTextFile('soru_sablonu.csv', bilgiCsvTemplate)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _panelCard('CSV METNİ', [
                  const Text('Dosya yerine satırları buraya yapıştırabilirsin.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _csvText,
                    minLines: 8,
                    maxLines: 14,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    decoration: _fieldDeco(bilgiCsvColumns.join(',')),
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: _primary('Kaydet', _saveCsvText)),
                ]),
                const SizedBox(height: 16),
                _panelCard('FORMAT BİLGİSİ', [
                  const Text('Sütunlar', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in bilgiCsvColumns)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(8)),
                          child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Örnek', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  const Text(bilgiCsvExample, style: TextStyle(color: BilgiColors.secondary, fontSize: 13)),
                  const SizedBox(height: 12),
                  const Text('Doğru cevap: A, B, C veya D.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text('Zorluk: kolay, orta, zor, efsane.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text('Açıklama, soru cevaplandıktan sonra gösterilen doğru cevap metnidir. Virgül varsa tırnak içine alın.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text('İpucu isteğe bağlıdır. Boşsa ipucu jokeri o soruda pasif kalır.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 6),
                  const Text('Kategori ana kategori adıdır. Alt kategori zorunludur. Bilinmeyen satır atlanır. Yeni sorular onay bekler.', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickCsv() async {
    final file = await pickCsvFile();
    if (!mounted || file == null) return;
    if (file.notCsv) {
      setState(() => _note = 'Yalnızca CSV yüklenebilir.');
      return;
    }
    if (file.tooBig) {
      setState(() => _note = 'Dosya 10 MB sınırını aşıyor.');
      return;
    }
    final added = await _importCsv(file.text);
    if (!mounted) return;
    setState(() {
      _csvName = file.name;
      _note = '${file.name}: ${added.$1} satır beklemeye alındı. ${added.$2} satır atlandı. ${added.$3} satır kaydedilemedi.';
    });
    await _load();
  }

  Future<void> _saveCsvText() async {
    final raw = _csvText.text;
    if (raw.trim().isEmpty) {
      setState(() => _note = 'CSV metni boş.');
      return;
    }
    if (raw.length > 10 * 1024 * 1024) {
      setState(() => _note = 'Metin 10 MB sınırını aşıyor.');
      return;
    }
    final added = await _importCsv(raw);
    if (!mounted) return;
    _csvText.clear();
    setState(() => _note = '${added.$1} satır beklemeye alındı. ${added.$2} satır atlandı. ${added.$3} satır kaydedilemedi.');
    await _load();
  }

  Future<(int, int, int)> _importCsv(String raw) async {
    var skipped = 0;
    var seq = 0;
    final batch = <BilgiQuestion>[];
    final text = raw.replaceFirst('\uFEFF', '');
    final stamp = DateTime.now().microsecondsSinceEpoch;
    for (final line in text.split(RegExp(r'\r?\n'))) {
      final parsed = parseBilgiCsvLine(line);
      if (parsed.kind == BilgiCsvKind.blank || parsed.kind == BilgiCsvKind.header) continue;
      final fields = parsed.fields;
      if (parsed.kind == BilgiCsvKind.invalid || fields == null) {
        skipped += 1;
        continue;
      }
      final category = _categoryId(fields.category);
      final subcategory = category == null ? null : _subName(category, fields.subcategory);
      final difficulty = _fold(fields.difficulty);
      if (category == null || subcategory == null || fields.text.isEmpty || !const {'kolay', 'orta', 'zor', 'efsane'}.contains(difficulty)) {
        skipped += 1;
        continue;
      }
      seq += 1;
      batch.add(
        BilgiQuestion(
          id: 'imp$stamp$seq',
          text: fields.text,
          options: fields.options,
          correct: _letterIndex(fields.correctLetter),
          categoryId: category,
          difficulty: difficulty,
          explanation: fields.explanation,
          hint: fields.hint.length > 500 ? fields.hint.substring(0, 500) : fields.hint,
          status: 'pending',
          tags: [subcategory],
        ),
      );
    }
    if (batch.isEmpty) return (0, skipped, 0);
    try {
      await _saveRemote(batch);
      return (batch.length, skipped, 0);
    } catch (_) {
      return (0, skipped, batch.length);
    }
  }

  String? _categoryId(String raw) {
    final folded = _fold(raw.trim());
    for (final category in _categories) {
      final source = bilgiCategoryById(category.id);
      if (_fold(category.name) == folded || _fold(category.id) == folded || (source != null && _fold(source.name) == folded)) {
        return category.id;
      }
    }
    return null;
  }

  String? _subName(String categoryId, String raw) {
    final category = _categories.where((item) => item.id == categoryId).firstOrNull;
    if (category == null) return null;
    final folded = _fold(raw.trim());
    for (final name in category.subs) {
      if (_fold(name) == folded) return name;
    }
    return null;
  }

  int _letterIndex(String raw) {
    final n = int.tryParse(raw.trim());
    if (n != null) return n.clamp(0, 3);
    return switch (raw.trim().toUpperCase()) { 'B' => 1, 'C' => 2, 'D' => 3, _ => 0 };
  }

  List<BilgiCategory> get _categories => resolveBilgiCategories(_catalog);

  int _questionTotal(String id) => _bankSummary.categoryTotal(id);

  Widget _categoryList() {
    final groups = <String, List<BilgiCategory>>{};
    for (final category in _categories) {
      groups.putIfAbsent(category.group, () => []).add(category);
    }
    final order = [
      for (final group in bilgiGroups)
        if (groups.containsKey(group) || group == bilgiSpecialEventGroup) group,
      for (final group in groups.keys)
        if (!bilgiGroups.contains(group)) group,
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        for (var i = 0; i < order.length; i++) ...[
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 16, bottom: 12),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    order[i].toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: BilgiColors.secondary, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w800),
                  ),
                ),
                if (order[i] == bilgiSpecialEventGroup) ...[
                  const SizedBox(width: 8),
                  _specialEventTag(),
                ],
                const SizedBox(width: 8),
                _catBtn('✏️', () => _editGroup(order[i])),
                const Spacer(),
                Text('${(groups[order[i]] ?? const <BilgiCategory>[]).length} kategori', style: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final rows = groups[order[i]] ?? const <BilgiCategory>[];
              final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 620 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final category in rows) _categoryCard(category, width),
                ],
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _categoryCard(BilgiCategory category, double width) {
    final total = _questionTotal(category.id);
    final ready = bilgiNamesReady(_labels, 'category', category.id, locales: category.locales);
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: _cardDeco(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(14)),
            child: Text(category.emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ready ? null : const Color(0xFFFF5C7A)),
                      ),
                    ),
                    if (ready) ...[
                      const SizedBox(width: 6),
                      _langOk(),
                    ],
                  ],
                ),
                if (bilgiSpecialEventCategory(category)) ...[
                  const SizedBox(height: 6),
                  _specialEventTag(compact: true),
                ],
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(child: Text('📝 $total soru    📁 ${category.subs.length} alt', style: const TextStyle(color: BilgiColors.muted, fontSize: 11))),
                    _popularMark(category),
                    const SizedBox(width: 8),
                    _activeSwitch(category.active, (value) => _toggleCategory(category, value)),
                  ],
                ),
              ],
            ),
          ),
          _catBtn('✏️', () => _editCategory(category)),
          const SizedBox(width: 6),
          if (total == 0) ...[
            _catBtn('🗑️', () => _deleteCategory(category)),
            const SizedBox(width: 6),
          ],
          _catBtn('📁', () => setState(() {
                _subCat = category.id;
                _index = 9;
              })),
        ],
      ),
    );
  }

  Widget _catBtn(String emoji, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BilgiColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x1AFFFFFF)),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Future<void> _editGroup(String group) async {
    final fields = <String, TextEditingController>{
      'tr': TextEditingController(text: group),
      for (final locale in GameLocale.all)
        if (locale.id != 'tr') locale.id: TextEditingController(text: _labels['${locale.id}|group|$group'] ?? bilgiGroupLabel(locale.id, group) ?? ''),
    };
    var lang = 'en';
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          backgroundColor: BilgiColors.card,
          constraints: BoxConstraints(maxWidth: _labelDialogWidth(context) + 64),
          title: const Text('Üst başlığı düzenle'),
          content: SizedBox(
            width: _labelDialogWidth(context),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _BilgiLangTabs(
                    selected: lang,
                    wrap: true,
                    onSelect: (id) => setLocal(() => lang = id),
                    filled: (id) => fields[id]?.text.trim().isNotEmpty ?? false,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: ValueKey(lang),
                    controller: fields[lang],
                    readOnly: lang == 'tr',
                    onChanged: (_) => setLocal(() {}),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(labelText: lang == 'tr' ? 'Türkçe ad' : 'Görünen ad'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    final names = {for (final entry in fields.entries) if (entry.key != 'tr') entry.key: entry.value.text.trim()};
    for (final field in fields.values) {
      field.dispose();
    }
    if (saved != true || !mounted) return;
    await _saveNameLabels(scope: 'group', key: group, names: names);
    if (!mounted) return;
    setState(() => _note = '$group kaydedildi.');
    await _load();
  }

  Future<void> _editCategory(BilgiCategory category) async {
    final labels = await BilgiQuestionApi.loadLabels();
    if (!mounted) return;
    setState(() => _labels = labels);
    final result = await _askCategory(
      title: 'Kategoriyi düzenle',
      name: category.name,
      emoji: category.emoji,
      group: category.group,
      names: {
        for (final locale in GameLocale.all)
          if (locale.id != 'tr') locale.id: labels['${locale.id}|category|${category.id}'] ?? '',
      },
      locales: category.locales,
      saveNames: (names) => _saveNameLabels(scope: 'category', key: category.id, names: names),
    );
    if (!mounted) return;
    if (result == null) {
      await _load();
      return;
    }
    final saved = await BilgiQuestionApi.saveCategory(
      sl<ApiSession>().adminToken ?? '',
      id: category.id,
      name: result.name,
      emoji: result.emoji,
      group: result.group,
      locales: result.locales,
    );
    if (!mounted) return;
    if (saved.error != null) {
      setState(() => _note = saved.error!);
      return;
    }
    await _saveNameLabels(scope: 'category', key: category.id, names: result.names);
    await _load();
  }

  Future<void> _addCategory() async {
    final result = await _askCategory(
      title: 'Yeni kategori',
      name: '',
      emoji: '📚',
      group: bilgiGroups.first,
      names: const {},
      locales: const ['tr'],
    );
    if (result == null || !mounted) return;
    if (_categories.any((category) => _fold(category.name) == _fold(result.name))) {
      setState(() => _note = 'Bu kategori adı zaten var.');
      return;
    }
    final saved = await BilgiQuestionApi.saveCategory(
      sl<ApiSession>().adminToken ?? '',
      name: result.name,
      emoji: result.emoji,
      group: result.group,
      locales: result.locales,
    );
    if (!mounted) return;
    if (saved.error != null || saved.id == null) {
      setState(() => _note = saved.error ?? 'Kategori kaydedilemedi.');
      return;
    }
    await _saveNameLabels(scope: 'category', key: saved.id!, names: result.names);
    if (!mounted) return;
    setState(() => _note = '${result.name} eklendi.');
    await _load();
  }

  String _groupDropdownLabel(String locale, String group) {
    if (locale == 'tr') return group;
    final stored = (_labels['$locale|group|$group'] ?? '').trim();
    // Stored Turkish key (or empty) must not mask the catalog translation for en/de/….
    if (stored.isNotEmpty && stored != group) return stored;
    return bilgiGroupLabel(locale, group) ?? group;
  }

  Future<({String name, String emoji, String group, Map<String, String> names, List<String> locales})?> _askCategory({
    required String title,
    required String name,
    required String emoji,
    required String group,
    required Map<String, String> names,
    List<String>? locales,
    Future<String?> Function(Map<String, String> names)? saveNames,
  }) async {
    final fields = <String, TextEditingController>{
      'tr': TextEditingController(text: name),
      for (final locale in GameLocale.all)
        if (locale.id != 'tr') locale.id: TextEditingController(text: names[locale.id] ?? ''),
    };
    final emojiField = TextEditingController(text: emoji);
    final initialGroup = bilgiGroups.contains(group) ? group : bilgiGroups.first;
    final saved = await showDialog<({bool ok, String group, List<String> locales})>(
      context: context,
      builder: (context) => _AskCategoryDialog(
        title: title,
        fields: fields,
        emojiField: emojiField,
        initialGroup: initialGroup,
        initialLocales: locales,
        saveNames: saveNames,
        groupLabel: _groupDropdownLabel,
      ),
    );
    final nextName = fields['tr']!.text.trim();
    final nextEmoji = emojiField.text.trim();
    final nextGroup = saved?.group ?? initialGroup;
    final nextLocales = saved?.locales ?? bilgiPublishLocalesOf(locales);
    final nextNames = {for (final entry in fields.entries) if (entry.key != 'tr') entry.key: entry.value.text.trim()};
    for (final field in fields.values) {
      field.dispose();
    }
    emojiField.dispose();
    if (saved == null || !saved.ok || nextName.isEmpty || nextEmoji.isEmpty) return null;
    return (name: nextName, emoji: nextEmoji, group: nextGroup, names: nextNames, locales: nextLocales);
  }

  Future<String?> _saveNameLabels({
    required String scope,
    required String key,
    required Map<String, String> names,
  }) async {
    final rows = [
      for (final entry in names.entries)
        if (entry.value.isNotEmpty) {'locale': entry.key, 'scope': scope, 'key': key, 'label': entry.value},
    ];
    if (rows.isEmpty) return null;
    final error = await BilgiQuestionApi.saveLabels(sl<ApiSession>().adminToken ?? '', rows);
    if (!mounted) return error;
    if (error != null) setState(() => _note = error);
    return error;
  }

  Widget _popularMark(BilgiCategory category) {
    final on = category.popular;
    return InkWell(
      onTap: () => _togglePopular(category),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          on ? '⭐ Popüler' : '☆ Popüler',
          style: TextStyle(
            color: on ? BilgiColors.warning : BilgiColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _togglePopular(BilgiCategory category) async {
    final error = await BilgiQuestionApi.setPopular(
      sl<ApiSession>().adminToken ?? '',
      id: category.id,
      popular: !category.popular,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _note = error);
      return;
    }
    await _load();
  }

  Future<void> _toggleCategory(BilgiCategory category, bool active) async {
    if (active) {
      final labels = await BilgiQuestionApi.loadLabels();
      if (!bilgiNamesReady(labels, 'category', category.id, locales: category.locales)) {
        if (!mounted) return;
        setState(() => _note = bilgiCategoryBlocked);
        return;
      }
    }
    final error = await BilgiQuestionApi.setActive(
      sl<ApiSession>().adminToken ?? '',
      kind: 'category',
      key: category.id,
      active: active,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _note = error);
      return;
    }
    await _load();
  }

  bool _subIsActive(String categoryId, String name) {
    final raw = _catalog['inactiveSubs'];
    if (raw is! List) return true;
    return !raw.map((item) => '$item').contains('$categoryId|$name');
  }

  Widget _activeSwitch(bool value, ValueChanged<bool> onChanged) {
    return Switch(
      value: value,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      activeThumbColor: BilgiColors.secondary,
      activeTrackColor: const Color(0x7300D9C0),
      onChanged: onChanged,
    );
  }

  Future<void> _deleteCategory(BilgiCategory category) async {
    if (_questionTotal(category.id) > 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BilgiColors.card,
        title: Text('${category.name} silinsin mi?'),
        content: const Text('Bu kategoride soru yok. Kayıt veritabanından silinir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BilgiColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final message = await BilgiQuestionApi.deleteCategory(sl<ApiSession>().adminToken ?? '', category.id);
    if (!mounted) return;
    if (message != null) {
      setState(() => _note = message);
      return;
    }
    setState(() => _note = '${category.name} silindi.');
    await _load();
  }

  Widget _subs() {
    if (_categories.isEmpty) {
      return const Center(child: Text('Kategori yok.', style: TextStyle(color: BilgiColors.muted)));
    }
    final selected = _categories.where((category) => category.id == _subCat).firstOrNull ?? _categories.first;
    final count = _bankSummary.categoryApproved(selected.id);
    final query = _subSearch.text.trim();
    final filtering = query.length >= 3;
    final folded = _fold(query);
    final karmaTitle = '${selected.name} Karma';
    final showKarma = !filtering || _fold(karmaTitle).contains(folded);
    final visibleSubs = filtering ? [for (final sub in selected.subs) if (_fold(sub).contains(folded)) sub] : selected.subs;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: _cardDeco(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Ana Kategori', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                  if (bilgiSpecialEventCategory(selected)) ...[
                    const SizedBox(width: 8),
                    _specialEventTag(compact: true),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              _SearchCombo(
                hint: 'Kategori ara',
                selected: selected.id,
                clearable: false,
                options: [
                  for (final c in ([..._categories]..sort((a, b) => _fold(a.name).compareTo(_fold(b.name)))))
                    (c.id, '${c.emoji} ${c.name}'),
                ],
                onChanged: (v) {
                  if (v.isEmpty) return;
                  setState(() => _subCat = v);
                },
              ),
              const SizedBox(height: 16),
              const Text('Ara', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _subSearch,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'En az 3 harf yaz',
                  hintStyle: const TextStyle(color: BilgiColors.muted),
                  helperText: query.isEmpty || filtering ? null : 'Arama 3 harfte başlar',
                  helperStyle: const TextStyle(color: BilgiColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Yeni alt kategori', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: _newSub, style: const TextStyle(color: Colors.white), decoration: InputDecoration(hintText: 'Alt kategori adı', hintStyle: TextStyle(color: BilgiColors.muted)))),
                  const SizedBox(width: 12),
                  _primary('Ekle', () => _addSub(selected)),
                ],
              ),
            ],
          ),
        ),
        if (showKarma)
          _subRow(
            '🎲',
            karmaTitle,
            'Aynı soru havuzu • $count soru',
            gradient: true,
            event: bilgiSpecialEventCategory(selected),
          ),
        if (selected.subs.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 12), child: Text('Bu kategoride alt kategori yok.', style: TextStyle(color: BilgiColors.muted)))
        else if (visibleSubs.isEmpty && !showKarma)
          const Padding(padding: EdgeInsets.only(top: 12), child: Text('Sonuç yok.', style: TextStyle(color: BilgiColors.muted)))
        else
          for (final sub in visibleSubs)
            _subRow(
              _subIcon(sub),
              sub,
              _subCountLine(selected.id, sub).label,
              caption: _subCountCaption(selected.id, sub),
              ready: bilgiNamesReady(_labels, 'sub', '${selected.id}|$sub', locales: selected.locales),
              event: bilgiSpecialEventCategory(selected),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _activeSwitch(_subIsActive(selected.id, sub), (value) => _toggleSub(selected, sub, value)),
                  _catBtn('✏️', () => _editSub(selected, sub)),
                  if (_subQuestionCount(sub) == 0) ...[
                    const SizedBox(width: 6),
                    _catBtn('🗑️', () => _deleteSub(selected, sub)),
                  ],
                ],
              ),
            ),
      ],
    );
  }

  Future<void> _addSub(BilgiCategory category) async {
    final name = _newSub.text.trim();
    if (name.isEmpty) {
      setState(() => _note = 'Alt kategori adı boş.');
      return;
    }
    if (category.subs.any((sub) => _fold(sub) == _fold(name))) {
      setState(() => _note = 'Bu alt kategori zaten var.');
      return;
    }
    final saved = await BilgiQuestionApi.saveCategory(
      sl<ApiSession>().adminToken ?? '',
      id: category.id,
      name: category.name,
      emoji: category.emoji,
      group: category.group,
      addSub: name,
    );
    if (!mounted) return;
    if (saved.error != null) {
      setState(() => _note = saved.error!);
      return;
    }
    _newSub.clear();
    if (!mounted) return;
    setState(() => _note = '$name eklendi.');
    await _load();
  }

  int _subQuestionCount(String name) => _bankSummary.subTotal(name);

  int _subStatusCount(String categoryId, String name, String status) =>
      _bankSummary.subStatusCount(categoryId, name, status);

  BilgiSubCountLine _subCountLine(String categoryId, String name) {
    return bilgiSubCountLine(
      pending: _subStatusCount(categoryId, name, 'pending'),
      published: _subStatusCount(categoryId, name, 'approved'),
    );
  }

  Widget _subCountCaption(String categoryId, String name) {
    final line = _subCountLine(categoryId, name);
    return Text.rich(
      TextSpan(
        style: const TextStyle(color: BilgiColors.muted, fontSize: 11),
        children: [
          TextSpan(text: 'Beklemede ${line.pending} • Yayınlı '),
          TextSpan(
            text: '${line.published}',
            style: line.publishedLow
                ? const TextStyle(color: BilgiColors.error, fontWeight: FontWeight.w800, fontSize: 11)
                : null,
          ),
        ],
      ),
    );
  }

  String _subIcon(String name) {
    final icons = _catalog['subEmoji'];
    if (icons is Map && icons[name] is String && '${icons[name]}'.trim().isNotEmpty) return '${icons[name]}'.trim();
    return bilgiSubIcon(name, '📁');
  }

  Future<void> _editSub(BilgiCategory category, String name) async {
    final labels = await BilgiQuestionApi.loadLabels();
    if (!mounted) return;
    final fields = <String, TextEditingController>{
      'tr': TextEditingController(text: name),
      for (final locale in GameLocale.all)
        if (locale.id != 'tr') locale.id: TextEditingController(text: labels['${locale.id}|sub|${category.id}|$name'] ?? ''),
    };
    final emojiField = TextEditingController(text: _subIcon(name) == '📁' ? '' : _subIcon(name));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BilgiColors.card,
        constraints: BoxConstraints(maxWidth: _labelDialogWidth(context) + 64),
        title: const Text('Alt kategoriyi düzenle'),
        content: SizedBox(
          width: _labelDialogWidth(context),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LangNameFields(
                  fields: fields,
                  published: category.publishLocales.toSet(),
                  saveNames: (names) => _saveNameLabels(scope: 'sub', key: '${category.id}|${fields['tr']!.text.trim()}', names: names),
                ),
                TextField(controller: emojiField, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Simge')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    final next = fields['tr']!.text.trim();
    final emoji = emojiField.text.trim();
    final allowed = category.publishLocales.toSet();
    final names = {
      for (final entry in fields.entries)
        if (entry.key != 'tr' && allowed.contains(entry.key)) entry.key: entry.value.text.trim(),
    };
    for (final field in fields.values) {
      field.dispose();
    }
    emojiField.dispose();
    if (saved != true || !mounted || next.isEmpty) {
      if (mounted && saved != true) await _load();
      return;
    }
    if (next != name && category.subs.any((sub) => _fold(sub) == _fold(next))) {
      setState(() => _note = 'Bu alt kategori zaten var.');
      return;
    }
    final stored = await BilgiQuestionApi.saveCategory(
      sl<ApiSession>().adminToken ?? '',
      id: category.id,
      name: category.name,
      emoji: category.emoji,
      group: category.group,
      renameFrom: name,
      renameTo: next,
      subEmoji: emoji,
    );
    if (!mounted) return;
    if (stored.error != null) {
      setState(() => _note = stored.error!);
      return;
    }
    await _saveNameLabels(scope: 'sub', key: '${category.id}|$next', names: names);
    if (!mounted) return;
    setState(() => _note = '$next kaydedildi.');
    await _load();
  }

  Future<void> _deleteSub(BilgiCategory category, String name) async {
    if (_subQuestionCount(name) > 0) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: BilgiColors.card,
        title: Text('$name silinsin mi?'),
        content: const Text('Bu alt kategoride soru yok.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BilgiColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final message = await BilgiQuestionApi.deleteSubcategory(sl<ApiSession>().adminToken ?? '', category.id, name);
    if (!mounted) return;
    setState(() => _note = message ?? '$name silindi.');
    await _load();
  }

  Future<void> _toggleSub(BilgiCategory category, String name, bool active) async {
    final key = '${category.id}|$name';
    if (active) {
      final labels = await BilgiQuestionApi.loadLabels();
      if (!bilgiNamesReady(labels, 'sub', key, locales: category.locales)) {
        if (!mounted) return;
        setState(() => _note = bilgiSubBlocked);
        return;
      }
    }
    final error = await BilgiQuestionApi.setActive(
      sl<ApiSession>().adminToken ?? '',
      kind: 'sub',
      key: key,
      active: active,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _note = error);
      return;
    }
    await _load();
  }

  Widget _langOk() => const Icon(Icons.check_circle, color: Color(0xFF3DDC84), size: 18);

  Widget _subRow(String emoji, String title, String hint, {bool gradient = false, bool ready = false, bool event = false, Widget? caption, Widget? trailing}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: gradient ? const LinearGradient(colors: [BilgiColors.primary, BilgiColors.primaryLight]) : null,
        color: gradient ? null : BilgiColors.card,
        border: gradient ? null : Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Row(
        children: [
          Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(12)), child: Text(emoji, style: const TextStyle(fontSize: 22))),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700))),
                    if (event) ...[
                      const SizedBox(width: 6),
                      _specialEventTag(compact: true),
                    ],
                    if (ready) ...[
                      const SizedBox(width: 6),
                      _langOk(),
                    ],
                  ],
                ),
                caption ?? Text(hint, style: TextStyle(color: gradient ? Colors.white70 : BilgiColors.muted, fontSize: 11)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _tags() {
    final counts = <String, int>{..._bankSummary.tagCounts};
    for (final tag in _config.adminTags) {
      counts.putIfAbsent(tag, () => 0);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: _cardDeco(),
          child: counts.isEmpty
              ? const Text('Etiket yok.', style: TextStyle(color: BilgiColors.muted))
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final entry in counts.entries)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x1AFFFFFF))),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [Text(entry.key), const SizedBox(width: 8), _badge('${entry.value}', BilgiColors.primary)]),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _karma() {
    final approved = _bankSummary.approved;
    final counts = {
      'kolay': _bankSummary.approvedByDifficulty['kolay'] ?? 0,
      'orta': _bankSummary.approvedByDifficulty['orta'] ?? 0,
      'zor': _bankSummary.approvedByDifficulty['zor'] ?? 0,
      'efsane': _bankSummary.approvedByDifficulty['efsane'] ?? 0,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _panelCard('KARMA', [
          const Text('Alt kategoriler ayrı banka tutmaz. Tümü Karma tüm onaylı soruları çeker. Genel Karma kendi kategorisidir.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
          const SizedBox(height: 12),
          _infoRow('Tümü Karma', '$approved onaylı soru'),
          _infoRow('Soru sayısı', 'Mod ayarındaki tur uzunluğu'),
          for (final entry in counts.entries) _infoRow(_diffName(entry.key), '${entry.value} soru'),
        ]),
      ],
    );
  }

  DateTime _userRegisteredAt(BilgiProfile user) => user.accountCreatedAt ?? user.createdAt;

  String _userDay(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }

  String _userStatusKey(BilgiProfile user) {
    if (user.banned) return 'banli';
    if (user.guestHere) return 'misafir';
    if (user.premium) return 'premium';
    return 'aktif';
  }

  bool _userMatches(BilgiProfile user, {required bool? banned, required bool premium, required String query}) {
    if (premium && !user.premium) return false;
    if (banned != null && user.banned != banned) return false;
    if (query.isNotEmpty &&
        !user.username.toLowerCase().contains(query) &&
        !user.email.toLowerCase().contains(query)) {
      return false;
    }
    if (_userFirstGame.isNotEmpty && user.accountFirstGame != _userFirstGame) return false;
    if (_userActiveGame.isNotEmpty && !user.accountGames.contains(_userActiveGame)) return false;
    if (banned == null && !premium && _userStatus.isNotEmpty && _userStatusKey(user) != _userStatus) {
      return false;
    }
    final registered = _userRegisteredAt(user);
    final now = DateTime.now();
    if (_userPeriod == '7' && registered.isBefore(now.subtract(const Duration(days: 7)))) return false;
    if (_userPeriod == '30' && registered.isBefore(now.subtract(const Duration(days: 30)))) return false;
    if (_userPeriod == 'year' && registered.year != now.year) return false;
    final minPlays = int.tryParse(_userPlays);
    if (minPlays != null && user.gamesPlayed < minPlays) return false;
    if (_userPlays == '0' && user.gamesPlayed != 0) return false;
    return true;
  }

  Widget _userFilter(String label, Widget field) {
    return SizedBox(
      width: 220,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          field,
        ],
      ),
    );
  }

  Widget _userList(bool? banned, {bool premium = false}) {
    if (_ledgerUser != null) return _ledgerPage();
    final query = _topSearch.text.trim().toLowerCase();
    final rows = _users.where((user) => _userMatches(user, banned: banned, premium: premium, query: query)).toList()
      ..sort((a, b) => _userRegisteredAt(b).compareTo(_userRegisteredAt(a)));
    final games = <(String, String)>[
      ('', 'Tümü'),
      for (final id in GameIds.all) (id, lunoGameLabel(id)),
    ];
    final empty = premium ? 'Premium üye yok.' : banned == true ? 'Banlı kullanıcı yok.' : 'Kayıtlı kullanıcı yok.';
    final filtersOn = _userFirstGame.isNotEmpty ||
        _userActiveGame.isNotEmpty ||
        _userStatus.isNotEmpty ||
        _userPeriod.isNotEmpty ||
        _userPlays.isNotEmpty;
    const columns = <(String, double)>[
      ('Kullanıcı', 168),
      ('E-posta', 200),
      ('Durum', 96),
      ('İlk oyun', 130),
      ('Etkin oyunlar', 210),
      ('İlk kayıt', 148),
      ('Son işlem', 148),
      ('Oyun sayısı', 104),
      ('Etkin oyun', 96),
      ('Seviye', 72),
      ('Altın', 80),
      ('Seri', 64),
      ('İşlem', 210),
    ];
    final tableWidth = columns.fold<double>(24, (sum, column) => sum + column.$2);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
        if (premium)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Play makbuzu olmadan premium yüklenmez.', style: TextStyle(color: BilgiColors.warning)),
          ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _userFilter('İlk oyun', _select(_userFirstGame, games, (value) => setState(() => _userFirstGame = value))),
            _userFilter('Etkin oyun', _select(_userActiveGame, games, (value) => setState(() => _userActiveGame = value))),
            if (banned == null && !premium)
              _userFilter(
                'Durum',
                _select(_userStatus, const [
                  ('', 'Tümü'),
                  ('aktif', 'Aktif'),
                  ('misafir', 'Misafir'),
                  ('premium', 'Premium'),
                  ('banli', 'Banlı'),
                ], (value) => setState(() => _userStatus = value)),
              ),
            _userFilter(
              'İlk kayıt',
              _select(_userPeriod, const [
                ('', 'Tümü'),
                ('7', 'Son 7 gün'),
                ('30', 'Son 30 gün'),
                ('year', 'Bu yıl'),
              ], (value) => setState(() => _userPeriod = value)),
            ),
            _userFilter(
              'Oyun sayısı',
              _select(_userPlays, const [
                ('', 'Tümü'),
                ('0', 'Henüz yok'),
                ('1', '1 ve üzeri'),
                ('10', '10 ve üzeri'),
                ('50', '50 ve üzeri'),
              ], (value) => setState(() => _userPlays = value)),
            ),
            if (filtersOn)
              _ghost('Filtreleri temizle', () => setState(() {
                    _userFirstGame = '';
                    _userActiveGame = '';
                    _userStatus = '';
                    _userPeriod = '';
                    _userPlays = '';
                  })),
          ],
        ),
              const SizedBox(height: 14),
              Text('${rows.length} kullanıcı', style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDeco(),
                    child: Text(empty, style: const TextStyle(color: BilgiColors.muted)),
                  ),
                )
              : Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _userHead(columns),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: rows.length,
                              itemBuilder: (context, index) => _userRow(rows[index], columns, premium: premium),
                            ),
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

  Widget _userHead(List<(String, double)> columns) {
    return Container(
      color: const Color(0xFF16132A),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          for (final column in columns) _userCell(column.$1, column.$2, header: true),
        ],
      ),
    );
  }

  Widget _userRow(BilgiProfile user, List<(String, double)> columns, {required bool premium}) {
    final first = (user.accountFirstGame ?? '').isEmpty ? '' : lunoGameLabel(user.accountFirstGame!);
    final active = user.accountGames.isEmpty ? '' : user.accountGames.map(lunoGameLabel).join(', ');
    final status = user.banned ? 'Banlı' : user.guestHere ? 'Misafir' : user.premium ? 'Premium' : 'Aktif';
    final statusColor = user.banned
        ? BilgiColors.error
        : user.guestHere
            ? BilgiColors.warning
            : BilgiColors.secondary;
    final values = <String>[
      user.username,
      user.email,
      status,
      first,
      active,
      _userDay(_userRegisteredAt(user)),
      user.lastActivityAt == null ? '' : _userDay(user.lastActivityAt!),
      '${user.gamesPlayed}',
      '${user.accountGames.length}',
      '${user.level}',
      '${user.gold}',
      '${user.streak}',
    ];
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x14FFFFFF)))),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < values.length; i++)
            i == 2
                ? SizedBox(width: columns[i].$2, child: Align(alignment: Alignment.centerLeft, child: _badge(status, statusColor)))
                : _userCell(values[i], columns[i].$2, strong: i == 0),
          SizedBox(
            width: columns.last.$2,
            child: Wrap(
              spacing: 8,
              children: [
                _ghost('Hareketler', () {
                  setState(() {
                    _ledgerUser = user;
                    _ledgerLines = const [];
                    _ledgerFlow = '';
                    _ledgerError = '';
                  });
                  _loadLedger();
                }),
                if (!premium)
                  _ghost(user.banned ? 'Aç' : 'Banla', () async {
                    final nextBanned = !user.banned;
                    final reason = nextBanned ? 'Askıya alındı' : '';
                    final token = sl<ApiSession>().adminToken ?? '';
                    final error = await BilgiUserApi.setBan(
                      token,
                      user.id,
                      banned: nextBanned,
                      reason: reason,
                    );
                    await _server.setBan(user.id, banned: nextBanned, reason: reason);
                    if (error != null && mounted) setState(() => _note = error);
                    await _load();
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userCell(String text, double width, {bool header = false, bool strong = false}) {
    return SizedBox(
      width: width,
      child: Text(
        text.isEmpty ? (header ? '' : '—') : text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: header ? BilgiColors.muted : Colors.white,
          fontSize: header ? 11 : 13,
          fontWeight: header || strong ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _loadLedger() async {
    final user = _ledgerUser;
    if (user == null) return;
    final token = sl<ApiSession>().adminToken ?? '';
    final result = await BilgiUserApi.ledger(
      token,
      user.id,
      asset: _ledgerAsset,
      reason: _ledgerReason,
      from: _ledgerFrom.text.trim(),
      to: _ledgerTo.text.trim(),
    );
    if (!mounted || _ledgerUser?.id != user.id) return;
    setState(() {
      _ledgerLines = result.lines;
      _ledgerError = result.error ?? '';
    });
  }

  String _ledgerLabel(String code, List<(String, String)> items) {
    for (final item in items) {
      if (item.$1 == code) return item.$2;
    }
    return code;
  }

  Widget _ledgerPage() {
    const assets = <(String, String)>[
      ('', 'Tümü'),
      ('gold', 'Altın'),
      ('diamond', 'Elmas'),
      ('xp', 'XP'),
      ('life', 'Can'),
      ('joker_half', 'Yarı yarıya'),
      ('joker_double', 'Çift puan'),
      ('joker_time', 'Süre'),
      ('joker_change', 'Değiştir'),
      ('joker_hint', 'İpucu'),
      ('league_score', 'Lig puanı'),
      ('premium', 'Premium'),
    ];
    const reasons = <(String, String)>[
      ('', 'Tümü'),
      ('starter', 'Başlangıç'),
      ('opening', 'Geçiş bakiyesi'),
      ('life_spend', 'Can harcama'),
      ('life_regen', 'Can yenileme'),
      ('round_finish', 'Tur sonu'),
      ('score_double', 'Puanı ikiye katla'),
      ('joker_buy', 'Joker alımı'),
      ('joker_use', 'Joker kullanımı'),
      ('life_refill', 'Can doldurma'),
      ('daily', 'Günlük ödül'),
      ('ad_gold', 'Reklam altın'),
      ('ad_joker', 'Reklam joker'),
      ('ad_life', 'Reklam can'),
      ('play_gold', 'Altın satın alma'),
      ('play_plus', 'Luno Plus'),
      ('invite', 'Davet'),
      ('league_monday', 'Pazartesi lig'),
      ('admin', 'Yönetici'),
    ];
    final user = _ledgerUser!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Row(
          children: [
            _ghost('Geri', () => setState(() => _ledgerUser = null)),
            const SizedBox(width: 12),
            Expanded(child: Text('${user.username} hareketleri', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            _userFilter('Varlık', _select(_ledgerAsset, assets, (value) => setState(() => _ledgerAsset = value))),
            _userFilter('Neden', _select(_ledgerReason, reasons, (value) => setState(() => _ledgerReason = value))),
            _userFilter(
              'Yön',
              _select(_ledgerFlow, const [
                ('', 'Tümü'),
                ('in', 'Yükleme'),
                ('out', 'Tüketim'),
              ], (value) => setState(() => _ledgerFlow = value)),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _ledgerFrom,
                decoration: const InputDecoration(labelText: 'Başlangıç', hintText: 'GG.AA.YYYY', isDense: true),
              ),
            ),
            SizedBox(
              width: 150,
              child: TextField(
                controller: _ledgerTo,
                decoration: const InputDecoration(labelText: 'Bitiş', hintText: 'GG.AA.YYYY', isDense: true),
              ),
            ),
            _primary('Göster', _loadLedger),
          ],
        ),
        const SizedBox(height: 12),
        Text('${_ledgerVisible().length} hareket', style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
        if (_ledgerError.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_ledgerError, style: const TextStyle(color: BilgiColors.error)),
        ],
        const SizedBox(height: 12),
        _ledgerGrid(assets, reasons),
      ],
    );
  }

  List<BilgiLedgerLine> _ledgerVisible() {
    return [
      for (final line in _ledgerLines)
        if (_ledgerFlow == 'in' && line.amount > 0 || _ledgerFlow == 'out' && line.amount < 0 || _ledgerFlow == '') line,
    ];
  }

  String _ledgerFlowLabel(int amount) {
    if (amount > 0) return 'Yükleme';
    if (amount < 0) return 'Tüketim';
    return '—';
  }

  Widget _ledgerGrid(List<(String, String)> assets, List<(String, String)> reasons) {
    const head = TextStyle(color: BilgiColors.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4);
    const cell = TextStyle(fontSize: 12, fontWeight: FontWeight.w600);
    final rows = _ledgerVisible();
    Widget col(String text, double width, {TextStyle? style, Color? color}) {
      return SizedBox(
        width: width,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: (style ?? cell).copyWith(color: color),
        ),
      );
    }

    Widget lineRow(BilgiLedgerLine? line) {
      final amount = line == null ? '' : '${line.amount > 0 ? '+' : ''}${line.amount}';
      final amountColor = line == null
          ? null
          : line.amount > 0
              ? BilgiColors.secondary
              : line.amount < 0
                  ? BilgiColors.error
                  : null;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: line == null ? const Color(0xFF121022) : null,
          border: const Border(bottom: BorderSide(color: Color(0x08FFFFFF))),
        ),
        child: Row(
          children: [
            col(line == null ? 'Tarih' : _ledgerWhen(line.createdAt), 132, style: line == null ? head : cell),
            col(line == null ? 'Varlık' : _ledgerLabel(line.asset, assets), 100, style: line == null ? head : cell),
            col(line == null ? 'Yön' : _ledgerFlowLabel(line.amount), 88, style: line == null ? head : cell),
            col(line == null ? 'Tutar' : amount, 72, style: line == null ? head : cell, color: amountColor),
            col(line == null ? 'Sonraki stok' : '${line.balanceAfter}', 96, style: line == null ? head : cell),
            col(line == null ? 'Neden' : _ledgerLabel(line.reason, reasons), 130, style: line == null ? head : cell),
            col(line == null ? 'Referans' : (line.ref.isEmpty ? '—' : line.ref), 168, style: line == null ? head : const TextStyle(fontSize: 11, color: BilgiColors.muted)),
            col(line == null ? 'Ayrıntı' : (line.detail.isEmpty ? '—' : _ledgerDetail(line.detail)), 280, style: line == null ? head : cell),
          ],
        ),
      );
    }

    return Container(
      decoration: _cardDeco(),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            lineRow(null),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Bu süzgeçte hareket yok.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
              )
            else
              for (final line in rows) lineRow(line),
          ],
        ),
      ),
    );
  }

  String _ledgerWhen(DateTime time) {
    final local = time.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }

  String _ledgerDetail(Map<String, Object?> detail) {
    return detail.entries.where((entry) => '${entry.value}'.isNotEmpty).map((entry) => '${entry.key}: ${entry.value}').join(' · ');
  }

  Widget _toggles() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _panelCard('OYUN AYARLARI', [
          _infoRow('Can sistemi', _config.livesEnabled ? 'Açık' : 'Kapalı'),
          _infoRow('Otomatik zorluk', 'Kapalı'),
          _infoRow('Günlük ücretsiz oyun', '${_config.dailyFreeGames}'),
          _infoRow('İlk reklamsız oyun', '${_config.newUserAdFree}'),
          _infoRow('Kolay / Orta / Zor / Efsane', '${_config.scoreKolay} / ${_config.scoreOrta} / ${_config.scoreZor} / ${_config.scoreEfsane}'),
          _infoRow('Hız bonusu', '${_config.scoreTimeBonus}'),
        ]),
      ],
    );
  }

  Widget _modes() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final mode in bilgiModes)
              SizedBox(
                width: 260,
                child: _panelCard('${mode.emoji} ${mode.name}'.toUpperCase(), [
                  _infoRow('Soru', '${_config.resolvedMode(mode).questions}'),
                  _infoRow('Süre', mode.totalSeconds > 0 ? '${mode.totalSeconds ~/ 60} dk' : mode.seconds == 0 ? 'Süresiz' : '${_config.resolvedMode(mode).seconds} sn'),
                  _infoRow('Katsayı', '${_config.resolvedMode(mode).multiplier}x'),
                  _infoRow('Can', '${_config.resolvedMode(mode).lifeCost}'),
                  _infoRow('Joker', '${mode.jokerMax}'),
                ]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _jokers() {
    const names = {'half': 'Yarı Yarıya', 'double': 'Çift Puan', 'time': 'Süre Durdur', 'change': 'Soru Değiştir', 'hint': 'İpucu'};
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final key in names.keys)
              SizedBox(
                width: 220,
                child: _panelCard(names[key]!.toUpperCase(), [
                  _infoRow('Fiyat', '${_config.jokerPrices[key] ?? 0} altın'),
                  _infoRow('Başlangıç', '${_config.jokerStarts[key] ?? 0}'),
                  _infoRow('Ödüllü reklam tavanı', '${_config.rewardedJokerLimit}'),
                ]),
              ),
          ],
        ),
      ],
    );
  }

  Widget _lives() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric('❤️', '${_config.maxLives}', 'En fazla can'),
            _metric('▶️', '${_config.startLives}', 'Başlangıç can'),
            _metric('⏱️', '${_config.lifeMinutes} dk', 'Yenileme'),
            _metric('🪙', '${_config.lifePrice}', 'Doldurma altını'),
            _metric('🎮', '${_config.lifeCostDefault}', 'Tur maliyeti'),
            _metric('🏃', '${_config.lifeCostMarathon}', 'Maraton maliyeti'),
            _metric('🎁', '${_config.inviteLifeEvery}', 'Davette can eşiği'),
            _metric('📺', '${_config.rewardedLifeLimit}', 'Ödüllü can tavanı'),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Günlük giriş ve seviye atlama canı 0. Günün yarışması ve günün sorusu can harcamaz.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
      ],
    );
  }

  Widget _economy() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _panelCard('EKONOMİ', [
          _infoRow('Başlangıç altını', '500'),
          _infoRow('Altın', 'puan / 10 × mod katsayısı'),
          _infoRow('XP', 'puan / 2'),
          _infoRow('Günün sorusu', '100 altın + 50 XP'),
          _infoRow('Düello', 'kazanan +50, kaybeden +10'),
          _infoRow('Elmas', 'her 5 seviyede 1'),
          _infoRow('Can fiyatı', '${_config.lifePrice} altın'),
          _infoRow('Yarı yarıya', '${_config.jokerPrices['half'] ?? 50} altın'),
          _infoRow('Lig ödülü', '10000 / 5000 / 2500, ilk 100 kişi 500'),
        ]),
      ],
    );
  }

  Widget _packs() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _packCard('Aylık', '29,99 TL'),
            _packCard('6 Aylık', '129,99 TL'),
            _packCard('Yıllık', '199,99 TL', popular: true),
          ],
        ),
        const SizedBox(height: 12),
        const Text('Fiyatlar yalnızca görüntülenir. Play makbuzu olmadan Plus, can, joker veya altın yazılmaz.', style: TextStyle(color: BilgiColors.warning)),
      ],
    );
  }

  Widget _packCard(String title, String price, {bool popular = false}) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: popular ? BilgiColors.primary : const Color(0x0DFFFFFF), width: popular ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (popular) ...[_badge('Popüler', BilgiColors.primary), const SizedBox(height: 8)],
          Text(title, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          Text(price, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _rewards() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          decoration: _cardDeco(),
          child: Column(
            children: [
              _tableHead(const ['Gün', 'Ödül']),
              for (var i = 0; i < 7; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
                  child: Row(children: [Expanded(child: Text('Gün ${i + 1}')), Expanded(child: Text('${_rewardAmount(i)} ${_rewardKind(i)}'))]),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _ads() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _panelCard('REKLAM', [
          _infoRow('Günlük ücretsiz oyun', '${_config.dailyFreeGames}'),
          _infoRow('Oyun öncesi reklam', '${_config.preGameAdSeconds} sn'),
          _infoRow('Yeni kullanıcı reklamsız', '${_config.newUserAdFree}'),
          _infoRow('Banner', _config.bannerEnabled ? 'Açık' : 'Kapalı'),
          _infoRow('Ödüllü altın', '${_config.rewardedGold} • limit ${_config.rewardedGoldLimit}'),
          _infoRow('Joker / can / 2x limiti', '${_config.rewardedJokerLimit} / ${_config.rewardedLifeLimit} / ${_config.rewardedDoubleLimit}'),
          const Text('Reklam dönmezse altın, joker, can veya 2x yazılmaz. Premium zorunlu reklamı atlar.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
        ]),
      ],
    );
  }

  List<BilgiBoardEntry> _leagueStandings(String key, DateTime now) {
    final weekly = key == 'week' || key.endsWith(':week');
    final category = key.startsWith('cat:') ? key.split(':')[1] : null;
    final snap = bilgiLeagueSnapshot(
      users: _leagueUsers,
      scope: category == null ? (weekly ? 'weekly' : 'global') : 'category',
      categoryId: category,
      categoryWeekly: weekly,
      now: now,
      seedIfShort: false,
    );
    return snap.rows;
  }

  Widget _eventEditor() {
    final now = DateTime.now().toUtc();
    final week = bilgiWeekId(now);
    final left = bilgiWeekRemaining(now);
    final open = bilgiOpenCategoryIds(_leagueUsers);
    final choices = <({String id, String label})>[
      (id: 'all', label: 'Genel tüm zamanlar'),
      (id: 'week', label: 'Genel bu hafta'),
      for (final id in open) ...[
        (id: 'cat:$id:all', label: '${bilgiCategoryById(id)?.name ?? id} tüm zamanlar'),
        (id: 'cat:$id:week', label: '${bilgiCategoryById(id)?.name ?? id} bu hafta'),
      ],
    ];
    final selected = choices.any((item) => item.id == _leagueBoard) ? _leagueBoard : 'all';
    final standings = _leagueStandings(selected, now);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _panelCard('LUNO LİGİ', [
          _infoRow('Hafta', week),
          _infoRow('Kalan', '${left.inDays} gün ${left.inHours % 24} saat'),
          _infoRow('Son kapanan hafta', _settledWeek.isEmpty ? '—' : _settledWeek),
          _infoRow('Kademe', 'Bronz 0 • Gümüş 500 • Altın 2000 • Elmas 6000 • Efsane 15000'),
          _infoRow('Genel ödül', '10000 / 5000 / 2500, 4-100 arası 500 altın'),
          _infoRow('Kategori ödülü', '1000 / 500 / 250, 4-10 arası 100 altın'),
          _infoRow('Gerçek oyuncu', '${standings.length}'),
          _infoRow('Oyuncu ekranı', standings.length < bilgiLeagueRealLimit ? 'Örnek sıra' : 'Gerçek liste'),
        ]),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selected,
          items: [for (final item in choices) DropdownMenuItem(value: item.id, child: Text(item.label))],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _leagueBoard = value);
          },
        ),
        const SizedBox(height: 12),
        if (standings.isEmpty)
          const Text('Bu ligde gerçek sıra yok.', style: TextStyle(color: BilgiColors.muted))
        else
          for (var i = 0; i < standings.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _infoRow('${i + 1}. ${standings[i].name}', '${standings[i].score} • ${standings[i].tier}'),
            ),
        const SizedBox(height: 12),
        _panelCard('GÜNÜN SORUSU', [
          _infoRow('Soru', '1'),
          _infoRow('Süre', '30 sn'),
          _infoRow('Ödül', '100 altın + 50 XP'),
        ]),
        const SizedBox(height: 12),
        if (_events.isEmpty)
          const Text('Kayıtlı ek etkinlik yok.', style: TextStyle(color: BilgiColors.muted))
        else
          for (final event in _events)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: _cardDeco(),
              child: Row(
                children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${event['title']}', style: const TextStyle(fontWeight: FontWeight.w700)), Text('${event['body']}', style: const TextStyle(color: BilgiColors.muted, fontSize: 12))])),
                  _iconBtn('🗑️', () async {
                    await _server.deleteEvent('${event['id']}');
                    await _load();
                  }),
                ],
              ),
            ),
        const SizedBox(height: 12),
        _panelCard('YENİ ETKİNLİK', [
          _Fields(
            labels: const ['Başlık', 'Metin'],
            onSave: (values) async {
              if (values[0].trim().isEmpty) return;
              await _server.saveEvent({'title': values[0].trim(), 'body': values[1].trim()});
              await _load();
            },
          ),
        ]),
      ],
    );
  }

  Widget _stats() {
    var correct = 0;
    var asked = 0;
    for (final game in _games) {
      correct += game['correct'] as int? ?? 0;
      final questions = game['questions'];
      if (questions is List) asked += questions.length;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _metric('👥', '${_users.length}', 'Kullanıcı'),
            _metric('🎮', '${_games.length}', 'Oyun'),
            _metric('✅', asked == 0 ? '—' : '${(correct / asked * 100).toStringAsFixed(0)}%', 'Doğru oranı'),
            _metric('💰', '—', 'Gelir'),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 13))),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _general() {
    final zone = DateTime.now().timeZoneName;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _panelCard(
                'UYGULAMA BİLGİLERİ',
                [
                  _labeledField('Uygulama Adı', _appName),
                  const SizedBox(height: 12),
                  const Text('Versiyon', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: const Color(0x2215132A), borderRadius: BorderRadius.circular(12)),
                    child: const Text(gameVersionCode, style: TextStyle(color: Colors.white70)),
                  ),
                  const SizedBox(height: 12),
                  _labeledField('Destek E-posta', _supportMail, hint: 'destek@lunobilgi.com'),
                ],
              ),
              const SizedBox(height: 16),
              _panelCard(
                'SİSTEM DURUMU',
                [
                  _toggleRow('Bakım Modu', 'Açıkken Bilgi oyunu bakım sayfasını gösterir. Sayaç yok.', _config.maintenance, (value) {
                    setState(() => _note = '');
                    _config = BilgiConfig.fromMap({..._config.toMap(), 'maintenance': value});
                  }),
                  _toggleRow('Yeni Kayıtlar', 'Kapalıysa yeni Bilgi hesabı açılamaz. Mevcut girişler çalışır.', _config.registrationsOpen, (value) {
                    _config = BilgiConfig.fromMap({..._config.toMap(), 'registrationsOpen': value});
                    setState(() {});
                  }),
                  _toggleRow('Bildirimler', 'Yalnızca yerel Bilgi bayrağı. League bildirimi veya sesi değişmez.', _config.notificationsEnabled, (value) {
                    _config = BilgiConfig.fromMap({..._config.toMap(), 'notificationsEnabled': value});
                    setState(() {});
                  }),
                ],
              ),
              const SizedBox(height: 16),
              _panelCard(
                'DİL VE BÖLGE',
                [
                  const Text('Varsayılan Dil', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  DropdownButton<String>(
                    value: const {'tr', 'en', 'de'}.contains(_config.uiLocale) ? _config.uiLocale : 'tr',
                    dropdownColor: BilgiColors.card,
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _config = BilgiConfig.fromMap({..._config.toMap(), 'uiLocale': value});
                        if (value != 'tr') {
                          _note = 'Kayıt tutulur; canlı arayüz Türkçe kalır.';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Saat dilimi', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Text(
                    'Cihaz saati ($zone). Hafta kimliği ${DateKeys.weekId()}.',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _saveGeneral,
                  child: const Text('💾 Kaydet'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _saveGeneral() async {
    await _patch((map) {
      map['appName'] = _appName.text.trim().isEmpty ? 'Luno Bilgi' : _appName.text.trim();
      map['supportEmail'] = _supportMail.text.trim();
      map['maintenance'] = _config.maintenance;
      map['registrationsOpen'] = _config.registrationsOpen;
      map['notificationsEnabled'] = _config.notificationsEnabled;
      map['uiLocale'] = _config.uiLocale;
    });
    setState(() => _note = 'Bilgi ayarları kaydedildi.');
  }

  Widget _panelCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(bilgiRadius)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(color: BilgiColors.muted, fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: _fieldDeco(hint),
        ),
      ],
    );
  }

  InputDecoration _fieldDeco([String? hint]) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: BilgiColors.muted),
      filled: true,
      fillColor: const Color(0x2215132A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
  }

  Widget _toggleRow(String title, String hint, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(hint, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: BilgiColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _admins() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Container(
          decoration: _cardDeco(),
          child: Column(
            children: [
              _tableHead(const ['E-posta']),
              if (_staff.isEmpty)
                const Padding(padding: EdgeInsets.all(20), child: Text('Yönetici yok.', style: TextStyle(color: BilgiColors.muted)))
              else
                for (final row in _staff)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
                    child: Text('${row['email']}', style: const TextStyle(color: Colors.white)),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _panelCard('YÖNETİCİ EKLE', [
          _Fields(
            labels: const ['E-posta'],
            onSave: (values) async {
              await _server.saveStaff(values[0]);
              await _load();
            },
          ),
        ]),
      ],
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: BilgiColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      );

  Widget _select(String value, List<(String, String)> items, ValueChanged<String> onChanged) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 240),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x1AFFFFFF))),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((item) => item.$1 == value) ? value : items.first.$1,
          isExpanded: true,
          dropdownColor: BilgiColors.card,
          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          items: [for (final item in items) DropdownMenuItem(value: item.$1, child: Text(item.$2, overflow: TextOverflow.ellipsis))],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }

  Widget _tableHead(List<String> labels) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(color: Color(0xFF121022), borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      child: Row(
        children: [for (final label in labels) Expanded(child: Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.6)))],
      ),
    );
  }

  Widget _primary(String text, VoidCallback onTap) => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary, foregroundColor: Colors.white, minimumSize: const Size(0, 40)),
        onPressed: onTap,
        child: Text(text),
      );

  Widget _ghost(String text, VoidCallback onTap) => OutlinedButton(
        style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x33FFFFFF)), minimumSize: const Size(0, 40)),
        onPressed: onTap,
        child: Text(text),
      );

  Widget _solid(String text, Color bg, Color fg, VoidCallback onTap) => FilledButton(
        style: FilledButton.styleFrom(backgroundColor: bg, foregroundColor: fg, minimumSize: const Size(0, 36)),
        onPressed: onTap,
        child: Text(text),
      );

  Widget _iconBtn(String emoji, VoidCallback onTap) => InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(4), child: Text(emoji, style: const TextStyle(fontSize: 14))));

  /// Fixed-size row actions so approve/reject hit targets do not overlap.
  Widget _rowActionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      visualDensity: VisualDensity.compact,
      splashRadius: 18,
    );
  }

  Widget _pageBtn(String text, VoidCallback? onTap, bool active) => Padding(
        padding: const EdgeInsets.only(left: 6),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: active ? BilgiColors.primary : BilgiColors.bg, borderRadius: BorderRadius.circular(8)),
            child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ),
      );

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
      );

  Widget _diffBadge(String difficulty) => _badge(_diffName(difficulty), switch (difficulty) { 'orta' => BilgiColors.warning, 'zor' => BilgiColors.error, 'efsane' => BilgiColors.info, _ => BilgiColors.secondary });

  String _diffName(String difficulty) => switch (difficulty) { 'kolay' => 'Kolay', 'orta' => 'Orta', 'zor' => 'Zor', 'efsane' => 'Efsane', _ => difficulty };

  Widget _statusBadge(String status) {
    final color = switch (status) { 'approved' => BilgiColors.secondary, 'rejected' => BilgiColors.error, 'draft' => BilgiColors.info, _ => BilgiColors.warning };
    final label = switch (status) { 'approved' => 'Onaylı', 'rejected' => 'Reddedildi', 'draft' => 'Taslak', _ => 'Bekliyor' };
    return _badge(label, color);
  }

  String _subLabel(BilgiQuestion question) {
    final category = _categories.where((item) => item.id == question.categoryId).firstOrNull ?? bilgiCategoryById(question.categoryId);
    if (category == null) return '—';
    for (final tag in question.tags) {
      if (category.subs.contains(tag)) return tag;
    }
    return '—';
  }

  String _catLabel(String id) {
    final category = _categories.where((item) => item.id == id).firstOrNull ?? bilgiCategoryById(id);
    if (category == null) return id;
    return '${category.emoji} ${category.name}';
  }

  String _trInt(int value) {
    final text = '$value';
    final out = StringBuffer();
    for (var i = 0; i < text.length; i++) {
      if (i > 0 && (text.length - i) % 3 == 0) out.write('.');
      out.write(text[i]);
    }
    return out.toString();
  }

  Widget _metricGrid(bool narrow, List<Widget> cards) {
    Widget row(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: a), const SizedBox(width: 16), Expanded(child: b)],
        );
    if (narrow) {
      return Column(children: [row(cards[0], cards[1]), const SizedBox(height: 16), row(cards[2], cards[3])]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _dashMetric(String emoji, String value, String label, ({String text, bool up})? change) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SizedBox(
            height: 16,
            child: change == null
                ? null
                : Text(
                    change.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: change.text.contains('onay') ? BilgiColors.warning : (change.up ? BilgiColors.secondary : BilgiColors.error),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dashSplit(bool stacked, Widget left, Widget right) {
    if (stacked) {
      return Column(children: [left, const SizedBox(height: 16), right]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: left),
        const SizedBox(width: 16),
        Expanded(child: right),
      ],
    );
  }

  Widget _quickGrid(List<Widget> buttons) {
    return Column(
      children: [
        for (var i = 0; i < buttons.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: buttons[i]),
              const SizedBox(width: 10),
              Expanded(child: i + 1 < buttons.length ? buttons[i + 1] : const SizedBox(height: 72)),
            ],
          ),
        ],
      ],
    );
  }

  Widget _dashPanel({required String title, String? action, VoidCallback? onAction, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800))),
              if (action != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(foregroundColor: BilgiColors.primary, padding: EdgeInsets.zero, minimumSize: const Size(0, 32), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: Text(action, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _dashList(String emoji, String title, String hint, String? badge, Color color, {bool last = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: Color(0x0DFFFFFF)))),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(10)),
            child: Text(emoji, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                Text(hint, style: const TextStyle(color: BilgiColors.muted, fontSize: 11)),
              ],
            ),
          ),
          if (badge != null) _badge(badge, color),
        ],
      ),
    );
  }

  Widget _dashQuick(String emoji, String label, VoidCallback onTap) {
    return SizedBox(
      height: 72,
      width: double.infinity,
      child: Material(
        color: BilgiColors.bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x0DFFFFFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20, height: 1)),
                const SizedBox(height: 6),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, height: 1.1)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashTableHead(List<String> labels) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(child: Text(label.toUpperCase(), style: const TextStyle(color: BilgiColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1))),
        ],
      ),
    );
  }

  Widget _dashCategoryRow(({String label, int questions, int plays, int correct, int asked}) row) {
    final rate = row.asked == 0 ? null : (row.correct / row.asked * 100).round();
    final color = rate == null
        ? BilgiColors.muted
        : rate >= 70
            ? BilgiColors.secondary
            : rate >= 60
                ? BilgiColors.warning
                : BilgiColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
      child: Row(
        children: [
          Expanded(child: Text(row.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13))),
          Expanded(child: Text('${row.questions}', style: const TextStyle(fontSize: 13))),
          Expanded(child: Text('${row.plays}', style: const TextStyle(fontSize: 13))),
          Expanded(child: Align(alignment: Alignment.centerLeft, child: rate == null ? const Text('—', style: TextStyle(color: BilgiColors.muted)) : _badge('%$rate', color))),
        ],
      ),
    );
  }

  Widget _metric(String emoji, String value, String label) => Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco(),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  Text(label, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _QuestionDraft {
  const _QuestionDraft({
    required this.text,
    required this.options,
    required this.correct,
    required this.categoryId,
    required this.difficulty,
    required this.explanation,
    this.hint = '',
    required this.tags,
    required this.asDraft,
    required this.status,
    this.translations = const {},
    this.reviewed = false,
  });

  final String text;
  final List<String> options;
  final int correct;
  final String categoryId;
  final String difficulty;
  final String explanation;
  final String hint;
  final List<String> tags;
  final bool asDraft;
  final String status;
  final Map<String, BilgiTranslation> translations;
  final bool reviewed;
}

class _QuestionForm extends StatefulWidget {
  const _QuestionForm({
    super.key,
    required this.categories,
    required this.knownTags,
    required this.onSave,
    required this.onCancel,
    this.initial,
    this.rejectReason = '',
    this.onReview,
  });

  final List<BilgiCategory> categories;
  final List<String> knownTags;
  final Future<void> Function(_QuestionDraft draft) onSave;
  final VoidCallback onCancel;
  final BilgiQuestionFormData? initial;
  final String rejectReason;
  final Future<({String? error, String difficulty, String status, String rejectReason, String verdict})?> Function()? onReview;

  @override
  State<_QuestionForm> createState() => _QuestionFormState();
}

class _QuestionFormState extends State<_QuestionForm> {
  late final _text = TextEditingController(text: widget.initial?.text ?? '');
  late final _options = [
    for (var i = 0; i < 4; i++)
      TextEditingController(text: widget.initial != null && i < widget.initial!.options.length ? widget.initial!.options[i] : ''),
  ];
  late final _explanation = TextEditingController(text: widget.initial?.explanation ?? '');
  late final _hint = TextEditingController(text: widget.initial?.hint ?? '');
  final _newTag = TextEditingController();
  late var _correct = widget.initial?.correct ?? -1;
  late var _category = widget.initial?.categoryId ?? '';
  late var _sub = widget.initial?.subcategory ?? '';
  late var _difficulty = widget.initial?.difficulty ?? 'kolay';
  late var _status = widget.initial?.status ?? '';
  late var _reviewed = widget.initial?.reviewed ?? false;
  var _addingTag = false;
  var _busy = false;
  late final _picked = <String>{...?widget.initial?.tags};
  var _lang = 'tr';
  var _translating = false;
  var _translateNote = '';
  var _reviewing = false;
  late var _shownReason = widget.rejectReason;
  late final _bag = <String, BilgiTranslation>{
    ...?widget.initial?.translations,
    'tr': BilgiTranslation(
      text: widget.initial?.text ?? '',
      options: [
        for (var i = 0; i < 4; i++)
          widget.initial != null && i < widget.initial!.options.length ? widget.initial!.options[i] : '',
      ],
      explanation: widget.initial?.explanation ?? '',
      hint: widget.initial?.hint ?? '',
    ),
  };

  @override
  void dispose() {
    _text.dispose();
    for (final field in _options) {
      field.dispose();
    }
    _explanation.dispose();
    _hint.dispose();
    _newTag.dispose();
    super.dispose();
  }

  BilgiCategory? get _cat => widget.categories.where((category) => category.id == _category).firstOrNull ?? bilgiCategoryById(_category);

  String get _seconds => switch (_difficulty) { 'orta' => '15 saniye', 'zor' => '12 saniye', 'efsane' => '10 saniye', _ => '20 saniye' };

  bool _langFilled(String id) {
    final row = id == _lang
        ? BilgiTranslation(
            text: _text.text.trim(),
            options: [for (final field in _options) field.text.trim()],
            explanation: _explanation.text.trim(),
            hint: _hint.text.trim(),
          )
        : _bag[id];
    if (row == null) return false;
    if (!bilgiLanguageFieldsReady(row.text, row.options, row.explanation)) return false;
    if (id == 'tr') return true;
    final sourceHint = _lang == 'tr' ? _hint.text.trim() : (_bag['tr']?.hint.trim() ?? '');
    return bilgiTranslatedHintReady(sourceHint, row.hint);
  }

  void _storeLang() {
    _bag[_lang] = BilgiTranslation(
      text: _text.text.trim(),
      options: [for (final field in _options) field.text.trim()],
      explanation: _explanation.text.trim(),
      hint: _hint.text.trim(),
    );
  }

  Future<void> _reviewSaved() async {
    final review = widget.onReview;
    if (review == null || _reviewing || _busy) return;
    setState(() {
      _reviewing = true;
      _translateNote = 'Kontrol ediliyor...';
    });
    final result = await review();
    if (!mounted) return;
    if (result == null || result.error != null) {
      setState(() {
        _reviewing = false;
        _translateNote = result?.error ?? 'Kontrol yapılamadı.';
      });
      return;
    }
    setState(() {
      _reviewing = false;
      _difficulty = result.difficulty;
      _status = result.status;
      _reviewed = true;
      _shownReason = result.rejectReason;
      _translateNote = result.verdict == 'reject'
          ? 'Reddedildi: ${result.rejectReason}'
          : 'Kontrol edildi. Zorluk: ${_reviewDiff(result.difficulty)}';
    });
  }

  String _reviewDiff(String difficulty) => switch (difficulty) {
        'kolay' => 'Kolay',
        'orta' => 'Orta',
        'zor' => 'Zor',
        'efsane' => 'Efsane',
        _ => difficulty,
      };

  Future<void> _translateAll() async {
    if (_translating || _busy) return;
    _storeLang();
    final turkish = _bag['tr'];
    if (turkish == null || !bilgiLanguageFieldsReady(turkish.text, turkish.options, turkish.explanation)) {
      setState(() => _translateNote = 'Türkçe soru, dört şık ve açıklama dolu olmalı.');
      return;
    }
    setState(() {
      _translating = true;
      _translateNote = 'Çevriliyor...';
    });
    final targets = bilgiExtraLocales(_publishedLocales.toList());
    if (targets.isEmpty) {
      setState(() {
        _translating = false;
        _translateNote = 'Bu kategoride başka yayın dili yok.';
      });
      return;
    }
    final result = await BilgiQuestionApi.translateQuestion(
      sl<ApiSession>().adminToken ?? '',
      text: turkish.text,
      options: turkish.options,
      explanation: turkish.explanation,
      hint: turkish.hint,
      locales: targets,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _translating = false;
        _translateNote = result.error!;
      });
      return;
    }
    _bag.addAll(result.translations);
    if (_lang != 'tr') {
      final row = _bag[_lang];
      _text.text = row?.text ?? '';
      for (var i = 0; i < 4; i++) {
        _options[i].text = row != null && i < row.options.length ? row.options[i] : '';
      }
      _explanation.text = row?.explanation ?? '';
      _hint.text = row?.hint ?? '';
    }
    if (_category.isEmpty || _sub.trim().isEmpty) {
      setState(() {
        _translating = false;
        _translateNote = 'Tercüme yazıldı. Kaydetmek için alt kategori seç.';
      });
      return;
    }
    setState(() => _translateNote = 'Tercüme kaydediliyor...');
    final saved = await _submit(false);
    if (!mounted) return;
    setState(() {
      _translating = false;
      _translateNote = saved ? 'Tercüme kaydedildi.' : 'Tercüme geldi, kayıt tamamlanmadı.';
    });
  }

  Set<String> get _publishedLocales {
    final category = _cat;
    if (category == null) return {'tr'};
    return category.publishLocales.toSet();
  }

  void _showLang(String lang) {
    if (!_publishedLocales.contains(lang)) return;
    _storeLang();
    final row = _bag[lang];
    _text.text = row?.text ?? '';
    for (var i = 0; i < 4; i++) {
      _options[i].text = row != null && i < row.options.length ? row.options[i] : '';
    }
    _explanation.text = row?.explanation ?? '';
    _hint.text = row?.hint ?? '';
    setState(() => _lang = lang);
  }

  Future<bool> _submit(bool draft) async {
    _storeLang();
    final turkish = _bag['tr'];
    final text = turkish?.text.trim() ?? '';
    final options = turkish?.options ?? const <String>[];
    if (text.isEmpty || options.any((option) => option.isEmpty) || _correct < 0 || _category.isEmpty) return false;
    final category = _cat;
    final sub = _sub.trim();
    if (category == null || !category.subs.contains(sub)) return false;
    final tags = {..._picked, sub};
    setState(() => _busy = true);
    try {
      await widget.onSave(
        _QuestionDraft(
          text: text,
          options: options,
          correct: _correct,
          categoryId: _category,
          difficulty: _difficulty,
          explanation: turkish?.explanation ?? '',
          hint: turkish?.hint ?? '',
          tags: tags.toList(),
          asDraft: draft,
          status: draft ? 'draft' : (_status.isEmpty ? 'pending' : _status),
          reviewed: _reviewed,
          translations: {
            for (final entry in _bag.entries)
              if (entry.key != 'tr' &&
                  _publishedLocales.contains(entry.key) &&
                  entry.value.text.isNotEmpty &&
                  entry.value.options.every((item) => item.isNotEmpty) &&
                  bilgiTranslatedHintReady(turkish?.hint ?? '', entry.value.hint))
                entry.key: entry.value,
          },
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _busy = false);
      return false;
    }
    if (mounted) setState(() => _busy = false);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final turkish = _lang == 'tr'
        ? BilgiTranslation(
            text: _text.text.trim(),
            options: [for (final field in _options) field.text.trim()],
            explanation: _explanation.text.trim(),
            hint: _hint.text.trim(),
          )
        : _bag['tr'];
    final ready = (turkish?.text.isNotEmpty ?? false) &&
        (turkish?.options.every((item) => item.isNotEmpty) ?? false) &&
        _correct >= 0 &&
        _category.isNotEmpty &&
        (_cat?.subs.contains(_sub) ?? false);
    final subs = _cat?.subs ?? const <String>[];
    final optionIssue = bilgiSimilarOptionsIssue([for (final field in _options) field.text]);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _BilgiLangTabs(
                        selected: _publishedLocales.contains(_lang) ? _lang : 'tr',
                        onSelect: _showLang,
                        wrap: true,
                        filled: _langFilled,
                        published: _publishedLocales,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _translateAllButton(
                      busy: _translating,
                      onPressed: bilgiExtraLocales(_publishedLocales.toList()).isEmpty ? null : _translateAll,
                    ),
                    const SizedBox(width: 8),
                    _kontrolButton(
                      busy: _reviewing,
                      onPressed: widget.onReview == null || widget.initial == null || widget.initial!.id.isEmpty ? null : _reviewSaved,
                    ),
                  ],
                ),
                if (_translateNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_translateNote, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                _card(_lang == 'tr' ? '1. Soru Metni' : '1. Soru Metni · ${GameLocale.resolve(_lang).nativeName}', [
                  if (widget.categories.any((category) => category.id == _category && bilgiSpecialEventCategory(category))) ...[
                    _specialEventTag(),
                    const SizedBox(height: 8),
                  ],
                  if (_shownReason.trim().isNotEmpty) ...[
                    Text(_shownReason.trim(), style: const TextStyle(color: BilgiColors.error, fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                  ],
                  _label('Soru'),
                  TextField(
                    controller: _text,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _input(hint: 'Soruyu buraya yazın...'),
                  ),
                ]),
                _card('2. Şıklar (Doğru cevabı işaretleyin)', [
                  for (var i = 0; i < 4; i++) _optionRow(i),
                  if (optionIssue != null) ...[
                    const SizedBox(height: 4),
                    Text(optionIssue, style: const TextStyle(color: BilgiColors.error, fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ]),
                _card('3. Kategori ve Zorluk', [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _drop('Ana Kategori', _category, [for (final c in widget.categories) (c.id, '${c.emoji} ${c.name}')], (v) {
                        final next = widget.categories.where((category) => category.id == v).firstOrNull;
                        final allowed = next?.publishLocales.toSet() ?? {'tr'};
                        if (!allowed.contains(_lang)) _showLang('tr');
                        setState(() {
                          _category = v;
                          _sub = '';
                        });
                      })),
                      const SizedBox(width: 16),
                      Expanded(child: _drop('Alt Kategori', _sub, [for (final name in subs) (name, name)], (v) => setState(() => _sub = v), enabled: subs.isNotEmpty, emptyHint: _cat == null ? 'Önce ana kategori' : 'Bu kategoride alt kategori yok')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _drop('Zorluk', _difficulty, const [('kolay', 'Kolay'), ('orta', 'Orta'), ('zor', 'Zor'), ('efsane', 'Efsane')], (v) => setState(() => _difficulty = v))),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _drop(
                          'Kontrol edildi',
                          _reviewed ? 'yes' : 'no',
                          const [('yes', 'Evet'), ('no', 'Hayır')],
                          (v) => setState(() => _reviewed = v == 'yes'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      if (widget.initial != null) ...[
                        Expanded(child: _drop('Durum', _status, const [('pending', 'Bekliyor'), ('approved', 'Onaylı'), ('draft', 'Taslak'), ('rejected', 'Reddedildi')], (v) => setState(() => _status = v))),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _label('Soru Süresi'),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0x1AFFFFFF))),
                              child: Text(_seconds, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ]),
                _card('4. Etiketler', [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in {...widget.knownTags, ..._picked})
                        _chip(tag, active: _picked.contains(tag), onTap: () => setState(() => _picked.contains(tag) ? _picked.remove(tag) : _picked.add(tag))),
                      _chip('+ Etiket Ekle', onTap: () => setState(() => _addingTag = !_addingTag)),
                    ],
                  ),
                  if (_addingTag) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _newTag,
                      style: const TextStyle(color: Colors.white),
                      decoration: _input(hint: 'Etiket'),
                      onSubmitted: _addTag,
                    ),
                  ],
                ]),
                _card('5. Açıklama (Opsiyonel)', [
                  _label('Cevap açıklaması'),
                  TextField(
                    controller: _explanation,
                    minLines: 3,
                    maxLines: 6,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _input(hint: 'Doğru cevap sonrası gösterilecek açıklama...'),
                  ),
                ]),
                _card('6. İpucu', [
                  _label('Joker ipucu'),
                  TextField(
                    controller: _hint,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: _input(hint: 'Doğru şıkkı söylemeden daraltan kısa ipucu...'),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _barBtn('İptal', filled: false, onTap: _busy ? null : widget.onCancel),
                    const SizedBox(width: 12),
                    _barBtn('Taslak Kaydet', filled: false, onTap: _busy || !ready ? null : () => _submit(true)),
                    const SizedBox(width: 12),
                    _barBtn('Soruyu Kaydet', filled: true, onTap: _busy || !ready ? null : () => _submit(false)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty) return;
    setState(() {
      _picked.add(tag);
      _newTag.clear();
      _addingTag = false;
    });
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0x0DFFFFFF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(color: BilgiColors.muted, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
      );

  InputDecoration _input({String? hint}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: BilgiColors.muted, fontSize: 14),
        filled: true,
        fillColor: BilgiColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: BilgiColors.primary)),
      );

  Widget _optionRow(int index) {
    final letter = ['A', 'B', 'C', 'D'][index];
    final chosen = _correct == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: BilgiColors.bg, borderRadius: BorderRadius.circular(10)),
            child: Text(letter, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _options[index],
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _input(hint: '$letter şıkkı'),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: () => setState(() => _correct = index),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: chosen ? BilgiColors.secondary : BilgiColors.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: chosen ? BilgiColors.secondary : const Color(0x1AFFFFFF), width: 2),
              ),
              child: Icon(chosen ? Icons.circle : Icons.circle_outlined, size: 16, color: chosen ? BilgiColors.bg : Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drop(String label, String value, List<(String, String)> items, ValueChanged<String> onChanged, {bool enabled = true, String emptyHint = 'Önce ana kategori'}) {
    final current = items.any((item) => item.$1 == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        DropdownButtonFormField<String>(
          key: ValueKey('$label-${current ?? ''}-${items.length}'),
          initialValue: current,
          isExpanded: true,
          hint: Text(enabled ? 'Seç' : emptyHint, style: const TextStyle(color: BilgiColors.muted, fontSize: 14)),
          dropdownColor: BilgiColors.card,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: _input(),
          items: [for (final item in items) DropdownMenuItem(value: item.$1, child: Text(item.$2, overflow: TextOverflow.ellipsis))],
          onChanged: !enabled
              ? null
              : (next) {
                  if (next != null) onChanged(next);
                },
        ),
      ],
    );
  }

  Widget _chip(String label, {bool active = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? BilgiColors.primary : BilgiColors.bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? BilgiColors.primary : const Color(0x1AFFFFFF)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _barBtn(String label, {required bool filled, required VoidCallback? onTap}) {
    final child = Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14));
    if (filled) {
      return FilledButton(
        style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary, foregroundColor: Colors.white, disabledBackgroundColor: const Color(0xFF3A3458), minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 24)),
        onPressed: onTap,
        child: child,
      );
    }
    return OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x1AFFFFFF)), minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 24)),
      onPressed: onTap,
      child: child,
    );
  }
}

class _SearchCombo extends StatefulWidget {
  const _SearchCombo({
    required this.hint,
    required this.selected,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.clearable = true,
  });

  final String hint;
  final String selected;
  final List<(String, String)> options;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool clearable;

  @override
  State<_SearchCombo> createState() => _SearchComboState();
}

class _SearchComboState extends State<_SearchCombo> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  var _picked = '';
  var _open = false;

  @override
  void initState() {
    super.initState();
    _picked = widget.selected;
    _text.text = _labelOf(_picked);
    _focus.addListener(() {
      if (_focus.hasFocus && widget.enabled) setState(() => _open = true);
    });
  }

  @override
  void didUpdateWidget(covariant _SearchCombo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected != widget.selected) {
      _picked = widget.selected;
      _text.text = _labelOf(_picked);
      _open = false;
      if (widget.selected.isEmpty) _focus.unfocus();
    }
    if (!widget.enabled) _open = false;
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _labelOf(String id) {
    for (final option in widget.options) {
      if (option.$1 == id) return option.$2;
    }
    return '';
  }

  List<(String, String)> get _matches {
    final raw = _text.text.trim();
    final selected = _labelOf(_picked);
    final query = _fold(raw);
    final searching = raw.isNotEmpty && raw != selected && query.length >= 3;
    if (!searching) return widget.options;
    return [
      for (final option in widget.options)
        if (_fold(option.$2).contains(query)) option,
    ];
  }

  void _choose((String, String) option) {
    setState(() {
      _picked = option.$1;
      _text.text = option.$2;
      _open = false;
    });
    _focus.unfocus();
    widget.onChanged(option.$1);
  }

  void _clear() {
    setState(() {
      _picked = '';
      _text.clear();
      _open = widget.enabled;
    });
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final listOpen = widget.enabled && _open;
    return SizedBox(
      width: 240,
      child: TapRegion(
        onTapOutside: (_) {
          if (!_open) return;
          setState(() {
            _open = false;
            _text.text = _labelOf(_picked);
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _text,
              focusNode: _focus,
              enabled: widget.enabled,
              onChanged: (_) => setState(() => _open = true),
              onTap: () {
                if (!widget.enabled) return;
                _text.selection = TextSelection(baseOffset: 0, extentOffset: _text.text.length);
                setState(() => _open = true);
              },
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                isDense: true,
                hintText: widget.hint,
                hintStyle: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                filled: true,
                fillColor: BilgiColors.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                suffixIconConstraints: const BoxConstraints(maxWidth: 36, maxHeight: 36),
                suffixIcon: widget.clearable && _picked.isNotEmpty
                    ? IconButton(
                        onPressed: widget.enabled ? _clear : null,
                        icon: const Icon(Icons.close, size: 16, color: BilgiColors.muted),
                      )
                    : const Icon(Icons.arrow_drop_down, color: BilgiColors.muted, size: 24),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0x1AFFFFFF))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: BilgiColors.primary)),
              ),
            ),
            if (listOpen)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  color: const Color(0xFF241F3D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  shrinkWrap: true,
                  children: [
                    if (matches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: Text('Sonuç yok', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
                      )
                    else
                      for (final option in matches)
                        Material(
                          color: option.$1 == _picked ? const Color(0x336C3CE9) : Colors.transparent,
                          child: InkWell(
                            onTap: () => _choose(option),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Text(option.$2, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _fold(String value) {
  return value.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase().replaceAll('ı', 'i').replaceAll('ö', 'o').replaceAll('ü', 'u').replaceAll('ş', 's').replaceAll('ğ', 'g').replaceAll('ç', 'c');
}

const bilgiBankPageSize = 20;

const bilgiBankPageSizes = <int>[20, 50, 100, 200];

/// Soru bankası listesindeki doğru şık: 0=A, 1=B, 2=C, 3=D. İndeks dışındaysa boş.
String bilgiCorrectChoiceLetter(BilgiQuestion question) {
  final index = question.correct;
  if (index < 0 || index > 3) return '';
  return const ['A', 'B', 'C', 'D'][index];
}

String _bankMatchKey(String value) => _fold(value).replaceAll(RegExp(r'\s+'), ' ').trim();

/// Soru bankası süzgeci.
/// Üç harften kısa arama satır düşürmez.
/// Seçili kategoriye ait olmayan alt kategori, o kategorideki satırları silmez.
/// Geçerli alt kategori başka alt kategorideki soruları göstermez.
List<BilgiQuestion> bilgiFilterBankQuestions(
  Iterable<BilgiQuestion> questions, {
  String categoryId = '',
  String subcategory = '',
  String difficulty = '',
  String status = '',
  String translation = '',
  String reviewed = '',
  String detail = '',
  String search = '',
  Iterable<String> categorySubs = const [],
  bool Function(BilgiQuestion question)? isTranslated,
}) {
  final category = categoryId.trim();
  final wantedSub = subcategory.trim();
  final wantedDifficulty = difficulty.trim();
  final wantedStatus = status.trim();
  final knownSubs = [for (final name in categorySubs) if (name.trim().isNotEmpty) name.trim()];
  final wantedSubKey = _bankMatchKey(wantedSub);
  final subApplies = wantedSub.isNotEmpty &&
      (knownSubs.isEmpty || knownSubs.any((name) => _bankMatchKey(name) == wantedSubKey));
  final query = search.trim();
  final searching = query.length >= 3;
  final foldedQuery = _fold(query);
  return [
    for (final question in questions)
      if (_bilgiBankVisible(
        question,
        category: category,
        subApplies: subApplies,
        wantedSubKey: wantedSubKey,
        difficulty: wantedDifficulty,
        status: wantedStatus,
        translation: translation.trim(),
        reviewed: reviewed.trim(),
        detail: detail.trim(),
        searching: searching,
        foldedQuery: foldedQuery,
        isTranslated: isTranslated,
      ))
        question,
  ];
}

bool _bilgiBankVisible(
  BilgiQuestion question, {
  required String category,
  required bool subApplies,
  required String wantedSubKey,
  required String difficulty,
  required String status,
  required String translation,
  required String reviewed,
  required String detail,
  required bool searching,
  required String foldedQuery,
  required bool Function(BilgiQuestion question)? isTranslated,
}) {
  if (category.isNotEmpty && question.categoryId != category) return false;
  if (subApplies && !question.tags.any((tag) => _bankMatchKey(tag) == wantedSubKey)) return false;
  if (difficulty.isNotEmpty && question.difficulty != difficulty) return false;
  if (status.isNotEmpty && question.status.trim() != status) return false;
  final translated = isTranslated?.call(question) ?? false;
  if (translation == 'ready' && !translated) return false;
  if (translation == 'missing' && translated) return false;
  if (!bilgiBankDetailVisible(detail, question.explanation, question.hint)) return false;
  if (reviewed == 'yes' && !question.reviewed) return false;
  if (reviewed == 'no' && question.reviewed) return false;
  if (!searching) return true;
  if (_fold(question.text).contains(foldedQuery)) return true;
  for (final option in question.options) {
    if (_fold(option).contains(foldedQuery)) return true;
  }
  return false;
}

/// Filtered rows are paged. A page past the end still shows the filtered rows.
({List<T> slice, int page, int pages, int from, int to, int total}) bilgiBankWindow<T>(
  List<T> rows,
  int pageIndex, {
  int pageSize = bilgiBankPageSize,
}) {
  final pages = rows.isEmpty ? 1 : (rows.length / pageSize).ceil();
  final page = pageIndex.clamp(0, pages - 1);
  final start = page * pageSize;
  final slice = rows.skip(start).take(pageSize).toList();
  return (
    slice: slice,
    page: page,
    pages: pages,
    from: rows.isEmpty ? 0 : start + 1,
    to: rows.isEmpty ? 0 : start + slice.length,
    total: rows.length,
  );
}

class _Fields extends StatefulWidget {
  const _Fields({required this.labels, required this.onSave, this.lines = 1});

  final List<String> labels;
  final Future<void> Function(List<String> values) onSave;
  final int lines;

  @override
  State<_Fields> createState() => _FieldsState();
}

class _FieldsState extends State<_Fields> {
  late final List<TextEditingController> _fields = [for (final _ in widget.labels) TextEditingController()];

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.labels.length; i++) ...[
          Text(widget.labels[i], style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
          const SizedBox(height: 6),
          TextField(
            controller: _fields[i],
            minLines: widget.lines,
            maxLines: widget.lines,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: BilgiColors.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary, minimumSize: const Size(0, 40)),
            onPressed: () => widget.onSave([for (final field in _fields) field.text]),
            child: const Text('Kaydet'),
          ),
        ),
      ],
    );
  }
}

const _bilgiFlags = <String, String>{
  'tr': '🇹🇷',
  'en': '🇬🇧',
  'de': '🇩🇪',
  'es': '🇪🇸',
  'fr': '🇫🇷',
  'it': '🇮🇹',
  'ru': '🇷🇺',
  'nl': '🇳🇱',
  'pt': '🇵🇹',
  'pl': '🇵🇱',
};

class _AskCategoryDialog extends StatefulWidget {
  const _AskCategoryDialog({
    required this.title,
    required this.fields,
    required this.emojiField,
    required this.initialGroup,
    required this.groupLabel,
    this.initialLocales,
    this.saveNames,
  });

  final String title;
  final Map<String, TextEditingController> fields;
  final TextEditingController emojiField;
  final String initialGroup;

  /// null: eski kategori, on dil işaretli. Dolu liste: kayıtlı yayın dilleri.
  final List<String>? initialLocales;
  final String Function(String locale, String group) groupLabel;
  final Future<String?> Function(Map<String, String> names)? saveNames;

  @override
  State<_AskCategoryDialog> createState() => _AskCategoryDialogState();
}

class _AskCategoryDialogState extends State<_AskCategoryDialog> {
  var _lang = 'tr';
  late String _picked = widget.initialGroup;
  late final Set<String> _published = {
    ...bilgiPublishLocalesOf(widget.initialLocales),
    'tr',
  };

  List<String> get _locales => [for (final id in bilgiLocaleIds) if (_published.contains(id)) id];

  void _togglePublished(String id) {
    if (id == 'tr') return;
    setState(() {
      if (_published.contains(id)) {
        _published.remove(id);
      } else {
        _published.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: BilgiColors.card,
      constraints: BoxConstraints(maxWidth: _labelDialogWidth(context) + 64),
      title: Text(widget.title),
      content: SizedBox(
        width: _labelDialogWidth(context),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LangNameFields(
                fields: widget.fields,
                published: _published,
                onTogglePublished: _togglePublished,
                saveNames: widget.saveNames,
                onLocaleChanged: (id) => setState(() => _lang = id),
              ),
              TextField(
                controller: widget.emojiField,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Simge'),
              ),
              const SizedBox(height: 12),
              DropdownButton<String>(
                key: ValueKey('group-$_lang'),
                isExpanded: true,
                value: _picked,
                dropdownColor: BilgiColors.card,
                style: const TextStyle(color: Colors.white),
                selectedItemBuilder: (context) => [
                  for (final item in bilgiGroups)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        widget.groupLabel(_lang, item),
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                ],
                items: [
                  for (final item in bilgiGroups)
                    DropdownMenuItem(
                      value: item,
                      child: Text(widget.groupLabel(_lang, item)),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _picked = value);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, (ok: false, group: _picked, locales: _locales)), child: const Text('Vazgeç')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary),
          onPressed: () => Navigator.pop(context, (ok: true, group: _picked, locales: _locales)),
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _LangNameFields extends StatefulWidget {
  const _LangNameFields({
    required this.fields,
    this.published,
    this.onTogglePublished,
    this.saveNames,
    this.onLocaleChanged,
  });

  final Map<String, TextEditingController> fields;
  final Set<String>? published;
  final ValueChanged<String>? onTogglePublished;
  final Future<String?> Function(Map<String, String> names)? saveNames;
  final ValueChanged<String>? onLocaleChanged;

  @override
  State<_LangNameFields> createState() => _LangNameFieldsState();
}

class _LangNameFieldsState extends State<_LangNameFields> {
  var _lang = 'tr';
  var _translating = false;
  var _note = '';

  void _selectLang(String id) {
    widget.onLocaleChanged?.call(id);
    setState(() => _lang = id);
  }

  Future<void> _translate() async {
    if (_translating) return;
    final turkish = widget.fields['tr']?.text.trim() ?? '';
    if (turkish.isEmpty) {
      setState(() => _note = 'Türkçe ad dolu olmalı.');
      return;
    }
    setState(() {
      _translating = true;
      _note = 'Çevriliyor...';
    });
    final targets = bilgiExtraLocales(widget.published?.toList());
    if (targets.isEmpty) {
      setState(() {
        _translating = false;
        _note = 'Çevrilecek yayın dili yok.';
      });
      return;
    }
    final result = await BilgiQuestionApi.translateName(
      sl<ApiSession>().adminToken ?? '',
      turkish,
      locales: targets,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _translating = false;
        _note = result.error!;
      });
      return;
    }
    for (final entry in result.names.entries) {
      widget.fields[entry.key]?.text = entry.value;
    }
    final error = await widget.saveNames?.call(result.names);
    if (!mounted) return;
    setState(() {
      _translating = false;
      _note = error ?? (widget.saveNames == null ? 'Tercüme yazıldı. Kaydedince kalır.' : 'Tercüme kaydedildi.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final field = widget.fields[_lang];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BilgiLangTabs(
                selected: _lang,
                onSelect: _selectLang,
                wrap: true,
                filled: (id) => widget.fields[id]?.text.trim().isNotEmpty ?? false,
                published: widget.published,
                onTogglePublished: widget.onTogglePublished,
              ),
            ),
            const SizedBox(width: 12),
            _translateAllButton(
              busy: _translating,
              onPressed: widget.published != null && bilgiExtraLocales(widget.published!.toList()).isEmpty ? null : _translate,
            ),
          ],
        ),
        if (_note.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(_note, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
        ],
        const SizedBox(height: 12),
        TextField(
          key: ValueKey(_lang),
          controller: field,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(labelText: _lang == 'tr' ? 'Ad' : 'Görünen ad'),
        ),
      ],
    );
  }
}

Widget _kontrolButton({required bool busy, required VoidCallback? onPressed}) {
  return FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: BilgiColors.secondary,
      foregroundColor: BilgiColors.bg,
      minimumSize: const Size(0, 40),
    ),
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: BilgiColors.bg))
        : const Text('Kontrol'),
  );
}

Widget _translateAllButton({required bool busy, required VoidCallback? onPressed}) {
  return FilledButton(
    style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary, minimumSize: const Size(0, 40)),
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Text('Seçili dilleri çevir'),
  );
}

double _labelDialogWidth(BuildContext context) {
  final available = MediaQuery.sizeOf(context).width - 96;
  return available.clamp(720.0, 1280.0);
}

class _BilgiLangTabs extends StatelessWidget {
  const _BilgiLangTabs({
    required this.selected,
    required this.onSelect,
    required this.filled,
    this.wrap = false,
    this.published,
    this.onTogglePublished,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final bool Function(String localeId) filled;
  final bool wrap;
  final Set<String>? published;
  final ValueChanged<String>? onTogglePublished;

  Color _tabColor(String id) {
    final on = published == null || published!.contains(id);
    if (!on) return BilgiColors.muted;
    return filled(id) ? const Color(0xFF3DDC84) : const Color(0xFFFF5C7A);
  }

  @override
  Widget build(BuildContext context) {
    final locked = published != null && onTogglePublished == null;
    final locales = [
      for (final locale in GameLocale.all)
        if (!locked || locale.id == 'tr' || published!.contains(locale.id)) locale,
    ];
    final tabs = [
      for (final locale in locales)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (published != null && !locked)
              Checkbox(
                value: locale.id == 'tr' || published!.contains(locale.id),
                onChanged: locale.id == 'tr' ? null : (_) => onTogglePublished?.call(locale.id),
                activeColor: BilgiColors.secondary,
                side: const BorderSide(color: Colors.white54),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
            Material(
              color: selected == locale.id ? BilgiColors.primary : BilgiColors.bg,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onSelect(locale.id),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '${_bilgiFlags[locale.id] ?? ''}  '),
                        TextSpan(
                          text: locale.nativeName,
                          style: TextStyle(color: _tabColor(locale.id)),
                        ),
                      ],
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
    ];
    if (wrap) return Wrap(spacing: 8, runSpacing: 8, children: tabs);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) Padding(padding: const EdgeInsets.only(right: 8), child: tab),
        ],
      ),
    );
  }
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    const radius = 16.0;
    const dash = 6.0;
    const gap = 5.0;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = (start + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        start += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ContestPaperDialog extends StatefulWidget {
  const _ContestPaperDialog({
    required this.day,
    required this.questions,
    required this.spares,
    required this.editing,
  });

  final String day;
  final List<BilgiQuestion> questions;
  final List<BilgiQuestion> spares;
  final bool editing;

  @override
  State<_ContestPaperDialog> createState() => _ContestPaperDialogState();
}

class _ContestPaperDialogState extends State<_ContestPaperDialog> {
  late List<BilgiQuestion> _questions = [...widget.questions];
  late List<BilgiQuestion> _spares = [...widget.spares];
  var _locale = 'tr';
  var _busy = false;
  var _error = '';

  bool _localeReady(String id) {
    if (id == 'tr') return true;
    bool ready(BilgiQuestion question) {
      final row = question.translations[id];
      if (row == null || row.text.trim().isEmpty) return false;
      return row.options.length == 4 && row.options.every((item) => item.trim().isNotEmpty);
    }

    return _questions.every(ready) && _spares.every(ready);
  }

  Future<void> _edit({required bool spare, int? index}) async {
    final list = spare ? _spares : _questions;
    final current = index == null ? null : list[index];
    final next = await showDialog<BilgiQuestion>(
      context: context,
      builder: (context) => _ContestQuestionDialog(
        day: widget.day,
        question: current,
        index: index ?? list.length,
        editing: widget.editing,
      ),
    );
    if (next == null || !mounted) return;
    setState(() {
      final copy = [...list];
      if (index == null) {
        copy.add(next);
      } else {
        copy[index] = next;
      }
      if (spare) {
        _spares = copy;
      } else {
        _questions = copy;
      }
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = '';
    });
    final loaded = await BilgiContestApi.adminSaveQuestions(
      sl<ApiSession>().adminToken ?? '',
      widget.day,
      _questions,
      spares: _spares,
    );
    if (!mounted) return;
    if (loaded.error != null) {
      setState(() {
        _busy = false;
        _error = loaded.error!;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }

  Widget _card(BilgiQuestion question, String label, {required VoidCallback onEdit, VoidCallback? onRemove}) {
    final translated = _locale == 'tr' ? null : question.translations[_locale];
    final language = GameLocale.resolve(_locale).nativeName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: BilgiColors.card, borderRadius: BorderRadius.circular(12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$label. ${question.difficulty} · ${question.correctLetter}',
              style: const TextStyle(color: BilgiColors.secondary, fontWeight: FontWeight.w800, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text('Türkçe', style: TextStyle(color: BilgiColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            Text(question.text, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 6),
            for (var n = 0; n < question.options.length; n++)
              Text(
                '${['A', 'B', 'C', 'D'][n]}. ${question.options[n]}',
                style: TextStyle(
                  color: n == question.correct ? const Color(0xFF86EFAC) : BilgiColors.muted,
                  fontSize: 13,
                ),
              ),
            if (_locale != 'tr') ...[
              const SizedBox(height: 8),
              Text(language, style: const TextStyle(color: BilgiColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
              if (translated == null || translated.text.trim().isEmpty)
                const Text('Çeviri yok', style: TextStyle(color: BilgiColors.warning, fontSize: 13))
              else ...[
                Text(translated.text, style: const TextStyle(color: Colors.white)),
                const SizedBox(height: 6),
                for (var n = 0; n < translated.options.length && n < 4; n++)
                  Text(
                    '${['A', 'B', 'C', 'D'][n]}. ${translated.options[n]}',
                    style: TextStyle(
                      color: n == question.correct ? const Color(0xFF86EFAC) : BilgiColors.muted,
                      fontSize: 13,
                    ),
                  ),
              ],
            ],
            const SizedBox(height: 6),
            Text(
              'Dil ${1 + question.translations.length}/10',
              style: const TextStyle(color: BilgiColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _dialogGhost(widget.editing ? 'Düzenle' : 'Dilleri gör', onEdit),
                if (onRemove != null) _dialogGhost('Çıkar', onRemove),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: BilgiColors.bg,
      child: SizedBox(
        width: 760,
        height: 720,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.editing ? '${widget.day} düzenle' : widget.day,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 12),
              _BilgiLangTabs(selected: _locale, onSelect: (id) => setState(() => _locale = id), filled: _localeReady),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    _section('Kağıt · ${_questions.length}'),
                    for (var i = 0; i < _questions.length; i++)
                      _card(
                        _questions[i],
                        '${i + 1}',
                        onEdit: () => _edit(spare: false, index: i),
                        onRemove: widget.editing
                            ? () => setState(() => _questions = [..._questions]..removeAt(i))
                            : null,
                      ),
                    _section('Yedekler · ${_spares.length}'),
                    if (_spares.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Text('Yedek yok', style: TextStyle(color: BilgiColors.muted)),
                      ),
                    for (var i = 0; i < _spares.length; i++)
                      _card(
                        _spares[i],
                        'Y${i + 1}',
                        onEdit: () => _edit(spare: true, index: i),
                        onRemove: widget.editing
                            ? () => setState(() => _spares = [..._spares]..removeAt(i))
                            : null,
                      ),
                  ],
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: BilgiColors.warning)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.editing) _dialogGhost('Soru ekle', () => _edit(spare: false)),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
                  if (widget.editing) ...[
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(_busy ? 'Kaydediliyor' : 'Kaydet'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _dialogGhost(String text, VoidCallback onTap) => OutlinedButton(
      style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Color(0x33FFFFFF))),
      onPressed: onTap,
      child: Text(text),
    );

class _ContestQuestionDialog extends StatefulWidget {
  const _ContestQuestionDialog({required this.day, required this.index, this.question, this.editing = true});

  final String day;
  final int index;
  final BilgiQuestion? question;
  final bool editing;

  @override
  State<_ContestQuestionDialog> createState() => _ContestQuestionDialogState();
}

class _ContestQuestionDialogState extends State<_ContestQuestionDialog> {
  final String _locale = 'tr';
  late String _selected = 'tr';
  late int _correct = widget.question?.correct ?? 0;
  late String _difficulty = widget.question?.difficulty ?? 'kolay';
  late final Map<String, TextEditingController> _text = {
    for (final locale in GameLocale.all) locale.id: TextEditingController(text: _storedText(locale.id)),
  };
  late final Map<String, List<TextEditingController>> _options = {
    for (final locale in GameLocale.all)
      locale.id: [
        for (var i = 0; i < 4; i++) TextEditingController(text: _storedOption(locale.id, i)),
      ],
  };
  late final Map<String, TextEditingController> _hint = {
    for (final locale in GameLocale.all) locale.id: TextEditingController(text: _storedHint(locale.id)),
  };
  late final Map<String, TextEditingController> _explanation = {
    for (final locale in GameLocale.all) locale.id: TextEditingController(text: _storedExplanation(locale.id)),
  };
  var _busy = false;
  var _error = '';

  String _storedText(String locale) {
    if (locale == _locale) return widget.question?.text ?? '';
    return widget.question?.translations[locale]?.text ?? '';
  }

  String _storedOption(String locale, int index) {
    final options = locale == _locale ? widget.question?.options : widget.question?.translations[locale]?.options;
    if (options == null || options.length <= index) return '';
    return options[index];
  }

  String _storedHint(String locale) {
    if (locale == _locale) return widget.question?.hint ?? '';
    return widget.question?.translations[locale]?.hint ?? '';
  }

  String _storedExplanation(String locale) {
    if (locale == _locale) return widget.question?.explanation ?? '';
    return widget.question?.translations[locale]?.explanation ?? '';
  }

  bool _filled(String locale) {
    final text = _text[locale]?.text.trim() ?? '';
    final options = [for (final field in _options[locale] ?? const <TextEditingController>[]) field.text.trim()];
    return bilgiLanguageFieldsReady(text, options, _explanation[locale]?.text ?? 'dolu');
  }

  @override
  void dispose() {
    for (final field in _text.values) {
      field.dispose();
    }
    for (final fields in _options.values) {
      for (final field in fields) {
        field.dispose();
      }
    }
    for (final field in _hint.values) {
      field.dispose();
    }
    for (final field in _explanation.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _retranslate() async {
    if (_busy || !widget.editing) return;
    final text = _text[_locale]!.text.trim();
    final options = [for (final field in _options[_locale]!) field.text.trim()];
    final explanation = _explanation[_locale]!.text.trim();
    final hint = _hint[_locale]!.text.trim();
    if (!bilgiLanguageFieldsReady(text, options, explanation) || hint.isEmpty) {
      setState(() => _error = 'Türkçe soru, dört şık, ipucu ve açıklama dolu olmalı.');
      return;
    }
    setState(() {
      _busy = true;
      _error = '';
    });
    final result = await BilgiQuestionApi.translateQuestion(
      sl<ApiSession>().adminToken ?? '',
      text: text,
      options: options,
      explanation: explanation,
      hint: hint,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _busy = false;
        _error = result.error!;
      });
      return;
    }
    for (final entry in result.translations.entries) {
      _text[entry.key]?.text = entry.value.text;
      _explanation[entry.key]?.text = entry.value.explanation;
      _hint[entry.key]?.text = entry.value.hint;
      final fields = _options[entry.key];
      if (fields == null) continue;
      for (var i = 0; i < 4; i++) {
        fields[i].text = i < entry.value.options.length ? entry.value.options[i] : '';
      }
    }
    setState(() => _busy = false);
  }

  void _submit() {
    final text = _text[_locale]!.text.trim();
    final options = [for (final field in _options[_locale]!) field.text.trim()];
    if (!bilgiLanguageFieldsReady(text, options, _explanation[_locale]!.text)) {
      setState(() => _error = 'Türkçe soru, dört şık ve açıklama dolu olmalı.');
      return;
    }
    final translations = <String, BilgiTranslation>{};
    for (final locale in GameLocale.all) {
      if (locale.id == _locale) continue;
      final translated = _text[locale.id]!.text.trim();
      final translatedOptions = [for (final field in _options[locale.id]!) field.text.trim()];
      if (!bilgiLanguageFieldsReady(translated, translatedOptions, _explanation[locale.id]!.text.trim().isEmpty ? ' ' : _explanation[locale.id]!.text)) {
        if (translated.isEmpty && translatedOptions.every((item) => item.isEmpty)) continue;
        setState(() => _error = '${locale.nativeName} eksik. Dört şık da dolu olmalı.');
        return;
      }
      translations[locale.id] = BilgiTranslation(
        text: translated,
        options: translatedOptions,
        explanation: _explanation[locale.id]!.text.trim(),
        hint: _hint[locale.id]!.text.trim(),
      );
    }
    final current = widget.question;
    Navigator.pop(
      context,
      BilgiQuestion(
        id: current?.id ?? 'gun-${widget.day}-${widget.index}',
        categoryId: current?.categoryId ?? tumuKarmaId,
        text: text,
        options: options,
        correct: _correct.clamp(0, 3),
        difficulty: _difficulty,
        explanation: _explanation[_locale]!.text.trim(),
        hint: _hint[_locale]!.text.trim(),
        status: current?.status ?? 'approved',
        tags: current?.tags ?? const [],
        rejectReason: current?.rejectReason ?? '',
        translations: translations,
        reviewed: current?.reviewed ?? false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = _selected;
    final readOnly = !widget.editing;
    return Dialog(
      backgroundColor: BilgiColors.card,
      child: SizedBox(
        width: 760,
        height: 720,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.question == null ? 'Soru ekle' : (readOnly ? 'Diller' : 'Soruyu düzenle'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              if (widget.editing) ...[
                const SizedBox(height: 8),
                const Text(
                  'Kayıt Türkçeyi ve ekrandaki çevirileri yazar. Diğer diller ancak Dilleri yeniden yaz ile değişir.',
                  style: TextStyle(color: BilgiColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              _BilgiLangTabs(selected: locale, onSelect: (id) => setState(() => _selected = id), filled: _filled),
              const SizedBox(height: 12),
              Expanded(
                child: ListView(
                  children: [
                    TextField(
                      controller: _text[locale],
                      readOnly: readOnly,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Soru'),
                    ),
                    for (var i = 0; i < 4; i++)
                      TextField(
                        controller: _options[locale]![i],
                        readOnly: readOnly,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(labelText: '${['A', 'B', 'C', 'D'][i]} şıkkı'),
                      ),
                    TextField(
                      controller: _hint[locale],
                      readOnly: readOnly,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'İpucu'),
                    ),
                    TextField(
                      controller: _explanation[locale],
                      readOnly: readOnly,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(labelText: 'Açıklama'),
                    ),
                    if (locale == _locale) ...[
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int>(
                        initialValue: _correct,
                        dropdownColor: BilgiColors.card,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Doğru şık'),
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('A')),
                          DropdownMenuItem(value: 1, child: Text('B')),
                          DropdownMenuItem(value: 2, child: Text('C')),
                          DropdownMenuItem(value: 3, child: Text('D')),
                        ],
                        onChanged: readOnly ? null : (value) => setState(() => _correct = value ?? 0),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _difficulty,
                        dropdownColor: BilgiColors.card,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(labelText: 'Zorluk'),
                        items: const [
                          DropdownMenuItem(value: 'kolay', child: Text('Kolay')),
                          DropdownMenuItem(value: 'orta', child: Text('Orta')),
                          DropdownMenuItem(value: 'zor', child: Text('Zor')),
                          DropdownMenuItem(value: 'efsane', child: Text('Efsane')),
                        ],
                        onChanged: readOnly ? null : (value) => setState(() => _difficulty = value ?? 'kolay'),
                      ),
                    ],
                  ],
                ),
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(_error, style: const TextStyle(color: BilgiColors.warning)),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.editing)
                    OutlinedButton(
                      onPressed: _busy ? null : _retranslate,
                      child: Text(_busy ? 'Yazılıyor' : 'Dilleri yeniden yaz'),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
                  if (widget.editing) ...[
                    const SizedBox(width: 8),
                    FilledButton(onPressed: _busy ? null : _submit, child: const Text('Soruyu kaydet')),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
