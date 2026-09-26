import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

const _drop = {
  'FOTTUTO',
  'FOTTUTA',
  'FOTTITI',
  'FOTTUTI',
  'FOTTA',
  'FOTTE',
  'FOTTUTE',
  'FOTTANO',
  'FOTTO',
  'FOTTI',
  'FOTTONO',
  'FOTTIO',
  'FOTTIMI',
  'FIGHE',
  'FIGATA',
  'TROIE',
  'INCAZZA',
  'INCAZZO',
  'INCAZZI',
  'MERDOSA',
  'MERDINA',
  'MERDATE',
  'MERDOSI',
  'CULONE',
  'CULONA',
};

final _conj = RegExp(
  r'(?:indicative|subjunctive|imperative|participle|gerund|conditional|preterite|imperfect|past historic|simple past|future tense|present tense|past tense|person) of ([^\s,;]+)\s*\.?\s*$',
  caseSensitive: false,
);
final _inflection = RegExp(
  r'^(?:inflection of |form of |forma di )([^:,.]+)',
  caseSensitive: false,
);

Future<void> main(List<String> args) async {
  final order = <String>[];
  final wanted = <String>{};
  for (final raw in File('wordlists/it.txt').readAsLinesSync()) {
    final word = GameLocale.it.toUpper(raw);
    if (word.isEmpty || _drop.contains(word)) continue;
    final length = GameLocale.it.letterCount(word);
    if (!GameLocale.it.isAllowedWord(word) || length < 5 || length > 7) continue;
    if (!wanted.add(word)) continue;
    order.add(word);
  }
  final glosses = <String, String>{};
  final input = File(
    args.isEmpty ? r'C:\Users\omery\AppData\Local\Temp\it-wiki.jsonl' : args.first,
  );
  final lines = input
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  var seen = 0;
  await for (final line in lines) {
    seen++;
    if (seen % 20000 == 0) {
      stdout.writeln('seen=$seen glosses=${glosses.length}');
    }
    if (!line.contains('"lang_code":"it"') && !line.contains('"lang_code": "it"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map || decoded['lang_code'] != 'it') continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty || word.contains(' ') || word.contains('-')) {
      continue;
    }
    final gloss = _sense(decoded['senses']);
    if (gloss == null) continue;
    final lemma = GameLocale.it.toUpper(word);
    if (wanted.contains(lemma)) _put(glosses, lemma, gloss);
    final forms = decoded['forms'];
    if (forms is! List || _rank(gloss) < 3) continue;
    final short = gloss.split(';').first.trim();
    final formGloss = _clean('Forma di $word: $short');
    if (formGloss == null) continue;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ') || text.contains('-')) continue;
      final key = GameLocale.it.toUpper(text);
      if (key == lemma || !wanted.contains(key)) continue;
      _put(glosses, key, formGloss);
    }
  }

  final kept = [for (final word in order) if (glosses.containsKey(word)) word];
  final glossBuf = StringBuffer()
    ..writeln('/// Short senses for the Italian frequency list.')
    ..writeln('/// Source: Italian Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('const itGlosses = <String, String>{');
  for (final word in kept) {
    glossBuf.writeln("  '$word': '${_dart(glosses[word]!)}',");
  }
  glossBuf.writeln('};');
  File('lib/data/local/it_glosses.dart').writeAsStringSync(glossBuf.toString());

  final listBuf = StringBuffer()
    ..writeln('/// Common Italian words, most frequent first.')
    ..writeln('/// Accents are already folded, so città is stored as CITTA.')
    ..writeln("import 'package:kelimelig/data/local/it_glosses.dart';")
    ..writeln()
    ..writeln('const itFrequencyWords = <String>[')
  ;
  for (final word in kept) {
    listBuf.writeln("  '$word',");
  }
  listBuf
    ..writeln('];')
    ..writeln()
    ..writeln(r'''
String get itFrequencyWordsCsv {
  final rows = StringBuffer('word,language,definition,example,english,category,difficulty,frequency,status')
      ..writeln();
  for (final word in itFrequencyWords) {
    final gloss = (itGlosses[word] ?? '').replaceAll(',', ';').replaceAll('"', '');
    if (gloss.isEmpty) continue;
    rows.writeln('$word,it,$gloss,,,general,2,3,active');
  }
  return rows.toString();
}
''');
  File('lib/data/local/it_frequency_words.dart')
      .writeAsStringSync(listBuf.toString());
  stdout.writeln('glosses=${glosses.length} kept=${kept.length} wanted=${order.length}');
  for (final sample in ['QUESTO', 'ESSERE', 'GRAZIE', 'PERCHE', 'CITTA']) {
    stdout.writeln('$sample => ${glosses[sample]}');
  }
}

void _put(Map<String, String> glosses, String key, String gloss) {
  final current = glosses[key];
  if (current == null || _rank(gloss) > _rank(current)) {
    glosses[key] = gloss;
  }
}

int _rank(String gloss) {
  if (_weak(gloss)) return 0;
  final lower = gloss.toLowerCase();
  if (lower.startsWith('forma di ') && lower.contains(':')) return 2;
  if (lower.startsWith('forma di ')) return 1;
  return 3;
}

bool _weak(String gloss) {
  final text = gloss.toLowerCase();
  return text.startsWith('gerund of ') ||
      text.startsWith('plural of ') ||
      text.startsWith('plural form of ') ||
      text.startsWith('feminine of ') ||
      text.startsWith('masculine of ') ||
      text.startsWith('feminine plural of ') ||
      text.startsWith('masculine plural of ') ||
      text.startsWith('female equivalent') ||
      text.startsWith('inflection of ') ||
      text.startsWith('form of ') ||
      text.startsWith('alternative form of ') ||
      text.startsWith('alternative spelling of ') ||
      text.startsWith('obsolete') ||
      text.startsWith('archaic') ||
      text.startsWith('misspelling of ') ||
      text.startsWith('forms the ');
}

String? _sense(Object? senses) {
  if (senses is! List) return null;
  String? fallback;
  for (final sense in senses) {
    if (sense is! Map) continue;
    final glosses = sense['glosses'];
    if (glosses is! List || glosses.isEmpty) continue;
    final raw = glosses.first.toString();
    if (_weak(raw)) {
      fallback ??= _forma(raw);
      continue;
    }
    final forma = _forma(raw);
    final text = forma ?? _clean(raw);
    if (text == null) continue;
    if (forma != null) {
      fallback ??= text;
      continue;
    }
    final clause = text.split(';').first.trim();
    return _clean(clause) ?? text;
  }
  return fallback;
}

String? _forma(String raw) {
  final match = _inflection.firstMatch(raw) ?? _conj.firstMatch(raw);
  if (match == null) return null;
  return _clean('Forma di ${match.group(1)!.trim()}');
}

String? _clean(String? raw) {
  if (raw == null) return null;
  var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceFirst(
    RegExp(r'^Used as a copula\.\s*', caseSensitive: false),
    '',
  );
  if (text.isEmpty || text.length < 3) return null;
  if (text.length > 140) {
    final cut = text.lastIndexOf(' ', 140);
    text = text.substring(0, cut < 40 ? 140 : cut).trim();
    if (!text.endsWith('.')) text = '$text.';
  }
  return text;
}

String _dart(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');
