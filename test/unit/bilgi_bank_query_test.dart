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
}
