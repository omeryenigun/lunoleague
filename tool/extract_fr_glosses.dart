import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

const _drop = {
  'PUTES',
  'SALAUDS',
  'MERDES',
  'MERDER',
  'EMMERDE',
  'DEMERDE',
  'BAISERS',
  'BAISERA',
  'BITES',
  'COUILLE',
  'COUILLU',
  'CHIOTTE',
  'BORDELS',
};

final _conj = RegExp(
  r'(?:indicative|subjunctive|imperative|participle|gerund|conditional|preterite|imperfect|past historic|simple past|future tense|present tense|past tense|person) of ([^\s,;]+)\s*\.?\s*$',
  caseSensitive: false,
);
final _inflection = RegExp(
  r'^(?:inflection of |form of |forme de )([^:,.]+)',
  caseSensitive: false,
);

Future<void> main(List<String> args) async {
  final order = <String>[];
  final wanted = <String>{};
  for (final raw in File('wordlists/fr.txt').readAsLinesSync()) {
    final word = _key(raw);
    if (word.isEmpty || _drop.contains(word)) continue;
    final length = GameLocale.fr.letterCount(word);
    if (!GameLocale.fr.isAllowedWord(word) || length < 5 || length > 7) continue;
    if (!wanted.add(word)) continue;
    order.add(word);
  }
  final glosses = <String, String>{};
  final input = File(
    args.isEmpty ? r'C:\Users\omery\AppData\Local\Temp\fr-wiki.jsonl' : args.first,
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
    if (!line.contains('"lang_code":"fr"') && !line.contains('"lang_code": "fr"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map || decoded['lang_code'] != 'fr') continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty || word.contains(' ') || word.contains('-')) {
      continue;
    }
    final gloss = _sense(decoded['senses']);
    if (gloss == null) continue;
    final lemma = _key(word);
    if (wanted.contains(lemma)) _put(glosses, lemma, gloss);
    final forms = decoded['forms'];
    if (forms is! List || _rank(gloss) < 3) continue;
    final short = gloss.split(';').first.trim();
    final formGloss = _clean('Forme de $word: $short');
    if (formGloss == null) continue;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ') || text.contains('-')) continue;
      final key = _key(text);
      if (key == lemma || !wanted.contains(key)) continue;
      _put(glosses, key, formGloss);
    }
  }

  final kept = [for (final word in order) if (glosses.containsKey(word)) word];
  final glossBuf = StringBuffer()
    ..writeln('/// Short senses for the French frequency list.')
    ..writeln('/// Source: French Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('const frGlosses = <String, String>{');
  for (final word in kept) {
    glossBuf.writeln("  '$word': '${_dart(glosses[word]!)}',");
  }
  glossBuf.writeln('};');
  File('lib/data/local/fr_glosses.dart').writeAsStringSync(glossBuf.toString());

  final listBuf = StringBuffer()
    ..writeln('/// Common French words, most frequent first.')
    ..writeln('/// Accents are already folded, so école is stored as ECOLE.')
    ..writeln("import 'package:kelimelig/data/local/fr_glosses.dart';")
    ..writeln()
    ..writeln('const frFrequencyWords = <String>[')
  ;
  for (final word in kept) {
    listBuf.writeln("  '$word',");
  }
  listBuf
    ..writeln('];')
    ..writeln()
    ..writeln(r'''
String get frFrequencyWordsCsv {
  final rows = StringBuffer('word,language,definition,example,english,category,difficulty,frequency,status')
      ..writeln();
  for (final word in frFrequencyWords) {
    final gloss = (frGlosses[word] ?? '').replaceAll(',', ';').replaceAll('"', '');
    if (gloss.isEmpty) continue;
    rows.writeln('$word,fr,$gloss,,,general,2,3,active');
  }
  return rows.toString();
}
''');
  File('lib/data/local/fr_frequency_words.dart')
      .writeAsStringSync(listBuf.toString());
  stdout.writeln('glosses=${glosses.length} kept=${kept.length} wanted=${order.length}');
  for (final sample in ['ETAIT', 'FAIRE', 'MERCI', 'AVOIR', 'ECOLE']) {
    stdout.writeln('$sample => ${glosses[sample]}');
  }
}

/// Match form: vowel accents and ç fold. œ becomes OE, as in the word list.
String _key(String raw) =>
    GameLocale.fr.toUpper(raw).replaceAll('Œ', 'OE').replaceAll('Æ', 'AE');

void _put(Map<String, String> glosses, String key, String gloss) {
  final current = glosses[key];
  if (current == null || _rank(gloss) > _rank(current)) {
    glosses[key] = gloss;
  }
}

int _rank(String gloss) {
  if (_weak(gloss)) return 0;
  final lower = gloss.toLowerCase();
  if (lower.startsWith('forme de ') && lower.contains(':')) return 2;
  if (lower.startsWith('forme de ')) return 1;
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
      fallback ??= _forme(raw);
      continue;
    }
    final forme = _forme(raw);
    final text = forme ?? _clean(raw);
    if (text == null) continue;
    if (forme != null) {
      fallback ??= text;
      continue;
    }
    final clause = text.split(';').first.trim();
    return _clean(clause) ?? text;
  }
  return fallback;
}

String? _forme(String raw) {
  final match = _inflection.firstMatch(raw) ?? _conj.firstMatch(raw);
  if (match == null) return null;
  return _clean('Forme de ${match.group(1)!.trim()}');
}

String? _clean(String? raw) {
  if (raw == null) return null;
  var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
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
