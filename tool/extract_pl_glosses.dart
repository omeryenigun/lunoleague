import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

/// Everyday words that the blocklist also names. They stay.
const _keep = {
  'JAJKO',
};

/// Exact swear / slur tokens (LDNOOBW + common forms).
const _extraExact = {
  'CHUJ',
  'CHUJA',
  'CHUJE',
  'CHUJU',
  'CHUJEM',
  'CHUJOM',
  'CHUJÓW',
  'CHUJAMI',
  'CHUJNIA',
  'CHUJOWO',
  'CIPA',
  'CIPY',
  'CIPĘ',
  'CIPIE',
  'CIPĄ',
  'CIPOM',
  'DEBIL',
  'DEBILA',
  'DEBILE',
  'DEBILI',
  'DEBILU',
  'DUPA',
  'DUPY',
  'DUPĘ',
  'DUPIE',
  'DUPĄ',
  'DUPEK',
  'DUPKA',
  'DUPKI',
  'DUPKU',
  'FIUT',
  'FIUTA',
  'FIUTY',
  'FIUTEM',
  'FIUTOWI',
  'GÓWNO',
  'GÓWNA',
  'GÓWNIE',
  'GÓWNEM',
  'GOWNO',
  'GOWNA',
  'HUJ',
  'HUJA',
  'HUJE',
  'HUJU',
  'JEBAĆ',
  'JEBAC',
  'JEBANY',
  'JEBANA',
  'JEBANE',
  'JEBANI',
  'JEBANĄ',
  'JEBNĄĆ',
  'JEBNIJ',
  'KURWA',
  'KURWY',
  'KURWĘ',
  'KURWO',
  'KURWĄ',
  'KURWIE',
  'KURWOM',
  'KUTAS',
  'KUTASA',
  'KUTASY',
  'KUTASEM',
  'KUTASIE',
  'PIERDOL',
  'PIZDA',
  'PIZDY',
  'PIZDĘ',
  'PIŹDZIE',
  'PIZDĄ',
  'POJEB',
  'POJEBA',
  'POJEBY',
  'POJEBIE',
  'PORNO',
  'RUCHAĆ',
  'RUCHAC',
  'SKURWY',
  'SRACZ',
  'SRACZA',
  'SRAĆ',
  'SRAC',
  'SUKA',
  'SUKI',
  'SUKĘ',
  'SUKO',
  'SUKĄ',
  'SYF',
  'SYFU',
  'SYFEM',
  'WKURWI',
  'ZAJEBIE',
  'ZAJEBIS',
  'ZJEBIE',
};

/// Prefixes that mark vulgar derivatives (checked after fold).
const _badPrefixes = <String>[
  'CHUJ',
  'CIPA',
  'CIPY',
  'CIPĘ',
  'DEBIL',
  'DUPEK',
  'FIUT',
  'GOWN',
  'HUJ',
  'JEB',
  'KURW',
  'KUTAS',
  'PIERDOL',
  'PIZD',
  'POJEB',
  'SKURW',
  'SRAC',
  'ZAJEB',
  'ZJEB',
];

final _conj = RegExp(
  r'(?:indicative|subjunctive|imperative|participle|gerund|conditional|preterite|imperfect|past historic|simple past|future tense|present tense|past tense|person) of ([^\s,;]+)\s*\.?\s*$',
  caseSensitive: false,
);
final _inflection = RegExp(
  r'^(?:inflection of |form of |forma (?:odmiany )?|odmiana |zob\. |aspekt (?:dokonany|niedokonany) od[: ]+)([^:,.]+)',
  caseSensitive: false,
);

const _foldMap = <String, String>{
  'Ą': 'A',
  'Ć': 'C',
  'Ę': 'E',
  'Ł': 'L',
  'Ń': 'N',
  'Ó': 'O',
  'Ś': 'S',
  'Ź': 'Z',
  'Ż': 'Z',
};

String _fold(String word) {
  final buf = StringBuffer();
  for (final ch in word.runes.map(String.fromCharCode)) {
    buf.write(_foldMap[ch] ?? ch);
  }
  return buf.toString();
}

bool _isBlocked(String word, Set<String> drop) {
  if (_keep.contains(word)) return false;
  if (drop.contains(word) || drop.contains(_fold(word))) return true;
  final folded = _fold(word);
  for (final prefix in _badPrefixes) {
    if (folded.startsWith(prefix) || word.startsWith(prefix)) return true;
  }
  return false;
}

int _diacriticScore(String word) {
  var score = 0;
  for (final ch in word.runes.map(String.fromCharCode)) {
    if (_foldMap.containsKey(ch)) score++;
  }
  return score;
}

Future<void> main(List<String> args) async {
  final freqPath = args.isNotEmpty
      ? args[0]
      : r'C:\Users\omery\AppData\Local\Temp\luno-pl\pl_50k.txt';
  final badPath = args.length > 1
      ? args[1]
      : r'C:\Users\omery\AppData\Local\Temp\luno-pl\bad-pl.txt';
  final wikiPath = args.length > 2
      ? args[2]
      : r'C:\Users\omery\AppData\Local\Temp\luno-pl\pl-extract.jsonl.gz';

  final drop = <String>{..._extraExact};
  for (final raw in File(badPath).readAsLinesSync()) {
    final token = raw.trim().split(RegExp(r'\s+')).first;
    final word = GameLocale.pl.toUpper(token);
    if (word.isEmpty || word.contains(' ') || _keep.contains(word)) continue;
    drop.add(word);
    drop.add(_fold(word));
  }

  // foldKey -> first frequency spelling (usually ASCII from subtitles)
  final orderKeys = <String>[];
  final freqSpell = <String, String>{};
  var dropped = 0;
  for (final raw in File(freqPath).readAsLinesSync()) {
    final token = raw.trim().split(RegExp(r'\s+')).first;
    if (token.isEmpty || RegExp(r'\d').hasMatch(token)) continue;
    final word = GameLocale.pl.toUpper(token);
    if (word.isEmpty) continue;
    if (_isBlocked(word, drop)) {
      dropped++;
      continue;
    }
    final length = GameLocale.pl.letterCount(word);
    if (!GameLocale.pl.isAllowedWord(word) || length < 5 || length > 7) continue;
    final key = _fold(word);
    if (freqSpell.containsKey(key)) continue;
    freqSpell[key] = word;
    orderKeys.add(key);
  }

  final listBuf = StringBuffer();
  for (final key in orderKeys) {
    listBuf.writeln(freqSpell[key]);
  }
  File('wordlists/pl.txt').writeAsStringSync(listBuf.toString());

  final glosses = <String, String>{};
  final bestSpell = <String, String>{...freqSpell};
  final lemmaKeys = <String>{};

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
    if (!line.contains('"lang_code":"pl"') && !line.contains('"lang_code": "pl"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map || decoded['lang_code'] != 'pl') continue;
    final pos = decoded['pos']?.toString().toLowerCase() ?? '';
    if (pos == 'name' || pos == 'proper noun' || pos == 'prop') continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty || word.contains(' ') || word.contains('-')) {
      continue;
    }
    final gloss = _sense(decoded['senses']);
    if (gloss == null) continue;
    final lemma = GameLocale.pl.toUpper(word);
    if (!GameLocale.pl.isAllowedWord(lemma)) continue;
    final length = GameLocale.pl.letterCount(lemma);
    if (length < 5 || length > 7) continue;
    if (_isBlocked(lemma, drop)) continue;
    final key = _fold(lemma);
    if (!freqSpell.containsKey(key)) continue;
    // Dictionary headwords beat subtitle ASCII and inflected case forms.
    lemmaKeys.add(key);
    bestSpell[key] = lemma;
    _put(glosses, key, gloss);

    final forms = decoded['forms'];
    if (forms is! List || _rank(gloss) < 3) continue;
    final short = gloss.split(';').first.trim();
    final formGloss = _clean('Forma: $word — $short');
    if (formGloss == null) continue;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ') || text.contains('-')) continue;
      final formWord = GameLocale.pl.toUpper(text);
      if (!GameLocale.pl.isAllowedWord(formWord)) continue;
      final formLen = GameLocale.pl.letterCount(formWord);
      if (formLen < 5 || formLen > 7) continue;
      if (_isBlocked(formWord, drop)) continue;
      final formKey = _fold(formWord);
      if (!freqSpell.containsKey(formKey)) continue;
      if (!lemmaKeys.contains(formKey)) {
        _preferSpell(bestSpell, formKey, formWord);
      }
      _put(glosses, formKey, formGloss);
    }
  }

  final kept = <String>[];
  final keptGlosses = <String, String>{};
  for (final key in orderKeys) {
    final gloss = glosses[key];
    if (gloss == null || gloss.isEmpty) continue;
    final spell = bestSpell[key]!;
    if (_isBlocked(spell, drop)) continue;
    if (!GameLocale.pl.isAllowedWord(spell)) continue;
    final n = GameLocale.pl.letterCount(spell);
    if (n < 5 || n > 7) continue;
    kept.add(spell);
    keptGlosses[spell] = gloss;
  }

  final glossBuf = StringBuffer()
    ..writeln('/// Short senses for the Polish frequency list.')
    ..writeln('/// Source: Polish Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('const plGlosses = <String, String>{');
  for (final word in kept) {
    glossBuf.writeln("  '$word': '${_dart(keptGlosses[word]!)}',");
  }
  glossBuf.writeln('};');
  File('lib/data/local/pl_glosses.dart').writeAsStringSync(glossBuf.toString());

  final wordsBuf = StringBuffer()
    ..writeln('/// Common Polish words, most frequent first.')
    ..writeln('/// Polish diacritics stay: Ą Ć Ę Ł Ń Ó Ś Ź Ż.')
    ..writeln('/// Frequency from HermitDave FrequencyWords (OpenSubtitles 2018).')
    ..writeln("import 'package:kelimelig/data/local/pl_glosses.dart';")
    ..writeln()
    ..writeln('const plFrequencyWords = <String>[')
  ;
  for (final word in kept) {
    wordsBuf.writeln("  '$word',");
  }
  wordsBuf
    ..writeln('];')
    ..writeln()
    ..writeln(r'''
String get plFrequencyWordsCsv {
  final rows = StringBuffer('word,language,definition,example,english,category,difficulty,frequency,status')
      ..writeln();
  for (final word in plFrequencyWords) {
    final gloss = (plGlosses[word] ?? '').replaceAll(',', ';').replaceAll('"', '');
    if (gloss.isEmpty) continue;
    rows.writeln('$word,pl,$gloss,,,ogólne,2,3,active');
  }
  return rows.toString();
}
''');
  File('lib/data/local/pl_frequency_words.dart').writeAsStringSync(wordsBuf.toString());

  var c5 = 0, c6 = 0, c7 = 0;
  for (final word in kept) {
    switch (GameLocale.pl.letterCount(word)) {
      case 5:
        c5++;
      case 6:
        c6++;
      case 7:
        c7++;
    }
  }
  stdout.writeln(
    'candidates=${orderKeys.length} dropped=$dropped glosses=${glosses.length} kept=${kept.length} seen=$seen lengths=5:$c5 6:$c6 7:$c7',
  );
  for (final sample in ['SZKOŁA', 'RODZINA', 'BARDZO', 'SŁOŃCE', 'KSIĄŻKA', 'MOŻE', 'MOŻNA']) {
    final key = _fold(sample);
    stdout.writeln('$sample spell=${bestSpell[key]} gloss=${glosses[key]}');
  }
  for (final bad in ['KURWA', 'CHUJ', 'CHUJOWO', 'GÓWNO', 'JEBAĆ', 'PIZDA', 'POJEBIE', 'ZAJEBIE']) {
    stdout.writeln('blocked $bad inKept=${kept.contains(bad) || kept.any((w) => _fold(w) == _fold(bad))}');
  }
}

void _preferSpell(Map<String, String> bestSpell, String key, String candidate) {
  final current = bestSpell[key];
  if (current == null || _diacriticScore(candidate) > _diacriticScore(current)) {
    bestSpell[key] = candidate;
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
  if (lower.startsWith('forma:') || lower.startsWith('forma ')) return 2;
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
      text.startsWith('forma ') ||
      text.startsWith('forma:') ||
      text.startsWith('odmiana ') ||
      text.startsWith('zob. ') ||
      text.startsWith('aspekt ') ||
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
  return _clean('Forma: ${match.group(1)!.trim()}');
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

