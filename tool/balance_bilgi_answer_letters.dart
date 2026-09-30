// One-off: move excess correct-answer letters inside each Bilgi category.
// Run: railway run --service api dart run tool/balance_bilgi_answer_letters.dart
// Does not print secrets. Does not change the correct sentence, translations' meaning, or approval.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:postgres/postgres.dart';

const _api = 'https://api-production-bf3c9.up.railway.app';

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

  final rawQuestions = await _loadRaw(token);
  if (rawQuestions == null) {
    stderr.writeln('Failed to load admin questions (auth or API).');
    exitCode = 1;
    return;
  }

  var skipped = 0;
  final questions = <BilgiQuestion>[];
  for (final raw in rawQuestions) {
    final question = BilgiQuestion.fromMap(raw);
    if (_rawTranslationsSafe(raw)) {
      questions.add(question);
    } else {
      skipped += 1;
      questions.add(
        question.copyWith(
          translations: {
            ...question.translations,
            '_skip': const BilgiTranslation(text: 'skip', options: ['a'], explanation: ''),
          },
        ),
      );
    }
  }

  final changed = bilgiBalanceAnswerLetters(questions);
  final changedIds = {for (final question in changed) question.id};
  final multiTag = questions.where((question) => question.tags.where((tag) => tag.trim().isNotEmpty).length > 1).length;
  stdout.writeln('total=${questions.length} moving=${changed.length} skipped_incomplete=$skipped multi_tag=$multiTag');
  _printCategoryShifts(questions, changed);

  if (changed.isEmpty) {
    stdout.writeln('nothing_to_move');
    return;
  }

  var ok = 0;
  final failures = <String>[];
  for (var i = 0; i < changed.length; i += 400) {
    final end = i + 400 > changed.length ? changed.length : i + 400;
    final batch = changed.sublist(i, end);
    final error = await _save(token, batch);
    if (error != null) {
      failures.add('batch $i: $error');
      stdout.writeln('fail batch=$i size=${batch.length} reason=$error');
      continue;
    }
    ok += batch.length;
    stdout.writeln('saved $ok/${changed.length}');
  }

  final after = [
    for (final question in questions)
      if (changedIds.contains(question.id)) changed.firstWhere((item) => item.id == question.id) else question,
  ];
  stdout.writeln('done moved=$ok failed_batches=${failures.length}');
  _printLetters('after', after);
  for (final line in failures) {
    stdout.writeln('failure $line');
  }
  if (failures.isNotEmpty) exitCode = 1;
}

bool _rawTranslationsSafe(Map<String, dynamic> raw) {
  final translations = raw['translations'];
  if (translations == null) return true;
  if (translations is! Map) return false;
  for (final value in translations.values) {
    if (BilgiTranslation.fromMap(value) == null) return false;
  }
  return true;
}

void _printCategoryShifts(List<BilgiQuestion> before, List<BilgiQuestion> changed) {
  final byId = {for (final question in changed) question.id: question};
  final keys = <String>{};
  for (final question in before) {
    final tags = [for (final tag in question.tags) if (tag.trim().isNotEmpty) tag.trim()];
    if (tags.isEmpty) {
      keys.add('${question.categoryId}|');
    } else {
      for (final tag in tags) {
        keys.add('${question.categoryId}|$tag');
      }
    }
  }
  var shown = 0;
  for (final key in keys) {
    final split = key.indexOf('|');
    final categoryId = key.substring(0, split);
    final tag = key.substring(split + 1);
    final rows = before.where((question) {
      if (question.categoryId != categoryId) return false;
      if (tag.isEmpty) return question.tags.every((item) => item.trim().isEmpty);
      return question.tags.contains(tag);
    });
    final next = rows.map((question) => byId[question.id] ?? question);
    final left = _letters(rows);
    final right = _letters(next);
    if (left == right) continue;
    stdout.writeln('sub=$key $left -> $right');
    shown += 1;
  }
  stdout.writeln('subs_changed=$shown');
}

void _printLetters(String label, Iterable<BilgiQuestion> questions) {
  stdout.writeln('$label ${_letters(questions)}');
}

String _letters(Iterable<BilgiQuestion> questions) {
  final counts = [0, 0, 0, 0];
  var total = 0;
  for (final question in questions) {
    total += 1;
    counts[question.correct.clamp(0, 3)] += 1;
  }
  const names = ['A', 'B', 'C', 'D'];
  return 'n=$total ${[for (var i = 0; i < 4; i++) '${names[i]}=${counts[i]}'].join(' ')}';
}

Future<String?> _save(String token, List<BilgiQuestion> questions) async {
  try {
    final response = await http
        .put(
          Uri.parse('$_api/v1/admin/bilgi-questions'),
          headers: {
            'authorization': 'Bearer $token',
            'content-type': 'application/json; charset=utf-8',
          },
          body: jsonEncode({
            'questions': [for (final question in questions) question.toMap()],
          }),
        )
        .timeout(const Duration(seconds: 180));
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

Future<List<Map<String, dynamic>>?> _loadRaw(String token) async {
  try {
    final response = await http
        .get(
          Uri.parse('$_api/v1/admin/bilgi-questions'),
          headers: {'authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 180));
    if (response.statusCode != 200) return null;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map || decoded['questions'] is! List) return null;
    return [
      for (final item in decoded['questions'] as List)
        if (item is Map) Map<String, dynamic>.from(item),
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
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}
