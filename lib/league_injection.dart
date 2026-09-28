import 'package:kelimelig/core/config/api_config.dart';
import 'package:kelimelig/data/local/hive_store.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/data/remote/league_remote_sync.dart';
import 'package:kelimelig/data/remote/remote_game_server.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> registerLeagueServer({
  KeyValueStore? store,
  bool initHive = true,
  bool syncRemote = false,
}) async {
  if (sl.isRegistered<GameServer>()) return;

  final root = sl<KeyValueStore>();
  if (root is HiveKeyValueStore) {
    await root.adoptLegacyBoxes(GameIds.lunoLeague);
  }

  final remote = store == null && initHive;
  final GameServer server;
  if (remote) {
    await restorePlayerToken(sl<ApiSession>());
    server = RemoteGameServer(ApiConfig.baseUrl, sl<ApiSession>());
  } else {
    final kv = ScopedKeyValueStore(root, GameIds.lunoLeague);
    final local = LocalGameServer(kv);
    await local.initialize();
    if (syncRemote) {
      await syncLunoLeagueContent(kv);
    }
    server = local;
  }

  sl.registerSingleton<GameServer>(server);
}
