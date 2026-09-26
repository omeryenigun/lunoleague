import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/core/constants/admob.dart';

class AdService {
  Future<bool> showRewarded(String userId) async {
    if (kIsWeb || userId.isEmpty) return false;
    final unitId = kReleaseMode ? admobRewardedUnitId : admobTestRewardedUnitId;
    final loaded = Completer<RewardedAd?>();
    await RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) {
          if (!loaded.isCompleted) loaded.complete(null);
        },
      ),
    );
    final ad = await loaded.future;
    if (ad == null) return false;
    await ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userId),
    );
    // Android 15 draws full-screen ads under the navigation bar, which
    // covers the close button. Immersive mode hides that bar for the ad.
    await ad.setImmersiveMode(true);
    var rewarded = false;
    final closed = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    await ad.show(
      onUserEarnedReward: (_, _) {
        rewarded = true;
      },
    );
    return closed.future;
  }
}
