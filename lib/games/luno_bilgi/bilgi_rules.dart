class BilgiScore {
  const BilgiScore({
    required this.points,
    required this.timeBonus,
    required this.streakBonus,
  });

  final int points;
  final int timeBonus;
  final int streakBonus;
}

int difficultyPoints(
  String difficulty, {
  int kolay = 10,
  int orta = 15,
  int zor = 25,
  int efsane = 40,
}) {
  return switch (difficulty) {
    'orta' => orta,
    'zor' => zor,
    'efsane' => efsane,
    _ => kolay,
  };
}

int difficultySeconds(String difficulty) {
  return switch (difficulty) {
    'orta' => 15,
    'zor' => 12,
    'efsane' => 10,
    _ => 20,
  };
}

/// Zorluk puanı × katsayı + (kalan / toplam) × 5 + seri × 2 (en fazla 20).
BilgiScore scoreQuestion({
  required String difficulty,
  required double modeMultiplier,
  required int timeLeft,
  required int totalTime,
  required int streak,
  int kolay = 10,
  int orta = 15,
  int zor = 25,
  int efsane = 40,
  int timeBonusScale = 5,
}) {
  final base = (difficultyPoints(difficulty, kolay: kolay, orta: orta, zor: zor, efsane: efsane) * modeMultiplier).round();
  final time = totalTime <= 0
      ? 0
      : ((timeLeft.clamp(0, totalTime) / totalTime) * timeBonusScale).round();
  final streakBonus = (streak * 2).clamp(0, 20);
  return BilgiScore(
    points: base + time + streakBonus,
    timeBonus: time,
    streakBonus: streakBonus,
  );
}

int goldForScore(int totalScore, double modeMultiplier) {
  if (totalScore <= 0) return 0;
  return ((totalScore / 10) * modeMultiplier).floor();
}

int xpForScore(int totalScore) {
  if (totalScore <= 0) return 0;
  return totalScore ~/ 2;
}

class LevelStep {
  const LevelStep({
    required this.level,
    required this.xp,
    required this.diamondsGained,
  });

  final int level;
  final int xp;
  final int diamondsGained;
}

LevelStep applyXp({required int level, required int xp, required int gained}) {
  var nextLevel = level;
  var nextXp = xp + gained;
  var diamonds = 0;
  while (nextXp >= 5000 && nextLevel < 100) {
    nextXp -= 5000;
    nextLevel += 1;
    if (nextLevel % 5 == 0) diamonds += 1;
  }
  if (nextLevel >= 100) {
    nextLevel = 100;
    nextXp = nextXp.clamp(0, 4999);
  }
  return LevelStep(level: nextLevel, xp: nextXp, diamondsGained: diamonds);
}

int regeneratedLives({
  required int lives,
  required DateTime livesAt,
  required DateTime now,
  int maxLives = 5,
  int minutesPerLife = 30,
}) {
  if (lives >= maxLives) return maxLives;
  final gained = now.difference(livesAt).inMinutes ~/ minutesPerLife;
  if (gained <= 0) return lives;
  return (lives + gained).clamp(0, maxLives);
}

DateTime livesClockAfterRegen({
  required int lives,
  required DateTime livesAt,
  required DateTime now,
  int maxLives = 5,
  int minutesPerLife = 30,
}) {
  if (lives >= maxLives) return now;
  final gained = now.difference(livesAt).inMinutes ~/ minutesPerLife;
  if (gained <= 0) return livesAt;
  return livesAt.add(Duration(minutes: gained * minutesPerLife));
}

/// First page after boot. Language comes before intro/home.
String bilgiBootPage({
  required bool maintenance,
  required bool localeChosen,
  required bool seenIntro,
}) {
  if (maintenance) return 'maintenance';
  if (!localeChosen) return 'language';
  if (!seenIntro) return 'intro';
  return 'home';
}
