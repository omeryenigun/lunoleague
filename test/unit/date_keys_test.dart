import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/core/utils/date_keys.dart';

void main() {
  test('player clock stamp is the real start instant', () {
    const offset = Duration(hours: 3);
    final real = DateTime.utc(2026, 9, 23, 18, 4, 5);
    final stamped = real.add(offset);
    expect(DateKeys.playerInstant(stamped, offset: offset), real);
    expect(DateKeys.playerInstant(real, offset: Duration.zero), real);
  });

  test('month season year keys', () {
    final d = DateTime(2026, 9, 22);
    expect(DateKeys.monthId(d), '2026-09');
    expect(DateKeys.seasonId(d), '2026-S3');
    expect(DateKeys.yearId(d), '2026');
    expect(DateKeys.seasonId(DateTime(2026, 1, 1)), '2026-S1');
    expect(DateKeys.seasonId(DateTime(2026, 12, 1)), '2026-S4');
  });
}
