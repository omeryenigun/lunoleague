import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _random = Random.secure();

void mountAdminApi(Router router, Connection db) {
  router
    ..get('/v1/admin/status', (_) async {
      final count = await _count(db);
      return _json({'needsSetup': count == 0});
    })
    ..post('/v1/admin/setup', (request) async {
      if (await _count(db) != 0) {
        return _error(409, 'Yönetici hesabı zaten var.');
      }
      final body = await _body(request);
      final email = _email(body['email']);
      final password = _password(body['password']);
      if (email == null || password == null) {
        return _error(400, 'Geçerli e-posta ve en az 8 karakterlik şifre gerekli.');
      }
      final account = await _insert(db, email, password);
      final token = await _session(db, account.id);
      return _json({'token': token, 'id': account.id, 'email': account.email});
    })
    ..post('/v1/admin/login', (request) async {
      final body = await _body(request);
      final email = _email(body['email']);
      final password = body['password'];
      if (email == null || password is! String) {
        return _error(401, 'E-posta veya şifre hatalı.');
      }
      final rows = await db.execute(
        Sql.named(
          'select id, password_hash, salt from admin_users where email = @email',
        ),
        parameters: {'email': email},
      );
      if (rows.isEmpty) return _error(401, 'E-posta veya şifre hatalı.');
      final id = rows.first[0] as String;
      final expected = rows.first[1] as String;
      final salt = rows.first[2] as String;
      if (_hash(password, salt) != expected) {
        return _error(401, 'E-posta veya şifre hatalı.');
      }
      final token = await _session(db, id);
      return _json({'token': token, 'id': id, 'email': email});
    })
    ..get('/v1/admin/users', (request) async {
      if (await adminIdOf(db, request) == null) return _error(401, 'Oturum geçersiz.');
      final rows = await db.execute(
        'select id, email from admin_users order by created_at',
      );
      return _json({
        'users': [
          for (final row in rows) {'id': row[0], 'email': row[1]},
        ],
      });
    })
    ..post('/v1/admin/users', (request) async {
      if (await adminIdOf(db, request) == null) return _error(401, 'Oturum geçersiz.');
      final body = await _body(request);
      final email = _email(body['email']);
      final password = _password(body['password']);
      if (email == null || password == null) {
        return _error(400, 'Geçerli e-posta ve en az 8 karakterlik şifre gerekli.');
      }
      try {
        final account = await _insert(db, email, password);
        return _json({'id': account.id, 'email': account.email});
      } on ServerException catch (e) {
        if (e.code == '23505') return _error(409, 'Bu e-posta zaten kayıtlı.');
        rethrow;
      }
    })
    ..patch('/v1/admin/users/<id>', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) return _error(401, 'Oturum geçersiz.');
      final body = await _body(request);
      final email = body['email'] == null ? null : _email(body['email']);
      if (body['email'] != null && email == null) {
        return _error(400, 'Geçerli bir e-posta gir.');
      }
      final password = body['password'];
      if (password != null && password is! String) {
        return _error(400, 'Şifre geçersiz.');
      }
      if (password is String && password.isNotEmpty && password.length < 8) {
        return _error(400, 'Şifre en az 8 karakter olmalı.');
      }
      final existing = await db.execute(
        Sql.named('select id from admin_users where id = @id'),
        parameters: {'id': id},
      );
      if (existing.isEmpty) return _error(404, 'Yönetici bulunamadı.');
      if (email != null) {
        try {
          await db.execute(
            Sql.named('update admin_users set email = @email where id = @id'),
            parameters: {'email': email, 'id': id},
          );
        } on ServerException catch (e) {
          if (e.code == '23505') return _error(409, 'Bu e-posta zaten kayıtlı.');
          rethrow;
        }
      }
      if (password is String && password.isNotEmpty) {
        final salt = _id();
        await db.execute(
          Sql.named(
            'update admin_users set password_hash = @hash, salt = @salt where id = @id',
          ),
          parameters: {
            'hash': _hash(password, salt),
            'salt': salt,
            'id': id,
          },
        );
      }
      final rows = await db.execute(
        Sql.named('select id, email from admin_users where id = @id'),
        parameters: {'id': id},
      );
      return _json({'id': rows.first[0], 'email': rows.first[1]});
    });
}

Future<void> migrateAdmin(Connection db) async {
  await db.execute('''
    create table if not exists admin_users (
      id text primary key,
      email text not null unique,
      password_hash text not null,
      salt text not null,
      created_at timestamptz not null default now()
    )
  ''');
  await db.execute('''
    create table if not exists admin_sessions (
      token_hash text primary key,
      admin_id text not null references admin_users(id) on delete cascade,
      expires_at timestamptz not null
    )
  ''');
}

Response jsonResponse(Object body, {int status = 200}) => Response(
      status,
      body: jsonEncode(body),
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Response _json(Object body) => jsonResponse(body);

Response _error(int status, String message, [String? code]) => jsonResponse(
      {'error': message, 'code': ?code},
      status: status,
    );

Future<Map<String, dynamic>> readJson(Request request) async {
  final raw = await request.readAsString();
  if (raw.isEmpty) return {};
  final decoded = jsonDecode(raw);
  if (decoded is Map<String, dynamic>) return decoded;
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {};
}

Future<Map<String, dynamic>> _body(Request request) => readJson(request);

String? _email(Object? value) {
  if (value is! String) return null;
  final email = value.trim().toLowerCase();
  if (!_emailRe.hasMatch(email)) return null;
  return email;
}

String? _password(Object? value) {
  if (value is! String || value.length < 8) return null;
  return value;
}

String _id() {
  final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _hash(String password, String salt) {
  var digest = sha256.convert(utf8.encode('$salt::$password::luno-admin'));
  for (var i = 0; i < 12000; i++) {
    digest = sha256.convert(digest.bytes);
  }
  return digest.toString();
}

Future<int> _count(Connection db) async {
  final rows = await db.execute('select count(*) from admin_users');
  final value = rows.first[0];
  if (value is int) return value;
  return int.parse('$value');
}

class _Account {
  const _Account(this.id, this.email);
  final String id;
  final String email;
}

Future<_Account> _insert(Connection db, String email, String password) async {
  final id = _id();
  final salt = _id();
  await db.execute(
    Sql.named('''
      insert into admin_users (id, email, password_hash, salt)
      values (@id, @email, @hash, @salt)
    '''),
    parameters: {
      'id': id,
      'email': email,
      'hash': _hash(password, salt),
      'salt': salt,
    },
  );
  return _Account(id, email);
}

Future<String> _session(Connection db, String adminId) async {
  final token = _id() + _id();
  final hash = sha256.convert(utf8.encode(token)).toString();
  await db.execute(
    Sql.named('''
      insert into admin_sessions (token_hash, admin_id, expires_at)
      values (@hash, @adminId, now() + interval '14 days')
    '''),
    parameters: {'hash': hash, 'adminId': adminId},
  );
  return token;
}

String? bearerToken(Request request) {
  final header = request.headers['authorization'];
  if (header == null || !header.toLowerCase().startsWith('bearer ')) return null;
  final token = header.substring(7).trim();
  if (token.isEmpty) return null;
  return token;
}

String tokenHash(String token) => sha256.convert(utf8.encode(token)).toString();

Future<String?> adminIdOf(Connection db, Request request) async {
  final token = bearerToken(request);
  if (token == null) return null;
  final rows = await db.execute(
    Sql.named('''
      select admin_id from admin_sessions
      where token_hash = @hash and expires_at > now()
    '''),
    parameters: {'hash': tokenHash(token)},
  );
  if (rows.isEmpty) return null;
  return rows.first[0] as String;
}

String newToken() => _id() + _id();
