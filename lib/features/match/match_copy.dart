import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/l10n.dart';

String matchErrorText(L10n l10n, Object error) {
  if (error is AppFailure) {
    final key = switch (error.code) {
      'NO_OPPONENT' => 'err_no_opponent',
      'ROOM_MISSING' => 'err_room_missing',
      'ROOM_STARTED' => 'err_room_started',
      'ROOM_DONE' => 'err_room_done',
      'ROOM_FULL' => 'err_room_full',
      'ROOM_HOST' => 'err_room_host',
      'ROOM_CODE' => 'err_room_code',
      'NO_MATCH' => 'err_no_match',
      'NOT_STARTED' => 'err_not_started',
      _ => null,
    };
    if (key != null) return l10n.t(key);
    return error.message;
  }
  return '$error';
}
