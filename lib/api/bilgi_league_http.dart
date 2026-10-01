import 'dart:async';

import 'package:kelimelig/api/admin_http.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_league.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_wallet.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

const bilgiLeagueSettlementMeta = 'bilgi_league_settlement';

void mountBilgiLeague(Router router, KeyValueStore store) {
  router.get('/v1/bilgi/league', (request) => _league(request, store));
}

Future<void> settleBilgiLeague(KeyValueStore store, {DateTime? now, BilgiLedgerRepo? ledger}) async {
  final clock = now ?? DateTime.now().toUtc();
  final last = await store.getMeta(bilgiLeagueSettlementMeta);
  final weeks = bilgiWeeksToSettle(last, clock);
  if (weeks.isEmpty) return;
  var users = [for (final row in await store.values('users')) BilgiProfile.fromMap(row)];
  for (final week in weeks) {
    final before = {for (final user in users) user.id: user};
    users = applyBilgiSettlement(users, week: week, now: clock);
    await store.putMeta(bilgiLeagueSettlementMeta, week);
    if (ledger != null) {
      final lines = <BilgiLedgerLine>[];
      for (final user in users) {
        final prev = before[user.id];
        if (prev == null) continue;
        await bilgiEnsureOpening(ledger, prev, at: clock);
        lines.addAll(bilgiLedgerDiff(
          before: prev,
          after: user,
          reason: 'league_monday',
          ref: week,
          detail: {'week': week, 'text': user.leagueRewardText},
          at: clock,
        ));
      }
      await ledger.append(lines);
    }
  }
  for (final user in users) {
    await store.put('users', user.id, user.toMap());
  }
}

void watchBilgiLeague(KeyValueStore store, {BilgiLedgerRepo? ledger}) {
  unawaited(settleBilgiLeague(store, ledger: ledger));
  Timer.periodic(const Duration(hours: 1), (_) {
    unawaited(settleBilgiLeague(store, ledger: ledger));
  });
}

Future<Response> _league(Request request, KeyValueStore store) async {
  final scope = request.url.queryParameters['scope'] ?? 'global';
  final categoryId = request.url.queryParameters['categoryId'];
  final weekly = request.url.queryParameters['weekly'] == '1';
  final meId = request.url.queryParameters['me'] ?? '';
  final rows = await store.values('users');
  final users = [for (final row in rows) BilgiProfile.fromMap(row)];
  BilgiProfile? me;
  if (meId.isNotEmpty) {
    for (final user in users) {
      if (user.id == meId) me = user;
    }
  }
  final settled = await store.getMeta(bilgiLeagueSettlementMeta) ?? '';
  final snap = bilgiLeagueSnapshot(
    users: users,
    me: me,
    scope: scope,
    categoryId: categoryId,
    categoryWeekly: weekly,
    now: DateTime.now().toUtc(),
    settledWeek: settled,
  );
  return jsonResponse(snap.toMap());
}
