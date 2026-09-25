class MatchRow {
  const MatchRow({
    required this.userId,
    required this.name,
    required this.finished,
    required this.solved,
    required this.guesses,
    required this.millis,
    required this.left,
    required this.rank,
    this.greens = 0,
    this.yellows = 0,
  });

  final String userId;
  final String name;
  final bool finished;
  final bool solved;
  final int guesses;
  final int millis;
  final bool left;
  final int rank;
  final int greens;
  final int yellows;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'name': name,
        'finished': finished,
        'solved': solved,
        'guesses': guesses,
        'millis': millis,
        'left': left,
        'rank': rank,
        'greens': greens,
        'yellows': yellows,
      };

  factory MatchRow.fromMap(Map<String, dynamic> map) => MatchRow(
        userId: map['userId'] as String,
        name: map['name'] as String? ?? '',
        finished: map['finished'] as bool? ?? false,
        solved: map['solved'] as bool? ?? false,
        guesses: map['guesses'] as int? ?? 0,
        millis: map['millis'] as int? ?? 0,
        left: map['left'] as bool? ?? false,
        rank: map['rank'] as int? ?? 0,
        greens: map['greens'] as int? ?? 0,
        yellows: map['yellows'] as int? ?? 0,
      );
}

class MatchSnapshot {
  const MatchSnapshot({
    required this.kind,
    required this.status,
    required this.rows,
    this.id,
    this.code,
    this.hostId,
    this.opponentName,
    this.sessionId,
    this.message,
  });

  final String kind;
  final String status;
  final List<MatchRow> rows;
  final String? id;
  final String? code;
  final String? hostId;
  final String? opponentName;
  final String? sessionId;
  final String? message;

  bool get ready => status == 'ready' || status == 'playing';

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'status': status,
        'rows': rows.map((r) => r.toMap()).toList(),
        'id': id,
        'code': code,
        'hostId': hostId,
        'opponentName': opponentName,
        'sessionId': sessionId,
        'message': message,
      };

  factory MatchSnapshot.fromMap(Map<String, dynamic> map) => MatchSnapshot(
        kind: map['kind'] as String? ?? '',
        status: map['status'] as String? ?? '',
        rows: ((map['rows'] as List?) ?? const [])
            .map((e) => MatchRow.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        id: map['id'] as String?,
        code: map['code'] as String?,
        hostId: map['hostId'] as String?,
        opponentName: map['opponentName'] as String?,
        sessionId: map['sessionId'] as String?,
        message: map['message'] as String?,
      );
}
