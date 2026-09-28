import 'package:kelimelig/games/luno_bilgi/bilgi_model.dart';

BilgiQuestion _t(
  String id,
  String categoryId,
  String difficulty,
  String text,
  List<String> options,
  int correct, {
  List<String> tags = const [],
}) {
  return BilgiQuestion(
    id: id,
    categoryId: categoryId,
    difficulty: difficulty,
    text: text,
    options: options,
    correct: correct,
    explanation: '',
    status: 'approved',
    tags: tags,
  );
}

const _felsefeSubs = <String, List<List<String>>>{
  'Antik Yunan Felsefesi': [
    ['Sokrates’in öğrencisi ve Akademi’nin kurucusu kimdir?', 'Aristoteles', 'Platon', 'Epikuros', 'Zenon', '1'],
    ['Aristoteles’in Atina’da kurduğu okulun adı nedir?', 'Akademi', 'Lykeion', 'Stoa', 'Agora', '1'],
    ['Sokrates’e verilen idam cezası hangi zehirle uygulanmıştır?', 'Baldıran', 'Arsenik', 'Siyanür', 'Afyon', '0'],
  ],
  'Modern Felsefe': [
    ['“Düşünüyorum, öyleyse varım” sözü kime aittir?', 'Kant', 'Hegel', 'Descartes', 'Locke', '2'],
    ['Immanuel Kant’ın en bilinen eseri hangisidir?', 'Saf Aklın Eleştirisi', 'Kapital', 'Devlet', 'Varlık ve Hiçlik', '0'],
    ['“Böyle Buyurdu Zerdüşt” kimin eseridir?', 'Marx', 'Nietzsche', 'Hume', 'Spinoza', '1'],
  ],
  'Çağdaş Felsefe': [
    ['Varoluşçuluğun önde gelen adlarından biri kimdir?', 'Sartre', 'Platon', 'Aquinas', 'Farabi', '0'],
    ['Albert Camus’nün absürt üzerine denemesi hangisidir?', 'Devlet', 'Sisifos Söyleni', 'Etik', 'Meditasyonlar', '1'],
    ['“Varlık ve Zaman” hangi düşünüre aittir?', 'Heidegger', 'Camus', 'Bacon', 'Descartes', '0'],
  ],
  'Doğu Felsefesi': [
    ['Tao Te Ching hangi geleneğe aittir?', 'Taoizm', 'Stoacılık', 'Skolastik', 'Pozitivizm', '0'],
    ['Konfüçyüs’ün öğretisi en çok neyi vurgular?', 'Erdem ve toplumsal düzen', 'Atomculuk', 'Şüphecilik', 'Hazcılık', '0'],
    ['Lao Tzu hangi kültürün düşünürüdür?', 'Çin', 'Yunan', 'Roma', 'Mısır', '0'],
  ],
  'İslam Felsefesi': [
    ['Muallim-i Sani diye anılan filozof kimdir?', 'Gazali', 'Farabi', 'İbn Haldun', 'Mevlana', '1'],
    ['Aristoteles yorumlarıyla tanınan Endülüslü filozof kimdir?', 'İbn Rüşd', 'Hallac', 'Yunus Emre', 'Hacı Bektaş', '0'],
    ['Gazali’nin filozofları eleştirdiği eserin adı nedir?', 'Tehafütü’l-Felasife', 'Mukaddime', 'Divan', 'Mesnevi', '0'],
  ],
};

List<BilgiQuestion> _subQuestions() {
  const difficulties = ['kolay', 'orta', 'zor'];
  final list = <BilgiQuestion>[];
  var block = 0;
  for (final entry in _felsefeSubs.entries) {
    for (var i = 0; i < entry.value.length; i++) {
      final row = entry.value[i];
      list.add(
        _t(
          'tr_fel_sub_${block}_$i',
          'felsefe',
          difficulties[i],
          row[0],
          [row[1], row[2], row[3], row[4]],
          int.parse(row[5]),
          tags: [entry.key],
        ),
      );
    }
    block += 1;
  }
  return list;
}

final bilgiTrialQuestions = <BilgiQuestion>[
  ..._category('felsefe', 'tr_fel', const [
    ['Sokrates’e göre erdemin kaynağı nedir?', 'Bilgi', 'Soy', 'Servet', 'Şans', '0', 'kolay'],
    ['Platon’un ideal devletini anlattığı eser hangisidir?', 'Devlet', 'Poetika', 'Denemeler', 'Leviathan', '0', 'kolay'],
    ['Aristoteles mantığında doğru çıkarımın adı nedir?', 'Kıyas', 'Sofizm', 'Paradoks', 'Mit', '0', 'orta'],
    ['“İnsan her şeyin ölçüsüdür” sözü hangi akıma yakındır?', 'Sofizm', 'Skolastik', 'Taoizm', 'Pozitivizm', '0', 'orta'],
    ['Stoacılığın kurucusu kabul edilen düşünür kimdir?', 'Zenon', 'Epikuros', 'Platon', 'Descartes', '0', 'orta'],
    ['Epikuros’un öğretisi en çok neyle ilişkilidir?', 'Haz ve acının dengesi', 'Mutlak monarşi', 'Boş inanç', 'Savaş', '0', 'kolay'],
    ['John Locke zihni neye benzetir?', 'Boş levha', 'Mağara', 'Saat', 'Nehir', '0', 'orta'],
    ['Hegel’in yönteminde üçlü ilerleyiş hangisidir?', 'Tez, antitez, sentez', 'Giriş, gelişme, sonuç', 'Öncül, sonuç, örnek', 'Neden, sonuç, şans', '0', 'zor'],
    ['Karl Marx’ın başyapıtı hangisidir?', 'Kapital', 'Prens', 'Utopya', 'Meditasyonlar', '0', 'kolay'],
    ['“Tanrı öldü” sözü hangi düşünürle anılır?', 'Nietzsche', 'Kant', 'Farabi', 'Aquinas', '0', 'kolay'],
    ['Descartes hangi çağın filozofudur?', 'Modern', 'Antik', 'Orta Çağ', 'İlk Çağ', '0', 'orta'],
    ['Spinoza’nın ünlü eseri hangisidir?', 'Etika', 'Devlet', 'Şehir', 'Sözler', '0', 'zor'],
    ['Francis Bacon’ın vurguladığı yöntem hangisidir?', 'Deney ve gözlem', 'Saf sezgi', 'Mit yorumu', 'Kehanet', '0', 'orta'],
    ['“Aydınlanma nedir?” sorusunu ünlü eden düşünür kimdir?', 'Kant', 'Homeros', 'Herodot', 'Öklid', '0', 'orta'],
    ['Varoluşçulukta özgürlük ve sorumluluk birlikte anılır. Bu vurgu kime yakındır?', 'Sartre', 'Tales', 'Öklid', 'Pisagor', '0', 'kolay'],
    ['Mantıkta bir önermenin karşıtını alma işlemine ne denir?', 'Değilleme', 'Toplama', 'Çarpma', 'Bölme', '0', 'orta'],
    ['Felsefede “neden varız?” sorusu hangi dala girer?', 'Metafizik', 'Estetik', 'Retorik', 'Aritmetik', '0', 'kolay'],
    ['Güzelin ne olduğunu soran felsefe dalı hangisidir?', 'Estetik', 'Etik', 'Mantık', 'Kozmoloji', '0', 'kolay'],
    ['Doğru eylemeyi soran felsefe dalı hangisidir?', 'Etik', 'Geometri', 'Astronomi', 'Müzik', '0', 'kolay'],
    ['Şüpheyi yöntem edinen modern filozof kimdir?', 'Descartes', 'Homeros', 'Herodot', 'Solon', '0', 'orta'],
  ]),
  ..._category('mitoloji', 'tr_mit', const [
    ['Yunan tanrılarının başı kimdir?', 'Zeus', 'Hades', 'Apollo', 'Ares', '0', 'kolay'],
    ['Denizlerin Yunan tanrısı kimdir?', 'Poseidon', 'Hermes', 'Dionysos', 'Pan', '0', 'kolay'],
    ['Yeraltı tanrısı Hades hangi mitolojidendir?', 'Yunan', 'Norse', 'Mısır', 'Aztek', '0', 'kolay'],
    ['Bilgelik tanrıçası Athena’nın simgesi nedir?', 'Baykuş', 'Trident', 'Çekiç', 'Güneş kursu', '0', 'orta'],
    ['Norse mitolojisinde tanrıların başı kimdir?', 'Odin', 'Loki', 'Thor', 'Freyr', '0', 'kolay'],
    ['Thor’un silahı nedir?', 'Çekiç Mjölnir', 'Mızrak Gungnir', 'Kılıç Excalibur', 'Yay', '0', 'kolay'],
    ['Mısır güneş tanrısı kimdir?', 'Ra', 'Anubis', 'Set', 'Thoth', '0', 'kolay'],
    ['Anubis en çok neyle ilişkilidir?', 'Ölüm ve mumyalama', 'Deniz', 'Hasat', 'Aşk', '0', 'orta'],
    ['Gılgamış destanı hangi uygarlığa aittir?', 'Mezopotamya', 'Aztek', 'Kelt', 'Slav', '0', 'orta'],
    ['Türk mitolojisinde yeraltı ile anılan varlık hangisidir?', 'Erlik', 'Zeus', 'Ra', 'Odin', '0', 'orta'],
    ['Japon güneş tanrıçası kimdir?', 'Amaterasu', 'Susanoo', 'İzanagi', 'Hachiman', '0', 'orta'],
    ['Aztek tüylü yılan tanrısı kimdir?', 'Quetzalcoatl', 'Thor', 'Şiva', 'Horus', '0', 'zor'],
    ['Medusa’ya bakanın taşa döndüğü anlatı hangi mitolojidendir?', 'Yunan', 'Çin', 'Slav', 'Polinezya', '0', 'kolay'],
    ['On iki görevle anılan kahraman kimdir?', 'Herakles', 'Odysseus', 'Aeneas', 'Beowulf', '0', 'kolay'],
    ['Odysseia kimin yolculuğunu anlatır?', 'Odysseus', 'Theseus', 'Perseus', 'Orpheus', '0', 'orta'],
    ['Norse mitolojisinde tanrıların son savaşına ne denir?', 'Ragnarök', 'Tufan', 'Olympos', 'Karma', '0', 'orta'],
    ['Prometheus insanlara neyi verdiği için cezalandırılır?', 'Ateşi', 'Yazıyı', 'Tekerleği', 'Parayı', '0', 'kolay'],
    ['Osiris hangi mitolojinin tanrısıdır?', 'Mısır', 'Kelt', 'Slav', 'Roma', '0', 'orta'],
    ['Minotor’un tutulduğu yapı nedir?', 'Labirent', 'Piramit', 'Ziggurat', 'Stonehenge', '0', 'kolay'],
    ['Roma aşk tanrıçasının adı nedir?', 'Venüs', 'Athena', 'Hestia', 'Demeter', '0', 'kolay'],
  ]),
  ..._category('din', 'tr_din', const [
    ['İslam’ın kutsal kitabı hangisidir?', 'Kur’an', 'Tevrat', 'İncil', 'Vedalar', '0', 'kolay'],
    ['Hristiyanlığın kutsal metin derlemesine ne denir?', 'İncil', 'Avesta', 'Tripitaka', 'Upanişadlar', '0', 'kolay'],
    ['Yahudiliğin temel metinlerinden biri hangisidir?', 'Tevrat', 'Kur’an', 'Guru Granth', 'Tao Te Ching', '0', 'kolay'],
    ['İslam’da günde kaç vakit namaz vardır?', 'Beş', 'Üç', 'Yedi', 'İki', '0', 'kolay'],
    ['Hac ibadeti hangi şehre yapılır?', 'Mekke', 'Medine yalnızca', 'Kudüs', 'İstanbul', '0', 'kolay'],
    ['Ramazan ayı hangi dinle ilişkilidir?', 'İslam', 'Budizm', 'Şinto', 'Sihizm', '0', 'kolay'],
    ['Noel hangi dinin kutlamasıyla özdeşleşmiştir?', 'Hristiyanlık', 'Hinduizm', 'Taoizm', 'Caynizm', '0', 'kolay'],
    ['On Emir hangi gelenekte anılır?', 'Yahudi ve Hristiyan', 'Şinto', 'Zerdüştlük yalnızca', 'Konfüçyüsçülük', '0', 'orta'],
    ['Budizmin kurucusu kimdir?', 'Siddhartha Gautama', 'Muhammed', 'Musa', 'Zerdüşt', '0', 'kolay'],
    ['Nirvana kavramı en çok hangi dinde geçer?', 'Budizm', 'İslam', 'Hristiyanlık', 'Yahudilik', '0', 'orta'],
    ['Hinduizmin eski metinlerine ne denir?', 'Vedalar', 'İncil', 'Kur’an', 'Talmud', '0', 'orta'],
    ['Kudüs hangi üç din için de önemlidir?', 'Yahudilik, Hristiyanlık, İslam', 'Şinto, Tao, Sih', 'Yalnızca Hinduizm', 'Yalnızca Budizm', '0', 'orta'],
    ['Vatikan hangi mezhebin merkezidir?', 'Katolik', 'Ortodoks', 'Protestan', 'Anglikan', '0', 'kolay'],
    ['Talmud hangi dine aittir?', 'Yahudilik', 'İslam', 'Budizm', 'Hinduizm', '0', 'orta'],
    ['Avesta hangi inancın metnidir?', 'Zerdüştlük', 'Sihizm', 'Caynizm', 'Şinto', '0', 'zor'],
    ['Şinto inancı hangi ülkeyle özdeşleşir?', 'Japonya', 'Hindistan', 'Mısır', 'Yunanistan', '0', 'orta'],
    ['Sihlerin kutsal kitabı hangisidir?', 'Guru Granth Sahib', 'Vedalar', 'İncil', 'Kur’an', '0', 'zor'],
    ['Hanuka hangi dine aittir?', 'Yahudilik', 'İslam', 'Budizm', 'Şinto', '0', 'orta'],
    ['İslam’ın beş şartından biri hangisidir?', 'Oruç', 'Vaftiz', 'Koşer', 'Yoga', '0', 'kolay'],
    ['Dharma kavramı en çok hangi geleneklerde geçer?', 'Hinduizm ve Budizm', 'Yalnızca Hristiyanlık', 'Yalnızca İslam', 'Yalnızca Şinto', '0', 'orta'],
  ]),
  ..._category('ezoterizm', 'tr_ezo', const [
    ['Klasik tarot destesindeki kart sayısı kaçtır?', '78', '52', '64', '22', '0', 'orta'],
    ['Batı astrolojisinde burç sayısı kaçtır?', 'On iki', 'Yedi', 'On', 'Yirmi', '0', 'kolay'],
    ['Yin ve yang hangi gelenekten gelir?', 'Çin', 'Yunan', 'Nordik', 'Aztek', '0', 'kolay'],
    ['Simyada kurşunu altına çevirme ülküsü neyi simgeler?', 'Dönüşüm', 'Savaş', 'Hasat', 'Denizcilik', '0', 'orta'],
    ['Hermes Trismegistus hangi alanla anılır?', 'Hermetizm', 'Fıkıh', 'Geometri', 'Deniz hukuku', '0', 'zor'],
    ['Feng shui en çok neyi düzenler?', 'Mekân ve akış', 'Vergi', 'Askerlik', 'Deniz feneri', '0', 'kolay'],
    ['Yaygın çakra anlatısında ana merkez sayısı kaçtır?', 'Yedi', 'Üç', 'On iki', 'Bir', '0', 'orta'],
    ['I Ching hangi kültürün kehanet kitabıdır?', 'Çin', 'Roma', 'Mısır', 'Kelt', '0', 'orta'],
    ['Runik yazı hangi gelenekle anılır?', 'İskandinav', 'Mısır', 'Maya', 'Arap', '0', 'orta'],
    ['Mandala en çok hangi gelenekte kullanılır?', 'Hint ve Budist', 'Roma hukuku', 'Denizcilik', 'Madencilik', '0', 'orta'],
    ['Pentagramın klasik çiziminde kaç köşe vardır?', 'Beş', 'Altı', 'Sekiz', 'Dört', '0', 'kolay'],
    ['Zodyak neyin kuşağıdır?', 'Burçlar', 'Okyanus akıntısı', 'Dağ silsilesi', 'Nehir', '0', 'kolay'],
    ['Nostradamus neyle tanınır?', 'Dörtlüklerle kehanet', 'Matbaa', 'Pusula', 'Barut', '0', 'kolay'],
    ['Kabbala hangi geleneğin mistik yorumudur?', 'Yahudi', 'Şinto', 'Aztek', 'İnka', '0', 'zor'],
    ['Reenkarnasyon inancı neyi söyler?', 'Ruhun yeniden doğması', 'Tek bir yaşam', 'Yalnızca rüya', 'Yalnızca unutuş', '0', 'kolay'],
    ['Simyada civanın klasik simgesi hangi gezegenle eşleşir?', 'Merkür', 'Satürn', 'Mars', 'Jüpiter', '0', 'zor'],
    ['Nazar boncuğu neye karşı bir simgedir?', 'Kötü bakış', 'Deprem', 'Vergi', 'Kıtlık yasası', '0', 'kolay'],
    ['Astroloji gök cisimleri ile neyi ilişkilendirir?', 'Kader ve karakter yorumu', 'Vergi oranı', 'Harita ölçeği', 'Mutfak tarifi', '0', 'kolay'],
    ['Ouija tahtası ne için kullanılır?', 'Ruh çağırma oyunu', 'Satranç', 'Deniz seyrüseferi', 'Terazi', '0', 'orta'],
    ['Aura anlatısında insanın çevresinde ne tasvir edilir?', 'Enerji alanı', 'Gölge saati', 'Pusula ibresi', 'Mürekkep', '0', 'orta'],
  ]),
  ..._category('psikoloji', 'tr_psi', const [
    ['Bilinçdışı kavramını öne çıkaran kuramcı kimdir?', 'Freud', 'Pavlov', 'Skinner', 'Piaget', '0', 'kolay'],
    ['Pavlov’un köpek deneyi hangi öğrenmeyi gösterir?', 'Klasik koşullanma', 'Gözlem', 'İçgörü', 'Taklit yalnızca', '0', 'kolay'],
    ['Maslow’un piramidinin tepesinde ne vardır?', 'Kendini gerçekleştirme', 'Açlık', 'Uyku', 'Güvenlik', '0', 'kolay'],
    ['Jung’un ortak sembol kalıplarına ne denir?', 'Arketip', 'Refleks', 'Uyarım', 'Eşik', '0', 'orta'],
    ['Piaget hangi gelişimi incelemiştir?', 'Bilişsel gelişim', 'Kas gelişimi', 'Diş gelişimi', 'Boy artışı', '0', 'orta'],
    ['Skinner hangi akıma yakındır?', 'Davranışçılık', 'Yapısalcılık', 'İçgörücü mistisizm', 'Simya', '0', 'orta'],
    ['İlk zekâ testini geliştiren isim kimdir?', 'Binet', 'Freud', 'Jung', 'Adler', '0', 'orta'],
    ['Adler’in öne çıkardığı kavram hangisidir?', 'Aşağılık karmaşası', 'Oedipus', 'Refleks yayı', 'Zekâ yaşı', '0', 'orta'],
    ['Kısa süreli belleğin kabaca kapasitesi kaç birim diye anılır?', 'Yedi artı eksi iki', 'İki', 'Yirmi', 'Yüz', '0', 'zor'],
    ['Gestalt psikolojisinin sloganı neye yakındır?', 'Bütün, parçaların toplamından fazladır', 'Yalnızca uyarıcıdır', 'Yalnızca içgüdüdür', 'Yalnızca reflekstir', '0', 'orta'],
    ['Bandura’nın Bobo bebeği deneyi neyi gösterir?', 'Gözleyerek öğrenme', 'Uyku evresi', 'Tat alma', 'Renk körlüğü', '0', 'orta'],
    ['Beck hangi terapi çizgisiyle anılır?', 'Bilişsel terapi', 'Hipnoz gösterisi', 'Frenoloji', 'Astroloji', '0', 'zor'],
    ['DSM neyin sınıflamasıdır?', 'Ruhsal bozukluklar', 'Bitkiler', 'Yıldızlar', 'Mineraller', '0', 'orta'],
    ['Empati neyi anlatır?', 'Karşının duygusunu anlama', 'Yalnızca unutma', 'Yalnızca refleks', 'Yalnızca açlık', '0', 'kolay'],
    ['Stres tepkisinde savaş ya da kaç hangi sistemle anılır?', 'Sempatik sinir sistemi', 'Sindirim yalnızca', 'İşitme', 'Koku', '0', 'orta'],
    ['Erikson gelişimi ne üzerinden böler?', 'Psikososyal evreler', 'Diş evreleri', 'Boy persentili', 'Kan grubu', '0', 'orta'],
    ['Rüya yorumunu psikanalizde öne çıkaran kimdir?', 'Freud', 'Skinner', 'Watson', 'Thorndike', '0', 'kolay'],
    ['Davranışçılık zihinden çok neyi inceler?', 'Gözlenebilir davranışı', 'Rüyayı', 'Mitolojiyi', 'Burcu', '0', 'kolay'],
    ['Klasik koşullanmada zil önce nötrdür, sonra ne olur?', 'Koşullu uyarıcı', 'Pekiştireç silinir', 'İçgüdü olur', 'Refleks kaybolur', '0', 'orta'],
    ['Bilişsel çarpıtma neyi anlatır?', 'Gerçeği çarpıtan düşünce kalıbı', 'Kas kramplı', 'Renk körlüğü', 'İşitme kaybı', '0', 'orta'],
  ]),
  ..._subQuestions(),
];

List<BilgiQuestion> _category(String categoryId, String prefix, List<List<String>> rows) {
  final list = <BilgiQuestion>[];
  for (var i = 0; i < rows.length; i++) {
    final row = rows[i];
    list.add(
      _t(
        '${prefix}_${(i + 1).toString().padLeft(2, '0')}',
        categoryId,
        row[6],
        row[0],
        [row[1], row[2], row[3], row[4]],
        int.parse(row[5]),
      ),
    );
  }
  return list;
}
