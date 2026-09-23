import 'package:kelimelig/data/local/key_value_store.dart';

/// Overlays the signed-in player and device locale for one request.
///
/// [LocalGameServer] stores `currentUserId` and `device_locale` as meta on a
/// single device. Those two keys stay on this object so concurrent HTTP
/// requests do not replace each other's player. Every other box and meta key
/// is shared.
class SessionKv implements KeyValueStore {
  SessionKv(this._inner, {this.userId, this.locale});

  final KeyValueStore _inner;

  /// Matches `LocalGameServer`'s current-user meta key.
  static const currentUserKey = 'currentUserId';

  /// Matches `LocalGameServer`'s device-locale meta key.
  static const deviceLocaleKey = 'device_locale';

  String? userId;
  String? locale;

  @override
  Future<void> put(String box, String key, Map<String, dynamic> value) {
    return _inner.put(box, key, value);
  }

  @override
  Future<Map<String, dynamic>?> get(String box, String key) {
    return _inner.get(box, key);
  }

  @override
  Future<void> delete(String box, String key) {
    return _inner.delete(box, key);
  }

  @override
  Future<List<Map<String, dynamic>>> values(String box) {
    return _inner.values(box);
  }

  @override
  Future<void> putMeta(String key, String value) async {
    if (key == currentUserKey) {
      userId = value.isEmpty ? null : value;
      return;
    }
    if (key == deviceLocaleKey) {
      locale = value.isEmpty ? null : value;
      return;
    }
    await _inner.putMeta(key, value);
  }

  @override
  Future<String?> getMeta(String key) async {
    if (key == currentUserKey) {
      final id = userId;
      if (id == null || id.isEmpty) return null;
      return id;
    }
    if (key == deviceLocaleKey) {
      final value = locale;
      if (value == null || value.isEmpty) return null;
      return value;
    }
    return _inner.getMeta(key);
  }
}
