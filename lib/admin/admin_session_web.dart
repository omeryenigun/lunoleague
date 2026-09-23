import 'package:web/web.dart';

const _key = 'lunoAdminToken';

String? readAdminToken() => window.sessionStorage.getItem(_key);

void writeAdminToken(String? token) {
  if (token == null || token.isEmpty) {
    window.sessionStorage.removeItem(_key);
  } else {
    window.sessionStorage.setItem(_key, token);
  }
}
