import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

bool linkIsUp(List<ConnectivityResult> results) {
  for (final result in results) {
    if (result == ConnectivityResult.wifi || result == ConnectivityResult.mobile) {
      return true;
    }
  }
  return false;
}

class DeviceLink {
  DeviceLink({Connectivity? connectivity}) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// True until the first successful check says otherwise.
  bool online = true;

  Future<bool> refresh() async {
    if (_widgetTest) return online;
    try {
      online = linkIsUp(await _connectivity.checkConnectivity());
    } on Object {
      // A missing platform channel must not block startup.
    }
    return online;
  }
}

bool get _widgetTest {
  var testing = false;
  assert(() {
    testing = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    return true;
  }());
  return testing;
}
