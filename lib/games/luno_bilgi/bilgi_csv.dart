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
