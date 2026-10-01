import 'package:flutter/material.dart';
import 'package:kelimelig/admin/word_csv_pick.dart';
import 'package:kelimelig/core/constants/game_version.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/core/mail/mail_template.dart';
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_csv.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_mail.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_question_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_theme.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_user_api.dart';
import 'package:kelimelig/injection.dart';

class BilgiAdminScreen extends StatefulWidget {
  const BilgiAdminScreen({super.key, required this.onLeave});

  final VoidCallback onLeave;

  @override
  State<BilgiAdminScreen> createState() => _BilgiAdminScreenState();
}

class _BilgiAdminScreenState extends State<BilgiAdminScreen> {
  var _index = 0;
  var _note = '';
  List<BilgiQuestion> _questions = const [];
  List<BilgiProfile> _users = const [];
  BilgiConfig _config = const BilgiConfig();
  Map<String, dynamic> _catalog = const {};
  List<Map<String, dynamic>> _events = const [];
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
  var _bankPage = 0;
  var _labels = const <String, String>{};
  var _moveCat = '';
  var _moveSub = '';
  final _selectedIds = <String>{};
  var _bulkBusy = false;
  var _bulkStatusOpen = false;
  var _formSerial = 0;
  String? _translatingId;
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

  LunoBilgiServer get _server => sl<LunoBilgiServer>();

  int get _pendingCount => _questions.where(_pendingReady).length;
  int get _bannedCount => _users.where((u) => u.banned).length;
  int get _bankBadge => _questions.where((q) => q.status == 'approved' || q.status == 'pending').length;

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
    _bankSearch.dispose();
    _mailSubject.dispose();
    _mailHtml.dispose();
    _mailText.dispose();
    _mailTestTo.dispose();
    super.dispose();
  }

  Future<void> _saveRemote(List<BilgiQuestion> questions) async {
    final error = await BilgiQuestionApi.save(sl<ApiSession>().adminToken ?? '', questions);
    if (error != null) throw StateError(error);
    for (final question in questions) {
      await _server.saveQuestion(question);
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

  Future<List<BilgiQuestion>> _bank() async {
    await _pushLocalBankOnce();
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) return _server.questions();
    final remote = await BilgiQuestionApi.loadAll(token);
    if (remote == null) return _server.questions();
    await _server.replaceQuestionBank(remote);
    // loadAll already replaced Hive; never re-PUT that stale bank over newer API writes.
    await _server.writeMeta('questionsPushedToApi', '1');
    return remote;
  }

  Future<void> _applyRemoteActive() async {
    final active = await BilgiQuestionApi.loadActive();
    if (active == null) return;
    final catalog = await _server.catalog();
    await _server.saveCatalog(bilgiCatalogClosedUnless(catalog, active.categories, active.subs));
  }

  Future<List<BilgiProfile>> _usersBank() async {
    final token = sl<ApiSession>().adminToken ?? '';
    if (token.isEmpty) return _server.users();
    final remote = await BilgiUserApi.loadAll(token);
    if (remote == null) return _server.users();
    return remote;
  }

  Future<void> _load() async {
    final questions = await _bank();
    final labels = await BilgiQuestionApi.loadLabels();
    final users = await _usersBank();
    final config = await _server.config();
    final events = await _server.events();
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
      _questions = questions;
      _labels = labels;
      _selectedIds.removeWhere((id) => !questions.any((question) => question.id == id));
      _users = users;
      _config = config;
      _catalog = catalog;
      _events = events;
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
      19 => 'Ekonomi Ayarları',
      25 => 'Genel Ayarlar',
      27 => 'E-posta şablonu',
      _ => _nav[_index].label,
    };
  }

  String get _subtitle {
    return switch (_index) {
      0 => 'Luno Bilgi genel bakış',
      1 => '${_questions.length} soru • $_pendingCount onay bekliyor',
      2 => 'Doğru şıkkın A B C D dağılımı',
      3 => 'Oyuncuların hatalı soru bildirimleri',
      4 => _editing == null ? 'Soru bankasına yeni soru ekle' : 'Kayıtlı soruyu güncelle',
      5 => '$_pendingCount soru onay bekliyor',
      6 => '${_questions.where((q) => q.status == 'rejected').length} soru reddedildi',
      7 => 'Yalnızca CSV ile toplu soru yükle',
      8 => '${_categories.length} ana kategori • ${bilgiGroups.length} grup',
      12 => '${_users.length} kullanıcı • ${_users.where((u) => u.premium).length} premium',
      13 => '$_bannedCount kullanıcı banlı',
      14 => '${_users.where((u) => u.premium).length} premium üye',
      21 => '7 günlük ödül takvimi',
      22 => 'Reklam stratejisi ve limitleri',
      23 => '${_events.where((e) => e['status'] == 'active').length} aktif • ${_events.where((e) => e['status'] == 'pending').length} bekleyen',
      24 => 'Detaylı analiz ve raporlar',
      25 => 'Uygulama geneli yapılandırma',
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
          onTap: () => i == 4 ? _openEditor() : setState(() => _index = i),
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
      final byId = _questions.where((question) => question.id == id).firstOrNull;
      if (byId != null) return byId;
    }
    final text = report.questionText.trim();
    if (text.isEmpty) return null;
    return _questions.where((question) => question.text == text).firstOrNull;
  }

  void _openReportEditor(BilgiQuestionReport report) {
    final question = _questionForReport(report);
    if (question == null) {
      setState(() => _reportEditMisses[report.id] = 'Soru bankasında bulunamadı.');
      return;
    }
    setState(() => _reportEditMisses.remove(report.id));
    _openEditor(question);
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
      17 => _jokers(),
      18 => _lives(),
      19 => _economy(),
      20 => _packs(),
      21 => _rewards(),
      22 => _ads(),
      23 => _eventEditor(),
      24 => _stats(),
      25 => _general(),
      26 => _admins(),
      27 => _mail(),
      _ => _admins(),
    };
  }

  Widget _optionDistribution() {
    final rows = [
      for (final question in _questions)
        if ((_distCat.isEmpty || question.categoryId == _distCat) &&
            (_distSub.isEmpty || question.tags.contains(_distSub)))
          question,
    ];
    final counts = [0, 0, 0, 0];
    const difficulties = ['kolay', 'orta', 'zor', 'efsane'];
    final difficultyCounts = [0, 0, 0, 0];
    var otherDifficulty = 0;
    for (final question in rows) {
      counts[question.correct.clamp(0, 3)] += 1;
      final slot = difficulties.indexOf(question.difficulty);
      if (slot < 0) {
        otherDifficulty += 1;
      } else {
        difficultyCounts[slot] += 1;
      }
    }
    final total = rows.length;
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
              onChanged: (value) => setState(() {
                _distCat = value;
                _distSub = '';
              }),
            ),
            _SearchCombo(
              hint: _distCat.isEmpty ? 'Önce ana kategori' : 'Alt kategori',
              selected: _distSub,
              enabled: _distCat.isNotEmpty,
              options: [for (final name in subs) (name, name)],
              onChanged: (value) => setState(() => _distSub = value),
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
      ],
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
              _dashMetric('❓', _trInt(_questions.length), 'Toplam Soru', _pendingCount == 0 ? null : (text: '$_pendingCount onay bekliyor', up: true)),
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
                onAction: () => setState(() => _index = 5),
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
                  _dashQuick('✅', 'Onay Bekleyenler', () => setState(() => _index = 5)),
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
          questions: _questions.where((q) => q.categoryId == id && q.status == 'approved').length,
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
    final chosen = _questions.where((question) => _selectedIds.contains(question.id)).toList();
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
          status: question.status,
          tags: [
            _moveSub,
            ...question.tags.where((tag) {
              final previous = _categories.where((item) => item.id == question.categoryId).firstOrNull;
              return tag != _moveSub && !(previous?.subs.contains(tag) ?? false);
            }),
          ],
          rejectReason: question.rejectReason,
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

  bool _pendingReady(BilgiQuestion question) =>
      bilgiPendingApprovalReady(question, locales: _publishLocales(question.categoryId));

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
    final chosen = _questions.where((question) => _selectedIds.contains(question.id)).toList();
    final changed = <BilgiQuestion>[];
    var blocked = 0;
    for (final question in chosen) {
      if (status == 'approved' && !_questionReady(question)) {
        blocked++;
        continue;
      }
      if (question.status == status) continue;
      changed.add(bilgiQuestionWithReviewStatus(question, status));
    }
    if (changed.isEmpty) {
      setState(() {
        _bulkStatusOpen = false;
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
      _bulkStatusOpen = false;
      _note = blocked == 0
          ? '${changed.length} sorunun durumu ${labels[status]} oldu.'
          : '${changed.length} sorunun durumu ${labels[status]} oldu. $blocked soru tercümesi tamam olmadığı için onaylanmadı.';
    });
    await _load();
  }

  Future<void> _translateSelected() async {
    if (_bulkBusy) return;
    if (_selectedIds.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    final chosen = _questions.where((question) => _selectedIds.contains(question.id)).toList();
    if (chosen.isEmpty) {
      setState(() => _note = 'Önce soru seç.');
      return;
    }
    setState(() => _bulkBusy = true);
    var translated = 0;
    var skipped = 0;
    var failed = 0;
    try {
      for (var i = 0; i < chosen.length; i++) {
        if (!mounted) return;
        final question = chosen[i];
        if (!bilgiLanguageFieldsReady(question.text, question.options, question.explanation)) {
          skipped++;
          setState(() => _note = 'Türkçe soru, dört şık ve açıklama dolu olmalı.');
          continue;
        }
        final targets = bilgiExtraLocales(_publishLocales(question.categoryId));
        if (targets.isEmpty) {
          skipped++;
          continue;
        }
        setState(() {
          _translatingId = question.id;
          _note = 'Çevriliyor... (${i + 1}/${chosen.length})';
        });
        final result = await BilgiQuestionApi.translateQuestion(
          sl<ApiSession>().adminToken ?? '',
          text: question.text,
          options: question.options,
          explanation: question.explanation,
          locales: targets,
        );
        if (!mounted) return;
        if (result.error != null) {
          failed++;
          setState(() => _note = result.error!);
          continue;
        }
        final written = question.copyWith(translations: {...question.translations, ...result.translations});
        try {
          setState(() => _note = 'Tercüme kaydediliyor... (${i + 1}/${chosen.length})');
          await _saveRemote([written]);
          translated++;
          await _load();
        } on StateError catch (error) {
          failed++;
          if (!mounted) return;
          setState(() => _note = error.message);
        } catch (_) {
          failed++;
          if (!mounted) return;
          setState(() => _note = 'Soru kaydedilemedi.');
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _bulkBusy = false;
          _translatingId = null;
          _note = '$translated soru çevrildi. $skipped atlandı. $failed başarısız.';
        });
      }
    }
  }

  Widget _bankTable() {
    final query = _bankSearch.text.trim();
    final filtering = query.length >= 3;
    final folded = _fold(query);
    final rows = _questions.where((q) {
      if (_bankCat.isNotEmpty && q.categoryId != _bankCat) return false;
      if (_bankSub.isNotEmpty && !q.tags.contains(_bankSub)) return false;
      if (_bankDiff.isNotEmpty && q.difficulty != _bankDiff) return false;
      if (_bankStatus.isNotEmpty && q.status != _bankStatus) return false;
      final translated = _questionReady(q);
      if (_bankLang == 'ready' && !translated) return false;
      if (_bankLang == 'missing' && translated) return false;
      if (!filtering) return true;
      if (_fold(q.text).contains(folded)) return true;
      for (final option in q.options) {
        if (_fold(option).contains(folded)) return true;
      }
      return false;
    }).toList();
    const pageSize = 12;
    final pages = rows.isEmpty ? 1 : (rows.length / pageSize).ceil();
    final page = _bankPage.clamp(0, pages - 1);
    final slice = rows.skip(page * pageSize).take(pageSize).toList();
    final from = rows.isEmpty ? 0 : page * pageSize + 1;
    final to = page * pageSize + slice.length;
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
              const Text('Ara', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextField(
                controller: _bankSearch,
                style: const TextStyle(color: Colors.white),
                onChanged: (_) => setState(() => _bankPage = 0),
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
                    onChanged: (v) => setState(() { _bankCat = v; _bankSub = ''; _bankPage = 0; }),
                  ),
                  _SearchCombo(
                    hint: _bankCat.isEmpty ? 'Önce ana kategori' : 'Alt kategori',
                    selected: _bankSub,
                    enabled: _bankCat.isNotEmpty,
                    options: [
                      for (final name in _categories.where((item) => item.id == _bankCat).firstOrNull?.subs ?? const <String>[]) (name, name),
                    ],
                    onChanged: (v) => setState(() { _bankSub = v; _bankPage = 0; }),
                  ),
                  _select(_bankDiff, [('','Tüm Zorluklar'), ('kolay','Kolay'), ('orta','Orta'), ('zor','Zor'), ('efsane','Efsane')], (v) => setState(() { _bankDiff = v; _bankPage = 0; })),
                  _select(_bankStatus, [('','Tüm Durumlar'), ('approved','Onaylı'), ('pending','Bekleyen'), ('draft','Taslak'), ('rejected','Reddedilen')], (v) => setState(() { _bankStatus = v; _bankPage = 0; })),
                  _select(_bankLang, [('','Tüm Tercümeler'), ('ready','Tercüme tamam'), ('missing','Tercüme eksik')], (v) => setState(() { _bankLang = v; _bankPage = 0; })),
                  _ghost('📥 İçe Aktar', () => setState(() => _index = 7)),
                  _primary('➕ Yeni Soru', _openEditor),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _ghost('Tümünü seç', () {
                    if (rows.isEmpty || _bulkBusy) return;
                    setState(() {
                      for (final question in rows) {
                        _selectedIds.add(question.id);
                      }
                    });
                  }),
                  _ghost('Seçimi temizle', () {
                    if (_selectedIds.isEmpty || _bulkBusy) return;
                    setState(_selectedIds.clear);
                  }),
                  Text('${_selectedIds.length} seçili', style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
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
                  _primary('Kategoriyi değiştir', () { _applyBulkCategory(); }),
                  _primary('Seçilenleri çevir', () { _translateSelected(); }),
                  _primary('Toplu durum güncelle', () {
                    if (_bulkBusy) return;
                    setState(() => _bulkStatusOpen = !_bulkStatusOpen);
                  }),
                  if (_bulkStatusOpen) ...[
                    _ghost('Onaylı', () { _applyBulkStatus('approved'); }),
                    _ghost('Bekleyen', () { _applyBulkStatus('pending'); }),
                    _ghost('Taslak', () { _applyBulkStatus('draft'); }),
                    _ghost('Reddedilen', () { _applyBulkStatus('rejected'); }),
                  ],
                  _solid('Seçimi sil', BilgiColors.error, Colors.white, () { _deleteSelected(); }),
                ],
              ),
            ],
          ),
        ),
        Container(
          decoration: _cardDeco(),
          child: Column(
            children: [
              _bankCells([
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
                              }
                            } else {
                              for (final question in rows) {
                                _selectedIds.add(question.id);
                              }
                            }
                          });
                        },
                  activeColor: BilgiColors.secondary,
                  side: const BorderSide(color: Colors.white54),
                ),
                for (final label in const ['ID', 'SORU', 'KATEGORİ', 'ALT KATEGORİ', 'ZORLUK', 'DURUM', 'İŞLEM'])
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
                    Text('$from-$to / ${rows.length} soru', style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                    const Spacer(),
                    _pageBtn('‹', page > 0 ? () => setState(() => _bankPage = page - 1) : null, false),
                    _pageBtn('${page + 1}', null, true),
                    _pageBtn('›', page + 1 < pages ? () => setState(() => _bankPage = page + 1) : null, false),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static const _bankFlex = [1, 2, 4, 2, 3, 2, 2, 3];

  Widget _bankCells(List<Widget> cells, {bool header = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: header
          ? const BoxDecoration(color: Color(0xFF121022), borderRadius: BorderRadius.vertical(top: Radius.circular(16)))
          : const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
      child: Row(
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

  Widget _bankRow(BilgiQuestion question) {
    final pending = question.status == 'pending';
    return _bankCells([
      Checkbox(
        value: _selectedIds.contains(question.id),
        onChanged: _bulkBusy
            ? null
            : (checked) => setState(() {
                  if (checked ?? false) {
                    _selectedIds.add(question.id);
                  } else {
                    _selectedIds.remove(question.id);
                  }
                }),
        activeColor: BilgiColors.secondary,
        side: const BorderSide(color: Colors.white54),
      ),
      Text(question.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
      Row(
        children: [
          if (_questionReady(question)) ...[
            _langOk(),
            const SizedBox(width: 6),
          ],
          Expanded(child: Text(question.text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
      Text(_catLabel(question.categoryId), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      Text(_subLabel(question), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 13)),
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

  Widget _rowTranslateBtn(BilgiQuestion question) {
    final busy = _translatingId == question.id;
    return Tooltip(
      message: 'Tüm dilleri çevir',
      child: InkWell(
        onTap: busy ? null : () => _translateRow(question),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: BilgiColors.primary),
                )
              : const Text(
                  'Çevir',
                  style: TextStyle(color: BilgiColors.primary, fontSize: 11, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }

  Future<void> _translateRow(BilgiQuestion question) async {
    if (_translatingId == question.id) return;
    if (!bilgiLanguageFieldsReady(question.text, question.options, question.explanation)) {
      setState(() => _note = 'Türkçe soru, dört şık ve açıklama dolu olmalı.');
      return;
    }
    setState(() {
      _translatingId = question.id;
      _note = 'Çevriliyor...';
    });
    final targets = bilgiExtraLocales(_publishLocales(question.categoryId));
    if (targets.isEmpty) {
      setState(() {
        _translatingId = null;
        _note = 'Bu kategoride başka yayın dili yok.';
      });
      return;
    }
    final result = await BilgiQuestionApi.translateQuestion(
      sl<ApiSession>().adminToken ?? '',
      text: question.text,
      options: question.options,
      explanation: question.explanation,
      locales: targets,
    );
    if (!mounted) return;
    if (result.error != null) {
      setState(() {
        _translatingId = null;
        _note = result.error!;
      });
      return;
    }
    final written = question.copyWith(translations: {...question.translations, ...result.translations});
    try {
      setState(() => _note = 'Tercüme kaydediliyor...');
      await _saveRemote([written]);
      await _load();
      if (!mounted) return;
      setState(() {
        _translatingId = null;
        _note = 'Soru çevrildi ve kaydedildi.';
      });
    } on StateError catch (error) {
      if (!mounted) return;
      setState(() {
        _translatingId = null;
        _note = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _translatingId = null;
        _note = 'Soru kaydedilemedi.';
      });
    }
  }

  Widget _pendingCards() {
    final rows = _questions.where(_pendingReady).toList();
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
                  Text(question.id, style: const TextStyle(color: BilgiColors.muted, fontWeight: FontWeight.w700)),
                  if (_questionReady(question)) ...[
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
    final rows = _questions.where((q) => q.status == 'rejected').toList();
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
                              if (_questionReady(question)) ...[
                                _langOk(),
                                const SizedBox(width: 6),
                              ],
                              Expanded(child: Text(question.text, maxLines: 1, overflow: TextOverflow.ellipsis)),
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
    final latest = _questions.where((row) => row.id == question.id).firstOrNull ?? question;
    if (status == 'approved' && !_questionReady(latest)) {
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
    setState(() {
      _questions = [
        for (final row in _questions)
          if (row.id == updated.id) updated else row,
      ];
      _note = status == 'approved'
          ? 'Soru onaylandı.'
          : status == 'rejected'
              ? 'Soru reddedildi.'
              : 'Durum güncellendi.';
    });
    await _load();
  }

  void _openEditor([BilgiQuestion? question]) {
    setState(() {
      _editing = question;
      _formSerial += 1;
      _index = 4;
    });
  }

  Widget _editor() {
    final known = <String>{
      for (final question in _questions) ...question.tags.where((tag) => tag.isNotEmpty && bilgiCategoryById(tag) == null),
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
          status: draft.asDraft ? 'draft' : (existing == null ? 'pending' : draft.status),
          tags: draft.tags,
          rejectReason: existing?.rejectReason ?? '',
          translations: draft.translations,
        );
        if (written.status == 'approved' && !_questionReady(written)) {
          setState(() => _note = bilgiApproveBlocked);
          throw StateError(bilgiApproveBlocked);
        }
        try {
          await _saveRemote([written]);
          await _load();
          final stored = _questions.where((question) => question.id == id).firstOrNull;
          if (stored == null || !sameStoredBilgiQuestion(stored, written)) {
            throw StateError('Soru kaydedilemedi.');
          }
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
        await _load();
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

  int _questionTotal(String id) => _questions.where((question) => question.categoryId == id).length;

  Widget _categoryList() {
    final groups = <String, List<BilgiCategory>>{};
    for (final category in _categories) {
      groups.putIfAbsent(category.group, () => []).add(category);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: EdgeInsets.only(top: entry.key == groups.keys.first ? 0 : 16, bottom: 12),
            child: Row(
              children: [
                Text(entry.key.toUpperCase(), style: const TextStyle(color: BilgiColors.secondary, fontSize: 13, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                _catBtn('✏️', () => _editGroup(entry.key)),
                const Spacer(),
                Text('${entry.value.length} kategori', style: const TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900 ? 3 : constraints.maxWidth >= 620 ? 2 : 1;
              final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (final category in entry.value) _categoryCard(category, width),
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
    final count = _questions.where((q) => q.categoryId == selected.id && q.status == 'approved').length;
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
              const Text('Ana Kategori', style: TextStyle(color: BilgiColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
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
        if (showKarma) _subRow('🎲', karmaTitle, 'Aynı soru havuzu • $count soru', gradient: true),
        if (selected.subs.isEmpty)
          const Padding(padding: EdgeInsets.only(top: 12), child: Text('Bu kategoride alt kategori yok.', style: TextStyle(color: BilgiColors.muted)))
        else if (visibleSubs.isEmpty && !showKarma)
          const Padding(padding: EdgeInsets.only(top: 12), child: Text('Sonuç yok.', style: TextStyle(color: BilgiColors.muted)))
        else
          for (final sub in visibleSubs)
            _subRow(
              _subIcon(sub),
              sub,
              '${_subQuestionCount(sub)} soru',
              ready: bilgiNamesReady(_labels, 'sub', '${selected.id}|$sub', locales: selected.locales),
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

  int _subQuestionCount(String name) => _questions.where((question) => question.tags.contains(name)).length;

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
    final names = {for (final entry in fields.entries) if (entry.key != 'tr') entry.key: entry.value.text.trim()};
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

  Widget _subRow(String emoji, String title, String hint, {bool gradient = false, bool ready = false, Widget? trailing}) {
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
                    if (ready) ...[
                      const SizedBox(width: 6),
                      _langOk(),
                    ],
                  ],
                ),
                Text(hint, style: TextStyle(color: gradient ? Colors.white70 : BilgiColors.muted, fontSize: 11)),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }

  Widget _tags() {
    final counts = <String, int>{};
    for (final question in _questions) {
      for (final tag in question.tags) {
        if (tag.isEmpty) continue;
        counts[tag] = (counts[tag] ?? 0) + 1;
      }
    }
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
    final approved = _questions.where((q) => q.status == 'approved').length;
    final counts = {
      'kolay': _questions.where((q) => q.status == 'approved' && q.difficulty == 'kolay').length,
      'orta': _questions.where((q) => q.status == 'approved' && q.difficulty == 'orta').length,
      'zor': _questions.where((q) => q.status == 'approved' && q.difficulty == 'zor').length,
      'efsane': _questions.where((q) => q.status == 'approved' && q.difficulty == 'efsane').length,
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

  Widget _userList(bool? banned, {bool premium = false}) {
    final query = _topSearch.text.trim().toLowerCase();
    final rows = _users.where((user) {
      if (premium && !user.premium) return false;
      if (banned != null && user.banned != banned) return false;
      if (query.isEmpty) return true;
      return user.username.toLowerCase().contains(query) || user.email.toLowerCase().contains(query);
    }).toList();
    final empty = premium ? 'Premium üye yok.' : banned == true ? 'Banlı kullanıcı yok.' : 'Kayıtlı kullanıcı yok.';
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        if (premium)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Play makbuzu olmadan premium yüklenmez.', style: TextStyle(color: BilgiColors.warning)),
          ),
        Container(
          decoration: _cardDeco(),
          child: Column(
            children: [
              _tableHead(const ['Kullanıcı', 'Seviye', 'Altın', 'Durum', 'İşlem']),
              if (rows.isEmpty)
                Padding(padding: const EdgeInsets.all(20), child: Text(empty, style: const TextStyle(color: BilgiColors.muted)))
              else
                for (final user in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0x08FFFFFF)))),
                    child: Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.username, style: const TextStyle(fontWeight: FontWeight.w700)), Text(user.email, style: const TextStyle(color: BilgiColors.muted, fontSize: 11))])),
                        Expanded(child: Text('${user.level}')),
                        Expanded(child: Text('${user.gold}')),
                        Expanded(child: _badge(user.banned ? 'Banlı' : user.premium ? 'Premium' : 'Aktif', user.banned ? BilgiColors.error : BilgiColors.secondary)),
                        if (!premium)
                          _ghost(user.banned ? 'Aç' : 'Banla', () async {
                            final banned = !user.banned;
                            final reason = banned ? 'Askıya alındı' : '';
                            final token = sl<ApiSession>().adminToken ?? '';
                            final error = await BilgiUserApi.setBan(
                              token,
                              user.id,
                              banned: banned,
                              reason: reason,
                            );
                            await _server.setBan(user.id, banned: banned, reason: reason);
                            if (error != null && mounted) setState(() => _note = error);
                            await _load();
                          }),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
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
        const Text('Günlük giriş ve seviye atlama canı 0. Sakin mod ve günün sorusu can harcamaz.', style: TextStyle(color: BilgiColors.muted, fontSize: 12)),
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
            _packCard('Haftalık', '19,99 TL'),
            _packCard('Aylık', '49,99 TL', popular: true),
            _packCard('Yıllık', '399,99 TL'),
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

  Widget _eventEditor() {
    final week = DateKeys.weekId();
    final left = DateKeys.weekRemaining();
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        _panelCard('LUNO LİGİ', [
          _infoRow('Hafta', week),
          _infoRow('Kalan', '${left.inDays} gün ${left.inHours % 24} saat'),
          _infoRow('Ödül', '10000 / 5000 / 2500, ilk 100 kişi 500'),
        ]),
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
    required this.tags,
    required this.asDraft,
    required this.status,
    this.translations = const {},
  });

  final String text;
  final List<String> options;
  final int correct;
  final String categoryId;
  final String difficulty;
  final String explanation;
  final List<String> tags;
  final bool asDraft;
  final String status;
  final Map<String, BilgiTranslation> translations;
}

class _QuestionForm extends StatefulWidget {
  const _QuestionForm({
    super.key,
    required this.categories,
    required this.knownTags,
    required this.onSave,
    required this.onCancel,
    this.initial,
  });

  final List<BilgiCategory> categories;
  final List<String> knownTags;
  final Future<void> Function(_QuestionDraft draft) onSave;
  final VoidCallback onCancel;
  final BilgiQuestionFormData? initial;

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
  final _newTag = TextEditingController();
  late var _correct = widget.initial?.correct ?? -1;
  late var _category = widget.initial?.categoryId ?? '';
  late var _sub = widget.initial?.subcategory ?? '';
  late var _difficulty = widget.initial?.difficulty ?? 'kolay';
  late var _status = widget.initial?.status ?? '';
  var _addingTag = false;
  var _busy = false;
  late final _picked = <String>{...?widget.initial?.tags};
  var _lang = 'tr';
  var _translating = false;
  var _translateNote = '';
  late final _bag = <String, BilgiTranslation>{
    ...?widget.initial?.translations,
    'tr': BilgiTranslation(
      text: widget.initial?.text ?? '',
      options: [
        for (var i = 0; i < 4; i++)
          widget.initial != null && i < widget.initial!.options.length ? widget.initial!.options[i] : '',
      ],
      explanation: widget.initial?.explanation ?? '',
    ),
  };

  @override
  void dispose() {
    _text.dispose();
    for (final field in _options) {
      field.dispose();
    }
    _explanation.dispose();
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
          )
        : _bag[id];
    if (row == null) return false;
    return bilgiLanguageFieldsReady(row.text, row.options, row.explanation);
  }

  void _storeLang() {
    _bag[_lang] = BilgiTranslation(
      text: _text.text.trim(),
      options: [for (final field in _options) field.text.trim()],
      explanation: _explanation.text.trim(),
    );
  }

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
    final targets = bilgiExtraLocales(_cat?.locales);
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

  void _showLang(String lang) {
    _storeLang();
    final row = _bag[lang];
    _text.text = row?.text ?? '';
    for (var i = 0; i < 4; i++) {
      _options[i].text = row != null && i < row.options.length ? row.options[i] : '';
    }
    _explanation.text = row?.explanation ?? '';
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
          tags: tags.toList(),
          asDraft: draft,
          status: draft ? 'draft' : (_status.isEmpty ? 'pending' : _status),
          translations: {
            for (final entry in _bag.entries)
              if (entry.key != 'tr' && entry.value.text.isNotEmpty && entry.value.options.every((item) => item.isNotEmpty))
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
        ? BilgiTranslation(text: _text.text.trim(), options: [for (final field in _options) field.text.trim()], explanation: _explanation.text.trim())
        : _bag['tr'];
    final ready = (turkish?.text.isNotEmpty ?? false) &&
        (turkish?.options.every((item) => item.isNotEmpty) ?? false) &&
        _correct >= 0 &&
        _category.isNotEmpty &&
        (_cat?.subs.contains(_sub) ?? false);
    final subs = _cat?.subs ?? const <String>[];
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
                        selected: _lang,
                        onSelect: _showLang,
                        wrap: true,
                        filled: _langFilled,
                      ),
                    ),
                    const SizedBox(width: 12),
                    _translateAllButton(busy: _translating, onPressed: _translateAll),
                  ],
                ),
                if (_translateNote.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(_translateNote, style: const TextStyle(color: BilgiColors.muted, fontSize: 12)),
                ],
                const SizedBox(height: 12),
                _card(_lang == 'tr' ? '1. Soru Metni' : '1. Soru Metni · ${GameLocale.resolve(_lang).nativeName}', [
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
                ]),
                _card('3. Kategori ve Zorluk', [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _drop('Ana Kategori', _category, [for (final c in widget.categories) (c.id, '${c.emoji} ${c.name}')], (v) => setState(() { _category = v; _sub = ''; }))),
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
      if (!_focus.hasFocus) _text.text = _labelOf(_picked);
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
    final targets = [
      for (final id in bilgiExtraLocales(null))
        if (widget.published == null || widget.published!.contains(id)) id,
    ];
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

Widget _translateAllButton({required bool busy, required VoidCallback? onPressed}) {
  return FilledButton(
    style: FilledButton.styleFrom(backgroundColor: BilgiColors.primary, minimumSize: const Size(0, 40)),
    onPressed: busy ? null : onPressed,
    child: busy
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Text('Tüm dilleri çevir'),
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
    final tabs = [
      for (final locale in GameLocale.all)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (published != null)
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
