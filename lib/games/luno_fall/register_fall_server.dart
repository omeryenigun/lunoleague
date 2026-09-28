import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/games/luno_fall/luno_fall_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> registerFallServer() async {
  if (sl.isRegistered<LunoFallServer>()) return;
  final fall = LunoFallServer(ScopedKeyValueStore(sl<KeyValueStore>(), GameIds.lunoFall));
  await fall.initialize();
  sl.registerSingleton<LunoFallServer>(fall);
}
