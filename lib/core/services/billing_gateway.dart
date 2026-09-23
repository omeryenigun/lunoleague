import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';

class StorePurchase {
  const StorePurchase({
    required this.productId,
    required this.purchaseToken,
    this.acknowledge,
  });

  final String productId;
  final String purchaseToken;

  /// Completes the Play purchase after the server has granted the item.
  final Future<void> Function()? acknowledge;
}

abstract class BillingGateway {
  Future<bool> isAvailable();
  Future<Map<String, String>> priceLabels();
  Future<StorePurchase> buy(String productId);
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
}

/// Confirms a Play consumable, then returns its purchase token. Does not grant coins.
class PlayBillingGateway implements BillingGateway {
  PlayBillingGateway({InAppPurchase? store}) : _store = store ?? InAppPurchase.instance;

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
}
