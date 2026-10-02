import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/services/billing_gateway.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_controller.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_shop.dart';
import 'package:kelimelig/injection.dart';

void main() {
  test('Play catalog ids match the Bilgi products', () {
    expect(bilgiGold1000.productId, 'bilgi_gold_1000');
    expect(bilgiGold1000.purchaseOptionId, 'bilgi-gold-1000-buy');
    expect(bilgiGold1000.gold, 1000);
    expect(bilgiGold5000.productId, 'bilgi_gold_5000');
    expect(bilgiGold5000.purchaseOptionId, 'bilgi-gold-5000-buy');
    expect(bilgiGold5000.gold, 5000);
    expect(bilgiPlusAylik.productId, 'luno_plus');
    expect(bilgiPlusAylik.basePlanId, 'luno-plus-aylik');
    expect(bilgiPlus6Ay.basePlanId, 'luno-plus-6ay');
    expect(bilgiPlusYillik.basePlanId, 'luno-plus-yillik');
    expect(bilgiPlaySku('luno_plus', 'luno-plus-6ay')?.months, 6);
    expect(bilgiPlaySku('luno_plus'), isNull);
    expect(PlayBillingGateway.productIds, {
      'coins_100',
      'coins_550',
      'coins_1400',
      'coins_4000',
      'streak_shield_1',
    });
  });

  test('base plan selection prefers the plan over a promo offer', () {
    final offers = [
      (basePlanId: 'luno-plus-aylik', offerId: 'intro'),
      (basePlanId: 'luno-plus-aylik', offerId: null),
      (basePlanId: 'luno-plus-yillik', offerId: ''),
    ];
    expect(playBasePlanOfferIndex(offers, 'luno-plus-aylik'), 1);
    expect(playBasePlanOfferIndex(offers, 'luno-plus-yillik'), 2);
    expect(playBasePlanOfferIndex(offers, 'luno-plus-6ay'), isNull);
    expect(
      playBasePlanOfferIndex([(basePlanId: 'luno-plus-6ay', offerId: 'sale')], 'luno-plus-6ay'),
      0,
    );
  });

  test('month math clamps the day and stacks from the later end', () {
    expect(bilgiAddMonths(DateTime.utc(2026, 1, 31), 1), DateTime.utc(2026, 2, 28));
    expect(bilgiAddMonths(DateTime.utc(2026, 10, 1), 6), DateTime.utc(2027, 4, 1));
    final now = DateTime.utc(2026, 10, 1);
    final existing = DateTime.utc(2026, 12, 1);
    expect(bilgiPlusUntil(now, existing, 12), DateTime.utc(2027, 12, 1));
    expect(bilgiPlusUntil(now, DateTime.utc(2026, 9, 1), 1), DateTime.utc(2026, 11, 1));
  });

  test('gold is granted once per receipt and can be bought again', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime.utc(2026, 10, 1));
    final pushed = <String>[];
    server.remoteUpsert = (user) async {
      pushed.add(user.id);
      return null;
    };
    final before = (await server.profile()).gold;
    final first = await server.grantPlayPurchase(
      productId: bilgiGold1000.productId,
      purchaseToken: 'gold-a',
    );
    expect(first.ok, isTrue);
    expect(first.profile!.gold, before + 1000);
    expect(first.profile!.premium, isFalse);
    final again = await server.grantPlayPurchase(
      productId: bilgiGold1000.productId,
      purchaseToken: 'gold-a',
    );
    expect(again.profile!.gold, before + 1000);
    final second = await server.grantPlayPurchase(
      productId: bilgiGold5000.productId,
      purchaseToken: 'gold-b',
      orderId: 'order-b',
    );
    expect(second.profile!.gold, before + 6000);
    expect(pushed, [first.profile!.id, first.profile!.id]);

    final empty = await server.grantPlayPurchase(productId: bilgiGold1000.productId, purchaseToken: '  ');
    expect(empty.ok, isFalse);
    expect((await server.profile()).gold, before + 6000);
    final unknown = await server.grantPlayPurchase(productId: 'coins_100', purchaseToken: 'nope');
    expect(unknown.ok, isFalse);
    expect((await server.profile()).gold, before + 6000);
  });

  test('Plus stacks forward and a repeat order does not extend it', () async {
    var now = DateTime.utc(2026, 10, 1);
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => now);
    final pushed = <bool>[];
    server.remoteUpsert = (user) async {
      pushed.add(user.premium);
      return null;
    };
    final registered = await server.register(
      username: 'Ada',
      email: 'ada@example.com',
      password: 'secret1',
    );
    expect(registered.ok, isTrue);
    pushed.clear();

    final month = await server.grantPlayPurchase(
      productId: 'luno_plus',
      basePlanId: 'luno-plus-aylik',
      purchaseToken: 'plus-token',
      orderId: 'order-month',
    );
    expect(month.profile!.premium, isTrue);
    expect(month.profile!.premiumUntil, DateTime.utc(2026, 11, 1));
    expect(month.profile!.gold, 2500);
    expect(pushed, [true]);

    final today = DateKeys.dayKey(now);
    final active = month.profile!.copyWith(adFreeLeft: 0, freePlaysUsed: 1, lastPlayDay: today);
    expect(server.needsAd(active, await server.config()), isFalse);
    final lapsed = active.copyWith(premiumUntil: now.subtract(const Duration(days: 1)));
    expect(server.needsAd(lapsed, await server.config()), isTrue);
    expect(bilgiPlusActive(active.copyWith(clearPremiumUntil: true), now), isTrue);

    final replay = await server.grantPlayPurchase(
      productId: 'luno_plus',
      basePlanId: 'luno-plus-yillik',
      purchaseToken: 'plus-token',
      orderId: 'order-month',
    );
    expect(replay.profile!.premiumUntil, DateTime.utc(2026, 11, 1));
    expect(replay.profile!.gold, 2500);

    final year = await server.grantPlayPurchase(
      productId: 'luno_plus',
      basePlanId: 'luno-plus-yillik',
      purchaseToken: 'plus-token',
      orderId: 'order-year',
    );
    expect(year.profile!.premiumUntil, DateTime.utc(2027, 11, 1));

    final half = await server.grantPlayPurchase(
      productId: 'luno_plus',
      basePlanId: 'luno-plus-6ay',
      purchaseToken: 'plus-token',
      orderId: 'order-half',
    );
    expect(half.profile!.premiumUntil, DateTime.utc(2028, 5, 1));

    now = DateTime.utc(2029, 1, 15);
    final restarted = await server.grantPlayPurchase(
      productId: 'luno_plus',
      basePlanId: 'luno-plus-aylik',
      purchaseToken: 'plus-token',
      orderId: 'order-restart',
    );
    expect(restarted.profile!.premiumUntil, DateTime.utc(2029, 2, 15));
  });

  test('desktop shop purchase does not grant gold or Plus', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime.utc(2026, 10, 1));
    final game = BilgiController(server);
    final before = await server.profile();
    await game.buyPlay(bilgiGold1000);
    expect(game.notice, bilgiPlayAndroidNotice);
    final after = await server.profile();
    expect(after.gold, before.gold);
    expect(after.premium, isFalse);
    await game.buyPlay(bilgiPlusYillik);
    expect((await server.profile()).premium, isFalse);
    game.dispose();
  });

  test('a canceled Play purchase does not grant gold or Plus', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await resetDependencies();
    });
    sl.registerSingleton<BillingGateway>(const _CancelBilling());
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime.utc(2026, 10, 1));
    final game = BilgiController(server);
    final before = await server.profile();
    await game.buyPlay(bilgiGold1000);
    expect(game.notice, UserMessages.purchaseCanceled);
    var after = await server.profile();
    expect(after.gold, before.gold);
    await game.buyPlay(bilgiPlusAylik);
    after = await server.profile();
    expect(after.gold, before.gold);
    expect(after.premium, isFalse);
    game.dispose();
  });
}

class _CancelBilling implements BillingGateway {
  const _CancelBilling();

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<Map<String, String>> priceLabels() async => const {};

  @override
  Future<StorePurchase> buy(String productId) async {
    throw AppFailure(UserMessages.purchaseCanceled, code: 'CANCELED');
  }

  @override
  Future<StorePurchase> buyOffer({
    required String productId,
    String? basePlanId,
    bool consumable = true,
  }) =>
      buy(productId);
}
