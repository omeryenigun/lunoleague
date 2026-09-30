import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/api/bilgi_users_http.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

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
    expect(second.gold, 900);
    expect(second.banned, isTrue);
    expect(second.banReason, 'Askıya alındı');
    expect((await store.values('users')).length, 1);
  });

  test('username and email are enough for admin search fields', () {
    final user = _profile(id: 'u1', username: 'Play Demo', email: 'demo@example.com');
    final query = 'demo@example.com';
    final hit = user.username.toLowerCase().contains(query) || user.email.toLowerCase().contains(query);
    expect(hit, isTrue);
  });
}
