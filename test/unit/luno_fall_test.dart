import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/games/luno_fall/fall_rules.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';

void main() {
  test('wait is shorter for the first runs and zero for premium', () {
    expect(
      FallRules.waitSeconds(
        difficulty: FallDifficulty.legend,
        runsToday: 1,
        premium: false,
      ),
      30,
    );
    expect(
      FallRules.waitSeconds(
        difficulty: FallDifficulty.legend,
        runsToday: 4,
        premium: false,
      ),
      90,
    );
    expect(
      FallRules.waitSeconds(
        difficulty: FallDifficulty.legend,
        runsToday: 9,
        premium: true,
      ),
      0,
    );
  });

  test('banner hides at night and after the daily cap', () {
    expect(
      FallRules.bannerAllowed(now: DateTime(2026, 9, 23, 1), shownToday: 0),
      isFalse,
    );
    expect(
      FallRules.bannerAllowed(now: DateTime(2026, 9, 23, 12), shownToday: 20),
      isFalse,
    );
    expect(
      FallRules.bannerAllowed(now: DateTime(2026, 9, 23, 12), shownToday: 3),
      isTrue,
    );
    expect(FallRules.weeklyPoints([10, 40, 5, 30]), 80);
  });

  test('fall coins stay out of the league store', () async {
    final root = MemoryKeyValueStore();
    final league = LocalGameServer(ScopedKeyValueStore(root, 'luno_league'));
    final fall = LunoFallServer(ScopedKeyValueStore(root, 'luno_fall'));
    await league.initialize();
    await fall.initialize();
    await fall.finishRun(
      difficulty: FallDifficulty.easy,
      score: 120,
      words: 2,
      maxCombo: 5,
    );
    final fallProfile = await fall.profile();
    expect(fallProfile.coins, greaterThan(100));
    expect(await root.get('luno_league__profiles', 'tr'), isNull);
    expect(await root.get('luno_fall__profiles', 'tr'), isNotNull);
    await fall.setLocale('en');
    final english = await fall.profile();
    expect(english.coins, 100);
    expect(english.locale, 'en');
  });
}
