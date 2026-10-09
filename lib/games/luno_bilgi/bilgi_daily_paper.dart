import 'dart:convert';

import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';

/// Günlük kağıt bu günden itibaren CSV ile kurulur. Öncesi bankadan yazılır.
const bilgiContestAiFrom = '2026-10-09';

/// Kağıt: 6 kolay, 8 orta, 4 zor, 2 efsane.
const bilgiDailyAiQuotas = <int>[6, 8, 4, 2];

/// Oynanan sıra. İlk üç kolay veya orta, 20. soru efsane, ikinci efsane ilk yarıda değil.
const bilgiDailyPlayOrder = <String>[
  'kolay',
  'orta',
  'kolay',
  'orta',
  'orta',
  'zor',
  'orta',
  'kolay',
  'orta',
  'zor',
  'efsane',
  'orta',
  'kolay',
  'zor',
  'orta',
  'kolay',
  'orta',
  'zor',
  'kolay',
  'efsane',
];

bool bilgiContestAiDay(String day) => day.compareTo(bilgiContestAiFrom) >= 0;

/// Model çıktısını kağıt ve yedek listesine çevirir.
/// Bozuk satır düşer. 20 sağlam soru varsa kağıt kabul edilir; yedek 11'den az olabilir.
({List<Map<String, dynamic>> questions, List<Map<String, dynamic>> spares, String? error})
    bilgiDailyPaperFromModel(
  Object? raw, {
  required String day,
  Set<String> avoid = const {},
}) {
  final decoded = raw is String ? bilgiDailyJsonObject(raw) : raw;
  if (decoded is! Map) {
    return (questions: <Map<String, dynamic>>[], spares: <Map<String, dynamic>>[], error: 'Üretim okunamadı.');
  }
  final questions = _rows(decoded['questions']);
  final spares = _rows(decoded['spares']);
  if (questions == null || spares == null) {
    return (questions: <Map<String, dynamic>>[], spares: <Map<String, dynamic>>[], error: 'Üretim okunamadı.');
  }
  final seen = <String>{};
  final pool = [
    ..._accepted(questions, seen, avoid),
    ..._accepted(spares, seen, avoid),
  ];
  if (pool.isEmpty) {
    return (questions: <Map<String, dynamic>>[], spares: <Map<String, dynamic>>[], error: 'Sağlam soru kalmadı.');
  }
  final paper = pool.take(20).toList();
  final extra = pool.skip(paper.length).take(11).toList();
  final prepared = _repair(paper, extra);
  if (prepared.questions.length < 20) {
    return (
      questions: _stamp(prepared.questions, day, 'p'),
      spares: _stamp(prepared.spares, day, 'y'),
      error: 'Kağıt 20 soru olmalı.',
    );
  }
  return (
    questions: _stamp(prepared.questions, day, 'p'),
    spares: _stamp(prepared.spares, day, 'y'),
    error: null,
  );
}

List<Map<String, dynamic>> _accepted(List<Map<String, dynamic>> rows, Set<String> seen, Set<String> avoid) {
  final out = <Map<String, dynamic>>[];
  for (final row in rows) {
    final error = _rowError(row, seen, avoid);
    final hintOnly = error == 'ipucu doğru şıkkı yazıyor.' || error == 'ipucu açıklamanın aynısı.';
    if (error != null && !hintOnly) continue;
    if (hintOnly) {
      final key = bilgiDailyFold('${row['text'] ?? ''}'.trim());
      if (key.isEmpty || !seen.add(key) || avoid.contains(key)) continue;
    }
    out.add(_copyRow(row));
  }
  return out;
}

const _safeHint = 'Doğru seçenek sorunun konusuna doğrudan bağlanır.';

({List<Map<String, dynamic>> questions, List<Map<String, dynamic>> spares}) _repair(
  List<Map<String, dynamic>> questions,
  List<Map<String, dynamic>> spares,
) {
  final paper = _arrangePaper([for (final row in questions) _copyRow(row)]);
  final extra = [for (final row in spares) _copyRow(row)];
  _balance(paper);
  _balance(extra);
  _fixHints(paper);
  _fixHints(extra);
  return (questions: paper, spares: extra);
}

Map<String, dynamic> _copyRow(Map<String, dynamic> row) {
  final copy = Map<String, dynamic>.from(row);
  final options = row['options'];
  if (options is List) copy['options'] = [for (final option in options) option];
  return copy;
}

List<Map<String, dynamic>> _arrangePaper(List<Map<String, dynamic>> rows) {
  if (rows.length != 20 || _quota(rows, bilgiDailyAiQuotas, 'Kağıt') != null) return rows;
  void swap(int a, int b) {
    if (a == b) return;
    final item = rows[a];
    rows[a] = rows[b];
    rows[b] = item;
  }

  if (rows[19]['difficulty'] != 'efsane') {
    final index = rows.lastIndexWhere((row) => row['difficulty'] == 'efsane');
    if (index >= 0) swap(19, index);
  }
  final other = [for (var i = 0; i < 19; i++) i].where((i) => rows[i]['difficulty'] == 'efsane');
  if (other.isNotEmpty && other.first < 10) {
    for (var j = 10; j < 19; j++) {
      if (rows[j]['difficulty'] != 'efsane') {
        swap(other.first, j);
        break;
      }
    }
  }
  for (var i = 0; i < 3; i++) {
    final difficulty = '${rows[i]['difficulty']}';
    if (difficulty == 'kolay' || difficulty == 'orta') continue;
    for (var j = 3; j < 19; j++) {
      final next = '${rows[j]['difficulty']}';
      if (next == 'kolay' || next == 'orta') {
        swap(i, j);
        break;
      }
    }
  }
  _breakTopicRuns(rows);
  return rows;
}

void _breakTopicRuns(List<Map<String, dynamic>> rows) {
  bool structurallyOk() {
    if ('${rows[19]['difficulty']}' != 'efsane') return false;
    for (var i = 0; i < 3; i++) {
      final difficulty = '${rows[i]['difficulty']}';
      if (difficulty != 'kolay' && difficulty != 'orta') return false;
    }
    final other = rows.indexWhere((row) => row['difficulty'] == 'efsane');
    return other >= 10;
  }

  int runs() {
    var count = 0;
    for (var i = 2; i < rows.length; i++) {
      final topic = bilgiDailyFold(_topic(rows[i]));
      if (topic.isNotEmpty && topic == bilgiDailyFold(_topic(rows[i - 1])) && topic == bilgiDailyFold(_topic(rows[i - 2]))) {
        count += 1;
      }
    }
    return count;
  }

  for (var pass = 0; pass < rows.length; pass++) {
    final before = runs();
    if (before == 0) return;
    var moved = false;
    for (var i = 2; i < rows.length && !moved; i++) {
      final topic = bilgiDailyFold(_topic(rows[i]));
      if (topic.isEmpty || topic != bilgiDailyFold(_topic(rows[i - 1])) || topic != bilgiDailyFold(_topic(rows[i - 2]))) {
        continue;
      }
      for (final slot in [i, i - 1, i - 2]) {
        if (moved || '${rows[slot]['difficulty']}' == 'efsane') continue;
        for (var j = 0; j < rows.length; j++) {
          if ((j - slot).abs() < 2 || bilgiDailyFold(_topic(rows[j])) == topic) continue;
          if ('${rows[j]['difficulty']}' == 'efsane') continue;
          final item = rows[slot];
          rows[slot] = rows[j];
          rows[j] = item;
          if (structurallyOk() && runs() < before) {
            moved = true;
            break;
          }
          rows[j] = rows[slot];
          rows[slot] = item;
        }
      }
    }
    if (!moved) return;
  }
}

void _balance(List<Map<String, dynamic>> rows) {
  for (final difficulty in bilgiDifficultyLevels) {
    final group = [for (final row in rows) if (row['difficulty'] == difficulty) row];
    for (var guard = 0; guard < group.length * 4; guard++) {
      final counts = [0, 0, 0, 0];
      for (final row in group) {
        final correct = _correct(row['correct']);
        if (correct < 0 || correct > 3) return;
        counts[correct] += 1;
      }
      var maxSlot = 0;
      var minSlot = 0;
      for (var i = 1; i < 4; i++) {
        if (counts[i] > counts[maxSlot]) maxSlot = i;
        if (counts[i] < counts[minSlot]) minSlot = i;
      }
      if (counts[maxSlot] - counts[minSlot] <= 1) break;
      Map<String, dynamic>? row;
      for (final item in group) {
        if (_correct(item['correct']) == maxSlot) {
          row = item;
          break;
        }
      }
      if (row == null) break;
      final options = row['options'];
      if (options is! List || options.length != 4) break;
      final next = [for (final option in options) '$option'];
      final answer = next.removeAt(maxSlot);
      next.insert(minSlot, answer);
      row['options'] = next;
      row['correct'] = minSlot;
    }
  }
}

void _fixHints(List<Map<String, dynamic>> rows) {
  for (final row in rows) {
    final options = row['options'];
    final correct = _correct(row['correct']);
    if (options is! List || options.length != 4 || correct < 0 || correct > 3) continue;
    final answer = bilgiDailyFold('${options[correct]}');
    final hint = '${row['hint'] ?? ''}'.trim();
    final explanation = '${row['explanation'] ?? ''}'.trim();
    final folded = bilgiDailyFold(hint);
    final leaks = answer.length >= 4 && folded.contains(answer);
    final same = folded.isNotEmpty && folded == bilgiDailyFold(explanation);
    final badLength = hint.length < 4 || hint.length > 500;
    if (!leaks && !same && !badLength) continue;
    final safe = bilgiDailyFold(_safeHint);
    if (safe == bilgiDailyFold(explanation)) continue;
    if (answer.length >= 4 && safe.contains(answer)) continue;
    row['hint'] = _safeHint;
  }
}

String? bilgiDailyOrderError(List<Map<String, dynamic>> rows) {
  if (rows.length != bilgiDailyPlayOrder.length) return 'Kağıt sırası bozuk.';
  for (var i = 0; i < rows.length; i++) {
    final difficulty = '${rows[i]['difficulty'] ?? ''}'.trim();
    if (difficulty != bilgiDailyPlayOrder[i]) {
      return 'Kağıt ${i + 1}: zorluk ${bilgiDailyPlayOrder[i]} olmalı.';
    }
  }
  return null;
}

String? bilgiDailyPaperError({
  required List<Map<String, dynamic>> questions,
  required List<Map<String, dynamic>> spares,
  Set<String> avoid = const {},
}) {
  if (questions.length != 20) return 'Kağıt 20 soru olmalı.';
  if (spares.length != 11) return 'Yedek 11 soru olmalı.';
  final seen = <String>{};
  final paperTopics = <String>[];
  for (var i = 0; i < questions.length; i++) {
    final error = _rowError(questions[i], seen, avoid);
    if (error != null) return 'Kağıt ${i + 1}: $error';
    paperTopics.add(_topic(questions[i]));
  }
  for (var i = 0; i < spares.length; i++) {
    final error = _rowError(spares[i], seen, avoid);
    if (error != null) return 'Yedek ${i + 1}: $error';
  }
  final quotaError = _quota(questions, bilgiDailyAiQuotas, 'Kağıt');
  if (quotaError != null) return quotaError;
  final spareError = _quota(spares, bilgiContestSpareCounts, 'Yedek');
  if (spareError != null) return spareError;
  for (var i = 0; i < 3; i++) {
    final difficulty = '${questions[i]['difficulty']}';
    if (difficulty != 'kolay' && difficulty != 'orta') {
      return 'İlk üç soru kolay veya orta olmalı.';
    }
  }
  if ('${questions[19]['difficulty']}' != 'efsane') return '20. soru efsane olmalı.';
  final otherEfsane = questions.indexWhere((row) => row['difficulty'] == 'efsane' && row != questions[19]);
  if (otherEfsane >= 0 && otherEfsane < 10) return 'İkinci efsane ilk yarıda durmamalı.';
  final run = _topicRun(paperTopics);
  if (run != null) return run;
  final balance = _groupBalance(questions) ?? _groupBalance(spares);
  if (balance != null) return balance;
  return null;
}

Map<String, dynamic>? bilgiDailyJsonObject(String raw) {
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

String bilgiDailyFold(String value) {
  final text = value
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ç', 'c');
  return text.replaceAll(RegExp(r'[^a-z0-9]+'), '');
}

List<Map<String, dynamic>>? _rows(Object? raw) {
  if (raw is! List) return null;
  final out = <Map<String, dynamic>>[];
  for (final item in raw) {
    if (item is! Map) return null;
    out.add(Map<String, dynamic>.from(item));
  }
  return out;
}

List<Map<String, dynamic>> _stamp(List<Map<String, dynamic>> rows, String day, String kind) {
  final compact = day.replaceAll('-', '');
  final out = <Map<String, dynamic>>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    final options = [for (final option in row['options'] as List) '$option'.trim()];
    out.add({
      'id': 'gun$compact$kind${(i + 1).toString().padLeft(2, '0')}',
      'categoryId': tumuKarmaId,
      'text': '${row['text']}'.trim(),
      'options': options,
      'correct': _correct(row['correct']),
      'difficulty': '${row['difficulty']}'.trim(),
      'explanation': '${row['explanation'] ?? ''}'.trim(),
      'hint': '${row['hint'] ?? ''}'.trim(),
      'status': 'approved',
      'tags': ['Günlük', _topic(row)],
      'rejectReason': '',
      'reviewed': true,
    });
  }
  return out;
}

String? _rowError(Map<String, dynamic> row, Set<String> seen, Set<String> avoid) {
  final text = '${row['text'] ?? ''}'.trim();
  final options = row['options'];
  if (text.isEmpty || options is! List || options.length != 4) return 'dört şık dolu olmalı.';
  final opts = [for (final option in options) '$option'.trim()];
  if (opts.any((option) => option.isEmpty)) return 'şık boş.';
  final foldedOptions = [for (final option in opts) bilgiDailyFold(option)];
  if (foldedOptions.toSet().length != 4) return 'şıklar birbirinin kopyası.';
  final correct = _correct(row['correct']);
  if (correct < 0 || correct > 3) return 'doğru şık 0 ile 3 arasında olmalı.';
  final difficulty = '${row['difficulty'] ?? ''}'.trim();
  if (!bilgiDifficultyLevels.contains(difficulty)) return 'zorluk geçersiz.';
  final hint = '${row['hint'] ?? ''}'.trim();
  final explanation = '${row['explanation'] ?? ''}'.trim();
  if (hint.length < 4 || hint.length > 500) return 'ipucu dolu olmalı.';
  if (explanation.isEmpty) return 'açıklama dolu olmalı.';
  if (bilgiDailyFold(hint) == bilgiDailyFold(explanation)) return 'ipucu açıklamanın aynısı.';
  final answer = foldedOptions[correct];
  if (answer.length >= 4 && bilgiDailyFold(hint).contains(answer)) return 'ipucu doğru şıkkı yazıyor.';
  if (_topic(row).isEmpty) return 'konu dolu olmalı.';
  final key = bilgiDailyFold(text);
  if (key.isEmpty) return 'soru metni boş.';
  if (!seen.add(key) || avoid.contains(key)) return 'bu olgu zaten kullanıldı.';
  return null;
}

int _correct(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw') ?? -1;
}

String _topic(Map<String, dynamic> row) => '${row['topic'] ?? ''}'.trim();

String? _quota(List<Map<String, dynamic>> rows, List<int> quotas, String label) {
  for (var i = 0; i < bilgiDifficultyLevels.length; i++) {
    final difficulty = bilgiDifficultyLevels[i];
    final count = rows.where((row) => row['difficulty'] == difficulty).length;
    if (count != quotas[i]) return '$label $difficulty sayısı ${quotas[i]} olmalı.';
  }
  return null;
}

String? _topicRun(List<String> topics) {
  var run = 1;
  for (var i = 1; i < topics.length; i++) {
    final topic = bilgiDailyFold(topics[i]);
    if (topic.isNotEmpty && topic == bilgiDailyFold(topics[i - 1])) {
      run += 1;
      if (run > 2) return 'Aynı konu art arda ikiden fazla geldi.';
    } else {
      run = 1;
    }
  }
  return null;
}

String? _groupBalance(List<Map<String, dynamic>> rows) {
  for (final difficulty in bilgiDifficultyLevels) {
    final counts = [0, 0, 0, 0];
    for (final row in rows) {
      if (row['difficulty'] != difficulty) continue;
      final correct = _correct(row['correct']);
      if (correct < 0 || correct > 3) return 'Şık dağılımı bozuk.';
      counts[correct] += 1;
    }
    final span = counts.reduce((a, b) => a > b ? a : b) - counts.reduce((a, b) => a < b ? a : b);
    if (span > 1) return '$difficulty şıkları dengeli dağılmalı.';
  }
  return null;
}
