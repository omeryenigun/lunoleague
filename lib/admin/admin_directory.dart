import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/utils/password_hash.dart';
import 'package:kelimelig/domain/game/game_ids.dart';

enum AdminRole {
  superAdmin('super_admin', 'Süper Admin'),
  editor('editor', 'İçerik Editörü'),
  moderator('moderator', 'Moderatör');

  const AdminRole(this.id, this.label);
  final String id;
  final String label;

  static AdminRole parse(Object? value) {
    final id = value is String ? value : '';
    return AdminRole.values.where((role) => role.id == id).firstOrNull ??
        AdminRole.superAdmin;
  }
}

enum AdminAccountStatus {
  active('active', 'Aktif'),
  disabled('disabled', 'Devre dışı');

  const AdminAccountStatus(this.id, this.label);
  final String id;
  final String label;

  static AdminAccountStatus parse(Object? value) {
    final id = value is String ? value : '';
    return AdminAccountStatus.values
            .where((status) => status.id == id)
            .firstOrNull ??
        AdminAccountStatus.active;
  }
}

class AdminAccount {
  const AdminAccount({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.gameIds,
    required this.status,
    this.lastLoginAt,
  });

  final String id;
  final String email;
  final String name;
  final AdminRole role;
  final List<String> gameIds;
  final AdminAccountStatus status;
  final DateTime? lastLoginAt;

  bool get isSuperAdmin => role == AdminRole.superAdmin;
  bool get isActive => status == AdminAccountStatus.active;

  bool canEditGame(String gameId) => isSuperAdmin || gameIds.contains(gameId);

  String get displayName {
    final trimmed = name.trim();
    if (trimmed.isNotEmpty) return trimmed;
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    return AdminAccount(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String? ?? '',
      role: AdminRole.parse(json['role']),
      gameIds: _stringList(json['gameIds']),
      status: AdminAccountStatus.parse(json['status']),
      lastLoginAt: _time(json['lastLoginAt']),
    );
  }
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.isNotEmpty) item,
  ];
}

DateTime? _time(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
  return null;
}

class AdminAuthException implements Exception {
  AdminAuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Live admin operators. The first account is created in the panel, not in code.
abstract class AdminDirectory {
  Future<bool> needsSetup();
  Future<String> setup({required String email, required String password});
  Future<String> login({required String email, required String password});
  Future<AdminAccount> me(String token);
  Future<List<AdminAccount>> list(String token);
  Future<AdminAccount> create(
    String token, {
    required String name,
    required String email,
    required String password,
    required AdminRole role,
    required List<String> gameIds,
  });
  Future<AdminAccount> update(
    String token,
    String id, {
    String? name,
    String? email,
    String? password,
    AdminRole? role,
    List<String>? gameIds,
    AdminAccountStatus? status,
  });
}

class RemoteAdminDirectory implements AdminDirectory {
  RemoteAdminDirectory(String baseUrl)
      : _root = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final String _root;

  Uri _uri(String path) => Uri.parse('$_root$path');

  Map<String, String> _headers(String? token) => {
        'content-type': 'application/json; charset=utf-8',
        if (token != null) 'authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = _headers(token);
    final encoded = body == null ? null : jsonEncode(body);
    final response = switch (method) {
      'GET' => await http.get(_uri(path), headers: headers),
      'POST' => await http.post(_uri(path), headers: headers, body: encoded),
      'PATCH' => await http.patch(_uri(path), headers: headers, body: encoded),
      _ => throw StateError(method),
    };
    final raw = response.body;
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    final map = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
    if (response.statusCode >= 400) {
      throw AdminAuthException(
        map['error'] as String? ?? 'Yönetim isteği başarısız.',
      );
    }
    return map;
  }

  @override
  Future<bool> needsSetup() async {
    final body = await _send('GET', '/v1/admin/status');
    return body['needsSetup'] == true;
  }

  @override
  Future<String> setup({required String email, required String password}) async {
    final body = await _send('POST', '/v1/admin/setup', body: {
      'email': email,
      'password': password,
    });
    return body['token'] as String;
  }

  @override
  Future<String> login({required String email, required String password}) async {
    final body = await _send('POST', '/v1/admin/login', body: {
      'email': email,
      'password': password,
    });
    return body['token'] as String;
  }

  @override
  Future<AdminAccount> me(String token) async {
    final body = await _send('GET', '/v1/admin/me', token: token);
    return AdminAccount.fromJson(body);
  }

  @override
  Future<List<AdminAccount>> list(String token) async {
    final body = await _send('GET', '/v1/admin/users', token: token);
    final users = body['users'];
    if (users is! List) return const [];
    return [
      for (final item in users)
        if (item is Map) AdminAccount.fromJson(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<AdminAccount> create(
    String token, {
    required String name,
    required String email,
    required String password,
    required AdminRole role,
    required List<String> gameIds,
  }) async {
    final body = await _send('POST', '/v1/admin/users', token: token, body: {
      'name': name,
      'email': email,
      'password': password,
      'role': role.id,
      'gameIds': gameIds,
    });
    return AdminAccount.fromJson(body);
  }

  @override
  Future<AdminAccount> update(
    String token,
    String id, {
    String? name,
    String? email,
    String? password,
    AdminRole? role,
    List<String>? gameIds,
    AdminAccountStatus? status,
  }) async {
    final body = await _send('PATCH', '/v1/admin/users/$id', token: token, body: {
      'name': ?name,
      'email': ?email,
      'password': ?password,
      'role': ?role?.id,
      'gameIds': ?gameIds,
      'status': ?status?.id,
    });
    return AdminAccount.fromJson(body);
  }
}

class _StoredAdmin {
  _StoredAdmin({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.gameIds,
    required this.status,
    required this.salt,
    required this.passwordHash,
  });

  final String id;
  String email;
  String name;
  AdminRole role;
  List<String> gameIds;
  AdminAccountStatus status;
  String salt;
  String passwordHash;
  DateTime? lastLoginAt;

  AdminAccount get asAccount => AdminAccount(
        id: id,
        email: email,
        name: name,
        role: role,
        gameIds: List<String>.from(gameIds),
        status: status,
        lastLoginAt: lastLoginAt,
      );
}

/// In-memory directory for widget tests. Production uses [RemoteAdminDirectory].
class MemoryAdminDirectory implements AdminDirectory {
  MemoryAdminDirectory();

  factory MemoryAdminDirectory.seeded({
    required String email,
    required String password,
  }) {
    final directory = MemoryAdminDirectory();
    directory._add(
      email: email,
      password: password,
      name: '',
      role: AdminRole.superAdmin,
      gameIds: const [],
    );
    return directory;
  }

  final _users = <_StoredAdmin>[];
  final _tokens = <String, String>{};
  var _n = 0;

  void _add({
    required String email,
    required String password,
    required String name,
    required AdminRole role,
    required List<String> gameIds,
  }) {
    final salt = 'salt-$_n';
    _users.add(
      _StoredAdmin(
        id: 'admin-$_n',
        email: PasswordHash.normalizeEmail(email),
        name: name.trim(),
        role: role,
        gameIds: List<String>.from(gameIds),
        status: AdminAccountStatus.active,
        salt: salt,
        passwordHash: PasswordHash.hash(password, salt),
      ),
    );
    _n++;
  }

  String _issue(_StoredAdmin user) {
    final token = 'token-${user.id}-$_n';
    _n++;
    _tokens[token] = user.id;
    return token;
  }

  _StoredAdmin _require(String token) {
    final id = _tokens[token];
    if (id == null) throw AdminAuthException('Oturum geçersiz.');
    final user = _users.where((item) => item.id == id).firstOrNull;
    if (user == null || !user.status.isActive) {
      throw AdminAuthException('Oturum geçersiz.');
    }
    return user;
  }

  bool _lastActiveSuper(_StoredAdmin user) {
    if (user.role != AdminRole.superAdmin ||
        user.status != AdminAccountStatus.active) {
      return false;
    }
    return !_users.any(
      (item) =>
          item.id != user.id &&
          item.role == AdminRole.superAdmin &&
          item.status == AdminAccountStatus.active,
    );
  }

  @override
  Future<bool> needsSetup() async => _users.isEmpty;

  @override
  Future<String> setup({required String email, required String password}) async {
    if (_users.isNotEmpty) {
      throw AdminAuthException('Yönetici hesabı zaten var.');
    }
    _add(
      email: email,
      password: password,
      name: '',
      role: AdminRole.superAdmin,
      gameIds: const [],
    );
    return _issue(_users.single);
  }

  @override
  Future<String> login({required String email, required String password}) async {
    final normalized = PasswordHash.normalizeEmail(email);
    final user = _users.where((item) => item.email == normalized).firstOrNull;
    if (user == null ||
        user.status != AdminAccountStatus.active ||
        !PasswordHash.verify(password, user.salt, user.passwordHash)) {
      throw AdminAuthException('E-posta veya şifre hatalı.');
    }
    user.lastLoginAt = DateTime.now();
    return _issue(user);
  }

  @override
  Future<AdminAccount> me(String token) async => _require(token).asAccount;

  @override
  Future<List<AdminAccount>> list(String token) async {
    _require(token);
    return [for (final user in _users) user.asAccount];
  }

  @override
  Future<AdminAccount> create(
    String token, {
    required String name,
    required String email,
    required String password,
    required AdminRole role,
    required List<String> gameIds,
  }) async {
    _require(token);
    final normalized = PasswordHash.normalizeEmail(email);
    if (_users.any((user) => user.email == normalized)) {
      throw AdminAuthException('Bu e-posta zaten kayıtlı.');
    }
    _add(
      email: email,
      password: password,
      name: name,
      role: role,
      gameIds: _knownGames(gameIds),
    );
    return _users.last.asAccount;
  }

  @override
  Future<AdminAccount> update(
    String token,
    String id, {
    String? name,
    String? email,
    String? password,
    AdminRole? role,
    List<String>? gameIds,
    AdminAccountStatus? status,
  }) async {
    _require(token);
    final user = _users.where((item) => item.id == id).firstOrNull;
    if (user == null) throw AdminAuthException('Yönetici bulunamadı.');
    final nextRole = role ?? user.role;
    final nextStatus = status ?? user.status;
    if (_lastActiveSuper(user) &&
        (nextRole != AdminRole.superAdmin ||
            nextStatus != AdminAccountStatus.active)) {
      throw AdminAuthException('Son süper admin kaldırılamaz.');
    }
    if (name != null) user.name = name.trim();
    if (email != null) {
      final normalized = PasswordHash.normalizeEmail(email);
      if (_users.any((item) => item.id != id && item.email == normalized)) {
        throw AdminAuthException('Bu e-posta zaten kayıtlı.');
      }
      user.email = normalized;
    }
    if (role != null) user.role = role;
    if (gameIds != null) user.gameIds = _knownGames(gameIds);
    if (status != null) user.status = status;
    if (password != null && password.isNotEmpty) {
      user.salt = 'salt-$_n';
      _n++;
      user.passwordHash = PasswordHash.hash(password, user.salt);
    }
    return user.asAccount;
  }
}

extension on AdminAccountStatus {
  bool get isActive => this == AdminAccountStatus.active;
}

List<String> _knownGames(List<String> ids) {
  return [for (final id in ids) if (GameIds.all.contains(id)) id];
}
