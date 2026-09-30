import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

class BilgiUserApi {
  static Future<List<BilgiProfile>?> loadAll(String token) async {
    if (token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-users'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['users'] is! List) return null;
      return [
        for (final item in decoded['users'] as List)
          if (item is Map) BilgiProfile.fromMap(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<String?> setBan(
    String token,
    String userId, {
    required bool banned,
    String reason = '',
  }) async {
    if (token.isEmpty) return 'Yönetici oturumu gerekli.';
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-users/${Uri.encodeComponent(userId)}'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'banned': banned,
          'banReason': reason,
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      return _error(response.body) ?? 'Ban güncellenemedi.';
    } catch (_) {
      return 'Ban güncellenemedi.';
    }
  }

  /// Pushes a registered Bilgi account to the shared server list (best-effort).
  static Future<void> upsert(BilgiProfile user) async {
    if (user.email.trim().isEmpty && user.passwordHash.isEmpty) return;
    try {
      await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/users'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode(user.toMap()),
      );
    } catch (_) {}
  }

  static String? _error(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) return '${decoded['error']}';
    } catch (_) {}
    return null;
  }
}
