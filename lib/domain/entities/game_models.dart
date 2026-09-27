import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';

class GameSessionView {
  const GameSessionView({
    required this.sessionId,
    required this.gameType,
    required this.wordLength,
    required this.maxAttempts,
    required this.currentAttempt,
    required this.guesses,
    required this.keyboard,
    required this.status,
    required this.hintUsed,
    required this.revealedLetters,
    this.letterHintsOnRow = 0,
    required this.definitionHint,
    required this.startedAt,
    required this.expiresAt,
    this.outcome,
    this.answer,
    this.solved,
    this.dailyIndex = 1,
  });

  final String sessionId;
  final GameType gameType;
  final int wordLength;
  final int maxAttempts;
  final int currentAttempt;
  final List<EvaluatedGuess> guesses;
  final Map<String, LetterStatus> keyboard;
  final GameStatus status;
  final bool hintUsed;
  final Map<int, String> revealedLetters;

  /// Letter hints bought on the current row. One stays; the next skips the row.
  final int letterHintsOnRow;
  final String? definitionHint;
  final DateTime startedAt;
  final DateTime expiresAt;
  final GameOutcome? outcome;

  /// The secret, sent only after the session is finished.
  final String? answer;

  /// True when the finished session was won. Null while the game is open.
  final bool? solved;

  /// Today's shared daily number. 1 is the first game of the day.
  final int dailyIndex;

  bool get isFinished =>
      status == GameStatus.won ||
      status == GameStatus.lost ||
      status == GameStatus.completed;
}

class GameOutcome {
  const GameOutcome({
    required this.won,
    required this.word,
    required this.definition,
    required this.exampleSentence,
    required this.englishTranslation,
    required this.wordId,
    required this.xpEarned,
    required this.coinEarned,
    required this.leaguePoints,
    required this.streak,
    required this.level,
    required this.guesses,
    required this.timeSpentSeconds,
    required this.unlockedAchievements,
    this.rankBefore,
    this.rankAfter,
    this.endlessRun = 0,
    this.canReviveEndlessWithAd = false,
    this.showEndlessBreakAd = false,
  });

  final bool won;
  final String word;
  final String definition;
  final String exampleSentence;
  final String englishTranslation;
  final String wordId;
  final int xpEarned;
  final int coinEarned;
  final int leaguePoints;
  final int streak;
  final int level;
  final int guesses;
  final int timeSpentSeconds;
  final List<String> unlockedAchievements;
  final int? rankBefore;
  final int? rankAfter;
  final int endlessRun;
  final bool canReviveEndlessWithAd;
  final bool showEndlessBreakAd;
}

class PeriodStandingBrief {
  const PeriodStandingBrief({
    required this.period,
    required this.periodId,
    this.rank,
    this.points = 0,
  });

  final RankPeriod period;
  final String periodId;
  final int? rank;
  final int points;
}

class HomeSnapshot {
  const HomeSnapshot({
    required this.user,
    required this.dailyStatus,
    required this.dailyRewardAvailable,
    required this.rewardCycleDay,
    required this.weekId,
    required this.leagueRank,
    required this.leaguePoints,
    required this.offline,
    this.periodStandings = const [],
    this.dailyIndex = 1,
    this.dailyNeedsAd = false,
  });

  final UserEntity user;
  final DailyStatus dailyStatus;
  final bool dailyRewardAvailable;
  final int rewardCycleDay;
  final String weekId;
  final int? leagueRank;
  final int leaguePoints;
  final bool offline;
  final List<PeriodStandingBrief> periodStandings;

  /// The daily number the player should open next, or the one already open.
  final int dailyIndex;

  /// True when that number is not stored yet and an ad must create it.
  final bool dailyNeedsAd;
}

class DailyRewardResult {
  const DailyRewardResult({
    required this.day,
    required this.coins,
    required this.hintLevel1,
    required this.hintLevel2,
    required this.shield,
  });

  final int day;
  final int coins;
  final int hintLevel1;
  final int hintLevel2;
  final int shield;
}

class CompetitionSnapshot {
  const CompetitionSnapshot({
    required this.guest,
    required this.league,
    required this.weekId,
    required this.monthId,
    required this.seasonId,
    required this.yearId,
    required this.week,
    required this.month,
    required this.season,
    required this.year,
    this.weekTitleActive = false,
    this.badges = const [],
    this.unlockedCosmetics = const [],
    this.equippedTheme = 'theme_default',
    this.equippedFrame = 'frame_default',
  });

  final bool guest;
  final LeagueTier league;
  final String weekId;
  final String monthId;
  final String seasonId;
  final String yearId;
  final List<LeaderboardEntry> week;
  final List<LeaderboardEntry> month;
  final List<LeaderboardEntry> season;
  final List<LeaderboardEntry> year;
  final bool weekTitleActive;
  final List<String> badges;
  final List<String> unlockedCosmetics;
  final String equippedTheme;
  final String equippedFrame;

  LeaderboardEntry? get meWeek => week.where((e) => e.isCurrentUser).firstOrNull;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.points,
    required this.rank,
    required this.isCurrentUser,
  });

  final String userId;
  final String displayName;
  final int points;
  final int rank;
  final bool isCurrentUser;
}

class ResultPlace {
  const ResultPlace({
    required this.rank,
    required this.displayName,
    required this.score,
    required this.isCurrentUser,
  });

  final int rank;
  final String displayName;
  final String score;
  final bool isCurrentUser;

  Map<String, dynamic> toMap() => {
        'rank': rank,
        'displayName': displayName,
        'score': score,
        'isCurrentUser': isCurrentUser,
      };

  factory ResultPlace.fromMap(Map<dynamic, dynamic> map) {
    return ResultPlace(
      rank: map['rank'] as int? ?? 0,
      displayName: map['displayName'] as String? ?? '',
      score: map['score'] as String? ?? '',
      isCurrentUser: map['isCurrentUser'] as bool? ?? false,
    );
  }
}

class ResultBoardLines {
  const ResultBoardLines({required this.rows, this.rankOnly});

  final List<ResultPlace> rows;
  final int? rankOnly;
}

/// Top 10. Ranks 11–20 add the player as the 11th row. Beyond that, the
/// 11th row is only their rank number.
ResultBoardLines resultBoardLines(List<ResultPlace> all) {
  final top = all.where((e) => e.rank >= 1 && e.rank <= 10).toList()
    ..sort((a, b) => a.rank.compareTo(b.rank));
  final mine = all.where((e) => e.isCurrentUser);
  final me = mine.isEmpty ? null : mine.first;
  if (me == null || me.rank <= 10) {
    return ResultBoardLines(rows: top);
  }
  if (me.rank <= 20) {
    return ResultBoardLines(rows: [...top, me]);
  }
  return ResultBoardLines(rows: top, rankOnly: me.rank);
}

class SavedWord {
  const SavedWord({
    required this.id,
    required this.word,
    required this.definition,
    required this.exampleSentence,
    required this.englishTranslation,
    required this.savedAt,
  });

  final String id;
  final String word;
  final String definition;
  final String exampleSentence;
  final String englishTranslation;
  final DateTime savedAt;
}

class AchievementView {
  const AchievementView({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.rewardCoin,
    required this.unlocked,
    this.unlockedAt,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final int rewardCoin;
  final bool unlocked;
  final DateTime? unlockedAt;
}
