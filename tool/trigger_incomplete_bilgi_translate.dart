// One-off operational trigger: translate incomplete Bilgi questions on live API.
// Run: railway run --service api dart run tool/trigger_incomplete_bilgi_translate.dart
// Does not print secrets. Does not approve / delete.

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
    stderr.writeln('DATABASE_URL missing (use railway run --service api).');
    exitCode = 1;
    return;
  }

  final db = await _open(databaseUrl);
  late final String token;
  try {
    token = await _mintAdminSession(db);
  } finally {
    await db.close();
  }

  final questions = await _loadAll(token);
  if (questions == null) {
    stderr.writeln('Failed to load admin questions (auth or API).');
    exitCode = 1;
    return;
  }

  final pendingIncomplete = <BilgiQuestion>[];
  final anyIncomplete = <BilgiQuestion>[];
  for (final q in questions) {
    if (!bilgiLanguageFieldsReady(q.text, q.options, q.explanation)) continue;
    if (bilgiQuestionLanguagesReady(q)) continue;
    anyIncomplete.add(q);
    if (q.status == 'pending') pendingIncomplete.add(q);
  }

  // Prefer explicit IDS=comma-separated; else pending incomplete.
  // Cap with MAX_TRANSLATE (default 40) to avoid translating the whole bank.
  final idFilter = (Platform.environment['IDS'] ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet();
  final maxTranslate = int.tryParse(Platform.environment['MAX_TRANSLATE'] ?? '40') ?? 40;

  List<BilgiQuestion> incomplete;
  if (idFilter.isNotEmpty) {
    incomplete = [
      for (final q in questions)
        if (idFilter.contains(q.id) &&
            bilgiLanguageFieldsReady(q.text, q.options, q.explanation) &&
            !bilgiQuestionLanguagesReady(q))
          q,
    ];
  } else {
    incomplete = List<BilgiQuestion>.from(pendingIncomplete);
    if (incomplete.length > maxTranslate) {
      incomplete = incomplete.take(maxTranslate).toList();
    }
  }

  final byStatus = <String, int>{};
  for (final q in questions) {
    byStatus[q.status] = (byStatus[q.status] ?? 0) + 1;
  }
  final pendingReady = questions.where(bilgiPendingApprovalReady).length;
  stdout.writeln(
    'total=${questions.length} statuses=$byStatus pending_ready=$pendingReady '
    'pending_incomplete=${pendingIncomplete.length} any_incomplete=${anyIncomplete.length} '
    'targeting=${incomplete.length}',
  );
  if (Platform.environment['DRY_RUN'] == '1') {
    for (final q in incomplete) {
      stdout.writeln('would_translate id=${q.id} status=${q.status}');
    }
    return;
  }
  if (incomplete.isEmpty) {
    stdout.writeln('nothing_to_translate');
    return;
  }

  var ok = 0;
  final failures = <String>[];
  for (var i = 0; i < incomplete.length; i++) {
    final q = incomplete[i];
    stdout.writeln('translating ${i + 1}/${incomplete.length} id=${q.id}');
    final result = await _translate(token, q);
    if (result.error != null) {
      failures.add('${q.id}: translate ${result.error}');
      stdout.writeln('fail id=${q.id} reason=${result.error}');
      continue;
    }
    final written = q.copyWith(translations: result.translations);
    final saveError = await _save(token, written);
    if (saveError != null) {
      failures.add('${q.id}: save $saveError');
      stdout.writeln('fail id=${q.id} reason=save $saveError');
      continue;
    }
    ok += 1;
    stdout.writeln('saved id=${q.id}');
  }

  stdout.writeln('done incomplete=${incomplete.length} saved=$ok failed=${failures.length}');
  for (final line in failures) {
    stdout.writeln('failure $line');
  }
}

Future<({Map<String, BilgiTranslation> translations, String? error})> _translate(
  String token,
  BilgiQuestion q,
) async {
  try {
    final response = await http
        .post(
          Uri.parse('$_api/v1/admin/bilgi-translate'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'kind': 'question',
            'text': q.text,
            'options': q.options,
            'explanation': q.explanation,
          }),
        )
        .timeout(const Duration(seconds: 90));
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return (translations: <String, BilgiTranslation>{}, error: 'bad_json');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return (translations: <String, BilgiTranslation>{}, error: '${decoded['error'] ?? response.statusCode}');
    }
    final raw = decoded['translations'];
    if (raw is! Map) return (translations: <String, BilgiTranslation>{}, error: 'no_translations');
    final out = <String, BilgiTranslation>{};
    for (final locale in _locales) {
      final row = BilgiTranslation.fromMap(raw[locale]);
      if (row == null || !bilgiLanguageFieldsReady(row.text, row.options, row.explanation)) {
        return (translations: <String, BilgiTranslation>{}, error: 'incomplete_locale_$locale');
      }
      out[locale] = row;
    }
    return (translations: out, error: null);
  } catch (e) {
    return (translations: <String, BilgiTranslation>{}, error: 'network');
  }
}

Future<String?> _save(String token, BilgiQuestion q) async {
  try {
    final response = await http
        .put(
          Uri.parse('$_api/v1/admin/bilgi-questions'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'questions': [q.toMap()],
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode >= 200 && response.statusCode < 300) return null;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['error'] != null) return '${decoded['error']}';
    } catch (_) {}
    return 'http_${response.statusCode}';
  } catch (_) {
    return 'network';
  }
}

Future<List<BilgiQuestion>?> _loadAll(String token) async {
  try {
    final response = await http
        .get(
          Uri.parse('$_api/v1/admin/bilgi-questions'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['questions'] is! List) return null;
    return [
      for (final item in decoded['questions'] as List)
        if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
    ];
  } catch (_) {
    return null;
  }
}

Future<String> _mintAdminSession(Connection db) async {
  final rows = await db.execute(
    "select id from admin_users where status = 'active' order by last_login_at desc nulls last limit 1",
  );
  if (rows.isEmpty) {
    throw StateError('No active admin user');
  }
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
  final username = Uri.decodeComponent(userInfo.first);
  final password = Uri.decodeComponent(userInfo.skip(1).join(':'));
  // Local SSH tunnel from `railway connect Postgres --tunnel-only -P ...`
  final tunnelPort = int.tryParse(Platform.environment['LOCAL_PG_PORT'] ?? '');
  final host = tunnelPort != null ? '127.0.0.1' : uri.host;
  final port = tunnelPort ?? (uri.hasPort ? uri.port : 5432);
  final internal = host.contains('railway.internal') || host == '127.0.0.1';
  return Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: uri.pathSegments.isEmpty ? 'railway' : uri.pathSegments.first,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(
      sslMode: internal ? SslMode.disable : SslMode.require,
    ),
  );
}

String _id() {
  final r = Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
