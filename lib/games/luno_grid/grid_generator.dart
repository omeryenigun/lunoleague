import 'dart:math';

import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/games/luno_grid/grid_model.dart';

class GridGenerator {
  GridGenerator({Random? random, DateTime Function()? clock})
      : _random = random ?? Random(),
        _clock = clock ?? DateTime.now;

  final Random _random;
  final DateTime Function() _clock;

  GridPuzzle? build({
    required List<String> dictionary,
    required String difficulty,
    String sceneType = GridSceneTypes.cross5Id,
    bool active = false,
    int? palette,
    String? id,
    DateTime? createdAt,
  }) {
    final type = GridSceneTypes.byId(sceneType);
    final words = _prepare(dictionary);
    if (words.length < type.wordCount) return null;
    final lengths = _lengths(difficulty, words);
    final seeds = words.where((word) => lengths.contains(TurkishText.letterCount(word))).toList();
    if (seeds.isEmpty) return null;
    seeds.shuffle(_random);
    for (final seed in seeds) {
      if (TurkishText.letterCount(seed) > type.maxCircle) continue;
      final chosen = _pickWords(words, seed, type.wordCount, type.maxCircle);
      if (chosen == null) continue;
      final byLetter = <String, List<String>>{};
      for (final word in chosen) {
        for (final letter in TurkishText.letters(word).toSet()) {
          byLetter.putIfAbsent(letter, () => []).add(word);
        }
      }
      final placed = _grow(seed, byLetter, type.wordCount, type.maxCircle);
      if (placed.length != type.wordCount) continue;
      final shifted = _shift(placed);
      final circle = circleOf(shifted);
      if (circle.length > type.maxCircle) continue;
      return GridPuzzle(
        id: id ?? 'grid_${_clock().microsecondsSinceEpoch}_${_random.nextInt(9999)}',
        difficulty: difficulty,
        type: type.id,
        palette: palette ?? _random.nextInt(6),
        active: active,
        words: shifted,
        circle: circle,
        given: _given(shifted, _reveal(difficulty)),
        createdAt: createdAt ?? _clock(),
      );
    }
    return null;
  }

  List<String> _prepare(List<String> dictionary) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in dictionary) {
      final word = TurkishText.toUpper(raw);
      final length = TurkishText.letterCount(word);
      if (length < 3 || length > 7) continue;
      if (!TurkishText.isAllowedWord(word)) continue;
      if (seen.add(word)) out.add(word);
    }
    return out;
  }

  List<int> _lengths(String difficulty, List<String> words) {
    final have = words.map(TurkishText.letterCount).toSet();
    final wanted = switch (difficulty) {
      'starter' => [3, 4, 5],
      'easy' => [4, 5],
      'normal' => [5, 6],
      'hard' => [6, 7],
      _ => [7, 6, 5],
    };
    final ready = wanted.where(have.contains).toList();
    if (ready.isNotEmpty) return ready;
    return have.toList()..sort();
  }

  List<String>? _pickWords(List<String> words, String seed, int count, int maxCircle) {
    final chosen = <String>[seed];
    while (chosen.length < count) {
      String? pick;
      var pickSize = 99;
      for (final word in words) {
        if (chosen.contains(word)) continue;
        if (!_sharesLetter(word, chosen)) continue;
        final size = circleOf([
          for (final picked in chosen) GridWord(word: picked, x: 0, y: 0, across: true),
          GridWord(word: word, x: 0, y: 0, across: true),
        ]).length;
        if (size > maxCircle || size >= pickSize) continue;
        pickSize = size;
        pick = word;
      }
      if (pick == null) return null;
      chosen.add(pick);
    }
    return chosen;
  }

  bool _sharesLetter(String word, List<String> chosen) {
    final letters = TurkishText.letters(word).toSet();
    for (final other in chosen) {
      for (final letter in TurkishText.letters(other)) {
        if (letters.contains(letter)) return true;
      }
    }
    return false;
  }

  double _reveal(String difficulty) => switch (difficulty) {
        'starter' => 0.38,
        'easy' => 0.32,
        'normal' => 0.25,
        'hard' => 0.12,
        _ => 0.04,
      };

  List<GridWord> _grow(
    String seed,
    Map<String, List<String>> byLetter,
    int target,
    int maxCircle,
  ) {
    final board = <(int, int), String>{};
    final placed = <GridWord>[GridWord(word: seed, x: 0, y: 0, across: true)];
    _paint(board, placed.first);
    final used = {seed};
    var budget = 6000;
    bool search() {
      if (placed.length == target) return true;
      if (budget-- <= 0) return false;
      final options = _options(board, placed, byLetter, used, maxCircle);
      for (final next in options) {
        placed.add(next);
        used.add(next.word);
        _paint(board, next);
        if (search()) return true;
        placed.removeLast();
        used.remove(next.word);
        board.clear();
        for (final word in placed) {
          _paint(board, word);
        }
      }
      return false;
    }

    if (!search()) return const [];
    return placed;
  }

  List<GridWord> _options(
    Map<(int, int), String> board,
    List<GridWord> placed,
    Map<String, List<String>> byLetter,
    Set<String> used,
    int maxCircle,
  ) {
    final found = <GridWord>[];
    final seen = <String>{};
    for (final anchor in placed) {
      var fromAnchor = 0;
      final letters = TurkishText.letters(anchor.word);
      for (var index = 0; index < letters.length && fromAnchor < 6; index++) {
        final letter = letters[index];
        final ax = anchor.across ? anchor.x + index : anchor.x;
        final ay = anchor.across ? anchor.y : anchor.y + index;
        for (final word in byLetter[letter] ?? const <String>[]) {
          if (fromAnchor >= 6) break;
          if (used.contains(word)) continue;
          final spots = TurkishText.letters(word);
          for (var i = 0; i < spots.length; i++) {
            if (spots[i] != letter) continue;
            final across = !anchor.across;
            final x = across ? ax - i : ax;
            final y = across ? ay : ay - i;
            final key = '$word@$x,$y,$across';
            if (!seen.add(key)) continue;
            if (!_fits(board, spots, x, y, across)) continue;
            final next = GridWord(word: word, x: x, y: y, across: across);
            if (circleOf([...placed, next]).length > maxCircle) continue;
            found.add(next);
            fromAnchor++;
            break;
          }
        }
      }
    }
    found.shuffle(_random);
    if (found.length > 18) return found.sublist(0, 18);
    return found;
  }

  void _paint(Map<(int, int), String> board, GridWord word) {
    final letters = TurkishText.letters(word.word);
    for (var i = 0; i < letters.length; i++) {
      final x = word.across ? word.x + i : word.x;
      final y = word.across ? word.y : word.y + i;
      board[(x, y)] = letters[i];
    }
  }

  bool _fits(Map<(int, int), String> board, List<String> letters, int x, int y, bool across) {
    final before = across ? (x - 1, y) : (x, y - 1);
    final after = across ? (x + letters.length, y) : (x, y + letters.length);
    if (board.containsKey(before) || board.containsKey(after)) return false;
    var crossed = board.isEmpty;
    for (var i = 0; i < letters.length; i++) {
      final cx = across ? x + i : x;
      final cy = across ? y : y + i;
      final current = board[(cx, cy)];
      if (current != null) {
        if (current != letters[i]) return false;
        crossed = true;
        continue;
      }
      final sideA = across ? (cx, cy - 1) : (cx - 1, cy);
      final sideB = across ? (cx, cy + 1) : (cx + 1, cy);
      if (board.containsKey(sideA) || board.containsKey(sideB)) return false;
    }
    return crossed;
  }

  List<GridWord> _shift(List<GridWord> words) {
    var minX = words.first.x;
    var minY = words.first.y;
    for (final word in words) {
      if (word.x < minX) minX = word.x;
      if (word.y < minY) minY = word.y;
    }
    return [
      for (final word in words)
        GridWord(word: word.word, x: word.x - minX, y: word.y - minY, across: word.across),
    ];
  }

  List<String> circleOf(List<GridWord> placed) {
    final need = <String, int>{};
    for (final word in placed) {
      final counts = <String, int>{};
      for (final letter in TurkishText.letters(word.word)) {
        counts[letter] = (counts[letter] ?? 0) + 1;
      }
      for (final entry in counts.entries) {
        if (entry.value > (need[entry.key] ?? 0)) need[entry.key] = entry.value;
      }
    }
    return [
      for (final entry in need.entries)
        for (var i = 0; i < entry.value; i++) entry.key,
    ];
  }

  bool matchesType(GridPuzzle puzzle) {
    final type = GridSceneTypes.byId(puzzle.type);
    if (puzzle.type != type.id || puzzle.words.length != type.wordCount) return false;
    final circle = circleOf(puzzle.words);
    if (circle.length > type.maxCircle || circle.length != puzzle.circle.length) return false;
    final left = [...circle]..sort();
    final right = [...puzzle.circle]..sort();
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  /// Rebuilds a saved scene into the current 5-word type, keeping its identity.
  GridPuzzle? repair(GridPuzzle puzzle, {required List<String> dictionary}) {
    if (matchesType(puzzle)) return puzzle;
    return build(
      dictionary: dictionary,
      difficulty: puzzle.difficulty,
      sceneType: GridSceneTypes.cross5.id,
      active: puzzle.active,
      palette: puzzle.palette,
      id: puzzle.id,
      createdAt: puzzle.createdAt,
    );
  }

  List<String> _given(List<GridWord> words, double ratio) {
    final cells = <String>[];
    final seen = <String>{};
    for (final word in words) {
      final letters = TurkishText.letters(word.word);
      for (var i = 0; i < letters.length; i++) {
        final x = word.across ? word.x + i : word.x;
        final y = word.across ? word.y : word.y + i;
        if (seen.add('$x,$y')) cells.add('$x,$y');
      }
    }
    final count = max(1, (cells.length * ratio).floor());
    final picked = <String>{};
    for (final word in words) {
      picked.add('${word.x},${word.y}');
      if (picked.length >= count) break;
    }
    cells.shuffle(_random);
    for (final key in cells) {
      if (picked.length >= count) break;
      picked.add(key);
    }
    return picked.toList();
  }
}
