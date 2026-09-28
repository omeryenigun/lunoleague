import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/core/mail/mail_template.dart';

class BilgiMailApi {
  static Future<String> sendReset(String email) async {
    return _message(
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/password-reset'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({'email': email.trim()}),
      ),
      fallback: 'E-posta gönderilemedi.',
      ok: 'Sıfırlama kodu e-postana gönderildi.',
    );
  }

  static Future<String?> confirm(String email, String code) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/password-reset/confirm'),
      headers: {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return null;
    final decoded = _json(response.body);
    return '${decoded['error'] ?? 'Kod geçersiz.'}';
  }

  static Future<MailTemplate?> load(String token) async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/v1/admin/mail-template'),
      headers: _auth(token),
    );
    if (response.statusCode != 200) return null;
    final decoded = _json(response.body);
    return MailTemplate.fromJson(decoded);
  }

  static Future<String?> save(String token, MailTemplate template) async {
    final response = await http.put(
      Uri.parse('${ApiConfig.baseUrl}/v1/admin/mail-template'),
      headers: _auth(token),
      body: jsonEncode(template.toJson()),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) return null;
    return '${_json(response.body)['error'] ?? 'Şablon kaydedilemedi.'}';
  }

  static Future<String> sendTest(String token, String email) async {
    return _message(
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/mail-test'),
        headers: _auth(token),
        body: jsonEncode({'to': email.trim()}),
      ),
      fallback: 'Deneme maili gönderilemedi.',
      ok: 'Deneme maili gönderildi.',
    );
  }

  static Map<String, String> _auth(String token) => {
        'content-type': 'application/json; charset=utf-8',
        'authorization': 'Bearer $token',
      };

  static Future<String> _message(http.Response response, {required String fallback, required String ok}) async {
    final decoded = _json(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return '${decoded['message'] ?? ok}';
    }
    return '${decoded['error'] ?? fallback}';
  }

  static Map<String, dynamic> _json(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return {};
  }
}
