import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

/// Everyday words that the blocklist also names. They stay.
const _keep = {
  'БУГОР',
  'ГОЛЫЙ',
  'МЕНТ',
  'ОФИГЕТЬ',
  'СЕКС',
  'ФИГА',
  'ХАПАТЬ',
  'ХРЕН',
};

/// Obscene words the blocklist only has in Latin or inside a phrase.
const _extra = {
  'ДРОЧИЛ',
  'ЕБАЛО',
  'ЕБАНАЯ',
  'ЕБАНЫЕ',
  'ЕБАНЫЙ',
  'ЕБАТЬСЯ',
  'ЕБУЧАЯ',
  'ЕБУЧИЕ',
  'ЕБУЧИЙ',
  'ЁБАНАЯ',
  'ЁБАНЫЕ',
  'ЁБАНЫЙ',
  'ЗАЕБИСЬ',
  'МИНЕТ',
  'МУДАК',
  'МУДАКА',
  'МУДАКИ',
  'МУДАКОВ',
  'МУДАКОМ',
  'ОРГАЗМ',
  'ОРГИЯ',
  'ОТСОС',
  'ОХУЕННО',
  'ПЕДИК',
  'ПЕДИКИ',
  'ПЕДИКОВ',
  'ПЕДИКОМ',
  'ПИЗДА',
  'ПИЗДЕЦ',
  'ПИЗДУ',
  'ПИЗДЫ',
  'ПИЗДЮК',
  'ПИДОР',
  'ПОРНО',
  'СУЧКА',
  'СУЧКЕ',
  'СУЧКИ',
  'СУЧКОЙ',
  'СУЧКУ',
  'ТРАХАЕТ',
  'ТРАХАЙ',
  'ТРАХАЛ',
  'ТРАХАТЬ',
  'ТРАХАЮ',
  'ТРАХАЮТ',
  'ТРАХНИ',
  'ТРАХНУ',
  'ТРАХНУЛ',
  'УБЛЮДКА',
  'УБЛЮДКИ',
  'УБЛЮДКУ',
  'УБЛЮДОК',
  'ХУЕСОС',
  'ХУЙНЮ',
  'ХУЙНЯ',
  'ШЛЮХА',
  'ШЛЮХАМИ',
  'ШЛЮХЕ',
  'ШЛЮХИ',
  'ШЛЮХОЙ',
  'ШЛЮХУ',
};

final _inflection = RegExp(
  r'^(?:форма слова |мн\. ч\. от |множественное число от )([^:,.;]+)',
  caseSensitive: false,
);

String _plain(String raw) => raw
    .replaceAll('\u0301', '')
    .replaceAll('\u0300', '')
    .replaceAll('\u00B4', '');

Future<void> main(List<String> args) async {
  final freqPath = args.isNotEmpty
      ? args[0]
      : r'C:\Users\omery\AppData\Local\Temp\luno-ru\ru_50k.txt';
  final badPath = args.length > 1
      ? args[1]
      : r'C:\Users\omery\AppData\Local\Temp\luno-ru\bad-ru.txt';
  final wikiPath = args.length > 2
      ? args[2]
      : r'C:\Users\omery\AppData\Local\Temp\luno-ru\ru-extract.jsonl.gz';

  final drop = <String>{};
  for (final raw in File(badPath).readAsLinesSync()) {
    final word = GameLocale.ru.toUpper(_plain(raw));
    if (word.isEmpty || word.contains(' ') || _keep.contains(word)) continue;
    drop.add(word);
  }
  drop.addAll(_extra);

  final order = <String>[];
  final wanted = <String>{};
  var dropped = 0;
  for (final raw in File(freqPath).readAsLinesSync()) {
    final token = raw.trim().split(RegExp(r'\s+')).first;
    final word = GameLocale.ru.toUpper(_plain(token));
    if (word.isEmpty) continue;
    if (drop.contains(word)) {
      dropped++;
      continue;
    }
    final length = GameLocale.ru.letterCount(word);
    if (!GameLocale.ru.isAllowedWord(word) || length < 5 || length > 7) continue;
    if (!wanted.add(word)) continue;
    order.add(word);
  }

  final listBuf = StringBuffer();
  for (final word in order) {
    listBuf.writeln(word);
  }
  File('wordlists/ru.txt').writeAsStringSync(listBuf.toString());

  final glosses = <String, String>{};
  final lines = File(wikiPath)
      .openRead()
      .transform(gzip.decoder)
      .transform(utf8.decoder)
      .transform(const LineSplitter());
  var seen = 0;
  await for (final line in lines) {
    seen++;
    if (seen % 40000 == 0) {
      stdout.writeln('seen=$seen glosses=${glosses.length}');
    }
    if (!line.contains('"lang_code":"ru"') && !line.contains('"lang_code": "ru"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map || decoded['lang_code'] != 'ru') continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty || word.contains(' ') || word.contains('-')) {
      continue;
    }
    final gloss = _sense(decoded['senses']);
    if (gloss == null) continue;
    final lemma = GameLocale.ru.toUpper(_plain(word));
    if (drop.contains(lemma)) continue;
    if (wanted.contains(lemma)) _put(glosses, lemma, gloss);
    final forms = decoded['forms'];
    if (forms is! List || _rank(gloss) < 3) continue;
    final short = gloss.split(';').first.trim();
    final formGloss = _clean('Форма слова $word: $short');
    if (formGloss == null) continue;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ') || text.contains('-')) continue;
      final key = GameLocale.ru.toUpper(_plain(text));
      if (key == lemma || drop.contains(key) || !wanted.contains(key)) continue;
      _put(glosses, key, formGloss);
    }
    if (glosses.length == wanted.length) break;
  }

  final kept = [for (final word in order) if (glosses.containsKey(word)) word];
  final glossBuf = StringBuffer()
    ..writeln('/// Short senses for the Russian frequency list.')
    ..writeln('/// Source: Russian Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('/// Yo stays yo. Stress marks are already removed.')
    ..writeln('const ruGlosses = <String, String>{');
  for (final word in kept) {
    glossBuf.writeln("  '$word': '${_dart(glosses[word]!)}',");
  }
  glossBuf.writeln('};');
  File('lib/data/local/ru_glosses.dart').writeAsStringSync(glossBuf.toString());

  final wordsBuf = StringBuffer()
    ..writeln('/// Common Russian words, most frequent first.')
    ..writeln('/// Yo stays yo. Stress marks are already removed.')
    ..writeln("import 'package:kelimelig/data/local/ru_glosses.dart';")
    ..writeln()
    ..writeln('const ruFrequencyWords = <String>[')
  ;
  for (final word in kept) {
    wordsBuf.writeln("  '$word',");
  }
  wordsBuf
    ..writeln('];')
    ..writeln()
    ..writeln(r'''
String get ruFrequencyWordsCsv {
  final rows = StringBuffer('word,language,definition,example,english,category,difficulty,frequency,status')
      ..writeln();
  for (final word in ruFrequencyWords) {
    final gloss = (ruGlosses[word] ?? '').replaceAll(',', ';').replaceAll('"', '');
    if (gloss.isEmpty) continue;
    rows.writeln('$word,ru,$gloss,,,общее,2,3,active');
  }
  return rows.toString();
}
''');
  File('lib/data/local/ru_frequency_words.dart').writeAsStringSync(wordsBuf.toString());
  stdout.writeln(
    'candidates=${order.length} dropped=$dropped glosses=${glosses.length} kept=${kept.length} seen=$seen',
  );
  for (final sample in ['ГОРОД', 'РОССИЯ', 'СЕЙЧАС', 'СЕРДЦЕ', 'ЁЛКА', 'БЛЯДЬ', 'ХУЙ']) {
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
  if (lower.startsWith('форма слова ') && lower.contains(':')) return 2;
  if (lower.startsWith('форма слова ')) return 1;
  return 3;
}

bool _weak(String gloss) {
  final text = gloss.toLowerCase();
  return text.startsWith('форма слова ') ||
      text.startsWith('мн. ч.') ||
      text.startsWith('мн.ч.') ||
      text.startsWith('множественное число') ||
      text.startsWith('уменьш') ||
      text.startsWith('устаревш') ||
      text.startsWith('см.') ||
      text.startsWith('то же') ||
      text.startsWith('plural of ') ||
      text.startsWith('form of ') ||
      text.startsWith('inflection of ');
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
  final match = _inflection.firstMatch(raw);
  if (match == null) return null;
  return _clean('Форма слова ${match.group(1)!.trim()}');
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
