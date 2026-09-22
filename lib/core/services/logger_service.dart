import 'package:flutter/foundation.dart';

class LoggerService {
  void info(String message, [Object? data]) {
    debugPrint('[Luno League] $message ${data ?? ''}');
  }

  void error(String message, [Object? error]) {
    debugPrint('[Luno League][ERR] $message $error');
  }
}

class AnalyticsService {
  AnalyticsService(this._log);
  final LoggerService _log;

  void event(String name, [Map<String, Object?> params = const {}]) {
    _log.info('event:$name', params);
  }
}
