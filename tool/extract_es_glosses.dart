import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

const _drop = {'HOSTIA', 'HOSTIAS', 'FOLLON', 'COÑOS'};

final _inflection = RegExp(
  r'^(?:inflection of |forma de |forma del |flexión de |flexion de )([^:,]+)',
  caseSensitive: false,
);
final _verbForm = RegExp(
  r'(?:indicative|subjunctive|imperative|participle|gerund|conditional|preterite|imperfect) of ([^\s,;]+)\s*$',
  caseSensitive: false,
);

Future<void> main(List<String> args) async {
  final order = <String>[];
  final wanted = <String>{};
  for (final raw in File('wordlists/es.txt').readAsLinesSync()) {
    final word = GameLocale.es.toUpper(raw);
    if (word.isEmpty || _drop.contains(word)) continue;
    final length = GameLocale.es.letterCount(word);
    if (!GameLocale.es.isAllowedWord(word) || length < 5 || length > 7) continue;
    if (!wanted.add(word)) continue;
    order.add(word);
  }
  final glosses = <String, String>{};
  final input = File(
    args.isEmpty ? r'C:\Users\omery\AppData\Local\Temp\es-wiki.jsonl' : args.first,
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
    if (!line.contains('"lang_code":"es"') && !line.contains('"lang_code": "es"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map) continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty || word.contains(' ')) continue;
    final gloss = _sense(decoded['senses']);
    if (gloss == null) continue;
    final lemma = GameLocale.es.toUpper(word);
    if (wanted.contains(lemma)) _put(glosses, lemma, gloss);
    final forms = decoded['forms'];
    if (forms is! List) continue;
    final formGloss =
        _clean('Forma de $word: ${gloss.split(';').first.trim()}') ?? gloss;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ')) continue;
      final key = GameLocale.es.toUpper(text);
      if (key == lemma || !wanted.contains(key)) continue;
      _put(glosses, key, formGloss);
    }
    if (glosses.length == wanted.length) break;
  }

  final kept = [for (final word in order) if (glosses.containsKey(word)) word];
  final glossBuf = StringBuffer()
    ..writeln('/// Short senses for the Spanish frequency list.')
    ..writeln('/// Source: Spanish Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('const esGlosses = <String, String>{');
  for (final word in kept) {
    glossBuf.writeln("  '$word': '${_dart(glosses[word]!)}',");
  }
  glossBuf.writeln('};');
  File('lib/data/local/es_glosses.dart').writeAsStringSync(glossBuf.toString());

  final listBuf = StringBuffer()
    ..writeln('/// Common Spanish words, most frequent first.')
    ..writeln('/// Ñ stays. Vowel accents in the source list are already folded.')
    ..writeln("import 'package:kelimelig/data/local/es_glosses.dart';")
    ..writeln()
    ..writeln('const esFrequencyWords = <String>[')
  ;
  for (final word in kept) {
    listBuf.writeln("  '$word',");
  }
  listBuf
    ..writeln('];')
    ..writeln()
    ..writeln(r'''
String get esFrequencyWordsCsv {
  final rows = StringBuffer('word,language,definition,example,english,category,difficulty,frequency,status')
      ..writeln();
  for (final word in esFrequencyWords) {
    final gloss = (esGlosses[word] ?? '').replaceAll(',', ';').replaceAll('"', '');
    if (gloss.isEmpty) continue;
    rows.writeln('$word,es,$gloss,,,general,2,3,active');
  }
  return rows.toString();
}
''');
  File('lib/data/local/es_frequency_words.dart').writeAsStringSync(listBuf.toString());
  stdout.writeln('glosses=${glosses.length} kept=${kept.length} wanted=${order.length}');
  for (final sample in ['ESTOY', 'GRACIAS', 'MAÑANA', 'CAÑON', 'TIENE']) {
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
  if (gloss.toLowerCase().startsWith('forma de ')) return 1;
  return 2;
}

bool _weak(String gloss) {
  final text = gloss.toLowerCase();
  return text.startsWith('gerund of ') ||
      text.startsWith('gerundio') ||
      text.startsWith('plural de ') ||
      text.startsWith('plural of ') ||
      text.startsWith('femenino de ') ||
      text.startsWith('masculino de ') ||
      text.startsWith('participio') ||
      text.startsWith('inflection of ') ||
      text.startsWith('flexión de ') ||
      text.startsWith('flexion de ') ||
      text.startsWith('forma verbal') ||
      text.startsWith('obsolete') ||
      text.startsWith('obsoleto');
}

String? _sense(Object? senses) {
  if (senses is! List) return null;
  String? fallback;
  for (final sense in senses) {
    if (sense is! Map) continue;
    final glosses = sense['glosses'];
    if (glosses is! List || glosses.isEmpty) continue;
    final raw = glosses.first.toString();
    final inflection = _inflection.firstMatch(raw) ?? _verbForm.firstMatch(raw);
    final text = inflection != null
        ? _clean('Forma de ${inflection.group(1)!.trim()}')
        : _clean(raw);
    if (text == null || _weak(text)) {
      fallback ??= text;
      continue;
    }
    final clause = text.split(';').first.trim();
    return _clean(clause) ?? text;
  }
  return fallback;
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
