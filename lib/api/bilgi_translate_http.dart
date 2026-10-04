import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _targetLocales = ['en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl'];

/// İstek `locales` göndermezse dokuz dil. Gönderirse yalnız listedekiler.
/// Kapalı dil bu listede yoktur, modele gitmez.
List<String> _requestedLocales(Map<String, dynamic> body) {
  final raw = body['locales'];
  if (raw is! List) return List<String>.from(_targetLocales);
  final picked = <String>[];
  for (final item in raw) {
    final id = '$item'.trim();
    if (_targetLocales.contains(id) && !picked.contains(id)) picked.add(id);
  }
  return picked;
}

void mountBilgiTranslate(Router router, Connection db) {
  router.post('/v1/admin/bilgi-translate', (request) => _translate(request, db));
}

Future<Response> _translate(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final openRouter = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  final openAi = Platform.environment['OPENAI_API_KEY'] ?? '';
  if (openRouter.isEmpty && openAi.isEmpty) {
    return jsonResponse({'error': 'Tercüme anahtarı yok.'}, status: 503);
  }
  final body = await readJson(request);
  final kind = '${body['kind'] ?? ''}'.trim();
  if (kind == 'question') return _question(body);
  if (kind == 'name') return _name(body);
  return jsonResponse({'error': 'Tercüme isteği geçersiz.'}, status: 400);
}

Future<Response> _question(Map<String, dynamic> body) async {
  final text = '${body['text'] ?? ''}'.trim();
  final explanation = '${body['explanation'] ?? ''}'.trim();
  final options = body['options'];
  if (options is! List || options.length != 4) {
    return jsonResponse({'error': 'Türkçe soru, dört şık ve açıklama dolu olmalı.'}, status: 400);
  }
  final choices = [for (final item in options) '$item'.trim()];
  if (!bilgiLanguageFieldsReady(text, choices, explanation)) {
    return jsonResponse({'error': 'Türkçe soru, dört şık ve açıklama dolu olmalı.'}, status: 400);
  }
  final targets = _requestedLocales(body);
  if (targets.isEmpty) return jsonResponse({'translations': <String, Object>{}});
  final sample = targets.map((id) => '"$id":{"text":"","options":["","","",""],"explanation":""}').join(',');
  final decoded = await _ask(
    'Translate this Turkish trivia item into ${targets.join(', ')}. '
    'Keep the four options in the same order. Do not change which option is correct. '
    'Every text, option, and explanation must be non-empty. '
    'Return only JSON: {$sample}.',
    jsonEncode({'text': text, 'options': choices, 'explanation': explanation}),
  );
  if (decoded is String) return jsonResponse({'error': decoded}, status: 502);
  if (decoded is! Map) return jsonResponse({'error': 'Tercüme okunamadı.'}, status: 502);
  final out = <String, Object>{};
  for (final locale in targets) {
    final row = decoded[locale];
    if (row is! Map) return jsonResponse({'error': 'Tercüme eksik geldi.'}, status: 502);
    final translated = '${row['text'] ?? ''}'.trim();
    final note = '${row['explanation'] ?? ''}'.trim();
    final rawOptions = row['options'];
    if (rawOptions is! List || rawOptions.length != 4) {
      return jsonResponse({'error': 'Tercüme eksik geldi.'}, status: 502);
    }
    final translatedOptions = [for (final item in rawOptions) '$item'.trim()];
    if (!bilgiLanguageFieldsReady(translated, translatedOptions, note)) {
      return jsonResponse({'error': 'Tercüme eksik geldi.'}, status: 502);
    }
    out[locale] = {'text': translated, 'options': translatedOptions, 'explanation': note};
  }
  return jsonResponse({'translations': out});
}

Future<Response> _name(Map<String, dynamic> body) async {
  final text = '${body['text'] ?? ''}'.trim();
  if (text.isEmpty || text.length > 80) {
    return jsonResponse({'error': 'Türkçe ad dolu olmalı.'}, status: 400);
  }
  final targets = _requestedLocales(body);
  if (targets.isEmpty) return jsonResponse({'names': <String, String>{}});
  final sample = targets.map((id) => '"$id":""').join(',');
  final decoded = await _ask(
    'Translate this Turkish category name into short display names for ${targets.join(', ')}. '
    'Each name must be non-empty and at most 80 characters. '
    'Return only JSON: {$sample}.',
    text,
  );
  if (decoded is String) return jsonResponse({'error': decoded}, status: 502);
  if (decoded is! Map) return jsonResponse({'error': 'Tercüme okunamadı.'}, status: 502);
  final out = <String, String>{};
  for (final locale in targets) {
    final label = '${decoded[locale] ?? ''}'.trim();
    if (label.isEmpty || label.length > 80) {
      return jsonResponse({'error': 'Tercüme eksik geldi.'}, status: 502);
    }
    out[locale] = label;
  }
  return jsonResponse({'names': out});
}

/// OpenRouter önce denenir. Kota veya bağlantı hatasında OpenAI yedeği kullanılır.
Future<Object?> _ask(String instruction, String source) async {
  final openRouterKey = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  Object? primary;
  if (openRouterKey.isNotEmpty) {
    primary = await _complete(
      endpoint: Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
      key: openRouterKey,
      model: Platform.environment['OPENROUTER_MODEL'] ?? 'google/gemini-2.5-flash',
      instruction: instruction,
      source: source,
      extraHeaders: const {
        'http-referer': 'https://onyapp.app',
        'x-title': 'Luno Bilgi',
      },
    );
    if (primary is Map) return primary;
  }
  final openAiKey = Platform.environment['OPENAI_API_KEY'] ?? '';
  if (openAiKey.isEmpty) {
    if (primary is String) return primary;
    return 'Tercüme servisi yanıt vermedi.';
  }
  return _complete(
    endpoint: Uri.parse('https://api.openai.com/v1/chat/completions'),
    key: openAiKey,
    model: Platform.environment['OPENAI_MODEL'] ?? 'gpt-4o-mini',
    instruction: instruction,
    source: source,
    jsonMode: true,
  );
}

Future<Object?> _complete({
  required Uri endpoint,
  required String key,
  required String model,
  required String instruction,
  required String source,
  Map<String, String> extraHeaders = const {},
  bool jsonMode = false,
}) async {
  try {
    final payload = <String, Object>{
      'model': model,
      'temperature': 0.2,
      'max_tokens': 2000,
      'messages': [
        {'role': 'system', 'content': instruction},
        {'role': 'user', 'content': source},
      ],
    };
    if (jsonMode) payload['response_format'] = {'type': 'json_object'};
    final response = await http
        .post(
          endpoint,
          headers: {
            'authorization': 'Bearer $key',
            'content-type': 'application/json',
            ...extraHeaders,
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 60));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map) {
      return 'Tercüme servisi yanıt vermedi.';
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) return 'Tercüme okunamadı.';
    final message = (choices.first as Map)['message'];
    if (message is! Map) return 'Tercüme okunamadı.';
    final content = message['content'];
    final text = content is String ? content : (content is List ? content.map((item) => item is Map ? '${item['text'] ?? ''}' : '').join() : '');
    final raw = _jsonObject(text);
    if (raw == null) return 'Tercüme okunamadı.';
    return raw;
  } catch (_) {
    return 'Tercüme servisi yanıt vermedi.';
  }
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
