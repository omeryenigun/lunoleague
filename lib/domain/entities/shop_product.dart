class ShopProduct {
  const ShopProduct({
    required this.id,
    this.coins = 0,
    this.shields = 0,
    required this.priceTry,
    required this.priceUsd,
    this.badge,
    this.popular = false,
    this.sortOrder = 0,
    this.active = true,
  });

  final String id;
  final int coins;
  /// Streak shields granted on purchase (capped by [AppConstants.maxStreakShields] at grant time).
  final int shields;
  /// Display price in Turkish Lira (Play style).
  final String priceTry;
  /// Display price in USD.
  final String priceUsd;
  final String? badge;
  final bool popular;
  final int sortOrder;
  final bool active;

  bool get grantsCoins => coins > 0;
  bool get grantsShields => shields > 0;

  String priceLabel(String locale) =>
      locale == 'en' ? priceUsd : priceTry;

  ShopProduct copyWith({
    String? id,
    int? coins,
    int? shields,
    String? priceTry,
    String? priceUsd,
    String? badge,
    bool clearBadge = false,
    bool? popular,
    int? sortOrder,
    bool? active,
  }) {
    return ShopProduct(
      id: id ?? this.id,
      coins: coins ?? this.coins,
      shields: shields ?? this.shields,
      priceTry: priceTry ?? this.priceTry,
      priceUsd: priceUsd ?? this.priceUsd,
      badge: clearBadge ? null : (badge ?? this.badge),
      popular: popular ?? this.popular,
      sortOrder: sortOrder ?? this.sortOrder,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'coins': coins,
        'shields': shields,
        'priceTry': priceTry,
        'priceUsd': priceUsd,
        'badge': badge,
        'popular': popular,
        'sortOrder': sortOrder,
        'active': active,
      };

  factory ShopProduct.fromMap(Map<dynamic, dynamic> map) => ShopProduct(
        id: map['id'] as String,
        coins: map['coins'] as int? ?? 0,
        shields: map['shields'] as int? ?? 0,
        priceTry: map['priceTry'] as String? ?? '',
        priceUsd: map['priceUsd'] as String? ?? '',
        badge: map['badge'] as String?,
        popular: map['popular'] as bool? ?? false,
        sortOrder: map['sortOrder'] as int? ?? 0,
        active: map['active'] as bool? ?? true,
      );
}

/// Default mock IAP catalog. Real Play Billing SKUs will map to these ids later.
class ShopCatalog {
  static const products = <ShopProduct>[
    ShopProduct(
      id: 'coins_100',
      coins: 100,
      priceTry: '₺19,99',
      priceUsd: '\$0.99',
      sortOrder: 10,
    ),
    ShopProduct(
      id: 'coins_550',
      coins: 550,
      priceTry: '₺69,99',
      priceUsd: '\$2.99',
      badge: 'populer',
      popular: true,
      sortOrder: 20,
    ),
    ShopProduct(
      id: 'coins_1400',
      coins: 1400,
      priceTry: '₺149,99',
      priceUsd: '\$5.99',
      badge: 'avantaj',
      sortOrder: 30,
    ),
    ShopProduct(
      id: 'coins_4000',
      coins: 4000,
      priceTry: '₺349,99',
      priceUsd: '\$14.99',
      badge: 'en_iyi',
      sortOrder: 40,
    ),
    ShopProduct(
      id: 'streak_shield_1',
      shields: 1,
      priceTry: '₺29,99',
      priceUsd: '\$1.49',
      badge: 'kalkan',
      sortOrder: 50,
    ),
  ];

  static ShopProduct? byId(String id) {
    for (final p in products) {
      if (p.id == id) return p;
    }
    return null;
  }
}
