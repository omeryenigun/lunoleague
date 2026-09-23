import 'package:flutter/material.dart';
import 'package:kelimelig/admin/admin_directory.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/utils/password_hash.dart';

class AdminAccountsScreen extends StatefulWidget {
  const AdminAccountsScreen({super.key});

  @override
  State<AdminAccountsScreen> createState() => _AdminAccountsScreenState();
}

class _AdminAccountsScreenState extends State<AdminAccountsScreen> {
  Future<List<AdminAccount>>? _future;

  AdminDirectory _directory(BuildContext context) {
    return context.getInheritedWidgetOfExactType<AdminGameScope>()!.directory;
  }

  String _token(BuildContext context) {
    final token = context.getInheritedWidgetOfExactType<AdminGameScope>()!.token;
    if (token == null || token.isEmpty) {
      throw AdminAuthException('Oturum geçersiz.');
    }
    return token;
  }

  Future<List<AdminAccount>> _load() {
    return _directory(context).list(_token(context));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _edit(AdminAccount account) async {
    final email = TextEditingController(text: account.email);
    final password = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yöneticiyi değiştir'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni şifre (boşsa aynı kalır)',
                ),
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
    if (saved != true || !mounted) {
      email.dispose();
      password.dispose();
      return;
    }
    final nextEmail = email.text.trim();
    final nextPassword = password.text;
    email.dispose();
    password.dispose();
    if (!PasswordHash.isValidEmail(nextEmail)) {
      _show('Geçerli bir e-posta gir.');
      return;
    }
    if (nextPassword.isNotEmpty && nextPassword.length < 8) {
      _show('Şifre en az 8 karakter olmalı.');
      return;
    }
    try {
      await _directory(context).update(
        _token(context),
        account.id,
        email: nextEmail,
        password: nextPassword.isEmpty ? null : nextPassword,
      );
      _reload();
    } on AdminAuthException catch (e) {
      _show(e.message);
    }
  }

  Future<void> _create() async {
    final email = TextEditingController();
    final password = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Yönetici ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'E-posta'),
              ),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Şifre'),
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
              child: const Text('Ekle'),
            ),
          ],
        );
      },
    );
    if (saved != true || !mounted) {
      email.dispose();
      password.dispose();
      return;
    }
    final nextEmail = email.text.trim();
    final nextPassword = password.text;
    email.dispose();
    password.dispose();
    if (!PasswordHash.isValidEmail(nextEmail) || nextPassword.length < 8) {
      _show('E-posta ve en az 8 karakterlik şifre gerekli.');
      return;
    }
    try {
      await _directory(context).create(
        _token(context),
        email: nextEmail,
        password: nextPassword,
      );
      _reload();
    } on AdminAuthException catch (e) {
      _show(e.message);
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yöneticiler'),
        actions: [
          IconButton(onPressed: _create, icon: const Icon(Icons.person_add)),
        ],
      ),
      body: FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final users = snap.data!;
          if (users.isEmpty) {
            return const Center(
              child: Text('Yönetici yok', style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          return ListView(
            children: [
              for (final user in users)
                ListTile(
                  title: Text(user.email),
                  subtitle: const Text('E-posta ve şifre değiştirilebilir'),
                  trailing: const Icon(Icons.edit),
                  onTap: () => _edit(user),
                ),
            ],
          );
        },
      ),
    );
  }
}
