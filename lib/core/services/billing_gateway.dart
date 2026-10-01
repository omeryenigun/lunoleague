import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';

class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.purchaseToken,
    this.orderId,
    this.acknowledge,
  });

  final String productId;
  final String purchaseToken;

  /// Play order id. A subscription renewal uses a new order id and the same token.
  final String? orderId;

  /// Completes the Play purchase after the server has granted the item.
  final Future<void> Function()? acknowledge;
}

/// Index of the offer for [basePlanId]. Prefers the base plan over a promo offer.
int? playBasePlanOfferIndex(
  List<({String basePlanId, String? offerId})> offers,
  String basePlanId,
) {
  var promo = -1;
  for (var i = 0; i < offers.length; i++) {
    if (offers[i].basePlanId != basePlanId) continue;
    final offerId = offers[i].offerId;
    if (offerId == null || offerId.isEmpty) return i;
    if (promo < 0) promo = i;
  }
  return promo < 0 ? null : promo;
}

abstract class BillingGateway {
  Future<bool> isAvailable();
  Future<Map<String, String>> priceLabels();
  Future<StorePurchase> buy(String productId);

  /// Buys [productId]. [basePlanId] selects a subscription offer when the store lists several.
  /// The returned purchase is not completed until [StorePurchase.acknowledge] runs.
  Future<StorePurchase> buyOffer({
    required String productId,
    String? basePlanId,
    bool consumable = true,
  });
}

class UnavailableBillingGateway implements BillingGateway {
  const UnavailableBillingGateway();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<Map<String, String>> priceLabels() async => const {};

  @override
  Future<StorePurchase> buy(String productId) {
    throw AppFailure(UserMessages.billingUnavailable, code: 'NO_BILLING');
  }

  @override
  Future<StorePurchase> buyOffer({
    required String productId,
    String? basePlanId,
    bool consumable = true,
  }) =>
      buy(productId);
}

/// Confirms a Play consumable, then returns its purchase token. Does not grant coins.
class PlayBillingGateway implements BillingGateway {
  PlayBillingGateway({InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

  /// League consumables. Bilgi gold and Plus are bought with [buyOffer], not this set.
  static const productIds = {
    'coins_100',
    'coins_550',
    'coins_1400',
    'coins_4000',
    'streak_shield_1',
  };

  final InAppPurchase _store;

  @override
  Future<bool> isAvailable() => _store.isAvailable();

  @override
  Future<Map<String, String>> priceLabels() async {
    if (!await isAvailable()) return const {};
    final response = await _store.queryProductDetails(productIds);
    return {for (final product in response.productDetails) product.id: product.price};
  }

  @override
  Future<StorePurchase> buy(String productId) async {
    if (!await isAvailable()) {
      throw AppFailure(UserMessages.billingUnavailable, code: 'NO_BILLING');
    }
    final response = await _store.queryProductDetails({productId});
    if (response.productDetails.isEmpty) {
      throw AppFailure(UserMessages.billingUnavailable, code: 'NO_PRODUCT');
    }
    final details = response.productDetails.first;
    final completer = Completer<StorePurchase>();
    final sub = _store.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (purchase.productID != productId || completer.isCompleted) continue;
          switch (purchase.status) {
            case PurchaseStatus.pending:
              break;
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              final token =
                  purchase.verificationData.serverVerificationData.trim();
              if (token.isEmpty) {
                completer.completeError(
                  AppFailure(UserMessages.billingUnavailable, code: 'NO_PURCHASE'),
                );
              } else {
                completer.complete(
                  StorePurchase(
                    productId: productId,
                    purchaseToken: token,
                    acknowledge: () async {
                      if (purchase.pendingCompletePurchase) {
                        await _store.completePurchase(purchase);
                      }
                    },
                  ),
                );
              }
            case PurchaseStatus.error:
              completer.completeError(
                AppFailure(UserMessages.billingUnavailable, code: 'BILLING_ERROR'),
              );
              if (purchase.pendingCompletePurchase) {
                await _store.completePurchase(purchase);
              }
            case PurchaseStatus.canceled:
              completer.completeError(
                AppFailure(UserMessages.purchaseCanceled, code: 'CANCELED'),
              );
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) {
          completer.completeError(
            AppFailure(UserMessages.billingUnavailable, code: 'BILLING_ERROR'),
          );
        }
      },
    );
    final started = await _store.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!started) {
      await sub.cancel();
      throw AppFailure(UserMessages.billingUnavailable, code: 'NO_BILLING');
    }
    try {
      return await completer.future.timeout(const Duration(minutes: 5));
    } finally {
      await sub.cancel();
    }
  }

  @override
  Future<StorePurchase> buyOffer({
    required String productId,
    String? basePlanId,
    bool consumable = true,
  }) async {
    if (!await isAvailable()) {
      throw AppFailure(UserMessages.billingUnavailable, code: 'NO_BILLING');
    }
    final response = await _store.queryProductDetails({productId});
    final details = _detailsFor(response.productDetails, productId, basePlanId);
    if (details == null) {
      throw AppFailure(UserMessages.billingUnavailable, code: 'NO_PRODUCT');
    }
    final completer = Completer<StorePurchase>();
    final sub = _store.purchaseStream.listen(
      (purchases) async {
        for (final purchase in purchases) {
          if (completer.isCompleted) continue;
          final id = purchase.productID;
          if (id.isNotEmpty && id != productId) continue;
          switch (purchase.status) {
            case PurchaseStatus.pending:
              break;
            case PurchaseStatus.purchased:
            case PurchaseStatus.restored:
              if (id != productId) break;
              final token = purchase.verificationData.serverVerificationData.trim();
              if (token.isEmpty) {
                completer.completeError(
                  AppFailure(UserMessages.billingUnavailable, code: 'NO_PURCHASE'),
                );
              } else {
                completer.complete(
                  StorePurchase(
                    productId: productId,
                    purchaseToken: token,
                    orderId: purchase.purchaseID,
                    acknowledge: () => _finishPlayPurchase(purchase, consumable: consumable),
                  ),
                );
              }
            case PurchaseStatus.error:
              completer.completeError(
                AppFailure(UserMessages.billingUnavailable, code: 'BILLING_ERROR'),
              );
              if (purchase.pendingCompletePurchase) {
                await _store.completePurchase(purchase);
              }
            case PurchaseStatus.canceled:
              completer.completeError(
                AppFailure(UserMessages.purchaseCanceled, code: 'CANCELED'),
              );
          }
        }
      },
      onError: (_) {
        if (!completer.isCompleted) {
          completer.completeError(
            AppFailure(UserMessages.billingUnavailable, code: 'BILLING_ERROR'),
          );
        }
      },
    );
    final param = _purchaseParam(details);
    try {
      final started = consumable
          ? await _store.buyConsumable(purchaseParam: param, autoConsume: false)
          : await _store.buyNonConsumable(purchaseParam: param);
      if (!started) {
        throw AppFailure(UserMessages.billingUnavailable, code: 'NO_BILLING');
      }
      return await completer.future.timeout(const Duration(minutes: 5));
    } finally {
      await sub.cancel();
    }
  }

  ProductDetails? _detailsFor(List<ProductDetails> products, String productId, String? basePlanId) {
    final rows = [for (final product in products) if (product.id == productId) product];
    if (rows.isEmpty) return null;
    final plan = basePlanId?.trim() ?? '';
    if (plan.isEmpty) {
      for (final row in rows) {
        if (row is! GooglePlayProductDetails || row.subscriptionIndex == null) return row;
      }
      return null;
    }
    final offers = <({String basePlanId, String? offerId, ProductDetails details})>[];
    for (final row in rows) {
      if (row is! GooglePlayProductDetails) continue;
      final index = row.subscriptionIndex;
      final list = row.productDetails.subscriptionOfferDetails;
      if (index == null || list == null || index < 0 || index >= list.length) continue;
      final offer = list[index];
      offers.add((basePlanId: offer.basePlanId, offerId: offer.offerId, details: row));
    }
    final picked = playBasePlanOfferIndex(
      [for (final offer in offers) (basePlanId: offer.basePlanId, offerId: offer.offerId)],
      plan,
    );
    if (picked == null) return null;
    return offers[picked].details;
  }

  PurchaseParam _purchaseParam(ProductDetails details) {
    if (details is GooglePlayProductDetails) {
      final token = details.offerToken;
      if (token != null && token.isNotEmpty) {
        return GooglePlayPurchaseParam(productDetails: details, offerToken: token);
      }
    }
    return PurchaseParam(productDetails: details);
  }

  /// Consumes a gold pack, or acknowledges Plus, only after the grant has succeeded.
  Future<void> _finishPlayPurchase(PurchaseDetails purchase, {required bool consumable}) async {
    if (consumable) {
      final addition = _store.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final result = await addition.consumePurchase(purchase);
      if (result.responseCode != BillingResponse.ok) {
        throw AppFailure(UserMessages.billingUnavailable, code: 'BILLING_ERROR');
      }
      return;
    }
    if (purchase.pendingCompletePurchase) {
      await _store.completePurchase(purchase);
    }
  }
}

/// Test double. [tokenPrefix] is appended with the product id so each buy is unique
/// unless [fixedToken] is set.
class ScriptedBillingGateway implements BillingGateway {
  ScriptedBillingGateway({
    this.available = true,
    this.fixedToken,
    Map<String, String>? prices,
  }) : prices = prices ?? const {};

  bool available;
  String? fixedToken;
  final Map<String, String> prices;
  var _n = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Map<String, String>> priceLabels() async => prices;

  @override
  Future<StorePurchase> buy(String productId) async {
    if (!available) {
      throw AppFailure(UserMessages.billingUnavailable, code: 'NO_BILLING');
    }
    final token = fixedToken ?? 'scripted-$productId-${_n++}';
    return StorePurchase(productId: productId, purchaseToken: token);
  }

  @override
  Future<StorePurchase> buyOffer({
    required String productId,
    String? basePlanId,
    bool consumable = true,
  }) =>
      buy(productId);
}
