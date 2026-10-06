import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/api/bilgi_bank_query.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_question_api.dart';

void main() {
  test('bank search fold matches the admin alphabet', () {
    expect(bilgiBankFoldFrom.length, bilgiBankFoldTo.length);
    expect(bilgiBankFoldFrom.length, 38);
    expect(bilgiBankFold('İstanbul Işık'), 'istanbul isik');
    expect(bilgiBankLike(r'100%_a'), r'%100\%\_a%');
    expect(bilgiBankPageLimit(50), 50);
    expect(bilgiBankPageLimit(15), 20);
    expect(bilgiBankPageLimit(500, select: true), 200);
  });

  test('ready sql keeps each category on its own languages', () {
    final sql = bilgiBankReadySql({
      'genel': ['en', 'de'],
      'felsefe': ['en'],
    });
    expect(sql.contains("'genel'"), isTrue);
    expect(sql.contains("'felsefe'"), isTrue);
    expect(sql.contains("-> 'en'"), isTrue);
    expect(sql.contains("-> 'de'"), isTrue);
    expect(sql.contains('q.explanation'), isTrue);
    expect(sql.toLowerCase().contains('case'), isTrue);
    expect(sql.contains('pg_input_is_valid'), isTrue);
    expect(sql.contains('jsonb_array_elements_text'), isFalse);
    for (final call in ['jsonb_array_length', 'jsonb_array_elements']) {
      var from = 0;
      var seen = 0;
      while (true) {
        final at = sql.indexOf(call, from);
        if (at < 0) break;
        seen++;
        final before = sql.substring(0, at);
        final typeofAt = before.lastIndexOf('jsonb_typeof');
        expect(typeofAt, greaterThanOrEqualTo(0), reason: call);
        final thenAt = before.indexOf('then', typeofAt);
        expect(thenAt, greaterThanOrEqualTo(0), reason: call);
        expect(before.substring(typeofAt, thenAt), contains("= 'array'"));
        from = at + call.length;
      }
      expect(seen, greaterThan(0), reason: call);
    }
  });

  test('summary counts group category and subcategory', () {
    final summary = BilgiBankSummary.fromMap({
      'total': 3,
      'pendingReady': 1,
      'status': {'approved': 2, 'draft': 1},
      'category': [
        {'categoryId': 'genel', 'status': 'draft', 'count': 1},
        {'categoryId': 'genel', 'status': 'approved', 'count': 2},
      ],
      'difficultyApproved': {'zor': 2},
      'subs': [
        {'categoryId': 'genel', 'name': 'Günlük Bilgi', 'status': 'draft', 'count': 1},
      ],
      'tags': {'Günlük Bilgi': 1},
    });
    expect(summary.total, 3);
    expect(summary.pendingReady, 1);
    expect(summary.categoryTotal('genel'), 3);
    expect(summary.categoryApproved('genel'), 2);
    expect(summary.subStatusCount('genel', 'Günlük Bilgi', 'draft'), 1);
    expect(summary.subTotal('Günlük Bilgi'), 1);
    expect(summary.bankBadge, 2);
  });

  test('detail filter is empty when explanation or hint is blank', () {
    expect(bilgiBankDetailEmpty('neden', 'ipucu'), isFalse);
    expect(bilgiBankDetailVisible('filled', 'neden', 'ipucu'), isTrue);
    expect(bilgiBankDetailVisible('empty', 'neden', 'ipucu'), isFalse);

    expect(bilgiBankDetailEmpty('', 'ipucu'), isTrue);
    expect(bilgiBankDetailVisible('empty', '', 'ipucu'), isTrue);
    expect(bilgiBankDetailVisible('filled', '', 'ipucu'), isFalse);

    expect(bilgiBankDetailEmpty('neden', ''), isTrue);
    expect(bilgiBankDetailVisible('empty', 'neden', ''), isTrue);
    expect(bilgiBankDetailVisible('filled', 'neden', ''), isFalse);

    expect(bilgiBankDetailEmpty('', ''), isTrue);
    expect(bilgiBankDetailEmpty(null, null), isTrue);
    expect(bilgiBankDetailEmpty(null, 'ipucu'), isTrue);
    expect(bilgiBankDetailEmpty('neden', null), isTrue);

    expect(bilgiBankDetailEmpty('   ', 'ipucu'), isTrue);
    expect(bilgiBankDetailEmpty('neden', ' \n\t '), isTrue);
    expect(bilgiBankDetailEmpty('  ', '\t'), isTrue);
    expect(bilgiBankDetailVisible('empty', ' \n ', ' \t '), isTrue);
    expect(bilgiBankDetailVisible('filled', ' \n ', 'ipucu'), isFalse);

    expect(bilgiBankDetailVisible('', ' ', ''), isTrue);
    expect(bilgiBankDetailSql(''), '');
    expect(bilgiBankDetailSql('other'), '');

    final emptySql = bilgiBankDetailSql('empty');
    expect(emptySql, contains("coalesce(q.explanation, '')"));
    expect(emptySql, contains("coalesce(q.hint, '')"));
    expect(emptySql, contains(' or '));
    expect(emptySql.contains('translations'), isFalse);

    final filledSql = bilgiBankDetailSql('filled');
    expect(filledSql, contains('not'));
    expect(filledSql, contains("coalesce(q.explanation, '')"));
    expect(filledSql, contains("coalesce(q.hint, '')"));
    expect(filledSql.contains('translations'), isFalse);
  });

  test('published matrix keeps category, subcategory and difficulty', () {
    final matrix = bilgiPublishedMatrix([
      {'categoryId': 'felsefe', 'sub': 'Ahlak Felsefesi', 'difficulty': 'kolay', 'count': 58},
      {'categoryId': 'felsefe', 'sub': 'Ahlak Felsefesi', 'difficulty': 'efsane', 'count': 0},
      {'categoryId': '', 'sub': 'Etik', 'difficulty': 'zor', 'count': 4},
    ]);
    expect(matrix[(categoryId: 'felsefe', sub: 'Ahlak Felsefesi', difficulty: 'kolay')], 58);
    expect(matrix[(categoryId: 'felsefe', sub: 'Ahlak Felsefesi', difficulty: 'efsane')], 0);
    expect(matrix.containsKey((categoryId: '', sub: 'Etik', difficulty: 'zor')), isFalse);
  });
}
