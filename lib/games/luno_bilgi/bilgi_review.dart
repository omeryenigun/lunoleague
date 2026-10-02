import 'dart:convert';

import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';

/// Sistem mesajı. Model soruyu yeniden yazmaz, yalnız karar döner.
const bilgiReviewInstruction = '''
Türkçe bir bilgi yarışması sorusunu denetle. Soru metnini, şıkları ve doğru indeksi değiştirme. Yalnızca karar ver.

Zorluk, doğru şıkkı dört seçenek arasından kimin ayırabildiğidir.
Doğruyu bilen kişi şıkları ayıramıyorsa soru bozuktur. Zorluk yükseltme. Reddet.
Kolay: herkes, gündelik veya ilkokul bilgisi. Yanlış şıklar başka kavramlar.
Orta: meraklı bir acemi, genel kültür. Şıklar aynı aileden olabilir.
Zor: konuda yetkin biri. Sayı, terim veya başlık. Şıklar yakın. Tek ayrıntı ayırır.
Efsane: o alt konuyu izleyen biri. Nadir bilgi. Şıklar çok yakın, ince bir ayrım. Yine tek doğru cevap var.
Şık benzerliği en fazla bir kademe kaydırır, iki kademe değil.
Eğitim düzeyi yalnızca ipucudur. Şık uzunluğu ölçü değildir. Doğru oranı kullanma. Şansın altı bozuk anahtar demektir, efsane değil.
Bir alan uzmanına kolay gelmesi, soruyu kolay yapmaz.

Reddet:
- Doğru şık yanlışsa veya doğruyu bilen kişi ayıramıyorsa
- Soru veya cevap anlamsızsa, şüpheli veya tutarsızsa
- Teknik bozukluk varsa: eksik şık, tekrarlayan şık, doğru harf metinle uyuşmuyorsa

Yanıt yalnız JSON olsun:
{"verdict":"keep","difficulty":"kolay","reason":""}
veya
{"verdict":"reject","difficulty":"kolay","reason":"tek kısa Türkçe cümle"}
keep iken reason boş. reject iken reason dolu. difficulty yalnız kolay, orta, zor, efsane.
''';

/// Model kararı. [keep] ise [difficulty] yazılır. Değilse [reason] red nedenidir.
class BilgiReviewDecision {
  const BilgiReviewDecision._({required this.keep, required this.difficulty, required this.reason});

  final bool keep;
  final String difficulty;
  final String reason;

  String get verdict => keep ? 'keep' : 'reject';
}

/// Model metninden karar okur. Bozuk JSON, boş red nedeni veya dört zorluk dışındaki kelime null döner.
BilgiReviewDecision? bilgiParseReview(String raw) {
  final map = bilgiReviewJson(raw);
  if (map == null) return null;
  final verdict = '${map['verdict'] ?? ''}'.trim();
  final difficulty = '${map['difficulty'] ?? ''}'.trim();
  final reason = '${map['reason'] ?? ''}'.trim();
  if (!bilgiDifficultyLevels.contains(difficulty)) return null;
  if (verdict == 'keep') {
    if (reason.isNotEmpty) return null;
    return BilgiReviewDecision._(keep: true, difficulty: difficulty, reason: '');
  }
  if (verdict == 'reject') {
    if (reason.isEmpty) return null;
    final clipped = reason.length > 400 ? reason.substring(0, 400) : reason;
    return BilgiReviewDecision._(keep: false, difficulty: difficulty, reason: clipped);
  }
  return null;
}

/// Tutulursa zorluk değişir ve red nedeni silinir. Reddedilirse durum rejected olur, zorluk aynı kalır.
({String difficulty, String status, String rejectReason}) bilgiApplyReview({
  required String currentDifficulty,
  required String currentStatus,
  required BilgiReviewDecision decision,
}) {
  if (decision.keep) {
    return (difficulty: decision.difficulty, status: currentStatus, rejectReason: '');
  }
  return (difficulty: currentDifficulty, status: 'rejected', rejectReason: decision.reason);
}

Map<String, dynamic>? bilgiReviewJson(String raw) {
  final trimmed = raw.trim();
  final fenced = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(trimmed);
  final body = fenced?.group(1)?.trim() ?? trimmed;
  final start = body.indexOf('{');
  final end = body.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final decoded = jsonDecode(body.substring(start, end + 1));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return null;
}
