import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _random = Random.secure();
const _roles = {'super_admin', 'editor', 'moderator'};
const _statuses = {'active', 'disabled'};

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
      final account = await _insert(
        db,
        email: email,
        password: password,
        name: '',
        role: 'super_admin',
        gameIds: const [],
      );
      final token = await _session(db, account.id);
      return _json({
        'token': token,
        ...account.toJson(),
      });
    })
    ..post('/v1/admin/login', (request) async {
      final body = await _body(request);
      final email = _email(body['email']);
      final password = body['password'];
      if (email == null || password is! String) {
        return _error(401, 'E-posta veya şifre hatalı.');
      }
      final rows = await db.execute(
        Sql.named('''
          select id, password_hash, salt, status
          from admin_users where email = @email
        '''),
        parameters: {'email': email},
      );
      if (rows.isEmpty) return _error(401, 'E-posta veya şifre hatalı.');
      final id = rows.first[0] as String;
      final expected = rows.first[1] as String;
      final salt = rows.first[2] as String;
      final status = rows.first[3] as String? ?? 'active';
      if (status != 'active' || _hash(password, salt) != expected) {
        return _error(401, 'E-posta veya şifre hatalı.');
      }
      await db.execute(
        Sql.named('update admin_users set last_login_at = now() where id = @id'),
        parameters: {'id': id},
      );
      final token = await _session(db, id);
      final account = await _loadAccount(db, id);
      return _json({'token': token, ...?account?.toJson()});
    })
    ..get('/v1/admin/me', (request) async {
      final id = await adminIdOf(db, request);
      if (id == null) return _error(401, 'Oturum geçersiz.');
      final account = await _loadAccount(db, id);
      if (account == null) return _error(401, 'Oturum geçersiz.');
      return _json(account.toJson());
    })
    ..get('/v1/admin/users', (request) async {
      if (await adminIdOf(db, request) == null) {
        return _error(401, 'Oturum geçersiz.');
      }
      final rows = await db.execute('''
        select id, email, display_name, role, game_ids, status, last_login_at
        from admin_users order by created_at
      ''');
      return _json({
        'users': [for (final row in rows) _rowAccount(row).toJson()],
      });
    })
    ..post('/v1/admin/users', (request) async {
      final actor = await _requireSuper(db, request);
      if (actor.id == null) return actor.error!;
      final body = await _body(request);
      final name = _name(body['name']);
      final email = _email(body['email']);
      final password = _password(body['password']);
      final role = _role(body['role']);
      final gameIds = _gameIds(body['gameIds']);
      if (name == null || email == null || password == null || role == null || gameIds == null) {
        return _error(400, 'Ad, geçerli e-posta, şifre, rol ve oyun yetkileri gerekli.');
      }
      try {
        final account = await _insert(
          db,
          email: email,
          password: password,
          name: name,
          role: role,
          gameIds: gameIds,
        );
        return _json(account.toJson());
      } on ServerException catch (e) {
        if (e.code == '23505') return _error(409, 'Bu e-posta zaten kayıtlı.');
        rethrow;
      }
    })
    ..patch('/v1/admin/users/<id>', (Request request, String id) async {
      final actor = await _requireSuper(db, request);
      if (actor.id == null) return actor.error!;
      final body = await _body(request);
      final name = body.containsKey('name') ? _name(body['name']) : null;
      if (body.containsKey('name') && name == null) {
        return _error(400, 'Ad gerekli.');
      }
      final email = body['email'] == null ? null : _email(body['email']);
      if (body['email'] != null && email == null) {
        return _error(400, 'Geçerli bir e-posta gir.');
      }
      final role = body['role'] == null ? null : _role(body['role']);
      if (body['role'] != null && role == null) {
        return _error(400, 'Rol geçersiz.');
      }
      final gameIds = body.containsKey('gameIds') ? _gameIds(body['gameIds']) : null;
      if (body.containsKey('gameIds') && gameIds == null) {
        return _error(400, 'Oyun yetkileri geçersiz.');
      }
      final status = body['status'] == null ? null : _status(body['status']);
      if (body['status'] != null && status == null) {
        return _error(400, 'Durum geçersiz.');
      }
      final password = body['password'];
      if (password != null && password is! String) {
        return _error(400, 'Şifre geçersiz.');
      }
      if (password is String && password.isNotEmpty && password.length < 8) {
        return _error(400, 'Şifre en az 8 karakter olmalı.');
      }
      final existing = await _loadAccount(db, id);
      if (existing == null) return _error(404, 'Yönetici bulunamadı.');
      final nextRole = role ?? existing.role;
      final nextStatus = status ?? existing.status;
      if (await _isLastActiveSuper(db, existing) &&
          (nextRole != 'super_admin' || nextStatus != 'active')) {
        return _error(400, 'Son süper admin kaldırılamaz.');
      }
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
      if (name != null) {
        await db.execute(
          Sql.named('update admin_users set display_name = @name where id = @id'),
          parameters: {'name': name, 'id': id},
        );
      }
      if (role != null) {
        await db.execute(
          Sql.named('update admin_users set role = @role where id = @id'),
          parameters: {'role': role, 'id': id},
        );
      }
      if (gameIds != null) {
        await db.execute(
          Sql.named('update admin_users set game_ids = @games where id = @id'),
          parameters: {'games': jsonEncode(gameIds), 'id': id},
        );
      }
      if (status != null) {
        await db.execute(
          Sql.named('update admin_users set status = @status where id = @id'),
          parameters: {'status': status, 'id': id},
        );
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
      final account = await _loadAccount(db, id);
      return _json(account!.toJson());
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
  await db.execute(
    "alter table admin_users add column if not exists display_name text not null default ''",
  );
  await db.execute(
    "alter table admin_users add column if not exists role text not null default 'super_admin'",
  );
  await db.execute(
    "alter table admin_users add column if not exists game_ids text not null default '[]'",
  );
  await db.execute(
    "alter table admin_users add column if not exists status text not null default 'active'",
  );
  await db.execute(
    'alter table admin_users add column if not exists last_login_at timestamptz',
  );
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

String? _name(Object? value) {
  if (value is! String) return null;
  final name = value.trim();
  if (name.isEmpty) return null;
  return name;
}

String? _role(Object? value) {
  if (value is! String || !_roles.contains(value)) return null;
  return value;
}

String? _status(Object? value) {
  if (value is! String || !_statuses.contains(value)) return null;
  return value;
}

List<String>? _gameIds(Object? value) {
  if (value == null) return const [];
  if (value is! List) return null;
  final ids = <String>[];
  for (final item in value) {
    if (item is! String || !GameIds.all.contains(item)) return null;
    ids.add(item);
  }
  return ids;
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
  const _Account({
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
  final String role;
  final List<String> gameIds;
  final String status;
  final DateTime? lastLoginAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role,
        'gameIds': gameIds,
        'status': status,
        'lastLoginAt': lastLoginAt?.toUtc().toIso8601String(),
      };
}

class _Actor {
  const _Actor(this.id, [this.error]);
  final String? id;
  final Response? error;
}

_Account _rowAccount(ResultRow row) {
  return _Account(
    id: row[0] as String,
    email: row[1] as String,
    name: row[2] as String? ?? '',
    role: row[3] as String? ?? 'super_admin',
    gameIds: _decodeGames(row[4]),
    status: row[5] as String? ?? 'active',
    lastLoginAt: row[6] is DateTime ? row[6] as DateTime : null,
  );
}

List<String> _decodeGames(Object? raw) {
  if (raw is List) {
    return [for (final item in raw) if (item is String) item];
  }
  if (raw is String && raw.isNotEmpty) {
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return [for (final item in decoded) if (item is String) item];
    }
  }
  return const [];
}

Future<_Account?> _loadAccount(Connection db, String id) async {
  final rows = await db.execute(
    Sql.named('''
      select id, email, display_name, role, game_ids, status, last_login_at
      from admin_users where id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return null;
  return _rowAccount(rows.first);
}

Future<bool> _isLastActiveSuper(Connection db, _Account user) async {
  if (user.role != 'super_admin' || user.status != 'active') return false;
  final rows = await db.execute(
    Sql.named('''
      select count(*) from admin_users
      where role = 'super_admin' and status = 'active' and id <> @id
    '''),
    parameters: {'id': user.id},
  );
  final value = rows.first[0];
  final others = value is int ? value : int.parse('$value');
  return others == 0;
}

Future<_Actor> _requireSuper(Connection db, Request request) async {
  final id = await adminIdOf(db, request);
  if (id == null) return _Actor(null, _error(401, 'Oturum geçersiz.'));
  final account = await _loadAccount(db, id);
  if (account == null) return _Actor(null, _error(401, 'Oturum geçersiz.'));
  if (account.role != 'super_admin') {
    return _Actor(null, _error(403, 'Bu işlem için süper admin gerekli.'));
  }
  return _Actor(id);
}

Future<_Account> _insert(
  Connection db, {
  required String email,
  required String password,
  required String name,
  required String role,
  required List<String> gameIds,
}) async {
  final id = _id();
  final salt = _id();
  await db.execute(
    Sql.named('''
      insert into admin_users (id, email, password_hash, salt, display_name, role, game_ids, status)
      values (@id, @email, @hash, @salt, @name, @role, @games, 'active')
    '''),
    parameters: {
      'id': id,
      'email': email,
      'hash': _hash(password, salt),
      'salt': salt,
      'name': name,
      'role': role,
      'games': jsonEncode(gameIds),
    },
  );
  return _Account(
    id: id,
    email: email,
    name: name,
    role: role,
    gameIds: gameIds,
    status: 'active',
  );
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
      select s.admin_id from admin_sessions s
      join admin_users u on u.id = s.admin_id
      where s.token_hash = @hash and s.expires_at > now() and u.status = 'active'
    '''),
    parameters: {'hash': tokenHash(token)},
  );
  if (rows.isEmpty) return null;
  return rows.first[0] as String;
}

String newToken() => _id() + _id();
