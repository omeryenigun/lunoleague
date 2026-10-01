import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/data/remote/session_kv.dart';
import 'package:kelimelig/domain/game/game_ids.dart';

/// Shared account lives on the unscoped store, outside any game box.
const lunoAccountsBox = 'luno_accounts';

/// Walks session and game scopes back to the store that holds [lunoAccountsBox].
KeyValueStore lunoAccountRoot(KeyValueStore store) {
  if (store is SessionKv) return lunoAccountRoot(store.inner);
  if (store is ScopedKeyValueStore) return store.root;
  return store;
}

String lunoAccountGameId(KeyValueStore store) {
  if (store is SessionKv) return lunoAccountGameId(store.inner);
  if (store is ScopedKeyValueStore) return store.gameId;
  return GameIds.lunoLeague;
}

String lunoGameLabel(String gameId) {
  return switch (gameId) {
    GameIds.lunoLeague => 'Luno League',
    GameIds.lunoBilgi => 'Luno Bilgi',
    GameIds.lunoGrid => 'Luno Grid',
    GameIds.lunoFall => 'Luno Fall',
    _ => gameId,
  };
}

class LunoAccount {
  const LunoAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.googleId,
    required this.provider,
    required this.firstGameId,
    required this.activatedGames,
    required this.progressIds,
    required this.createdAt,
  });

  final String id;
  final String displayName;
  final String email;
  final String googleId;
  final String provider;
  final String firstGameId;
  final List<String> activatedGames;
  final Map<String, String> progressIds;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'googleId': googleId,
        'provider': provider,
        'firstGameId': firstGameId,
        'activatedGames': activatedGames,
        'progressIds': progressIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory LunoAccount.fromMap(Map<String, dynamic> map) {
    final games = <String>[
      for (final item in map['activatedGames'] as List? ?? const [])
        if ('$item'.isNotEmpty) '$item',
    ];
    final progress = <String, String>{};
    final raw = map['progressIds'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final id = '${entry.value}'.trim();
        if (id.isEmpty) continue;
        progress['${entry.key}'] = id;
      }
    }
    return LunoAccount(
      id: '${map['id'] ?? ''}',
      displayName: '${map['displayName'] ?? ''}',
      email: '${map['email'] ?? ''}'.trim().toLowerCase(),
      googleId: '${map['googleId'] ?? ''}'.trim(),
      provider: '${map['provider'] ?? 'email'}',
      firstGameId: '${map['firstGameId'] ?? ''}',
      activatedGames: games,
      progressIds: progress,
      createdAt: DateTime.tryParse('${map['createdAt'] ?? ''}') ?? DateTime.now(),
    );
  }
}

class LunoAccountLink {
  const LunoAccountLink(this.account, {this.otherProgressId});

  final LunoAccount account;

  /// This game already has a different progress row. Open that row.
  final String? otherProgressId;
}

class LunoAccountDirectory {
  LunoAccountDirectory(this._store);

  final KeyValueStore _store;

  Future<List<LunoAccount>> all() async {
    final rows = await _store.values(lunoAccountsBox);
    return [for (final row in rows) LunoAccount.fromMap(row)];
  }

  Future<LunoAccount?> find({String? email, String? googleId}) async {
    final mail = email?.trim().toLowerCase() ?? '';
    final google = googleId?.trim() ?? '';
    if (mail.isEmpty && google.isEmpty) return null;
    for (final account in await all()) {
      if (google.isNotEmpty && account.googleId == google) return account;
    }
    if (mail.isEmpty) return null;
    for (final account in await all()) {
      if (account.email == mail) return account;
    }
    return null;
  }

  /// Creates the account, or attaches [progressId] when this game has none yet.
  /// A different existing progress id is returned and left unchanged.
  Future<LunoAccountLink> link({
    required String gameId,
    required String progressId,
    required String displayName,
    required String provider,
    String? email,
    String? googleId,
  }) async {
    final mail = email?.trim().toLowerCase() ?? '';
    final google = googleId?.trim() ?? '';
    final found = await find(email: mail, googleId: google);
    if (found == null) {
      final created = LunoAccount(
        id: 'a${DateTime.now().microsecondsSinceEpoch}',
        displayName: displayName.trim().isEmpty ? 'Oyuncu' : displayName.trim(),
        email: mail,
        googleId: google,
        provider: provider,
        firstGameId: gameId,
        activatedGames: [gameId],
        progressIds: {gameId: progressId},
        createdAt: DateTime.now(),
      );
      await _store.put(lunoAccountsBox, created.id, created.toMap());
      return LunoAccountLink(created);
    }
    final existing = found.progressIds[gameId];
    if (existing != null && existing.isNotEmpty && existing != progressId) {
      return LunoAccountLink(found, otherProgressId: existing);
    }
    final games = [
      ...found.activatedGames.where((id) => id != gameId),
      gameId,
    ];
    final progress = Map<String, String>.from(found.progressIds);
    progress[gameId] = progressId;
    final next = LunoAccount(
      id: found.id,
      displayName: found.displayName.trim().isEmpty ? displayName.trim() : found.displayName,
      email: found.email.isNotEmpty ? found.email : mail,
      googleId: found.googleId.isNotEmpty ? found.googleId : google,
      provider: found.provider.isNotEmpty ? found.provider : provider,
      firstGameId: found.firstGameId.isNotEmpty ? found.firstGameId : gameId,
      activatedGames: games,
      progressIds: progress,
      createdAt: found.createdAt,
    );
    await _store.put(lunoAccountsBox, next.id, next.toMap());
    return LunoAccountLink(next);
  }
}
