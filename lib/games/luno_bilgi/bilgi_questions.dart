import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

/// Deneme soruları silindi. Kategori listesi ayrı durur.
const bilgiQuestionLines = <String>[];

List<BilgiQuestion> seedBilgiQuestions() {
  final list = <BilgiQuestion>[];
  final seen = <String, int>{};
  for (final line in bilgiQuestionLines) {
    final parts = line.split('|');
    if (parts.length != 9) {
      throw StateError('Soru satırı bozuk: $line');
    }
    final categoryId = parts[0];
    final n = (seen[categoryId] ?? 0) + 1;
    seen[categoryId] = n;
    list.add(
      BilgiQuestion(
        id: '${categoryId}_$n',
        categoryId: categoryId,
        difficulty: parts[1],
        text: parts[2],
        options: [parts[3], parts[4], parts[5], parts[6]],
        correct: int.parse(parts[7]),
        explanation: parts[8],
        tags: [categoryId],
      ),
    );
  }
  return list;
}
