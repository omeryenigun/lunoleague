import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected an object');
}

int _intKey(Object? value) => value is int ? value : int.parse('$value');

Map<String, dynamic> wireGuess(EvaluatedGuess guess) => {
      'guess': guess.guess,
      'statuses': guess.statuses.map((s) => s.name).toList(),
    };

EvaluatedGuess readGuess(Object? raw) {
  final map = _map(raw);
  return EvaluatedGuess(
    guess: map['guess'] as String,
    statuses: [
      for (final name in map['statuses'] as List)
        LetterStatus.values.byName(name as String),
    ],
  );
}

Map<String, dynamic> wireOutcome(GameOutcome outcome) => {
      'won': outcome.won,
      'word': outcome.word,
      'definition': outcome.definition,
      'exampleSentence': outcome.exampleSentence,
      'englishTranslation': outcome.englishTranslation,
      'wordId': outcome.wordId,
      'xpEarned': outcome.xpEarned,
      'coinEarned': outcome.coinEarned,
      'leaguePoints': outcome.leaguePoints,
      'streak': outcome.streak,
      'level': outcome.level,
      'guesses': outcome.guesses,
      'timeSpentSeconds': outcome.timeSpentSeconds,
      'unlockedAchievements': outcome.unlockedAchievements,
      'rankBefore': outcome.rankBefore,
      'rankAfter': outcome.rankAfter,
      'endlessRun': outcome.endlessRun,
      'canReviveEndlessWithAd': outcome.canReviveEndlessWithAd,
      'showEndlessBreakAd': outcome.showEndlessBreakAd,
    };

GameOutcome readOutcome(Object? raw) {
  final map = _map(raw);
  return GameOutcome(
    won: map['won'] as bool,
    word: map['word'] as String,
    definition: map['definition'] as String? ?? '',
    exampleSentence: map['exampleSentence'] as String? ?? '',
    englishTranslation: map['englishTranslation'] as String? ?? '',
    wordId: map['wordId'] as String,
    xpEarned: map['xpEarned'] as int? ?? 0,
    coinEarned: map['coinEarned'] as int? ?? 0,
    leaguePoints: map['leaguePoints'] as int? ?? 0,
    streak: map['streak'] as int? ?? 0,
    level: map['level'] as int? ?? 1,
    guesses: map['guesses'] as int? ?? 0,
    timeSpentSeconds: map['timeSpentSeconds'] as int? ?? 0,
    unlockedAchievements: List<String>.from(map['unlockedAchievements'] as List? ?? const []),
    rankBefore: map['rankBefore'] as int?,
    rankAfter: map['rankAfter'] as int?,
    endlessRun: map['endlessRun'] as int? ?? 0,
    canReviveEndlessWithAd: map['canReviveEndlessWithAd'] as bool? ?? false,
    showEndlessBreakAd: map['showEndlessBreakAd'] as bool? ?? false,
  );
}

Map<String, dynamic> wireSession(GameSessionView view) => {
      'sessionId': view.sessionId,
      'gameType': view.gameType.name,
      'wordLength': view.wordLength,
      'maxAttempts': view.maxAttempts,
      'currentAttempt': view.currentAttempt,
      'guesses': view.guesses.map(wireGuess).toList(),
      'keyboard': {
        for (final e in view.keyboard.entries) e.key: e.value.name,
      },
      'status': view.status.name,
      'hintUsed': view.hintUsed,
      'revealedLetters': {
        for (final e in view.revealedLetters.entries) '${e.key}': e.value,
      },
      'definitionHint': view.definitionHint,
      'startedAt': view.startedAt.toIso8601String(),
      'expiresAt': view.expiresAt.toIso8601String(),
      'outcome': view.outcome == null ? null : wireOutcome(view.outcome!),
      'answer': view.answer,
      'solved': view.solved,
    };

GameSessionView readSession(Object? raw) {
  final map = _map(raw);
  final revealed = <int, String>{};
  final revealedRaw = map['revealedLetters'];
  if (revealedRaw is Map) {
    for (final e in revealedRaw.entries) {
      revealed[_intKey(e.key)] = e.value as String;
    }
  }
  final keyboard = <String, LetterStatus>{};
  final keyboardRaw = map['keyboard'];
  if (keyboardRaw is Map) {
    for (final e in keyboardRaw.entries) {
      keyboard['${e.key}'] = LetterStatus.values.byName(e.value as String);
    }
  }
  return GameSessionView(
    sessionId: map['sessionId'] as String,
    gameType: GameType.values.byName(map['gameType'] as String),
    wordLength: map['wordLength'] as int,
    maxAttempts: map['maxAttempts'] as int,
    currentAttempt: map['currentAttempt'] as int? ?? 0,
    guesses: [
      for (final guess in map['guesses'] as List? ?? const []) readGuess(guess),
    ],
    keyboard: keyboard,
    status: GameStatus.values.byName(map['status'] as String),
    hintUsed: map['hintUsed'] as bool? ?? false,
    revealedLetters: revealed,
    definitionHint: map['definitionHint'] as String?,
    startedAt: DateKeys.playerInstant(DateTime.parse(map['startedAt'] as String)),
    expiresAt: DateKeys.playerInstant(DateTime.parse(map['expiresAt'] as String)),
    outcome: map['outcome'] == null ? null : readOutcome(map['outcome']),
    answer: map['answer'] as String?,
    solved: map['solved'] as bool?,
  );
}

Map<String, dynamic> wireBrief(PeriodStandingBrief brief) => {
      'period': brief.period.name,
      'periodId': brief.periodId,
      'rank': brief.rank,
      'points': brief.points,
    };

PeriodStandingBrief readBrief(Object? raw) {
  final map = _map(raw);
  return PeriodStandingBrief(
    period: RankPeriod.values.byName(map['period'] as String),
    periodId: map['periodId'] as String,
    rank: map['rank'] as int?,
    points: map['points'] as int? ?? 0,
  );
}

Map<String, dynamic> wireHome(HomeSnapshot home) => {
      'user': home.user.toMap(),
      'dailyStatus': home.dailyStatus.name,
      'dailyRewardAvailable': home.dailyRewardAvailable,
      'rewardCycleDay': home.rewardCycleDay,
      'weekId': home.weekId,
      'leagueRank': home.leagueRank,
      'leaguePoints': home.leaguePoints,
      'offline': home.offline,
      'periodStandings': home.periodStandings.map(wireBrief).toList(),
    };

HomeSnapshot readHome(Object? raw) {
  final map = _map(raw);
  return HomeSnapshot(
    user: UserEntity.fromMap(_map(map['user'])),
    dailyStatus: DailyStatus.values.byName(map['dailyStatus'] as String),
    dailyRewardAvailable: map['dailyRewardAvailable'] as bool? ?? false,
    rewardCycleDay: map['rewardCycleDay'] as int? ?? 1,
    weekId: map['weekId'] as String? ?? '',
    leagueRank: map['leagueRank'] as int?,
    leaguePoints: map['leaguePoints'] as int? ?? 0,
    offline: map['offline'] as bool? ?? false,
    periodStandings: [
      for (final item in map['periodStandings'] as List? ?? const []) readBrief(item),
    ],
  );
}

Map<String, dynamic> wireReward(DailyRewardResult reward) => {
      'day': reward.day,
      'coins': reward.coins,
      'hintLevel1': reward.hintLevel1,
      'hintLevel2': reward.hintLevel2,
      'shield': reward.shield,
    };

DailyRewardResult readReward(Object? raw) {
  final map = _map(raw);
  return DailyRewardResult(
    day: map['day'] as int? ?? 1,
    coins: map['coins'] as int? ?? 0,
    hintLevel1: map['hintLevel1'] as int? ?? 0,
    hintLevel2: map['hintLevel2'] as int? ?? 0,
    shield: map['shield'] as int? ?? 0,
  );
}

Map<String, dynamic> wireBoard(LeaderboardEntry entry) => {
      'userId': entry.userId,
      'displayName': entry.displayName,
      'points': entry.points,
      'rank': entry.rank,
      'isCurrentUser': entry.isCurrentUser,
    };

LeaderboardEntry readBoard(Object? raw) {
  final map = _map(raw);
  return LeaderboardEntry(
    userId: map['userId'] as String,
    displayName: map['displayName'] as String? ?? '',
    points: map['points'] as int? ?? 0,
    rank: map['rank'] as int? ?? 0,
    isCurrentUser: map['isCurrentUser'] as bool? ?? false,
  );
}

Map<String, dynamic> wireCompetition(CompetitionSnapshot snap) => {
      'guest': snap.guest,
      'league': snap.league.name,
      'weekId': snap.weekId,
      'monthId': snap.monthId,
      'seasonId': snap.seasonId,
      'yearId': snap.yearId,
      'week': snap.week.map(wireBoard).toList(),
      'month': snap.month.map(wireBoard).toList(),
      'season': snap.season.map(wireBoard).toList(),
      'year': snap.year.map(wireBoard).toList(),
      'weekTitleActive': snap.weekTitleActive,
      'badges': snap.badges,
      'unlockedCosmetics': snap.unlockedCosmetics,
      'equippedTheme': snap.equippedTheme,
      'equippedFrame': snap.equippedFrame,
    };

CompetitionSnapshot readCompetition(Object? raw) {
  final map = _map(raw);
  List<LeaderboardEntry> board(String key) => [
        for (final item in map[key] as List? ?? const []) readBoard(item),
      ];
  return CompetitionSnapshot(
    guest: map['guest'] as bool? ?? false,
    league: LeagueTier.values.byName(map['league'] as String? ?? 'bronze'),
    weekId: map['weekId'] as String? ?? '',
    monthId: map['monthId'] as String? ?? '',
    seasonId: map['seasonId'] as String? ?? '',
    yearId: map['yearId'] as String? ?? '',
    week: board('week'),
    month: board('month'),
    season: board('season'),
    year: board('year'),
    weekTitleActive: map['weekTitleActive'] as bool? ?? false,
    badges: List<String>.from(map['badges'] as List? ?? const []),
    unlockedCosmetics: List<String>.from(map['unlockedCosmetics'] as List? ?? const []),
    equippedTheme: map['equippedTheme'] as String? ?? 'theme_default',
    equippedFrame: map['equippedFrame'] as String? ?? 'frame_default',
  );
}

Map<String, dynamic> wireSaved(SavedWord word) => {
      'id': word.id,
      'word': word.word,
      'definition': word.definition,
      'exampleSentence': word.exampleSentence,
      'englishTranslation': word.englishTranslation,
      'savedAt': word.savedAt.toIso8601String(),
    };

SavedWord readSaved(Object? raw) {
  final map = _map(raw);
  return SavedWord(
    id: map['id'] as String,
    word: map['word'] as String? ?? '',
    definition: map['definition'] as String? ?? '',
    exampleSentence: map['exampleSentence'] as String? ?? '',
    englishTranslation: map['englishTranslation'] as String? ?? '',
    savedAt: DateTime.parse(map['savedAt'] as String),
  );
}

Map<String, dynamic> wireAchievement(AchievementView view) => {
      'id': view.id,
      'name': view.name,
      'description': view.description,
      'icon': view.icon,
      'rewardCoin': view.rewardCoin,
      'unlocked': view.unlocked,
      'unlockedAt': view.unlockedAt?.toIso8601String(),
    };

AchievementView readAchievement(Object? raw) {
  final map = _map(raw);
  return AchievementView(
    id: map['id'] as String,
    name: map['name'] as String? ?? '',
    description: map['description'] as String? ?? '',
    icon: map['icon'] as String? ?? '',
    rewardCoin: map['rewardCoin'] as int? ?? 0,
    unlocked: map['unlocked'] as bool? ?? false,
    unlockedAt: map['unlockedAt'] == null
        ? null
        : DateTime.parse(map['unlockedAt'] as String),
  );
}

Map<String, dynamic> wireOverview(AdminOverview overview) => {
      'registeredCount': overview.registeredCount,
      'guestCount': overview.guestCount,
      'bannedCount': overview.bannedCount,
      'todayDailyCompleted': overview.todayDailyCompleted,
      'todayEndlessCompleted': overview.todayEndlessCompleted,
      'wordPoolByLength': {
        for (final e in overview.wordPoolByLength.entries) '${e.key}': e.value,
      },
      'missingDailyLeagues': overview.missingDailyLeagues.map((e) => e.name).toList(),
      'weekId': overview.weekId,
    };

AdminOverview readOverview(Object? raw) {
  final map = _map(raw);
  final pools = <int, int>{};
  final poolRaw = map['wordPoolByLength'];
  if (poolRaw is Map) {
    for (final e in poolRaw.entries) {
      pools[_intKey(e.key)] = e.value as int;
    }
  }
  return AdminOverview(
    registeredCount: map['registeredCount'] as int? ?? 0,
    guestCount: map['guestCount'] as int? ?? 0,
    bannedCount: map['bannedCount'] as int? ?? 0,
    todayDailyCompleted: map['todayDailyCompleted'] as int? ?? 0,
    todayEndlessCompleted: map['todayEndlessCompleted'] as int? ?? 0,
    wordPoolByLength: pools,
    missingDailyLeagues: [
      for (final name in map['missingDailyLeagues'] as List? ?? const [])
        LeagueTier.values.byName(name as String),
    ],
    weekId: map['weekId'] as String? ?? '',
  );
}

Map<String, dynamic> wireGameRecord(AdminGameRecord record) => {
      'sessionId': record.sessionId,
      'userId': record.userId,
      'displayName': record.displayName,
      'gameType': record.gameType.name,
      'wordId': record.wordId,
      'word': record.word,
      'guesses': record.guesses,
      'won': record.won,
      'timeSpent': record.timeSpent,
      'hintUsed': record.hintUsed,
      'xpEarned': record.xpEarned,
      'coinEarned': record.coinEarned,
      'leaguePoints': record.leaguePoints,
      'createdAt': record.createdAt.toIso8601String(),
      'startedAt': record.startedAt?.toIso8601String(),
      'endedAt': record.endedAt?.toIso8601String(),
      'inProgress': record.inProgress,
      'isGuest': record.isGuest,
      'isSample': record.isSample,
      'gameNo': record.gameNo,
    };

AdminGameRecord readGameRecord(Object? raw) {
  final map = _map(raw);
  return AdminGameRecord(
    sessionId: map['sessionId'] as String,
    userId: map['userId'] as String,
    displayName: map['displayName'] as String? ?? '',
    gameType: GameType.values.byName(map['gameType'] as String),
    wordId: map['wordId'] as String? ?? '',
    word: map['word'] as String? ?? '',
    guesses: map['guesses'] as int? ?? 0,
    won: map['won'] as bool? ?? false,
    timeSpent: map['timeSpent'] as int? ?? 0,
    hintUsed: map['hintUsed'] as bool? ?? false,
    xpEarned: map['xpEarned'] as int? ?? 0,
    coinEarned: map['coinEarned'] as int? ?? 0,
    leaguePoints: map['leaguePoints'] as int? ?? 0,
    createdAt: DateTime.parse(map['createdAt'] as String),
    startedAt: map['startedAt'] == null ? null : DateTime.parse(map['startedAt'] as String),
    endedAt: map['endedAt'] == null ? null : DateTime.parse(map['endedAt'] as String),
    inProgress: map['inProgress'] as bool? ?? false,
    isGuest: map['isGuest'] as bool? ?? false,
    isSample: map['isSample'] as bool? ?? false,
    gameNo: map['gameNo'] as int?,
  );
}

Map<String, dynamic> wireUserDetail(AdminUserDetail detail) => {
      'user': detail.user.toMap(),
      'recentGames': detail.recentGames.map(wireGameRecord).toList(),
    };

AdminUserDetail readUserDetail(Object? raw) {
  final map = _map(raw);
  return AdminUserDetail(
    user: UserEntity.fromMap(_map(map['user'])),
    recentGames: [
      for (final item in map['recentGames'] as List? ?? const []) readGameRecord(item),
    ],
  );
}

Map<String, dynamic> wireSessionDetail(AdminSessionDetail detail) => {
      'session': wireSession(detail.session),
      'userId': detail.userId,
      'displayName': detail.displayName,
      'wordId': detail.wordId,
      'word': detail.word,
    };

AdminSessionDetail readSessionDetail(Object? raw) {
  final map = _map(raw);
  return AdminSessionDetail(
    session: readSession(map['session']),
    userId: map['userId'] as String,
    displayName: map['displayName'] as String? ?? '',
    wordId: map['wordId'] as String? ?? '',
    word: map['word'] as String? ?? '',
  );
}
