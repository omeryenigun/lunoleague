import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kelimelig/admin/game_scope.dart';
import 'package:kelimelig/admin/widgets/admin_widgets.dart';
import 'package:kelimelig/core/theme/colors.dart';
import 'package:kelimelig/domain/entities/shop_product.dart';

class ShopAdminScreen extends StatefulWidget {
  const ShopAdminScreen({super.key});

  @override
  State<ShopAdminScreen> createState() => _ShopAdminScreenState();
}

class _ShopAdminScreenState extends State<ShopAdminScreen> {
  var _reloadToken = 0;
  String? _busyId;

  Future<List<ShopProduct>> _load() =>
      adminServer(context).adminListShopProducts();

  Future<void> _edit({ShopProduct? existing}) async {
    final isNew = existing == null;
    final idCtrl = TextEditingController(text: existing?.id ?? '');
    final coinsCtrl =
        TextEditingController(text: existing == null ? '100' : '${existing.coins}');
    final shieldsCtrl = TextEditingController(
      text: existing == null ? '0' : '${existing.shields}',
    );
    final tryCtrl =
        TextEditingController(text: existing?.priceTry ?? '₺19,99');
    final usdCtrl =
        TextEditingController(text: existing?.priceUsd ?? '\$0.99');
    final badgeCtrl = TextEditingController(text: existing?.badge ?? '');
    final sortCtrl = TextEditingController(
      text: '${existing?.sortOrder ?? ((await _load()).length + 1) * 10}',
    );
    var popular = existing?.popular ?? false;
    var active = existing?.active ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isNew ? 'Yeni ürün' : 'Ürün düzenle'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idCtrl,
                    enabled: isNew,
                    decoration: const InputDecoration(
                      labelText: 'Ürün id (SKU)',
                      hintText: 'coins_100 / streak_shield_1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: coinsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Coin miktarı (0 olabilir)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: shieldsCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Streak kalkanı',
                      hintText: '0 veya 1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fiyat (TRY)',
                      hintText: '₺69,99',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: usdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Fiyat (USD)',
                      hintText: '\$2.99',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: badgeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Rozet (opsiyonel)',
                      hintText: 'populer / avantaj / en_iyi / kalkan',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: sortCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'-?[0-9]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Sıra',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Popüler'),
                    value: popular,
                    onChanged: (v) => setLocal(() => popular = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aktif (oyunda görünür)'),
                    value: active,
                    onChanged: (v) => setLocal(() => active = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Vazgeç'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) return;
    final coins = int.tryParse(coinsCtrl.text.trim()) ?? 0;
    final shields = int.tryParse(shieldsCtrl.text.trim()) ?? 0;
    final sort = int.tryParse(sortCtrl.text.trim()) ?? 0;
    final badge = badgeCtrl.text.trim();
    try {
      await adminServer(context).adminUpsertShopProduct(
        ShopProduct(
          id: idCtrl.text.trim(),
          coins: coins,
          shields: shields,
          priceTry: tryCtrl.text.trim(),
          priceUsd: usdCtrl.text.trim(),
          badge: badge.isEmpty ? null : badge,
          popular: popular,
          sortOrder: sort,
          active: active,
        ),
      );
      setState(() => _reloadToken++);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _delete(ShopProduct p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürünü sil'),
        content: Text('${p.id} silinsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busyId = p.id);
    try {
      await adminServer(context).adminDeleteShopProduct(p.id);
      setState(() {
        _busyId = null;
        _reloadToken++;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Varsayılan katalog'),
        content: const Text(
          'Tüm mağaza ürünleri silinip varsayılan paketlerle değiştirilecek. Devam?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sıfırla'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await adminServer(context).adminResetShopCatalog();
    setState(() => _reloadToken++);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Mağaza ürünleri',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: _reset, child: const Text('Varsayılana dön')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ürün ekle'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: AdminBody(
            key: ValueKey(_reloadToken),
            future: _load(),
            builder: (context, products) {
              if (products.isEmpty) {
                return const Center(
                  child: Text(
                    'Ürün yok',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor:
                              WidgetStateProperty.all(AppColors.surface),
                          columnSpacing: 20,
                          columns: const [
                            DataColumn(label: Text('Id')),
                            DataColumn(label: Text('Coin'), numeric: true),
                            DataColumn(label: Text('Kalkan'), numeric: true),
                            DataColumn(label: Text('TRY')),
                            DataColumn(label: Text('USD')),
                            DataColumn(label: Text('Rozet')),
                            DataColumn(label: Text('Sıra'), numeric: true),
                            DataColumn(label: Text('Aktif')),
                            DataColumn(label: Text('')),
                          ],
                          rows: [
                            for (final p in products)
                              DataRow(
                                cells: [
                                  DataCell(Text(p.id)),
                                  DataCell(Text('${p.coins}')),
                                  DataCell(Text('${p.shields}')),
                                  DataCell(Text(p.priceTry)),
                                  DataCell(Text(p.priceUsd)),
                                  DataCell(
                                    Text(
                                      [
                                        if (p.badge != null) p.badge!,
                                        if (p.popular) 'popüler',
                                      ].join(' · '),
                                    ),
                                  ),
                                  DataCell(Text('${p.sortOrder}')),
                                  DataCell(
                                    Switch(
                                      value: p.active,
                                      onChanged: (v) async {
                                        await adminServer(context)
                                            .adminUpsertShopProduct(
                                          p.copyWith(active: v),
                                        );
                                        setState(() => _reloadToken++);
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    _busyId == p.id
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: () =>
                                                    _edit(existing: p),
                                                child: const Text('Düzenle'),
                                              ),
                                              TextButton(
                                                onPressed: () => _delete(p),
                                                child: const Text('Sil'),
                                              ),
                                            ],
                                          ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
