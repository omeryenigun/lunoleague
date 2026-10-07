import 'dart:convert';

import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:postgres/postgres.dart';

/// Onaylı bir sorunun sayıya giren alanları.
class BilgiCountPart {
  const BilgiCountPart({
    required this.categoryId,
    required this.difficulty,
    required this.status,
    required this.tags,
  });

  final String categoryId;
  final String difficulty;
  final String status;
  final List<String> tags;

  bool get counts => status == 'approved' && categoryId.isNotEmpty;
}

/// Kategori, alt kategori ve zorluk sayıları. Sıfırlar tutulmaz.
class BilgiCountSnapshot {
  BilgiCountSnapshot({
    Map<String, int>? categories,
    Map<String, int>? subs,
    Map<String, int>? slices,
  })  : categories = categories ?? <String, int>{},
        subs = subs ?? <String, int>{},
        slices = slices ?? <String, int>{};

  final Map<String, int> categories;
  final Map<String, int> subs;
  final Map<String, int> slices;

  factory BilgiCountSnapshot.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return BilgiCountSnapshot();
    return BilgiCountSnapshot(
      categories: _ints(decoded['categories']),
      subs: _ints(decoded['subs']),
      slices: _ints(decoded['slices']),
    );
  }

  String encode() => jsonEncode({
        'categories': categories,
        'subs': subs,
        'slices': slices,
      });

  /// Eski hal çıkar, yeni hal eklenir. Onaylı sayı değişmediyse false.
  bool replaceAll(List<BilgiCountPart?> before, List<BilgiCountPart?> after) {
    final prior = encode();
    final count = before.length > after.length ? before.length : after.length;
    for (var i = 0; i < count; i++) {
      _touch(i < before.length ? before[i] : null, -1);
      _touch(i < after.length ? after[i] : null, 1);
    }
    return encode() != prior;
  }

  /// Alt kategori adı değişince kova eski anahtardan yeni anahtara taşınır.
  bool moveSub(String categoryId, String from, String to) {
    if (from == to || categoryId.isEmpty || from.isEmpty || to.isEmpty) return false;
    final prior = encode();
    final oldSub = '$categoryId|$from';
    final newSub = '$categoryId|$to';
    final moved = subs.remove(oldSub);
    if (moved != null) subs[newSub] = (subs[newSub] ?? 0) + moved;
    final prefix = '$categoryId|$from|';
    final nextPrefix = '$categoryId|$to|';
    for (final key in slices.keys.where((item) => item.startsWith(prefix)).toList()) {
      final value = slices.remove(key)!;
      final dest = '$nextPrefix${key.substring(prefix.length)}';
      slices[dest] = (slices[dest] ?? 0) + value;
    }
    return encode() != prior;
  }

  /// Kapalı kategori ve alt kategori cevapta yer almaz. Soru satırı okunmaz.
  /// [eventCategories] kendi sayısını korur, tümü havuzuna girmez.
  BilgiCountSnapshot visible(
    Set<String> openCategories,
    Set<String> openSubs, {
    Set<String> eventCategories = const {},
  }) {
    final shownCategories = <String, int>{};
    var total = 0;
    final shownDiff = <String, int>{};
    final playable = <String, int>{};
    for (final entry in subs.entries) {
      if (entry.value <= 0) continue;
      final bar = entry.key.indexOf('|');
      if (bar <= 0) continue;
      final categoryId = entry.key.substring(0, bar);
      if (categoryId == tumuKarmaId || !openCategories.contains(categoryId)) continue;
      if (!openSubs.contains(entry.key)) continue;
      playable[categoryId] = (playable[categoryId] ?? 0) + entry.value;
    }
    for (final entry in playable.entries) {
      shownCategories[entry.key] = entry.value;
      if (!eventCategories.contains(entry.key)) total += entry.value;
    }
    if (total > 0) shownCategories[tumuKarmaId] = total;

    final shownSubs = <String, int>{};
    for (final entry in subs.entries) {
      if (entry.value <= 0) continue;
      final bar = entry.key.indexOf('|');
      if (bar <= 0) continue;
      final categoryId = entry.key.substring(0, bar);
      if (!openCategories.contains(categoryId) || !openSubs.contains(entry.key)) continue;
      shownSubs[entry.key] = entry.value;
    }

    final shownSlices = <String, int>{};
    for (final entry in slices.entries) {
      if (entry.value <= 0) continue;
      final wide = entry.key.split('||');
      if (wide.length == 2) {
        final categoryId = wide[0];
        if (categoryId == tumuKarmaId || !openCategories.contains(categoryId)) continue;
        shownSlices[entry.key] = entry.value;
        if (!eventCategories.contains(categoryId)) {
          shownDiff[wide[1]] = (shownDiff[wide[1]] ?? 0) + entry.value;
        }
        continue;
      }
      final parts = entry.key.split('|');
      if (parts.length != 3) continue;
      final subKey = '${parts[0]}|${parts[1]}';
      if (!openCategories.contains(parts[0]) || !openSubs.contains(subKey)) continue;
      shownSlices[entry.key] = entry.value;
    }
    for (final entry in shownDiff.entries) {
      if (entry.value > 0) shownSlices['$tumuKarmaId||${entry.key}'] = entry.value;
    }
    return BilgiCountSnapshot(categories: shownCategories, subs: shownSubs, slices: shownSlices);
  }

  Map<String, Object> toJson() => {
        'categories': categories,
        'subs': subs,
        'slices': slices,
      };

  void _touch(BilgiCountPart? part, int sign) {
    if (part == null || !part.counts) return;
    _bump(categories, part.categoryId, sign);
    _bump(categories, tumuKarmaId, sign);
    _bump(slices, '${part.categoryId}||${part.difficulty}', sign);
    _bump(slices, '$tumuKarmaId||${part.difficulty}', sign);
    for (final tag in part.tags) {
      final name = tag.trim();
      if (name.isEmpty) continue;
      _bump(subs, '${part.categoryId}|$name', sign);
      _bump(slices, '${part.categoryId}|$name|${part.difficulty}', sign);
    }
  }

  void _bump(Map<String, int> map, String key, int sign) {
    final next = (map[key] ?? 0) + sign;
    if (next <= 0) {
      map.remove(key);
    } else {
      map[key] = next;
    }
  }

  static Map<String, int> _ints(Object? raw) {
    if (raw is! Map) return <String, int>{};
    final out = <String, int>{};
    for (final entry in raw.entries) {
      final value = entry.value;
      final count = value is int ? value : (value is num ? value.toInt() : null);
      if (count == null || count <= 0) continue;
      out['${entry.key}'] = count;
    }
    return out;
  }
}

/// Kategori ve zorluk kovaları canlı onaylı sayımla aynıysa true.
/// Alt kategori adı kayması bu karşılaştırmaya girmez.
bool bilgiSnapshotDifficultyCountsMatch(BilgiCountSnapshot stored, Map<String, int> live) {
  final fromStored = <String, int>{};
  for (final entry in stored.slices.entries) {
    final parts = entry.key.split('|');
    if (parts.length != 3 || parts[1].isNotEmpty || parts[0] == tumuKarmaId) continue;
    fromStored[entry.key] = entry.value;
  }
  if (fromStored.length != live.length) return false;
  for (final entry in live.entries) {
    if (fromStored[entry.key] != entry.value) return false;
  }
  return true;
}

Future<void> ensureBilgiCountSnapshot(Connection db) async {
  await db.execute('''
    create table if not exists bilgi_count_snapshot (
      id int primary key,
      body text not null
    )
  ''');
  final existing = await db.execute('select body from bilgi_count_snapshot where id = 1');
  if (existing.isNotEmpty) {
    final stored = BilgiCountSnapshot.decode('${existing.first[0]}');
    final live = await _approvedDifficultyCounts(db);
    if (bilgiSnapshotDifficultyCountsMatch(stored, live)) return;
  }
  await _writeSnapshot(db, await _scanApprovedCounts(db));
}

Future<Map<String, int>> _approvedDifficultyCounts(Connection db) async {
  final rows = await db.execute('''
    select category_id, difficulty, count(*)::int
    from bilgi_questions
    where status = 'approved'
    group by category_id, difficulty
  ''');
  final out = <String, int>{};
  for (final row in rows) {
    final count = row[2];
    out['${row[0]}||${row[1]}'] = count is int ? count : int.parse('$count');
  }
  return out;
}

Future<BilgiCountSnapshot> loadBilgiCountSnapshot(Connection db) async {
  final rows = await db.execute('select body from bilgi_count_snapshot where id = 1');
  if (rows.isEmpty) {
    final built = await _scanApprovedCounts(db);
    await _writeSnapshot(db, built);
    return built;
  }
  return BilgiCountSnapshot.decode('${rows.first[0]}');
}

Future<void> commitBilgiCountDelta(
  Connection db, {
  required List<BilgiCountPart?> before,
  required List<BilgiCountPart?> after,
}) async {
  final touches = before.any((part) => part?.counts == true) || after.any((part) => part?.counts == true);
  if (!touches) return;
  final rows = await db.execute('select body from bilgi_count_snapshot where id = 1');
  if (rows.isEmpty) {
    await _writeSnapshot(db, await _scanApprovedCounts(db));
    return;
  }
  final snapshot = BilgiCountSnapshot.decode('${rows.first[0]}');
  if (!snapshot.replaceAll(before, after)) return;
  await _writeSnapshot(db, snapshot);
}

Future<void> moveBilgiCountSubName(Connection db, String categoryId, String from, String to) async {
  final rows = await db.execute('select body from bilgi_count_snapshot where id = 1');
  if (rows.isEmpty) {
    await _writeSnapshot(db, await _scanApprovedCounts(db));
    return;
  }
  final snapshot = BilgiCountSnapshot.decode('${rows.first[0]}');
  if (!snapshot.moveSub(categoryId, from, to)) return;
  await _writeSnapshot(db, snapshot);
}

Future<Map<String, BilgiCountPart>> loadBilgiCountParts(Connection db, List<String> ids) async {
  if (ids.isEmpty) return const {};
  final parameters = <String, Object>{};
  final marks = <String>[];
  for (var i = 0; i < ids.length; i++) {
    parameters['id$i'] = ids[i];
    marks.add('@id$i');
  }
  final rows = await db.execute(
    Sql.named('''
      select id, category_id, difficulty, status, tags_json
      from bilgi_questions
      where id in (${marks.join(', ')})
    '''),
    parameters: parameters,
  );
  final out = <String, BilgiCountPart>{};
  for (final row in rows) {
    out['${row[0]}'] = BilgiCountPart(
      categoryId: '${row[1]}',
      difficulty: '${row[2]}',
      status: '${row[3]}',
      tags: _tags(row[4]),
    );
  }
  return out;
}

Future<BilgiCountSnapshot> _scanApprovedCounts(Connection db) async {
  final rows = await db.execute('''
    select category_id, difficulty, tags_json
    from bilgi_questions
    where status = 'approved'
  ''');
  final snapshot = BilgiCountSnapshot();
  final after = <BilgiCountPart?>[
    for (final row in rows)
      BilgiCountPart(
        categoryId: '${row[0]}',
        difficulty: '${row[1]}',
        status: 'approved',
        tags: _tags(row[2]),
      ),
  ];
  snapshot.replaceAll(const [], after);
  return snapshot;
}

Future<void> _writeSnapshot(Connection db, BilgiCountSnapshot snapshot) async {
  await db.execute(
    Sql.named('''
      insert into bilgi_count_snapshot (id, body)
      values (1, @body)
      on conflict (id) do update set body = excluded.body
    '''),
    parameters: {'body': snapshot.encode()},
  );
}

List<String> _tags(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return [for (final item in decoded) '$item'];
  } catch (_) {}
  return const [];
}
