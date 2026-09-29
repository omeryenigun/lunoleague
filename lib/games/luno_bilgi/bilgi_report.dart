class BilgiQuestionReport {
  const BilgiQuestionReport({
    required this.id,
    required this.questionId,
    required this.questionText,
    required this.options,
    required this.correct,
    required this.categoryId,
    required this.difficulty,
    required this.note,
    required this.createdAt,
  });

  final String id;
  final String questionId;
  final String questionText;
  final List<String> options;
  final int correct;
  final String categoryId;
  final String difficulty;
  final String note;
  final String createdAt;

  String get correctLetter => ['A', 'B', 'C', 'D'][correct.clamp(0, 3)];

  factory BilgiQuestionReport.fromJson(Map<String, dynamic> map) {
    return BilgiQuestionReport(
      id: '${map['id'] ?? ''}',
      questionId: '${map['questionId'] ?? ''}',
      questionText: '${map['questionText'] ?? ''}',
      options: (map['options'] as List? ?? const []).map((item) => '$item').toList(),
      correct: map['correct'] is int ? map['correct'] as int : int.tryParse('${map['correct']}') ?? 0,
      categoryId: '${map['categoryId'] ?? ''}',
      difficulty: '${map['difficulty'] ?? ''}',
      note: '${map['note'] ?? ''}',
      createdAt: '${map['createdAt'] ?? ''}',
    );
  }
}

String? bilgiReportNoteError(String note) {
  final text = note.trim();
  if (text.isEmpty) return 'Açıklama zorunlu.';
  if (text.length > 800) return 'Açıklama en fazla 800 karakter olabilir.';
  return null;
}
