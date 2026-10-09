import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_daily_paper.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';

/// CSV columns: soru, a, b, c, d, dogru, kategori, altkategori, zorluk, aciklama, ipucu.
const bilgiCsvColumns = [
  'soru',
  'a',
  'b',
  'c',
  'd',
  'dogru',
  'kategori',
  'altkategori',
  'zorluk',
  'aciklama',
  'ipucu',
];

const bilgiCsvExample =
    "Osmanlı'nın kurucusu?,Orhan,Osman,Murat,Bayezid,B,Osmanlı Tarihi,Kuruluş,kolay,Osman Bey kurmuştur.,Beylik sınırında kurulmuştur.";

final bilgiCsvTemplate = '${bilgiCsvColumns.join(',')}\n$bilgiCsvExample\n';

class BilgiCsvFields {
  const BilgiCsvFields({
    required this.text,
    required this.options,
    required this.correctLetter,
    required this.category,
    required this.subcategory,
    required this.difficulty,
    required this.explanation,
    this.hint = '',
  });

  final String text;
  final List<String> options;
  final String correctLetter;
  final String category;
  final String subcategory;
  final String difficulty;
  final String explanation;
  final String hint;
}

enum BilgiCsvKind { blank, header, invalid, row }

class BilgiCsvLine {
  const BilgiCsvLine._(this.kind, [this.fields]);

  const BilgiCsvLine.blank() : this._(BilgiCsvKind.blank);
  const BilgiCsvLine.header() : this._(BilgiCsvKind.header);
  const BilgiCsvLine.invalid() : this._(BilgiCsvKind.invalid);
  const BilgiCsvLine.row(BilgiCsvFields fields) : this._(BilgiCsvKind.row, fields);

  final BilgiCsvKind kind;
  final BilgiCsvFields? fields;
}

BilgiCsvLine parseBilgiCsvLine(String line) {
  if (line.trim().isEmpty) return const BilgiCsvLine.blank();
  final parts = splitBilgiCsvRow(line);
  if (parts.isEmpty) return const BilgiCsvLine.blank();
  if (parts.first.trim().toLowerCase() == 'soru') return const BilgiCsvLine.header();
  if (parts.length < 9) return const BilgiCsvLine.invalid();
  return BilgiCsvLine.row(
    BilgiCsvFields(
      text: parts[0].trim(),
      options: [parts[1].trim(), parts[2].trim(), parts[3].trim(), parts[4].trim()],
      correctLetter: parts[5].trim(),
      category: parts[6].trim(),
      subcategory: parts[7].trim(),
      difficulty: parts[8].trim(),
      explanation: parts.length >= 10 ? parts[9].trim() : '',
      hint: parts.length >= 11 ? parts[10].trim() : '',
    ),
  );
}

List<String> splitBilgiCsvRow(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var quote = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (quote) {
      if (ch == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i += 1;
        } else {
          quote = false;
        }
      } else {
        buf.write(ch);
      }
    } else if (ch == '"') {
      quote = true;
    } else if (ch == ',') {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}

/// Günlük kağıt: tur asil veya yedek. Diğer sütunlar soru bankasıyla aynı düzendedir.
const bilgiDailyCsvColumns = [
  'tur',
  'soru',
  'a',
  'b',
  'c',
  'd',
  'dogru',
  'konu',
  'zorluk',
  'aciklama',
  'ipucu',
];

const bilgiDailyCsvExample =
    'asil,İnsan vücudunda oksijeni taşıyan kan hücrelerinin adı nedir?,Alyuvar,Akyuvar,Trombosit,Nöron,A,İnsan,kolay,Alyuvarlar hemoglobine bağlanan oksijeni taşır.,Kanda oksijen taşıyan hücrelerdir.';

const bilgiDailyCsvSpareExample =
    'yedek,Bitkiler besinini hangi işlemle üretir?,Fotosentez,Solunum,Terleme,Çimlenme,A,Doğa,kolay,Bitkiler ışıkla besin üretir.,Işıkla besin üretimi.';

final bilgiDailyCsvTemplate = '${bilgiDailyCsvColumns.join(',')}\n$bilgiDailyCsvExample\n$bilgiDailyCsvSpareExample\n';

const bilgiDailyCsvRecipe = <String>[
  'İlk satır başlıktır: tur,soru,a,b,c,d,dogru,konu,zorluk,aciklama,ipucu',
  'tur: asil veya yedek. Asıl satırlar dosyadaki sırayla oynanır. Yedekler değiştir jokeri içindir.',
  'Asıl 20 satır: 6 kolay, 8 orta, 4 zor, 2 efsane.',
  'Asıl sıra: kolay, orta, kolay, orta, orta, zor, orta, kolay, orta, zor, efsane, orta, kolay, zor, orta, kolay, orta, zor, kolay, efsane.',
  'Yedek 11 satır: 3 kolay, 3 orta, 3 zor, 2 efsane. Yedek sırası serbesttir.',
  'dogru: A, B, C veya D. Aynı zorlukta doğru harfler en fazla 1 farkla dağılır.',
  'Kolay 6 asıl için örnek harf: A A B B C D. Orta 8 asıl: her harf iki kez. Zor 4 asıl: her harf bir kez. Efsane 2 asıl: iki farklı harf.',
  'Yedek kolay, orta ve zor 3 soruda üç farklı harf. Yedek efsane iki farklı harf.',
  'konu kısa bir addır (İnsan, Doğa, Tarih). Aynı konu art arda en fazla 2 soru gelir.',
  'aciklama boş olamaz. ipucu 4 ile 500 karakterdir.',
  'Virgül içeren hücreyi tırnak içine al. Tırnak karakteri için "" yaz.',
  'Kayıt yalnız teknik hatalarda durur (sütun, boş alan, geçersiz zorluk/harf, asıl 20 / yedek 11). Zorluk sırası, kota, ipucu kalitesi, konu tekrarı gibi içerik kuralları not olur; kaydı engellemez.',
  'Hata satırı Kağıt 4 ise 4. asıl sorudur. Yedek 2 ise 2. yedek satırdır.',
];

class BilgiDailyCsvPaper {
  const BilgiDailyCsvPaper({
    this.questions = const [],
    this.spares = const [],
    this.error,
    this.notes = const [],
  });

  final List<BilgiQuestion> questions;
  final List<BilgiQuestion> spares;
  final String? error;
  final List<String> notes;
}

BilgiDailyCsvPaper parseBilgiDailyCsv(String raw, {required String day}) {
  final text = raw.replaceFirst('\uFEFF', '');
  final mains = <Map<String, dynamic>>[];
  final extras = <Map<String, dynamic>>[];
  final notes = <String>[];
  final lines = text.split(RegExp(r'\r?\n'));
  var data = 0;
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trim().isEmpty) continue;
    final parts = splitBilgiCsvRow(line);
    final head = bilgiDailyFold(parts.first.trim());
    if (data == 0 && (head == 'tur' || head == 'soru')) {
      if (head == 'soru') {
        return const BilgiDailyCsvPaper(error: 'Bu banka CSV dosyası. Günlük dosyanın ilk sütunu tur olmalı.');
      }
      continue;
    }
    data += 1;
    final row = _dailyRow(parts, i + 1);
    if (row.error != null) return BilgiDailyCsvPaper(error: row.error);
    final built = row.row!;
    if (built.remove('_spare') == true) {
      extras.add(built);
    } else {
      mains.add(built);
    }
  }
  if (mains.isEmpty && extras.isEmpty) return const BilgiDailyCsvPaper(error: 'CSV boş.');
  if (mains.length != 20) {
    return BilgiDailyCsvPaper(error: 'Asıl soru 20 olmalı. Dosyada ${mains.length} asıl var.');
  }
  if (extras.length != 11) {
    return BilgiDailyCsvPaper(error: 'Yedek soru 11 olmalı. Dosyada ${extras.length} yedek var.');
  }
  final order = bilgiDailyOrderError(mains);
  if (order != null) notes.add(order);
  final paper = bilgiDailyPaperError(questions: mains, spares: extras, softContent: true, notes: notes);
  if (paper != null) return BilgiDailyCsvPaper(error: paper);
  final compact = day.replaceAll('-', '');
  return BilgiDailyCsvPaper(
    questions: [for (var i = 0; i < mains.length; i++) _dailyQuestion(mains[i], 'gun${compact}p${(i + 1).toString().padLeft(2, '0')}')],
    spares: [for (var i = 0; i < extras.length; i++) _dailyQuestion(extras[i], 'gun${compact}y${(i + 1).toString().padLeft(2, '0')}')],
    notes: notes,
  );
}

({Map<String, dynamic>? row, String? error}) _dailyRow(List<String> parts, int line) {
  if (parts.length < bilgiDailyCsvColumns.length) {
    return (row: null, error: 'Satır $line: ${bilgiDailyCsvColumns.length} sütun olmalı.');
  }
  final kind = bilgiDailyFold(parts[0].trim());
  if (kind != 'asil' && kind != 'yedek') {
    return (row: null, error: 'Satır $line: tur asil veya yedek olmalı.');
  }
  final text = parts[1].trim();
  final options = [parts[2].trim(), parts[3].trim(), parts[4].trim(), parts[5].trim()];
  if (text.isEmpty) return (row: null, error: 'Satır $line: soru boş.');
  if (options.any((option) => option.isEmpty)) return (row: null, error: 'Satır $line: şık boş.');
  final foldedOptions = [for (final option in options) bilgiDailyFold(option)];
  if (foldedOptions.toSet().length != 4) return (row: null, error: 'Satır $line: şıklar birbirinin kopyası.');
  final correct = switch (parts[6].trim().toUpperCase()) { 'A' => 0, 'B' => 1, 'C' => 2, 'D' => 3, _ => -1 };
  if (correct < 0) return (row: null, error: 'Satır $line: dogru A, B, C veya D olmalı.');
  final topic = parts[7].trim();
  if (topic.isEmpty) return (row: null, error: 'Satır $line: konu boş.');
  final difficulty = bilgiDailyFold(parts[8].trim());
  if (!bilgiDifficultyLevels.contains(difficulty)) {
    return (row: null, error: 'Satır $line: zorluk kolay, orta, zor veya efsane olmalı.');
  }
  final explanation = parts[9].trim();
  final hint = parts[10].trim();
  if (explanation.isEmpty) return (row: null, error: 'Satır $line: açıklama boş.');
  if (hint.length < 4 || hint.length > 500) {
    return (row: null, error: 'Satır $line: ipucu 4 ile 500 karakter olmalı.');
  }
  // İpucu kalite uyarıları (doğru şık / açıklama kopyası) softHints ile not olur; burada kesilmez.
  return (
    row: {
      'text': text,
      'options': options,
      'correct': correct,
      'difficulty': difficulty,
      'topic': topic,
      'explanation': explanation,
      'hint': hint,
      '_spare': kind == 'yedek',
    },
    error: null,
  );
}

BilgiQuestion _dailyQuestion(Map<String, dynamic> row, String id) {
  return BilgiQuestion(
    id: id,
    categoryId: tumuKarmaId,
    text: '${row['text']}',
    options: [for (final option in row['options'] as List) '$option'],
    correct: row['correct'] as int,
    difficulty: '${row['difficulty']}',
    explanation: '${row['explanation']}',
    hint: '${row['hint']}',
    status: 'approved',
    tags: ['Günlük', '${row['topic']}'],
    reviewed: true,
  );
}
