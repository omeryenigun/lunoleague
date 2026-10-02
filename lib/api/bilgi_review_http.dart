import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/bilgi_count_snapshot.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_review.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

void mountBilgiReview(Router router, Connection db) {
  router.post('/v1/admin/bilgi-review', (request) => _review(request, db));
}

Future<Response> _review(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final key = Platform.environment['OPENROUTER_API_KEY'] ?? '';
  if (key.isEmpty) return jsonResponse({'error': 'OpenRouter anahtarı yok.'}, status: 503);
  final body = await readJson(request);
  final id = '${body['id'] ?? ''}'.trim();
  if (id.isEmpty || id.length > 80) {
    return jsonResponse({'error': 'Soru bulunamadı.'}, status: 400);
  }
  final rows = await db.execute(
    Sql.named('''
      select q.text, q.options_json, q.correct, q.difficulty, q.status,
             q.tags_json, q.category_id, coalesce(c.name, q.category_id)
      from bilgi_questions q
      left join bilgi_categories c on c.id = q.category_id
      where q.id = @id
    '''),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return jsonResponse({'error': 'Soru bulunamadı.'}, status: 404);
  final row = rows.first;
  final text = '${row[0]}'.trim();
  final options = _options(row[1]);
  final correct = row[2] is int ? row[2] as int : (row[2] is num ? (row[2] as num).toInt() : -1);
  final difficulty = '${row[3]}'.trim();
  final status = '${row[4]}'.trim();
  final tags = _tags(row[5]);
  final categoryId = '${row[6]}'.trim();
  final categoryName = '${row[7]}'.trim();
  if (text.isEmpty || options == null || correct < 0 || correct > 3) {
    return jsonResponse({'error': 'Soru kontrol edilemedi.'}, status: 400);
  }
  final asked = await _ask(
    key,
    jsonEncode({
      'text': text,
      'options': options,
      'correct': ['A', 'B', 'C', 'D'][correct],
      'category': categoryName,
      'subcategory': tags.join(', '),
      'difficulty': difficulty,
    }),
  );
  if (asked.error != null) return jsonResponse({'error': asked.error}, status: 502);
  final decision = bilgiParseReview(asked.text ?? '');
  if (decision == null) return jsonResponse({'error': 'Kontrol okunamadı.'}, status: 502);
  final applied = bilgiApplyReview(
    currentDifficulty: difficulty,
    currentStatus: status,
    decision: decision,
  );
  final previous = await loadBilgiCountParts(db, [id]);
  await db.execute(
    Sql.named('''
      update bilgi_questions
      set difficulty = @difficulty,
          status = @status,
          reject_reason = @rejectReason,
          reviewed = true
      where id = @id
    '''),
    parameters: {
      'id': id,
      'difficulty': applied.difficulty,
      'status': applied.status,
      'rejectReason': applied.rejectReason,
    },
  );
  await commitBilgiCountDelta(
    db,
    before: [previous[id]],
    after: [
      BilgiCountPart(
        categoryId: categoryId,
        difficulty: applied.difficulty,
        status: applied.status,
        tags: tags,
      ),
    ],
  );
  return jsonResponse({
    'id': id,
    'verdict': decision.verdict,
    'difficulty': applied.difficulty,
    'status': applied.status,
    'rejectReason': applied.rejectReason,
    'reviewed': true,
  });
}

Future<({String? text, String? error})> _ask(String key, String source) async {
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
            'temperature': 0,
            'max_tokens': 500,
            'messages': [
              {'role': 'system', 'content': bilgiReviewInstruction},
              {'role': 'user', 'content': source},
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));
    final decoded = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || decoded is! Map) {
      return (text: null, error: 'Kontrol servisi yanıt vermedi.');
    }
    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty || choices.first is! Map) {
      return (text: null, error: 'Kontrol okunamadı.');
    }
    final message = (choices.first as Map)['message'];
    if (message is! Map) return (text: null, error: 'Kontrol okunamadı.');
    final content = message['content'];
    final text = content is String
        ? content
        : (content is List ? content.map((item) => item is Map ? '${item['text'] ?? ''}' : '').join() : '');
    if (text.trim().isEmpty) return (text: null, error: 'Kontrol okunamadı.');
    return (text: text, error: null);
  } catch (_) {
    return (text: null, error: 'Kontrol servisi yanıt vermedi.');
  }
}

List<String>? _options(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List || decoded.length != 4) return null;
    final options = [for (final item in decoded) '$item'.trim()];
    if (options.any((item) => item.isEmpty)) return null;
    return options;
  } catch (_) {
    return null;
  }
}

List<String> _tags(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return [for (final item in decoded) '$item'.trim()].where((item) => item.isNotEmpty).toList();
  } catch (_) {}
  return const [];
}
