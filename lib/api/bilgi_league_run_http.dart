import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league_run.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const bilgiLeagueOpenBox = 'league_open';

void mountBilgiLeagueRun(Router router, KeyValueStore store) {
  router
    ..get('/v1/bilgi/league-run', (request) => _load(request, store))
    ..post('/v1/bilgi/league-run', (request) => _save(request, store));
}

Future<Response> _load(Request request, KeyValueStore store) async {
  final userId = (request.url.queryParameters['userId'] ?? '').trim();
  final categoryId = (request.url.queryParameters['categoryId'] ?? '').trim();
  final modeId = (request.url.queryParameters['modeId'] ?? '').trim();
  if (!_idsOk(userId, categoryId, modeId)) return jsonResponse({'run': null});
  final row = await store.get(bilgiLeagueOpenBox, _key(userId, categoryId, modeId));
  final questions = _questionsOf(row);
  if (row == null || row['closed'] == true || questions.isEmpty || bilgiInt(row['index'], 0) >= questions.length) {
    return jsonResponse({'run': null});
  }
  return jsonResponse({'run': row});
}

Future<Response> _save(Request request, KeyValueStore store) async {
  final body = await readJson(request);
  final userId = '${body['userId'] ?? ''}'.trim();
  final categoryId = '${body['categoryId'] ?? ''}'.trim();
  final modeId = '${body['modeId'] ?? ''}'.trim();
  if (!_idsOk(userId, categoryId, modeId)) {
    return jsonResponse({'error': 'Tur geçersiz.'}, status: 400);
  }
  final key = _key(userId, categoryId, modeId);
  final existing = await store.get(bilgiLeagueOpenBox, key);
  final decision = bilgiLeagueOpenWrite(
    userId: userId,
    categoryId: categoryId,
    modeId: modeId,
    existing: existing,
    body: body,
  );
  if (decision.rejected) return jsonResponse({'error': 'Soru seti yok.'}, status: 400);
  if (decision.closed) {
    final tombstone = {'userId': userId, 'categoryId': categoryId, 'modeId': modeId, 'closed': true};
    await store.put(bilgiLeagueOpenBox, key, tombstone);
    return jsonResponse({'run': null});
  }
  if (decision.run == null) return jsonResponse({'run': null});
  if (!identical(decision.run, existing)) await store.put(bilgiLeagueOpenBox, key, decision.run!);
  return jsonResponse({'run': decision.run});
}

/// A later save moves the index forward. A fresh start replaces the question list.
BilgiLeagueOpenWrite bilgiLeagueOpenWrite({
  required String userId,
  required String categoryId,
  required String modeId,
  Map<String, dynamic>? existing,
  required Map<String, dynamic> body,
}) {
  if (body['finished'] == true) return const BilgiLeagueOpenWrite.closed();
  if (existing != null && existing['closed'] == true && body['fresh'] != true) {
    return const BilgiLeagueOpenWrite.ignore();
  }
  final open = existing != null && existing['closed'] != true ? existing : null;
  final storedQuestions = _questionsOf(open);
  final incoming = _questionsOf(body);
  final replace = body['fresh'] == true && incoming.isNotEmpty;
  final questions = replace || storedQuestions.isEmpty ? incoming : storedQuestions;
  if (questions.isEmpty) return const BilgiLeagueOpenWrite.rejected();
  final index = bilgiInt(body['index'], 0);
  if (!replace && open != null && index < bilgiInt(open['index'], 0)) return BilgiLeagueOpenWrite.keep(open);
  if (index >= questions.length) return const BilgiLeagueOpenWrite.closed();
  final Object? spare = replace || storedQuestions.isEmpty ? body['spare'] : open?['spare'];
  return BilgiLeagueOpenWrite.store({
    'userId': userId,
    'categoryId': categoryId,
    'modeId': '${replace ? modeId : (open?['modeId'] ?? modeId)}',
    'difficulty': '${body['difficulty'] ?? open?['difficulty'] ?? ''}',
    'subcategory': '${body['subcategory'] ?? open?['subcategory'] ?? ''}',
    'questions': questions,
    if (spare is Map) 'spare': Map<String, dynamic>.from(spare),
    'index': index,
    'score': bilgiInt(body['score'], 0),
    'correct': bilgiInt(body['correct'], 0),
    'wrong': bilgiInt(body['wrong'], 0),
    'streak': bilgiInt(body['streak'], 0),
    'jokersUsed': bilgiInt(body['jokersUsed'], 0),
    'doubleLeft': bilgiInt(body['doubleLeft'], 0),
    'hidden': [for (final item in (body['hidden'] as List? ?? const [])) bilgiInt(item, -1)].where((item) => item >= 0).toList(),
    'hint': '${body['hint'] ?? ''}',
    'finished': false,
  });
}

class BilgiLeagueOpenWrite {
  const BilgiLeagueOpenWrite.store(this.run) : closed = false, rejected = false;
  const BilgiLeagueOpenWrite.keep(this.run) : closed = false, rejected = false;
  const BilgiLeagueOpenWrite.closed() : run = null, closed = true, rejected = false;
  const BilgiLeagueOpenWrite.ignore() : run = null, closed = false, rejected = false;
  const BilgiLeagueOpenWrite.rejected() : run = null, closed = false, rejected = true;

  final Map<String, dynamic>? run;
  final bool closed;
  final bool rejected;
}

bool _idsOk(String userId, String categoryId, String modeId) {
  if (userId.isEmpty || userId.length > 80) return false;
  if (categoryId.isEmpty || categoryId.length > 80) return false;
  return bilgiLeagueResumable(modeId);
}

String _key(String userId, String categoryId, String modeId) => '$userId|$categoryId|$modeId';

List<Map<String, dynamic>> _questionsOf(Map<String, dynamic>? row) {
  final saved = row?['questions'];
  if (saved is! List) return const [];
  return [for (final item in saved) if (item is Map) Map<String, dynamic>.from(item)];
}
