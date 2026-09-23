import 'package:kelimelig/games/luno_fall/fall_rules.dart';

const fallAlphabetTr = 'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ';
const fallAlphabetEn = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';

const fallWords = <String, List<FallWord>>{
  'tr': [
    FallWord(word: 'KALEM', clue: 'Yazı yazmak için kullanılan araç', category: 'Nesne'),
    FallWord(word: 'KİTAP', clue: 'Sayfalardan oluşan okuma aracı', category: 'Nesne'),
    FallWord(word: 'DENİZ', clue: 'Tuzlu su kütlesi', category: 'Doğa'),
    FallWord(word: 'GÜNEŞ', clue: 'Gökyüzündeki ışık kaynağı', category: 'Doğa'),
    FallWord(word: 'ÇİÇEK', clue: 'Bitkilerin renkli kısmı', category: 'Doğa'),
    FallWord(word: 'BULUT', clue: 'Gökyüzünde süzülen beyaz kütle', category: 'Doğa'),
    FallWord(word: 'ORMAN', clue: 'Ağaçlarla kaplı geniş alan', category: 'Doğa'),
    FallWord(word: 'MASA', clue: 'Üzerinde çalışılan mobilya', category: 'Nesne'),
    FallWord(word: 'KAPI', clue: 'Odaya giriş açıklığı', category: 'Nesne'),
    FallWord(word: 'GECE', clue: 'Güneş battıktan sonraki zaman', category: 'Zaman'),
    FallWord(word: 'YILDIZ', clue: 'Gece parlayan gök cismi', category: 'Doğa'),
    FallWord(word: 'BAHÇE', clue: 'Ev etrafındaki yeşil alan', category: 'Mekan'),
    FallWord(word: 'RÜZGAR', clue: 'Hareket eden hava', category: 'Doğa'),
    FallWord(word: 'NEHİR', clue: 'Akıp giden tatlı su', category: 'Doğa'),
    FallWord(word: 'KÖPRÜ', clue: 'İki yakayı birleştiren yapı', category: 'Mekan'),
    FallWord(word: 'SANDIK', clue: 'Eşya konulan kapaklı kutu', category: 'Nesne'),
    FallWord(word: 'KELEBEK', clue: 'Renkli kanatlı uçan böcek', category: 'Doğa'),
    FallWord(word: 'KARANFİL', clue: 'Kırmızı renkli kokulu çiçek', category: 'Doğa'),
    FallWord(word: 'ŞEMSİYE', clue: 'Yağmurdan korunma aracı', category: 'Nesne'),
    FallWord(word: 'MERHABA', clue: 'Karşılaşınca söylenen selam', category: 'Kültür'),
    FallWord(word: 'BAHARAT', clue: 'Yemeklere tat veren madde', category: 'Mutfak'),
    FallWord(word: 'TELESKOP', clue: 'Uzak gök cisimlerini büyüten alet', category: 'Bilim'),
    FallWord(word: 'KÜTÜPHANE', clue: 'Kitapların saklandığı yer', category: 'Mekan'),
    FallWord(word: 'GÖKKUŞAĞI', clue: 'Yağmur sonrası oluşan renkli yay', category: 'Doğa'),
    FallWord(word: 'BİLGİSAYAR', clue: 'Hesap ve yazı için elektronik alet', category: 'Nesne'),
  ],
  'en': [
    FallWord(word: 'BOOK', clue: 'Pages you read', category: 'Object'),
    FallWord(word: 'STAR', clue: 'A light in the night sky', category: 'Nature'),
    FallWord(word: 'TREE', clue: 'A tall plant with a trunk', category: 'Nature'),
    FallWord(word: 'MOON', clue: 'Earth’s night companion', category: 'Nature'),
    FallWord(word: 'FISH', clue: 'An animal that lives in water', category: 'Nature'),
    FallWord(word: 'RAIN', clue: 'Water falling from clouds', category: 'Nature'),
    FallWord(word: 'BIRD', clue: 'An animal with feathers', category: 'Nature'),
    FallWord(word: 'LAMP', clue: 'A light you switch on', category: 'Object'),
    FallWord(word: 'DESK', clue: 'A table for work', category: 'Object'),
    FallWord(word: 'RIVER', clue: 'Flowing fresh water', category: 'Nature'),
    FallWord(word: 'GARDEN', clue: 'A planted space by a house', category: 'Place'),
    FallWord(word: 'BRIDGE', clue: 'A path across water', category: 'Place'),
    FallWord(word: 'WINDOW', clue: 'A glass opening in a wall', category: 'Object'),
    FallWord(word: 'PENCIL', clue: 'A tool for writing', category: 'Object'),
    FallWord(word: 'RAINBOW', clue: 'Colored arc after rain', category: 'Nature'),
    FallWord(word: 'LIBRARY', clue: 'A place that keeps books', category: 'Place'),
    FallWord(word: 'UMBRELLA', clue: 'Shelter from the rain', category: 'Object'),
    FallWord(word: 'MOUNTAIN', clue: 'A very high hill', category: 'Nature'),
    FallWord(word: 'TELESCOPE', clue: 'A tool that brings the sky closer', category: 'Science'),
    FallWord(word: 'BUTTERFLY', clue: 'An insect with colored wings', category: 'Nature'),
    FallWord(word: 'WATERFALL', clue: 'A river dropping over a cliff', category: 'Nature'),
    FallWord(word: 'DICTIONARY', clue: 'A book of word meanings', category: 'Object'),
  ],
};

List<FallWord> wordsFor(String locale, FallDifficulty difficulty) {
  final rule = FallRules.difficulty[difficulty]!;
  final pool = fallWords[locale] ?? fallWords['tr']!;
  final matched = pool
      .where((word) =>
          word.word.length >= rule.minLetters &&
          word.word.length <= rule.maxLetters)
      .toList();
  return matched.isEmpty ? pool : matched;
}
