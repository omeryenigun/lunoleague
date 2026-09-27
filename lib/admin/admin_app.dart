import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_accounts_screen.dart';
import 'package:kelimelig/admin/admin_session.dart';
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/admin/admin_locale.dart';
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/admin/game_catalog.dart';
import 'package:kelimelig/admin/screens/fall_admin_screen.dart';
import 'package:kelimelig/admin/screens/grid_admin_screen.dart';
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
  String? _token;
  String? _gameId;

  @override
  void initState() {
    super.initState();
    final saved = readAdminToken();
    if (saved != null && saved.isNotEmpty) {
      _token = saved;
      _authed = true;
      _remember(saved);
    }
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final game = _gameId == null ? null : AdminGameCatalog.byId(_gameId!);
    return AdminGameScope(
      authed: _authed,
      directory: _directory,
      token: _token,
      game: game,
      server: _server,
      onAuthed: (token) {
        _remember(token);
        setState(() {
          _token = token;
          _authed = true;
        });
      },
      onOpenGame: _openGame,
      onLeaveGame: _closeGame,
      onSignOut: _signOut,
      child: MaterialApp(
        navigatorKey: _nav,
        title: 'Game Server Admin',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: const AdminEntry(),
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
      return AdminGate(
        directory: scope.directory,
        onSuccess: scope.onAuthed,
      );
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
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
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
                      Text(_error!, style: const TextStyle(color: AppColors.danger)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Oyunlar'),
            GameVersionLabel(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SiteCardsScreen()),
              );
            },
            child: const Text('Oyun kartları'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminAccountsScreen()),
              );
            },
            child: const Text('Yöneticiler'),
          ),
          TextButton(onPressed: onSignOut, child: const Text('Çıkış')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Her oyun kendi deposunu kullanır. Kullanıcı, kelime, lig ve mağaza kayıtları birbirine karışmaz.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final game in AdminGameCatalog.games) ...[
            _GameCard(game: game, onOpen: () => onOpen(game.id)),
            const SizedBox(height: 12),
          ],
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(game.icon, color: AppColors.accent),
              const SizedBox(width: 12),
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
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FilledButton(onPressed: onOpen, child: const Text('Yönet')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SiteCardForm(cardId: game.id),
                        ),
                      );
                    },
                    child: const Text('Vitrini Düzenle'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'İzole depo: ${game.storePrefix}*',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final section in game.sections)
                Chip(
                  label: Text(adminSectionInfo[section]!.label),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
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
  var _index = 0;
  var _locale = GameLocale.tr.id;
  var _league = LeagueTier.bronze;
  int? _listLength;

  Widget _page(AdminSection section) {
    final gameId = AdminGameScope.gameOf(context).id;
    if (gameId == GameIds.lunoFall) {
      return FallAdminScreen(section: section);
    }
    if (gameId == GameIds.lunoGrid) {
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
      };
  }

  @override
  Widget build(BuildContext context) {
    final game = AdminGameScope.gameOf(context);
    final sections = game.sections;
    final index = _index.clamp(0, sections.length - 1);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return AdminLocaleScope(
      locale: _locale,
      league: _league,
      listLength: _listLength,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(game.name),
              const GameVersionLabel(),
            ],
          ),
          leading: IconButton(
            tooltip: 'Oyunlara dön',
            icon: const Icon(Icons.arrow_back),
            onPressed: widget.onLeave,
          ),
          actions: [
            if (game.leagueFilter)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SegmentedButton<int>(
                  segments: [
                    for (final length in const [3, 4])
                      ButtonSegment(
                        value: length,
                        label: Text('$length'),
                        tooltip: '$length harf',
                      ),
                    for (final tier in LeagueTier.values)
                      ButtonSegment(
                        value: tier.wordLength,
                        label: Text(tier.label),
                        tooltip: '${tier.label} (${tier.wordLength} harf)',
                      ),
                  ],
                  selected: {_listLength ?? _league.wordLength},
                  onSelectionChanged: (next) {
                    final length = next.first;
                    setState(() {
                      final tier = LeagueTier.values
                          .where((item) => item.wordLength == length)
                          .firstOrNull;
                      if (tier == null) {
                        _listLength = length;
                        final words = sections.indexOf(AdminSection.words);
                        if (words >= 0) _index = words;
                      } else {
                        _listLength = null;
                        _league = tier;
                      }
                    });
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            if (game.localeFilter)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: DropdownButton<String>(
                  value: _locale,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final loc in GameLocale.all)
                      DropdownMenuItem(
                        value: loc.id,
                        child: Text('${loc.id.toUpperCase()}  ${loc.nativeName}'),
                      ),
                  ],
                  onChanged: (next) {
                    if (next == null) return;
                    setState(() => _locale = next);
                  },
                ),
              ),
          ],
        ),
        drawer: wide
            ? null
            : Drawer(
                child: ListView(
                  children: [
                    DrawerHeader(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            game.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Depo ${game.storePrefix}*',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    for (var i = 0; i < sections.length; i++)
                      ListTile(
                        leading: Icon(adminSectionInfo[sections[i]]!.icon),
                        title: Text(adminSectionInfo[sections[i]]!.label),
                        selected: index == i,
                        onTap: () {
                          setState(() => _index = i);
                          Navigator.pop(context);
                        },
                      ),
                  ],
                ),
              ),
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: AppColors.surface,
                destinations: [
                  for (final section in sections)
                    NavigationRailDestination(
                      icon: Icon(adminSectionInfo[section]!.icon),
                      selectedIcon: Icon(adminSectionInfo[section]!.selectedIcon),
                      label: Text(adminSectionInfo[section]!.label),
                    ),
                ],
              ),
            Expanded(
              child: KeyedSubtree(
                key: ValueKey('${game.id}-$_locale-${_league.name}-$index'),
                child: _page(sections[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
