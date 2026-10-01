import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';

class BilgiLeagueApi {
  static Future<BilgiLeagueSnapshot?> load({
    required String scope,
    String? categoryId,
    bool categoryWeekly = false,
    String? me,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/v1/bilgi/league').replace(
        queryParameters: {
          'scope': scope,
          if (categoryId != null && categoryId.isNotEmpty) 'categoryId': categoryId,
          if (categoryWeekly) 'weekly': '1',
          if (me != null && me.isNotEmpty) 'me': me,
        },
      );
      final response = await http.get(uri);
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      return BilgiLeagueSnapshot.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }
}
