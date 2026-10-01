import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/data/remote/postgres_kv.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';
import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

/// Bilgi accounts live in `kv_entry` box `luno_bilgi__users` (same scope as the app).
void mountBilgiUsers(Router router, Connection db) {
  final store = ScopedKeyValueStore(PostgresKv(db), GameIds.lunoBilgi);
  router
    ..get('/v1/admin/bilgi-users', (request) => _list(request, db, store))
    ..patch('/v1/admin/bilgi-users/<id>', (Request request, String id) {
      return _setBan(request, db, store, id);
    })
    ..put('/v1/bilgi/users', (request) => _upsert(request, store));
}

Future<Response> _list(Request request, Connection db, KeyValueStore store) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final users = await store.values('users');
  final players = [for (final row in users) BilgiProfile.fromMap(row)];
  final accounts = await LunoAccountDirectory(lunoAccountRoot(store)).all();
  final listed = annotateBilgiAccounts(players, accounts);
  listed.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  players.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return jsonResponse({
    'users': [for (final user in listed) user.toPublicMap()],
    'players': [for (final user in players) user.toPublicMap()],
  });
}

Future<Response> _setBan(
  Request request,
  Connection db,
  KeyValueStore store,
  String id,
) async {
  if (await adminIdOf(db, request) == null) {
    return jsonResponse({'error': 'Oturum geçersiz.'}, status: 401);
  }
  final key = id.trim();
  if (key.isEmpty || key.length > 80) {
    return jsonResponse({'error': 'Kullanıcı bulunamadı.'}, status: 400);
  }
  final raw = await store.get('users', key);
  if (raw == null) {
    return jsonResponse({'error': 'Kullanıcı bulunamadı.'}, status: 404);
  }
  final body = await readJson(request);
  final banned = body['banned'] == true;
  final reason = banned ? '${body['banReason'] ?? ''}'.trim() : '';
  final next = BilgiProfile.fromMap(raw).copyWith(banned: banned, banReason: reason);
  await store.put('users', key, next.toMap());
  return jsonResponse({'ok': true, 'user': next.toPublicMap()});
}

Future<Response> _upsert(Request request, KeyValueStore store) async {
  final body = await readJson(request);
  final incoming = BilgiProfile.fromMap(Map<String, dynamic>.from(body));
  if (incoming.id.trim().isEmpty || incoming.id.length > 80) {
    return jsonResponse({'error': 'Kullanıcı geçersiz.'}, status: 400);
  }
  final saved = await mergeBilgiUser(store, incoming);
  return jsonResponse({'ok': true, 'user': saved.toPublicMap()});
}

/// Upserts by email when present, otherwise by id. Client cannot clear a server ban.
Future<BilgiProfile> mergeBilgiUser(KeyValueStore store, BilgiProfile incoming) async {
  final all = await store.values('users');
  Map<String, dynamic>? existing;
  final email = incoming.email.trim().toLowerCase();
  if (email.isNotEmpty) {
    for (final row in all) {
      if ('${row['email'] ?? ''}'.trim().toLowerCase() == email) {
        existing = row;
        break;
      }
    }
  }
  existing ??= await store.get('users', incoming.id);
  final banned = existing == null ? incoming.banned : existing['banned'] == true;
  final banReason = existing == null ? incoming.banReason : '${existing['banReason'] ?? ''}';
  final id = existing == null ? incoming.id : '${existing['id']}';
  final merged = existing == null
      ? bilgiBornProfile(incoming)
      : bilgiKeepServerWallet(BilgiProfile.fromMap(existing), incoming);
  final guest = incoming.email.trim().isEmpty && incoming.passwordHash.isEmpty;
  if (guest) {
    final saved = merged.copyWith(id: id, banned: banned, banReason: banReason, email: '', passwordHash: '');
    await store.put('users', id, saved.toMap());
    return saved;
  }
  final directory = LunoAccountDirectory(lunoAccountRoot(store));
  final known = await directory.find(email: email);
  final otherId = known?.progressIds[GameIds.lunoBilgi];
  if (otherId != null && otherId.isNotEmpty && otherId != id) {
    final row = await store.get('users', otherId);
    if (row != null) return BilgiProfile.fromMap(row);
  }
  final link = await directory.link(
    gameId: GameIds.lunoBilgi,
    progressId: id,
    displayName: incoming.username,
    provider: incoming.passwordHash.isEmpty ? 'google' : 'email',
    email: incoming.email,
  );
  final saved = merged.copyWith(
    id: id,
    banned: banned,
    banReason: banReason,
    accountId: link.account.id,
    accountFirstGame: link.account.firstGameId,
    accountGames: link.account.activatedGames,
  );
  await store.put('users', id, saved.toMap());
  return saved;
}

Map<String, dynamic> bilgiUserPublicMap(Map<String, dynamic> map) {
  final out = Map<String, dynamic>.from(map);
  out.remove('passwordHash');
  return out;
}
