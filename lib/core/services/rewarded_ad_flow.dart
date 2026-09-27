import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/ad_service.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

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

const dailyNextAdData = 'daily_next';

/// Stores the next shared daily after a rewarded ad.
/// Returns true when this player may start that game.
Future<bool> confirmAndOpenNextDaily({
  required BuildContext context,
  required GameServer server,
  required String userId,
}) async {
  final l10n = sl<L10n>();
  if (kIsWeb) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('daily_new_web'))),
    );
    return false;
  }
  final opened = await openNextDailyWithAd(server: server, userId: userId);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.t('daily_new_failed'))),
    );
  }
  return opened;
}

/// Stores the next shared daily, then waits for this player's ad proof.
/// Coins stay unchanged. Returns true when that player may start the game.
Future<bool> openNextDailyWithAd({
  required GameServer server,
  required String userId,
}) async {
  final prepared = await server.prepareNextDaily();
  if (!prepared) return false;
  final shown = await AdService().showRewarded(userId, customData: dailyNextAdData);
  if (!shown) return false;
  for (var i = 0; i < 20; i++) {
    final home = await server.homeSnapshot();
    if (!home.dailyNeedsAd) return true;
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  return false;
}
