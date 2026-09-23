import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/core/constants/game_version.dart';

Future<String> readLiveGameVersion() async {
  final fallback = GameVersion.parse(gameVersionCode).label;
  try {
    final root = ApiConfig.baseUrl.endsWith('/')
        ? ApiConfig.baseUrl.substring(0, ApiConfig.baseUrl.length - 1)
        : ApiConfig.baseUrl;
    final response = await http
        .get(Uri.parse('$root/v1/version'))
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return fallback;
    final decoded = jsonDecode(response.body);
    if (decoded is Map && decoded['version'] is String) {
      final label = decoded['version'] as String;
      if (label.isNotEmpty) return label;
    }
  } catch (_) {}
  return fallback;
}
