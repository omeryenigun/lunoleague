import 'dart:async';

/// Tracks a rewarded fullscreen ad until the user can leave it.
///
/// Luno League completed the watch inside `onUserEarnedReward`. That callback
/// runs when the video ends, before the close control. The app then continued
/// under the ad, and on Android 15 the navigation bar covered the close
/// button, so the fullscreen ad could not be dismissed. Earning a reward only
/// sets a flag. The watch finishes when the ad is dismissed, or when it fails
/// to show.
class RewardedFullscreenGate {
  final Completer<bool> _done = Completer<bool>();
  bool earned = false;
  bool showed = false;

  Future<bool> get done => _done.future;
  bool get isClosed => _done.isCompleted;

  void onUserEarnedReward() {
    earned = true;
  }

  void onShowed() {
    showed = true;
  }

  void onDismissed() {
    if (!_done.isCompleted) _done.complete(earned);
  }

  void onFailedToShow() {
    if (!_done.isCompleted) _done.complete(false);
  }
}
