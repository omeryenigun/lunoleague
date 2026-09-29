import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/core/constants/admob.dart';

class AdService {
  RewardedAd? _cached;
  String? _cachedUnit;
  Future<RewardedAd?>? _loading;
  Future<void>? _sdk;

  /// Initializes the ads SDK and loads one rewarded ad for the current game.
  Future<void> prepare() async {
    if (kIsWeb) return;
    await _ensureSdk();
    await _preload();
  }

  Future<void> _ensureSdk() async {
    if (kIsWeb) return;
    try {
      _sdk ??= MobileAds.instance.initialize().then((_) {});
      await _sdk;
    } catch (_) {
      _sdk = null;
    }
  }

  Future<RewardedAd?> _preload() {
    final pending = _loading;
    if (pending != null) return pending;
    final unitId = _rewardedUnitId();
    if (_cached != null && _cachedUnit == unitId) return Future.value(_cached);
    final future = _load(unitId).then((ad) {
      if (ad != null && _cached == null && _rewardedUnitId() == unitId) {
        _cached = ad;
        _cachedUnit = unitId;
      } else {
        ad?.dispose();
      }
      return _cached;
    });
    _loading = future;
    future.whenComplete(() {
      if (identical(_loading, future)) _loading = null;
    });
    return future;
  }

  Future<RewardedAd?> _load(String unitId) async {
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
    return loaded.future;
  }

  Future<RewardedAd?> _takeAd() async {
    final unitId = _rewardedUnitId();
    if (_cached != null && _cachedUnit == unitId) {
      final ad = _cached;
      _cached = null;
      _cachedUnit = null;
      return ad;
    }
    await (_loading ?? _preload());
    if (_cached != null && _cachedUnit == unitId) {
      final ad = _cached;
      _cached = null;
      _cachedUnit = null;
      return ad;
    }
    return _load(unitId);
  }

  Future<bool> showRewarded(String userId, {String? customData}) async {
    if (kIsWeb || userId.isEmpty) return false;
    await _ensureSdk();
    final ad = await _takeAd();
    if (ad == null) return false;
    unawaited(_preload());
    await ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userId, customData: customData),
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

String _rewardedUnitId() {
  if (!kReleaseMode) return admobTestRewardedUnitId;
  if (defaultTargetPlatform == TargetPlatform.android && !androidUsesLeagueAds) {
    return androidRewardedUnitId ?? admobTestRewardedUnitId;
  }
  return admobRewardedUnitId;
}
