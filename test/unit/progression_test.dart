import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/domain/entities/app_config.dart';
import 'package:kelimelig/domain/game/progression.dart';

void main() {
  const calc = ProgressionCalculator();
  final config = AppConfig.defaults();

  test('level thresholds from config', () {
    expect(calc.levelForXp(0, config.levelXpThresholds), 1);
    expect(calc.levelForXp(500, config.levelXpThresholds), 2);
    expect(calc.levelForXp(16000, config.levelXpThresholds), 10);
    expect(calc.levelForXp(499, config.levelXpThresholds), 1);
  });

  test('daily xp with and without hint', () {
    expect(
      calc.dailyXp(config: config, won: true, hintUsed: false, perfect: false, streakAfter: 1),
      130,
    );
    expect(
      calc.dailyXp(config: config, won: true, hintUsed: true, perfect: false, streakAfter: 1),
      70,
    );
    expect(
      calc.dailyXp(config: config, won: true, hintUsed: false, perfect: true, streakAfter: 1),
      180,
    );
    expect(
      calc.dailyXp(config: config, won: false, hintUsed: false, perfect: false, streakAfter: 1),
      0,
    );
  });

  test('streak bonus xp', () {
    expect(
      calc.dailyXp(config: config, won: true, hintUsed: true, perfect: false, streakAfter: 5),
      170,
    );
  });

  test('coins', () {
    expect(calc.dailyCoins(config: config, won: true), 25);
    expect(calc.dailyCoins(config: config, won: false), 5);
    expect(calc.endlessCoins(config), 3);
  });

  test('league points', () {
    expect(calc.leaguePoints(guesses: 1, won: true, hintUsed: false), 100);
    expect(calc.leaguePoints(guesses: 3, won: true, hintUsed: false), 80);
    expect(calc.leaguePoints(guesses: 3, won: true, hintUsed: true), 60);
    expect(calc.leaguePoints(guesses: 6, won: false, hintUsed: false), 10);
  });
}
