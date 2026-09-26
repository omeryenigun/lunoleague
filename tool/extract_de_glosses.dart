import 'dart:convert';
import 'dart:io';

import 'package:kelimelig/core/l10n/game_locale.dart';

final _inflection = RegExp(r'^inflection of ([^:,]+)');

Future<void> main(List<String> args) async {
  final wanted = <String>{
    for (final raw in File('wordlists/de.txt').readAsLinesSync())
      if (raw.trim().isNotEmpty) GameLocale.de.writtenUpper(raw),
  };
  final glosses = <String, String>{};
  final input = File(
    args.isEmpty ? r'C:\Users\omery\AppData\Local\Temp\de-wiki.jsonl' : args.first,
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
    if (!line.contains('"lang_code":"de"') && !line.contains('"lang_code": "de"')) {
      continue;
    }
    final decoded = jsonDecode(line);
    if (decoded is! Map) continue;
    final word = decoded['word'];
    if (word is! String || word.isEmpty) continue;
    final gloss = _sense(decoded['senses'], word);
    if (gloss == null) continue;
    final lemma = GameLocale.de.writtenUpper(word);
    if (wanted.contains(lemma)) _put(glosses, lemma, gloss);
    final forms = decoded['forms'];
    if (forms is! List) continue;
    final formGloss = _clean('Form von $word: ${gloss.split(';').first.trim()}') ?? gloss;
    for (final form in forms) {
      if (form is! Map) continue;
      final text = form['form'];
      if (text is! String || text.contains(' ')) continue;
      final key = GameLocale.de.writtenUpper(text);
      if (key == lemma || !wanted.contains(key)) continue;
      _put(glosses, key, formGloss);
    }
    if (glosses.length == wanted.length) break;
  }
  final buf = StringBuffer()
    ..writeln('/// Short senses for the German frequency list.')
    ..writeln('/// Source: German Wiktionary via Kaikki, CC BY-SA 4.0.')
    ..writeln('const deGlosses = <String, String>{');
  final keys = glosses.keys.toList()..sort();
  for (final key in keys) {
    buf.writeln("  '${_dart(key)}': '${_dart(glosses[key]!)}',");
  }
  buf.writeln('};');
  File('lib/data/local/de_glosses.dart').writeAsStringSync(buf.toString());
  stdout.writeln('glosses=${glosses.length} wanted=${wanted.length}');
}

void _put(Map<String, String> glosses, String key, String gloss) {
  final current = glosses[key];
  if (current == null || _rank(gloss) > _rank(current)) {
    glosses[key] = gloss;
  }
}

int _rank(String gloss) {
  if (_weak(gloss)) return 0;
  if (gloss.startsWith('Form von ')) return 1;
  return 2;
}

bool _weak(String gloss) {
  final text = gloss.toLowerCase();
  return text.startsWith('form von ') && text.contains('gerund') ||
      text.startsWith('gerund of ') ||
      text.startsWith('plural of ') ||
      text.startsWith('female equivalent') ||
      text.startsWith('nominative') ||
      text.startsWith('genitive') ||
      text.startsWith('dative') ||
      text.startsWith('accusative') ||
      text.startsWith('alternative ') ||
      text.startsWith('obsolete') ||
      text.startsWith('inflection of ') ||
      text.startsWith('forms the ') ||
      text.contains('rechtschreibreform');
}

String? _sense(Object? senses, String word) {
  if (senses is! List) return null;
  String? fallback;
  for (final sense in senses) {
    if (sense is! Map) continue;
    final glosses = sense['glosses'];
    if (glosses is! List || glosses.isEmpty) continue;
    final raw = glosses.first.toString();
    final inflection = _inflection.firstMatch(raw);
    final text = inflection != null
        ? _clean('Form von ${inflection.group(1)!.trim()}')
        : _clean(raw);
    if (text == null || _weak(text)) {
      fallback ??= text;
      continue;
    }
    final clause = text.split(';').first.trim();
    return _clean(clause) ?? text;
  }
  return fallback ?? _clean(word);
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
