import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_report.dart';

class BilgiReportApi {
  static Future<String?> send({required BilgiQuestion question, required String note}) async {
    final error = bilgiReportNoteError(note);
    if (error != null) return error;
    if (question.id.trim().isEmpty || question.text.trim().isEmpty) return 'Soru bulunamadı.';
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/question-reports'),
        headers: {'content-type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'questionId': question.id,
          'questionText': question.text,
          'options': question.options,
          'correct': question.correct,
          'categoryId': question.categoryId,
          'difficulty': question.difficulty,
          'note': note.trim(),
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      final decoded = _json(response.body);
      return '${decoded['error'] ?? 'Bildirim gönderilemedi.'}';
    } catch (_) {
      return 'Bildirim gönderilemedi.';
    }
  }

  static Future<List<BilgiQuestionReport>?> load(String token) async {
    if (token.isEmpty) return null;
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-question-reports'),
        headers: {'authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['reports'] is! List) return null;
      return [
        for (final item in decoded['reports'] as List)
          if (item is Map) BilgiQuestionReport.fromJson(Map<String, dynamic>.from(item)),
      ];
    } catch (_) {
      return null;
    }
  }

  static Future<String?> setStatus({
    required String token,
    required String reportId,
    required String status,
  }) async {
    if (token.isEmpty) return 'Bildirimler için yönetici oturumu gerekli.';
    final id = reportId.trim();
    if (id.isEmpty) return 'Bildirim bulunamadı.';
    final next = normalizeBilgiReportStatus(status);
    if (status.trim() != next) return 'Durum geçersiz.';
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}/v1/admin/bilgi-question-reports/$id'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({'status': next}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) return null;
      final decoded = _json(response.body);
      return '${decoded['error'] ?? 'Durum güncellenemedi.'}';
    } catch (_) {
      return 'Durum güncellenemedi.';
    }
  }

  static Map<String, dynamic> _json(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }
}
