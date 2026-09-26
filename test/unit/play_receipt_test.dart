import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/api/play_receipt.dart';

void main() {
  test('legacy purchased state grants the same product', () {
    expect(
      playPurchaseGranted( 'coins_100', 200, {
        'purchaseState': 0,
        'productId': 'coins_100',
      }),
      isTrue,
    );
  });

  test('legacy response for another product grants nothing', () {
    expect(
      playPurchaseGranted('coins_4000', 200, {
        'purchaseState': 0,
        'productId': 'coins_100',
      }),
      isFalse,
    );
  });

  test('one-time product v2 purchased state grants the matching line', () {
    expect(
      playPurchaseGranted('coins_100', 200, {
        'purchaseStateContext': {'purchaseState': 'PURCHASED'},
        'productLineItem': [
          {'productId': 'coins_100'},
        ],
      }),
      isTrue,
    );
  });

  test('pending, canceled, and failed responses grant nothing', () {
    expect(
      playPurchaseGranted('coins_100', 200, {
        'purchaseStateContext': {'purchaseState': 'PENDING'},
        'productLineItem': [
          {'productId': 'coins_100'},
        ],
      }),
      isFalse,
    );
    expect(
      playPurchaseGranted('coins_100', 200, {'purchaseState': 1}),
      isFalse,
    );
    expect(playPurchaseGranted('coins_100', 403, {'error': {}}), isFalse);
  });
}
