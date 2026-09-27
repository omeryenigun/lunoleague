import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/services/device_link.dart';

void main() {
  test('wifi or mobile counts as a link', () {
    expect(linkIsUp([ConnectivityResult.wifi]), isTrue);
    expect(linkIsUp([ConnectivityResult.mobile]), isTrue);
    expect(
      linkIsUp([ConnectivityResult.vpn, ConnectivityResult.wifi]),
      isTrue,
    );
    expect(linkIsUp([ConnectivityResult.none]), isFalse);
    expect(linkIsUp([ConnectivityResult.bluetooth]), isFalse);
    expect(linkIsUp(const []), isFalse);
  });
}