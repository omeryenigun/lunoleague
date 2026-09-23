import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/l10n.dart';

String matchErrorText(L10n l10n, Object error) {
  if (error is AppFailure) {
    final key = switch (error.code) {
      'NO_OPPONENT' => 'err_no_opponent',
      'DUEL_MISSING' => 'err_duel_missing',
      'DUEL_STARTED' => 'err_duel_started',
      'DUEL_DONE' => 'err_duel_done',
      'DUEL_FULL' => 'err_duel_full',
      'DUEL_HOST' => 'err_duel_host',
      'DUEL_WAIT' => 'err_duel_wait',
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
