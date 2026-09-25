import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/utils/turkish_text.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/data/remote/session_kv.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/game/match_rank.dart';
import 'package:kelimelig/features/match/rival_notice.dart';

Future<void> inviteDuel(LocalGameServer host, LocalGameServer guest) async {
  final created = await host.duelCreate();
  expect(created.status, 'lobby');
  expect(created.code, hasLength(6));
  await guest.duelJoin(created.code!);
  final started = await host.duelStart();
  expect(started.status, 'playing');
}

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

  test('rank copy keeps the last guess colors', () {
    final ranked = rankMatch([
      const MatchRow(
        userId: 'a',
        name: 'Ada',
        finished: false,
        solved: false,
        guesses: 1,
        millis: 0,
        left: false,
        rank: 0,
        greens: 2,
        yellows: 1,
      ),
    ]);
    expect(ranked.single.greens, 2);
    expect(ranked.single.yellows, 1);
  });

  MatchRow seat(String id, {int guesses = 0, int greens = 0, int yellows = 0, bool finished = false, bool solved = false}) {
    return MatchRow(
      userId: id,
      name: id,
      finished: finished,
      solved: solved,
      guesses: guesses,
      millis: 0,
      left: false,
      rank: 0,
      greens: greens,
      yellows: yellows,
    );
  }

  test('rival notices skip yourself and the opening snapshot', () {
    final me = seat('me', guesses: 1, greens: 3);
    final rival = seat('Ada', guesses: 1, greens: 2, yellows: 1);
    expect(
      rivalNotices(previous: null, next: [me, rival], me: 'me'),
      isEmpty,
    );
    expect(
      rivalNotices(previous: [me, rival], next: [seat('me', guesses: 2, greens: 5), rival], me: 'me'),
      isEmpty,
    );
  });

  test('a new rival guess reports colors, and a finish stays word-free', () {
    final before = [
      seat('me'),
      seat('Ada'),
    ];
    final moved = rivalNotices(
      previous: before,
      next: [
        seat('me'),
        seat('Ada', guesses: 1, greens: 2, yellows: 1),
      ],
      me: 'me',
    );
    expect(moved, hasLength(1));
    expect(moved.single.kind, RivalNoticeKind.colors);
    expect(moved.single.greens, 2);
    expect(moved.single.yellows, 1);

    final done = rivalNotices(
      previous: [seat('me'), seat('Ada', guesses: 1, greens: 2, yellows: 1)],
      next: [
        seat('me'),
        seat('Ada', guesses: 2, greens: 5, yellows: 0, finished: true, solved: true),
      ],
      me: 'me',
    );
    expect(done.map((n) => n.kind), [RivalNoticeKind.colors, RivalNoticeKind.finished]);
    expect(done.last.solved, isTrue);
    expect(done.last.name, 'Ada');
  });

  test('guests pair, share a word, and a miss ranks below a solve', () async {
    var now = DateTime(2026, 9, 23, 12);
    final root = MemoryKeyValueStore();
    final a = LocalGameServer(SessionKv(root), clock: () => now);
    final b = LocalGameServer(SessionKv(root), clock: () => now);
    await a.initialize();
    await a.signInAnonymously();
    await b.signInAnonymously();

    await inviteDuel(a, b);
    now = now.add(const Duration(seconds: 4));
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

    await inviteDuel(a, b);
    now = now.add(const Duration(seconds: 4));
    final sessionA = await a.openAssigned(GameType.duel);
    final sessionB = await b.openAssigned(GameType.duel);
    final secret = (await a.adminGetSession(sessionA.sessionId))!.word;
    final wrong = (await a.adminListWords())
        .where((w) => w.length == 5 && w.playable && w.language == 'tr')
        .map((w) => w.word)
        .firstWhere((w) => !TurkishText.equals(w, secret));

    final played = await a.submitGuess(sessionA.sessionId, wrong);
    final afterOne = await b.matchSnapshot('duel');
    final adaRow = afterOne.rows.firstWhere((row) => row.name == 'Ada');
    final last = played.guesses.last.statuses;
    expect(adaRow.guesses, 1);
    expect(adaRow.greens, last.where((s) => s == LetterStatus.correct).length);
    expect(adaRow.yellows, last.where((s) => s == LetterStatus.present).length);
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
    await inviteDuel(c, d);
    later = later.add(const Duration(seconds: 4));
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

  test('a duel code invites one friend and does not match strangers', () async {
    var now = DateTime(2026, 9, 23, 17);
    final root = MemoryKeyValueStore();
    final a = LocalGameServer(SessionKv(root), clock: () => now);
    final b = LocalGameServer(SessionKv(root), clock: () => now);
    final c = LocalGameServer(SessionKv(root), clock: () => now);
    await a.initialize();
    await a.signInAnonymously();
    await b.signInAnonymously();
    await c.signInAnonymously();
    await a.setLocale('en');

    final mine = await a.duelCreate();
    final theirs = await b.duelCreate();
    expect(mine.code, isNot(theirs.code));
    expect(mine.status, 'lobby');
    expect(theirs.status, 'lobby');

    await expectLater(
      c.duelJoin('000000'),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'DUEL_MISSING')),
    );
    await expectLater(
      a.duelStart(),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'DUEL_WAIT')),
    );

    await b.duelJoin(mine.code!);
    await expectLater(
      c.duelJoin(mine.code!),
      throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'DUEL_FULL')),
    );
    final started = await a.duelStart();
    expect(started.status, 'playing');
    now = now.add(const Duration(seconds: 4));
    final session = await a.openAssigned(GameType.duel);
    expect((await a.adminGetSession(session.sessionId))!.word.length, 5);
    expect(
      (await b.adminGetSession((await b.openAssigned(GameType.duel)).sessionId))!
          .wordId,
      (await a.adminGetSession(session.sessionId))!.wordId,
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

  test('guests get a unique numbered name', () async {
    final root = MemoryKeyValueStore();
    final a = LocalGameServer(SessionKv(root), random: _FixedRandom(42));
    final b = LocalGameServer(SessionKv(root), random: _FixedRandom(99));
    await a.initialize();
    final first = await a.signInAnonymously();
    final second = await b.signInAnonymously();
    expect(first.displayName, matches(RegExp(r'^Misafir\d{4}$')));
    expect(second.displayName, matches(RegExp(r'^Misafir\d{4}$')));
    expect(first.displayName, isNot(second.displayName));
  });

  test('a player who leaves is timed out after five minutes', () async {
    var now = DateTime(2026, 9, 23, 18);
    final root = MemoryKeyValueStore();
    final a = LocalGameServer(SessionKv(root), clock: () => now);
    final b = LocalGameServer(SessionKv(root), clock: () => now);
    await a.initialize();
    await a.signInAnonymously();
    await b.signInAnonymously();
    await inviteDuel(a, b);
    final me = (await a.currentUser())!.id;

    now = now.add(const Duration(minutes: 4));
    final early = await a.duelPoll();
    expect(early.rows.firstWhere((r) => r.userId != me).finished, isFalse);

    now = now.add(const Duration(minutes: 1));
    final late = await a.duelPoll();
    final other = late.rows.firstWhere((r) => r.userId != me);
    expect(other.finished, isTrue);
    expect(other.left, isTrue);
    expect(other.solved, isFalse);
    expect(late.status, 'playing');
  });
}

class _FixedRandom implements Random {
  _FixedRandom(this._value);

  final int _value;

  @override
  int nextInt(int max) => _value % max;

  @override
  bool nextBool() => false;

  @override
  double nextDouble() => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
