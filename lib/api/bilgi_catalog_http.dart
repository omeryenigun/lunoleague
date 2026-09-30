import 'dart:convert';

import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/bilgi_count_snapshot.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_catalog.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

Future<void> migrateBilgiCatalog(Connection db) async {
  await db.execute('''
    create table if not exists bilgi_categories (
      id text primary key,
      group_name text not null,
      name text not null,
      emoji text not null,
      sort_order int not null default 0
    )
  ''');
  await db.execute(
    'alter table bilgi_categories add column if not exists popular boolean not null default false',
  );
  await db.execute('''
    create table if not exists bilgi_subcategories (
      category_id text not null references bilgi_categories(id) on delete cascade,
      name text not null,
      emoji text not null default '',
      sort_order int not null default 0,
      primary key (category_id, name)
    )
  ''');
  await db.execute('''
    create table if not exists bilgi_catalog_meta (
      key text primary key,
      value text not null
    )
  ''');
  final seeded = await db.execute("select value from bilgi_catalog_meta where key = 'seeded'");
  if (seeded.isEmpty) {
    await _seedBuiltIn(db);
    await db.execute("insert into bilgi_catalog_meta (key, value) values ('seeded', '1')");
  }
  await _linkQuestionCategories(db);
  await _seedGroupLabels(db);
  await db.execute('''
    do \$\$
    begin
      if not exists (select 1 from pg_constraint where conname = 'bilgi_questions_category_fk') then
        alter table bilgi_questions
          add constraint bilgi_questions_category_fk
          foreign key (category_id) references bilgi_categories(id);
      end if;
    end
    \$\$;
  ''');
}

Future<void> _seedGroupLabels(Connection db) async {
  for (final group in bilgiGroupLabels.entries) {
    for (final locale in group.value.entries) {
      await db.execute(
        Sql.named('''
          insert into bilgi_labels (locale, scope, key, label)
          values (@locale, 'group', @key, @label)
          on conflict (locale, scope, key) do nothing
        '''),
        parameters: {'locale': locale.key, 'key': group.key, 'label': locale.value},
      );
    }
  }
}

Future<void> _seedBuiltIn(Connection db) async {
  final existing = await db.execute('select count(*) from bilgi_categories');
  final count = existing.first[0];
  final total = count is int ? count : (count is num ? count.toInt() : 0);
  if (total > 0) return;
  for (var i = 0; i < bilgiCategories.length; i++) {
    final category = bilgiCategories[i];
    await db.execute(
      Sql.named('''
        insert into bilgi_categories (id, group_name, name, emoji, sort_order)
        values (@id, @group, @name, @emoji, @sort)
        on conflict (id) do nothing
      '''),
      parameters: {
        'id': category.id,
        'group': category.group,
        'name': category.name,
        'emoji': category.emoji,
        'sort': i,
      },
    );
    for (var n = 0; n < category.subs.length; n++) {
      await db.execute(
        Sql.named('''
          insert into bilgi_subcategories (category_id, name, emoji, sort_order)
          values (@categoryId, @name, '', @sort)
          on conflict (category_id, name) do nothing
        '''),
        parameters: {'categoryId': category.id, 'name': category.subs[n], 'sort': n},
      );
    }
  }
}

Future<void> _linkQuestionCategories(Connection db) async {
  final orphans = await db.execute('''
    select distinct category_id from bilgi_questions q
    where not exists (select 1 from bilgi_categories c where c.id = q.category_id)
  ''');
  for (final row in orphans) {
    final id = '${row[0]}'.trim();
    if (id.isEmpty) continue;
    await db.execute(
      Sql.named('''
        insert into bilgi_categories (id, group_name, name, emoji, sort_order)
        values (@id, @group, @id, '📚', 1000)
        on conflict (id) do nothing
      '''),
      parameters: {'id': id, 'group': bilgiGroups.first},
    );
  }
  final tagged = await db.execute('select category_id, tags_json from bilgi_questions');
  for (final row in tagged) {
    final categoryId = '${row[0]}'.trim();
    if (categoryId.isEmpty) continue;
    final tags = _decodeList(row[1]);
    for (final tag in tags) {
      final name = tag.trim();
      if (name.isEmpty) continue;
      await db.execute(
        Sql.named('''
          insert into bilgi_subcategories (category_id, name, emoji, sort_order)
          values (@categoryId, @name, '', 1000)
          on conflict (category_id, name) do nothing
        '''),
        parameters: {'categoryId': categoryId, 'name': name},
      );
    }
  }
}

void mountBilgiCatalog(Router router, Connection db) {
  router
    ..get('/v1/bilgi/catalog', (request) => _catalog(db))
    ..put('/v1/admin/bilgi-categories', (request) => _save(request, db))
    ..put('/v1/admin/bilgi-categories/popular', (request) => _setPopular(request, db))
    ..delete('/v1/admin/bilgi-categories/<id>', (Request request, String id) => _delete(request, db, id))
    ..delete('/v1/admin/bilgi-categories/<id>/subs/<name>', (Request request, String id, String name) => _deleteSub(request, db, id, name));
}

Future<Map<String, dynamic>> bilgiAuthoritativeCatalog(Connection db) async {
  final categories = await db.execute('''
    select id, group_name, name, emoji, popular
    from bilgi_categories
    order by sort_order, name
  ''');
  final subs = await db.execute('''
    select category_id, name, emoji
    from bilgi_subcategories
    order by sort_order, name
  ''');
  final byCategory = <String, List<Map<String, String>>>{};
  final icons = <String, String>{};
  for (final row in subs) {
    final categoryId = '${row[0]}';
    final name = '${row[1]}';
    final emoji = '${row[2]}'.trim();
    byCategory.putIfAbsent(categoryId, () => []).add({'name': name, 'emoji': emoji});
    if (emoji.isNotEmpty) icons[name] = emoji;
  }
  return {
    'authoritative': true,
    'custom': [
      for (final row in categories)
        {
          'id': '${row[0]}',
          'group': '${row[1]}',
          'name': '${row[2]}',
          'emoji': '${row[3]}',
          'subs': [for (final sub in byCategory['${row[0]}'] ?? const []) sub['name']],
          'active': true,
          'popular': _isPopular(row[4]),
        },
    ],
    if (icons.isNotEmpty) 'subEmoji': icons,
  };
}

bool _isPopular(Object? raw) {
  if (raw == true) return true;
  if (raw is num) return raw != 0;
  final text = '$raw'.toLowerCase();
  return text == 't' || text == 'true' || text == '1';
}

Future<Response> _catalog(Connection db) async {
  return jsonResponse(await bilgiAuthoritativeCatalog(db));
}

Future<Response> _save(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final name = '${body['name'] ?? ''}'.trim();
  final emoji = '${body['emoji'] ?? ''}'.trim();
  final group = '${body['group'] ?? ''}'.trim();
  if (name.isEmpty || emoji.isEmpty || group.isEmpty) {
    return jsonResponse({'error': 'Kategori bulunamadı.'}, status: 400);
  }
  var id = '${body['id'] ?? ''}'.trim();
  if (id.isEmpty) id = 'c${DateTime.now().microsecondsSinceEpoch}';
  if (id.length > 80) return jsonResponse({'error': 'Kategori bulunamadı.'}, status: 400);
  final sortRows = await db.execute('select coalesce(max(sort_order), -1) from bilgi_categories');
  final maxSort = sortRows.first[0];
  final nextSort = (maxSort is int ? maxSort : (maxSort is num ? maxSort.toInt() : -1)) + 1;
  await db.execute(
    Sql.named('''
      insert into bilgi_categories (id, group_name, name, emoji, sort_order)
      values (@id, @group, @name, @emoji, @sort)
      on conflict (id) do update set
        group_name = excluded.group_name,
        name = excluded.name,
        emoji = excluded.emoji
    '''),
    parameters: {'id': id, 'group': group, 'name': name, 'emoji': emoji, 'sort': nextSort},
  );
  final rename = body['renameSub'];
  if (rename is Map) {
    final from = '${rename['from'] ?? ''}'.trim();
    final to = '${rename['to'] ?? ''}'.trim();
    final subEmoji = '${rename['emoji'] ?? ''}'.trim();
    if (from.isNotEmpty && to.isNotEmpty && from != to) {
      final taken = await db.execute(
        Sql.named('select 1 from bilgi_subcategories where category_id = @id and name = @name'),
        parameters: {'id': id, 'name': to},
      );
      if (taken.isNotEmpty) return jsonResponse({'error': 'Bu alt kategori zaten var.'}, status: 409);
      await _renameSub(db, id, from, to, subEmoji);
    } else if (from.isNotEmpty && subEmoji.isNotEmpty) {
      await db.execute(
        Sql.named('update bilgi_subcategories set emoji = @emoji where category_id = @id and name = @name'),
        parameters: {'id': id, 'emoji': subEmoji, 'name': from},
      );
    }
  }
  final addSub = '${body['addSub'] ?? ''}'.trim();
  if (addSub.isNotEmpty) {
    final subSort = await db.execute(
      Sql.named('select coalesce(max(sort_order), -1) from bilgi_subcategories where category_id = @id'),
      parameters: {'id': id},
    );
    final raw = subSort.first[0];
    final sort = (raw is int ? raw : (raw is num ? raw.toInt() : -1)) + 1;
    await db.execute(
      Sql.named('''
        insert into bilgi_subcategories (category_id, name, emoji, sort_order)
        values (@id, @name, '', @sort)
        on conflict (category_id, name) do nothing
      '''),
      parameters: {'id': id, 'name': addSub, 'sort': sort},
    );
  }
  return jsonResponse({'id': id});
}

Future<Response> _setPopular(Request request, Connection db) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final body = await readJson(request);
  final id = '${body['id'] ?? ''}'.trim();
  if (id.isEmpty || id.length > 80 || body['popular'] is! bool) {
    return jsonResponse({'error': 'Kategori bulunamadı.'}, status: 400);
  }
  final updated = await db.execute(
    Sql.named('update bilgi_categories set popular = @popular where id = @id'),
    parameters: {'id': id, 'popular': body['popular'] as bool},
  );
  if (updated.affectedRows == 0) return jsonResponse({'error': 'Kategori bulunamadı.'}, status: 404);
  return jsonResponse({'ok': true});
}

Future<void> _renameSub(Connection db, String categoryId, String from, String to, String emoji) async {
  await db.execute(
    Sql.named('update bilgi_subcategories set name = @to, emoji = case when @emoji = \'\' then emoji else @emoji end where category_id = @id and name = @from'),
    parameters: {'id': categoryId, 'from': from, 'to': to, 'emoji': emoji},
  );
  final oldKey = '$categoryId|$from';
  final newKey = '$categoryId|$to';
  await db.execute(
    Sql.named('update bilgi_labels set key = @next where scope = \'sub\' and key = @previous'),
    parameters: {'previous': oldKey, 'next': newKey},
  );
  await db.execute(
    Sql.named('update bilgi_active set key = @next where kind = \'sub\' and key = @previous'),
    parameters: {'previous': oldKey, 'next': newKey},
  );
  final rows = await db.execute(
    Sql.named('''
      select id, tags_json from bilgi_questions
      where category_id = @id and tags_json::jsonb @> @tag::jsonb
    '''),
    parameters: {'id': categoryId, 'tag': jsonEncode([from])},
  );
  for (final row in rows) {
    final tags = [for (final item in _decodeList(row[1])) item == from ? to : item];
    await db.execute(
      Sql.named('update bilgi_questions set tags_json = @tags where id = @id'),
      parameters: {'id': '${row[0]}', 'tags': jsonEncode(tags)},
    );
  }
  await moveBilgiCountSubName(db, categoryId, from, to);
}

Future<Response> _delete(Request request, Connection db, String id) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final key = Uri.decodeComponent(id).trim();
  if (key.isEmpty) return jsonResponse({'error': 'Kategori bulunamadı.'}, status: 400);
  final used = await db.execute(
    Sql.named('select count(*) from bilgi_questions where category_id = @id'),
    parameters: {'id': key},
  );
  final raw = used.first[0];
  final count = raw is int ? raw : (raw is num ? raw.toInt() : 0);
  if (count > 0) return jsonResponse({'error': 'Bu kategoride soru var.'}, status: 409);
  await db.execute(
    Sql.named("delete from bilgi_labels where scope = 'category' and key = @id"),
    parameters: {'id': key},
  );
  await db.execute(
    Sql.named("delete from bilgi_labels where scope = 'sub' and starts_with(key, @prefix)"),
    parameters: {'prefix': '$key|'},
  );
  await db.execute(
    Sql.named("delete from bilgi_active where kind = 'category' and key = @id"),
    parameters: {'id': key},
  );
  await db.execute(
    Sql.named("delete from bilgi_active where kind = 'sub' and starts_with(key, @prefix)"),
    parameters: {'prefix': '$key|'},
  );
  await db.execute(
    Sql.named('delete from bilgi_categories where id = @id'),
    parameters: {'id': key},
  );
  return jsonResponse({'ok': true});
}

Future<Response> _deleteSub(Request request, Connection db, String id, String name) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final categoryId = Uri.decodeComponent(id).trim();
  final sub = Uri.decodeComponent(name).trim();
  if (categoryId.isEmpty || sub.isEmpty) return jsonResponse({'error': 'Alt kategori bulunamadı.'}, status: 400);
  final used = await db.execute(
    Sql.named('''
      select count(*) from bilgi_questions
      where category_id = @id and tags_json::jsonb @> @tag::jsonb
    '''),
    parameters: {'id': categoryId, 'tag': jsonEncode([sub])},
  );
  final raw = used.first[0];
  final count = raw is int ? raw : (raw is num ? raw.toInt() : 0);
  if (count > 0) return jsonResponse({'error': 'Bu alt kategoride soru var.'}, status: 409);
  final key = '$categoryId|$sub';
  await db.execute(
    Sql.named("delete from bilgi_labels where scope = 'sub' and key = @key"),
    parameters: {'key': key},
  );
  await db.execute(
    Sql.named("delete from bilgi_active where kind = 'sub' and key = @key"),
    parameters: {'key': key},
  );
  await db.execute(
    Sql.named('delete from bilgi_subcategories where category_id = @id and name = @name'),
    parameters: {'id': categoryId, 'name': sub},
  );
  return jsonResponse({'ok': true});
}

List<String> _decodeList(Object? raw) {
  if (raw is! String || raw.isEmpty) return const [];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is List) return [for (final item in decoded) '$item'];
  } catch (_) {}
  return const [];
}
