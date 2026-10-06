import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room.dart';

class BilgiRoomApi {
  static BilgiRoomHooks hooks() {
    return BilgiRoomHooks(
      create: create,
      join: join,
      poll: poll,
      start: start,
      score: score,
      leave: leave,
    );
  }

  static Future<BilgiRoomSync> create({
    required String kind,
    required String playerId,
    required String name,
    required String categoryId,
    required String subcategory,
    required String difficulty,
    required int questionCount,
    required int seconds,
  }) {
    return _send('/v1/bilgi/rooms', {
      'kind': kind,
      'playerId': playerId,
      'name': name,
      'categoryId': categoryId,
      'subcategory': subcategory,
      'difficulty': difficulty,
      'questionCount': questionCount,
      'seconds': seconds,
    });
  }

  static Future<BilgiRoomSync> join({
    required String code,
    required String playerId,
    required String name,
  }) {
    return _send('/v1/bilgi/rooms/${Uri.encodeComponent(code)}/join', {
      'playerId': playerId,
      'name': name,
    });
  }

  static Future<BilgiRoomSync> start({
    required String code,
    required String playerId,
  }) {
    return _send('/v1/bilgi/rooms/${Uri.encodeComponent(code)}/start', {
      'playerId': playerId,
    });
  }

  static Future<BilgiRoomSync> poll(String code) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/rooms/${Uri.encodeComponent(code)}'),
      );
      return _read(response.statusCode, response.body);
    } catch (_) {
      return const BilgiRoomSync(message: 'Oda açılamadı. Bağlantını kontrol et.');
    }
  }

  static Future<bool> leave({
    required String code,
    required String playerId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/rooms/${Uri.encodeComponent(code)}/leave'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({'playerId': playerId}),
      );
      return response.statusCode == 404 || (response.statusCode >= 200 && response.statusCode < 300);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> score({
    required String code,
    required String playerId,
    required int score,
    required int index,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/rooms/${Uri.encodeComponent(code)}/score'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'playerId': playerId,
          'score': score,
          'index': index,
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<BilgiRoomSync> _send(String path, Map<String, Object> body) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode(body),
      );
      return _read(response.statusCode, response.body);
    } catch (_) {
      return const BilgiRoomSync(message: 'Oda açılamadı. Bağlantını kontrol et.');
    }
  }

  static BilgiRoomSync _read(int status, String body) {
    Map<String, dynamic>? decoded;
    try {
      final raw = jsonDecode(body);
      if (raw is Map) decoded = Map<String, dynamic>.from(raw);
    } catch (_) {}
    if (decoded == null) {
      return const BilgiRoomSync(message: 'Oda açılamadı. Bağlantını kontrol et.');
    }
    if (status < 200 || status >= 300) {
      return BilgiRoomSync(message: '${decoded['error'] ?? 'Oda açılamadı. Bağlantını kontrol et.'}');
    }
    final roomRaw = decoded['room'];
    if (roomRaw is! Map) {
      return const BilgiRoomSync(message: 'Oda açılamadı. Bağlantını kontrol et.');
    }
    final questions = _questions(decoded['questions']);
    final listed = _questions(decoded['spares']);
    final spareRaw = decoded['spare'];
    final spare = spareRaw is Map ? BilgiQuestion.fromMap(Map<String, dynamic>.from(spareRaw)) : null;
    return BilgiRoomSync(
      room: BilgiRoom.fromMap(Map<String, dynamic>.from(roomRaw)),
      questions: questions,
      spare: spare,
      spares: listed.isNotEmpty ? listed : (spare == null ? const [] : [spare]),
    );
  }

  static List<BilgiQuestion> _questions(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) BilgiQuestion.fromMap(Map<String, dynamic>.from(item)),
    ];
  }
}
