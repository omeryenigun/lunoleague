import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';

class BilgiUserApi {
  static List<BilgiProfile> _profiles(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map) BilgiProfile.fromMap(Map<String, dynamic>.from(item)),
    ];
  }

  static Future<({List<BilgiProfile> listed, List<BilgiProfile> players})?> loadAll(String token) async {
    if (token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-users'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['users'] is! List) return null;
      final listed = _profiles(decoded['users']);
      final players = decoded['players'] is List ? _profiles(decoded['players']) : listed;
      return (listed: listed, players: players);
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

  /// Asks the server wallet to apply [op]. The phone displays the returned profile.
  static Future<BilgiWalletReply> wallet({required String op, required Map<String, dynamic> body}) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/wallet'),
            headers: {'content-type': 'application/json; charset=utf-8'},
            body: jsonEncode({'op': op, ...body}),
          )
          .timeout(const Duration(seconds: 12));
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return const BilgiWalletReply(error: 'İşlem tamamlanamadı.');
      if (response.statusCode < 200 || response.statusCode >= 300 || decoded['user'] is! Map) {
        final error = '${decoded['error'] ?? ''}'.trim();
        return BilgiWalletReply(error: error.isEmpty ? 'İşlem tamamlanamadı.' : error);
      }
      final userMap = Map<String, dynamic>.from(decoded['user'] as Map);
      return BilgiWalletReply(
        profile: BilgiProfile.fromMap(userMap),
        livesReported: userMap['lives'] != null,
      );
    } catch (_) {
      return const BilgiWalletReply(error: 'Bağlantı kurulamadı.');
    }
  }

  static Future<({List<BilgiLedgerLine> lines, String? error})> ledger(
    String token,
    String userId, {
    String asset = '',
    String reason = '',
    String from = '',
    String to = '',
  }) async {
    if (token.isEmpty) return (lines: const <BilgiLedgerLine>[], error: 'Yönetici oturumu gerekli.');
    try {
      final query = <String, String>{
        if (asset.isNotEmpty) 'asset': asset,
        if (reason.isNotEmpty) 'reason': reason,
        if (from.isNotEmpty) 'from': from,
        if (to.isNotEmpty) 'to': to,
      };
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-users/${Uri.encodeComponent(userId)}/ledger').replace(queryParameters: query),
        headers: {'authorization': 'Bearer $token'},
      );
      if (response.statusCode == 401) return (lines: const <BilgiLedgerLine>[], error: 'Oturum geçersiz.');
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return (lines: const <BilgiLedgerLine>[], error: 'Hareketler alınamadı.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['lines'] is! List) {
        return (lines: const <BilgiLedgerLine>[], error: 'Hareketler alınamadı.');
      }
      return (
        lines: [
          for (final item in decoded['lines'] as List)
            if (item is Map) BilgiLedgerLine.fromMap(Map<String, dynamic>.from(item)),
        ],
        error: null,
      );
    } catch (_) {
      return (lines: const <BilgiLedgerLine>[], error: 'Hareketler alınamadı.');
    }
  }

  /// Pushes a registered Bilgi account and returns the saved public profile.
  static Future<Map<String, dynamic>?> upsert(BilgiProfile user) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/users'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode(user.toMap()),
      );
      if (response.statusCode == 409 && _error(response.body) == UserMessages.nicknameTaken) {
        throw const BilgiUsernameTaken();
      }
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['user'] is! Map) return null;
      return Map<String, dynamic>.from(decoded['user'] as Map);
    } on BilgiUsernameTaken {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  static String? _error(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] != null) return '${decoded['error']}';
    } catch (_) {}
    return null;
  }
}
