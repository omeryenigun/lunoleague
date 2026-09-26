import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';

class WordEntity {
  const WordEntity({
    required this.id,
    required this.word,
    required this.language,
    required this.length,
    required this.difficulty,
    required this.frequency,
    required this.category,
    required this.definition,
    required this.exampleSentence,
    required this.englishTranslation,
    required this.status,
    required this.isActive,
    required this.usedCount,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String word;
  final String language;
  final int length;
  final int difficulty;
  final int frequency;
  final String category;
  final String definition;
  final String exampleSentence;
  final String englishTranslation;
  final WordStatus status;
  final bool isActive;
  final int usedCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayWord => GameLocale.resolve(language).writtenUpper(word);

  bool get playable => isActive && status == WordStatus.active;

  WordEntity copyWith({
    String? word,
    int? difficulty,
    int? frequency,
    String? category,
    String? definition,
    String? exampleSentence,
    String? englishTranslation,
    WordStatus? status,
    bool? isActive,
    int? usedCount,
    DateTime? updatedAt,
  }) {
    final w = word ?? this.word;
    return WordEntity(
      id: id,
      word: w,
      language: language,
      length: GameLocale.resolve(language).letterCount(w),
      difficulty: difficulty ?? this.difficulty,
      frequency: frequency ?? this.frequency,
      category: category ?? this.category,
      definition: definition ?? this.definition,
      exampleSentence: exampleSentence ?? this.exampleSentence,
      englishTranslation: englishTranslation ?? this.englishTranslation,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      usedCount: usedCount ?? this.usedCount,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'word': word,
        'language': language,
        'length': length,
        'difficulty': difficulty,
        'frequency': frequency,
        'category': category,
        'definition': definition,
        'exampleSentence': exampleSentence,
        'englishTranslation': englishTranslation,
        'status': status.name,
        'isActive': isActive,
        'usedCount': usedCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory WordEntity.fromMap(Map<dynamic, dynamic> map) {
    return WordEntity(
      id: map['id'] as String,
      word: map['word'] as String,
      language: map['language'] as String? ?? 'tr',
      length: map['length'] as int? ?? TurkishText.letterCount(map['word'] as String),
      difficulty: map['difficulty'] as int? ?? 1,
      frequency: map['frequency'] as int? ?? 3,
      category: map['category'] as String? ?? 'genel',
      definition: map['definition'] as String? ?? '',
      exampleSentence: map['exampleSentence'] as String? ?? '',
      englishTranslation: map['englishTranslation'] as String? ?? '',
      status: WordStatus.values.byName(map['status'] as String? ?? 'active'),
      isActive: map['isActive'] as bool? ?? true,
      usedCount: map['usedCount'] as int? ?? 0,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }
}
