import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

/// Everyday tokens that appear on blocklists but stay playable.
const _keep = <String>{};

/// Extra exact vulgar tokens beyond LDNOOBW (A-Z).
const _extraExact = {
  'FUCKS',
  'FUCKER',
  'FUCKED',
  'FUCKING',
  'SHITS',
  'SHITTY',
  'BITCH',
  'BITCHY',
  'BITCHES',
  'ASSHOLE',
  'ARSEHOLE',
  'CUNTS',
  'PRICKS',
  'WANKER',
  'WANKERS',
  'PORNO',
  'PORNOS',
  'NIGGER',
  'NIGGERS',
  'FAGGOT',
  'FAGGOTS',
  'RETARD',
  'SLUTTY',
  'WHORES',
  'PUSSY',
  'PUSSIES',
  'COCKS',
  'DICKS',
  'DILDOS',
  'HORNY',
};

final _conj = RegExp(
  r'(?:indicative|subjunctive|imperative|participle|gerund|conditional|preterite|imperfect|past historic|simple past|future tense|present tense|past tense|person) of ([^\s,;]+)\s*\.?\s*$',
  caseSensitive: false,
);
final _inflection = RegExp(
  r'^(?:inflection of |form of |plural of |present participle of |past participle of |simple past of |third-person singular simple present indicative of )([^:,.]+)',
  caseSensitive: false,
);

bool _isBlocked(String word, Set<String> drop) {
  if (_keep.contains(word)) return false;
  return drop.contains(word);
}

Future<void> main(List<String> args) async {
  final freqPath = args.isNotEmpty
      ? args[0]
      : r'C:\Users\omery\AppData\Local\Temp\luno-en\en_50k.txt';
  final badPath = args.length > 1
      ? args[1]
      : r'C:\Users\omery\AppData\Local\Temp\luno-en\bad-en.txt';
  final wikiPath = args.length > 2
      ? args[2]
      : r'C:\Users\omery\AppData\Local\Temp\luno-en\en-extract.jsonl.gz';

  final drop = <String>{..._extraExact};
  for (final raw in File(badPath).readAsLinesSync()) {
    final token = raw.trim().split(RegExp(r'\s+')).first;
    final word = GameLocale.en.toUpper(token);
    if (word.isEmpty || word.contains(' ') || _keep.contains(word)) continue;
    final n = GameLocale.en.letterCount(word);
    if (n < 5 || n > 7) continue;
    drop.add(word);
  }

  final order = <String>[];
  final wanted = <String>{};
  var dropped = 0;
  for (final raw in File(freqPath).readAsLinesSync()) {
    final token = raw.trim().split(RegExp(r'\s+')).first;
    if (token.isEmpty || RegExp(r'\d').hasMatch(token)) continue;
    final word = GameLocale.en.toUpper(token);
    if (word.isEmpty) continue;
    if (_isBlocked(word, drop)) {
      dropped++;
      continue;
    }
    final length = GameLocale.en.letterCount(word);
    if (!GameLocale.en.isAllowedWord(word) || length < 5 || length > 7) continue;
    if (!wanted.add(word)) continue;
    order.add(word);
  }

  File('wordlists/en.txt').writeAsStringSync('${order.join('\n')}\n');

  final glosses = <String, String>{};
  final lines = File(wikiPath)
      .openRead()
      .transform(gzip.decoder)
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  var seen = 0;
  await for (final line in lines) {
    seen++;
    if (seen % 50000 == 0) {
      stdout.writeln('seen=$seen glosses=${glosses.length}');
    }
    if (!line.contains('"lang_code":"en"') && !line.contains('"lang_code": "en"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map || decoded['lang_code'] != 'en') continue;
    final pos = decoded['pos']?.toString().toLowerCase() ?? '';
    if (pos == 'name' || pos == 'proper noun' || pos == 'prop') continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty || word.contains(' ') || word.contains('-')) {
      continue;
    }
    final gloss = _sense(decoded['senses']);
    if (gloss == null) continue;
    final lemma = GameLocale.en.toUpper(word);
    if (!GameLocale.en.isAllowedWord(lemma)) continue;
    final length = GameLocale.en.letterCount(lemma);
    if (length < 5 || length > 7) continue;
    if (_isBlocked(lemma, drop)) continue;
    if (wanted.contains(lemma)) _put(glosses, lemma, gloss);

    final forms = decoded['forms'];
    if (forms is! List || _rank(gloss) < 3) continue;
    final short = gloss.split(';').first.trim();
    final formGloss = _clean('Form of $word: $short');
    if (formGloss == null) continue;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ') || text.contains('-')) continue;
      final formWord = GameLocale.en.toUpper(text);
      if (!GameLocale.en.isAllowedWord(formWord)) continue;
      final formLen = GameLocale.en.letterCount(formWord);
      if (formLen < 5 || formLen > 7) continue;
      if (_isBlocked(formWord, drop)) continue;
      if (!wanted.contains(formWord) || formWord == lemma) continue;
      _put(glosses, formWord, formGloss);
    }
  }

  final kept = <String>[];
  final keptGlosses = <String, String>{};
  for (final word in order) {
    final gloss = glosses[word];
    if (gloss == null || gloss.isEmpty) continue;
    if (_isBlocked(word, drop)) continue;
    kept.add(word);
    keptGlosses[word] = gloss;
  }

  final glossBuf = StringBuffer()
    ..writeln('/// Short senses for the English frequency list.')
    ..writeln('/// Source: English Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('const enGlosses = <String, String>{');
  for (final word in kept) {
    glossBuf.writeln("  '$word': '${_dart(keptGlosses[word]!)}',");
  }
  glossBuf.writeln('};');
  File('lib/data/local/en_glosses.dart').writeAsStringSync(glossBuf.toString());

  final wordsBuf = StringBuffer()
    ..writeln('/// Common English words, most frequent first.')
    ..writeln('/// Accents are folded to plain A-Z.')
    ..writeln('/// Frequency from HermitDave FrequencyWords (OpenSubtitles 2018).')
    ..writeln("import 'package:kelimelig/data/local/en_glosses.dart';")
    ..writeln()
    ..writeln('const enFrequencyWords = <String>[');
  for (final word in kept) {
    wordsBuf.writeln("  '$word',");
  }
  wordsBuf
    ..writeln('];')
    ..writeln()
    ..writeln(r'''
String get enFrequencyWordsCsv {
  final rows = StringBuffer('word,language,definition,example,english,category,difficulty,frequency,status')
      ..writeln();
  for (final word in enFrequencyWords) {
    final gloss = (enGlosses[word] ?? '').replaceAll(',', ';').replaceAll('"', '');
    if (gloss.isEmpty) continue;
    rows.writeln('$word,en,$gloss,,,general,2,3,active');
  }
  return rows.toString();
}
''');
  File('lib/data/local/en_frequency_words.dart').writeAsStringSync(wordsBuf.toString());

  var c5 = 0, c6 = 0, c7 = 0;
  for (final word in kept) {
    switch (GameLocale.en.letterCount(word)) {
      case 5:
        c5++;
      case 6:
        c6++;
      case 7:
        c7++;
    }
  }
  stdout.writeln(
    'candidates=${order.length} dropped=$dropped glosses=${glosses.length} kept=${kept.length} seen=$seen lengths=5:$c5 6:$c6 7:$c7',
  );
  for (final sample in ['ABOUT', 'THERE', 'WORLD', 'SCHOOL', 'FRIEND', 'FAMILY', 'SHOULD']) {
    stdout.writeln('$sample gloss=${glosses[sample]}');
  }
  for (final bad in ['BITCH', 'FUCKER', 'ASSHOLE', 'PORNO', 'NIGGER', 'WANKER']) {
    stdout.writeln('blocked $bad inKept=${kept.contains(bad)}');
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
  if (lower.startsWith('form of ') && lower.contains(':')) return 2;
  if (lower.startsWith('form of ')) return 1;
  return 3;
}

bool _weak(String gloss) {
  final text = gloss.toLowerCase();
  return text.startsWith('gerund of ') ||
      text.startsWith('plural of ') ||
      text.startsWith('feminine of ') ||
      text.startsWith('masculine of ') ||
      text.startsWith('inflection of ') ||
      text.startsWith('form of ') ||
      text.startsWith('present participle of ') ||
      text.startsWith('past participle of ') ||
      text.startsWith('simple past of ') ||
      text.startsWith('third-person singular') ||
      text.startsWith('alternative form of ') ||
      text.startsWith('alternative spelling of ') ||
      text.startsWith('obsolete') ||
      text.startsWith('archaic') ||
      text.startsWith('misspelling of ');
}

String? _sense(Object? senses) {
  if (senses is! List) return null;
  String? fallback;
  for (final sense in senses) {
    if (sense is! Map) continue;
    final tags = sense['tags'];
    if (tags is List &&
        tags.any((t) =>
            t.toString().toLowerCase().contains('name') ||
            t.toString().toLowerCase() == 'surname' ||
            t.toString().toLowerCase() == 'given-name')) {
      continue;
    }
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
  return _clean('Form of ${match.group(1)!.trim()}');
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
