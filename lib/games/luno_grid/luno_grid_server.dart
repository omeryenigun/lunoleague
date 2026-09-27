import 'dart:math';

import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/seed_words.dart';
import 'package:kelimelig/games/luno_grid/grid_generator.dart';
import 'package:kelimelig/games/luno_grid/grid_model.dart';

class GridScore {
  const GridScore({
    required this.name,
    required this.score,
    required this.sceneId,
    required this.createdAt,
  });

  final String name;
  final int score;
  final String sceneId;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'name': name,
        'score': score,
        'sceneId': sceneId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GridScore.fromMap(Map<String, dynamic> map) {
    return GridScore(
      name: map['name'] as String? ?? 'Oyuncu',
      score: map['score'] as int? ?? 0,
      sceneId: map['sceneId'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class LunoGridServer {
  LunoGridServer(
    this._store, {
    required Future<List<String>> Function() words,
    GridGenerator? generator,
    DateTime Function()? clock,
    Random? random,
  })  : _words = words,
        _generator = generator ?? GridGenerator(random: random, clock: clock),
        _clock = clock ?? DateTime.now;

  final KeyValueStore _store;
  final Future<List<String>> Function() _words;
  final GridGenerator _generator;
  final DateTime Function() _clock;

  Future<List<String>> dictionary() => _words();

  Future<GridProfile> profile({String? displayName}) async {
    final raw = await _store.get('profile', 'me');
    final current = raw == null
        ? GridProfile(
            displayName: displayName ?? 'Oyuncu',
            gamesFinished: 0,
            bestScore: 0,
            totalScore: 0,
            noAds: false,
            weekScores: const [0, 0, 0, 0, 0, 0, 0],
          )
        : GridProfile.fromMap(raw);
    final named = displayName == null || displayName.isEmpty
        ? current
        : current.copyWith(displayName: displayName);
    if (raw == null || named.displayName != current.displayName) {
      await _store.put('profile', 'me', named.toMap());
    }
    return named;
  }

  Future<List<GridPuzzle>> scenes() async {
    final rows = await _store.values('scenes');
    final list = <GridPuzzle>[];
    for (final row in rows) {
      list.add(await _keep(GridPuzzle.fromMap(row)));
    }
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<GridPuzzle?> scene(String id) async {
    final raw = await _store.get('scenes', id);
    if (raw == null) return null;
    return _keep(GridPuzzle.fromMap(raw));
  }

  Future<GridPuzzle> _keep(GridPuzzle puzzle) async {
    final fixed = _generator.repair(puzzle, dictionary: await _words());
    if (fixed == null || _sceneKey(fixed) == _sceneKey(puzzle)) return fixed ?? puzzle;
    await _store.put('scenes', fixed.id, fixed.toMap());
    return fixed;
  }

  String _sceneKey(GridPuzzle puzzle) {
    final words = puzzle.words.map((word) => '${word.word}@${word.x},${word.y},${word.across}').join('|');
    final circle = [...puzzle.circle]..sort();
    final given = [...puzzle.given]..sort();
    return '${puzzle.type}#$words#${circle.join()}#${given.join(';')}';
  }

  Future<GridPuzzle?> generate({
    required String difficulty,
    String sceneType = GridSceneTypes.cross5Id,
    bool active = false,
  }) async {
    final puzzle = _generator.build(
      dictionary: await _words(),
      difficulty: difficulty,
      sceneType: sceneType,
      active: active,
    );
    if (puzzle == null) return null;
    await _store.put('scenes', puzzle.id, puzzle.toMap());
    return puzzle;
  }

  Future<void> setActive(String id, bool active) async {
    final current = await scene(id);
    if (current == null) return;
    await _store.put('scenes', id, current.copyWith(active: active).toMap());
  }

  Future<GridPuzzle?> openPractice() async {
    final active = [for (final item in await scenes()) if (item.active) item];
    if (active.isNotEmpty) return active.first;
    return generate(difficulty: 'normal');
  }

  Future<GridPuzzle?> todaysDaily() async {
    final saved = await _store.getMeta('daily_${DateKeys.dayKey(_clock())}');
    if (saved == null) return null;
    return scene(saved);
  }

  Future<GridPuzzle?> openDaily() async {
    final day = DateKeys.dayKey(_clock());
    final saved = await _store.getMeta('daily_$day');
    if (saved != null) return scene(saved);
    final active = [for (final item in await scenes()) if (item.active) item];
    if (active.isEmpty) return null;
    await _store.putMeta('daily_$day', active.first.id);
    return active.first;
  }

  Future<int> weeklyPoints() async {
    final profile = await this.profile();
    return profile.weeklyPoints;
  }

  Future<String> openRoom() async {
    final puzzle = await openPractice();
    if (puzzle == null) return '';
    final code = _code();
    await _store.putMeta('room_$code', puzzle.id);
    return code;
  }

  Future<GridPuzzle?> joinRoom(String code) async {
    final id = await _store.getMeta('room_${code.trim().toUpperCase()}');
    if (id == null) return null;
    return scene(id);
  }

  Future<void> recordScore({
    required String sceneId,
    required int score,
    required String name,
  }) async {
    final now = _clock();
    await _store.put('scores', '${now.microsecondsSinceEpoch}', {
      'name': name,
      'score': score,
      'sceneId': sceneId,
      'createdAt': now.toIso8601String(),
    });
    final current = await profile();
    final week = List<int>.from(current.weekScores);
    if (week.length < 7) {
      week.addAll(List.filled(7 - week.length, 0));
    }
    final index = now.weekday - 1;
    week[index] = week[index] + score;
    final finished = [...current.finishedIds];
    if (!finished.contains(sceneId)) finished.add(sceneId);
    await _store.put(
      'profile',
      'me',
      current
          .copyWith(
            gamesFinished: current.gamesFinished + 1,
            bestScore: score > current.bestScore ? score : current.bestScore,
            totalScore: current.totalScore + score,
            weekScores: week,
            finishedIds: finished,
          )
          .toMap(),
    );
  }

  Future<List<GridScore>> ranking({String? sceneId}) async {
    final rows = await _store.values('scores');
    final scores = [for (final row in rows) GridScore.fromMap(row)];
    final filtered = sceneId == null ? scores : scores.where((item) => item.sceneId == sceneId);
    final sorted = filtered.toList()..sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  String _code() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(5, (_) => alphabet[_generatorNext(alphabet.length)]).join();
  }

  int _generatorNext(int max) => DateTime.now().microsecond % max;
}

Future<List<String>> gridDictionary(KeyValueStore leagueStore) async {
  final rows = await leagueStore.values('words');
  final fromStore = <String>[];
  for (final row in rows) {
    final language = row['language'] as String? ?? '';
    final active = row['isActive'] as bool? ?? true;
    final word = row['word'] as String? ?? '';
    final status = row['status'] as String? ?? 'active';
    if (language == 'tr' && active && status == 'active' && word.isNotEmpty) fromStore.add(word);
  }
  if (fromStore.length >= 12) return fromStore;
  return [for (final word in buildSeedWords()) word.word];
}
