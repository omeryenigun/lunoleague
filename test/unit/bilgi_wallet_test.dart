import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';

void main() {
  test('a new guest gets starter lines and a second sync does not duplicate them', () async {
    final ledger = MemoryBilgiLedger();
    final book = BilgiWalletBook(
      MemoryKeyValueStore(),
      ledger,
      clock: () => DateTime.utc(2026, 10, 2, 9),
    );
    final first = await book.apply({'op': 'sync', 'userId': 'guest-1'});
    expect(first.profile?.gold, 500);
    expect(first.profile?.lives, 5);
    expect(ledger.lines.where((line) => line.reason == 'starter'), isNotEmpty);
    final starterCount = ledger.lines.length;
    final again = await book.apply({'op': 'sync', 'userId': 'guest-1'});
    expect(again.profile?.gold, 500);
    expect(ledger.lines, hasLength(starterCount));
  });

  test('an existing profile gets one opening snapshot', () async {
    final store = MemoryKeyValueStore();
    final ledger = MemoryBilgiLedger();
    final book = BilgiWalletBook(store, ledger, clock: () => DateTime.utc(2026, 10, 2, 9));
    final existing = bilgiFreshProfile(
      id: 'ada',
      now: DateTime.utc(2026, 10, 1),
      config: const BilgiConfig(),
    ).copyWith(gold: 1200, xp: 40, username: 'Ada');
    await store.put(bilgiWalletUsers, existing.id, existing.toMap());
    final opened = await book.apply({'op': 'sync', 'userId': 'ada'});
    expect(opened.profile?.gold, 1200);
    expect(ledger.lines.where((line) => line.reason == 'opening' && line.asset == 'gold').single.balanceAfter, 1200);
    await book.apply({'op': 'sync', 'userId': 'ada'});
    expect(ledger.lines.where((line) => line.reason == 'opening'), hasLength(ledger.lines.where((line) => line.reason == 'opening').length));
    expect(ledger.lines.where((line) => line.reason == 'opening' && line.asset == 'gold'), hasLength(1));
  });

  test('life spend and finish are recorded once', () async {
    final ledger = MemoryBilgiLedger();
    final book = BilgiWalletBook(
      MemoryKeyValueStore(),
      ledger,
      clock: () => DateTime.utc(2026, 10, 2, 9),
    );
    await book.apply({'op': 'sync', 'userId': 'ada'});
    final spent = await book.apply({
      'op': 'life_spend',
      'userId': 'ada',
      'modeId': 'klasik',
      'roundId': 'round-1',
    });
    expect(spent.profile?.lives, 4);
    final finished = await book.apply({
      'op': 'finish',
      'userId': 'ada',
      'roundId': 'round-1',
      'score': 40,
      'multiplier': 1,
      'modeId': 'klasik',
      'correct': 2,
      'categoryId': 'genel',
    });
    final again = await book.apply({
      'op': 'finish',
      'userId': 'ada',
      'roundId': 'round-1',
      'score': 40,
      'multiplier': 1,
      'modeId': 'klasik',
      'correct': 2,
      'categoryId': 'genel',
    });
    expect(finished.profile?.gold, again.profile?.gold);
    expect(ledger.lines.where((line) => line.reason == 'round_finish' && line.asset == 'gold'), hasLength(1));
    expect(ledger.lines.where((line) => line.reason == 'life_spend' && line.asset == 'life').single.amount, -1);
  });

  test('a phone upload cannot replace server gold', () {
    final server = bilgiFreshProfile(
      id: 'ada',
      now: DateTime.utc(2026, 10, 1),
      config: const BilgiConfig(),
    ).copyWith(gold: 800, email: 'ada@luno.test');
    final phone = server.copyWith(gold: 10, username: 'Ada');
    final kept = bilgiKeepServerWallet(server, phone);
    expect(kept.gold, 800);
    expect(kept.username, 'Ada');
  });

  test('a new day clears every ad counter before the next reward', () async {
    final store = MemoryKeyValueStore();
    final book = BilgiWalletBook(store, MemoryBilgiLedger(), clock: () => DateTime.utc(2026, 10, 2, 9));
    final existing = bilgiFreshProfile(
      id: 'ada',
      now: DateTime.utc(2026, 10, 1, 9),
      config: const BilgiConfig(),
    ).copyWith(adGoldToday: 10, adJokerToday: 4, adDay: '2026-10-01');
    await store.put(bilgiWalletUsers, existing.id, existing.toMap());
    final synced = await book.apply({'op': 'sync', 'userId': 'ada'});
    expect(synced.profile?.adGoldToday, 0);
    expect(synced.profile?.adJokerToday, 0);
    expect(synced.profile?.adDay, '2026-10-02');
    final rewarded = await book.apply({'op': 'ad', 'userId': 'ada', 'kind': 'gold'});
    expect(rewarded.error, isNull);
    expect(rewarded.profile?.adGoldToday, 1);
    expect(rewarded.profile?.adJokerToday, 0);
    expect(rewarded.profile?.gold, 550);
  });

  test('Istanbul midnight rolls the ad day while UTC is still yesterday', () async {
    final store = MemoryKeyValueStore();
    final book = BilgiWalletBook(store, MemoryBilgiLedger(), clock: () => DateTime.utc(2026, 10, 1, 22));
    final existing = bilgiFreshProfile(
      id: 'ada',
      now: DateTime.utc(2026, 10, 1, 9),
      config: const BilgiConfig(),
    ).copyWith(adGoldToday: 10, adDay: '2026-10-01');
    await store.put(bilgiWalletUsers, existing.id, existing.toMap());
    final synced = await book.apply({'op': 'sync', 'userId': 'ada'});
    expect(synced.profile?.adDay, '2026-10-02');
    expect(synced.profile?.adGoldToday, 0);
  });

  test('dismissing the shown league reward clears the text and keeps the gold', () {
    final server = bilgiFreshProfile(
      id: 'ada',
      now: DateTime.utc(2026, 10, 1),
      config: const BilgiConfig(),
    ).copyWith(gold: 800, leagueRewardWeek: '2026-W40', leagueRewardText: '1. sıra');
    final dismissed = bilgiKeepServerWallet(server, server.copyWith(leagueRewardText: ''));
    expect(dismissed.leagueRewardText, isEmpty);
    expect(dismissed.gold, 800);
    final behind = server.copyWith(leagueRewardWeek: '2026-W39', leagueRewardText: '');
    expect(bilgiKeepServerWallet(server, behind).leagueRewardText, '1. sıra');
  });

  test('invite records the host balance before the bonus', () async {
    final store = MemoryKeyValueStore();
    final ledger = MemoryBilgiLedger();
    final book = BilgiWalletBook(store, ledger, clock: () => DateTime.utc(2026, 10, 2, 9));
    final host = bilgiFreshProfile(
      id: 'host',
      now: DateTime.utc(2026, 10, 1),
      config: const BilgiConfig(),
    ).copyWith(gold: 800, inviteCode: 'LB99');
    await store.put(bilgiWalletUsers, host.id, host.toMap());
    await book.apply({'op': 'sync', 'userId': 'guest'});
    final invited = await book.apply({'op': 'invite', 'userId': 'guest', 'code': 'LB99'});
    expect(invited.error, isNull);
    expect(
      ledger.lines.where((line) => line.userId == 'host' && line.reason == 'opening' && line.asset == 'gold').single.balanceAfter,
      800,
    );
    expect(
      ledger.lines.where((line) => line.userId == 'host' && line.reason == 'invite' && line.asset == 'gold').single.amount,
      100,
    );
  });

  test('bind rejects a username another profile already has', () async {
    final store = MemoryKeyValueStore();
    final ledger = MemoryBilgiLedger();
    final book = BilgiWalletBook(store, ledger, clock: () => DateTime.utc(2026, 10, 2, 9));
    final guest = bilgiFreshProfile(
      id: 'guest',
      now: DateTime.utc(2026, 10, 1),
      config: const BilgiConfig(),
    ).copyWith(username: 'Avatar');
    await store.put(bilgiWalletUsers, guest.id, guest.toMap());

    final taken = await book.apply({
      'op': 'bind',
      'userId': 'ada',
      'email': 'ada@example.com',
      'username': 'avatar',
      'passwordHash': 'abc',
    });
    expect(taken.profile, isNull);
    expect(taken.error, UserMessages.nicknameTaken);
    expect(await store.get(bilgiWalletUsers, 'ada'), isNull);

    final own = await book.apply({
      'op': 'bind',
      'userId': 'guest',
      'email': 'guest@example.com',
      'username': 'Avatar',
      'passwordHash': 'abc',
    });
    expect(own.error, isNull);
    expect(own.profile?.id, 'guest');
    expect(own.profile?.username, 'Avatar');
  });

  test('elapsed life time writes one regen line', () async {
    final store = MemoryKeyValueStore();
    final ledger = MemoryBilgiLedger();
    final book = BilgiWalletBook(store, ledger, clock: () => DateTime.utc(2026, 10, 2, 12));
    final existing = bilgiFreshProfile(
      id: 'ada',
      now: DateTime.utc(2026, 10, 2, 10),
      config: const BilgiConfig(),
    ).copyWith(lives: 3, livesAt: DateTime.utc(2026, 10, 2, 10));
    await store.put(bilgiWalletUsers, existing.id, existing.toMap());
    final synced = await book.apply({'op': 'sync', 'userId': 'ada'});
    expect(synced.profile?.lives, 5);
    expect(ledger.lines.where((line) => line.reason == 'life_regen'), hasLength(1));
  });
}
