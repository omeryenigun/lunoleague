import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kelimelig/core/constants/admob.dart';
import 'package:kelimelig/core/services/rewarded_fullscreen_gate.dart';

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
    try {
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
      return await loaded.future;
    } catch (_) {
      return null;
    }
  }

  Future<RewardedInterstitialAd?> _loadInterstitial(String unitId) async {
    try {
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
      return await loaded.future;
    } catch (_) {
      return null;
    }
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
    try {
      await _ensureSdk();
      if (_interstitialFormat) {
        return await _showInterstitial(userId, customData: customData);
      }
      return await _showRewardedVideo(userId, customData: customData);
    } catch (_) {
      return false;
    }
  }

  Future<bool> _showRewardedVideo(String userId, {String? customData}) async {
    final ad = await _takeRewarded();
    if (ad == null) return false;
    unawaited(_preload());
    try {
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(userId: userId, customData: customData),
      );
      // Android 15 draws full-screen ads under the navigation bar, which
      // covers the close button. Immersive mode hides that bar for the ad.
      await ad.setImmersiveMode(true);
    } catch (_) {
      ad.dispose();
      return false;
    }
    return _showAndWait(
      listen: (gate, release) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (_) => gate.onShowed(),
          onAdDismissedFullScreenContent: (_) {
            // The reward callback can land just after dismiss. The ad is
            // already closed; wait briefly so a late reward still counts,
            // then let the activity finish before dispose.
            Future<void>.delayed(const Duration(milliseconds: 300), () {
              gate.onDismissed();
              release(delay: true);
            });
          },
          onAdFailedToShowFullScreenContent: (_, _) {
            release(delay: false);
            gate.onFailedToShow();
          },
        );
      },
      show: (gate) => ad.show(
        onUserEarnedReward: (_, _) => gate.onUserEarnedReward(),
      ),
      dispose: ad.dispose,
    );
  }

  Future<bool> _showInterstitial(String userId, {String? customData}) async {
    final ad = await _takeInterstitial();
    if (ad == null) return false;
    unawaited(_preload());
    try {
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(userId: userId, customData: customData),
      );
      await ad.setImmersiveMode(true);
    } catch (_) {
      ad.dispose();
      return false;
    }
    return _showAndWait(
      listen: (gate, release) {
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (_) => gate.onShowed(),
          onAdDismissedFullScreenContent: (_) {
            // The reward callback can land just after dismiss. The ad is
            // already closed; wait briefly so a late reward still counts,
            // then let the activity finish before dispose.
            Future<void>.delayed(const Duration(milliseconds: 300), () {
              gate.onDismissed();
              release(delay: true);
            });
          },
          onAdFailedToShowFullScreenContent: (_, _) {
            release(delay: false);
            gate.onFailedToShow();
          },
        );
      },
      show: (gate) => ad.show(
        onUserEarnedReward: (_, _) => gate.onUserEarnedReward(),
      ),
      dispose: ad.dispose,
    );
  }

  /// Presents the ad and waits until it is dismissed.
  ///
  /// Dispose runs after dismiss so the ad activity can finish. Disposing
  /// inside the dismiss callback can leave a fullscreen overlay that has no
  /// close control.
  Future<bool> _showAndWait({
    required void Function(
      RewardedFullscreenGate gate,
      void Function({required bool delay}) release,
    ) listen,
    required Future<void> Function(RewardedFullscreenGate gate) show,
    required void Function() dispose,
  }) async {
    final gate = RewardedFullscreenGate();
    var released = false;
    void release({required bool delay}) {
      if (released) return;
      released = true;
      if (!delay) {
        dispose();
        return;
      }
      Future<void>.delayed(const Duration(milliseconds: 200), dispose);
    }

    listen(gate, release);
    try {
      await show(gate);
    } catch (_) {
      release(delay: false);
      gate.onFailedToShow();
      return false;
    }
    return gate.done;
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
