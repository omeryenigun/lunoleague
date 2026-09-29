import 'dart:convert';
import 'dart:math';

import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/bilgi_questions_http.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _kinds = {'duello', 'grup', 'oda'};

Future<void> migrateBilgiRooms(Connection db) async {
  await db.execute('''
    create table if not exists bilgi_rooms (
      code text primary key,
      kind text not null,
      host_id text not null,
      host_name text not null,
      category_id text not null,
      subcategory text not null default '',
      difficulty text not null default '',
      question_count int not null,
      seconds int not null,
      status text not null,
      questions_json text not null default '[]',
      spare_json text not null default '',
      created_at timestamptz not null default now()
    )
  ''');
  await db.execute('''
    create table if not exists bilgi_room_players (
      room_code text not null references bilgi_rooms(code) on delete cascade,
      player_id text not null,
      name text not null,
      role text not null,
      score int not null default 0,
      question_index int not null default 0,
      primary key (room_code, player_id)
    )
  ''');
  await db.execute(
    'create index if not exists bilgi_rooms_open on bilgi_rooms (kind, status)',
  );
}

void mountBilgiRooms(Router router, Connection db) {
  router
    ..post('/v1/bilgi/rooms', (request) => _create(request, db))
    ..get('/v1/bilgi/rooms/open', (request) => _open(request, db))
    ..get('/v1/bilgi/rooms/<code>', (Request request, String code) => _poll(db, code))
    ..post('/v1/bilgi/rooms/<code>/join', (Request request, String code) => _join(request, db, code))
    ..post('/v1/bilgi/rooms/<code>/start', (Request request, String code) => _start(request, db, code))
    ..post('/v1/bilgi/rooms/<code>/score', (Request request, String code) => _score(request, db, code));
}

Future<Response> _create(Request request, Connection db) async {
  final body = await readJson(request);
  final kind = '${body['kind'] ?? 'oda'}'.trim();
  final playerId = _id(body['playerId']);
  final name = _name(body['name']);
  if (!_kinds.contains(kind) || playerId == null || name == null) {
    return jsonResponse({'error': 'Oda isteği geçersiz.'}, status: 400);
  }
  final categoryId = '${body['categoryId'] ?? tumuKarmaId}'.trim();
  final subcategory = '${body['subcategory'] ?? ''}'.trim();
  final difficulty = '${body['difficulty'] ?? ''}'.trim();
  if (categoryId.isEmpty || categoryId.length > 80 || subcategory.length > 80 || difficulty.length > 20) {
    return jsonResponse({'error': 'Oda isteği geçersiz.'}, status: 400);
  }
  final code = await _freshCode(db);
  if (code == null) return jsonResponse({'error': 'Oda açılamadı. Bağlantını kontrol et.'}, status: 503);
  final count = kind == 'duello' ? 10 : 20;
  final seconds = kind == 'duello' ? 10 : 15;
  await db.execute(
    Sql.named('''
      insert into bilgi_rooms (
        code, kind, host_id, host_name, category_id, subcategory, difficulty,
        question_count, seconds, status
      ) values (
        @code, @kind, @hostId, @hostName, @categoryId, @subcategory, @difficulty,
        @count, @seconds, 'lobby'
      )
    '''),
    parameters: {
      'code': code,
      'kind': kind,
      'hostId': playerId,
      'hostName': name,
      'categoryId': categoryId,
      'subcategory': subcategory,
      'difficulty': difficulty,
      'count': count,
      'seconds': seconds,
    },
  );
  await _seat(db, code: code, playerId: playerId, name: name, role: 'host');
  return jsonResponse(await _payload(db, code, includeQuestions: false));
}

Future<Response> _open(Request request, Connection db) async {
  final kind = (request.url.queryParameters['kind'] ?? 'grup').trim();
  if (kind != 'grup') return jsonResponse({'error': 'Açık grup odası yok.'}, status: 404);
  final rows = await db.execute('''
    select code from bilgi_rooms
    where kind = 'grup' and status = 'lobby'
    order by created_at
    limit 8
  ''');
  for (final row in rows) {
    final code = '${row[0]}';
    final players = await _players(db, code);
    if (players.length < 10) {
      return jsonResponse(await _payload(db, code, includeQuestions: false));
    }
  }
  return jsonResponse({'error': 'Açık grup odası yok.'}, status: 404);
}

Future<Response> _join(Request request, Connection db, String code) async {
  final room = await _room(db, code);
  if (room == null) return jsonResponse({'error': 'Oda bulunamadı.'}, status: 404);
  if (room['status'] != 'lobby') {
    return jsonResponse({'error': 'Oda başladı.'}, status: 409);
  }
  final body = await readJson(request);
  final playerId = _id(body['playerId']);
  final name = _name(body['name']);
  if (playerId == null || name == null) {
    return jsonResponse({'error': 'Oda isteği geçersiz.'}, status: 400);
  }
  final players = await _players(db, room['code'] as String);
  final cap = room['kind'] == 'duello' ? 2 : 10;
  final already = players.any((player) => player['id'] == playerId);
  if (!already && players.length >= cap) {
    return jsonResponse({'error': 'Oda dolu.'}, status: 409);
  }
  await _seat(
    db,
    code: room['code'] as String,
    playerId: playerId,
    name: name,
    role: playerId == room['hostId'] ? 'host' : 'player',
  );
  return jsonResponse(await _payload(db, room['code'] as String, includeQuestions: false));
}

Future<Response> _start(Request request, Connection db, String code) async {
  final room = await _room(db, code);
  if (room == null) return jsonResponse({'error': 'Oda bulunamadı.'}, status: 404);
  final body = await readJson(request);
  final playerId = _id(body['playerId']);
  if (playerId == null) return jsonResponse({'error': 'Oda isteği geçersiz.'}, status: 400);
  if (playerId != room['hostId']) {
    return jsonResponse({'error': 'Odayı kuran başlatır.'}, status: 403);
  }
  if (room['status'] == 'playing') {
    return jsonResponse(await _payload(db, room['code'] as String, includeQuestions: true));
  }
  final count = room['questionCount'] as int;
  final picked = await drawApprovedBilgiQuestions(
    db,
    categoryId: '${room['categoryId']}',
    subcategory: '${room['subcategory']}',
    difficulty: '${room['difficulty']}',
    count: count + 1,
  );
  if (picked.length < count) {
    return jsonResponse({'error': '❓ Bu kategoride yeterli soru yok.'}, status: 409);
  }
  final questions = picked.sublist(0, count);
  final spare = picked.length > count ? picked[count] : null;
  await db.execute(
    Sql.named('''
      update bilgi_rooms
      set status = 'playing',
          questions_json = @questions,
          spare_json = @spare
      where code = @code and status = 'lobby'
    '''),
    parameters: {
      'code': room['code'],
      'questions': jsonEncode(questions),
      'spare': spare == null ? '' : jsonEncode(spare),
    },
  );
  return jsonResponse(await _payload(db, room['code'] as String, includeQuestions: true));
}

Future<Response> _score(Request request, Connection db, String code) async {
  final room = await _room(db, code);
  if (room == null) return jsonResponse({'error': 'Oda bulunamadı.'}, status: 404);
  final body = await readJson(request);
  final playerId = _id(body['playerId']);
  final score = body['score'];
  final index = body['index'];
  final points = score is int ? score : (score is num ? score.toInt() : null);
  final at = index is int ? index : (index is num ? index.toInt() : null);
  if (playerId == null || points == null || at == null || points < 0 || points > 1000000 || at < 0 || at > 60) {
    return jsonResponse({'error': 'Puan isteği geçersiz.'}, status: 400);
  }
  final updated = await db.execute(
    Sql.named('''
      update bilgi_room_players
      set score = @score, question_index = @index
      where room_code = @code and player_id = @playerId
    '''),
    parameters: {
      'code': room['code'],
      'playerId': playerId,
      'score': points,
      'index': at,
    },
  );
  if (updated.affectedRows == 0) {
    return jsonResponse({'error': 'Oyuncu odada değil.'}, status: 404);
  }
  return jsonResponse({'ok': true});
}

Future<Response> _poll(Connection db, String code) async {
  final room = await _room(db, code);
  if (room == null) return jsonResponse({'error': 'Oda bulunamadı.'}, status: 404);
  return jsonResponse(await _payload(db, room['code'] as String, includeQuestions: room['status'] == 'playing'));
}

Future<String?> _freshCode(Connection db) async {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final random = Random();
  for (var attempt = 0; attempt < 6; attempt++) {
    final code = 'LB${List.generate(4, (_) => alphabet[random.nextInt(alphabet.length)]).join()}';
    final taken = await db.execute(
      Sql.named('select 1 from bilgi_rooms where code = @code'),
      parameters: {'code': code},
    );
    if (taken.isEmpty) return code;
  }
  return null;
}

Future<void> _seat(
  Connection db, {
  required String code,
  required String playerId,
  required String name,
  required String role,
}) async {
  await db.execute(
    Sql.named('''
      insert into bilgi_room_players (room_code, player_id, name, role)
      values (@code, @playerId, @name, @role)
      on conflict (room_code, player_id) do update set name = excluded.name
    '''),
    parameters: {
      'code': code,
      'playerId': playerId,
      'name': name,
      'role': role,
    },
  );
}

Future<Map<String, dynamic>?> _room(Connection db, String code) async {
  final key = code.trim().toUpperCase();
  if (key.isEmpty || key.length > 12) return null;
  final rows = await db.execute(
    Sql.named('''
      select code, kind, host_id, host_name, category_id, subcategory, difficulty,
             question_count, seconds, status, questions_json, spare_json
      from bilgi_rooms
      where code = @code
    '''),
    parameters: {'code': key},
  );
  if (rows.isEmpty) return null;
  final row = rows.first;
  return {
    'code': '${row[0]}',
    'kind': '${row[1]}',
    'hostId': '${row[2]}',
    'hostName': '${row[3]}',
    'categoryId': '${row[4]}',
    'subcategory': '${row[5]}',
    'difficulty': '${row[6]}',
    'questionCount': row[7] is int ? row[7] as int : int.parse('${row[7]}'),
    'seconds': row[8] is int ? row[8] as int : int.parse('${row[8]}'),
    'status': '${row[9]}',
    'questions': _maps(row[10]),
    'spare': _one(row[11]),
  };
}

Future<List<Map<String, String>>> _players(Connection db, String code) async {
  final rows = await db.execute(
    Sql.named('''
      select player_id, name, role, score, question_index
      from bilgi_room_players
      where room_code = @code
      order by case when role = 'host' then 0 else 1 end, name
    '''),
    parameters: {'code': code},
  );
  return [
    for (final row in rows)
      {
        'id': '${row[0]}',
        'name': '${row[1]}',
        'role': '${row[2]}',
        'score': '${row[3]}',
        'index': '${row[4]}',
      },
  ];
}

Future<Map<String, dynamic>> _payload(
  Connection db,
  String code, {
  required bool includeQuestions,
}) async {
  final room = await _room(db, code);
  if (room == null) return {'error': 'Oda bulunamadı.'};
  final players = await _players(db, code);
  return {
    'room': {
      'code': room['code'],
      'kind': room['kind'],
      'hostId': room['hostId'],
      'hostName': room['hostName'],
      'categoryId': room['categoryId'],
      'subcategory': room['subcategory'],
      'difficulty': room['difficulty'],
      'questionCount': room['questionCount'],
      'seconds': room['seconds'],
      'status': room['status'],
      'players': players,
    },
    'questions': includeQuestions ? room['questions'] : const [],
    'spare': includeQuestions ? room['spare'] : null,
  };
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];
    return [
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  } catch (_) {
    return const [];
  }
}

Map<String, dynamic>? _one(Object? raw) {
  if (raw is! String || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}

String? _id(Object? raw) {
  final value = '${raw ?? ''}'.trim();
  if (value.isEmpty || value.length > 80) return null;
  return value;
}

String? _name(Object? raw) {
  final value = '${raw ?? ''}'.trim();
  if (value.isEmpty) return null;
  return value.length > 40 ? value.substring(0, 40) : value;
}
