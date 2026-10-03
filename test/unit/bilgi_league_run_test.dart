import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/api/bilgi_league_run_http.dart';

void main() {
  const userId = 'user-1';
  const categoryId = 'tarih';

  Map<String, dynamic> body({
    required List<Map<String, dynamic>> questions,
    int index = 0,
    bool finished = false,
    bool fresh = false,
  }) {
    return {
      'questions': questions,
      'index': index,
      'score': index * 10,
      'finished': finished,
      'fresh': fresh,
    };
  }

  test('first save stores the drawn set', () {
    final decision = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'lig',
      body: body(questions: [_question('a')], fresh: true),
    );
    expect(decision.run?['questions'], [_question('a')]);
    expect(decision.closed, isFalse);
  });

  test('a later save keeps the original questions', () {
    final first = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'hizli',
      body: body(questions: [_question('a'), _question('b')], fresh: true, index: 1),
    );
    final next = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'hizli',
      existing: first.run,
      body: body(questions: [_question('other')], index: 1),
    );
    expect(next.run?['questions'], [_question('a'), _question('b')]);
    expect(next.run?['index'], 1);
  });

  test('an older index does not rewind the run', () {
    final first = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'lig',
      body: body(questions: [_question('a'), _question('b')], fresh: true, index: 1),
    );
    final late = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'lig',
      existing: first.run,
      body: body(questions: [_question('a'), _question('b')], index: 0),
    );
    expect(identical(late.run, first.run), isTrue);
  });

  test('finishing closes the run and a stale save cannot reopen it', () {
    final first = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'sakin',
      body: body(questions: [_question('a')], fresh: true),
    );
    final closed = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'sakin',
      existing: first.run,
      body: body(questions: [_question('a')], finished: true),
    );
    expect(closed.closed, isTrue);
    final stale = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'sakin',
      existing: {'userId': userId, 'categoryId': categoryId, 'modeId': 'sakin', 'closed': true},
      body: body(questions: [_question('a')], index: 0),
    );
    expect(stale.run, isNull);
    expect(stale.closed, isFalse);
  });

  test('a new start after close stores a new set', () {
    final decision = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'klasik',
      existing: {'closed': true},
      body: body(questions: [_question('next')], fresh: true),
    );
    expect(decision.run?['questions'], [_question('next')]);
    expect(decision.run?['modeId'], 'klasik');
  });

  test('a first save without the fresh flag still stores the set', () {
    final decision = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'lig',
      body: body(questions: [_question('a'), _question('b')]),
    );
    expect(decision.run?['questions'], [_question('a'), _question('b')]);
  });

  test('a fresh start replaces a short open set', () {
    final short = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'lig',
      body: body(questions: [_question('only')], fresh: true),
    );
    final drawn = [for (var i = 0; i < 20; i++) _question('q$i')];
    final next = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'lig',
      existing: short.run,
      body: body(questions: drawn, fresh: true),
    );
    expect(next.run?['questions'], drawn);
    expect(next.run?['index'], 0);
  });

  test('a later save keeps the original mode', () {
    final first = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'maraton',
      body: body(questions: [_question('a'), _question('b')], fresh: true),
    );
    final next = bilgiLeagueOpenWrite(
      userId: userId,
      categoryId: categoryId,
      modeId: 'sakin',
      existing: first.run,
      body: body(questions: [_question('a'), _question('b')], index: 1),
    );
    expect(next.run?['modeId'], 'maraton');
  });
}

Map<String, dynamic> _question(String id) => {
      'id': id,
      'text': id,
      'options': ['1', '2', '3', '4'],
      'correct': 0,
    };
