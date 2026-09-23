import 'package:hive_flutter/hive_flutter.dart';
import 'package:kelimelig/data/local/key_value_store.dart';

class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore(this._boxes, this._meta);

  final Map<String, Box<dynamic>> _boxes;
  final Box<dynamic> _meta;

  static Future<HiveKeyValueStore> open() async {
    final boxes = <String, Box<dynamic>>{};
    for (final n in legacyBoxNames) {
      boxes[n] = await Hive.openBox(n);
    }
    final meta = await Hive.openBox('app_meta');
    return HiveKeyValueStore(boxes, meta);
  }

  static const legacyBoxNames = [
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
    'shop_products',
    'auth_accounts',
  ];

  Future<Box<dynamic>> _ensure(String name) async {
    final existing = _boxes[name];
    if (existing != null && existing.isOpen) return existing;
    final box = await Hive.openBox(name);
    _boxes[name] = box;
    return box;
  }

  /// Copies pre-isolation boxes into `{gameId}__*` once.
  /// Destination boxes that already have rows are left untouched.
  Future<void> adoptLegacyBoxes(String gameId) async {
    final flag = '${gameId}__legacy_adopted';
    if (_meta.get(flag) == '1') return;
    for (final name in legacyBoxNames) {
      final legacy = _boxes[name];
      if (legacy == null || legacy.isEmpty) continue;
      final dest = await _ensure('${gameId}__$name');
      if (dest.isNotEmpty) continue;
      for (final key in legacy.keys) {
        final value = legacy.get(key);
        await dest.put(
          key,
          value is Map ? Map<String, dynamic>.from(value) : value,
        );
      }
    }
    final keys = _meta.keys.map((key) => key.toString()).toList();
    for (final key in keys) {
      if (key.contains('__')) continue;
      final scoped = '${gameId}__$key';
      if (_meta.containsKey(scoped)) continue;
      await _meta.put(scoped, _meta.get(key));
    }
    await _meta.put(flag, '1');
  }

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    await (await _ensure(box)).put(key, value);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) async {
    final v = (await _ensure(box)).get(key);
    if (v == null) return null;
    return Map<String, dynamic>.from(v as Map);
  }

  @override
  Future<void> delete(String box, String key) async {
    await (await _ensure(box)).delete(key);
  }

  @override
  Future<List<Map<String, dynamic>>> values(String box) async {
    return (await _ensure(box))
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
