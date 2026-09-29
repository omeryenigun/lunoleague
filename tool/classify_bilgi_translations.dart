// Classify incomplete Bilgi translations on live API.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:postgres/postgres.dart';

const _api = 'https://api-production-bf3c9.up.railway.app';
const _locales = ['en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl'];

Future<void> main() async {
  final databaseUrl = Platform.environment['DATABASE_URL'];
  if (databaseUrl == null || databaseUrl.isEmpty) {
    stderr.writeln('DATABASE_URL missing');
    exitCode = 1;
    return;
  }
  final db = await _open(databaseUrl);
  late final String token;
  try {
    token = await _mint(db);
  } finally {
    await db.close();
  }
  final response = await http.get(
    Uri.parse('$_api/v1/admin/bilgi-questions'),
    headers: {'authorization': 'Bearer $token'},
  );
  if (response.statusCode != 200) {
    stderr.writeln('load_failed ${response.statusCode}');
    exitCode = 1;
    return;
  }
  final decoded = jsonDecode(response.body);
  if (decoded is! Map || decoded['questions'] is! List) {
    stderr.writeln('bad_body');
    exitCode = 1;
    return;
  }
  final questions = [
    for (final item in decoded['questions'] as List)
      if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
  ];

  var empty = 0, partial = 0, ready = 0, noTr = 0;
  final byStatusEmpty = <String, int>{};
  final byStatusPartial = <String, int>{};
  final recentPrefixes = <String, int>{};
  for (final q in questions) {
    if (!bilgiLanguageFieldsReady(q.text, q.options, q.explanation)) {
      noTr += 1;
      continue;
    }
    if (bilgiQuestionLanguagesReady(q)) {
      ready += 1;
      continue;
    }
    var filled = 0;
    for (final loc in _locales) {
      final row = q.translations[loc];
      if (row != null && bilgiLanguageFieldsReady(row.text, row.options, row.explanation)) {
        filled += 1;
      }
    }
    final prefix = q.id.length >= 16 ? q.id.substring(0, 16) : q.id;
    recentPrefixes[prefix] = (recentPrefixes[prefix] ?? 0) + 1;
    if (filled == 0) {
      empty += 1;
      byStatusEmpty[q.status] = (byStatusEmpty[q.status] ?? 0) + 1;
    } else {
      partial += 1;
      byStatusPartial[q.status] = (byStatusPartial[q.status] ?? 0) + 1;
      stdout.writeln('partial id=${q.id} status=${q.status} filled=$filled/${_locales.length}');
    }
  }
  stdout.writeln('ready=$ready empty=$empty partial=$partial no_tr=$noTr total=${questions.length}');
  stdout.writeln('empty_by_status=$byStatusEmpty');
  stdout.writeln('partial_by_status=$byStatusPartial');
  final top = recentPrefixes.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  for (final e in top.take(15)) {
    stdout.writeln('prefix ${e.key} count=${e.value}');
  }
}

Future<String> _mint(Connection db) async {
  final rows = await db.execute(
    "select id from admin_users where status = 'active' order by last_login_at desc nulls last limit 1",
  );
  if (rows.isEmpty) throw StateError('no admin');
  final adminId = rows.first[0] as String;
  final token = _id() + _id();
  final hash = sha256.convert(utf8.encode(token)).toString();
  await db.execute(
    Sql.named('''
      insert into admin_sessions (token_hash, admin_id, expires_at)
      values (@hash, @adminId, now() + interval '2 hours')
    '''),
    parameters: {'hash': hash, 'adminId': adminId},
  );
  return token;
}

Future<Connection> _open(String databaseUrl) async {
  final uri = Uri.parse(databaseUrl);
  final userInfo = uri.userInfo.split(':');
  final tunnelPort = int.tryParse(Platform.environment['LOCAL_PG_PORT'] ?? '');
  return Connection.open(
    Endpoint(
      host: tunnelPort != null ? '127.0.0.1' : uri.host,
      port: tunnelPort ?? (uri.hasPort ? uri.port : 5432),
      database: uri.pathSegments.isEmpty ? 'railway' : uri.pathSegments.first,
      username: Uri.decodeComponent(userInfo.first),
      password: Uri.decodeComponent(userInfo.skip(1).join(':')),
    ),
    settings: const ConnectionSettings(sslMode: SslMode.disable),
  );
}

String _id() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
