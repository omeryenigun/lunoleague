import 'package:hive_flutter/hive_flutter.dart';
import 'package:kelimelig/data/local/key_value_store.dart';

class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore(this._boxes, this._meta);

  final Map<String, Box<dynamic>> _boxes;
  final Box<dynamic> _meta;

  static Future<HiveKeyValueStore> open() async {
    const names = [
      'users',
      'words',
      'game_sessions',
      'game_results',
      'daily_games',
      'wallets',
      'wallet_transactions',
      'user_words',
      'league_players',
      'weekly_leagues',
      'user_achievements',
      'app_config',
      'npc_players',
      'period_scores',
    ];
    final boxes = <String, Box<dynamic>>{};
    for (final n in names) {
      boxes[n] = await Hive.openBox(n);
    }
    final meta = await Hive.openBox('app_meta');
    return HiveKeyValueStore(boxes, meta);
  }

  Box<dynamic> _box(String name) => _boxes[name]!;

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    await _box(box).put(key, value);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) async {
    final v = _box(box).get(key);
    if (v == null) return null;
    return Map<String, dynamic>.from(v as Map);
  }

  @override
  Future<void> delete(String box, String key) async {
    await _box(box).delete(key);
  }

  @override
  Future<List<Map<String, dynamic>>> values(String box) async {
    return _box(box)
        .values
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  @override
  Future<void> putMeta(String key, String value) async {
    await _meta.put(key, value);
  }

  @override
  Future<String?> getMeta(String key) async {
    return _meta.get(key) as String?;
  }
}
