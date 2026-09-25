import 'package:kelimelig/domain/entities/match_snapshot.dart';

enum RivalNoticeKind { colors, finished }

class RivalNotice {
  const RivalNotice({
    required this.name,
    required this.kind,
    this.greens = 0,
    this.yellows = 0,
    this.solved = false,
  });

  final String name;
  final RivalNoticeKind kind;
  final int greens;
  final int yellows;
  final bool solved;
}

/// Notices for rivals only. The first snapshot is a baseline and stays quiet.
List<RivalNotice> rivalNotices({
  required List<MatchRow>? previous,
  required List<MatchRow> next,
  required String me,
}) {
  if (previous == null) return const [];
  final before = {for (final row in previous) row.userId: row};
  final notices = <RivalNotice>[];
  for (final row in next) {
    if (row.userId == me) continue;
    final old = before[row.userId];
    if (old == null) continue;
    if (row.guesses > old.guesses) {
      notices.add(RivalNotice(
        name: row.name,
        kind: RivalNoticeKind.colors,
        greens: row.greens,
        yellows: row.yellows,
      ));
    }
    if (row.finished && !old.finished) {
      notices.add(RivalNotice(
        name: row.name,
        kind: RivalNoticeKind.finished,
        solved: row.solved,
      ));
    }
  }
  return notices;
}
