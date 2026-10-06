import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';

BilgiRoom _room({
  String hostId = 'host',
  String kind = 'duello',
  String status = 'lobby',
  List<Map<String, String>>? players,
}) {
  return BilgiRoom(
    code: '123456',
    hostId: hostId,
    hostName: 'Host',
    categoryId: 'tumu',
    questionCount: 10,
    seconds: 10,
    difficulty: 'orta',
    players: players ??
        const [
          {'id': 'host', 'name': 'Host', 'role': 'host'},
        ],
    kind: kind,
    status: status,
  );
}

void main() {
  test('a duel start button waits until the host sees the second player', () {
    final alone = _room();
    expect(bilgiRoomStartVisible(alone, 'host'), isFalse);
    expect(bilgiViewerHostsRoom(alone, 'host'), isTrue);

    final full = _room(
      players: const [
        {'id': 'host', 'name': 'Host', 'role': 'host'},
        {'id': 'guest', 'name': 'Guest', 'role': 'player'},
      ],
    );
    expect(bilgiRoomStartVisible(full, 'host'), isTrue);
    expect(bilgiRoomStartVisible(full, 'guest'), isFalse);
    expect(bilgiRoomStartVisible(full, 'host', remote: false), isTrue);
  });

  test('the host seat still starts when the host id field does not match the profile', () {
    final full = _room(
      hostId: '',
      players: const [
        {'id': 'seat-host', 'name': 'Host', 'role': 'host'},
        {'id': 'guest', 'name': 'Guest', 'role': 'player'},
      ],
    );
    expect(bilgiViewerHostsRoom(full, 'seat-host'), isTrue);
    expect(bilgiRoomStartVisible(full, 'seat-host'), isTrue);
    expect(bilgiRoomStartVisible(full, 'guest'), isFalse);
  });

  test('a playing room and a private room keep their start rules', () {
    final playing = _room(
      status: 'playing',
      players: const [
        {'id': 'host', 'name': 'Host', 'role': 'host'},
        {'id': 'guest', 'name': 'Guest', 'role': 'player'},
      ],
    );
    expect(bilgiRoomStartVisible(playing, 'host'), isFalse);

    final privateRoom = _room(kind: 'oda');
    expect(bilgiRoomStartVisible(privateRoom, 'host'), isTrue);
    expect(bilgiRoomStartVisible(privateRoom, 'guest'), isFalse);
  });

  test('a missing host id is recovered from the host seat', () {
    final room = BilgiRoom.fromMap({
      'code': '123456',
      'hostName': 'Host',
      'categoryId': 'tumu',
      'questionCount': 10,
      'seconds': 10,
      'difficulty': 'orta',
      'kind': 'duello',
      'players': [
        {'id': 'seat-host', 'name': 'Host', 'role': 'host'},
        {'id': 'guest', 'name': 'Guest', 'role': 'player'},
      ],
    });
    expect(room.hostId, 'seat-host');
    expect(bilgiRoomStartVisible(room, 'seat-host'), isTrue);
  });

  test('invite setup keeps the host choice and falls back when the value is outside the list', () {
    expect(bilgiInviteCount('duello', 5), 5);
    expect(bilgiInviteCount('duello', 7), 10);
    expect(bilgiInviteCount('oda', 0), 20);
    expect(bilgiInvitePace('oda', 20), 20);
    expect(bilgiInvitePace('duello', 12), 10);
    expect(bilgiInviteDifficulty('zor'), 'zor');
    expect(bilgiInviteDifficulty('kolayca'), 'hepsi');
  });

  test('a duel or private room stores the host setup', () async {
    final server = LunoBilgiServer(MemoryKeyValueStore());
    final duel = await server.createRoom(
      kind: 'duello',
      categoryId: 'tarih',
      subcategory: 'Osmanlı',
      difficulty: 'zor',
      questionCount: 5,
      seconds: 20,
    );
    expect(duel!.questionCount, 5);
    expect(duel.seconds, 20);
    expect(duel.difficulty, 'zor');
    expect(duel.categoryId, 'tarih');
    expect(duel.subcategory, 'Osmanlı');

    final mixed = await server.createRoom(
      kind: 'oda',
      categoryId: 'tumu',
      subcategory: 'Osmanlı',
      difficulty: 'yok',
      questionCount: 99,
      seconds: 15,
    );
    expect(mixed!.questionCount, 20);
    expect(mixed.seconds, 15);
    expect(mixed.difficulty, 'hepsi');
    expect(mixed.subcategory, '');
  });

  test('starting a duel spends no life and skips the pre-game ad', () async {
    final clock = DateTime(2026, 10, 6, 12);
    final store = MemoryKeyValueStore();
    final server = LunoBilgiServer(store, clock: () => clock);
    final user = await server.profile();
    await store.put(
      'users',
      user.id,
      user.copyWith(lives: 3, livesAt: clock, lastPlayDay: '2026-10-06', freePlaysUsed: 5, adFreeLeft: 0).toMap(),
    );
    final question = BilgiQuestion(
      id: 'q1',
      categoryId: 'genel',
      text: 'Soru',
      options: const ['A', 'B', 'C', 'D'],
      correct: 0,
      difficulty: 'kolay',
      explanation: 'aciklama',
    );
    final solo = await server.startRound(
      modeId: 'hizli',
      categoryId: 'tumu',
      fixedQuestions: [question],
      questionCount: 1,
    );
    expect(solo.message, 'ad');
    expect((await server.profile()).lives, 3);

    final duel = await server.startRound(
      modeId: 'duello',
      categoryId: 'tumu',
      fixedQuestions: [question],
      questionCount: 1,
      seconds: 20,
    );
    expect(duel.message, isNull);
    expect(duel.round!.seconds, 20);
    expect(duel.round!.lifeCost, 0);
    final after = await server.profile();
    expect(after.lives, 3);
    expect(after.freePlaysUsed, 5);
    expect(after.adFreeLeft, 0);
  });
}
