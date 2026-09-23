import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/utils/password_hash.dart';

class AdminAccount {
  const AdminAccount({required this.id, required this.email});

  final String id;
  final String email;

  factory AdminAccount.fromJson(Map<String, dynamic> json) {
    return AdminAccount(
      id: json['id'] as String,
      email: json['email'] as String,
    );
  }
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
  Future<List<AdminAccount>> list(String token);
  Future<AdminAccount> create(
    String token, {
    required String email,
    required String password,
  });
  Future<AdminAccount> update(
    String token,
    String id, {
    String? email,
    String? password,
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
    required String email,
    required String password,
  }) async {
    final body = await _send('POST', '/v1/admin/users', token: token, body: {
      'email': email,
      'password': password,
    });
    return AdminAccount.fromJson(body);
  }

  @override
  Future<AdminAccount> update(
    String token,
    String id, {
    String? email,
    String? password,
  }) async {
    final body = await _send('PATCH', '/v1/admin/users/$id', token: token, body: {
      if (email != null) 'email': email,
      if (password != null) 'password': password,
    });
    return AdminAccount.fromJson(body);
  }
}

class _StoredAdmin {
  _StoredAdmin({
    required this.id,
    required this.email,
    required this.salt,
    required this.passwordHash,
  });

  final String id;
  String email;
  String salt;
  String passwordHash;
}

/// In-memory directory for widget tests. Production uses [RemoteAdminDirectory].
class MemoryAdminDirectory implements AdminDirectory {
  MemoryAdminDirectory();

  factory MemoryAdminDirectory.seeded({
    required String email,
    required String password,
  }) {
    final directory = MemoryAdminDirectory();
    directory._add(email, password);
    return directory;
  }

  final _users = <_StoredAdmin>[];
  final _tokens = <String, String>{};
  var _n = 0;

  void _add(String email, String password) {
    final salt = 'salt-$_n';
    _users.add(
      _StoredAdmin(
        id: 'admin-$_n',
        email: PasswordHash.normalizeEmail(email),
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
    return _users.firstWhere((user) => user.id == id);
  }

  @override
  Future<bool> needsSetup() async => _users.isEmpty;

  @override
  Future<String> setup({required String email, required String password}) async {
    if (_users.isNotEmpty) {
      throw AdminAuthException('Yönetici hesabı zaten var.');
    }
    _add(email, password);
    return _issue(_users.single);
  }

  @override
  Future<String> login({required String email, required String password}) async {
    final normalized = PasswordHash.normalizeEmail(email);
    final user = _users.where((item) => item.email == normalized).firstOrNull;
    if (user == null || !PasswordHash.verify(password, user.salt, user.passwordHash)) {
      throw AdminAuthException('E-posta veya şifre hatalı.');
    }
    return _issue(user);
  }

  @override
  Future<List<AdminAccount>> list(String token) async {
    _require(token);
    return [for (final user in _users) AdminAccount(id: user.id, email: user.email)];
  }

  @override
  Future<AdminAccount> create(
    String token, {
    required String email,
    required String password,
  }) async {
    _require(token);
    final normalized = PasswordHash.normalizeEmail(email);
    if (_users.any((user) => user.email == normalized)) {
      throw AdminAuthException('Bu e-posta zaten kayıtlı.');
    }
    _add(email, password);
    final user = _users.last;
    return AdminAccount(id: user.id, email: user.email);
  }

  @override
  Future<AdminAccount> update(
    String token,
    String id, {
    String? email,
    String? password,
  }) async {
    _require(token);
    final user = _users.where((item) => item.id == id).firstOrNull;
    if (user == null) throw AdminAuthException('Yönetici bulunamadı.');
    if (email != null) {
      final normalized = PasswordHash.normalizeEmail(email);
      if (_users.any((item) => item.id != id && item.email == normalized)) {
        throw AdminAuthException('Bu e-posta zaten kayıtlı.');
      }
      user.email = normalized;
    }
    if (password != null && password.isNotEmpty) {
      user.salt = 'salt-$_n';
      _n++;
      user.passwordHash = PasswordHash.hash(password, user.salt);
    }
    return AdminAccount(id: user.id, email: user.email);
  }
}
