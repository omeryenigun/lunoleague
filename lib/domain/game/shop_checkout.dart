import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/services/billing_gateway.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/game_server.dart';

/// Buys through Play, then grants the catalog item. Unavailable billing leaves the wallet alone.
Future<UserEntity> checkoutShopProduct({
  required BillingGateway billing,
  required GameServer server,
  required String productId,
}) async {
  if (!await billing.isAvailable()) {
    throw AppFailure(UserMessages.billingUnavailable, code: 'NO_BILLING');
  }
  final purchase = await billing.buy(productId);
  if (purchase.productId != productId || purchase.purchaseToken.trim().isEmpty) {
    throw AppFailure(UserMessages.billingUnavailable, code: 'NO_PURCHASE');
  }
  return server.purchaseShopProduct(
    productId,
    purchaseToken: purchase.purchaseToken,
  ).then((user) async {
    final acknowledge = purchase.acknowledge;
    if (acknowledge != null) await acknowledge();
    return user;
  });
}
