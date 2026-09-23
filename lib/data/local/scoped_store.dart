import 'package:kelimelig/data/local/key_value_store.dart';

/// One game's view of a shared store. Boxes and meta keys are prefixed so
/// games cannot read or write each other's data.
class ScopedKeyValueStore implements KeyValueStore {
  ScopedKeyValueStore(this._inner, this.gameId)
      : assert(gameId.isNotEmpty),
        assert(!gameId.contains('__'));

  final KeyValueStore _inner;
  final String gameId;

  static String boxName(String gameId, String box) => '${gameId}__$box';

  static String metaKey(String gameId, String key) => '${gameId}__$key';

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) {
    return _inner.put(boxName(gameId, box), key, value);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) {
    return _inner.get(boxName(gameId, box), key);
  }

  @override
  Future<void> delete(String box, String key) {
    return _inner.delete(boxName(gameId, box), key);
  }

  @override
  Future<List<Map<String, dynamic>>> values(String box) {
    return _inner.values(boxName(gameId, box));
  }

  @override
  Future<void> putMeta(String key, String value) {
    return _inner.putMeta(metaKey(gameId, key), value);
  }

  @override
  Future<String?> getMeta(String key) {
    return _inner.getMeta(metaKey(gameId, key));
  }
}
