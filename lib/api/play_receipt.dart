import 'dart:convert';
import 'dart:io';

import 'package:googleapis_auth/auth_io.dart';

const _publisherScope = 'https://www.googleapis.com/auth/androidpublisher';

/// True when a Play Developer API body is a paid purchase of [productId].
/// Accepts the legacy product resource and the one-time product v2 resource.
bool playPurchaseGranted(String productId, int statusCode, Object? body) {
  if (statusCode != 200 || body is! Map) return false;
  final legacyState = body['purchaseState'];
  if (legacyState is int) {
    final reported = body['productId'];
    if (reported is String && reported.isNotEmpty && reported != productId) {
      return false;
    }
    return legacyState == 0;
  }
  final context = body['purchaseStateContext'];
  if (context is! Map || context['purchaseState'] != 'PURCHASED') return false;
  final items = body['productLineItem'];
  if (items is! List) return false;
  for (final item in items) {
    if (item is Map && item['productId'] == productId) return true;
  }
  return false;
}

/// Confirms a consumable with the Play Developer API.
/// Missing credentials or any failed check grants nothing.
Future<bool> confirmPlayPurchase(String productId, String purchaseToken) async {
  final raw = Platform.environment['GOOGLE_PLAY_SERVICE_ACCOUNT_JSON'];
  final token = purchaseToken.trim();
  if (raw == null || raw.trim().isEmpty || token.isEmpty) return false;
  final package = Platform.environment['GOOGLE_PLAY_PACKAGE_NAME'];
  final packageName = (package == null || package.trim().isEmpty)
      ? 'com.lunoleague.game'
      : package.trim();
  try {
    final credentials = ServiceAccountCredentials.fromJson(jsonDecode(raw));
    final client = await clientViaServiceAccount(
      credentials,
      const [_publisherScope],
    );
    try {
      final root =
          'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/'
          '${Uri.encodeComponent(packageName)}';
      final encodedToken = Uri.encodeComponent(token);
      final current = await client.get(
        Uri.parse('$root/purchases/productsv2/tokens/$encodedToken'),
      );
      final currentBody = _decodeBody(current.body);
      if (playPurchaseGranted(productId, current.statusCode, currentBody)) {
        return true;
      }
      final legacy = await client.get(
        Uri.parse(
          '$root/purchases/products/${Uri.encodeComponent(productId)}/tokens/$encodedToken',
        ),
      );
      final legacyBody = _decodeBody(legacy.body);
      final granted = playPurchaseGranted(productId, legacy.statusCode, legacyBody);
      if (!granted) {
        stdout.writeln(
          'play purchase rejected v2=${current.statusCode} v1=${legacy.statusCode}',
        );
      }
      return granted;
    } finally {
      client.close();
    }
  } catch (_) {
    stdout.writeln('play purchase rejected error');
    return false;
  }
}

Object? _decodeBody(String raw) {
  try {
    return jsonDecode(raw);
  } catch (_) {
    return null;
  }
}
