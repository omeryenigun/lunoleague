import 'package:kelimelig/core/utils/turkish_text.dart';

class GridWord {
  const GridWord({
    required this.word,
    required this.x,
    required this.y,
    required this.across,
  });

  final String word;
  final int x;
  final int y;
  final bool across;

  List<String> get letters => TurkishText.letters(word);

  Map<String, dynamic> toMap() => {
        'word': word,
        'x': x,
        'y': y,
        'across': across,
      };

  factory GridWord.fromMap(Map<String, dynamic> map) {
    return GridWord(
      word: map['word'] as String,
      x: map['x'] as int,
      y: map['y'] as int,
      across: map['across'] as bool,
    );
  }
}

class GridSceneType {
  const GridSceneType({
    required this.id,
    required this.label,
    required this.wordCount,
    required this.maxCircle,
  });

  final String id;
  final String label;
  final int wordCount;
  final int maxCircle;
}

class GridSceneTypes {
  static const cross5Id = 'cross5';
  static const cross5 = GridSceneType(id: cross5Id, label: '5 kelime', wordCount: 5, maxCircle: 8);

  static const all = <GridSceneType>[cross5];

  static GridSceneType byId(String? id) {
    for (final type in all) {
      if (type.id == id) return type;
    }
    return cross5;
  }
}

class GridCell {
  const GridCell({
    required this.x,
    required this.y,
    required this.letter,
    required this.given,
  });

  final int x;
  final int y;
  final String letter;
  final bool given;

  String get key => '$x,$y';
}

class GridPuzzle {
  const GridPuzzle({
    required this.id,
    required this.difficulty,
    this.type = GridSceneTypes.cross5Id,
    required this.palette,
    required this.active,
    required this.words,
    required this.circle,
    required this.given,
    required this.createdAt,
  });

  final String id;
  final String difficulty;
  final String type;
  final int palette;
  final bool active;
  final List<GridWord> words;
  final List<String> circle;
  final List<String> given;
  final DateTime createdAt;

  List<GridCell> get cells {
    final givenSet = given.toSet();
    final out = <GridCell>[];
    final seen = <String>{};
    for (final word in words) {
      final letters = word.letters;
      for (var i = 0; i < letters.length; i++) {
        final x = word.across ? word.x + i : word.x;
        final y = word.across ? word.y : word.y + i;
        final key = '$x,$y';
        if (!seen.add(key)) continue;
        out.add(GridCell(x: x, y: y, letter: letters[i], given: givenSet.contains(key)));
      }
    }
    return out;
  }

  GridPuzzle copyWith({bool? active}) {
    return GridPuzzle(
      id: id,
      difficulty: difficulty,
      type: type,
      palette: palette,
      active: active ?? this.active,
      words: words,
      circle: circle,
      given: given,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'difficulty': difficulty,
        'type': type,
        'palette': palette,
        'active': active,
        'words': [for (final word in words) word.toMap()],
        'circle': circle,
        'given': given,
        'createdAt': createdAt.toIso8601String(),
      };

  factory GridPuzzle.fromMap(Map<String, dynamic> map) {
    return GridPuzzle(
      id: map['id'] as String,
      difficulty: map['difficulty'] as String,
      type: map['type'] as String? ?? GridSceneTypes.cross5.id,
      palette: map['palette'] as int? ?? 0,
      active: map['active'] as bool? ?? false,
      words: [
        for (final raw in map['words'] as List<dynamic>)
          GridWord.fromMap(Map<String, dynamic>.from(raw as Map)),
      ],
      circle: [for (final letter in map['circle'] as List<dynamic>) letter as String],
      given: [for (final key in map['given'] as List<dynamic>) key as String],
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}

class GridProfile {
  const GridProfile({
    required this.displayName,
    required this.gamesFinished,
    required this.bestScore,
    required this.totalScore,
    required this.noAds,
    required this.weekScores,
    this.finishedIds = const [],
  });

  final String displayName;
  final int gamesFinished;
  final int bestScore;
  final int totalScore;
  final bool noAds;
  final List<int> weekScores;
  final List<String> finishedIds;

  int get weeklyPoints => weekScores.fold(0, (sum, score) => sum + score);

  GridProfile copyWith({
    String? displayName,
    int? gamesFinished,
    int? bestScore,
    int? totalScore,
    bool? noAds,
    List<int>? weekScores,
    List<String>? finishedIds,
  }) {
    return GridProfile(
      displayName: displayName ?? this.displayName,
      gamesFinished: gamesFinished ?? this.gamesFinished,
      bestScore: bestScore ?? this.bestScore,
      totalScore: totalScore ?? this.totalScore,
      noAds: noAds ?? this.noAds,
      weekScores: weekScores ?? this.weekScores,
      finishedIds: finishedIds ?? this.finishedIds,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'gamesFinished': gamesFinished,
        'bestScore': bestScore,
        'totalScore': totalScore,
        'noAds': noAds,
        'weekScores': weekScores,
        'finishedIds': finishedIds,
      };

  factory GridProfile.fromMap(Map<String, dynamic> map) {
    return GridProfile(
      displayName: map['displayName'] as String? ?? 'Oyuncu',
      gamesFinished: map['gamesFinished'] as int? ?? 0,
      bestScore: map['bestScore'] as int? ?? 0,
      totalScore: map['totalScore'] as int? ?? 0,
      noAds: map['noAds'] as bool? ?? false,
      weekScores: [
        for (final score in map['weekScores'] as List<dynamic>? ?? const [0, 0, 0, 0, 0, 0, 0])
          score as int,
      ],
      finishedIds: [
        for (final id in map['finishedIds'] as List<dynamic>? ?? const []) id as String,
      ],
    );
  }
}
