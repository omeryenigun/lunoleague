import '../entities/match_snapshot.dart';

/// Solved players rank above players who finished without the word.
/// Among solved players, fewer guesses win, then the shorter clock.
List<MatchRow> rankMatch(List<MatchRow> rows) {
  final ordered = [...rows]..sort(_compare);
  return [
    for (var i = 0; i < ordered.length; i++)
      MatchRow(
        userId: ordered[i].userId,
        name: ordered[i].name,
        finished: ordered[i].finished,
        solved: ordered[i].solved,
        guesses: ordered[i].guesses,
        millis: ordered[i].millis,
        left: ordered[i].left,
        rank: ordered[i].finished ? i + 1 : 0,
        greens: ordered[i].greens,
        yellows: ordered[i].yellows,
      ),
  ];
}

int _compare(MatchRow a, MatchRow b) {
  if (a.finished != b.finished) return a.finished ? -1 : 1;
  if (!a.finished) return a.name.compareTo(b.name);
  if (a.solved != b.solved) return a.solved ? -1 : 1;
  if (!a.solved) return a.name.compareTo(b.name);
  final byGuess = a.guesses.compareTo(b.guesses);
  if (byGuess != 0) return byGuess;
  final byTime = a.millis.compareTo(b.millis);
  if (byTime != 0) return byTime;
  return a.name.compareTo(b.name);
}
