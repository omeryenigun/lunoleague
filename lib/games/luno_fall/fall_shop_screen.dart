import 'package:flutter/material.dart';
import 'package:kelimelig/games/luno_fall/fall_copy.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

class FallShopScreen extends StatefulWidget {
  const FallShopScreen({super.key});

  @override
  State<FallShopScreen> createState() => _FallShopScreenState();
}

class _FallShopScreenState extends State<FallShopScreen> {
  FallProfile? _profile;
  String? _busy;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await sl<LunoFallServer>().profile();
    if (mounted) setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    if (profile == null) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2ECC71)));
    }
    final lang = profile.locale;
    final products = sl<LunoFallServer>().shop();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      children: [
        Text(
          '${fallText(lang, 'shop')} · ${profile.coins}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFF1C40F)),
        ),
        const SizedBox(height: 8),
        Text(
          lang == 'en'
              ? 'Coin packs are a mock purchase. Power-ups spend this game’s coins only.'
              : 'Coin paketleri deneme satın alması. Güçler yalnız bu oyunun coinini harcar.',
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          value: profile.premium,
          title: Text(fallText(lang, 'premium')),
          subtitle: Text(lang == 'en' ? 'Local preview, not a real subscription' : 'Yerel önizleme, gerçek abonelik değil'),
          onChanged: (value) async {
            await sl<LunoFallServer>().setPremium(value);
            await _load();
          },
        ),
        for (final product in products)
          Card(
            color: const Color(0xFF111827),
            child: ListTile(
              title: Text(_title(product, lang)),
              subtitle: Text(product.kind == 'coins' ? product.priceLabel : '${product.coins} coin'),
              trailing: _busy == product.id
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : FilledButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        setState(() => _busy = product.id);
                        final next = await sl<LunoFallServer>().buy(product.id);
                        if (!mounted) return;
                        setState(() {
                          _busy = null;
                          if (next != null) _profile = next;
                        });
                        if (next == null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(lang == 'en' ? 'Not enough coins' : 'Coin yetmiyor')),
                          );
                        }
                      },
                      child: Text(lang == 'en' ? 'Get' : 'Al'),
                    ),
            ),
          ),
      ],
    );
  }

  String _title(FallProduct product, String lang) {
    final en = lang == 'en';
    return switch (product.kind) {
      'coins' => '${product.coins} ${en ? 'coins' : 'coin'}',
      'hint' => en ? 'Letter hint' : 'Harf ipucu',
      'shield' => en ? 'Shield' : 'Kalkan',
      'joker' => en ? 'Joker' : 'Joker',
      'life' => en ? 'Extra life' : 'Ekstra can',
      'time' => en ? '+10 seconds' : '+10 saniye',
      _ => product.id,
    };
  }
}
