import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/games/luno_grid/luno_grid_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> registerGridServer() async {
  if (sl.isRegistered<LunoGridServer>()) return;
  sl.registerSingleton<LunoGridServer>(
    LunoGridServer(
      ScopedKeyValueStore(sl<KeyValueStore>(), GameIds.lunoGrid),
      words: gridDictionary,
    ),
  );
}
