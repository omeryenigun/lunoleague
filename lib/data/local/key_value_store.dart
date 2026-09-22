abstract class KeyValueStore {
  Future<void> put(String box, String key, Map<String, dynamic> value);
  Future<Map<String, dynamic>?> get(String box, String key);
  Future<void> delete(String box, String key);
  Future<List<Map<String, dynamic>>> values(String box);
  Future<void> putMeta(String key, String value);
  Future<String?> getMeta(String key);
}

class MemoryKeyValueStore implements KeyValueStore {
  final _boxes = <String, Map<String, Map<String, dynamic>>>{};
  final _meta = <String, String>{};

  Map<String, Map<String, dynamic>> _box(String name) =>
      _boxes.putIfAbsent(name, () => {});

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) async {
    _box(box)[key] = Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) async {
    final v = _box(box)[key];
    return v == null ? null : Map<String, dynamic>.from(v);
  }

  @override
  Future<void> delete(String box, String key) async => _box(box).remove(key);

  @override
  Future<List<Map<String, dynamic>>> values(String box) async =>
      _box(box).values.map(Map<String, dynamic>.from).toList();

  @override
  Future<void> putMeta(String key, String value) async => _meta[key] = value;

  @override
  Future<String?> getMeta(String key) async => _meta[key];
}
