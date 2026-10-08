import 'package:kelimelig/games/luno_bilgi/bilgi_l10n.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

/// Shown on web and desktop. Play billing runs in the Android app.
const bilgiPlayAndroidNotice = 'Satın alma Android uygulamasında açılır.';

/// One Play product the Bilgi shop can buy.
class BilgiPlaySku {
  const BilgiPlaySku({
    required this.productId,
    required this.gold,
    required this.months,
    this.basePlanId,
    this.purchaseOptionId,
    this.includedGold = 0,
  });

  /// Play product id. Gold packs and Plus are queried with this id.
  final String productId;

  /// Subscription base plan id. Gold packs have none.
  final String? basePlanId;

  /// Play Console purchase-option id for a gold pack.
  /// The billing plugin buys the consumable by [productId]; it does not accept this id as an offer token.
  final String? purchaseOptionId;

  final int gold;
  final int months;

  /// Gold granted with a Plus period. Gold packs leave this at zero.
  final int includedGold;

  bool get consumable => gold > 0;
  bool get plus => months > 0;
}

const bilgiGold1000 = BilgiPlaySku(
  productId: 'bilgi_gold_1000',
  purchaseOptionId: 'bilgi-gold-1000-buy',
  gold: 1000,
  months: 0,
);

const bilgiGold5000 = BilgiPlaySku(
  productId: 'bilgi_gold_5000',
  purchaseOptionId: 'bilgi-gold-5000-buy',
  gold: 5000,
  months: 0,
);

const bilgiPlusAylik = BilgiPlaySku(
  productId: 'luno_plus',
  basePlanId: 'luno-plus-aylik',
  gold: 0,
  months: 1,
  includedGold: 2000,
);

const bilgiPlus6Ay = BilgiPlaySku(
  productId: 'luno_plus',
  basePlanId: 'luno-plus-6ay',
  gold: 0,
  months: 6,
  includedGold: 14000,
);

const bilgiPlusYillik = BilgiPlaySku(
  productId: 'luno_plus',
  basePlanId: 'luno-plus-yillik',
  gold: 0,
  months: 12,
  includedGold: 30000,
);

const bilgiPlaySkus = <BilgiPlaySku>[
  bilgiGold1000,
  bilgiGold5000,
  bilgiPlusAylik,
  bilgiPlus6Ay,
  bilgiPlusYillik,
];

/// Question before a Luno-gold shop spend, and the reward-load line after it.
class BilgiShopExchangeCopy {
  const BilgiShopExchangeCopy({
    required this.confirm,
    required this.icon,
    required this.amount,
    required this.caption,
  });

  final String confirm;
  final String icon;
  final String amount;
  final String caption;
}

String _shopFill(String locale, String key, Map<String, String> values) {
  var text = bilgiT(locale, key);
  for (final entry in values.entries) {
    text = text.replaceAll('{${entry.key}}', entry.value);
  }
  return text;
}

BilgiShopExchangeCopy bilgiShopJokerExchange({
  required String name,
  required int price,
  required int stockAfter,
  required String icon,
  String locale = 'tr',
}) {
  final values = {'price': '$price', 'name': name, 'stock': '$stockAfter'};
  return BilgiShopExchangeCopy(
    confirm: _shopFill(locale, 'shop_joker_confirm', values),
    icon: icon,
    amount: '$price',
    caption: _shopFill(locale, 'shop_joker_caption', values),
  );
}

BilgiShopExchangeCopy bilgiShopLifeExchange({
  required int price,
  required int livesAfter,
  String locale = 'tr',
}) {
  final values = {'price': '$price', 'lives': '$livesAfter'};
  return BilgiShopExchangeCopy(
    confirm: _shopFill(locale, 'shop_life_confirm', values),
    icon: '❤️',
    amount: '$price',
    caption: _shopFill(locale, 'shop_life_caption', values),
  );
}

/// The catalog row for this Play product, or null when the ids are not sold here.
BilgiPlaySku? bilgiPlaySku(String productId, [String? basePlanId]) {
  final plan = basePlanId?.trim() ?? '';
  for (final sku in bilgiPlaySkus) {
    if (sku.productId != productId) continue;
    final skuPlan = sku.basePlanId ?? '';
    if (skuPlan != plan) continue;
    return sku;
  }
  return null;
}

/// Adds calendar months, clamping the day to the last day of the target month.
DateTime bilgiAddMonths(DateTime from, int months) {
  final index = from.month - 1 + months;
  final year = from.year + index ~/ 12;
  final month = index % 12 + 1;
  final last = DateTime(year, month + 1, 0).day;
  final day = from.day > last ? last : from.day;
  if (from.isUtc) {
    return DateTime.utc(
      year,
      month,
      day,
      from.hour,
      from.minute,
      from.second,
      from.millisecond,
      from.microsecond,
    );
  }
  return DateTime(
    year,
    month,
    day,
    from.hour,
    from.minute,
    from.second,
    from.millisecond,
    from.microsecond,
  );
}

/// Plus runs until [months] after the later of [now] and an existing [currentUntil].
DateTime bilgiPlusUntil(DateTime now, DateTime? currentUntil, int months) {
  final start = currentUntil != null && currentUntil.isAfter(now) ? currentUntil : now;
  return bilgiAddMonths(start, months);
}

/// Premium with no end date stays active. A set [BilgiProfile.premiumUntil] ends the pass.
bool bilgiPlusActive(BilgiProfile user, DateTime now) {
  if (!user.premium) return false;
  final until = user.premiumUntil;
  if (until == null) return true;
  return !until.isBefore(now);
}

BilgiProfile applyBilgiPlayReward(BilgiProfile user, BilgiPlaySku sku, DateTime now) {
  if (sku.gold > 0) return user.copyWith(gold: user.gold + sku.gold);
  return user.copyWith(
    gold: user.gold + sku.includedGold,
    premium: true,
    premiumUntil: bilgiPlusUntil(now, user.premiumUntil, sku.months),
  );
}
