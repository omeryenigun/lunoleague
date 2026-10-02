import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/bilgi_questions_http.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const bilgiContestPaperBox = 'contest_paper';
const bilgiContestRunBox = 'contest_run';

void mountBilgiContest(Router router, Connection db, KeyValueStore store) {
  router
    ..get('/v1/bilgi/contest', (request) => _load(request, db, store))
    ..post('/v1/bilgi/contest', (request) => _save(request, db, store))
    ..get('/v1/admin/bilgi-contest', (request) => _adminMonth(request, db, store))
    ..post('/v1/admin/bilgi-contest', (request) => _adminBuild(request, db, store));
}

Future<Response> _load(Request request, Connection db, KeyValueStore store) async {
  final day = bilgiDayKey(DateTime.now());
  final paper = await _openDay(db, store, day);
  final userId = (request.url.queryParameters['userId'] ?? '').trim();
  final runs = await _runs(store, day);
  final me = userId.isEmpty ? null : runs[userId];
  return jsonResponse(_payload(day, paper, runs, me));
}

Future<Response> _save(Request request, Connection db, KeyValueStore store) async {
  final body = await readJson(request);
  final userId = '${body['userId'] ?? ''}'.trim();
  if (userId.isEmpty || userId.length > 80) {
    return jsonResponse({'error': 'Kullanıcı geçersiz.'}, status: 400);
  }
  final day = bilgiDayKey(DateTime.now());
  final paper = await _openDay(db, store, day);
  final runs = await _runs(store, day);
  final previous = runs[userId];
  if (previous != null && previous['finished'] == true) {
    return jsonResponse(_payload(day, paper, runs, previous));
  }
  final next = {
    'day': day,
    'userId': userId,
    'username': '${body['username'] ?? ''}'.trim(),
    'avatar': '${body['avatar'] ?? '😎'}'.trim(),
    'index': bilgiInt(body['index'], 0),
    'score': bilgiInt(body['score'], 0),
    'correct': bilgiInt(body['correct'], 0),
    'wrong': bilgiInt(body['wrong'], 0),
    'streak': bilgiInt(body['streak'], 0),
    'finished': body['finished'] == true,
  };
  runs[userId] = next;
  await store.put(bilgiContestRunBox, '$day|$userId', next);
  return jsonResponse(_payload(day, paper, runs, next));
}

class _ContestPaper {
  const _ContestPaper({required this.title, required this.questions});

  final String title;
  final List<Map<String, dynamic>> questions;
}

Future<_ContestPaper> _openDay(Connection db, KeyValueStore store, String day) async {
  final stored = await store.get(bilgiContestPaperBox, day);
  final ready = _questionsOf(stored);
  if (ready.isNotEmpty) {
    return _ContestPaper(title: _titleOf(stored), questions: ready);
  }
  final picked = await _draw(db, await _monthIds(store, day.substring(0, 7), skip: day));
  final again = await store.get(bilgiContestPaperBox, day);
  final raced = _questionsOf(again);
  if (raced.isNotEmpty) {
    return _ContestPaper(title: _titleOf(again), questions: raced);
  }
  final title = _titleOf(stored);
  await store.put(bilgiContestPaperBox, day, {'day': day, 'title': title, 'questions': picked});
  return _ContestPaper(title: title, questions: picked);
}

Future<List<Map<String, dynamic>>> _draw(Connection db, Set<String> exclude) async {
  final picked = <Map<String, dynamic>>[];
  final seen = {...exclude};
  for (var i = 0; i < bilgiDifficultyLevels.length; i++) {
    final count = i < bilgiDailyQuotas.length ? bilgiDailyQuotas[i] : 0;
    if (count <= 0) continue;
    final batch = await drawApprovedBilgiQuestions(
      db,
      categoryId: tumuKarmaId,
      subcategory: '',
      difficulty: bilgiDifficultyLevels[i],
      count: count,
      exclude: seen,
    );
    for (final item in batch) {
      seen.add('${item['id']}');
      picked.add(item);
    }
  }
  return picked;
}

Future<Map<String, Map<String, dynamic>>> _runs(KeyValueStore store, String day) async {
  final out = <String, Map<String, dynamic>>{};
  for (final row in await store.values(bilgiContestRunBox)) {
    final id = '${row['userId'] ?? ''}'.trim();
    if (id.isEmpty) continue;
    final keyDay = '${row['day'] ?? ''}';
    if (keyDay.isNotEmpty && keyDay != day) continue;
    out[id] = row;
  }
  return out;
}

Map<String, dynamic> _payload(
  String day,
  _ContestPaper paper,
  Map<String, Map<String, dynamic>> runs,
  Map<String, dynamic>? me,
) {
  final ranking = [
    for (final row in runs.values)
      if (row['finished'] == true)
        {
          'id': '${row['userId'] ?? ''}',
          'name': '${row['username'] ?? ''}',
          'avatar': '${row['avatar'] ?? '😎'}',
          'score': bilgiInt(row['score'], 0),
        },
  ];
  return {
    'day': day,
    'title': paper.title,
    'questions': paper.questions,
    'joined': runs.length,
    'ranking': ranking,
    if (me != null)
      'me': {
        'index': bilgiInt(me['index'], 0),
        'score': bilgiInt(me['score'], 0),
        'correct': bilgiInt(me['correct'], 0),
        'wrong': bilgiInt(me['wrong'], 0),
        'streak': bilgiInt(me['streak'], 0),
        'finished': me['finished'] == true,
      },
  };
}

Future<Response> _adminMonth(Request request, Connection db, KeyValueStore store) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final month = (request.url.queryParameters['month'] ?? '').trim();
  final days = bilgiContestMonthDays(month);
  if (days.isEmpty) return jsonResponse({'error': 'Ay geçersiz.'}, status: 400);
  return jsonResponse(await _monthPayload(store, month, days));
}

Future<Response> _adminBuild(Request request, Connection db, KeyValueStore store) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final month = '${body['month'] ?? ''}'.trim();
  final day = '${body['day'] ?? ''}'.trim();
  if (month.isNotEmpty) {
    final days = bilgiContestMonthDays(month);
    if (days.isEmpty) return jsonResponse({'error': 'Ay geçersiz.'}, status: 400);
    await _fillMonth(db, store, days);
    return jsonResponse(await _monthPayload(store, month, days));
  }
  if (bilgiContestMonthDays(day.length >= 7 ? day.substring(0, 7) : '').contains(day) == false) {
    return jsonResponse({'error': 'Gün geçersiz.'}, status: 400);
  }
  final locked = await _lockedDays(store);
  if (locked.contains(day)) {
    return jsonResponse({'error': 'Bu gün kilitli.'}, status: 409);
  }
  final stored = await store.get(bilgiContestPaperBox, day);
  final rebuild = body['rebuild'] == true;
  final hasTitle = body.containsKey('title');
  var title = _titleOf(stored);
  if (hasTitle) {
    title = '${body['title'] ?? ''}'.trim();
    if (title.length > 40) return jsonResponse({'error': 'Ad 40 karakteri geçemez.'}, status: 400);
  }
  var questions = _questionsOf(stored);
  if (rebuild || questions.isEmpty) {
    final exclude = await _monthIds(store, day.substring(0, 7), skip: day);
    questions = await _draw(db, exclude);
  }
  await store.put(bilgiContestPaperBox, day, {'day': day, 'title': title, 'questions': questions});
  return jsonResponse(await _monthPayload(store, day.substring(0, 7), bilgiContestMonthDays(day.substring(0, 7))));
}

Future<void> _fillMonth(Connection db, KeyValueStore store, List<String> days) async {
  final locked = await _lockedDays(store);
  final used = <String>{};
  for (final day in days) {
    final stored = await store.get(bilgiContestPaperBox, day);
    _takeIds(_questionsOf(stored), used);
  }
  for (final day in days) {
    if (locked.contains(day)) continue;
    final stored = await store.get(bilgiContestPaperBox, day);
    if (_questionsOf(stored).isNotEmpty) continue;
    final picked = await _draw(db, used);
    _takeIds(picked, used);
    await store.put(bilgiContestPaperBox, day, {'day': day, 'title': _titleOf(stored), 'questions': picked});
  }
}

Future<Map<String, dynamic>> _monthPayload(KeyValueStore store, String month, List<String> days) async {
  final locked = await _lockedDays(store);
  final rows = <Map<String, dynamic>>[];
  for (final day in days) {
    final stored = await store.get(bilgiContestPaperBox, day);
    rows.add({
      'day': day,
      'title': _titleOf(stored),
      'count': _questionsOf(stored).length,
      'locked': locked.contains(day),
    });
  }
  return {'month': month, 'days': rows};
}

Future<Set<String>> _lockedDays(KeyValueStore store) async {
  final days = <String>{};
  for (final row in await store.values(bilgiContestRunBox)) {
    final day = '${row['day'] ?? ''}'.trim();
    if (day.isNotEmpty) days.add(day);
  }
  return days;
}

Future<Set<String>> _monthIds(KeyValueStore store, String month, {required String skip}) async {
  final ids = <String>{};
  for (final day in bilgiContestMonthDays(month)) {
    if (day == skip) continue;
    _takeIds(_questionsOf(await store.get(bilgiContestPaperBox, day)), ids);
  }
  return ids;
}

String _titleOf(Map<String, dynamic>? row) {
  final title = '${row?['title'] ?? ''}'.trim();
  return title.length > 40 ? title.substring(0, 40) : title;
}

List<Map<String, dynamic>> _questionsOf(Map<String, dynamic>? row) {
  final saved = row?['questions'];
  if (saved is! List) return const [];
  return [for (final item in saved) if (item is Map) Map<String, dynamic>.from(item)];
}

void _takeIds(List<Map<String, dynamic>> questions, Set<String> into) {
  for (final item in questions) {
    final id = '${item['id'] ?? ''}'.trim();
    if (id.isNotEmpty) into.add(id);
  }
}
