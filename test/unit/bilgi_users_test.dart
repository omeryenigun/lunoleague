import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/api/bilgi_users_http.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';

BilgiProfile _profile({
  required String id,
  String username = 'Ada',
  String email = 'ada@example.com',
  String passwordHash = 'abc',
  bool banned = false,
  int gold = 500,
  int level = 1,
}) {
  final now = DateTime(2026, 9, 30);
  return BilgiProfile(
    id: id,
    username: username,
    email: email,
    passwordHash: passwordHash,
    avatar: '😎',
    level: level,
    xp: 0,
    gold: gold,
    diamond: 0,
    lives: 5,
    livesAt: now,
    title: 'Çaylak',
    premium: false,
    premiumUntil: null,
    banned: banned,
    banReason: banned ? 'Askıya alındı' : '',
    city: '',
    createdAt: now,
    jokers: const {'half': 2},
    gamesPlayed: 0,
    correctTotal: 0,
    bestScore: 0,
    totalScore: 0,
    streak: 0,
    lastReward: '',
    rewardDay: 0,
    lastPlayDay: '',
    freePlaysUsed: 0,
    adFreeLeft: 3,
    inviteCode: 'LB11',
    invites: 0,
    friends: const [],
    badges: const [],
    duelWins: 0,
    categoriesPlayed: const [],
    adGoldToday: 0,
    adJokerToday: 0,
    adLifeToday: 0,
    adDoubleToday: 0,
    adDay: '',
    weekId: '',
    weekScore: 0,
  );
}

void main() {
  test('public map hides password hashes', () {
    final user = _profile(id: 'u1');
    final public = user.toPublicMap();
    expect(public.containsKey('passwordHash'), isFalse);
    expect(public['username'], 'Ada');
    expect(public['email'], 'ada@example.com');
    expect(bilgiUserPublicMap(user.toMap()).containsKey('passwordHash'), isFalse);
  });

  test('merge upserts by email and keeps server ban', () async {
    final store = MemoryKeyValueStore();
    final first = await mergeBilgiUser(
      store,
      _profile(id: 'local-a', username: 'Ada', email: 'ada@example.com', gold: 500),
    );
    expect(first.id, 'local-a');
    expect((await store.values('users')).length, 1);

    await store.put('users', first.id, first.copyWith(banned: true, banReason: 'Askıya alındı').toMap());

    final second = await mergeBilgiUser(
      store,
      _profile(
        id: 'local-b',
        username: 'Ada2',
        email: 'ada@example.com',
        gold: 900,
        banned: false,
      ),
    );
    expect(second.id, 'local-a');
    expect(second.username, 'Ada2');
    expect(second.gold, 500);
    expect(second.banned, isTrue);
    expect(second.banReason, 'Askıya alındı');
    expect((await store.values('users')).length, 1);
  });

  test('a guest is stored by id and stays off the shared account list', () async {
    final store = MemoryKeyValueStore();
    final saved = await mergeBilgiUser(
      store,
      _profile(id: 'g1', username: 'Misafir', email: '', passwordHash: '', gold: 20),
    );
    expect(saved.id, 'g1');
    expect(saved.gold, 500);
    expect(saved.email, isEmpty);
    expect(saved.passwordHash, isEmpty);
    expect(saved.accountId, isNull);
    expect(await store.values(lunoAccountsBox), isEmpty);
    final listed = annotateBilgiAccounts([saved], const []);
    expect(listed, hasLength(1));
    expect(listed.single.guestHere, isTrue);
    expect(listed.single.id, 'g1');
    expect(bilgiPublicPlayer(saved), isTrue);

    await store.put('users', saved.id, saved.copyWith(banned: true, banReason: 'Askıya alındı').toMap());
    final again = await mergeBilgiUser(
      store,
      _profile(id: 'g1', username: 'Misafir', email: '', passwordHash: '', gold: 80),
    );
    expect(again.id, 'g1');
    expect(again.banned, isTrue);
    expect(again.gold, 500);
    expect(await store.values(lunoAccountsBox), isEmpty);
  });

  test('two profiles cannot share a normalized username', () async {
    final store = MemoryKeyValueStore();
    final first = await mergeBilgiUser(
      store,
      _profile(id: 'a', username: 'Avatar', email: '', passwordHash: ''),
    );
    expect(first.username, 'Avatar');

    await expectLater(
      mergeBilgiUser(store, _profile(id: 'b', username: 'avatar', email: '', passwordHash: '')),
      throwsA(isA<BilgiUsernameTaken>()),
    );
    expect(await store.get('users', 'b'), isNull);
    expect((await store.values('users')).length, 1);

    final kept = await mergeBilgiUser(
      store,
      _profile(id: 'a', username: '  AVATAR  ', email: '', passwordHash: ''),
    );
    expect(kept.id, 'a');
    expect(bilgiUsernameNormalized(kept.username).toLowerCase(), 'avatar');

    final registered = await mergeBilgiUser(
      store,
      _profile(id: 'c', username: 'Deniz', email: 'deniz@example.com'),
    );
    expect(registered.username, 'Deniz');
    await expectLater(
      mergeBilgiUser(store, _profile(id: 'd', username: 'deniz', email: '', passwordHash: '')),
      throwsA(isA<BilgiUsernameTaken>()),
    );
    final again = await mergeBilgiUser(
      store,
      _profile(id: 'c', username: 'deniz', email: 'deniz@example.com', gold: 900),
    );
    expect(again.id, 'c');
    expect(again.gold, 500);
    expect(bilgiUsernameNormalized(again.username).toLowerCase(), 'deniz');

    expect(
      bilgiUsernameTaken(
        [
          {'id': 'a', 'username': ''},
          {'id': 'b', 'username': '   '},
        ],
        '',
        exceptId: 'c',
      ),
      isFalse,
    );
    expect(
      bilgiUsernameTaken(
        [
          {'id': 'a', 'username': ''},
        ],
        'Avatar',
        exceptId: 'c',
      ),
      isFalse,
    );
  });

  test('the phone shows the taken-name message and keeps the previous username', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore(), clock: () => DateTime.utc(2026, 10, 1));
    final guest = await server.profile();
    server.remoteUpsert = (user) async {
      if (bilgiUsernameNormalized(user.username).toLowerCase() == 'avatar') {
        throw const BilgiUsernameTaken();
      }
      return user.toPublicMap();
    };

    final taken = await server.updateProfile(username: 'Avatar');
    expect(taken.ok, isFalse);
    expect(taken.message, UserMessages.nicknameTaken);
    expect((await server.profile()).username, guest.username);

    final own = await server.updateProfile(username: guest.username);
    expect(own.ok, isTrue);
    expect(own.profile!.id, guest.id);
    expect(own.profile!.username, guest.username);
  });

  test('username and email are enough for admin search fields', () {
    final user = _profile(id: 'u1', username: 'Play Demo', email: 'demo@example.com');
    final query = 'demo@example.com';
    final hit = user.username.toLowerCase().contains(query) || user.email.toLowerCase().contains(query);
    expect(hit, isTrue);
  });
}
