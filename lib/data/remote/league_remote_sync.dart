import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/domain/game/game_ids.dart';

/// Pulls published Luno League content from the API into this device's store.
/// Luno Fall is not part of this project and is left untouched.
Future<void> syncLunoLeagueContent(KeyValueStore store) async {
  final base = ApiConfig.baseUrl.trim();
  if (base.isEmpty) return;
  final root = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final uri = Uri.parse('$root/v1/games/${GameIds.lunoLeague}/bootstrap');
  try {
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return;
    final body = jsonDecode(response.body);
    if (body is Map<String, dynamic>) {
      await applyLeagueBootstrap(store, body);
    } else if (body is Map) {
      await applyLeagueBootstrap(store, Map<String, dynamic>.from(body));
    }
  } catch (_) {
    // Offline or API down: the installed game keeps its local copy.
  }
}

Future<void> applyLeagueBootstrap(
  KeyValueStore store,
  Map<String, dynamic> body,
) async {
  final config = body['config'];
  if (config is Map) {
    await store.put(
      'app_config',
      'default',
      Map<String, dynamic>.from(config),
    );
  }
  final shop = body['shop'];
  if (shop is List) {
    for (final item in shop) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id'];
      if (id is String && id.isNotEmpty) {
        await store.put('shop_products', id, map);
      }
    }
  }
  final words = body['words'];
  if (words is List && words.isNotEmpty) {
    for (final item in words) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final id = map['id'];
      if (id is String && id.isNotEmpty) {
        await store.put('words', id, map);
      }
    }
  }
  final daily = body['daily'];
  if (daily is List && daily.isNotEmpty) {
    for (final item in daily) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final date = map['date'];
      final league = map['league'];
      final language = map['language'] ?? 'tr';
      if (date is String && league is String) {
        await store.put('daily_games', '${date}_${language}_$league', map);
        if (language == 'tr') {
          await store.put('daily_games', '${date}_$league', map);
        }
      }
    }
  }
}
