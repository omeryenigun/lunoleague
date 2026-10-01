import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';

void main() {
  test('link keeps the first game and adds later games', () async {
    final root = MemoryKeyValueStore();
    final directory = LunoAccountDirectory(root);
    final first = await directory.link(
      gameId: GameIds.lunoBilgi,
      progressId: 'bilgi-1',
      displayName: 'Ada',
      provider: 'email',
      email: 'ada@luno.app',
    );
    final second = await directory.link(
      gameId: GameIds.lunoLeague,
      progressId: 'league-1',
      displayName: 'Ada',
      provider: 'email',
      email: 'ada@luno.app',
    );
    expect(second.account.id, first.account.id);
    expect(second.account.firstGameId, GameIds.lunoBilgi);
    expect(second.account.activatedGames, [GameIds.lunoBilgi, GameIds.lunoLeague]);
    expect(second.otherProgressId, isNull);
  });

  test('a different progress id is opened and not replaced', () async {
    final root = MemoryKeyValueStore();
    final directory = LunoAccountDirectory(root);
    await directory.link(
      gameId: GameIds.lunoBilgi,
      progressId: 'rich',
      displayName: 'Ada',
      provider: 'google',
      email: 'ada@luno.app',
      googleId: 'gid',
    );
    final again = await directory.link(
      gameId: GameIds.lunoBilgi,
      progressId: 'guest',
      displayName: 'Misafir1',
      provider: 'google',
      email: 'ada@luno.app',
      googleId: 'gid',
    );
    expect(again.otherProgressId, 'rich');
    expect(again.account.progressIds[GameIds.lunoBilgi], 'rich');
  });

  test('bilgi register upgrades the open guest', () async {
    final root = MemoryKeyValueStore();
    final server = LunoBilgiServer(ScopedKeyValueStore(root, GameIds.lunoBilgi));
    final guest = await server.profile();
    final result = await server.register(
      username: 'Ada',
      email: 'ada@luno.app',
      password: 'secret1',
    );
    expect(result.ok, isTrue);
    expect(result.profile!.id, guest.id);
    expect(result.profile!.gold, guest.gold);
    expect(result.profile!.email, 'ada@luno.app');
    final account = (await LunoAccountDirectory(root).all()).single;
    expect(account.firstGameId, GameIds.lunoBilgi);
    expect(account.progressIds[GameIds.lunoBilgi], guest.id);
    expect(account.activatedGames, [GameIds.lunoBilgi]);
  });

  test('bilgi opens an existing progress and leaves the guest alone', () async {
    final root = MemoryKeyValueStore();
    final bilgi = ScopedKeyValueStore(root, GameIds.lunoBilgi);
    final server = LunoBilgiServer(bilgi);
    final guest = await server.profile();
    final rich = BilgiProfile.fromMap({
      'id': 'rich',
      'username': 'Ada',
      'email': 'ada@luno.app',
      'gold': 20,
    });
    await bilgi.put('users', 'rich', rich.toMap());
    await LunoAccountDirectory(root).link(
      gameId: GameIds.lunoBilgi,
      progressId: 'rich',
      displayName: 'Ada',
      provider: 'google',
      email: 'ada@luno.app',
      googleId: 'gid',
    );
    final result = await server.loginSocial(
      email: 'ada@luno.app',
      username: 'Google Ada',
      googleId: 'gid',
    );
    expect(result.profile!.id, 'rich');
    expect(result.profile!.gold, 20);
    final guestRow = await bilgi.get('users', guest.id);
    expect('${guestRow!['email'] ?? ''}', isEmpty);
    expect(guestRow['gold'], guest.gold);
  });

  test('league email registration keeps the guest id and writes the account', () async {
    final root = MemoryKeyValueStore();
    final server = LocalGameServer(ScopedKeyValueStore(root, GameIds.lunoLeague));
    await server.initialize();
    final guest = await server.signInAnonymously();
    final user = await server.registerWithEmail(
      email: 'ada@luno.app',
      password: 'secret1',
      displayName: 'Ada',
    );
    expect(user.id, guest.id);
    expect(user.isAnonymous, isFalse);
    expect(user.accountId, isNotNull);
    final account = (await LunoAccountDirectory(root).all()).single;
    expect(account.firstGameId, GameIds.lunoLeague);
    expect(account.progressIds[GameIds.lunoLeague], guest.id);
  });

  test('apple sign-in does not create an account', () async {
    final root = MemoryKeyValueStore();
    final server = LocalGameServer(ScopedKeyValueStore(root, GameIds.lunoLeague));
    await server.initialize();
    await server.signInAnonymously();
    expect(
      () => server.signInWithApple(),
      throwsA(
        isA<AppFailure>().having((error) => error.message, 'message', UserMessages.appleNotReady),
      ),
    );
    expect(await LunoAccountDirectory(root).all(), isEmpty);
    expect((await server.currentUser())!.isAnonymous, isTrue);
  });
}
