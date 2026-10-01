import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_profile_name.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_sub_counts.dart';

void main() {
  test('published count under 60 is the low one', () {
    final under = bilgiSubCountLine(pending: 4, published: 59);
    expect(under.publishedLow, isTrue);
    expect(under.label, 'Beklemede 4 • Yayınlı 59');

    final zero = bilgiSubCountLine(pending: 0, published: 0);
    expect(zero.publishedLow, isTrue);

    final enough = bilgiSubCountLine(pending: 80, published: 60);
    expect(enough.publishedLow, isFalse);
    expect(enough.label, 'Beklemede 80 • Yayınlı 60');
  });

  test('profile heading keeps a real name and uses Avatar only as fallback', () {
    expect(bilgiProfileHeading(username: 'Ömer', displayName: 'Avatar'), 'Ömer');
    expect(bilgiProfileHeading(username: 'Avatar', displayName: 'Ömer'), 'Ömer');
    expect(bilgiProfileHeading(username: '', displayName: 'Luno'), 'Luno');
    expect(bilgiProfileHeading(username: 'Avatar', displayName: ''), 'Avatar');
    expect(bilgiProfileHeading(username: '  ', displayName: null), 'Avatar');
  });
}
