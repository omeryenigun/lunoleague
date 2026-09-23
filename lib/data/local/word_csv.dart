/// Sözlük CSV'si. İlk satır kolon adlarıdır.
const wordCsvHeaders = <String>[
  'word',
  'language',
  'definition',
  'example',
  'english',
  'category',
  'difficulty',
  'frequency',
  'status',
];

const wordCsvHeaderError =
    'CSV başlığı word,language,definition,example,english,category,difficulty,frequency,status olmalı.';

class WordCsvDocument {
  const WordCsvDocument({this.headerError, this.rows = const []});

  final String? headerError;
  final List<List<String>> rows;
}

WordCsvDocument parseWordCsv(String source) {
  var text = source;
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.trim().isEmpty) {
    return const WordCsvDocument(headerError: wordCsvHeaderError);
  }
  final delimiter = _delimiter(text);
  final records = _records(text, delimiter);
  if (records.isEmpty) {
    return const WordCsvDocument(headerError: wordCsvHeaderError);
  }
  final header = records.first.map((cell) => cell.trim().toLowerCase()).toList();
  if (header.length != wordCsvHeaders.length ||
      !_sameHeader(header, wordCsvHeaders)) {
    return const WordCsvDocument(headerError: wordCsvHeaderError);
  }
  return WordCsvDocument(rows: records.skip(1).toList(growable: false));
}

bool _sameHeader(List<String> header, List<String> expected) {
  for (var i = 0; i < expected.length; i++) {
    if (header[i] != expected[i]) return false;
  }
  return true;
}

String _delimiter(String text) {
  var commas = 0;
  var semicolons = 0;
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        i++;
      } else {
        quoted = !quoted;
      }
      continue;
    }
    if (quoted) continue;
    if (char == '\n') break;
    if (char == ',') commas++;
    if (char == ';') semicolons++;
  }
  return semicolons > commas ? ';' : ',';
}

List<List<String>> _records(String text, String delimiter) {
  final records = <List<String>>[];
  final row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    if (row.any((cell) => cell.trim().isNotEmpty)) {
      records.add(List<String>.of(row));
    }
    row.clear();
  }

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        field.write(char);
      }
      continue;
    }
    if (char == '"') {
      quoted = true;
    } else if (char == delimiter) {
      endField();
    } else if (char == '\n') {
      endRow();
    } else {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return records;
}
