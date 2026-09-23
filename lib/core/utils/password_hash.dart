import 'dart:convert';

/// Local mock password hashing. Replace with backend Auth (Firebase etc.) later.
/// Uses 32-bit arithmetic so it runs on Dart web (JS integers).
class PasswordHash {
  static String hash(String password, String salt) {
    final bytes = utf8.encode('$salt::$password::luno-league');
    var h = 2166136261;
    for (final b in bytes) {
      h ^= b;
      h = (h * 16777619) & 0xFFFFFFFF;
    }
    // Second pass mixes length so short passwords don't collide trivially.
    var h2 = 0x811C9DC5;
    for (var i = bytes.length - 1; i >= 0; i--) {
      h2 ^= bytes[i];
      h2 = (h2 * 16777619) & 0xFFFFFFFF;
    }
    return '${h.toRadixString(16).padLeft(8, '0')}'
        '${h2.toRadixString(16).padLeft(8, '0')}';
  }

  static bool verify(String password, String salt, String expectedHash) =>
      hash(password, salt) == expectedHash;

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static bool isValidEmail(String email) =>
      _emailRe.hasMatch(email.trim().toLowerCase());

  static String normalizeEmail(String email) => email.trim().toLowerCase();
}
