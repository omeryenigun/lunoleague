import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/data/local/seed_words.dart';
import 'package:kelimelig/games/luno_grid/grid_generator.dart';
import 'package:kelimelig/games/luno_grid/grid_model.dart';
import 'package:kelimelig/games/luno_grid/grid_rules.dart';

void main() {
  test('normal puzzle uses the seed dictionary and a spellable circle', () {
    final words = [for (final word in buildSeedWords()) word.word];
    final puzzle = GridGenerator(random: Random(7)).build(
      dictionary: words,
      difficulty: 'normal',
      palette: 1,
    );
    expect(puzzle, isNotNull);
    final scene = puzzle!;
    expect(scene.active, isFalse);
    expect(scene.palette, 1);
    expect(scene.type, GridSceneTypes.cross5.id);
    expect(scene.words, hasLength(GridSceneTypes.cross5.wordCount));
    expect(scene.circle.length, lessThanOrEqualTo(GridSceneTypes.cross5.maxCircle));
    expect(_sorted(scene.circle), _sorted(GridGenerator().circleOf(scene.words)));
    for (final slot in scene.words) {
      expect(GridRules.canSpell(TurkishText.toUpper(slot.word), scene.circle), isTrue);
      expect(TurkishText.letterCount(slot.word), inInclusiveRange(3, 7));
    }
    expect(scene.cells, isNotEmpty);
    expect(scene.given, isNotEmpty);
  });

  test('repair keeps saved scenes inside seven letters', () {
    final puzzle = GridPuzzle(
      id: 'old',
      difficulty: 'normal',
      palette: 2,
      active: true,
      words: const [
        GridWord(word: 'KALEM', x: 0, y: 0, across: true),
        GridWord(word: 'MOTOR', x: 0, y: 1, across: true),
      ],
      circle: const ['K', 'A', 'L', 'E', 'M', 'O', 'T', 'R', 'Z'],
      given: const ['0,0', '0,1'],
      createdAt: DateTime.utc(2026, 9, 26),
    );
    final words = [for (final word in buildSeedWords()) word.word];
    final fixed = GridGenerator(random: Random(3)).repair(puzzle, dictionary: words);
    expect(fixed, isNotNull);
    expect(fixed!.id, 'old');
    expect(fixed.active, isTrue);
    expect(fixed.palette, 2);
    expect(fixed.type, GridSceneTypes.cross5.id);
    expect(fixed.words, hasLength(5));
    expect(fixed.circle.length, lessThanOrEqualTo(GridSceneTypes.cross5.maxCircle));
  });
}

List<String> _sorted(List<String> letters) => [...letters]..sort();
