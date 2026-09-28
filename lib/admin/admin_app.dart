import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_accounts_screen.dart';
import 'package:kelimelig/admin/admin_hub.dart';
import 'package:kelimelig/admin/admin_session.dart';
import 'package:kelimelig/admin/admin_shell_chrome.dart';
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/admin/game_catalog.dart';
import 'package:kelimelig/admin/screens/fall_admin_screen.dart';
import 'package:kelimelig/admin/screens/grid_admin_screen.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_admin.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/screens/config_screen.dart';
import 'package:kelimelig/admin/screens/daily_screen.dart';
import 'package:kelimelig/admin/screens/games_screen.dart';
import 'package:kelimelig/admin/screens/league_screen.dart';
import 'package:kelimelig/admin/screens/overview_screen.dart';
import 'package:kelimelig/admin/screens/shop_admin_screen.dart';
import 'package:kelimelig/admin/screens/site_cards_screen.dart';
import 'package:kelimelig/admin/screens/users_screen.dart';
import 'package:kelimelig/admin/screens/words_screen.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/utils/password_hash.dart';
import 'package:kelimelig/core/theme/app_theme.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/widgets/game_version_label.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  final _nav = GlobalKey<NavigatorState>();
  late final AdminDirectory _directory = sl.isRegistered<AdminDirectory>()
      ? sl<AdminDirectory>()
      : RemoteAdminDirectory(ApiConfig.baseUrl);
  var _authed = false;
  var _booting = true;
  String? _token;
  String? _gameId;
  AdminAccount? _account;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = readAdminToken();
    if (saved != null && saved.isNotEmpty) {
      try {
        final account = await _directory.me(saved);
        if (!mounted) return;
        _remember(saved);
        setState(() {
          _token = saved;
          _account = account;
          _authed = true;
          _booting = false;
        });
        return;
      } catch (_) {
        _remember(null);
      }
    }
    if (mounted) setState(() => _booting = false);
  }

  Future<void> _onAuthed(String token) async {
    _remember(token);
    AdminAccount? account;
    try {
      account = await _directory.me(token);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _token = token;
      _account = account;
      _authed = true;
    });
  }

  void _remember(String? token) {
    writeAdminToken(token);
    if (sl.isRegistered<ApiSession>()) {
      sl<ApiSession>().adminToken = token;
    }
  }

  GameServer? get _server {
    if (_gameId == null) return null;
    if (_gameId == GameIds.lunoLeague) return sl<GameServer>();
    return null;
  }

  void _openGame(String id) {
    AdminGameCatalog.byId(id);
    if (_account != null && !_account!.canEditGame(id)) return;
    setState(() => _gameId = id);
  }

  void _closeGame() {
    _nav.currentState?.popUntil((route) => route.isFirst);
    setState(() => _gameId = null);
  }

  void _signOut() {
    _nav.currentState?.popUntil((route) => route.isFirst);
    _remember(null);
    setState(() {
      _gameId = null;
      _authed = false;
      _token = null;
      _account = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _gameId == null ? null : AdminGameCatalog.byId(_gameId!);
    return AdminGameScope(
      authed: _authed,
      directory: _directory,
      token: _token,
      account: _account,
      game: game,
      server: _server,
      onAuthed: _onAuthed,
      onOpenGame: _openGame,
      onLeaveGame: _closeGame,
      onSignOut: _signOut,
      child: MaterialApp(
        navigatorKey: _nav,
        title: 'Game Server Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: _booting
            ? const Scaffold(
                backgroundColor: AdminHubColors.bg,
                body: Center(child: CircularProgressIndicator()),
              )
            : const AdminEntry(),
      ),
    );
  }
}

class AdminEntry extends StatelessWidget {
  const AdminEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AdminGameScope>()!;
    if (!scope.authed) {
      return AdminGate(directory: scope.directory, onSuccess: scope.onAuthed);
    }
    final game = scope.game;
    if (game == null) {
      return GamePicker(onOpen: scope.onOpenGame, onSignOut: scope.onSignOut);
    }
    return AdminShell(key: ValueKey(game.id), onLeave: scope.onLeaveGame);
  }
}

class AdminGate extends StatefulWidget {
  const AdminGate({
    super.key,
    required this.directory,
    required this.onSuccess,
  });

  final AdminDirectory directory;
  final ValueChanged<String> onSuccess;

  @override
  State<AdminGate> createState() => _AdminGateState();
}

class _AdminGateState extends State<AdminGate> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  var _loading = true;
  var _needsSetup = false;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final needsSetup = await widget.directory.needsSetup();
      if (!mounted) return;
      setState(() {
        _needsSetup = needsSetup;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Yönetim sunucusuna ulaşılamadı.';
      });
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: _loading
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Game Server',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _needsSetup
                          ? 'İlk yönetici hesabını oluştur'
                          : 'Yönetici girişi',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    const GameVersionLabel(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: const InputDecoration(labelText: 'E-posta'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pass,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Şifre'),
                      onSubmitted: _needsSetup ? null : (_) => _submit(),
                    ),
                    if (_needsSetup) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _pass2,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Şifre tekrar',
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ],
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_needsSetup ? 'Hesabı oluştur' : 'Giriş'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _pass.text;
    if (!PasswordHash.isValidEmail(email)) {
      setState(() => _error = 'Geçerli bir e-posta gir.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Şifre en az 8 karakter olmalı.');
      return;
    }
    if (_needsSetup && password != _pass2.text) {
      setState(() => _error = 'Şifreler aynı değil.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = _needsSetup
          ? await widget.directory.setup(email: email, password: password)
          : await widget.directory.login(email: email, password: password);
      if (!mounted) return;
      widget.onSuccess(token);
    } on AdminAuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Yönetim sunucusuna ulaşılamadı.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class GamePicker extends StatelessWidget {
  const GamePicker({super.key, required this.onOpen, required this.onSignOut});

  final ValueChanged<String> onOpen;
  final VoidCallback onSignOut;

  void _openStaff(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminAccountsScreen(hub: true)),
    );
  }

  void _tryOpen(BuildContext context, String id) {
    final account = AdminGameScope.maybeOf(context)?.account;
    if (account != null && !account.canEditGame(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu oyunu yönetme yetkin yok.')),
      );
      return;
    }
    onOpen(id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminHubColors.bg,
      body: Column(
        children: [
          AdminHubBar(
            active: AdminHubNav.games,
            onGames: () {},
            onStaff: () => _openStaff(context),
            onSignOut: onSignOut,
          ),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(40, 40, 40, 40),
                  children: [
                    const Text(
                      'Oyunlar',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Her oyun kendi deposunu kullanır. Kullanıcı, kelime, lig ve mağaza kayıtları birbirine karışmaz.',
                      style: TextStyle(color: AdminHubColors.muted),
                    ),
                    const SizedBox(height: 24),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const gap = 24.0;
                        final wide = constraints.maxWidth >= 480 * 2 + gap;
                        final cardWidth = wide
                            ? (constraints.maxWidth - gap) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final game in AdminGameCatalog.games)
                              SizedBox(
                                width: cardWidth,
                                child: _GameCard(
                                  game: game,
                                  onOpen: () => _tryOpen(context, game.id),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onOpen});

  final AdminGameDefinition game;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bilgi = game.id == GameIds.lunoBilgi;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AdminHubColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: bilgi ? AdminHubColors.primary : const Color(0x14FFFFFF),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0x1A6C3CE9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: Center(
                      child: game.id == GameIds.lunoLeague
                          ? const Text('🔤', style: TextStyle(fontSize: 24))
                          : Icon(game.icon, color: AdminHubColors.teal),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        game.summary,
                        style: const TextStyle(color: AdminHubColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AdminHubColors.teal,
                  foregroundColor: const Color(0xFF042F2A),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onOpen,
                child: const Text('Yönet'),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text(
                  'İzole depo:',
                  style: TextStyle(
                    color: AdminHubColors.muted,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: AdminHubColors.bg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    child: Text(
                      game.storePrefix,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: AdminHubColors.teal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0x33FFFFFF)),
                  minimumSize: const Size(0, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SiteCardForm(cardId: game.id),
                    ),
                  );
                },
                child: const Text('Vitrini Düzenle'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.onLeave});

  final VoidCallback onLeave;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  var _index = 0;
  var _locale = GameLocale.tr.id;
  var _league = LeagueTier.bronze;
  int? _listLength;

  Widget _page(AdminSection section) {
    final game = AdminGameScope.gameOf(context);
    final account = AdminGameScope.maybeOf(context)?.account;
    if (section == AdminSection.staff) {
      return const AdminAccountsScreen();
    }
    if (account != null && !account.canEditGame(game.id)) {
      return const Center(
        child: Text(
          'Bu oyunu yönetme yetkin yok.',
          style: TextStyle(color: AdminHubColors.muted),
        ),
      );
    }
    if (game.id == GameIds.lunoFall) {
      return FallAdminScreen(section: section);
    }
    if (game.id == GameIds.lunoGrid) {
      return GridAdminScreen(section: section);
    }
    return switch (section) {
      AdminSection.overview => const OverviewScreen(),
      AdminSection.users => const UsersScreen(),
      AdminSection.games => const GamesScreen(),
      AdminSection.words => const WordsScreen(),
      AdminSection.daily => const DailyScreen(),
      AdminSection.league => const LeagueScreen(),
      AdminSection.shop => const ShopAdminScreen(),
      AdminSection.settings => const ConfigScreen(),
      AdminSection.scenes => const SizedBox.shrink(),
      AdminSection.staff => const AdminAccountsScreen(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final scope = AdminGameScope.maybeOf(context)!;
    final game = AdminGameScope.gameOf(context);
    if (game.id == GameIds.lunoBilgi) {
      return BilgiAdminScreen(onLeave: widget.onLeave);
    }
    final sections = game.menuSections;
    final index = _index.clamp(0, sections.length - 1);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final sidebar = AdminGameSidebar(
      game: game,
      sections: sections,
      selected: index,
      account: scope.account,
      onLeave: widget.onLeave,
      onSelect: (i) {
        setState(() => _index = i);
        _scaffoldKey.currentState?.closeDrawer();
      },
    );
    return AdminLocaleScope(
      locale: _locale,
      league: _league,
      listLength: _listLength,
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: AdminHubColors.bg,
        drawer: wide
            ? null
            : Drawer(
                backgroundColor: AdminHubColors.bar,
                child: sidebar,
              ),
        body: Row(
          children: [
            if (wide) sidebar,
            Expanded(
              child: Column(
                children: [
                  AdminGameTopBar(
                    game: game,
                    onLeave: widget.onLeave,
                    showMenu: wide
                        ? null
                        : () => _scaffoldKey.currentState?.openDrawer(),
                    locale: game.localeFilter ? _locale : null,
                    onLocale: game.localeFilter
                        ? (next) => setState(() => _locale = next)
                        : null,
                    league: game.leagueFilter ? _league : null,
                    listLength: _listLength,
                    onLeagueLength: game.leagueFilter
                        ? (length) {
                            setState(() {
                              final tier = LeagueTier.values
                                  .where((item) => item.wordLength == length)
                                  .firstOrNull;
                              if (tier == null) {
                                _listLength = length;
                                final words = sections.indexOf(
                                  AdminSection.words,
                                );
                                if (words >= 0) _index = words;
                              } else {
                                _listLength = null;
                                _league = tier;
                              }
                            });
                          }
                        : null,
                  ),
                  Expanded(
                    child: KeyedSubtree(
                      key: ValueKey(
                        '${game.id}-$_locale-${_league.name}-$index',
                      ),
                      child: _page(sections[index]),
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
