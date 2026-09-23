import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/remote/session_kv.dart';

void main() {
  test('player meta stays on the request and boxes stay shared', () async {
    final shared = MemoryKeyValueStore();
    final first = SessionKv(shared, userId: 'player-a');
    final second = SessionKv(shared, userId: 'player-b');

    await first.putMeta(SessionKv.deviceLocaleKey, 'en');
    await first.put('users', 'player-a', {'id': 'player-a'});
    await second.putMeta('seeded', '1');

    expect(await first.getMeta(SessionKv.currentUserKey), 'player-a');
    expect(await second.getMeta(SessionKv.currentUserKey), 'player-b');
    expect(await first.getMeta(SessionKv.deviceLocaleKey), 'en');
    expect(await second.getMeta(SessionKv.deviceLocaleKey), isNull);
    expect(await shared.getMeta(SessionKv.currentUserKey), isNull);
    expect(await shared.getMeta(SessionKv.deviceLocaleKey), isNull);
    expect(await shared.getMeta('seeded'), '1');
    expect(await second.get('users', 'player-a'), {'id': 'player-a'});

    await first.putMeta(SessionKv.currentUserKey, '');
    expect(first.userId, isNull);
    expect(await second.getMeta(SessionKv.currentUserKey), 'player-b');
  });
}
