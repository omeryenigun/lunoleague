import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';

class AdminOverview {
  const AdminOverview({
    required this.registeredCount,
    required this.guestCount,
    required this.bannedCount,
    required this.todayDailyCompleted,
    required this.todayEndlessCompleted,
    required this.wordPoolByLength,
    required this.missingDailyLeagues,
    required this.weekId,
  });

  final int registeredCount;
  final int guestCount;
  final int bannedCount;
  final int todayDailyCompleted;
  final int todayEndlessCompleted;
  final Map<int, int> wordPoolByLength;
  final List<LeagueTier> missingDailyLeagues;
  final String weekId;
}

class AdminGameRecord {
  const AdminGameRecord({
    required this.sessionId,
    required this.userId,
    required this.displayName,
    required this.gameType,
    required this.wordId,
    required this.word,
    required this.guesses,
    required this.won,
    required this.timeSpent,
    required this.hintUsed,
    required this.xpEarned,
    required this.coinEarned,
    required this.leaguePoints,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.inProgress = false,
    this.isGuest = false,
    this.isSample = false,
    this.gameNo,
  });

  final String sessionId;
  final String userId;
  final String displayName;
  final GameType gameType;
  final String wordId;
  final String word;
  final int guesses;
  final bool won;
  final int timeSpent;
  final bool hintUsed;
  final int xpEarned;
  final int coinEarned;
  final int leaguePoints;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final bool inProgress;
  final bool isGuest;
  final bool isSample;
  final int? gameNo;

  DateTime get effectiveStart =>
      startedAt ?? createdAt.subtract(Duration(seconds: timeSpent));
  DateTime? get effectiveEnd =>
      inProgress ? null : (endedAt ?? createdAt);
  String get playerLabel => isGuest ? 'Misafir' : displayName;
  String get statusLabel => inProgress
      ? 'Devam'
      : (won ? 'Tamamlandı · kazandı' : 'Tamamlandı · kaybetti');
}

class AdminUserDetail {
  const AdminUserDetail({
    required this.user,
    required this.recentGames,
  });

  final UserEntity user;
  final List<AdminGameRecord> recentGames;
}

class AdminSessionDetail {
  const AdminSessionDetail({
    required this.session,
    required this.userId,
    required this.displayName,
    required this.wordId,
    required this.word,
  });

  final GameSessionView session;
  final String userId;
  final String displayName;
  final String wordId;
  final String word;
}
