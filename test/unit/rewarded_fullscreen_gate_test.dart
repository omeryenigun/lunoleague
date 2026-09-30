import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/services/rewarded_fullscreen_gate.dart';

void main() {
  test('earning a reward does not close the ad', () {
    final gate = RewardedFullscreenGate();
    gate.onShowed();
    gate.onUserEarnedReward();
    expect(gate.earned, isTrue);
    expect(gate.isClosed, isFalse);
  });

  test('dismiss after a completed watch reports the reward', () async {
    final gate = RewardedFullscreenGate();
    gate.onShowed();
    gate.onUserEarnedReward();
    gate.onDismissed();
    expect(await gate.done, isTrue);
  });

  test('dismiss before the reward is earned does not grant it', () async {
    final gate = RewardedFullscreenGate();
    gate.onShowed();
    gate.onDismissed();
    expect(await gate.done, isFalse);
  });

  test('a failed show does not grant a reward', () async {
    final gate = RewardedFullscreenGate();
    gate.onUserEarnedReward();
    gate.onFailedToShow();
    expect(await gate.done, isFalse);
  });
}
