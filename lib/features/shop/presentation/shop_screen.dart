import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/core/theme/cosmic_backdrop.dart';
import 'package:kelimelig/core/theme/cosmic_glass.dart';
import 'package:kelimelig/core/theme/shimmer_title.dart';
import 'package:kelimelig/core/services/billing_gateway.dart';
import 'package:kelimelig/domain/entities/shop_product.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/domain/game/shop_checkout.dart';
import 'package:kelimelig/features/auth/cubit/auth_cubit.dart';
import 'package:kelimelig/injection.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopShelf {
  const _ShopShelf({
    required this.products,
    required this.available,
    required this.prices,
  });

  final List<ShopProduct> products;
  final bool available;
  final Map<String, String> prices;
}

class _ShopScreenState extends State<ShopScreen> {
  String? _buyingId;
  late final Future<_ShopShelf> _shelf = _loadShelf();

  Future<_ShopShelf> _loadShelf() async {
    final products = await sl<GameServer>().listShopProducts();
    final billing = sl<BillingGateway>();
    final available = await billing.isAvailable();
    final prices = available ? await billing.priceLabels() : const <String, String>{};
    return _ShopShelf(products: products, available: available, prices: prices);
  }

  String _badgeLabel(L10n l10n, String? badge) => switch (badge) {
        'populer' => l10n.t('shop_badge_popular'),
        'avantaj' => l10n.t('shop_badge_value'),
        'en_iyi' => l10n.t('shop_badge_best'),
        'kalkan' => l10n.t('shop_badge_shield'),
        _ => '',
      };

  String _title(L10n l10n, ShopProduct p) {
    if (p.grantsShields && !p.grantsCoins) {
      return '${p.shields} ${l10n.t('shop_shield')}';
    }
    if (p.grantsCoins && p.grantsShields) {
      return '${p.coins} ${l10n.t('shop_coins')} + ${p.shields} ${l10n.t('shop_shield')}';
    }
    return '${p.coins} ${l10n.t('shop_coins')}';
  }

  String _boughtMessage(L10n l10n, ShopProduct p, int coin, int shields) {
    if (p.grantsShields && !p.grantsCoins) {
      return l10nFill(
        l10n.t('shop_bought_shield'),
        {'n': '${p.shields}', 's': '$shields'},
      );
    }
    return l10nFill(
      l10n.t('shop_bought'),
      {'n': '${p.coins}', 'bal': '$coin'},
    );
  }

  Future<void> _buy(ShopProduct product) async {
    if (_buyingId != null) return;
    setState(() => _buyingId = product.id);
    try {
      final user = await checkoutShopProduct(
        billing: sl<BillingGateway>(),
        server: sl<GameServer>(),
        productId: product.id,
      );
      if (!mounted) return;
      await context.read<AuthCubit>().refreshUser();
      if (!mounted) return;
      final l10n = sl<L10n>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_boughtMessage(l10n, product, user.coin, user.shields)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _buyingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = sl<L10n>();
    final user = context.watch<AuthCubit>().state.user;
    final locale = user?.locale ?? l10n.id;

    return Scaffold(
      backgroundColor: AppColors.cosmicBg,
      body: CosmicBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: ShimmerTitle(
                        text: l10n.t('shop'),
                        fontSize: 26,
                        textAlign: TextAlign.left,
                      ),
                    ),
                    Text(
                      '🛡 ${user?.shields ?? 0}  ·  ${user?.coin ?? 0} 🪙',
                      style: const TextStyle(
                        color: AppColors.cosmicGold,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Text(
                  l10n.t('shop_sub'),
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: FutureBuilder(
                  future: _shelf,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final shelf = snap.data!;
                    final products = shelf.products;
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final p = products[i];
                        final storePrice = shelf.prices[p.id];
                        final canBuy = shelf.available && storePrice != null;
                        final busy = _buyingId == p.id;
                        final badge = _badgeLabel(l10n, p.badge);
                        final isShield = p.grantsShields && !p.grantsCoins;
                        return CosmicGlassCard(
                          colors: isShield
                              ? const [
                                  Color(0xFF3B82F6),
                                  Color(0xFF1E3A5F),
                                  Color(0xFF0F172A),
                                ]
                              : const [
                                  Color(0xFF334155),
                                  Color(0xFF1E293B),
                                  Color(0xFF0F172A),
                                ],
                          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: (isShield
                                          ? const Color(0xFF60A5FA)
                                          : AppColors.cosmicGold)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  isShield ? '🛡' : '🪙',
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            _title(l10n, p),
                                            style: const TextStyle(
                                              color: Color(0xFFF1F5F9),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        if (badge.isNotEmpty) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: p.popular
                                                  ? AppColors.cosmicGreen
                                                      .withValues(alpha: 0.2)
                                                  : AppColors.cosmicGold
                                                      .withValues(alpha: 0.18),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              badge,
                                              style: TextStyle(
                                                color: p.popular
                                                    ? AppColors.cosmicGreen
                                                    : AppColors.cosmicGold,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      storePrice ?? p.priceLabel(locale),
                                      style: const TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              FilledButton(
                                onPressed: busy || !canBuy ? null : () => _buy(p),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.cosmicGreen,
                                  foregroundColor: const Color(0xFF0F172A),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        canBuy
                                            ? l10n.t('shop_buy')
                                            : l10n.t('shop_unavailable'),
                                      ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String l10nFill(String template, Map<String, String> vars) {
  var out = template;
  for (final e in vars.entries) {
    out = out.replaceAll('{${e.key}}', e.value);
  }
  return out;
}
