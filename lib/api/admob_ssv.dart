import 'dart:convert';
import 'dart:typed_data';

import 'package:asn1lib/asn1lib.dart';
import 'package:http/http.dart' as http;
import 'package:kelimelig/core/constants/admob.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:pointycastle/export.dart';
import 'package:shelf/shelf.dart';

const _keysUrl = 'https://www.gstatic.com/admob/reward/verifier-keys.json';

Map<String, ECPublicKey>? _keys;

/// AdMob calls this after a rewarded video. Coins are granted only when the
/// signature matches Google's key and the ad unit is ours.
Future<Response> handleAdmobReward(Request request, LocalGameServer game) async {
  final uri = request.requestedUri;
  final params = uri.queryParameters;
  if (!params.containsKey('signature')) {
    return Response.ok('Luno League ad reward');
  }
  if (!await verifyAdmobQuery(uri.query)) return Response(400);
  final unit = params['ad_unit'] ?? '';
  if (_isOurRewardedUnit(unit)) {
    final userId = params['user_id'] ?? '';
    final transactionId = params['transaction_id'] ?? '';
    if (params['custom_data'] == 'daily_next') {
      await game.grantDailyNextProof(
        userId: userId,
        transactionId: transactionId,
      );
    } else {
      await game.grantRewardedAdProof(
        userId: userId,
        transactionId: transactionId,
      );
    }
  }
  return Response.ok('ok');
}

bool _isOurRewardedUnit(String unit) {
  const numeric = '5748202969';
  return unit == admobRewardedUnitId || unit == numeric || unit.endsWith('/$numeric');
}

Future<bool> verifyAdmobQuery(String query) async {
  final signatureIndex = query.indexOf('&signature=');
  if (signatureIndex <= 0) return false;
  final message = query.substring(0, signatureIndex);
  final params = Uri.splitQueryString(query);
  final signature = params['signature'];
  final keyId = params['key_id'];
  if (signature == null || keyId == null) return false;
  final key = (await _publicKeys())[keyId];
  if (key == null) return false;
  final sigBytes = _decode(signature);
  if (sigBytes == null) return false;
  final ecSignature = _derSignature(sigBytes);
  if (ecSignature == null) return false;
  final verifier = Signer('SHA-256/ECDSA')
    ..init(false, PublicKeyParameter<ECPublicKey>(key));
  return verifier.verifySignature(utf8.encode(message), ecSignature);
}

Future<Map<String, ECPublicKey>> _publicKeys() async {
  final cached = _keys;
  if (cached != null) return cached;
  final response = await http.get(Uri.parse(_keysUrl)).timeout(const Duration(seconds: 8));
  if (response.statusCode != 200) return {};
  final body = jsonDecode(response.body);
  final next = <String, ECPublicKey>{};
  if (body is Map && body['keys'] is List) {
    for (final item in body['keys'] as List) {
      if (item is! Map) continue;
      final id = '${item['keyId']}';
      final pem = item['pem'];
      if (pem is! String) continue;
      final key = _pemPublicKey(pem);
      if (key != null) next[id] = key;
    }
  }
  if (next.isNotEmpty) _keys = next;
  return next;
}

ECPublicKey? _pemPublicKey(String pem) {
  final lines = pem
      .replaceAll('-----BEGIN PUBLIC KEY-----', '')
      .replaceAll('-----END PUBLIC KEY-----', '')
      .replaceAll('\n', '')
      .trim();
  final der = base64.decode(lines);
  final parser = ASN1Parser(der);
  final seq = parser.nextObject() as ASN1Sequence;
  final bit = seq.elements[1] as ASN1BitString;
  final point = bit.contentBytes();
  if (point.isEmpty || point[0] != 0x04) return null;
  final raw = point.sublist(1);
  final half = raw.length ~/ 2;
  final x = _positive(raw.sublist(0, half));
  final y = _positive(raw.sublist(half));
  final domain = ECCurve_secp256r1();
  return ECPublicKey(domain.curve.createPoint(x, y), domain);
}

ECSignature? _derSignature(Uint8List der) {
  final parser = ASN1Parser(der);
  final seq = parser.nextObject() as ASN1Sequence;
  final r = (seq.elements[0] as ASN1Integer).valueAsBigInteger;
  final s = (seq.elements[1] as ASN1Integer).valueAsBigInteger;
  return ECSignature(r, s);
}

BigInt _positive(List<int> bytes) {
  var value = BigInt.zero;
  for (final byte in bytes) {
    value = (value << 8) | BigInt.from(byte);
  }
  return value;
}

Uint8List? _decode(String value) {
  try {
    return base64Url.decode(base64Url.normalize(value));
  } catch (_) {
    try {
      return base64.decode(base64.normalize(value));
    } catch (_) {
      return null;
    }
  }
}
