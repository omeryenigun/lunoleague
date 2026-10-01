import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/services/billing_gateway.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/domain/game/shop_checkout.dart';

void main() {
  late LocalGameServer server;

  setUp(() async {
    server = LocalGameServer(MemoryKeyValueStore());
    await server.initialize();
    await server.signInWithGoogle(googleId: 'buyer', displayName: 'Buyer');
  });

  test('checkout without Play billing does not grant coins', () async {
    final before = (await server.currentUser())!.coin;
    expect(
      () => checkoutShopProduct(
        billing: const UnavailableBillingGateway(),
        server: server,
        productId: 'coins_100',
      ),
      throwsA(isA<AppFailure>()),
    );
    expect((await server.currentUser())!.coin, before);
  });

  test('a confirmed purchase grants the catalog once', () async {
    const billing = _FixedBilling();
    final before = (await server.currentUser())!.coin;
    final bought = await checkoutShopProduct(
      billing: billing,
      server: server,
      productId: 'coins_100',
    );
    expect(bought.coin, before + 100);
    final again = await checkoutShopProduct(
      billing: billing,
      server: server,
      productId: 'coins_100',
    );
    expect(again.coin, before + 100);
  });
}

class _FixedBilling implements BillingGateway {
  const _FixedBilling();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, String>> priceLabels() async =>
      const {'coins_100': '₺19,99'};

  @override
  Future<StorePurchase> buy(String productId) async {
    return StorePurchase(productId: productId, purchaseToken: 'tok-$productId');
  }

  @override
  Future<StorePurchase> buyOffer({
    required String productId,
    String? basePlanId,
    bool consumable = true,
  }) =>
      buy(productId);
}
