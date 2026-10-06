import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';

/// Host picks one of these question counts for a duel or private room.
const bilgiInviteCounts = [5, 10, 20];

/// Host picks one of these per-question timers, in seconds.
const bilgiInviteSeconds = [10, 15, 20];

const bilgiInviteDifficulties = {'kolay', 'orta', 'zor', 'efsane', 'hepsi', bilgiMixDifficulty};

bool bilgiInviteMode(String modeId) => modeId == 'duello' || modeId == 'oda';

int bilgiInviteCount(String kind, int requested) {
  if (bilgiInviteCounts.contains(requested)) return requested;
  return kind == 'duello' ? 10 : 20;
}

int bilgiInvitePace(String kind, int requested) {
  if (bilgiInviteSeconds.contains(requested)) return requested;
  return kind == 'duello' ? 10 : 15;
}

String bilgiInviteDifficulty(String requested) {
  final value = requested.trim();
  if (bilgiInviteDifficulties.contains(value)) return value;
  return 'hepsi';
}

class BilgiRoomSync {
  const BilgiRoomSync({
    this.room,
    this.questions = const [],
    this.spare,
    this.spares = const [],
    this.message,
  });

  final BilgiRoom? room;
  final List<BilgiQuestion> questions;
  final BilgiQuestion? spare;
  final List<BilgiQuestion> spares;
  final String? message;

  bool get ok => message == null && room != null;
}

class BilgiRoomHooks {
  const BilgiRoomHooks({
    required this.create,
    required this.join,
    required this.poll,
    required this.start,
    required this.score,
    required this.leave,
  });

  final Future<BilgiRoomSync> Function({
    required String kind,
    required String playerId,
    required String name,
    required String categoryId,
    required String subcategory,
    required String difficulty,
    required int questionCount,
    required int seconds,
  }) create;

  final Future<BilgiRoomSync> Function({
    required String code,
    required String playerId,
    required String name,
  }) join;

  final Future<BilgiRoomSync> Function(String code) poll;

  final Future<BilgiRoomSync> Function({
    required String code,
    required String playerId,
  }) start;

  final Future<bool> Function({
    required String code,
    required String playerId,
    required int score,
    required int index,
  }) score;

  final Future<bool> Function({
    required String code,
    required String playerId,
  }) leave;
}

/// True when [viewerId] is the person who created [room].
/// Matches [BilgiRoom.hostId], or the seated player whose role is host.
bool bilgiViewerHostsRoom(BilgiRoom room, String? viewerId) {
  final me = viewerId?.trim() ?? '';
  if (me.isEmpty) return false;
  if (room.hostId.trim() == me) return true;
  for (final player in room.players) {
    final id = (player['id'] ?? '').trim();
    final role = (player['role'] ?? '').trim();
    if (id == me && role == 'host') return true;
  }
  return false;
}

/// Host start control for a lobby.
/// A remote duel stays hidden until the snapshot lists the second player.
/// A private room still shows the control to the host with one seat.
bool bilgiRoomStartVisible(BilgiRoom room, String? viewerId, {bool remote = true}) {
  if (room.status == 'playing') return false;
  if (!bilgiViewerHostsRoom(room, viewerId)) return false;
  if (remote && room.kind == 'duello' && room.players.length < 2) return false;
  return true;
}
