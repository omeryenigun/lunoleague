import 'dart:convert';

import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/bilgi_bank_query.dart';
import 'package:kelimelig/api/bilgi_catalog_http.dart';
import 'package:kelimelig/api/bilgi_count_snapshot.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_rules.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const _statuses = {'approved', 'pending', 'rejected', 'draft'};
const _difficulties = {'kolay', 'orta', 'zor', 'efsane'};
const _extraLocales = {'en', 'de', 'es', 'fr', 'it', 'ru', 'nl', 'pt', 'pl'};
const _labelScopes = {'category', 'sub', 'group'};

Future<void> migrateBilgiQuestions(Connection db) async {
  await db.execute('''
    create table if not exists bilgi_questions (
      id text primary key,
      category_id text not null,
      text text not null,
      options_json text not null,
      correct int not null,
      difficulty text not null,
      explanation text not null default '',
      status text not null,
      tags_json text not null default '[]',
      reject_reason text not null default ''
    )
  ''');
  await db.execute(
    'create index if not exists bilgi_questions_status on bilgi_questions (status)',
  );
  await db.execute('''
    create table if not exists bilgi_daily (
      day text primary key,
      question_json text not null
    )
  ''');
  await db.execute(
    "alter table bilgi_questions add column if not exists translations_json text not null default '{}'",
  );
  await db.execute(
    'alter table bilgi_questions add column if not exists reviewed boolean not null default false',
  );
  await db.execute(
    'create index if not exists bilgi_questions_bank on bilgi_questions (category_id, status, difficulty)',
  );
  await db.execute(
    'create index if not exists bilgi_questions_reviewed on bilgi_questions (reviewed)',
  );
  try {
    await db.execute(
      'create index if not exists bilgi_questions_tags_gin on bilgi_questions using gin ((tags_json::jsonb))',
    );
  } catch (_) {}
  try {
    await db.execute('create extension if not exists pg_trgm');
    await db.execute('''
      create index if not exists bilgi_questions_text_fold
      on bilgi_questions using gin (${bilgiBankFoldSql('text')} gin_trgm_ops)
    ''');
  } catch (_) {}
  await db.execute('''
    create table if not exists bilgi_labels (
      locale text not null,
      scope text not null,
      key text not null,
      label text not null,
      primary key (locale, scope, key)
    )
  ''');
  await db.execute('''
    create table if not exists bilgi_active (
      kind text not null,
      key text not null,
      primary key (kind, key)
    )
  ''');
  await ensureBilgiCountSnapshot(db);
}

void mountBilgiQuestions(Router router, Connection db) {
  router
    ..get('/v1/bilgi/labels', (request) => _labels(db))
    ..put('/v1/admin/bilgi-labels', (request) => _saveLabels(request, db))
    ..get('/v1/bilgi/active', (request) => _active(db))
    ..put('/v1/admin/bilgi-active', (request) => _setActive(request, db))
    ..get('/v1/bilgi/questions/counts', (request) => _counts(db))
    ..get('/v1/bilgi/questions/daily', (request) => _daily(request, db))
    ..get('/v1/bilgi/questions/draw', (request) => _draw(request, db))
    ..get('/v1/bilgi/questions', (request) => _list(db, approvedOnly: true))
    ..get('/v1/admin/bilgi-questions/page', (request) async {
      if (await adminIdOf(db, request) == null) {
        return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
      }
      return _page(request, db);
    })
    ..get('/v1/admin/bilgi-questions/summary', (request) async {
      if (await adminIdOf(db, request) == null) {
        return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
      }
      return _summary(db);
    })
    ..get('/v1/admin/bilgi-questions/distribution', (request) async {
      if (await adminIdOf(db, request) == null) {
        return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
      }
      return _distribution(request, db);
    })
    ..get('/v1/admin/bilgi-questions/item/<id>', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) {
        return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
      }
      return _item(db, id);
    })
    ..get('/v1/admin/bilgi-questions', (request) async {
      if (await adminIdOf(db, request) == null) {
        return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
      }
      return _list(db, approvedOnly: false);
    })
    ..put('/v1/admin/bilgi-questions', (request) => _save(request, db))
    ..delete('/v1/admin/bilgi-questions/<id>', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) {
        return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
      }
      final key = id.trim();
      if (key.isEmpty || key.length > 80) {
        return jsonResponse({'error': 'Soru bulunamadı.'}, status: 400);
      }
      final previous = await loadBilgiCountParts(db, [key]);
      await db.execute(
        Sql.named('delete from bilgi_questions where id = @id'),
        parameters: {'id': key},
      );
      await commitBilgiCountDelta(db, before: [previous[key]], after: const [null]);
      return jsonResponse({'ok': true});
    });
}

Future<Response> _counts(Connection db) async {
  final snapshot = await loadBilgiCountSnapshot(db);
  final open = await _openSets(db);
  final events = await _eventCategoryIds(db);
  return jsonResponse(snapshot.visible(open.categories, open.subs, eventCategories: events).toJson());
}

Future<Set<String>> _eventCategoryIds(Connection db) async {
  final rows = await db.execute(
    Sql.named('select id from bilgi_categories where group_name = @group'),
    parameters: {'group': bilgiSpecialEventGroup},
  );
  return {for (final row in rows) '${row[0]}'};
}

Future<Response> _daily(Request request, Connection db) async {
  final day = DateTime.now().toUtc().toIso8601String().substring(0, 10);
  final locale = (request.url.queryParameters['locale'] ?? '').trim();
  final existing = await db.execute(
    Sql.named('select question_json from bilgi_daily where day = @day'),
    parameters: {'day': day},
  );
  if (existing.isNotEmpty) {
    final stored = jsonDecode('${existing.first[0]}');
    if (stored is Map && await _publishesForLocale(db, stored, locale)) {
      return jsonResponse({'questions': [stored]});
    }
    if (locale.isEmpty) {
      return jsonResponse({'questions': stored is Map ? [stored] : const []});
    }
  }
  final picked = await drawApprovedBilgiQuestions(
    db,
    categoryId: tumuKarmaId,
    subcategory: '',
    difficulty: '',
    count: 1,
    locale: locale,
  );
  if (picked.isEmpty) return jsonResponse({'questions': const []});
  if (existing.isEmpty) {
    await db.execute(
      Sql.named('''
        insert into bilgi_daily (day, question_json)
        values (@day, @question)
        on conflict (day) do nothing
      '''),
      parameters: {'day': day, 'question': jsonEncode(picked.first)},
    );
    final again = await db.execute(
      Sql.named('select question_json from bilgi_daily where day = @day'),
      parameters: {'day': day},
    );
    if (again.isNotEmpty) {
      final stored = jsonDecode('${again.first[0]}');
      if (stored is Map && await _publishesForLocale(db, stored, locale)) {
        return jsonResponse({'questions': [stored]});
      }
    }
  }
  return jsonResponse({'questions': picked});
}

Future<bool> _publishesForLocale(Connection db, Map stored, String locale) async {
  if (locale.isEmpty) return true;
  final categoryId = '${stored['categoryId'] ?? ''}'.trim();
  if (categoryId.isEmpty) return false;
  final rows = await db.execute(
    Sql.named('select locales from bilgi_categories where id = @id'),
    parameters: {'id': categoryId},
  );
  if (rows.isEmpty) return false;
  return bilgiPublishLocalesOf(bilgiStoredLocales(rows.first[0])).contains(locale);
}

Future<List<Map<String, dynamic>>> drawApprovedBilgiQuestions(
  Connection db, {
  required String categoryId,
  required String subcategory,
  required String difficulty,
  required int count,
  Set<String> exclude = const {},
  String locale = '',
  bool fullLocales = false,
}) async {
  if (difficulty == bilgiMixDifficulty) {
    return _drawMixedApproved(
      db,
      categoryId: categoryId,
      subcategory: subcategory,
      count: count,
      exclude: exclude,
      locale: locale,
    );
  }
  final categories = resolveBilgiCategories(await _closedCatalog(db), playableOnly: true);
  final picked = <Map<String, dynamic>>[];
  final seen = <String>{...exclude};
  final narrowed = difficulty.isNotEmpty && difficulty != 'hepsi';
  final attempts = fullLocales ? 8 : 6;
  for (var attempt = 0; attempt < attempts && picked.length < count; attempt++) {
    final need = count - picked.length;
    final rows = await db.execute(
      Sql.named('''
        select id, category_id, text, options_json, correct, difficulty,
               explanation, status, tags_json, reject_reason, translations_json, reviewed
        from bilgi_questions
        where status = 'approved'
          and (@category = 'tumu' or category_id = @category)
          and (@difficulty = '' or difficulty = @difficulty)
          and (@sub = '' or tags_json::jsonb ? @sub)
        order by random()
        limit @limit
      '''),
      parameters: {
        'category': categoryId == tumuKarmaId ? 'tumu' : categoryId,
        'difficulty': narrowed ? difficulty : '',
        'sub': subcategory,
        'limit': fullLocales ? need * 10 : need,
      },
    );
    if (rows.isEmpty) break;
    var fresh = 0;
    for (final row in rows) {
      final item = _json(row);
      final id = '${item['id']}';
      if (!seen.add(id)) continue;
      fresh += 1;
      final question = BilgiQuestion.fromMap(item);
      if (!bilgiPlayableQuestion(
        question,
        categories,
        categoryId: categoryId,
        subcategory: subcategory,
        difficulty: narrowed ? difficulty : '',
        locale: locale,
      )) {
        continue;
      }
      if (fullLocales) {
        final owner = categories.where((category) => category.id == question.categoryId).firstOrNull;
        if (owner == null || !bilgiQuestionLanguagesReady(question, locales: owner.publishLocales)) {
          continue;
        }
      }
      picked.add(item);
      if (picked.length >= count) break;
    }
    if (fresh == 0) break;
  }
  if (fullLocales && picked.length < count) {
    var offset = 0;
    while (picked.length < count) {
      final rows = await db.execute(
        Sql.named('''
          select id, category_id, text, options_json, correct, difficulty,
                 explanation, status, tags_json, reject_reason, translations_json, reviewed
          from bilgi_questions
          where status = 'approved'
            and (@category = 'tumu' or category_id = @category)
            and (@difficulty = '' or difficulty = @difficulty)
            and (@sub = '' or tags_json::jsonb ? @sub)
          order by id
          limit 200 offset @offset
        '''),
        parameters: {
          'category': categoryId == tumuKarmaId ? 'tumu' : categoryId,
          'difficulty': narrowed ? difficulty : '',
          'sub': subcategory,
          'offset': offset,
        },
      );
      if (rows.isEmpty) break;
      for (final row in rows) {
        final item = _json(row);
        final id = '${item['id']}';
        if (!seen.add(id)) continue;
        final question = BilgiQuestion.fromMap(item);
        if (!bilgiPlayableQuestion(
          question,
          categories,
          categoryId: categoryId,
          subcategory: subcategory,
          difficulty: narrowed ? difficulty : '',
          locale: locale,
        )) {
          continue;
        }
        final owner = categories.where((category) => category.id == question.categoryId).firstOrNull;
        if (owner == null || !bilgiQuestionLanguagesReady(question, locales: owner.publishLocales)) {
          continue;
        }
        picked.add(item);
        if (picked.length >= count) break;
      }
      offset += rows.length;
      if (rows.length < 200) break;
    }
  }
  return picked;
}

Future<List<Map<String, dynamic>>> _drawMixedApproved(
  Connection db, {
  required String categoryId,
  required String subcategory,
  required int count,
  required Set<String> exclude,
  required String locale,
}) async {
  final picked = <Map<String, dynamic>>[];
  final seen = <String>{...exclude};
  final quotas = bilgiMixQuotas(count);
  for (var i = 0; i < bilgiDifficultyLevels.length; i++) {
    if (quotas[i] == 0) continue;
    final batch = await drawApprovedBilgiQuestions(
      db,
      categoryId: categoryId,
      subcategory: subcategory,
      difficulty: bilgiDifficultyLevels[i],
      count: quotas[i],
      exclude: seen,
      locale: locale,
    );
    for (final item in batch) {
      seen.add('${item['id']}');
      picked.add(item);
    }
  }
  var guard = 0;
  while (picked.length < count && guard < count) {
    guard += 1;
    var added = false;
    final order = [for (var i = 0; i < bilgiDifficultyLevels.length; i++) i]..sort(
        (a, b) => _mixCount(picked, bilgiDifficultyLevels[a]).compareTo(_mixCount(picked, bilgiDifficultyLevels[b])),
      );
    for (final index in order) {
      if (picked.length >= count) break;
      final batch = await drawApprovedBilgiQuestions(
        db,
        categoryId: categoryId,
        subcategory: subcategory,
        difficulty: bilgiDifficultyLevels[index],
        count: 1,
        exclude: seen,
        locale: locale,
      );
      if (batch.isEmpty) continue;
      seen.add('${batch.first['id']}');
      picked.add(batch.first);
      added = true;
      break;
    }
    if (!added) break;
  }
  return picked;
}

int _mixCount(List<Map<String, dynamic>> picked, String difficulty) {
  var count = 0;
  for (final item in picked) {
    if (item['difficulty'] == difficulty) count += 1;
  }
  return count;
}

Future<Response> _draw(Request request, Connection db) async {
  final params = request.url.queryParameters;
  final categoryId = (params['category'] ?? tumuKarmaId).trim();
  final subcategory = (params['sub'] ?? '').trim();
  final difficulty = (params['difficulty'] ?? '').trim();
  final count = int.tryParse(params['count'] ?? '') ?? 10;
  if (categoryId.isEmpty || count < 1 || count > 51) {
    return jsonResponse({'error': 'Soru isteği geçersiz.'}, status: 400);
  }
  final exclude = {
    for (final id in (params['exclude'] ?? '').split(','))
      if (id.trim().isNotEmpty) id.trim(),
  };
  final locale = (params['locale'] ?? '').trim();
  final picked = await drawApprovedBilgiQuestions(
    db,
    categoryId: categoryId,
    subcategory: subcategory,
    difficulty: difficulty,
    count: count,
    exclude: exclude,
    locale: locale,
  );
  return jsonResponse({'questions': picked});
}

Future<Map<String, List<String>>> _extraLocalesByCategory(Connection db) async {
  final rows = await db.execute('select id, locales from bilgi_categories');
  final out = <String, List<String>>{};
  for (final row in rows) {
    final publish = bilgiPublishLocalesOf(bilgiStoredLocales(row[1]));
    out['${row[0]}'] = [for (final id in publish) if (id != 'tr') id];
  }
  return out;
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

({String where, Map<String, Object> params}) _bankWhere(
  Map<String, String> query,
  String readySql, {
  bool ignoreTranslation = false,
}) {
  final params = <String, Object>{
    'category': (query['category'] ?? '').trim(),
    'sub': (query['sub'] ?? '').trim(),
    'difficulty': (query['difficulty'] ?? '').trim(),
    'status': (query['status'] ?? '').trim(),
    'reviewed': (query['reviewed'] ?? '').trim(),
  };
  final folded = bilgiBankFold((query['q'] ?? '').trim());
  final searching = folded.length >= 3;
  if (searching) params['like'] = bilgiBankLike(folded);
  final textFold = bilgiBankFoldSql('q.text');
  final optionFold = bilgiBankFoldSql('q.options_json');
  final translation = ignoreTranslation ? '' : (query['translation'] ?? '').trim();
  final translationClause = translation == 'ready'
      ? 'and $readySql'
      : translation == 'missing'
          ? 'and not ($readySql)'
          : '';
  final searchClause = searching
      ? "and ($textFold like @like escape '\\' or $optionFold like @like escape '\\')"
      : '';
  final where = '''
    (@category = '' or q.category_id = @category)
    and (@sub = '' or q.tags_json::jsonb ? @sub)
    and (@difficulty = '' or q.difficulty = @difficulty)
    and (@status = '' or q.status = @status)
    and (
      @reviewed = ''
      or (@reviewed = 'yes' and q.reviewed)
      or (@reviewed = 'no' and not q.reviewed)
    )
    $translationClause
    $searchClause
  ''';
  return (where: where, params: params);
}

Future<Response> _page(Request request, Connection db) async {
  final query = request.url.queryParameters;
  final page = _asInt(query['page']);
  final selectAll = query['select'] == '1';
  final size = bilgiBankPageLimit(_asInt(query['size']), select: selectAll);
  final safePage = page < 0 ? 0 : page;
  final readySql = bilgiBankReadySql(await _extraLocalesByCategory(db));
  final filter = _bankWhere(query, readySql);
  final params = {
    ...filter.params,
    'limit': size,
    'offset': safePage * size,
  };
  final totalRows = await db.execute(
    Sql.named('select count(*) from bilgi_questions q where ${filter.where}'),
    parameters: filter.params,
  );
  final rows = await db.execute(
    Sql.named('''
      select q.id, q.category_id, q.text, q.options_json, q.correct, q.difficulty,
             q.explanation, q.status, q.tags_json, q.reject_reason, q.reviewed,
             $readySql
      from bilgi_questions q
      where ${filter.where}
      order by q.id
      limit @limit offset @offset
    '''),
    parameters: params,
  );
  final total = totalRows.isEmpty ? 0 : _asInt(totalRows.first[0]);
  final pages = total == 0 ? 1 : (total / size).ceil();
  return jsonResponse({
    'total': total,
    'page': safePage,
    'pages': pages,
    'size': size,
    'questions': [
      for (final row in rows) _jsonList(row),
    ],
  });
}

Future<Response> _summary(Connection db) async {
  final readySql = bilgiBankReadySql(await _extraLocalesByCategory(db));
  final statusRows = await db.execute('select status, count(*) from bilgi_questions group by status');
  final categoryRows = await db.execute(
    'select category_id, status, count(*) from bilgi_questions group by category_id, status',
  );
  final difficultyRows = await db.execute(
    "select difficulty, count(*) from bilgi_questions where status = 'approved' group by difficulty",
  );
  final subRows = await db.execute('''
    select q.category_id, tag, q.status, count(*)
    from bilgi_questions q, jsonb_array_elements_text(q.tags_json::jsonb) tag
    group by q.category_id, tag, q.status
  ''');
  final tagRows = await db.execute('''
    select tag, count(*)
    from bilgi_questions q, jsonb_array_elements_text(q.tags_json::jsonb) tag
    group by tag
  ''');
  final pendingReady = await db.execute(
    Sql.named("select count(*) from bilgi_questions q where q.status = 'pending' and $readySql"),
  );
  final status = <String, int>{};
  var total = 0;
  for (final row in statusRows) {
    final count = _asInt(row[1]);
    status['${row[0]}'] = count;
    total += count;
  }
  return jsonResponse({
    'total': total,
    'status': status,
    'pendingReady': pendingReady.isEmpty ? 0 : _asInt(pendingReady.first[0]),
    'category': [
      for (final row in categoryRows)
        {'categoryId': '${row[0]}', 'status': '${row[1]}', 'count': _asInt(row[2])},
    ],
    'difficultyApproved': {for (final row in difficultyRows) '${row[0]}': _asInt(row[1])},
    'subs': [
      for (final row in subRows)
        {'categoryId': '${row[0]}', 'name': '${row[1]}', 'status': '${row[2]}', 'count': _asInt(row[3])},
    ],
    'tags': {for (final row in tagRows) '${row[0]}': _asInt(row[1])},
  });
}

Future<Response> _distribution(Request request, Connection db) async {
  final query = request.url.queryParameters;
  final rows = await db.execute(
    Sql.named('''
      select q.correct, q.difficulty, count(*)
      from bilgi_questions q
      where (@category = '' or q.category_id = @category)
        and (@sub = '' or q.tags_json::jsonb ? @sub)
      group by q.correct, q.difficulty
    '''),
    parameters: {
      'category': (query['category'] ?? '').trim(),
      'sub': (query['sub'] ?? '').trim(),
    },
  );
  final matrixRows = await db.execute('''
    select q.category_id, tag, q.difficulty, count(*)
    from bilgi_questions q, jsonb_array_elements_text(q.tags_json::jsonb) tag
    where q.status = 'approved'
    group by q.category_id, tag, q.difficulty
  ''');
  return jsonResponse({
    'rows': [
      for (final row in rows)
        {'correct': _asInt(row[0]), 'difficulty': '${row[1]}', 'count': _asInt(row[2])},
    ],
    'matrix': [
      for (final row in matrixRows)
        {
          'categoryId': '${row[0]}',
          'sub': '${row[1]}',
          'difficulty': '${row[2]}',
          'count': _asInt(row[3]),
        },
    ],
  });
}

Future<Response> _item(Connection db, String id) async {
  final key = id.trim();
  if (key.isEmpty || key.length > 80) {
    return jsonResponse({'error': 'Soru bulunamadı.'}, status: 404);
  }
  final rows = await db.execute(
    Sql.named('''
      select id, category_id, text, options_json, correct, difficulty,
             explanation, status, tags_json, reject_reason, translations_json, reviewed
      from bilgi_questions
      where id = @id
    '''),
    parameters: {'id': key},
  );
  if (rows.isEmpty) return jsonResponse({'error': 'Soru bulunamadı.'}, status: 404);
  return jsonResponse({'question': _json(rows.first)});
}

Map<String, dynamic> _jsonList(ResultRow row) {
  return {
    'id': row[0],
    'categoryId': row[1],
    'text': row[2],
    'options': _decodeList(row[3]),
    'correct': row[4],
    'difficulty': row[5],
    'explanation': row[6],
    'status': row[7],
    'tags': _decodeList(row[8]),
    'rejectReason': row[9],
    'reviewed': row[10] == true,
    'translationReady': row.length > 11 && row[11] == true,
  };
}

Future<Response> _list(Connection db, {required bool approvedOnly}) async {
  final rows = await db.execute(
    approvedOnly
        ? '''
            select id, category_id, text, options_json, correct, difficulty,
                   explanation, status, tags_json, reject_reason, translations_json, reviewed
            from bilgi_questions
            where status = 'approved'
            order by id
          '''
        : '''
            select id, category_id, text, options_json, correct, difficulty,
                   explanation, status, tags_json, reject_reason, translations_json, reviewed
            from bilgi_questions
            order by id
          ''',
  );
  return jsonResponse({
    'questions': [for (final row in rows) _json(row)],
  });
}

Future<Response> _save(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final raw = body['questions'];
  if (raw is! List || raw.isEmpty) {
    return jsonResponse({'error': 'Soru listesi boş.'}, status: 400);
  }
  if (raw.length > 400) {
    return jsonResponse({'error': 'Bir istekte en fazla 400 soru yazılır.'}, status: 400);
  }
  final localeRows = await db.execute('select id, locales from bilgi_categories');
  final localesByCategory = {for (final row in localeRows) '${row[0]}': bilgiStoredLocales(row[1])};
  final questions = <Map<String, Object>>[];
  for (final item in raw) {
    if (item is! Map) return jsonResponse({'error': 'Soru bulunamadı.'}, status: 400);
    final question = _read(Map<String, dynamic>.from(item));
    if (question == null) return jsonResponse({'error': 'Soru bulunamadı.'}, status: 400);
    questions.add(question);
  }
  await _useStoredTranslations(db, questions);
  for (final question in questions) {
    if (question['status'] == 'approved' &&
        !_approvedLanguagesReady(question, localesByCategory['${question['categoryId']}'])) {
      return jsonResponse({'error': bilgiApproveBlocked}, status: 400);
    }
  }
  final known = await db.execute('select id from bilgi_categories');
  final categoryIds = {for (final row in known) '${row[0]}'};
  final subRows = await db.execute('select category_id, name from bilgi_subcategories');
  final subNames = <String, Set<String>>{};
  for (final row in subRows) {
    subNames.putIfAbsent('${row[0]}', () => <String>{}).add('${row[1]}');
  }
  for (final question in questions) {
    final categoryId = '${question['categoryId']}';
    if (!categoryIds.contains(categoryId)) {
      return jsonResponse({'error': 'Kategori bulunamadı.'}, status: 400);
    }
    for (final tag in _decodeList(question['tags'])) {
      if (!(subNames[categoryId]?.contains(tag) ?? false)) {
        return jsonResponse({'error': 'Alt kategori bulunamadı.'}, status: 400);
      }
    }
  }
  final ids = [for (final question in questions) '${question['id']}'];
  final previous = await loadBilgiCountParts(db, ids);
  for (final question in questions) {
    await db.execute(
      Sql.named('''
        insert into bilgi_questions (
          id, category_id, text, options_json, correct, difficulty,
          explanation, status, tags_json, reject_reason, translations_json, reviewed
        ) values (
          @id, @categoryId, @text, @options, @correct, @difficulty,
          @explanation, @status, @tags, @rejectReason, @translations, @reviewed
        )
        on conflict (id) do update set
          category_id = excluded.category_id,
          text = excluded.text,
          options_json = excluded.options_json,
          correct = excluded.correct,
          difficulty = excluded.difficulty,
          explanation = excluded.explanation,
          status = excluded.status,
          tags_json = excluded.tags_json,
          reject_reason = excluded.reject_reason,
          translations_json = case
            when @keepTranslations then bilgi_questions.translations_json
            else excluded.translations_json
          end,
          reviewed = excluded.reviewed
      '''),
      parameters: question,
    );
  }
  await commitBilgiCountDelta(
    db,
    before: [for (final id in ids) previous[id]],
    after: [for (final question in questions) _countPart(question)],
  );
  return jsonResponse({'saved': questions.length});
}

BilgiCountPart _countPart(Map<String, Object> question) {
  return BilgiCountPart(
    categoryId: '${question['categoryId']}',
    difficulty: '${question['difficulty']}',
    status: '${question['status']}',
    tags: _decodeList(question['tags']),
  );
}

Map<String, Object>? _read(Map<String, dynamic> map) {
  final id = '${map['id'] ?? ''}'.trim();
  final categoryId = '${map['categoryId'] ?? ''}'.trim();
  final text = '${map['text'] ?? ''}'.trim();
  final difficulty = '${map['difficulty'] ?? ''}'.trim();
  final status = '${map['status'] ?? ''}'.trim();
  final explanation = '${map['explanation'] ?? ''}';
  final rejectReason = '${map['rejectReason'] ?? ''}';
  final options = _strings(map['options']);
  final tags = _strings(map['tags']);
  final correct = map['correct'];
  final correctIndex = correct is int ? correct : (correct is num ? correct.toInt() : null);
  if (id.isEmpty || id.length > 80 || categoryId.isEmpty || categoryId.length > 80) return null;
  if (text.isEmpty || text.length > 2000) return null;
  if (options == null || options.length != 4 || options.any((item) => item.trim().isEmpty || item.length > 500)) {
    return null;
  }
  if (correctIndex == null || correctIndex < 0 || correctIndex > 3) return null;
  if (!_difficulties.contains(difficulty) || !_statuses.contains(status)) return null;
  if (explanation.length > 4000 || rejectReason.length > 400) return null;
  if (tags == null || tags.length > 20 || tags.any((item) => item.length > 80)) return null;
  final keepTranslations = !map.containsKey('translations');
  final translations = _translations(map['translations']);
  if (translations == null) return null;
  return {
    'id': id,
    'categoryId': categoryId,
    'text': text,
    'options': jsonEncode(options),
    'correct': correctIndex,
    'difficulty': difficulty,
    'explanation': explanation,
    'status': status,
    'tags': jsonEncode(tags),
    'rejectReason': rejectReason,
    'translations': jsonEncode(translations),
    'keepTranslations': keepTranslations,
    'reviewed': map['reviewed'] == true,
  };
}

Future<({Set<String> categories, Set<String> subs})> _openSets(Connection db) async {
  final rows = await db.execute('select kind, key from bilgi_active');
  final categories = <String>{};
  final subs = <String>{};
  for (final row in rows) {
    if (row[0] == 'category') categories.add('${row[1]}');
    if (row[0] == 'sub') subs.add('${row[1]}');
  }
  return (categories: categories, subs: subs);
}

Future<Map<String, dynamic>> _closedCatalog(Connection db) async {
  final open = await _openSets(db);
  return bilgiCatalogClosedUnless(await bilgiAuthoritativeCatalog(db), open.categories, open.subs);
}

Future<Response> _active(Connection db) async {
  final rows = await db.execute('select kind, key from bilgi_active');
  return jsonResponse({
    'categories': [for (final row in rows) if (row[0] == 'category') '${row[1]}'],
    'subs': [for (final row in rows) if (row[0] == 'sub') '${row[1]}'],
  });
}

Future<Response> _setActive(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final kind = '${body['kind'] ?? ''}'.trim();
  final key = '${body['key'] ?? ''}'.trim();
  final active = body['active'] == true;
  if ((kind != 'category' && kind != 'sub') || key.isEmpty || key.length > 120) {
    return jsonResponse({'error': 'Kategori bulunamadı.'}, status: 400);
  }
  if (!active) {
    await db.execute(
      Sql.named('delete from bilgi_active where kind = @kind and key = @key'),
      parameters: {'kind': kind, 'key': key},
    );
    return jsonResponse({'ok': true});
  }
  final scope = kind == 'category' ? 'category' : 'sub';
  final named = await db.execute(
    Sql.named('''
      select locale from bilgi_labels
      where scope = @scope and key = @key and length(trim(label)) > 0
    '''),
    parameters: {'scope': scope, 'key': key},
  );
  final have = {for (final row in named) '${row[0]}'};
  final categoryId = kind == 'category' ? key : key.split('|').first;
  final storedLocales = await db.execute(
    Sql.named('select locales from bilgi_categories where id = @id'),
    parameters: {'id': categoryId},
  );
  final requiredLocales = bilgiExtraLocales(
    storedLocales.isEmpty ? null : bilgiStoredLocales(storedLocales.first[0]),
  );
  if (!requiredLocales.every(have.contains)) {
    return jsonResponse({'error': kind == 'category' ? bilgiCategoryBlocked : bilgiSubBlocked}, status: 400);
  }
  await db.execute(
    Sql.named('''
      insert into bilgi_active (kind, key) values (@kind, @key)
      on conflict (kind, key) do nothing
    '''),
    parameters: {'kind': kind, 'key': key},
  );
  return jsonResponse({'ok': true});
}

Future<void> _useStoredTranslations(Connection db, List<Map<String, Object>> questions) async {
  final pending = [
    for (final question in questions)
      if (question['status'] == 'approved' && question['keepTranslations'] == true) question,
  ];
  if (pending.isEmpty) return;
  final parameters = <String, Object>{};
  final slots = <String>[];
  for (var i = 0; i < pending.length; i++) {
    slots.add('@id$i');
    parameters['id$i'] = '${pending[i]['id']}';
  }
  final rows = await db.execute(
    Sql.named('select id, translations_json from bilgi_questions where id in (${slots.join(', ')})'),
    parameters: parameters,
  );
  final stored = {for (final row in rows) '${row[0]}': row[1]};
  for (final question in pending) {
    final value = stored['${question['id']}'];
    question['translations'] = bilgiApproveTranslationsJson(
      keepStored: true,
      submitted: '${question['translations']}',
      stored: value is String ? value : (value == null ? null : jsonEncode(value)),
    );
  }
}

bool _approvedLanguagesReady(Map<String, Object> question, List<String>? locales) {
  if ('${question['explanation']}'.trim().isEmpty) return false;
  final required = bilgiExtraLocales(locales);
  if (required.isEmpty) return true;
  final raw = jsonDecode('${question['translations']}');
  if (raw is! Map) return false;
  for (final locale in required) {
    final row = raw[locale];
    if (row is! Map) return false;
    final text = '${row['text'] ?? ''}'.trim();
    final explanation = '${row['explanation'] ?? ''}'.trim();
    final options = row['options'];
    if (text.isEmpty || explanation.isEmpty) return false;
    if (options is! List || options.length != 4 || options.any((item) => '$item'.trim().isEmpty)) return false;
  }
  return true;
}

Future<Response> _labels(Connection db) async {
  final rows = await db.execute('select locale, scope, key, label from bilgi_labels order by locale, scope, key');
  return jsonResponse({
    'labels': [
      for (final row in rows)
        {'locale': '${row[0]}', 'scope': '${row[1]}', 'key': '${row[2]}', 'label': '${row[3]}'},
    ],
  });
}

Future<Response> _saveLabels(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final raw = body['labels'];
  if (raw is! List) return jsonResponse({'error': 'Ad listesi boş.'}, status: 400);
  if (raw.length > 400) return jsonResponse({'error': 'Bir istekte en fazla 400 ad yazılır.'}, status: 400);
  for (final item in raw) {
    if (item is! Map) return jsonResponse({'error': 'Ad bulunamadı.'}, status: 400);
    final locale = '${item['locale'] ?? ''}'.trim();
    final scope = '${item['scope'] ?? ''}'.trim();
    final key = '${item['key'] ?? ''}'.trim();
    final label = '${item['label'] ?? ''}'.trim();
    if (!_extraLocales.contains(locale) && locale != 'tr') {
      return jsonResponse({'error': 'Dil bulunamadı.'}, status: 400);
    }
    if (!_labelScopes.contains(scope) || key.isEmpty || key.length > 120 || label.isEmpty || label.length > 80) {
      return jsonResponse({'error': 'Ad bulunamadı.'}, status: 400);
    }
    await db.execute(
      Sql.named('''
        insert into bilgi_labels (locale, scope, key, label)
        values (@locale, @scope, @key, @label)
        on conflict (locale, scope, key) do update set label = excluded.label
      '''),
      parameters: {'locale': locale, 'scope': scope, 'key': key, 'label': label},
    );
  }
  return jsonResponse({'saved': raw.length});
}

Map<String, dynamic> _json(ResultRow row) {
  return {
    'id': row[0],
    'categoryId': row[1],
    'text': row[2],
    'options': _decodeList(row[3]),
    'correct': row[4],
    'difficulty': row[5],
    'explanation': row[6],
    'status': row[7],
    'tags': _decodeList(row[8]),
    'rejectReason': row[9],
    'translations': row.length > 10 ? _decodeMap(row[10]) : const <String, dynamic>{},
    'reviewed': row.length > 11 && row[11] == true,
  };
}

Map<String, dynamic> _decodeMap(Object? raw) {
  if (raw is! String || raw.isEmpty || raw == '{}') return const {};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return const {};
}

Map<String, Object>? _translations(Object? raw) {
  if (raw == null) return {};
  if (raw is! Map) return null;
  final out = <String, Object>{};
  for (final entry in raw.entries) {
    final locale = '${entry.key}'.trim();
    if (!_extraLocales.contains(locale)) continue;
    final row = entry.value;
    if (row is! Map) return null;
    final text = '${row['text'] ?? ''}'.trim();
    final options = _strings(row['options']);
    final explanation = '${row['explanation'] ?? ''}';
    if (text.isEmpty || text.length > 2000) return null;
    if (options == null || options.length != 4 || options.any((item) => item.trim().isEmpty || item.length > 500)) {
      return null;
    }
    if (explanation.length > 4000) return null;
    out[locale] = {'text': text, 'options': options, 'explanation': explanation};
  }
  return out;
}

List<String> _decodeList(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return [for (final item in decoded) '$item'];
  } catch (_) {}
  return const [];
}

List<String>? _strings(Object? raw) {
  if (raw is! List) return null;
  return [for (final item in raw) '$item'];
}
