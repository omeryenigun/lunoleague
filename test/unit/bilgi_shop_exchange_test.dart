import 'package:flutter_test/flutter_test.dart';
import 'package:kelimelig/games/luno_bilgi/bilgi_shop.dart';

void main() {
  test('joker exchange asks for the gold and the next stock', () {
    final copy = bilgiShopJokerExchange(name: 'Çift Puan', price: 75, stockAfter: 2, icon: '👥');
    expect(copy.confirm, '75 altın harcanacak.\nÇift Puan yüklenecek. Stok 2.');
    expect(copy.icon, '👥');
    expect(copy.amount, '75');
    expect(copy.caption, '75 altın → Çift Puan, stok 2');
  });

  test('life exchange asks for the gold and the filled lives', () {
    final copy = bilgiShopLifeExchange(price: 100, livesAfter: 5);
    expect(copy.confirm, '100 altın harcanacak.\nCanın 5 olacak.');
    expect(copy.icon, '❤️');
    expect(copy.amount, '100');
    expect(copy.caption, '100 altın → Can doldu, 5');
  });
}
