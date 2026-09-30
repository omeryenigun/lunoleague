import 'dart:io';
import 'dart:math';

import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/api/site_card_media.dart';

const siteCardsMetaKey = 'site_cards_v1';
const siteCardsCopyKey = 'site_cards_copy_v1';
const siteCardsSloganKey = 'site_cards_slogan_v1';
const siteCardsShotKey = 'site_cards_shots_v1';
const siteCardsGridKey = 'site_cards_grid_v1';
const siteCardsBilgiKey = 'site_cards_bilgi_v1';

const _iconPaths = [
  '/seed/luno_league_icon.png',
  'assets/images/logo.png',
];
const _galleryPaths = [
  '/seed/luno_league_gallery.png',
  'store/feature-graphic.png',
];

final _ids = Random.secure();

Future<void> migrateSiteCards(Connection db) async {
  await db.execute('''
    create table if not exists site_cards (
      id text primary key,
      name text not null,
      description text not null,
      status text not null,
      sort_order int not null
    )
  ''');
  await db.execute('alter table site_cards add column if not exists name_en text');
  await db.execute('alter table site_cards add column if not exists description_en text');
  await db.execute('alter table site_cards add column if not exists play_url text');
  await db.execute('alter table site_cards add column if not exists ios_url text');
  await db.execute('''
    create table if not exists site_media (
      id text primary key,
      card_id text not null references site_cards(id) on delete cascade,
      role text not null,
      bytes bytea not null,
      content_type text not null,
      sort_order int not null
    )
  ''');
}

/// Writes the two launch cards once. Later admin edits stay.
Future<void> seedSiteCards(Connection db) async {
  final meta = await db.execute(
    Sql.named('select value from kv_meta where item_key = @key'),
    parameters: {'key': siteCardsMetaKey},
  );
  if (meta.isNotEmpty && meta.first[0] == '1') return;

  await _upsertCard(
    db,
    id: 'luno_league',
    name: 'Luno League',
    description: 'Kelimeyi tahmin et.',
    status: 'live',
    sortOrder: 1,
  );
  await _upsertCard(
    db,
    id: 'luno_fall',
    name: 'Luno Fall',
    description: 'Harfler düşer, kelimeler doğar.',
    status: 'soon',
    sortOrder: 2,
  );

  final icon = await _storeSeedImage(
    db,
    cardId: 'luno_league',
    role: 'icon',
    paths: _iconPaths,
    sortOrder: 1,
  );
  final gallery = await _storeSeedImage(
    db,
    cardId: 'luno_league',
    role: siteMediaShowcase,
    paths: _galleryPaths,
    sortOrder: 1,
  );
  if (!icon || !gallery) {
    stdout.writeln('site cards waiting for images');
    return;
  }
  await db.execute(
    Sql.named('''
      insert into kv_meta (item_key, value)
      values (@key, '1')
      on conflict (item_key) do update set value = excluded.value
    '''),
    parameters: {'key': siteCardsMetaKey},
  );
  stdout.writeln('site cards seeded league=live fall=soon');
}

/// Fills English copy and the Play link once. Existing text stays.
Future<void> seedSiteCardCopy(Connection db) async {
  final meta = await db.execute(
    Sql.named('select value from kv_meta where item_key = @key'),
    parameters: {'key': siteCardsCopyKey},
  );
  if (meta.isNotEmpty && meta.first[0] == '1') return;
  await db.execute(
    Sql.named('''
      update site_cards
      set name_en = coalesce(name_en, @nameEn),
          description_en = coalesce(description_en, @descriptionEn),
          play_url = coalesce(play_url, @playUrl)
      where id = 'luno_league'
    '''),
    parameters: {
      'nameEn': 'Luno League',
      'descriptionEn': 'Guess the word.',
      'playUrl': 'https://play.google.com/store/apps/details?id=com.lunoleague.game',
    },
  );
  await db.execute(
    Sql.named('''
      update site_cards
      set name_en = coalesce(name_en, @nameEn),
          description_en = coalesce(description_en, @descriptionEn)
      where id = 'luno_fall'
    '''),
    parameters: {
      'nameEn': 'Luno Fall',
      'descriptionEn': 'Letters fall. Words appear.',
    },
  );
  await db.execute(
    Sql.named('''
      insert into kv_meta (item_key, value)
      values (@key, '1')
      on conflict (item_key) do update set value = excluded.value
    '''),
    parameters: {'key': siteCardsCopyKey},
  );
  stdout.writeln('site card copy seeded');
}

/// Replaces the short blurbs with game slogans, once.
Future<void> seedSiteCardSlogans(Connection db) async {
  final meta = await db.execute(
    Sql.named('select value from kv_meta where item_key = @key'),
    parameters: {'key': siteCardsSloganKey},
  );
  if (meta.isNotEmpty && meta.first[0] == '1') return;
  await db.execute(
    Sql.named('''
      update site_cards
      set description = @description, description_en = @descriptionEn
      where id = 'luno_league'
    '''),
    parameters: {
      'description': 'Gizli kelimeyi harf harf çöz.',
      'descriptionEn': 'Solve the hidden word, letter by letter.',
    },
  );
  await db.execute(
    Sql.named('''
      update site_cards
      set description = @description, description_en = @descriptionEn
      where id = 'luno_fall'
    '''),
    parameters: {
      'description': 'Harfler düşer, kelimeler doğar.',
      'descriptionEn': 'Letters fall. Words appear.',
    },
  );
  await db.execute(
    Sql.named('''
      insert into kv_meta (item_key, value)
      values (@key, '1')
      on conflict (item_key) do update set value = excluded.value
    '''),
    parameters: {'key': siteCardsSloganKey},
  );
  stdout.writeln('site card slogans seeded');
}

/// Adds the mobile play screens to the Luno League card once.
Future<void> seedSiteCardShots(Connection db) async {
  final meta = await db.execute(
    Sql.named('select value from kv_meta where item_key = @key'),
    parameters: {'key': siteCardsShotKey},
  );
  if (meta.isNotEmpty && meta.first[0] == '1') return;
  const shots = [
    ['/seed/luno_shot_play.png', 'assets/site/luno_play.png', 2],
    ['/seed/luno_shot_win.png', 'assets/site/luno_win.png', 3],
  ];
  for (final shot in shots) {
    File? file;
    for (final path in [shot[0] as String, shot[1] as String]) {
      final candidate = File(path);
      if (candidate.existsSync()) {
        file = candidate;
        break;
      }
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final type = imageContentType(bytes);
    if (type == null || bytes.length > siteMediaMaxBytes) return;
    await _insertMedia(
      db,
      cardId: 'luno_league',
      role: siteMediaShot,
      bytes: bytes,
      contentType: type,
      sortOrder: shot[2] as int,
    );
  }
  await db.execute(
    Sql.named('''
      insert into kv_meta (item_key, value)
      values (@key, '1')
      on conflict (item_key) do update set value = excluded.value
    '''),
    parameters: {'key': siteCardsShotKey},
  );
  stdout.writeln('site card shots seeded');
}

/// Adds the Luno Grid showcase card once. Later admin edits stay.
Future<void> seedSiteCardGrid(Connection db) async {
  final meta = await db.execute(
    Sql.named('select value from kv_meta where item_key = @key'),
    parameters: {'key': siteCardsGridKey},
  );
  if (meta.isNotEmpty && meta.first[0] == '1') return;
  await db.execute(
    Sql.named('''
      insert into site_cards (
        id, name, description, status, sort_order, name_en, description_en
      )
      values (
        'luno_grid', @name, @description, 'soon', 3, @nameEn, @descriptionEn
      )
      on conflict (id) do update set
        name = excluded.name,
        description = excluded.description,
        status = excluded.status,
        sort_order = excluded.sort_order,
        name_en = excluded.name_en,
        description_en = excluded.description_en
    '''),
    parameters: {
      'name': 'Luno Kelime Izgarası',
      'description': 'Harflerden kelime üret, ızgarayı doldur.',
      'nameEn': 'Luno Word Grid',
      'descriptionEn': 'Spell words from the letters and fill the grid.',
    },
  );
  await db.execute(
    Sql.named('''
      insert into kv_meta (item_key, value)
      values (@key, '1')
      on conflict (item_key) do update set value = excluded.value
    '''),
    parameters: {'key': siteCardsGridKey},
  );
  stdout.writeln('site card grid seeded soon');
}

/// Adds the Luno Bilgi showcase card once. Later admin edits stay.
Future<void> seedSiteCardBilgi(Connection db) async {
  final meta = await db.execute(
    Sql.named('select value from kv_meta where item_key = @key'),
    parameters: {'key': siteCardsBilgiKey},
  );
  if (meta.isNotEmpty && meta.first[0] == '1') return;
  await db.execute(
    Sql.named('''
      insert into site_cards (
        id, name, description, status, sort_order, name_en, description_en
      )
      values (
        'luno_bilgi', @name, @description, 'soon', 4, @nameEn, @descriptionEn
      )
      on conflict (id) do update set
        name = excluded.name,
        description = excluded.description,
        status = excluded.status,
        sort_order = excluded.sort_order,
        name_en = excluded.name_en,
        description_en = excluded.description_en
    '''),
    parameters: {
      'name': 'Luno Bilgi',
      'description': 'Dört şıktan doğruyu bul.',
      'nameEn': 'Luno Bilgi',
      'descriptionEn': 'Find the right answer among four.',
    },
  );
  final icon = await _storeSeedImage(
    db,
    cardId: 'luno_bilgi',
    role: siteMediaIcon,
    paths: ['/seed/luno_bilgi_icon.png', 'assets/images/luno_bilgi_logo.png'],
    sortOrder: 1,
  );
  if (!icon) {
    stdout.writeln('site card bilgi waiting for icon');
    return;
  }
  await db.execute(
    Sql.named('''
      insert into kv_meta (item_key, value)
      values (@key, '1')
      on conflict (item_key) do update set value = excluded.value
    '''),
    parameters: {'key': siteCardsBilgiKey},
  );
  stdout.writeln('site card bilgi seeded soon');
}

void mountSiteCards(Router router, Connection db) {
  router
    ..get('/v1/site/cards', (request) async => _ok(await _cards(db, request)))
    ..get('/v1/site/media/<id>', (Request request, String id) => _media(db, id))
    ..get('/v1/admin/site-cards', (request) async {
      if (await adminIdOf(db, request) == null) return _fail(401, 'Oturum geçersiz.');
      return _ok(await _cards(db, request));
    })
    ..put('/v1/admin/site-cards/<id>', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) return _fail(401, 'Oturum geçersiz.');
      return _update(db, request, id);
    })
    ..post('/v1/admin/site-cards/<id>/icon', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) return _fail(401, 'Oturum geçersiz.');
      return _upload(db, request, id, role: siteMediaIcon);
    })
    ..post('/v1/admin/site-cards/<id>/showcase', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) return _fail(401, 'Oturum geçersiz.');
      return _upload(db, request, id, role: siteMediaShowcase);
    })
    ..post('/v1/admin/site-cards/<id>/shots', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) return _fail(401, 'Oturum geçersiz.');
      return _upload(db, request, id, role: siteMediaShot);
    })
    ..post('/v1/admin/site-cards/<id>/images', (Request request, String id) async {
      if (await adminIdOf(db, request) == null) return _fail(401, 'Oturum geçersiz.');
      return _upload(db, request, id, role: siteMediaShot);
    })
    ..delete(
      '/v1/admin/site-cards/<id>/images/<mediaId>',
      (Request request, String id, String mediaId) async {
        if (await adminIdOf(db, request) == null) return _fail(401, 'Oturum geçersiz.');
        final rows = await db.execute(
          Sql.named('''
            delete from site_media
            where id = @mediaId and card_id = @cardId
              and role in ('icon', 'showcase', 'shot', 'gallery')
          '''),
          parameters: {'mediaId': mediaId, 'cardId': id},
        );
        if (rows.affectedRows == 0) return _fail(404, 'Görsel bulunamadı.');
        return _ok(await _cards(db, request));
      },
    );
}

/// Turns the old mixed gallery into one showcase and the remaining shots.
Future<void> classifySiteCardMedia(Connection db) async {
  final gallery = await db.execute('''
    select id, card_id from site_media
    where role = 'gallery'
    order by card_id, sort_order, id
  ''');
  if (gallery.isEmpty) return;
  final showcaseCards = await db.execute('''
    select distinct card_id from site_media where role = 'showcase'
  ''');
  final hasShowcase = {for (final row in showcaseCards) row[0] as String};
  String? lastCard;
  for (final row in gallery) {
    final id = row[0] as String;
    final cardId = row[1] as String;
    final firstOfCard = lastCard != cardId;
    lastCard = cardId;
    final role = firstOfCard && !hasShowcase.contains(cardId)
        ? siteMediaShowcase
        : siteMediaShot;
    await db.execute(
      Sql.named('update site_media set role = @role where id = @id'),
      parameters: {'role': role, 'id': id},
    );
  }
}

Future<void> _upsertCard(
  Connection db, {
  required String id,
  required String name,
  required String description,
  required String status,
  required int sortOrder,
}) {
  return db.execute(
    Sql.named('''
      insert into site_cards (id, name, description, status, sort_order)
      values (@id, @name, @description, @status, @sort)
      on conflict (id) do update set
        name = excluded.name,
        description = excluded.description,
        status = excluded.status,
        sort_order = excluded.sort_order
    '''),
    parameters: {
      'id': id,
      'name': name,
      'description': description,
      'status': status,
      'sort': sortOrder,
    },
  );
}

Future<bool> _storeSeedImage(
  Connection db, {
  required String cardId,
  required String role,
  required List<String> paths,
  required int sortOrder,
}) async {
  final existing = await db.execute(
    Sql.named(
      'select id from site_media where card_id = @card and role = @role limit 1',
    ),
    parameters: {'card': cardId, 'role': role},
  );
  if (existing.isNotEmpty) return true;
  File? file;
  for (final path in paths) {
    final candidate = File(path);
    if (candidate.existsSync()) {
      file = candidate;
      break;
    }
  }
  if (file == null) return false;
  final bytes = await file.readAsBytes();
  final type = imageContentType(bytes);
  if (type == null || bytes.length > siteMediaMaxBytes) return false;
  await _insertMedia(
    db,
    cardId: cardId,
    role: role,
    bytes: bytes,
    contentType: type,
    sortOrder: sortOrder,
  );
  return true;
}

Future<Response> _update(Connection db, Request request, String id) async {
  final found = await db.execute(
    Sql.named('select id from site_cards where id = @id'),
    parameters: {'id': id},
  );
  if (found.isEmpty) return _fail(404, 'Kart bulunamadı.');
  final body = await readJson(request);
  final name = _text(body['name'], max: 80);
  final description = _text(body['description'], max: 500);
  final nameEn = _optional(body['nameEn'], max: 80);
  final descriptionEn = _optional(body['descriptionEn'], max: 500);
  final playUrl = _url(body['playUrl']);
  final iosUrl = _url(body['iosUrl']);
  final status = body['status'];
  final sort = body['sortOrder'];
  if (name == null || description == null) {
    return _fail(400, 'Ad ve açıklama gerekli.');
  }
  if (nameEn == null || descriptionEn == null || playUrl == null || iosUrl == null) {
    return _fail(400, 'İngilizce metin veya mağaza linki geçersiz.');
  }
  if (status != 'live' && status != 'soon') {
    return _fail(400, 'Durum yayında veya yakında olmalı.');
  }
  if (sort is! int || sort < 1 || sort > 999) {
    return _fail(400, 'Sıra 1 ile 999 arasında olmalı.');
  }
  await db.execute(
    Sql.named('''
      update site_cards
      set name = @name, description = @description, status = @status, sort_order = @sort,
          name_en = @nameEn, description_en = @descriptionEn,
          play_url = @playUrl, ios_url = @iosUrl
      where id = @id
    '''),
    parameters: {
      'name': name,
      'description': description,
      'nameEn': nameEn,
      'descriptionEn': descriptionEn,
      'playUrl': playUrl,
      'iosUrl': iosUrl,
      'status': status,
      'sort': sort,
      'id': id,
    },
  );
  final order = body['imageOrder'];
  if (order is List) {
    final ids = [for (final item in order) if (item is String) item];
    for (var i = 0; i < ids.length; i++) {
      await db.execute(
        Sql.named('''
          update site_media
          set sort_order = @sort
          where id = @mediaId and card_id = @cardId and role = 'shot'
        '''),
        parameters: {'sort': i + 1, 'mediaId': ids[i], 'cardId': id},
      );
    }
  }
  return _ok(await _cards(db, request));
}

Future<Response> _upload(
  Connection db,
  Request request,
  String id, {
  required String role,
}) async {
  final found = await db.execute(
    Sql.named('select id from site_cards where id = @id'),
    parameters: {'id': id},
  );
  if (found.isEmpty) return _fail(404, 'Kart bulunamadı.');
  final chunks = <int>[];
  var tooBig = false;
  await for (final chunk in request.read()) {
    if (tooBig) continue;
    chunks.addAll(chunk);
    if (chunks.length > siteMediaUploadMaxBytes) tooBig = true;
  }
  if (chunks.isEmpty) return _fail(400, 'Görsel boş.');
  if (tooBig) return _fail(413, 'Görsel 8 MB sınırını aşıyor.');
  if (imageContentType(chunks) == null) {
    return _fail(400, 'Yalnız png, jpeg veya webp.');
  }
  final web = prepareWebImage(chunks, role: role);
  if (web == null) return _fail(400, 'Görsel işlenemedi.');
  if (role == siteMediaShot) {
    final count = await _mediaCount(db, id, siteMediaShot);
    if (count >= siteShotLimit) {
      return _fail(400, 'Oyun ekran görüntüsü en fazla 15 olabilir.');
    }
  }
  if (role == siteMediaIcon || role == siteMediaShowcase) {
    await db.execute(
      Sql.named('delete from site_media where card_id = @card and role = @role'),
      parameters: {'card': id, 'role': role},
    );
  }
  final sort = role == siteMediaShot ? await _nextSort(db, id, role) : 1;
  await _insertMedia(
    db,
    cardId: id,
    role: role,
    bytes: web,
    contentType: 'image/webp',
    sortOrder: sort,
  );
  return _ok(await _cards(db, request));
}

Future<int> _mediaCount(Connection db, String cardId, String role) async {
  final rows = await db.execute(
    Sql.named('''
      select count(*) from site_media
      where card_id = @card and role = @role
    '''),
    parameters: {'card': cardId, 'role': role},
  );
  final value = rows.first[0];
  return value is int ? value : int.parse('$value');
}

Future<int> _nextSort(Connection db, String cardId, String role) async {
  final rows = await db.execute(
    Sql.named('''
      select coalesce(max(sort_order), 0) from site_media
      where card_id = @card and role = @role
    '''),
    parameters: {'card': cardId, 'role': role},
  );
  final value = rows.first[0];
  final current = value is int ? value : int.parse('$value');
  return current + 1;
}

Future<void> _insertMedia(
  Connection db, {
  required String cardId,
  required String role,
  required List<int> bytes,
  required String contentType,
  required int sortOrder,
}) {
  return db.execute(
    Sql.named('''
      insert into site_media (id, card_id, role, bytes, content_type, sort_order)
      values (@id, @card, @role, decode(@hex, 'hex'), @type, @sort)
    '''),
    parameters: {
      'id': _newId(),
      'card': cardId,
      'role': role,
      'hex': _hex(bytes),
      'type': contentType,
      'sort': sortOrder,
    },
  );
}

Future<Map<String, dynamic>> _cards(Connection db, Request request) async {
  final origin = _origin(request);
  final cards = await db.execute(
    '''
    select id, name, description, status, sort_order, name_en, description_en, play_url, ios_url
    from site_cards order by sort_order, name
    ''',
  );
  final media = await db.execute(
    'select id, card_id, role, sort_order from site_media order by sort_order, id',
  );
  final byCard = <String, List<ResultRow>>{};
  for (final row in media) {
    byCard.putIfAbsent(row[1] as String, () => []).add(row);
  }
  return {
    'cards': [
      for (final card in cards)
        _cardJson(card, byCard[card[0] as String] ?? const [], origin),
    ],
  };
}

Map<String, dynamic> _cardJson(ResultRow card, List<ResultRow> media, String origin) {
  Map<String, dynamic>? icon;
  Map<String, dynamic>? showcase;
  final shots = <Map<String, dynamic>>[];
  for (final row in media) {
    final item = {
      'id': row[0],
      'url': '$origin/v1/site/media/${row[0]}',
      'sortOrder': row[3],
    };
    switch (row[2]) {
      case siteMediaIcon:
        icon = item;
      case siteMediaShowcase:
        showcase = item;
      case siteMediaShot:
        shots.add(item);
    }
  }
  return {
    'id': card[0],
    'name': card[1],
    'description': card[2],
    'status': card[3],
    'sortOrder': card[4],
    'nameEn': card[5],
    'descriptionEn': card[6],
    'playUrl': card[7],
    'iosUrl': card[8],
    'icon': icon,
    'iconUrl': icon?['url'],
    'showcase': showcase,
    'shots': shots,
    'images': [
      ?showcase,
      ...shots,
    ],
  };
}

Future<Response> _media(Connection db, String id) async {
  final rows = await db.execute(
    Sql.named(
      "select encode(bytes, 'hex'), content_type from site_media where id = @id",
    ),
    parameters: {'id': id},
  );
  if (rows.isEmpty) return _fail(404, 'Görsel bulunamadı.');
  final hex = rows.first[0] as String;
  return Response.ok(
    _unhex(hex),
    headers: {
      'content-type': rows.first[1] as String,
      'cache-control': 'public, max-age=60',
    },
  );
}

String? _text(Object? value, {required int max}) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty || text.length > max) return null;
  return text;
}

String? _optional(Object? value, {required int max}) {
  if (value == null) return '';
  if (value is! String) return null;
  final text = value.trim();
  if (text.length > max) return null;
  return text;
}

String? _url(Object? value) {
  final text = _optional(value, max: 300);
  if (text == null || text.isEmpty) return text;
  final uri = Uri.tryParse(text);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return text;
}

Response _ok(Object body) => jsonResponse(body);

Response _fail(int status, String message) =>
    jsonResponse({'error': message}, status: status);

String _origin(Request request) {
  final host = request.headers['x-forwarded-host'] ?? request.headers['host'];
  if (host != null && host.isNotEmpty) {
    final forwarded = request.headers['x-forwarded-proto'];
    final proto = (forwarded == null || forwarded.isEmpty)
        ? 'https'
        : forwarded.split(',').first.trim();
    return '$proto://$host';
  }
  return request.requestedUri.origin;
}

String _newId() {
  final bytes = List<int>.generate(16, (_) => _ids.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

List<int> _unhex(String hex) {
  final out = List<int>.filled(hex.length ~/ 2, 0);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}
