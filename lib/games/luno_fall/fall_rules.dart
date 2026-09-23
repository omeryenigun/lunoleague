enum FallDifficulty { easy, normal, hard, legend }

enum FallSpecial { gold, bomb, ice, shield, joker, mirror, time }

enum FallTier { stone, bronze, silver, gold, diamond, legend }

enum FallAdPlace { replay, banner, coins }

class FallDifficultyRule {
  const FallDifficultyRule({
    required this.speed,
    required this.spawnMs,
    required this.wrongRate,
    required this.lives,
    required this.seconds,
    required this.scoreMult,
    required this.waitSeconds,
    required this.minLetters,
    required this.maxLetters,
  });

  final double speed;
  final int spawnMs;
  final double wrongRate;
  final int lives;
  final int seconds;
  final double scoreMult;
  final int waitSeconds;
  final int minLetters;
  final int maxLetters;
}

class FallRules {
  static const difficulty = <FallDifficulty, FallDifficultyRule>{
    FallDifficulty.easy: FallDifficultyRule(
      speed: 0.9,
      spawnMs: 1100,
      wrongRate: 0.20,
      lives: 5,
      seconds: 60,
      scoreMult: 1,
      waitSeconds: 30,
      minLetters: 4,
      maxLetters: 5,
    ),
    FallDifficulty.normal: FallDifficultyRule(
      speed: 1.4,
      spawnMs: 850,
      wrongRate: 0.35,
      lives: 3,
      seconds: 45,
      scoreMult: 1.5,
      waitSeconds: 60,
      minLetters: 5,
      maxLetters: 6,
    ),
    FallDifficulty.hard: FallDifficultyRule(
      speed: 2.2,
      spawnMs: 550,
      wrongRate: 0.50,
      lives: 2,
      seconds: 30,
      scoreMult: 2.5,
      waitSeconds: 60,
      minLetters: 6,
      maxLetters: 8,
    ),
    FallDifficulty.legend: FallDifficultyRule(
      speed: 3.0,
      spawnMs: 400,
      wrongRate: 0.60,
      lives: 1,
      seconds: 25,
      scoreMult: 5,
      waitSeconds: 90,
      minLetters: 8,
      maxLetters: 10,
    ),
  };

  static double comboMultiplier(int combo) {
    if (combo >= 20) return 5;
    if (combo >= 15) return 4;
    if (combo >= 10) return 3;
    if (combo >= 5) return 2;
    if (combo >= 3) return 1.5;
    return 1;
  }

  static String comboName(int combo, String locale) {
    final en = locale == 'en';
    if (combo >= 20) return en ? 'Legend' : 'Efsane';
    if (combo >= 15) return en ? 'Storm' : 'Fırtına';
    if (combo >= 10) return en ? 'Lightning' : 'Şimşek';
    if (combo >= 5) return en ? 'On fire' : 'Alev aldı';
    if (combo >= 3) return en ? 'Warming up' : 'Isınıyor';
    return '';
  }

  static FallTier tierForPoints(int points) {
    if (points >= 15000) return FallTier.legend;
    if (points >= 7000) return FallTier.diamond;
    if (points >= 3500) return FallTier.gold;
    if (points >= 1500) return FallTier.silver;
    if (points >= 500) return FallTier.bronze;
    return FallTier.stone;
  }

  static int tierReward(FallTier tier) => switch (tier) {
        FallTier.stone => 0,
        FallTier.bronze => 50,
        FallTier.silver => 150,
        FallTier.gold => 300,
        FallTier.diamond => 600,
        FallTier.legend => 1500,
      };

  static String tierLabel(FallTier tier, String locale) {
    final en = locale == 'en';
    return switch (tier) {
      FallTier.stone => en ? 'Stone' : 'Taş',
      FallTier.bronze => en ? 'Bronze' : 'Bronz',
      FallTier.silver => en ? 'Silver' : 'Gümüş',
      FallTier.gold => en ? 'Gold' : 'Altın',
      FallTier.diamond => en ? 'Diamond' : 'Elmas',
      FallTier.legend => en ? 'Legend' : 'Efsane',
    };
  }

  /// Best 3 runs, not best 10. Short reflex runs would otherwise reward grinding.
  static int weeklyPoints(List<int> scores) {
    final top = [...scores]..sort((a, b) => b.compareTo(a));
    return top.take(3).fold(0, (sum, score) => sum + score);
  }

  static bool isNight(DateTime now) => now.hour >= 23 || now.hour < 8;

  /// New players wait 30s for the first 3 runs of the day. Premium waits 0.
  static int waitSeconds({
    required FallDifficulty difficulty,
    required int runsToday,
    required bool premium,
  }) {
    if (premium) return 0;
    if (runsToday < 3) return 30;
    return FallRules.difficulty[difficulty]!.waitSeconds;
  }

  static bool bannerAllowed({required DateTime now, required int shownToday}) =>
      !isNight(now) && shownToday < 20;

  static bool coinAdAllowed({required int claimedToday}) => claimedToday < 5;
}

class FallWord {
  const FallWord({
    required this.word,
    required this.clue,
    required this.category,
  });

  final String word;
  final String clue;
  final String category;
}
