import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_csv.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_daily_paper.dart';

void main() {
  test('a full daily csv becomes 20 questions and 11 spares', () {
    final parsed = parseBilgiDailyCsv(_sheet(), day: '2026-10-10');
    expect(parsed.error, isNull, reason: parsed.error);
    expect(parsed.questions, hasLength(20));
    expect(parsed.spares, hasLength(11));
    expect(parsed.questions.first.id, 'gun20261010p01');
    expect(parsed.questions.first.difficulty, 'kolay');
    expect(parsed.questions.last.difficulty, 'efsane');
    expect(parsed.spares.first.tags, ['Günlük', 'Doga']);
    expect(parsed.questions[1].correct, 0);
  });

  test('the bank template and a short file are rejected', () {
    expect(parseBilgiDailyCsv(bilgiCsvTemplate, day: '2026-10-10').error, contains('tur'));
    expect(parseBilgiDailyCsv('$bilgiDailyCsvTemplate', day: '2026-10-10').error, contains('20'));
  });

  test('a leaked hint is a note and does not block the csv', () {
    final lines = _sheet().split('\n');
    lines[1] =
        'asil,Soru asil 1 hangi olguyu anlatır?,Alfa 1,Beta 1,Gama 1,Delta 1,A,Insan,kolay,Aciklama asil 1 nedeni soyler.,Alfa 1 cevabi burada.';
    final parsed = parseBilgiDailyCsv(lines.join('\n'), day: '2026-10-11');
    expect(parsed.error, isNull, reason: parsed.error);
    expect(parsed.questions, hasLength(20));
    expect(parsed.notes.join(' '), contains('ipucu doğru şıkkı'));
  });

  test('a wrong play-order difficulty is a note and still saves', () {
    final lines = _sheet().split('\n');
    // Slot 19 must be kolay in the recipe; force zor.
    lines[19] =
        'asil,Soru asil 19 hangi olguyu anlatır?,Alfa 19,Beta 19,Gama 19,Delta 19,A,Insan,zor,Aciklama asil 19 nedeni soyler.,Ipucu asil 19 konuyu acar.';
    final parsed = parseBilgiDailyCsv(lines.join('\n'), day: '2026-10-11');
    expect(parsed.error, isNull, reason: parsed.error);
    expect(parsed.questions, hasLength(20));
    expect(parsed.questions[18].difficulty, 'zor');
    expect(parsed.notes.join(' '), contains('zorluk kolay olmalı'));
  });
}

String _sheet() {
  final lines = <String>[bilgiDailyCsvColumns.join(',')];
  final used = <String, int>{};
  void add(String kind, String difficulty, int index, String topic) {
    final slot = ((used['$kind$difficulty'] = (used['$kind$difficulty'] ?? 0) + 1) - 1) % 4;
    final letter = ['A', 'B', 'C', 'D'][slot];
    lines.add(
      '$kind,Soru $kind $index hangi olguyu anlatır?,Alfa $index,Beta $index,Gama $index,Delta $index,$letter,$topic,$difficulty,Aciklama $kind $index nedeni soyler.,Ipucu $kind $index konuyu acar.',
    );
  }

  for (var i = 0; i < bilgiDailyPlayOrder.length; i++) {
    add('asil', bilgiDailyPlayOrder[i], i + 1, i.isEven ? 'Insan' : 'Tarih');
  }
  const spares = ['kolay', 'kolay', 'kolay', 'orta', 'orta', 'orta', 'zor', 'zor', 'zor', 'efsane', 'efsane'];
  for (var i = 0; i < spares.length; i++) {
    add('yedek', spares[i], i + 1, 'Doga');
  }
  return lines.join('\n');
}
