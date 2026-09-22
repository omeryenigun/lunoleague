import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/entities/app_config.dart';

class ProgressionCalculator {
  const ProgressionCalculator();

  int levelForXp(int xp, List<int> thresholds) {
    var level = 1;
    for (var i = 0; i < thresholds.length; i++) {
      if (xp >= thresholds[i]) {
        level = i + 1;
      }
    }
    return level;
  }

  int xpToNextLevel(int xp, List<int> thresholds) {
    final level = levelForXp(xp, thresholds);
    if (level >= thresholds.length) return 0;
    return thresholds[level] - xp;
  }

  int dailyXp({
    required AppConfig config,
    required bool won,
    required bool hintUsed,
    required bool perfect,
    required int streakAfter,
  }) {
    if (!won) return 0;
    var xp = hintUsed ? config.dailyWinXpWithHint : config.dailyWinXp;
    if (perfect) xp += config.perfectBonusXp;
    if (!hintUsed) xp += config.noHintBonusXp;
    xp += config.streakBonusXp[streakAfter] ?? 0;
    return xp;
  }

  int dailyCoins({required AppConfig config, required bool won}) {
    return won ? config.dailyWinCoins : config.dailyLoseCoins;
  }

  int endlessXp(AppConfig config) => config.endlessXp;
  int endlessCoins(AppConfig config) => config.endlessCoins;

  int leaguePoints({
    required int guesses,
    required bool won,
    required bool hintUsed,
  }) {
    if (!won) return 10;
    final base = (110 - (10 * guesses)).clamp(30, 100);
    return hintUsed ? (base - 20).clamp(0, 100) : base;
  }

  int hintCost(AppConfig config, HintLevel level) => switch (level) {
        HintLevel.letter => config.hint1Cost,
        HintLevel.meaning => config.hint2Cost,
      };
}
