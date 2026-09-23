import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

const _publisherScope = 'https://www.googleapis.com/auth/androidpublisher';

/// Confirms a consumable with the Play Developer API.
/// Missing credentials or any failed check grants nothing.
Future<bool> confirmPlayPurchase(String productId, String purchaseToken) async {
  final raw = Platform.environment['GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'];
  final token = purchaseToken.trim();
  if (raw == null || raw.trim().isEmpty || token.isEmpty) return false;
  final package = Platform.environment['GOOGLE_PLAY_PACKAGE_NAME'];
  final packageName = (package == null || package.trim().isEmpty)
      ? 'com.kelimelig.kelimelig'
      : package.trim();
  try {
    final credentials = ServiceAccountCredentials.fromJson(jsonDecode(raw));
    final client = await clientViaServiceAccount(
      credentials,
      const [_publisherScope],
    );
    try {
      final uri = Uri.parse(
        'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'
        '${Uri.encodeComponent(packageName)}/purchases/products/'
      '${Uri.encodeComponent(productId)}/tokens/${Uri.encodeComponent(token)}',
      );
      final response = await client.get(uri);
      if (response.statusCode != 200) return false;
      final body = jsonDecode(response.body);
      if (body is! Map) return false;
      return body['purchaseState'] == 0;
    } finally {
      client.close();
    }
  } catch (_) {
    return false;
  }
}
