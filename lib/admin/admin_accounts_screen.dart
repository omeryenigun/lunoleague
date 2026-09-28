import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/admin/admin_hub.dart';
import 'package:kelimelig/admin/game_catalog.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/core/utils/password_hash.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key, this.hub = false});

  final bool hub;

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  Future<List<AdminAccount>>? _future;

  AdminGameScope get _scope =>
      context.getInheritedWidgetOfExactType<AdminGameScope>()!;

  AdminDirectory get _directory => _scope.directory;

  String _token() {
    final token = _scope.token;
    if (token == null || token.isEmpty) {
      throw AdminAuthException('Oturum geçersiz.');
    }
    return token;
  }

  Future<List<AdminAccount>> _load() => _directory.list(_token());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    final draft = await _staffForm();
    if (draft == null || !mounted) return;
    if (!PasswordHash.isValidEmail(draft.email) || draft.password.length < 8) {
      _show('E-posta ve en az 8 karakterlik şifre gerekli.');
      return;
    }
    if (draft.name.isEmpty) {
      _show('Ad gerekli.');
      return;
    }
    try {
      await _directory.create(
        _token(),
        name: draft.name,
        email: draft.email,
        password: draft.password,
        role: draft.role,
        gameIds: draft.gameIds,
      );
      _reload();
    } on AdminAuthException catch (e) {
      _show(e.message);
    }
  }

  Future<void> _edit(AdminAccount account) async {
    final draft = await _staffForm(account);
    if (draft == null || !mounted) return;
    try {
      await _directory.update(
        _token(),
        account.id,
        name: draft.name,
        role: draft.role,
        gameIds: draft.gameIds,
        status: draft.status,
      );
      _reload();
    } on AdminAuthException catch (e) {
      _show(e.message);
    }
  }

  Future<void> _setPassword(AdminAccount account) async {
    final password = TextEditingController();
    final again = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AdminHubColors.card,
          title: const Text('Yeni şifre'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Yeni şifre'),
              ),
              TextField(
                controller: again,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Şifre tekrar'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Vazgeç'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Kaydet'),
            ),
          ],
        );
      },
    );
    final next = password.text;
    final confirm = again.text;
    password.dispose();
    again.dispose();
    if (saved != true || !mounted) return;
    if (next.length < 8) {
      _show('Şifre en az 8 karakter olmalı.');
      return;
    }
    if (next != confirm) {
      _show('Şifreler aynı değil.');
      return;
    }
    try {
      await _directory.update(_token(), account.id, password: next);
      _reload();
    } on AdminAuthException catch (e) {
      _show(e.message);
    }
  }

  Future<_StaffDraft?> _staffForm([AdminAccount? account]) async {
    final name = TextEditingController(text: account?.name ?? '');
    final email = TextEditingController(text: account?.email ?? '');
    final password = TextEditingController();
    var role = account?.role ?? AdminRole.editor;
    var status = account?.status ?? AdminAccountStatus.active;
    final selected = <String>{
      if (account != null && !account.isSuperAdmin) ...account.gameIds,
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialog) {
            return AlertDialog(
              backgroundColor: AdminHubColors.card,
              title: Text(account == null ? 'Yeni Yönetici' : 'Yetkileri düzenle'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: name,
                        decoration: const InputDecoration(labelText: 'Ad'),
                      ),
                      if (account == null) ...[
                        TextField(
                          controller: email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: 'E-posta'),
                        ),
                        TextField(
                          controller: password,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Şifre'),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DropdownButtonFormField<AdminRole>(
                        key: ValueKey(role),
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Rol'),
                        items: [
                          for (final item in AdminRole.values)
                            DropdownMenuItem(
                              value: item,
                              child: Text(item.label),
                            ),
                        ],
                        onChanged: (next) {
                          if (next == null) return;
                          setDialog(() => role = next);
                        },
                      ),
                      if (account != null) ...[
                        const SizedBox(height: 12),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Aktif'),
                          value: status == AdminAccountStatus.active,
                          onChanged: (on) {
                            setDialog(() {
                              status = on
                                  ? AdminAccountStatus.active
                                  : AdminAccountStatus.disabled;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 8),
                      const Text('Yönetebileceği oyunlar'),
                      if (role == AdminRole.superAdmin)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text(
                            'Süper admin her oyunu yönetir.',
                            style: TextStyle(color: AdminHubColors.muted),
                          ),
                        )
                      else
                        for (final game in AdminGameCatalog.games)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(game.name),
                            value: selected.contains(game.id),
                            onChanged: (on) {
                              setDialog(() {
                                if (on == true) {
                                  selected.add(game.id);
                                } else {
                                  selected.remove(game.id);
                                }
                              });
                            },
                          ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Vazgeç'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
    final draft = _StaffDraft(
      name: name.text.trim(),
      email: email.text.trim(),
      password: password.text,
      role: role,
      gameIds: role == AdminRole.superAdmin ? const [] : selected.toList(),
      status: status,
    );
    name.dispose();
    email.dispose();
    password.dispose();
    if (saved != true) return null;
    return draft;
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _lastLogin(DateTime? at) {
    if (at == null) return '';
    final local = at.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final table = FutureBuilder(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Text(
              '${snap.error}',
              style: const TextStyle(color: AdminHubColors.error),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final users = snap.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AdminHubColors.card),
                    headingTextStyle: const TextStyle(
                      color: AdminHubColors.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                    dataTextStyle: const TextStyle(color: Colors.white),
                    columns: const [
                      DataColumn(label: Text('YÖNETİCİ')),
                      DataColumn(label: Text('ROL')),
                      DataColumn(label: Text('SON GİRİŞ')),
                      DataColumn(label: Text('DURUM')),
                      DataColumn(label: Text('İŞLEM')),
                    ],
                    rows: [
                      for (final user in users)
                        DataRow(
                          cells: [
                            DataCell(
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: AdminHubColors.primary,
                                    child: Text(
                                      user.displayName.isEmpty
                                          ? '?'
                                          : user.displayName
                                              .substring(0, 1)
                                              .toUpperCase(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        user.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        user.email,
                                        style: const TextStyle(
                                          color: AdminHubColors.muted,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            DataCell(Text(user.role.label)),
                            DataCell(Text(_lastLogin(user.lastLoginAt))),
                            DataCell(
                              Text(
                                user.status.label,
                                style: TextStyle(
                                  color: user.isActive
                                      ? AdminHubColors.teal
                                      : AdminHubColors.muted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    tooltip: 'Düzenle',
                                    onPressed: () => _edit(user),
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                  ),
                                  IconButton(
                                    tooltip: 'Şifre',
                                    onPressed: () => _setPassword(user),
                                    icon: const Icon(Icons.vpn_key_outlined, size: 18),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    final body = ColoredBox(
      color: AdminHubColors.bg,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Yöneticiler',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Admin hesapları ve yetkileri',
                            style: TextStyle(color: AdminHubColors.muted),
                          ),
                        ],
                      ),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AdminHubColors.teal,
                        foregroundColor: const Color(0xFF042F2A),
                      ),
                      onPressed: _create,
                      child: const Text('+ Yeni Yönetici'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AdminHubColors.card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: table,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!widget.hub) {
      return body;
    }

    return Scaffold(
      backgroundColor: AdminHubColors.bg,
      body: Column(
        children: [
          AdminHubBar(
            active: AdminHubNav.staff,
            onGames: () => Navigator.of(context).pop(),
            onStaff: () {},
            onSignOut: _scope.onSignOut,
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _StaffDraft {
  const _StaffDraft({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.gameIds,
    required this.status,
  });

  final String name;
  final String email;
  final String password;
  final AdminRole role;
  final List<String> gameIds;
  final AdminAccountStatus status;
}
