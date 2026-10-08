import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/bilgi_daily_ai.dart';
import 'package:kelimelig/api/bilgi_questions_http.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_contest.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_daily_paper.dart';
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
  return jsonResponse(await _payload(store, day, paper, runs, me));
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
    return jsonResponse(await _payload(store, day, paper, runs, previous));
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
  return jsonResponse(await _payload(store, day, paper, runs, next));
}

class _ContestPaper {
  const _ContestPaper({required this.title, required this.questions, this.spares = const []});

  final String title;
  final List<Map<String, dynamic>> questions;
  final List<Map<String, dynamic>> spares;
}

Future<_ContestPaper> _openDay(Connection db, KeyValueStore store, String day) async {
  final stored = await store.get(bilgiContestPaperBox, day);
  final ready = _questionsOf(stored);
  if (bilgiContestAiDay(day)) {
    return _ContestPaper(title: _titleOf(stored), questions: ready, spares: _sparesOf(stored));
  }
  final wanted = bilgiDailyQuotas.fold<int>(0, (sum, count) => sum + count);
  if (ready.isNotEmpty && ready.length < wanted && !(await _lockedDays(store)).contains(day)) {
    final exclude = await _monthIds(store, day.substring(0, 7), skip: day);
    _takeIds(ready, exclude);
    final extra = await _drawCounted(db, exclude, [wanted - ready.length]);
    if (extra.isNotEmpty) {
      final questions = [...ready, ...extra];
      _takeIds(extra, exclude);
      final spares = await _drawCounted(db, exclude, bilgiContestSpareCounts);
      final title = _titleOf(stored);
      await store.put(bilgiContestPaperBox, day, {
        'day': day,
        'title': title,
        'questions': questions,
        'spares': spares,
      });
      return _ContestPaper(title: title, questions: questions, spares: spares);
    }
  }
  if (ready.isNotEmpty) {
    return _withSpares(db, store, day, stored, ready);
  }
  final picked = await _draw(db, await _monthIds(store, day.substring(0, 7), skip: day));
  final again = await store.get(bilgiContestPaperBox, day);
  final raced = _questionsOf(again);
  if (raced.isNotEmpty) {
    return _withSpares(db, store, day, again, raced);
  }
  final title = _titleOf(stored);
  final exclude = await _monthIds(store, day.substring(0, 7), skip: day);
  _takeIds(picked, exclude);
  final spares = await _drawCounted(db, exclude, bilgiContestSpareCounts);
  await store.put(bilgiContestPaperBox, day, {'day': day, 'title': title, 'questions': picked, 'spares': spares});
  return _ContestPaper(title: title, questions: picked, spares: spares);
}

Future<_ContestPaper> _withSpares(
  Connection db,
  KeyValueStore store,
  String day,
  Map<String, dynamic>? stored,
  List<Map<String, dynamic>> questions,
) async {
  final title = _titleOf(stored);
  if (stored != null && stored.containsKey('spares')) {
    return _ContestPaper(title: title, questions: questions, spares: _sparesOf(stored));
  }
  final exclude = await _monthIds(store, day.substring(0, 7), skip: day);
  _takeIds(questions, exclude);
  final spares = await _drawCounted(db, exclude, bilgiContestSpareCounts);
  final again = await store.get(bilgiContestPaperBox, day);
  if (again != null && again.containsKey('spares') && _questionsOf(again).isNotEmpty) {
    return _ContestPaper(title: _titleOf(again), questions: _questionsOf(again), spares: _sparesOf(again));
  }
  await store.put(bilgiContestPaperBox, day, {
    'day': day,
    'title': title,
    'questions': questions,
    'spares': spares,
  });
  return _ContestPaper(title: title, questions: questions, spares: spares);
}

Future<List<Map<String, dynamic>>> _draw(Connection db, Set<String> exclude) {
  return _drawCounted(db, exclude, bilgiDailyQuotas);
}

Future<List<Map<String, dynamic>>> _drawCounted(Connection db, Set<String> exclude, List<int> counts) async {
  final picked = <Map<String, dynamic>>[];
  final seen = {...exclude};
  for (var i = 0; i < bilgiDifficultyLevels.length; i++) {
    final count = i < counts.length ? counts[i] : 0;
    if (count <= 0) continue;
    final batch = await drawApprovedBilgiQuestions(
      db,
      categoryId: tumuKarmaId,
      subcategory: '',
      difficulty: bilgiDifficultyLevels[i],
      count: count,
      exclude: seen,
      fullLocales: true,
    );
    for (final item in batch) {
      seen.add('${item['id']}');
      picked.add(item);
    }
  }
  final wanted = counts.fold<int>(0, (sum, count) => sum + (count > 0 ? count : 0));
  final missing = wanted - picked.length;
  if (missing > 0) {
    final batch = await drawApprovedBilgiQuestions(
      db,
      categoryId: tumuKarmaId,
      subcategory: '',
      difficulty: '',
      count: missing,
      exclude: seen,
      fullLocales: true,
    );
    for (final item in batch) {
      final id = '${item['id']}';
      if (!seen.add(id)) continue;
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

Future<Map<String, dynamic>> _payload(
  KeyValueStore store,
  String day,
  _ContestPaper paper,
  Map<String, Map<String, dynamic>> runs,
  Map<String, dynamic>? me,
) async {
  final ranking = <Map<String, dynamic>>[];
  for (final row in runs.values) {
    if (row['finished'] != true) continue;
    final userId = '${row['userId'] ?? ''}';
    final profile = userId.isEmpty ? null : await store.get('users', userId);
    final liveName = profile == null ? '' : '${profile['username'] ?? ''}'.trim();
    final liveAvatar = profile == null ? '' : '${profile['avatar'] ?? ''}'.trim();
    ranking.add({
      'id': userId,
      'name': liveName.isEmpty ? '${row['username'] ?? ''}' : liveName,
      'avatar': liveAvatar.isEmpty ? '${row['avatar'] ?? '😎'}' : liveAvatar,
      'score': bilgiInt(row['score'], 0),
      'seed': false,
    });
  }
  final board = bilgiDailyBoard([
    for (final row in ranking)
      BilgiBoardEntry(
        id: '${row['id'] ?? ''}',
        name: '${row['name'] ?? ''}',
        avatar: '${row['avatar'] ?? '😎'}',
        score: bilgiInt(row['score'], 0),
        seed: false,
      ),
  ]);
  return {
    'day': day,
    'title': paper.title,
    'questions': paper.questions,
    'spares': paper.spares,
    'joined': runs.length,
    'ranking': [
      for (final row in board)
        {
          'id': row.id,
          'name': row.name,
          'avatar': row.avatar,
          'score': row.score,
          'seed': row.seed,
          'rank': row.rank,
          if (row.city.isNotEmpty) 'city': row.city,
        },
    ],
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
  final day = (request.url.queryParameters['day'] ?? '').trim();
  if (day.isNotEmpty) return _adminDay(store, day);
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
  if (bilgiContestAiDay(day)) return _adminAiDay(store, day, body);
  final stored = await store.get(bilgiContestPaperBox, day);
  final incoming = body['questions'];
  if (incoming is List) {
    final cleaned = _cleanQuestions(incoming);
    if (cleaned == null) return jsonResponse({'error': 'Soru eksik veya şıklar dört değil.'}, status: 400);
    final exclude = await _monthIds(store, day.substring(0, 7), skip: day);
    _takeIds(cleaned, exclude);
    await store.put(bilgiContestPaperBox, day, {
      'day': day,
      'title': _titleOf(stored),
      'questions': cleaned,
      'spares': await _drawCounted(db, exclude, bilgiContestSpareCounts),
    });
    return jsonResponse(await _monthPayload(store, day.substring(0, 7), bilgiContestMonthDays(day.substring(0, 7))));
  }
  final rebuild = body['rebuild'] == true;
  final hasTitle = body.containsKey('title');
  var title = _titleOf(stored);
  if (hasTitle) {
    title = '${body['title'] ?? ''}'.trim();
    if (title.length > 40) return jsonResponse({'error': 'Ad 40 karakteri geçemez.'}, status: 400);
  }
  var questions = _questionsOf(stored);
  var spares = stored != null && stored.containsKey('spares') ? _sparesOf(stored) : null;
  if (rebuild || questions.isEmpty) {
    final exclude = await _monthIds(store, day.substring(0, 7), skip: day);
    questions = await _draw(db, exclude);
    spares = null;
  }
  if (spares == null) {
    final exclude = await _monthIds(store, day.substring(0, 7), skip: day);
    _takeIds(questions, exclude);
    spares = await _drawCounted(db, exclude, bilgiContestSpareCounts);
  }
  await store.put(bilgiContestPaperBox, day, {'day': day, 'title': title, 'questions': questions, 'spares': spares});
  return jsonResponse(await _monthPayload(store, day.substring(0, 7), bilgiContestMonthDays(day.substring(0, 7))));
}

Future<Response> _adminAiDay(KeyValueStore store, String day, Map<String, dynamic> body) async {
  final stored = await store.get(bilgiContestPaperBox, day);
  final hasTitle = body.containsKey('title');
  var title = _titleOf(stored);
  if (hasTitle) {
    title = '${body['title'] ?? ''}'.trim();
    if (title.length > 40) return jsonResponse({'error': 'Ad 40 karakteri geçemez.'}, status: 400);
  }
  final monthDays = bilgiContestMonthDays(day.substring(0, 7));
  final incoming = body['questions'];
  if (incoming is List) {
    final cleaned = _cleanQuestions(incoming);
    if (cleaned == null) return jsonResponse({'error': 'Soru eksik veya şıklar dört değil.'}, status: 400);
    await store.put(bilgiContestPaperBox, day, {
      'day': day,
      'title': title,
      'questions': cleaned,
      'spares': _sparesOf(stored),
    });
    return jsonResponse(await _monthPayload(store, day.substring(0, 7), monthDays));
  }
  if (body['generate'] == true) {
    final generated = await bilgiGenerateDailyPaper(day: day, avoidFacts: await _avoidFacts(store, day));
    if (generated.error != null) return jsonResponse({'error': generated.error}, status: 502);
    await store.put(bilgiContestPaperBox, day, {
      'day': day,
      'title': title,
      'questions': generated.questions,
      'spares': generated.spares,
    });
    return jsonResponse(await _monthPayload(store, day.substring(0, 7), monthDays));
  }
  await store.put(bilgiContestPaperBox, day, {
    'day': day,
    'title': title,
    'questions': _questionsOf(stored),
    'spares': _sparesOf(stored),
  });
  return jsonResponse(await _monthPayload(store, day.substring(0, 7), monthDays));
}

Future<List<String>> _avoidFacts(KeyValueStore store, String day) async {
  final facts = <String>[];
  final month = day.substring(0, 7);
  for (final other in bilgiContestMonthDays(month)) {
    final stored = await store.get(bilgiContestPaperBox, other);
    for (final row in [..._questionsOf(stored), ..._sparesOf(stored)]) {
      final text = '${row['text'] ?? ''}'.trim();
      if (text.isEmpty) continue;
      final options = row['options'];
      final correct = bilgiInt(row['correct'], -1);
      final answer = options is List && correct >= 0 && correct < options.length ? '${options[correct]}'.trim() : '';
      facts.add(answer.isEmpty ? text : '$text => $answer');
    }
  }
  return facts;
}

Future<void> _fillMonth(Connection db, KeyValueStore store, List<String> days) async {
  final locked = await _lockedDays(store);
  final used = <String>{};
  for (final day in days) {
    final stored = await store.get(bilgiContestPaperBox, day);
    _takeIds(_questionsOf(stored), used);
    _takeIds(_sparesOf(stored), used);
  }
  for (final day in days) {
    if (locked.contains(day) || bilgiContestAiDay(day)) continue;
    final stored = await store.get(bilgiContestPaperBox, day);
    if (_questionsOf(stored).isNotEmpty) continue;
    final picked = await _draw(db, used);
    _takeIds(picked, used);
    final spares = await _drawCounted(db, used, bilgiContestSpareCounts);
    _takeIds(spares, used);
    await store.put(bilgiContestPaperBox, day, {
      'day': day,
      'title': _titleOf(stored),
      'questions': picked,
      'spares': spares,
    });
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
    final stored = await store.get(bilgiContestPaperBox, day);
    _takeIds(_questionsOf(stored), ids);
    _takeIds(_sparesOf(stored), ids);
  }
  return ids;
}

String _titleOf(Map<String, dynamic>? row) {
  final title = '${row?['title'] ?? ''}'.trim();
  return title.length > 40 ? title.substring(0, 40) : title;
}

List<Map<String, dynamic>> _questionsOf(Map<String, dynamic>? row) => _mapsOf(row?['questions']);

List<Map<String, dynamic>> _sparesOf(Map<String, dynamic>? row) => _mapsOf(row?['spares']);

List<Map<String, dynamic>> _mapsOf(Object? saved) {
  if (saved is! List) return const [];
  return [for (final item in saved) if (item is Map) Map<String, dynamic>.from(item)];
}

Future<Response> _adminDay(KeyValueStore store, String day) async {
  if (!bilgiContestMonthDays(day.length >= 7 ? day.substring(0, 7) : '').contains(day)) {
    return jsonResponse({'error': 'Gün geçersiz.'}, status: 400);
  }
  final stored = await store.get(bilgiContestPaperBox, day);
  final locked = (await _lockedDays(store)).contains(day);
  final questions = _questionsOf(stored);
  return jsonResponse({
    'day': day,
    'title': _titleOf(stored),
    'locked': locked,
    'count': questions.length,
    'questions': questions,
  });
}

List<Map<String, dynamic>>? _cleanQuestions(List<dynamic> raw) {
  if (raw.length > 40) return null;
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) return null;
    final map = Map<String, dynamic>.from(item);
    final text = '${map['text'] ?? ''}'.trim();
    final options = map['options'];
    if (text.isEmpty || options is! List || options.length != 4) return null;
    final opts = [for (final option in options) '$option'.trim()];
    if (opts.any((option) => option.isEmpty)) return null;
    final correct = bilgiInt(map['correct'], -1);
    if (correct < 0 || correct > 3) return null;
    final difficulty = '${map['difficulty'] ?? 'kolay'}'.trim();
    if (!bilgiDifficultyLevels.contains(difficulty)) return null;
    final id = '${map['id'] ?? ''}'.trim();
    map['id'] = id.isEmpty ? 'gun${DateTime.now().microsecondsSinceEpoch}${out.length}' : id;
    map['text'] = text;
    map['options'] = opts;
    map['correct'] = correct;
    map['difficulty'] = difficulty;
    map['categoryId'] = '${map['categoryId'] ?? tumuKarmaId}'.trim();
    map['explanation'] = '${map['explanation'] ?? ''}'.trim();
    out.add(map);
  }
  return out;
}

void _takeIds(List<Map<String, dynamic>> questions, Set<String> into) {
  for (final item in questions) {
    final id = '${item['id'] ?? ''}'.trim();
    if (id.isNotEmpty) into.add(id);
  }
}
