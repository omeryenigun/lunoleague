import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/core/constants/admob.dart';

class AdService {
  RewardedAd? _cachedRewarded;
  RewardedInterstitialAd? _cachedInterstitial;
  String? _cachedUnit;
  Future<void>? _loading;
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

  bool get _interstitialFormat => androidUsesRewardedInterstitial;

  Future<void> _preload() {
    final pending = _loading;
    if (pending != null) return pending;
    final unitId = _rewardedUnitId();
    if (_hasCached(unitId)) return Future.value();

    final Future<void> future;
    if (_interstitialFormat) {
      future = _loadInterstitial(unitId).then((ad) {
        if (ad != null &&
            _cachedInterstitial == null &&
            _rewardedUnitId() == unitId) {
          _cachedInterstitial = ad;
          _cachedUnit = unitId;
        } else {
          ad?.dispose();
        }
      });
    } else {
      future = _loadRewarded(unitId).then((ad) {
        if (ad != null &&
            _cachedRewarded == null &&
            _rewardedUnitId() == unitId) {
          _cachedRewarded = ad;
          _cachedUnit = unitId;
        } else {
          ad?.dispose();
        }
      });
    }
    _loading = future;
    future.whenComplete(() {
      if (identical(_loading, future)) _loading = null;
    });
    return future;
  }

  bool _hasCached(String unitId) {
    if (_cachedUnit != unitId) return false;
    return _interstitialFormat
        ? _cachedInterstitial != null
        : _cachedRewarded != null;
  }

  Future<RewardedAd?> _loadRewarded(String unitId) async {
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

  Future<RewardedInterstitialAd?> _loadInterstitial(String unitId) async {
    final loaded = Completer<RewardedInterstitialAd?>();
    await RewardedInterstitialAd.load(
      adUnitId: unitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: loaded.complete,
        onAdFailedToLoad: (_) {
          if (!loaded.isCompleted) loaded.complete(null);
        },
      ),
    );
    return loaded.future;
  }

  Future<RewardedAd?> _takeRewarded() async {
    final unitId = _rewardedUnitId();
    if (_cachedRewarded != null && _cachedUnit == unitId) {
      final ad = _cachedRewarded;
      _cachedRewarded = null;
      _cachedUnit = null;
      return ad;
    }
    await (_loading ?? _preload());
    if (_cachedRewarded != null && _cachedUnit == unitId) {
      final ad = _cachedRewarded;
      _cachedRewarded = null;
      _cachedUnit = null;
      return ad;
    }
    return _loadRewarded(unitId);
  }

  Future<RewardedInterstitialAd?> _takeInterstitial() async {
    final unitId = _rewardedUnitId();
    if (_cachedInterstitial != null && _cachedUnit == unitId) {
      final ad = _cachedInterstitial;
      _cachedInterstitial = null;
      _cachedUnit = null;
      return ad;
    }
    await (_loading ?? _preload());
    if (_cachedInterstitial != null && _cachedUnit == unitId) {
      final ad = _cachedInterstitial;
      _cachedInterstitial = null;
      _cachedUnit = null;
      return ad;
    }
    return _loadInterstitial(unitId);
  }

  Future<bool> showRewarded(String userId, {String? customData}) async {
    if (kIsWeb || userId.isEmpty) return false;
    await _ensureSdk();
    if (_interstitialFormat) {
      return _showInterstitial(userId, customData: customData);
    }
    return _showRewardedVideo(userId, customData: customData);
  }

  Future<bool> _showRewardedVideo(String userId, {String? customData}) async {
    final ad = await _takeRewarded();
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

  Future<bool> _showInterstitial(String userId, {String? customData}) async {
    final ad = await _takeInterstitial();
    if (ad == null) return false;
    unawaited(_preload());
    await ad.setServerSideOptions(
      ServerSideVerificationOptions(userId: userId, customData: customData),
    );
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
  if (!kReleaseMode) {
    return androidUsesRewardedInterstitial
        ? admobTestRewardedInterstitialUnitId
        : admobTestRewardedUnitId;
  }
  if (defaultTargetPlatform == TargetPlatform.android && !androidUsesLeagueAds) {
    return androidRewardedUnitId ??
        (androidUsesRewardedInterstitial
            ? admobTestRewardedInterstitialUnitId
            : admobTestRewardedUnitId);
  }
  return admobRewardedUnitId;
}
