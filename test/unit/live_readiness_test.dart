import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/api/game_http.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';

void main() {
  test('public bootstrap does not include the word list', () async {
    final store = MemoryKeyValueStore();
    final game = LocalGameServer(store);
    await game.initialize();
    final body = await liveBootstrap(store);
    expect(body.containsKey('words'), isFalse);
    expect(body['shop'], isA<List>());
    expect((body['shop'] as List).isNotEmpty, isTrue);
    expect(await store.values('words'), isNotEmpty);
  });

  test('unverified purchase and ad request grant nothing', () async {
    final server = LocalGameServer(
      MemoryKeyValueStore(),
      confirmPurchase: (_, _) async => false,
      grantUnverifiedAds: false,
    );
    await server.initialize();
    await server.signInWithGoogle(googleId: 'buyer', displayName: 'Buyer');
    final before = (await server.currentUser())!.coin;
    expect(
      () => server.purchaseShopProduct('coins_100', purchaseToken: 'not-play'),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', 'UNVERIFIED_PURCHASE'),
      ),
    );
    expect(
      () => server.watchRewardedAd(),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'NO_AD_PROOF')),
    );
    expect((await server.currentUser())!.coin, before);
  });
}
