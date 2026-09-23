import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/remote/league_remote_sync.dart';

void main() {
  test('bootstrap updates league config and leaves other boxes alone', () async {
    final store = MemoryKeyValueStore();
    await store.put('users', 'local', {'id': 'local'});
    await applyLeagueBootstrap(store, {
      'gameId': 'luno_league',
      'config': {'adCoinReward': 9, 'dailyWinCoins': 40},
      'shop': [
        {
          'id': 'coins_100',
          'coins': 100,
          'shields': 0,
          'priceTry': '₺19,99',
          'priceUsd': '\$0.99',
          'popular': false,
          'sortOrder': 10,
          'active': true,
        },
      ],
      'words': [],
      'daily': [],
    });
    final config = await store.get('app_config', 'default');
    expect(config?['adCoinReward'], 9);
    expect(await store.get('shop_products', 'coins_100'), isNotNull);
    expect(await store.get('users', 'local'), isNotNull);
    expect(await store.values('words'), isEmpty);
  });
}
