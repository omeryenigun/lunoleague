const bilgiReportStatusBekliyor = 'bekliyor';
const bilgiReportStatusDikkateAlindi = 'dikkate_alindi';
const bilgiReportStatusDikkateAlinmadi = 'dikkate_alinmadi';

const bilgiReportStatuses = <String>{
  bilgiReportStatusBekliyor,
  bilgiReportStatusDikkateAlindi,
  bilgiReportStatusDikkateAlinmadi,
};

String normalizeBilgiReportStatus(Object? raw) {
  final value = '$raw'.trim();
  if (bilgiReportStatuses.contains(value)) return value;
  return bilgiReportStatusBekliyor;
}

String bilgiReportStatusLabel(String status) {
  return switch (normalizeBilgiReportStatus(status)) {
    bilgiReportStatusDikkateAlindi => 'Dikkate alındı',
    bilgiReportStatusDikkateAlinmadi => 'Dikkate alınmadı',
    _ => 'Bekliyor',
  };
}

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
    this.status = bilgiReportStatusBekliyor,
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
  final String status;

  String get correctLetter => ['A', 'B', 'C', 'D'][correct.clamp(0, 3)];

  BilgiQuestionReport copyWith({String? status}) {
    return BilgiQuestionReport(
      id: id,
      questionId: questionId,
      questionText: questionText,
      options: options,
      correct: correct,
      categoryId: categoryId,
      difficulty: difficulty,
      note: note,
      createdAt: createdAt,
      status: status == null ? this.status : normalizeBilgiReportStatus(status),
    );
  }

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
      status: normalizeBilgiReportStatus(map['status']),
    );
  }
}

String? bilgiReportNoteError(String note) {
  final text = note.trim();
  if (text.isEmpty) return 'Açıklama zorunlu.';
  if (text.length > 800) return 'Açıklama en fazla 800 karakter olabilir.';
  return null;
}
