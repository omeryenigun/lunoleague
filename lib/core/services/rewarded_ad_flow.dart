import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/domain/game/game_server.dart';

/// Shows a rewarded ad, then reads the balance the server wrote after Google
/// confirms the view. Returns the coins added, or 0 when nothing was granted.
Future<int> collectRewardedAdCoins({
  required GameServer server,
  required String userId,
  required int balanceBefore,
}) async {
  final shown = await AdService().showRewarded(userId);
  if (!shown) return 0;
  try {
    return await server.watchRewardedAd();
  } on AppFailure {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(seconds: 1));
      final now = (await server.currentUser())?.coin ?? balanceBefore;
      if (now > balanceBefore) return now - balanceBefore;
    }
  }
  return 0;
}
