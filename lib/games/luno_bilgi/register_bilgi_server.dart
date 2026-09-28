import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/scoped_store.dart';
import 'package:kelimelig/domain/game/game_ids.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> registerBilgiServer({bool emptyQuestionBank = false}) async {
  if (sl.isRegistered<LunoBilgiServer>()) return;
  final bilgi = LunoBilgiServer(ScopedKeyValueStore(sl<KeyValueStore>(), GameIds.lunoBilgi));
  await bilgi.ensureSeed();
  if (emptyQuestionBank) {
    await bilgi.clearQuestionBankOnce();
  }
  sl.registerSingleton<LunoBilgiServer>(bilgi);
}
