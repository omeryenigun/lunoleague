import 'dart:convert';
import 'dart:math';

import 'package:kelimelig/api/admin_http.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

final _random = Random.secure();

const _statuses = {'bekliyor', 'dikkate_alindi', 'dikkate_alinmadi'};

Future<void> migrateBilgiReports(Connection db) async {
  await db.execute('''
    create table if not exists bilgi_question_reports (
      id text primary key,
      question_id text not null,
      question_text text not null,
      options_json text not null,
      correct int not null,
      category_id text not null,
      difficulty text not null,
      note text not null,
      status text not null default 'bekliyor',
      created_at timestamptz not null default now()
    )
  ''');
  await db.execute(
    "alter table bilgi_question_reports add column if not exists status text not null default 'bekliyor'",
  );
}

void mountBilgiReports(Router router, Connection db) {
  router
    ..post('/v1/bilgi/question-reports', (request) => _create(request, db))
    ..get('/v1/admin/bilgi-question-reports', (request) => _list(request, db))
    ..patch('/v1/admin/bilgi-question-reports/<id>', (Request request, String id) {
      return _setStatus(request, db, id);
    });
}

Future<Response> _create(Request request, Connection db) async {
  final body = await readJson(request);
  final questionId = '${body['questionId'] ?? ''}'.trim();
  final questionText = '${body['questionText'] ?? ''}'.trim();
  final note = '${body['note'] ?? ''}'.trim();
  final categoryId = '${body['categoryId'] ?? ''}'.trim();
  final difficulty = '${body['difficulty'] ?? ''}'.trim();
  final options = body['options'];
  final correct = body['correct'];
  if (questionId.isEmpty || questionText.isEmpty) {
    return jsonResponse({'error': 'Soru bulunamadı.'}, status: 400);
  }
  if (note.isEmpty) return jsonResponse({'error': 'Açıklama zorunlu.'}, status: 400);
  if (note.length > 800) {
    return jsonResponse({'error': 'Açıklama en fazla 800 karakter olabilir.'}, status: 400);
  }
  if (options is! List || options.length != 4 || correct is! int || correct < 0 || correct > 3) {
    return jsonResponse({'error': 'Soru bulunamadı.'}, status: 400);
  }
  final id = 'r${DateTime.now().microsecondsSinceEpoch}${_random.nextInt(1000)}';
  await db.execute(
    Sql.named('''
      insert into bilgi_question_reports (
        id, question_id, question_text, options_json, correct, category_id, difficulty, note, status
      ) values (
        @id, @questionId, @questionText, @options, @correct, @categoryId, @difficulty, @note, 'bekliyor'
      )
    '''),
    parameters: {
      'id': id,
      'questionId': questionId,
      'questionText': questionText,
      'options': jsonEncode(options.map((item) => '$item').toList()),
      'correct': correct,
      'categoryId': categoryId,
      'difficulty': difficulty,
      'note': note,
    },
  );
  return jsonResponse({'ok': true});
}

Future<Response> _list(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final rows = await db.execute('''
    select id, question_id, question_text, options_json, correct, category_id, difficulty, note, created_at, status
    from bilgi_question_reports
    order by created_at desc
    limit 200
  ''');
  return jsonResponse({
    'reports': [
      for (final row in rows)
        {
          'id': row[0],
          'questionId': row[1],
          'questionText': row[2],
          'options': _options(row[3]),
          'correct': row[4],
          'categoryId': row[5],
          'difficulty': row[6],
          'note': row[7],
          'createdAt': '${row[8]}',
          'status': _status(row[9]),
        },
    ],
  });
}

Future<Response> _setStatus(Request request, Connection db, String id) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final reportId = id.trim();
  if (reportId.isEmpty) {
    return jsonResponse({'error': 'Bildirim bulunamadı.'}, status: 404);
  }
  final body = await readJson(request);
  final status = _status(body['status']);
  if (!_statuses.contains('${body['status'] ?? ''}'.trim())) {
    return jsonResponse({'error': 'Durum geçersiz.'}, status: 400);
  }
  final updated = await db.execute(
    Sql.named('''
      update bilgi_question_reports
      set status = @status
      where id = @id
      returning id
    '''),
    parameters: {'id': reportId, 'status': status},
  );
  if (updated.isEmpty) {
    return jsonResponse({'error': 'Bildirim bulunamadı.'}, status: 404);
  }
  return jsonResponse({'ok': true, 'id': reportId, 'status': status});
}

String _status(Object? raw) {
  final value = '$raw'.trim();
  if (_statuses.contains(value)) return value;
  return 'bekliyor';
}

List<String> _options(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return decoded.map((item) => '$item').toList();
  } catch (_) {}
  return const [];
}
