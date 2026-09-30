import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/api/bilgi_count_snapshot.dart';

BilgiCountPart _part({
  String categoryId = 'felsefe',
  String difficulty = 'kolay',
  String status = 'approved',
  List<String> tags = const ['Antik'],
}) {
  return BilgiCountPart(
    categoryId: categoryId,
    difficulty: difficulty,
    status: status,
    tags: tags,
  );
}

void main() {
  test('pending questions do not change the stored counts', () {
    final snapshot = BilgiCountSnapshot();
    final pending = List<BilgiCountPart?>.generate(200, (_) => _part(status: 'pending'));
    expect(snapshot.replaceAll(List.filled(200, null), pending), isFalse);
    expect(snapshot.categories, isEmpty);
  });

  test('one approved batch writes category, subcategory and difficulty once', () {
    final snapshot = BilgiCountSnapshot();
    final added = [_part(), _part(difficulty: 'orta', tags: const ['Modern'])];
    expect(snapshot.replaceAll(const [null, null], added), isTrue);
    expect(snapshot.categories['felsefe'], 2);
    expect(snapshot.categories['tumu'], 2);
    expect(snapshot.subs['felsefe|Antik'], 1);
    expect(snapshot.subs['felsefe|Modern'], 1);
    expect(snapshot.slices['felsefe||kolay'], 1);
    expect(snapshot.slices['felsefe|Modern|orta'], 1);
    expect(snapshot.replaceAll(added, added), isFalse);
  });

  test('editing and deleting an approved question moves the stored count', () {
    final snapshot = BilgiCountSnapshot();
    final before = _part();
    snapshot.replaceAll(const [null], [before]);
    final moved = _part(categoryId: 'tarih', tags: const ['Osmanlı']);
    expect(snapshot.replaceAll([before], [moved]), isTrue);
    expect(snapshot.categories.containsKey('felsefe'), isFalse);
    expect(snapshot.categories['tarih'], 1);
    expect(snapshot.subs['tarih|Osmanlı'], 1);
    expect(snapshot.replaceAll([moved], const [null]), isTrue);
    expect(snapshot.categories, isEmpty);
    expect(snapshot.subs, isEmpty);
  });

  test('closed categories and subcategories stay out of the phone payload', () {
    final snapshot = BilgiCountSnapshot();
    snapshot.replaceAll(const [null, null], [
      _part(),
      _part(categoryId: 'tarih', tags: const ['Osmanlı'], difficulty: 'zor'),
    ]);
    final shown = snapshot.visible({'felsefe'}, {'felsefe|Antik'});
    expect(shown.categories['felsefe'], 1);
    expect(shown.categories['tumu'], 1);
    expect(shown.categories.containsKey('tarih'), isFalse);
    expect(shown.subs.keys, ['felsefe|Antik']);
    expect(shown.slices['felsefe||kolay'], 1);
    expect(shown.slices['tumu||kolay'], 1);
    expect(shown.slices.containsKey('tarih||zor'), isFalse);
  });

  test('renaming a subcategory moves its count key', () {
    final snapshot = BilgiCountSnapshot();
    snapshot.replaceAll(const [null], [_part(tags: const ['Antik'])]);
    expect(snapshot.moveSub('felsefe', 'Antik', 'Antik Yunan'), isTrue);
    expect(snapshot.subs.containsKey('felsefe|Antik'), isFalse);
    expect(snapshot.subs['felsefe|Antik Yunan'], 1);
    expect(snapshot.slices['felsefe|Antik Yunan|kolay'], 1);
    expect(snapshot.moveSub('felsefe', 'Antik', 'Antik Yunan'), isFalse);
  });
}
