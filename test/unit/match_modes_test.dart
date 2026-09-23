import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/remote/session_kv.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/game/match_rank.dart';

void main() {
  test('solved ranks above a miss, then fewer guesses, then a shorter clock', () {
    MatchRow row({
      required String name,
      required bool solved,
      required int guesses,
      required int millis,
      bool finished = true,
    }) =>
        MatchRow(
          userId: name,
          name: name,
          finished: finished,
          solved: solved,
          guesses: guesses,
          millis: millis,
          left: false,
          rank: 0,
        );

    final ranked = rankMatch([
      row(name: 'slow', solved: true, guesses: 4, millis: 1000),
      row(name: 'miss', solved: false, guesses: 6, millis: 500),
      row(name: 'fast', solved: true, guesses: 4, millis: 400),
      row(name: 'few', solved: true, guesses: 3, millis: 9000),
      row(name: 'open', solved: false, guesses: 1, millis: 0, finished: false),
    ]);

    expect(ranked.map((r) => r.name).toList(), ['few', 'fast', 'slow', 'miss', 'open']);
    expect(ranked.map((r) => r.rank).toList(), [1, 2, 3, 4, 0]);
  });

  test('guests pair, share a word, and a miss ranks below a solve', () async {
    final root = MemoryKeyValueStore();
    final a = LocalGameServer(SessionKv(root));
    final b = LocalGameServer(SessionKv(root));
    await a.initialize();
    await a.signInAnonymously();
    await b.signInAnonymously();

    expect((await a.duelSeek()).status, 'searching');
    final ready = await b.duelSeek();
    expect(ready.status, 'ready');
    final sessionA = await a.openAssigned(GameType.duel);
    final sessionB = await b.openAssigned(GameType.duel);
    final secret = (await a.adminGetSession(sessionA.sessionId))!;
    expect((await b.adminGetSession(sessionB.sessionId))!.wordId, secret.wordId);

    final wrong = (await a.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .map((w) => w.word)
        .where((w) => !TurkishText.equals(w, secret.word))
        .take(6);
    for (final guess in wrong) {
      await a.submitGuess(sessionA.sessionId, guess);
    }
    await b.submitGuess(sessionB.sessionId, secret.word);

    final board = await a.duelPoll();
    expect(board.status, 'done');
    expect(board.rows.first.solved, isTrue);
    expect(board.rows.first.userId, (await b.currentUser())!.id);
    expect(board.rows.last.solved, isFalse);
    expect(await a.leagueStandings(), isEmpty);
  });

  test('fewer guesses beat a faster clock, and equal guesses use the clock', () async {
    var now = DateTime(2026, 9, 23, 15);
    final root = MemoryKeyValueStore();
    final a = LocalGameServer(SessionKv(root), clock: () => now);
    final b = LocalGameServer(SessionKv(root), clock: () => now);
    await a.initialize();
    await a.signInWithGoogle(googleId: 'ada', displayName: 'Ada');
    await b.signInWithGoogle(googleId: 'bora', displayName: 'Bora');

    await a.duelSeek();
    await b.duelSeek();
    final sessionA = await a.openAssigned(GameType.duel);
    final sessionB = await b.openAssigned(GameType.duel);
    final secret = (await a.adminGetSession(sessionA.sessionId))!.word;
    final wrong = (await a.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .map((w) => w.word)
        .firstWhere((w) => !TurkishText.equals(w, secret));

    await a.submitGuess(sessionA.sessionId, wrong);
    await a.submitGuess(sessionA.sessionId, secret);
    now = now.add(const Duration(seconds: 5));
    await b.submitGuess(sessionB.sessionId, secret);

    final byGuess = await a.matchSnapshot('duel');
    expect(byGuess.rows.first.name, 'Bora');
    expect(byGuess.rows.first.guesses, 1);
    expect(byGuess.rows[1].guesses, 2);

    final ada = (await a.leagueStandings()).firstWhere((e) => e.isCurrentUser);
    final bora = (await b.leagueStandings()).firstWhere((e) => e.isCurrentUser);
    expect(bora.points, 100);
    expect(ada.points, 90);

    final root2 = MemoryKeyValueStore();
    var later = DateTime(2026, 9, 23, 16);
    final c = LocalGameServer(SessionKv(root2), clock: () => later);
    final d = LocalGameServer(SessionKv(root2), clock: () => later);
    await c.initialize();
    await c.signInAnonymously();
    await d.signInAnonymously();
    await c.duelSeek();
    await d.duelSeek();
    final sessionC = await c.openAssigned(GameType.duel);
    final sessionD = await d.openAssigned(GameType.duel);
    final word = (await c.adminGetSession(sessionC.sessionId))!.word;
    await c.submitGuess(sessionC.sessionId, word);
    later = later.add(const Duration(seconds: 4));
    await d.submitGuess(sessionD.sessionId, word);
    final byTime = await c.matchSnapshot('duel');
    expect(byTime.rows.first.userId, (await c.currentUser())!.id);
    expect(byTime.rows.first.millis, lessThan(byTime.rows[1].millis));
  });

  test('english queue does not match a turkish player', () async {
    final root = MemoryKeyValueStore();
    final a = LocalGameServer(SessionKv(root));
    final b = LocalGameServer(SessionKv(root));
    await a.initialize();
    await a.signInAnonymously();
    await b.signInAnonymously();
    await a.setLocale('en');
    expect((await a.duelSeek()).status, 'searching');
    expect((await b.duelSeek()).status, 'searching');
    await b.setLocale('en');
    expect((await b.duelSeek()).status, 'ready');
    final session = await a.openAssigned(GameType.duel);
    expect((await a.adminGetSession(session.sessionId))!.word.length, 5);
  });

  test('queue expires when nobody joins', () async {
    var now = DateTime(2026, 9, 23, 18);
    final server = LocalGameServer(
      SessionKv(MemoryKeyValueStore()),
      clock: () => now,
    );
    await server.initialize();
    await server.signInAnonymously();
    await server.duelSeek();
    now = now.add(const Duration(seconds: 46));
    await expectLater(
      server.duelPoll(),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'NO_OPPONENT')),
    );
  });

  test('room code, shared word, countdown, full room, and no league points', () async {
    var now = DateTime(2026, 9, 23, 19);
    final root = MemoryKeyValueStore();
    LocalGameServer player(String name) => LocalGameServer(
          SessionKv(root),
          clock: () => now,
        );

    final host = player('host');
    await host.initialize();
    await host.signInWithGoogle(googleId: 'host', displayName: 'Host');
    final created = await host.roomCreate();
    expect(created.code, hasLength(6));
    expect(int.parse(created.code!), inInclusiveRange(100000, 999999));

    final second = player('second');
    await second.signInWithGoogle(googleId: 'second', displayName: 'Second');
    final beforeHost = (await host.leagueStandings()).firstWhere((e) => e.isCurrentUser);
    final beforeSecond =
        (await second.leagueStandings()).firstWhere((e) => e.isCurrentUser);

    final others = <LocalGameServer>[];
    for (var i = 0; i < 3; i++) {
      final guest = player('g$i');
      await guest.signInAnonymously();
      others.add(guest);
    }
    final joined = <String>{created.code!};
    for (final guest in [second, ...others]) {
      final snap = await guest.roomJoin(created.code!);
      joined.add(snap.code!);
    }
    expect(joined, {created.code});

    final started = await host.roomStart();
    expect(started.status, 'playing');
    final hostSession = await host.openAssigned(GameType.room);
    final wordId = (await host.adminGetSession(hostSession.sessionId))!.wordId;
    for (final guest in [second, ...others]) {
      final session = await guest.openAssigned(GameType.room);
      expect((await guest.adminGetSession(session.sessionId))!.wordId, wordId);
    }

    await expectLater(
      host.submitGuess(hostSession.sessionId, 'KALEM'),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'NOT_STARTED')),
    );
    now = now.add(const Duration(seconds: 4));
    final secret = (await host.adminGetSession(hostSession.sessionId))!.word;
    await host.submitGuess(hostSession.sessionId, secret);
    final secondSession = await second.openAssigned(GameType.room);
    final wrong = (await host.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .map((w) => w.word)
        .firstWhere((w) => !TurkishText.equals(w, secret));
    await second.submitGuess(secondSession.sessionId, wrong);
    await second.submitGuess(secondSession.sessionId, secret);
    for (final guest in others) {
      final session = await guest.openAssigned(GameType.room);
      await guest.submitGuess(session.sessionId, secret);
    }

    final result = await host.matchSnapshot('room');
    expect(result.rows.first.userId, (await host.currentUser())!.id);
    expect(result.rows.first.guesses, 1);
    expect(result.rows[1].guesses, lessThanOrEqualTo(2));
    expect(
      (await host.leagueStandings()).firstWhere((e) => e.isCurrentUser).points,
      beforeHost.points,
    );
    expect(
      (await second.leagueStandings()).firstWhere((e) => e.isCurrentUser).points,
      beforeSecond.points,
    );

    final again = await host.roomCreate();
    expect(again.code, isNot(created.code));
    final crowd = player('crowd');
    await crowd.signInAnonymously();
    await crowd.roomJoin(again.code!);
    final fillers = <LocalGameServer>[];
    for (var i = 0; i < 8; i++) {
      final extra = player('e$i');
      await extra.signInAnonymously();
      await extra.roomJoin(again.code!);
      fillers.add(extra);
    }
    final blocked = player('blocked');
    await blocked.signInAnonymously();
    await expectLater(
      blocked.roomJoin(again.code!),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'ROOM_FULL')),
    );

    await host.roomLeave();
    await expectLater(
      blocked.roomJoin(again.code!),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'ROOM_DONE')),
    );
  });
}
