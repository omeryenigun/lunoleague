class AppConfig {
  const AppConfig({
    required this.levelXpThresholds,
    required this.dailyWinXp,
    required this.dailyWinXpWithHint,
    required this.perfectBonusXp,
    required this.noHintBonusXp,
    required this.endlessXp,
    required this.endlessCoins,
    required this.dailyWinCoins,
    required this.dailyLoseCoins,
    required this.hint1Cost,
    required this.hint2Cost,
    required this.adCoinReward,
    required this.streakBonusXp,
    required this.dailyRewardCycle,
  });

  final List<int> levelXpThresholds;
  final int dailyWinXp;
  final int dailyWinXpWithHint;
  final int perfectBonusXp;
  final int noHintBonusXp;
  final int endlessXp;
  final int endlessCoins;
  final int dailyWinCoins;
  final int dailyLoseCoins;
  final int hint1Cost;
  final int hint2Cost;
  final int adCoinReward;
  final Map<int, int> streakBonusXp;
  final List<DailyRewardSpec> dailyRewardCycle;

  factory AppConfig.defaults() => AppConfig(
        levelXpThresholds: const [
          0,
          500,
          1200,
          2000,
          3000,
          4500,
          6500,
          9000,
          12000,
          16000,
        ],
        dailyWinXp: 100,
        dailyWinXpWithHint: 70,
        perfectBonusXp: 50,
        noHintBonusXp: 30,
        endlessXp: 5,
        endlessCoins: 3,
        dailyWinCoins: 25,
        dailyLoseCoins: 5,
        hint1Cost: 10,
        hint2Cost: 15,
        adCoinReward: 5,
        streakBonusXp: const {
          5: 100,
          7: 250,
          14: 500,
          30: 1500,
        },
        dailyRewardCycle: const [
          DailyRewardSpec(day: 1, coins: 10),
          DailyRewardSpec(day: 2, coins: 10),
          DailyRewardSpec(day: 3, hintLevel1: 1),
          DailyRewardSpec(day: 4, coins: 15),
          DailyRewardSpec(day: 5, coins: 20),
          DailyRewardSpec(day: 6, hintLevel2: 1),
          DailyRewardSpec(day: 7, coins: 25, shield: 1),
        ],
      );

  Map<String, dynamic> toMap() => {
        'levelXpThresholds': levelXpThresholds,
        'dailyWinXp': dailyWinXp,
        'dailyWinXpWithHint': dailyWinXpWithHint,
        'perfectBonusXp': perfectBonusXp,
        'noHintBonusXp': noHintBonusXp,
        'endlessXp': endlessXp,
        'endlessCoins': endlessCoins,
        'dailyWinCoins': dailyWinCoins,
        'dailyLoseCoins': dailyLoseCoins,
        'hint1Cost': hint1Cost,
        'hint2Cost': hint2Cost,
        'adCoinReward': adCoinReward,
        'streakBonusXp': {
          for (final e in streakBonusXp.entries) '${e.key}': e.value,
        },
        'dailyRewardCycle': dailyRewardCycle.map((e) => e.toMap()).toList(),
      };

  factory AppConfig.fromMap(Map<dynamic, dynamic> map) {
    final streakRaw = Map<String, dynamic>.from(
      map['streakBonusXp'] as Map? ?? const {},
    );
    return AppConfig(
      levelXpThresholds: List<int>.from(
        map['levelXpThresholds'] as List? ?? AppConfig.defaults().levelXpThresholds,
      ),
      dailyWinXp: map['dailyWinXp'] as int? ?? 100,
      dailyWinXpWithHint: map['dailyWinXpWithHint'] as int? ?? 70,
      perfectBonusXp: map['perfectBonusXp'] as int? ?? 50,
      noHintBonusXp: map['noHintBonusXp'] as int? ?? 30,
      endlessXp: map['endlessXp'] as int? ?? 5,
      endlessCoins: map['endlessCoins'] as int? ?? 3,
      dailyWinCoins: map['dailyWinCoins'] as int? ?? 25,
      dailyLoseCoins: map['dailyLoseCoins'] as int? ?? 5,
      hint1Cost: map['hint1Cost'] as int? ?? 10,
      hint2Cost: map['hint2Cost'] as int? ?? 15,
      adCoinReward: map['adCoinReward'] as int? ?? 5,
      streakBonusXp: {
        for (final e in streakRaw.entries) int.parse(e.key): e.value as int,
      },
      dailyRewardCycle: (map['dailyRewardCycle'] as List? ?? const [])
          .map((e) => DailyRewardSpec.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  AppConfig copyWith({
    List<int>? levelXpThresholds,
    int? dailyWinXp,
    int? dailyWinXpWithHint,
    int? perfectBonusXp,
    int? noHintBonusXp,
    int? endlessXp,
    int? endlessCoins,
    int? dailyWinCoins,
    int? dailyLoseCoins,
    int? hint1Cost,
    int? hint2Cost,
    int? adCoinReward,
    Map<int, int>? streakBonusXp,
  }) {
    return AppConfig(
      levelXpThresholds: levelXpThresholds ?? this.levelXpThresholds,
      dailyWinXp: dailyWinXp ?? this.dailyWinXp,
      dailyWinXpWithHint: dailyWinXpWithHint ?? this.dailyWinXpWithHint,
      perfectBonusXp: perfectBonusXp ?? this.perfectBonusXp,
      noHintBonusXp: noHintBonusXp ?? this.noHintBonusXp,
      endlessXp: endlessXp ?? this.endlessXp,
      endlessCoins: endlessCoins ?? this.endlessCoins,
      dailyWinCoins: dailyWinCoins ?? this.dailyWinCoins,
      dailyLoseCoins: dailyLoseCoins ?? this.dailyLoseCoins,
      hint1Cost: hint1Cost ?? this.hint1Cost,
      hint2Cost: hint2Cost ?? this.hint2Cost,
      adCoinReward: adCoinReward ?? this.adCoinReward,
      streakBonusXp: streakBonusXp ?? this.streakBonusXp,
      dailyRewardCycle: dailyRewardCycle,
    );
  }
}

class DailyRewardSpec {
  const DailyRewardSpec({
    required this.day,
    this.coins = 0,
    this.hintLevel1 = 0,
    this.hintLevel2 = 0,
    this.shield = 0,
  });

  final int day;
  final int coins;
  final int hintLevel1;
  final int hintLevel2;
  final int shield;

  Map<String, dynamic> toMap() => {
        'day': day,
        'coins': coins,
        'hintLevel1': hintLevel1,
        'hintLevel2': hintLevel2,
        'shield': shield,
      };

  factory DailyRewardSpec.fromMap(Map<String, dynamic> map) => DailyRewardSpec(
        day: map['day'] as int,
        coins: map['coins'] as int? ?? 0,
        hintLevel1: map['hintLevel1'] as int? ?? 0,
        hintLevel2: map['hintLevel2'] as int? ?? 0,
        shield: map['shield'] as int? ?? 0,
      );
}
