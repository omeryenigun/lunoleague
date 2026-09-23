import 'package:flutter/material.dart';
import 'package:kelimelig/admin/game_catalog.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

/// Luno Fall admin reads only the fall store. League screens are not reused.
class FallAdminScreen extends StatefulWidget {
  const FallAdminScreen({super.key, required this.section});

  final AdminSection section;

  @override
  State<FallAdminScreen> createState() => _FallAdminScreenState();
}

class _FallAdminScreenState extends State<FallAdminScreen> {
  late final Future<Object> _future = _load(sl<LunoFallServer>());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snap.data!;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Luno Fall · luno_fall__*',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Bu ekran Luno League kutularını okumaz. TR ve EN ayrı profillerdir.',
            ),
            const SizedBox(height: 16),
            if (data is Map<String, dynamic>)
              for (final entry in data.entries)
                ListTile(title: Text(entry.key), trailing: Text('${entry.value}')),
            if (data is List<FallRunRecord>)
              for (final run in data)
                ListTile(
                  title: Text('${run.locale.toUpperCase()} · ${run.difficulty}'),
                  subtitle: Text('${run.words} kelime · kombo ${run.maxCombo}'),
                  trailing: Text('${run.score}'),
                ),
            if (data is List<FallProduct>)
              for (final product in data)
                ListTile(
                  title: Text(product.id),
                  subtitle: Text(product.kind),
                  trailing: Text(product.priceLabel),
                ),
          ],
        );
      },
    );
  }

  Future<Object> _load(LunoFallServer server) async {
    switch (widget.section) {
      case AdminSection.overview:
        return server.adminOverview();
      case AdminSection.games:
        await server.setLocale('tr');
        final tr = await server.recentRuns();
        await server.setLocale('en');
        final en = await server.recentRuns();
        await server.setLocale('tr');
        return [...tr, ...en];
      case AdminSection.shop:
        return server.shop();
      case AdminSection.settings:
        final tr = await server.setLocale('tr');
        final en = await server.setLocale('en');
        await server.setLocale('tr');
        return {
          'trCoins': tr.coins,
          'enCoins': en.coins,
          'trPremium': tr.premium,
          'enPremium': en.premium,
          'bannerCap': 20,
          'rewardCap': 5,
        };
      default:
        return server.adminOverview();
    }
  }
}
