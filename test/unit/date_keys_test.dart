import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/date_keys.dart';

void main() {
  test('month season year keys', () {
    final d = DateTime(2026, 9, 22);
    expect(DateKeys.monthId(d), '2026-09');
    expect(DateKeys.seasonId(d), '2026-S3');
    expect(DateKeys.yearId(d), '2026');
    expect(DateKeys.seasonId(DateTime(2026, 1, 1)), '2026-S1');
    expect(DateKeys.seasonId(DateTime(2026, 12, 1)), '2026-S4');
  });
}
