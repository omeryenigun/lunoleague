import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';

void main() {
  test('guest suffix is the last digits of the profile id and stays put', () {
    const id = 'u172778163434564';
    expect(bilgiGuestUsername(id), 'Misafir163434564');
    expect(bilgiGuestUsername(id), bilgiGuestUsername(id));
    expect(
      bilgiGuestUsername(id, {'misafir163434564'}),
      'Misafir8163434564',
    );
  });

  test('new and placeholder profiles keep one guest name without resetting progress', () async {
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store, clock: () => DateTime.utc(2026, 10, 1));
    final first = await server.profile();
    final digits = first.id.replaceAll(RegExp(r'[^0-9]'), '');
    expect(first.username, 'Misafir${digits.substring(digits.length - 9)}');
    expect(first.gold, 500);
    expect(first.lives, 5);

    final again = await server.profile();
    expect(again.id, first.id);
    expect(again.username, first.username);

    final raw = await store.get('users', first.id);
    raw!['username'] = 'Oyuncu';
    raw['gold'] = 900;
    raw['gamesPlayed'] = 4;
    await store.put('users', first.id, raw);

    final migrated = await server.profile();
    expect(migrated.id, first.id);
    expect(migrated.username, first.username);
    expect(migrated.gold, 900);
    expect(migrated.gamesPlayed, 4);

    final kept = await server.profile();
    expect(kept.username, first.username);
  });

  test('a chosen name and a registered username are not replaced', () async {
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store, clock: () => DateTime.utc(2026, 10, 1));
    final guest = await server.profile();
    final renamed = await server.updateProfile(username: 'Deniz');
    expect(renamed.ok, isTrue);
    expect(renamed.profile!.username, 'Deniz');
    expect((await server.profile()).username, 'Deniz');

    final raw = await store.get('users', guest.id);
    raw!['username'] = 'Oyuncu';
    await store.put('users', guest.id, raw);
    expect((await server.profile()).username, 'Oyuncu');

    final registered = await server.register(
      username: 'Ada',
      email: 'ada@example.com',
      password: 'secret1',
    );
    expect(registered.ok, isTrue);
    expect(registered.profile!.username, 'Ada');
    expect(registered.profile!.id, isNot(guest.id));
    expect((await server.profile()).username, 'Ada');
  });

  test('guest nickname edits use the existing username rules and persist', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime.utc(2026, 10, 1));
    final guest = await server.profile();

    final short = await server.updateProfile(username: 'A');
    expect(short.ok, isFalse);
    expect(short.message, UserMessages.nicknameShort);
    expect((await server.profile()).username, guest.username);

    final bad = await server.updateProfile(username: 'Ada!');
    expect(bad.ok, isFalse);
    expect(bad.message, UserMessages.nicknameBad);

    final long = await server.updateProfile(username: 'A' * 21);
    expect(long.ok, isFalse);
    expect(long.message, UserMessages.nicknameLong);

    final saved = await server.updateProfile(username: '  Deniz  ');
    expect(saved.ok, isTrue);
    expect(saved.profile!.id, guest.id);
    expect(saved.profile!.username, 'Deniz');
    expect((await server.profile()).username, 'Deniz');

    final registered = await server.register(
      username: 'Ada',
      email: 'ada@example.com',
      password: 'secret1',
    );
    expect(registered.ok, isTrue);
    final taken = await server.updateProfile(username: 'deniz');
    expect(taken.ok, isFalse);
    expect(taken.message, UserMessages.nicknameTaken);
    expect((await server.profile()).username, 'Ada');
  });
}
