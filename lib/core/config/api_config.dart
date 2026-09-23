/// Public Luno League content API. Luno Fall does not use this host.
class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-production-bf3c9.up.railway.app',
  );
}
