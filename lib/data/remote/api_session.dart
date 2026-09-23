/// Tokens for the live API. The player app fills [playerToken].
/// The admin web app fills [adminToken] after login.
class ApiSession {
  String? playerToken;
  String? adminToken;
}
