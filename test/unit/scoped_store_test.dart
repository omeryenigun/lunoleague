import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/local/scoped_store.dart';

void main() {
  test('each game keeps its own users', () async {
    final root = MemoryKeyValueStore();
    final luno = LocalGameServer(
      ScopedKeyValueStore(root, 'luno_league'),
    );
    final other = LocalGameServer(
      ScopedKeyValueStore(root, 'other_game'),
    );
    await luno.initialize();
    await other.initialize();

    final lunoUser = await luno.signInAnonymously();
    final otherUser = await other.signInAnonymously();

    expect(
      (await luno.adminListUsers()).map((user) => user.id),
      [lunoUser.id],
    );
    expect(
      (await other.adminListUsers()).map((user) => user.id),
      [otherUser.id],
    );
    expect(await root.get('users', lunoUser.id), isNull);
    expect(await root.get('luno_league__users', lunoUser.id), isNotNull);
    expect(await root.get('other_game__users', lunoUser.id), isNull);
    expect(await root.get('luno_league__users', otherUser.id), isNull);
  });
}
