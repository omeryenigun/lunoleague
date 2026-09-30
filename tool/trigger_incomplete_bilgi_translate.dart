// One-off operational trigger: translate incomplete Bilgi questions on live API.
// Run: railway run --service api dart run tool/trigger_incomplete_bilgi_translate.dart
// Does not print secrets. Does not approve / delete.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
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
  late String token;
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
  final publishLocales = await _loadPublishLocales();
  List<String>? localesOf(BilgiQuestion q) => publishLocales[q.categoryId];
  bool needsTranslation(BilgiQuestion q) =>
      bilgiLanguageFieldsReady(q.text, q.options, q.explanation) &&
      !bilgiQuestionLanguagesReady(q, locales: localesOf(q));

  final pendingIncomplete = <BilgiQuestion>[];
  final anyIncomplete = <BilgiQuestion>[];
  for (final q in questions) {
    if (!needsTranslation(q)) continue;
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
        if (idFilter.contains(q.id) && needsTranslation(q)) q,
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
  final pendingReady = questions.where((q) => bilgiPendingApprovalReady(q, locales: localesOf(q))).length;
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
    // Remint periodically so long batches outlive a short session / tunnel blip.
    if (i > 0 && i % 100 == 0) {
      try {
        final db = await _open(databaseUrl);
        try {
          token = await _mintAdminSession(db);
          stdout.writeln('reminted_session at=$i');
        } finally {
          await db.close();
        }
      } catch (_) {
        stdout.writeln('remint_failed at=$i continuing_with_existing_token');
      }
    }
    final q = incomplete[i];
    final missing = [
      for (final id in bilgiExtraLocales(localesOf(q)))
        if (!_localeFilled(q, id)) id,
    ];
    if (missing.isEmpty) {
      stdout.writeln('skip id=${q.id} reason=no_open_locale');
      continue;
    }
    stdout.writeln('translating ${i + 1}/${incomplete.length} id=${q.id} locales=${missing.join(',')}');
    var result = await _translate(token, q, missing);
    // Credits exhausted: stop immediately (no retry / no further batch).
    if (result.error == 'openrouter_402') {
      stdout.writeln(
        'stopped_on_402 incomplete=${incomplete.length} saved=$ok '
        'attempted=${i + 1} failed=${failures.length}',
      );
      break;
    }
    if (result.error == 'network' ||
        result.error == 'Tercüme servisi yanıt vermedi.' ||
        result.error == 'Tercüme okunamadı.' ||
        result.error == 'Tercüme eksik geldi.' ||
        (result.error?.startsWith('openrouter_') ?? false) ||
        (result.error?.startsWith('incomplete_locale_') ?? false)) {
      await Future<void>.delayed(const Duration(seconds: 3));
      result = await _translate(token, q, missing);
      if (result.error == 'openrouter_402') {
        stdout.writeln(
          'stopped_on_402 incomplete=${incomplete.length} saved=$ok '
          'attempted=${i + 1} failed=${failures.length}',
        );
        break;
      }
    }
    // Pace requests to avoid OpenRouter in-flight budget 402s.
    await Future<void>.delayed(const Duration(seconds: 1));
    if (result.error != null) {
      failures.add('${q.id}: translate ${result.error}');
      stdout.writeln('fail id=${q.id} reason=${result.error}');
      continue;
    }
    final written = q.copyWith(translations: {...q.translations, ...result.translations});
    var saveError = await _save(token, written);
    if (saveError == 'network') {
      await Future<void>.delayed(const Duration(seconds: 2));
      saveError = await _save(token, written);
    }
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
  List<String> locales,
) async {
  if (locales.isEmpty) return (translations: <String, BilgiTranslation>{}, error: null);
  // Prefer direct OpenRouter with max_tokens when the key is available (railway run).
  // Production /v1/admin/bilgi-translate currently omits max_tokens and can 402 when
  // remaining credits cannot cover the provider default ceiling (~65535).
  final key = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  if (key.isNotEmpty) return _translateOpenRouter(key, q, locales);
  return _translateViaApi(token, q, locales);
}

bool _localeFilled(BilgiQuestion q, String locale) {
  final row = q.translations[locale];
  return row != null && bilgiLanguageFieldsReady(row.text, row.options, row.explanation);
}

Future<Map<String, List<String>?>> _loadPublishLocales() async {
  final out = <String, List<String>?>{};
  try {
    final response = await http.get(Uri.parse('$_api/v1/bilgi/catalog')).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return out;
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return out;
    final custom = decoded['custom'];
    if (custom is! List) return out;
    for (final raw in custom) {
      if (raw is! Map || !raw.containsKey('locales')) continue;
      out['${raw['id']}'] = bilgiStoredLocales(raw['locales']);
    }
  } catch (_) {}
  return out;
}

Future<({Map<String, BilgiTranslation> translations, String? error})> _translateViaApi(
  String token,
  BilgiQuestion q,
  List<String> locales,
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
            'locales': locales,
          }),
        )
        .timeout(const Duration(seconds: 90));
    return _parseTranslations(response.statusCode, response.body, locales);
  } catch (e) {
    return (translations: <String, BilgiTranslation>{}, error: 'network');
  }
}

Future<({Map<String, BilgiTranslation> translations, String? error})> _translateOpenRouter(
  String key,
  BilgiQuestion q,
  List<String> locales,
) async {
  final model = Platform.environment['OPENROUTER_MODEL'] ?? 'google/gemini-2.5-flash';
  try {
    final response = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'authorization': 'Bearer $key',
            'content-type': 'application/json',
            'http-referer': 'https://onyapp.app',
            'x-title': 'Luno Bilgi',
          },
          body: jsonEncode({
            'model': model,
            'temperature': 0.2,
            'max_tokens': 2000,
            'messages': [
              {
                'role': 'system',
                'content':
                    'Translate this Turkish trivia item into ${locales.join(', ')}. '
                    'Keep the four options in the same order. Do not change which option is correct. '
                    'Every text, option, and explanation must be non-empty. '
                    'Return only JSON: {${locales.map((id) => '"$id":{"text":"","options":["","","",""],"explanation":""}').join(',')}}.',
              },
              {
                'role': 'user',
                'content': jsonEncode({
                  'text': q.text,
                  'options': q.options,
                  'explanation': q.explanation,
                }),
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 90));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return (translations: <String, BilgiTranslation>{}, error: 'openrouter_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return (translations: <String, BilgiTranslation>{}, error: 'bad_json');
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return (translations: <String, BilgiTranslation>{}, error: 'Tercüme okunamadı.');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) return (translations: <String, BilgiTranslation>{}, error: 'Tercüme okunamadı.');
    final content = message['content'];
    final text = content is String
        ? content
        : (content is List
            ? content.map((item) => item is Map ? '${item['text'] ?? ''}' : '').join()
            : '');
    final raw = _jsonObject(text);
    if (raw == null) return (translations: <String, BilgiTranslation>{}, error: 'Tercüme okunamadı.');
    return _translationsFromRaw(raw, locales);
  } catch (_) {
    return (translations: <String, BilgiTranslation>{}, error: 'network');
  }
}

({Map<String, BilgiTranslation> translations, String? error}) _parseTranslations(
  int statusCode,
  String body,
  List<String> locales,
) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return (translations: <String, BilgiTranslation>{}, error: 'bad_json');
    if (statusCode < 200 || statusCode >= 300) {
      return (translations: <String, BilgiTranslation>{}, error: '${decoded['error'] ?? statusCode}');
    }
    final raw = decoded['translations'];
    if (raw is! Map) return (translations: <String, BilgiTranslation>{}, error: 'no_translations');
    return _translationsFromRaw(Map<String, dynamic>.from(raw), locales);
  } catch (_) {
    return (translations: <String, BilgiTranslation>{}, error: 'bad_json');
  }
}

({Map<String, BilgiTranslation> translations, String? error}) _translationsFromRaw(Map raw, List<String> locales) {
  final out = <String, BilgiTranslation>{};
  for (final locale in locales) {
    final row = BilgiTranslation.fromMap(raw[locale]);
    if (row == null || !bilgiLanguageFieldsReady(row.text, row.options, row.explanation)) {
      return (translations: <String, BilgiTranslation>{}, error: 'incomplete_locale_$locale');
    }
    out[locale] = row;
  }
  return (translations: out, error: null);
}

Map<String, dynamic>? _jsonObject(String raw) {
  final trimmed = raw.trim();
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(trimmed);
  final body = fenced?.group(1)?.trim() ?? trimmed;
  final start = body.indexOf('{');
  final end = body.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(body.substring(start, end + 1));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
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
      values (@hash, @adminId, now() + interval '24 hours')
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
