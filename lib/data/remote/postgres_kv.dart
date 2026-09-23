import 'dart:convert';

import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:postgres/postgres.dart';

/// Shared boxes for every Luno League player. Callers that need a current
/// player wrap this with [SessionKv].
class PostgresKv implements KeyValueStore {
  PostgresKv(this._db);

  final Connection _db;
  Future<void> _queue = Future<void>.value();

  Future<T> _sync<T>(Future<T> Function() action) {
    final run = _queue.then((_) => action());
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  static Future<void> migrate(Connection db) async {
    await db.execute('''
      create table if not exists kv_entry (
        box text not null,
        item_key text not null,
        body jsonb not null,
        primary key (box, item_key)
      )
    ''');
    await db.execute('''
      create table if not exists kv_meta (
        item_key text primary key,
        value text not null
      )
    ''');
    await db.execute('''
      create table if not exists player_sessions (
        token_hash text primary key,
        user_id text,
        locale text,
        expires_at timestamptz not null
      )
    ''');
  }

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) {
    return _sync(() => _db.execute(
          Sql.named('''
            insert into kv_entry (box, item_key, body)
            values (@box, @key, @body::jsonb)
            on conflict (box, item_key) do update set body = excluded.body
          '''),
          parameters: {
            'box': box,
            'key': key,
            'body': jsonEncode(value),
          },
        ));
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) {
    return _sync(() async {
      final rows = await _db.execute(
        Sql.named(
          'select body from kv_entry where box = @box and item_key = @key',
        ),
        parameters: {'box': box, 'key': key},
      );
      if (rows.isEmpty) return null;
      return _object(rows.first[0]);
    });
  }

  @override
  Future<void> delete(String box, String key) {
    return _sync(() => _db.execute(
          Sql.named(
            'delete from kv_entry where box = @box and item_key = @key',
          ),
          parameters: {'box': box, 'key': key},
        ));
  }

  @override
  Future<List<Map<String, dynamic>>> values(String box) {
    return _sync(() async {
      final rows = await _db.execute(
        Sql.named('select body from kv_entry where box = @box'),
        parameters: {'box': box},
      );
      return [for (final row in rows) _object(row[0])];
    });
  }

  @override
  Future<void> putMeta(String key, String value) {
    return _sync(() => _db.execute(
          Sql.named('''
            insert into kv_meta (item_key, value)
            values (@key, @value)
            on conflict (item_key) do update set value = excluded.value
          '''),
          parameters: {'key': key, 'value': value},
        ));
  }

  @override
  Future<String?> getMeta(String key) {
    return _sync(() async {
      final rows = await _db.execute(
        Sql.named('select value from kv_meta where item_key = @key'),
        parameters: {'key': key},
      );
      if (rows.isEmpty) return null;
      return rows.first[0] as String?;
    });
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is String) {
      final decoded = jsonDecode(value);
      return Map<String, dynamic>.from(decoded as Map);
    }
    if (value is Map) return Map<String, dynamic>.from(value);
    throw StateError('Expected a JSON object');
  }
}
