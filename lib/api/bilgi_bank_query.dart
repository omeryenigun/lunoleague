import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';

/// Soru bankası araması, ekrandaki süzgeçle aynı harf katlamasını kullanır.
String bilgiBankFold(String value) {
  return value
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ç', 'c');
}

/// LIKE kalıbında % ve _ düz metin sayılır.
String bilgiBankLike(String folded) {
  final escaped = folded.replaceAll(r'\', r'\\').replaceAll('%', r'\%').replaceAll('_', r'\_');
  return '%$escaped%';
}

const _bilgiBankFoldPairs = <List<String>>[
  ['İ', 'i'],
  ['I', 'i'],
  ['ı', 'i'],
  ['Ö', 'o'],
  ['ö', 'o'],
  ['Ü', 'u'],
  ['ü', 'u'],
  ['Ş', 's'],
  ['ş', 's'],
  ['Ğ', 'g'],
  ['ğ', 'g'],
  ['Ç', 'c'],
  ['ç', 'c'],
  ['A', 'a'],
  ['B', 'b'],
  ['C', 'c'],
  ['D', 'd'],
  ['E', 'e'],
  ['F', 'f'],
  ['G', 'g'],
  ['H', 'h'],
  ['J', 'j'],
  ['K', 'k'],
  ['L', 'l'],
  ['M', 'm'],
  ['N', 'n'],
  ['O', 'o'],
  ['P', 'p'],
  ['Q', 'q'],
  ['R', 'r'],
  ['S', 's'],
  ['T', 't'],
  ['U', 'u'],
  ['V', 'v'],
  ['W', 'w'],
  ['X', 'x'],
  ['Y', 'y'],
  ['Z', 'z'],
];

final bilgiBankFoldFrom = _bilgiBankFoldPairs.map((pair) => pair[0]).join();
final bilgiBankFoldTo = _bilgiBankFoldPairs.map((pair) => pair[1]).join();

/// Sayfa boyu yalnız listedeki değerler. Seçim turu 200 satır ister.
int bilgiBankPageLimit(int size, {bool select = false}) {
  if (select) return size <= 0 ? 200 : (size > 200 ? 200 : size);
  const allowed = [20, 50, 100, 200];
  if (allowed.contains(size)) return size;
  return 20;
}

String bilgiBankFoldSql(String column) {
  return "translate(coalesce($column, ''), '$bilgiBankFoldFrom', '$bilgiBankFoldTo')";
}

/// Türkçe gövde ve kategorinin ek dilleri doluysa doğru.
/// [extraLocalesByCategory] boşsa her kategori dokuz dil ister.
String bilgiBankReadySql(Map<String, List<String>> extraLocalesByCategory) {
  final groups = <String, List<String>>{};
  for (final entry in extraLocalesByCategory.entries) {
    final id = entry.key.trim();
    if (!_safeId(id)) continue;
    final locales = [for (final locale in entry.value) if (locale != 'tr' && bilgiLocaleIds.contains(locale)) locale];
    final key = locales.join(',');
    groups.putIfAbsent(key, () => []).add(id);
  }
  final branches = <String>[];
  for (final entry in groups.entries) {
    final ids = entry.value.map((id) => "'${id.replaceAll("'", "''")}'").join(', ');
    final locales = entry.key.isEmpty ? const <String>[] : entry.key.split(',');
    branches.add('when q.category_id in ($ids) then ${_readyBundle(locales)}');
  }
  final fallback = _readyBundle([for (final id in bilgiLocaleIds) if (id != 'tr') id]);
  if (branches.isEmpty) return fallback;
  return '(case ${branches.join(' ')} else $fallback end)';
}

bool _safeId(String id) => RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id);

String _readyBundle(List<String> locales) {
  final parts = <String>[_turkishReady(), for (final locale in locales) _localeReady(locale)];
  return '(${parts.join(' and ')})';
}

String _turkishReady() {
  return '''
(
  length(btrim(coalesce(q.text, ''))) > 0
  and length(btrim(coalesce(q.explanation, ''))) > 0
  and ${_textArrayReady('q.options_json', 'q.options_json::jsonb')}
)
''';
}

/// Bozuk JSON, eksik anahtar ve dizi olmayan değer yanlış döner.
/// Dizi işlevleri yalnız `jsonb_typeof(...) = 'array'` dalında çalışır.
String _textArrayReady(String rawSql, String jsonbSql) {
  return '''
case
  when pg_input_is_valid(coalesce($rawSql, ''), 'jsonb') then
    case
      when jsonb_typeof($jsonbSql) = 'array' then
        jsonb_array_length($jsonbSql) = 4
        and not exists (
          select 1 from jsonb_array_elements_text($jsonbSql) opt
          where length(btrim(opt)) = 0
        )
      else false
    end
  else false
end
''';
}

String _localeReady(String locale) {
  final key = locale.replaceAll("'", '');
  final raw = 'q.translations_json';
  final value = "$raw::jsonb -> '$key'";
  return '''
case
  when pg_input_is_valid(coalesce($raw, ''), 'jsonb') then
    case
      when coalesce(length(btrim($value ->> 'text')), 0) > 0
       and coalesce(length(btrim($value ->> 'explanation')), 0) > 0
       and jsonb_typeof($value -> 'options') = 'array' then
        jsonb_array_length($value -> 'options') = 4
        and not exists (
          select 1 from jsonb_array_elements_text($value -> 'options') opt
          where length(btrim(opt)) = 0
        )
      else false
    end
  else false
end
''';
}
