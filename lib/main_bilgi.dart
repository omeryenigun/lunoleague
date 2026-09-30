import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kelimelig/core/constants/admob.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_question_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_room_api.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_screen.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_server.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_user_api.dart';
import 'package:kelimelig/games/luno_bilgi/register_bilgi_server.dart';
import 'package:kelimelig/injection.dart';

Future<void> main() async {
  androidUsesLeagueAds = false;
  androidRewardedUnitId = admobBilgiRewardedUnitId;
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  await registerBilgiServer();
  sl<LunoBilgiServer>()
    ..remoteDraw = BilgiQuestionApi.draw
    ..remoteDaily = BilgiQuestionApi.daily
    ..remoteRooms = BilgiRoomApi.hooks()
    ..remoteUpsert = BilgiUserApi.upsert;
  runApp(const LunoBilgiApp());
  if (!kIsWeb) {
    try {
      await sl<AdService>().prepare();
    } catch (_) {}
  }
}

class LunoBilgiApp extends StatelessWidget {
  const LunoBilgiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Luno Bilgi',
      debugShowCheckedModeBanner: false,
      home: BilgiScreen(),
    );
  }
}
