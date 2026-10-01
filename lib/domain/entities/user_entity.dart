import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/entities/cosmetics.dart';

class LocaleProgress {
  const LocaleProgress({
    this.league = LeagueTier.bronze,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.totalGuessesOnWins = 0,
    this.fastestSolveSeconds,
    this.firstGuessWins = 0,
    this.wordsLearned = 0,
    this.leagueWins = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.endlessBest = 0,
    this.consecutiveTop20 = 0,
    this.consecutiveBottom20 = 0,
    this.lastPlayedWeek,
  });

  final LeagueTier league;
  final int gamesPlayed;
  final int gamesWon;
  final int totalGuessesOnWins;
  final int? fastestSolveSeconds;
  final int firstGuessWins;
  final int wordsLearned;
  final int leagueWins;
  final int streak;
  final int longestStreak;
  final int endlessBest;
  final int consecutiveTop20;
  final int consecutiveBottom20;
  final String? lastPlayedWeek;

  factory LocaleProgress.fromUser(UserEntity user) {
    return LocaleProgress(
      league: user.currentLeague,
      gamesPlayed: user.gamesPlayed,
      gamesWon: user.gamesWon,
      totalGuessesOnWins: user.totalGuessesOnWins,
      fastestSolveSeconds: user.fastestSolveSeconds,
      firstGuessWins: user.firstGuessWins,
      wordsLearned: user.wordsLearned,
      leagueWins: user.leagueWins,
      streak: user.streak,
      longestStreak: user.longestStreak,
      endlessBest: user.endlessBest,
      consecutiveTop20: user.consecutiveTop20,
      consecutiveBottom20: user.consecutiveBottom20,
      lastPlayedWeek: user.lastPlayedWeek,
    );
  }

  factory LocaleProgress.fromMap(Map<dynamic, dynamic> map) {
    return LocaleProgress(
      league: LeagueTier.values.byName(map['league'] as String? ?? 'bronze'),
      gamesPlayed: map['gamesPlayed'] as int? ?? 0,
      gamesWon: map['gamesWon'] as int? ?? 0,
      totalGuessesOnWins: map['totalGuessesOnWins'] as int? ?? 0,
      fastestSolveSeconds: map['fastestSolveSeconds'] as int?,
      firstGuessWins: map['firstGuessWins'] as int? ?? 0,
      wordsLearned: map['wordsLearned'] as int? ?? 0,
      leagueWins: map['leagueWins'] as int? ?? 0,
      streak: map['streak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      endlessBest: map['endlessBest'] as int? ?? 0,
      consecutiveTop20: map['consecutiveTop20'] as int? ?? 0,
      consecutiveBottom20: map['consecutiveBottom20'] as int? ?? 0,
      lastPlayedWeek: map['lastPlayedWeek'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'league': league.name,
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'totalGuessesOnWins': totalGuessesOnWins,
        'fastestSolveSeconds': fastestSolveSeconds,
        'firstGuessWins': firstGuessWins,
        'wordsLearned': wordsLearned,
        'leagueWins': leagueWins,
        'streak': streak,
        'longestStreak': longestStreak,
        'endlessBest': endlessBest,
        'consecutiveTop20': consecutiveTop20,
        'consecutiveBottom20': consecutiveBottom20,
        'lastPlayedWeek': lastPlayedWeek,
      };

  UserEntity applyTo(UserEntity user, String localeId) {
    return user.copyWith(
      locale: localeId,
      currentLeague: league,
      gamesPlayed: gamesPlayed,
      gamesWon: gamesWon,
      totalGuessesOnWins: totalGuessesOnWins,
      fastestSolveSeconds: fastestSolveSeconds,
      clearFastest: fastestSolveSeconds == null,
      firstGuessWins: firstGuessWins,
      wordsLearned: wordsLearned,
      leagueWins: leagueWins,
      streak: streak,
      longestStreak: longestStreak,
      endlessBest: endlessBest,
      consecutiveTop20: consecutiveTop20,
      consecutiveBottom20: consecutiveBottom20,
      lastPlayedWeek: lastPlayedWeek,
      clearLastPlayedWeek: lastPlayedWeek == null,
    );
  }
}

class UserEntity {
  const UserEntity({
    required this.id,
    required this.displayName,
    this.email,
    required this.authProvider,
    required this.isAnonymous,
    required this.level,
    required this.xp,
    required this.coin,
    required this.currentLeague,
    required this.streak,
    required this.longestStreak,
    required this.endlessBest,
    required this.shields,
    required this.freeHint1,
    required this.freeHint2,
    required this.isBanned,
    this.banReason,
    required this.createdAt,
    required this.lastLoginAt,
    this.lastDailyDate,
    this.lastRewardDate,
    this.rewardCycleDay = 1,
    this.onboardingDone = false,
    this.consecutiveTop20 = 0,
    this.consecutiveBottom20 = 0,
    this.gamesPlayed = 0,
    this.gamesWon = 0,
    this.totalGuessesOnWins = 0,
    this.fastestSolveSeconds,
    this.firstGuessWins = 0,
    this.wordsLearned = 0,
    this.leagueWins = 0,
    this.lastPlayedWeek,
    this.soundOn = true,
    this.hapticOn = true,
    this.animationsOn = true,
    this.notificationsOn = true,
    this.leagueShields = 0,
    this.equippedTheme = Cosmetics.themeDefault,
    this.equippedFrame = Cosmetics.frameDefault,
    this.unlockedCosmetics = Cosmetics.defaults,
    this.badges = const [],
    this.weekTitleUntil,
    this.lastSettledWeek,
    this.lastSettledMonth,
    this.lastSettledSeason,
    this.lastSettledYear,
    this.locale = 'tr',
    this.lastDailyByLocale = const {},
    this.leagueByLocale = const {},
    this.progressByLocale = const {},
    this.avatar,
    this.firstName,
    this.lastName,
    this.accountId,
    this.accountFirstGame,
    this.accountGames = const [],
    this.accountCreatedAt,
    this.guestHere = false,
  });

  final String id;
  final String displayName;
  final String? email;
  final AuthProvider authProvider;
  final bool isAnonymous;
  final int level;
  final int xp;
  final int coin;
  final LeagueTier currentLeague;
  final int streak;
  final int longestStreak;
  final int endlessBest;
  final int shields;
  final int freeHint1;
  final int freeHint2;
  final bool isBanned;
  final String? banReason;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final String? lastDailyDate;
  final String? lastRewardDate;
  final int rewardCycleDay;
  final bool onboardingDone;
  final int consecutiveTop20;
  final int consecutiveBottom20;
  final int gamesPlayed;
  final int gamesWon;
  final int totalGuessesOnWins;
  final int? fastestSolveSeconds;
  final int firstGuessWins;
  final int wordsLearned;
  final int leagueWins;
  final String? lastPlayedWeek;
  final bool soundOn;
  final bool hapticOn;
  final bool animationsOn;
  final bool notificationsOn;
  final int leagueShields;
  final String equippedTheme;
  final String equippedFrame;
  final List<String> unlockedCosmetics;
  final List<String> badges;
  final DateTime? weekTitleUntil;
  final String? lastSettledWeek;
  final String? lastSettledMonth;
  final String? lastSettledSeason;
  final String? lastSettledYear;
  final String locale;
  final Map<String, String> lastDailyByLocale;
  final Map<String, String> leagueByLocale;
  final Map<String, LocaleProgress> progressByLocale;
  final String? avatar;
  final String? firstName;
  final String? lastName;
  final String? accountId;
  final String? accountFirstGame;
  final List<String> accountGames;
  final DateTime? accountCreatedAt;
  final bool guestHere;

  UserEntity stampCurrentLocale() {
    final map = Map<String, LocaleProgress>.from(progressByLocale);
    map[locale] = LocaleProgress.fromUser(this);
    return copyWith(
      progressByLocale: map,
      leagueByLocale: {
        for (final entry in map.entries) entry.key: entry.value.league.name,
      },
    );
  }

  UserEntity switchToLocale(String localeId) {
    final stamped = stampCurrentLocale();
    if (stamped.locale == localeId) return stamped;
    final next = stamped.progressByLocale[localeId] ?? const LocaleProgress();
    return next.applyTo(stamped, localeId);
  }

  bool playedDailyOn(String day, {String? language}) {
    final lang = language ?? locale;
    return lastDailyFor(lang) == day;
  }

  /// Per-locale last daily completion day. Legacy `lastDailyDate` only
  /// applies to TR when no locale map entries exist yet (pre-migration users).
  String? lastDailyFor(String language) {
    final byLocale = lastDailyByLocale[language];
    if (byLocale != null) return byLocale;
    if (language == 'tr' &&
        lastDailyByLocale.isEmpty &&
        lastDailyDate != null) {
      return lastDailyDate;
    }
    return null;
  }

  bool get hasWeekTitle =>
      weekTitleUntil != null && weekTitleUntil!.isAfter(DateTime.now());

  bool get canPlayDaily => !isBanned;
  bool get canJoinLeague => !isBanned;

  double get winRate =>
      gamesPlayed == 0 ? 0 : gamesWon / gamesPlayed;

  double get averageGuesses =>
      gamesWon == 0 ? 0 : totalGuessesOnWins / gamesWon;

  UserEntity copyWith({
    String? displayName,
    String? email,
    bool clearEmail = false,
    AuthProvider? authProvider,
    bool? isAnonymous,
    int? level,
    int? xp,
    int? coin,
    LeagueTier? currentLeague,
    int? streak,
    int? longestStreak,
    int? endlessBest,
    int? shields,
    int? freeHint1,
    int? freeHint2,
    bool? isBanned,
    String? banReason,
    bool clearBanReason = false,
    DateTime? lastLoginAt,
    String? lastDailyDate,
    String? lastRewardDate,
    int? rewardCycleDay,
    bool? onboardingDone,
    int? consecutiveTop20,
    int? consecutiveBottom20,
    int? gamesPlayed,
    int? gamesWon,
    int? totalGuessesOnWins,
    int? fastestSolveSeconds,
    int? firstGuessWins,
    int? wordsLearned,
    int? leagueWins,
    String? lastPlayedWeek,
    bool? soundOn,
    bool? hapticOn,
    bool? animationsOn,
    bool? notificationsOn,
    bool clearLastDaily = false,
    int? leagueShields,
    String? equippedTheme,
    String? equippedFrame,
    List<String>? unlockedCosmetics,
    List<String>? badges,
    DateTime? weekTitleUntil,
    bool clearWeekTitle = false,
    String? lastSettledWeek,
    String? lastSettledMonth,
    String? lastSettledSeason,
    String? lastSettledYear,
    String? locale,
    Map<String, String>? lastDailyByLocale,
    Map<String, String>? leagueByLocale,
    Map<String, LocaleProgress>? progressByLocale,
    bool clearFastest = false,
    bool clearLastPlayedWeek = false,
    String? avatar,
    String? firstName,
    bool clearFirstName = false,
    String? lastName,
    bool clearLastName = false,
    String? accountId,
    String? accountFirstGame,
    List<String>? accountGames,
    DateTime? accountCreatedAt,
    bool? guestHere,
  }) {
    return UserEntity(
      id: id,
      displayName: displayName ?? this.displayName,
      email: clearEmail ? null : (email ?? this.email),
      authProvider: authProvider ?? this.authProvider,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      coin: coin ?? this.coin,
      currentLeague: currentLeague ?? this.currentLeague,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      endlessBest: endlessBest ?? this.endlessBest,
      shields: shields ?? this.shields,
      freeHint1: freeHint1 ?? this.freeHint1,
      freeHint2: freeHint2 ?? this.freeHint2,
      isBanned: isBanned ?? this.isBanned,
      banReason: clearBanReason ? null : (banReason ?? this.banReason),
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      lastDailyDate: clearLastDaily ? lastDailyDate : (lastDailyDate ?? this.lastDailyDate),
      lastRewardDate: lastRewardDate ?? this.lastRewardDate,
      rewardCycleDay: rewardCycleDay ?? this.rewardCycleDay,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      consecutiveTop20: consecutiveTop20 ?? this.consecutiveTop20,
      consecutiveBottom20: consecutiveBottom20 ?? this.consecutiveBottom20,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      gamesWon: gamesWon ?? this.gamesWon,
      totalGuessesOnWins: totalGuessesOnWins ?? this.totalGuessesOnWins,
      fastestSolveSeconds: clearFastest
          ? fastestSolveSeconds
          : (fastestSolveSeconds ?? this.fastestSolveSeconds),
      firstGuessWins: firstGuessWins ?? this.firstGuessWins,
      wordsLearned: wordsLearned ?? this.wordsLearned,
      leagueWins: leagueWins ?? this.leagueWins,
      lastPlayedWeek: clearLastPlayedWeek
          ? lastPlayedWeek
          : (lastPlayedWeek ?? this.lastPlayedWeek),
      soundOn: soundOn ?? this.soundOn,
      hapticOn: hapticOn ?? this.hapticOn,
      animationsOn: animationsOn ?? this.animationsOn,
      notificationsOn: notificationsOn ?? this.notificationsOn,
      leagueShields: leagueShields ?? this.leagueShields,
      equippedTheme: equippedTheme ?? this.equippedTheme,
      equippedFrame: equippedFrame ?? this.equippedFrame,
      unlockedCosmetics: unlockedCosmetics ?? this.unlockedCosmetics,
      badges: badges ?? this.badges,
      weekTitleUntil: clearWeekTitle ? null : (weekTitleUntil ?? this.weekTitleUntil),
      lastSettledWeek: lastSettledWeek ?? this.lastSettledWeek,
      lastSettledMonth: lastSettledMonth ?? this.lastSettledMonth,
      lastSettledSeason: lastSettledSeason ?? this.lastSettledSeason,
      lastSettledYear: lastSettledYear ?? this.lastSettledYear,
      locale: locale ?? this.locale,
      lastDailyByLocale: lastDailyByLocale ?? this.lastDailyByLocale,
      leagueByLocale: leagueByLocale ?? this.leagueByLocale,
      progressByLocale: progressByLocale ?? this.progressByLocale,
      avatar: avatar ?? this.avatar,
      firstName: clearFirstName ? null : (firstName ?? this.firstName),
      lastName: clearLastName ? null : (lastName ?? this.lastName),
      accountId: accountId ?? this.accountId,
      accountFirstGame: accountFirstGame ?? this.accountFirstGame,
      accountGames: accountGames ?? this.accountGames,
      accountCreatedAt: accountCreatedAt ?? this.accountCreatedAt,
      guestHere: guestHere ?? this.guestHere,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'authProvider': authProvider.name,
        'isAnonymous': isAnonymous,
        'level': level,
        'xp': xp,
        'coin': coin,
        'currentLeague': currentLeague.name,
        'streak': streak,
        'longestStreak': longestStreak,
        'endlessBest': endlessBest,
        'shields': shields,
        'freeHint1': freeHint1,
        'freeHint2': freeHint2,
        'isBanned': isBanned,
        'banReason': banReason,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt.toIso8601String(),
        'lastDailyDate': lastDailyDate,
        'lastRewardDate': lastRewardDate,
        'rewardCycleDay': rewardCycleDay,
        'onboardingDone': onboardingDone,
        'consecutiveTop20': consecutiveTop20,
        'consecutiveBottom20': consecutiveBottom20,
        'gamesPlayed': gamesPlayed,
        'gamesWon': gamesWon,
        'totalGuessesOnWins': totalGuessesOnWins,
        'fastestSolveSeconds': fastestSolveSeconds,
        'firstGuessWins': firstGuessWins,
        'wordsLearned': wordsLearned,
        'leagueWins': leagueWins,
        'lastPlayedWeek': lastPlayedWeek,
        'soundOn': soundOn,
        'hapticOn': hapticOn,
        'animationsOn': animationsOn,
        'notificationsOn': notificationsOn,
        'leagueShields': leagueShields,
        'equippedTheme': equippedTheme,
        'equippedFrame': equippedFrame,
        'unlockedCosmetics': unlockedCosmetics,
        'badges': badges,
        'weekTitleUntil': weekTitleUntil?.toIso8601String(),
        'lastSettledWeek': lastSettledWeek,
        'lastSettledMonth': lastSettledMonth,
        'lastSettledSeason': lastSettledSeason,
        'lastSettledYear': lastSettledYear,
        'locale': locale,
        'lastDailyByLocale': lastDailyByLocale,
        'leagueByLocale': leagueByLocale,
        'progressByLocale': {
          for (final e in progressByLocale.entries) e.key: e.value.toMap(),
        },
        'avatar': avatar,
        'firstName': firstName,
        'lastName': lastName,
        'accountId': accountId,
        'accountFirstGame': accountFirstGame,
        'accountGames': accountGames,
        'accountCreatedAt': accountCreatedAt?.toIso8601String(),
        'guestHere': guestHere,
      };

  factory UserEntity.fromMap(Map<dynamic, dynamic> map) {
    return UserEntity(
      id: map['id'] as String,
      displayName: map['displayName'] as String? ?? 'Oyuncu',
      email: map['email'] as String?,
      authProvider: AuthProvider.values.byName(
        map['authProvider'] as String? ?? 'anonymous',
      ),
      isAnonymous: map['isAnonymous'] as bool? ?? true,
      level: map['level'] as int? ?? 1,
      xp: map['xp'] as int? ?? 0,
      coin: map['coin'] as int? ?? 0,
      currentLeague: LeagueTier.values.byName(
        map['currentLeague'] as String? ?? 'bronze',
      ),
      streak: map['streak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      endlessBest: map['endlessBest'] as int? ?? 0,
      shields: map['shields'] as int? ?? 0,
      freeHint1: map['freeHint1'] as int? ?? 0,
      freeHint2: map['freeHint2'] as int? ?? 0,
      isBanned: map['isBanned'] as bool? ?? false,
      banReason: map['banReason'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      lastLoginAt: DateTime.parse(map['lastLoginAt'] as String),
      lastDailyDate: map['lastDailyDate'] as String?,
      lastRewardDate: map['lastRewardDate'] as String?,
      rewardCycleDay: map['rewardCycleDay'] as int? ?? 1,
      onboardingDone: map['onboardingDone'] as bool? ?? false,
      consecutiveTop20: map['consecutiveTop20'] as int? ?? 0,
      consecutiveBottom20: map['consecutiveBottom20'] as int? ?? 0,
      gamesPlayed: map['gamesPlayed'] as int? ?? 0,
      gamesWon: map['gamesWon'] as int? ?? 0,
      totalGuessesOnWins: map['totalGuessesOnWins'] as int? ?? 0,
      fastestSolveSeconds: map['fastestSolveSeconds'] as int?,
      firstGuessWins: map['firstGuessWins'] as int? ?? 0,
      wordsLearned: map['wordsLearned'] as int? ?? 0,
      leagueWins: map['leagueWins'] as int? ?? 0,
      lastPlayedWeek: map['lastPlayedWeek'] as String?,
      soundOn: map['soundOn'] as bool? ?? true,
      hapticOn: map['hapticOn'] as bool? ?? true,
      animationsOn: map['animationsOn'] as bool? ?? true,
      notificationsOn: map['notificationsOn'] as bool? ?? true,
      leagueShields: map['leagueShields'] as int? ?? 0,
      equippedTheme: map['equippedTheme'] as String? ?? Cosmetics.themeDefault,
      equippedFrame: map['equippedFrame'] as String? ?? Cosmetics.frameDefault,
      unlockedCosmetics: List<String>.from(
        map['unlockedCosmetics'] as List? ?? Cosmetics.defaults,
      ),
      badges: List<String>.from(map['badges'] as List? ?? const []),
      weekTitleUntil: map['weekTitleUntil'] == null
          ? null
          : DateTime.tryParse(map['weekTitleUntil'] as String),
      lastSettledWeek: map['lastSettledWeek'] as String?,
      lastSettledMonth: map['lastSettledMonth'] as String?,
      lastSettledSeason: map['lastSettledSeason'] as String?,
      lastSettledYear: map['lastSettledYear'] as String?,
      locale: map['locale'] as String? ?? 'tr',
      lastDailyByLocale: _stringMap(map['lastDailyByLocale']),
      leagueByLocale: _stringMap(map['leagueByLocale']),
      progressByLocale: _progressMap(map['progressByLocale'], map['leagueByLocale']),
      avatar: map['avatar'] as String?,
      firstName: map['firstName'] as String?,
      lastName: map['lastName'] as String?,
      accountId: map['accountId'] as String?,
      accountCreatedAt: DateTime.tryParse('${map['accountCreatedAt'] ?? ''}'),
      accountFirstGame: map['accountFirstGame'] as String?,
      accountGames: [
        for (final item in map['accountGames'] as List? ?? const [])
          if ('$item'.isNotEmpty) '$item',
      ],
      guestHere: map['guestHere'] as bool? ?? false,
    );
  }
}

Map<String, String> _stringMap(Object? raw) {
  if (raw is Map) {
    return {
      for (final e in raw.entries) e.key.toString(): e.value.toString(),
    };
  }
  return const {};
}

Map<String, LocaleProgress> _progressMap(Object? raw, Object? leagues) {
  if (raw is Map && raw.isNotEmpty) {
    return {
      for (final e in raw.entries)
        if (e.value is Map)
          e.key.toString(): LocaleProgress.fromMap(
            Map<dynamic, dynamic>.from(e.value as Map),
          ),
    };
  }
  final leagueMap = _stringMap(leagues);
  if (leagueMap.isEmpty) return const {};
  return {
    for (final e in leagueMap.entries)
      e.key: LocaleProgress(league: LeagueTier.values.byName(e.value)),
  };
}
