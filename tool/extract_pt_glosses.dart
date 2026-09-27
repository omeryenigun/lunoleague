import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

/// Everyday words that the blocklist also names. They stay.
const _keep = {
  'ABORTO',
  'AMADOR',
  'ARANHA',
  'BISSEXUAL',
  'BURRO',
  'CERVEJA',
  'COMER',
  'HETEROSEXUAL',
  'HOMOEROTICO',
  'HOMOSEXUAL',
  'INFERNO',
  'LESBICA',
  'MAMA',
  'SACO',
  'TORNEIRA',
};

final _conj = RegExp(
  r'(?:indicative|subjunctive|imperative|participle|gerund|conditional|preterite|imperfect|past historic|simple past|future tense|present tense|past tense|person) of ([^\s,;]+)\s*\.?\s*$',
  caseSensitive: false,
);
final _inflection = RegExp(
  r'^(?:inflection of |form of |forma de |flexão de |flexao de |plural de )([^:,.]+)',
  caseSensitive: false,
);

Future<void> main(List<String> args) async {
  final freqPath = args.isNotEmpty
      ? args[0]
      : r'C:\Users\omery\AppData\Local\Temp\luno-pt\pt_50k.txt';
  final badPath = args.length > 1
      ? args[1]
      : r'C:\Users\omery\AppData\Local\Temp\luno-pt\bad-pt.txt';
  final wikiPath = args.length > 2
      ? args[2]
      : r'C:\Users\omery\AppData\Local\Temp\luno-pt\pt-extract.jsonl.gz';

  final drop = <String>{};
  for (final raw in File(badPath).readAsLinesSync()) {
    final word = GameLocale.pt.toUpper(raw);
    if (word.isEmpty || word.contains(' ') || _keep.contains(word)) continue;
    drop.add(word);
  }

  final order = <String>[];
  final wanted = <String>{};
  var dropped = 0;
  for (final raw in File(freqPath).readAsLinesSync()) {
    final token = raw.trim().split(RegExp(r'\s+')).first;
    final word = GameLocale.pt.toUpper(token);
    if (word.isEmpty) continue;
    if (drop.contains(word)) {
      dropped++;
      continue;
    }
    final length = GameLocale.pt.letterCount(word);
    if (!GameLocale.pt.isAllowedWord(word) || length < 5 || length > 7) continue;
    if (!wanted.add(word)) continue;
    order.add(word);
  }

  final listBuf = StringBuffer();
  for (final word in order) {
    listBuf.writeln(word);
  }
  File('wordlists/pt.txt').writeAsStringSync(listBuf.toString());

  final glosses = <String, String>{};
  final lines = File(wikiPath)
      .openRead()
      .transform(gzip.decoder)
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  var seen = 0;
  await for (final line in lines) {
    seen++;
    if (seen % 20000 == 0) {
      stdout.writeln('seen=$seen glosses=${glosses.length}');
    }
    if (!line.contains('"lang_code":"pt"') && !line.contains('"lang_code": "pt"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map || decoded['lang_code'] != 'pt') continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty || word.contains(' ') || word.contains('-')) {
      continue;
    }
    final gloss = _sense(decoded['senses']);
    if (gloss == null) continue;
    final lemma = GameLocale.pt.toUpper(word);
    if (drop.contains(lemma)) continue;
    if (wanted.contains(lemma)) _put(glosses, lemma, gloss);
    final forms = decoded['forms'];
    if (forms is! List || _rank(gloss) < 3) continue;
    final short = gloss.split(';').first.trim();
    final formGloss = _clean('Forma de $word: $short');
    if (formGloss == null) continue;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ') || text.contains('-')) continue;
      final key = GameLocale.pt.toUpper(text);
      if (key == lemma || drop.contains(key) || !wanted.contains(key)) continue;
      _put(glosses, key, formGloss);
    }
  }

  final kept = [for (final word in order) if (glosses.containsKey(word)) word];
  final glossBuf = StringBuffer()
    ..writeln('/// Short senses for the Portuguese frequency list.')
    ..writeln('/// Source: Portuguese Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('const ptGlosses = <String, String>{');
  for (final word in kept) {
    glossBuf.writeln("  '$word': '${_dart(glosses[word]!)}',");
  }
  glossBuf.writeln('};');
  File('lib/data/local/pt_glosses.dart').writeAsStringSync(glossBuf.toString());

  final wordsBuf = StringBuffer()
    ..writeln('/// Common Portuguese words, most frequent first.')
    ..writeln('/// Accents are already folded, so ação is stored as ACAO.')
    ..writeln("import 'package:kelimelig/data/local/pt_glosses.dart';")
    ..writeln()
    ..writeln('const ptFrequencyWords = <String>[')
  ;
  for (final word in kept) {
    wordsBuf.writeln("  '$word',");
  }
  wordsBuf
    ..writeln('];')
    ..writeln()
    ..writeln(r'''
String get ptFrequencyWordsCsv {
  final rows = StringBuffer('word,language,definition,example,english,category,difficulty,frequency,status')
      ..writeln();
  for (final word in ptFrequencyWords) {
    final gloss = (ptGlosses[word] ?? '').replaceAll(',', ';').replaceAll('"', '');
    if (gloss.isEmpty) continue;
    rows.writeln('$word,pt,$gloss,,,geral,2,3,active');
  }
  return rows.toString();
}
''');
  File('lib/data/local/pt_frequency_words.dart').writeAsStringSync(wordsBuf.toString());
  stdout.writeln(
    'candidates=${order.length} dropped=$dropped glosses=${glosses.length} kept=${kept.length} seen=$seen',
  );
  for (final sample in ['NOITE', 'CIDADE', 'PORQUE', 'FAMILIA', 'ACAO', 'CORACAO']) {
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
  if (lower.startsWith('forma de ') && lower.contains(':')) return 2;
  if (lower.startsWith('forma de ')) return 1;
  return 3;
}

bool _weak(String gloss) {
  final text = gloss.toLowerCase();
  return text.startsWith('gerund of ') ||
      text.startsWith('plural of ') ||
      text.startsWith('plural de ') ||
      text.startsWith('feminine of ') ||
      text.startsWith('masculine of ') ||
      text.startsWith('feminino de ') ||
      text.startsWith('masculino de ') ||
      text.startsWith('flexão de ') ||
      text.startsWith('flexao de ') ||
      text.startsWith('inflection of ') ||
      text.startsWith('form of ') ||
      text.startsWith('forma de ') ||
      text.startsWith('alternative form of ') ||
      text.startsWith('alternative spelling of ') ||
      text.startsWith('obsolete') ||
      text.startsWith('archaic') ||
      text.startsWith('misspelling of ') ||
      text.startsWith('verbo ') ||
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
  return _clean('Forma de ${match.group(1)!.trim()}');
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
