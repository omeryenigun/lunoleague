import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room.dart';

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
}
