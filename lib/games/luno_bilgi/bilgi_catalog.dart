class BilgiCategory {
  const BilgiCategory({
    required this.id,
    required this.group,
    required this.name,
    required this.emoji,
    required this.subs,
    this.active = true,
  });

  final String id;
  final String group;
  final String name;
  final String emoji;
  final List<String> subs;
  final bool active;

  String get karmaName => '$name Karma';
}

const bilgiGroups = <String>[
  'A. Temel Bilgi',
  'B. Tarih ve Medeniyet',
  'C. Bilim ve Teknoloji',
  'D. Sanat ve Edebiyat',
  'E. Felsefe ve İnanç',
  'F. Spor ve Oyun',
  'G. Yaşam ve Pratik',
  'H. Popüler Kültür',
];

const tumuKarmaId = 'tumu';

const bilgiCategories = <BilgiCategory>[
  BilgiCategory(id: 'genel', group: 'A. Temel Bilgi', name: 'Genel Kültür', emoji: '🧠', subs: ['Atasözleri', 'Günlük Bilgi']),
  BilgiCategory(id: 'turkiye', group: 'A. Temel Bilgi', name: 'Türkiye', emoji: '🇹🇷', subs: ['Şehirler', 'Simgeler']),
  BilgiCategory(id: 'dunya_kultur', group: 'A. Temel Bilgi', name: 'Dünya Kültürleri', emoji: '🌏', subs: ['Gelenekler', 'Bayramlar']),
  BilgiCategory(id: 'cografya', group: 'A. Temel Bilgi', name: 'Coğrafya', emoji: '🌍', subs: ['Ülkeler', 'Nehirler']),
  BilgiCategory(id: 'doga', group: 'A. Temel Bilgi', name: 'Doğa ve Çevre', emoji: '🌿', subs: ['Bitkiler', 'İklim']),
  BilgiCategory(id: 'uzay', group: 'A. Temel Bilgi', name: 'Uzay ve Astronomi', emoji: '🚀', subs: ['Gezegenler', 'Gökyüzü']),
  BilgiCategory(id: 'deniz', group: 'A. Temel Bilgi', name: 'Deniz ve Okyanus', emoji: '🌊', subs: ['Okyanuslar', 'Deniz Canlıları']),
  BilgiCategory(id: 'afet', group: 'A. Temel Bilgi', name: 'Doğal Afetler', emoji: '🌋', subs: ['Deprem', 'İklim Olayları']),
  BilgiCategory(id: 'tas', group: 'A. Temel Bilgi', name: 'Değerli Taşlar', emoji: '💎', subs: ['Elmas', 'Madenler']),
  BilgiCategory(id: 'renk', group: 'A. Temel Bilgi', name: 'Renkler ve Şekiller', emoji: '🌈', subs: ['Renkler', 'Geometri']),
  BilgiCategory(id: 'turk_tarihi', group: 'B. Tarih ve Medeniyet', name: 'Türk Tarihi', emoji: '🏛️', subs: ['İlk Türk Devletleri', 'Selçuklu', 'Beylikler', 'Kültür ve Medeniyet', 'Ünlü Türk Komutanlar']),
  BilgiCategory(id: 'osmanli', group: 'B. Tarih ve Medeniyet', name: 'Osmanlı Tarihi', emoji: '👑', subs: ['Kuruluş', 'Duraklama', 'Yenileşme']),
  BilgiCategory(id: 'cumhuriyet', group: 'B. Tarih ve Medeniyet', name: 'Cumhuriyet Tarihi', emoji: '🇹🇷', subs: ['Kurtuluş', 'İnkılaplar']),
  BilgiCategory(id: 'dunya_tarihi', group: 'B. Tarih ve Medeniyet', name: 'Dünya Tarihi', emoji: '📜', subs: ['Çağlar', 'Keşifler']),
  BilgiCategory(id: 'savas', group: 'B. Tarih ve Medeniyet', name: 'Savaşlar', emoji: '⚔️', subs: ['Dünya Savaşları', 'Antlaşmalar']),
  BilgiCategory(id: 'arkeoloji', group: 'B. Tarih ve Medeniyet', name: 'Arkeoloji', emoji: '🏺', subs: ['Kazılar', 'Yazıtlar']),
  BilgiCategory(id: 'antik', group: 'B. Tarih ve Medeniyet', name: 'Antik Uygarlıklar', emoji: '🗿', subs: ['Mısır', 'Mezopotamya']),
  BilgiCategory(id: 'devrim', group: 'B. Tarih ve Medeniyet', name: 'Devrimler', emoji: '📖', subs: ['Sanayi', 'Siyaset']),
  BilgiCategory(id: 'bilim', group: 'C. Bilim ve Teknoloji', name: 'Bilim', emoji: '🔬', subs: ['Yöntem', 'Bilim İnsanları']),
  BilgiCategory(id: 'kimya', group: 'C. Bilim ve Teknoloji', name: 'Kimya', emoji: '⚗️', subs: ['Elementler', 'Bileşikler']),
  BilgiCategory(id: 'biyoloji', group: 'C. Bilim ve Teknoloji', name: 'Biyoloji', emoji: '🧬', subs: ['Hücre', 'Canlılar']),
  BilgiCategory(id: 'fizik', group: 'C. Bilim ve Teknoloji', name: 'Fizik', emoji: '⚛️', subs: ['Kuvvet', 'Enerji']),
  BilgiCategory(id: 'teknoloji', group: 'C. Bilim ve Teknoloji', name: 'Teknoloji', emoji: '💻', subs: ['Bilgisayar', 'İnternet']),
  BilgiCategory(id: 'dijital', group: 'C. Bilim ve Teknoloji', name: 'Dijital', emoji: '📱', subs: ['Yazılım', 'Cihazlar']),
  BilgiCategory(id: 'mucit', group: 'C. Bilim ve Teknoloji', name: 'Mucitler ve İcatlar', emoji: '🔧', subs: ['Mucitler', 'İcatlar']),
  BilgiCategory(id: 'tip', group: 'C. Bilim ve Teknoloji', name: 'Tıp ve Sağlık', emoji: '🧪', subs: ['Hastalıklar', 'Keşifler']),
  BilgiCategory(id: 'edebiyat', group: 'D. Sanat ve Edebiyat', name: 'Edebiyat', emoji: '📚', subs: ['Türler', 'Akımlar']),
  BilgiCategory(id: 'sinema', group: 'D. Sanat ve Edebiyat', name: 'Sinema', emoji: '🎬', subs: ['Yönetmenler', 'Ödüller']),
  BilgiCategory(id: 'muzik', group: 'D. Sanat ve Edebiyat', name: 'Müzik', emoji: '🎵', subs: ['Çalgılar', 'Besteciler']),
  BilgiCategory(id: 'sanat', group: 'D. Sanat ve Edebiyat', name: 'Sanat', emoji: '🎨', subs: ['Resim', 'Heykel']),
  BilgiCategory(id: 'tiyatro', group: 'D. Sanat ve Edebiyat', name: 'Tiyatro ve Opera', emoji: '🎭', subs: ['Sahne', 'Opera']),
  BilgiCategory(id: 'fotograf', group: 'D. Sanat ve Edebiyat', name: 'Fotoğrafçılık', emoji: '📷', subs: ['Işık', 'Makine']),
  BilgiCategory(id: 'muze', group: 'D. Sanat ve Edebiyat', name: 'Müzeler', emoji: '🏛️', subs: ['Türkiye', 'Dünya']),
  BilgiCategory(id: 'yazar', group: 'D. Sanat ve Edebiyat', name: 'Yazarlar', emoji: '✍️', subs: ['Türk', 'Dünya']),
  BilgiCategory(id: 'felsefe', group: 'E. Felsefe ve İnanç', name: 'Felsefe', emoji: '🧘', subs: [
    'Antik Yunan Felsefesi',
    'Roma Felsefesi',
    'Orta Çağ Felsefesi',
    'Modern Felsefe',
    'İslam Felsefesi',
    'Çağdaş Felsefe',
    'Doğu Felsefesi',
    'Etik',
    'Metafizik',
    'Epistemoloji',
    'Siyaset Felsefesi',
    'Estetik',
    'Zihin Felsefesi',
    'Dil Felsefesi',
  ]),
  BilgiCategory(id: 'felsefe_antik', group: 'E. Felsefe ve İnanç', name: 'Antik', emoji: '🏛️', subs: []),
  BilgiCategory(id: 'felsefe_modern', group: 'E. Felsefe ve İnanç', name: 'Modern', emoji: '🧠', subs: []),
  BilgiCategory(id: 'mitoloji', group: 'E. Felsefe ve İnanç', name: 'Mitoloji', emoji: '⚡', subs: [
    'Yunan Mitolojisi',
    'Roma Mitolojisi',
    'Mısır Mitolojisi',
    'Norse Mitolojisi',
    'Mezopotamya Mitolojisi',
    'Hint Mitolojisi',
    'Çin Mitolojisi',
    'Japon Mitolojisi',
    'Kelt Mitolojisi',
    'Slav Mitolojisi',
    'Türk Mitolojisi',
    'Aztek-Maya-İnka Mitolojisi',
    'Afrika Mitolojisi',
    'Polinezya Mitolojisi',
    'Tanrılar ve Tanrıçalar',
    'Yaratıklar ve Canavarlar',
    'Kahramanlar ve Yarı-Tanrılar',
    'Efsanevi Yerler',
    'Yaratılış Mitleri',
    'Kıyamet Mitleri',
    'Ölüm ve Yeraltı',
    'Destanlar',
    'Kutsal Metinler',
    'Halk Hikâyeleri',
  ]),
  BilgiCategory(id: 'mitoloji_yunan', group: 'E. Felsefe ve İnanç', name: 'Yunan', emoji: '⚡', subs: []),
  BilgiCategory(id: 'mitoloji_iskandinav', group: 'E. Felsefe ve İnanç', name: 'İskandinav', emoji: '🪓', subs: []),
  BilgiCategory(id: 'din', group: 'E. Felsefe ve İnanç', name: 'Dinler', emoji: '🕊️', subs: []),
  BilgiCategory(id: 'din_inanclar', group: 'E. Felsefe ve İnanç', name: 'İnançlar', emoji: '🕊️', subs: []),
  BilgiCategory(id: 'din_kutsal', group: 'E. Felsefe ve İnanç', name: 'Kutsal Metinler', emoji: '📜', subs: []),
  BilgiCategory(id: 'ezoterizm', group: 'E. Felsefe ve İnanç', name: 'Ezoterizm', emoji: '🔮', subs: []),
  BilgiCategory(id: 'ezoterizm_simgeler', group: 'E. Felsefe ve İnanç', name: 'Simgeler', emoji: '🔮', subs: []),
  BilgiCategory(id: 'ezoterizm_gelenekler', group: 'E. Felsefe ve İnanç', name: 'Gelenekler', emoji: '🌙', subs: []),
  BilgiCategory(id: 'psikoloji', group: 'E. Felsefe ve İnanç', name: 'Psikoloji', emoji: '💭', subs: []),
  BilgiCategory(id: 'psikoloji_kuramlar', group: 'E. Felsefe ve İnanç', name: 'Kuramlar', emoji: '💭', subs: []),
  BilgiCategory(id: 'psikoloji_kavramlar', group: 'E. Felsefe ve İnanç', name: 'Kavramlar', emoji: '🧩', subs: []),
  BilgiCategory(id: 'mantik', group: 'E. Felsefe ve İnanç', name: 'Mantık', emoji: '🧠', subs: []),
  BilgiCategory(id: 'mantik_cikarim', group: 'E. Felsefe ve İnanç', name: 'Çıkarım', emoji: '🧠', subs: []),
  BilgiCategory(id: 'mantik_bilmeceler', group: 'E. Felsefe ve İnanç', name: 'Bilmeceler', emoji: '❓', subs: []),
  BilgiCategory(id: 'futbol', group: 'F. Spor ve Oyun', name: 'Futbol', emoji: '⚽', subs: ['Kulüpler', 'Turnuvalar']),
  BilgiCategory(id: 'basketbol', group: 'F. Spor ve Oyun', name: 'Basketbol', emoji: '🏀', subs: ['Kurallar', 'Ligler']),
  BilgiCategory(id: 'tenis', group: 'F. Spor ve Oyun', name: 'Tenis ve Diğer', emoji: '🎾', subs: ['Tenis', 'Raket Sporları']),
  BilgiCategory(id: 'olimpiyat', group: 'F. Spor ve Oyun', name: 'Olimpiyatlar', emoji: '🏅', subs: ['Yaz', 'Kış']),
  BilgiCategory(id: 'oyun', group: 'F. Spor ve Oyun', name: 'Video Oyunları', emoji: '🎮', subs: ['Türler', 'Tarihçe']),
  BilgiCategory(id: 'masa', group: 'F. Spor ve Oyun', name: 'Masa Oyunları', emoji: '🎲', subs: ['Satranç', 'Kart']),
  BilgiCategory(id: 'yemek', group: 'G. Yaşam ve Pratik', name: 'Yemek ve Mutfak', emoji: '🍳', subs: ['Türk Mutfağı', 'Dünya Mutfağı']),
  BilgiCategory(id: 'saglik', group: 'G. Yaşam ve Pratik', name: 'Sağlık', emoji: '🏥', subs: ['Beslenme', 'Vücut']),
  BilgiCategory(id: 'ekonomi', group: 'G. Yaşam ve Pratik', name: 'Ekonomi ve Finans', emoji: '💰', subs: ['Kavramlar', 'Piyasa']),
  BilgiCategory(id: 'oto', group: 'G. Yaşam ve Pratik', name: 'Otomobil', emoji: '🚗', subs: ['Markalar', 'Parçalar']),
  BilgiCategory(id: 'seyahat', group: 'G. Yaşam ve Pratik', name: 'Seyahat', emoji: '✈️', subs: ['Kentler', 'Ulaşım']),
  BilgiCategory(id: 'ev', group: 'G. Yaşam ve Pratik', name: 'Ev ve Dekorasyon', emoji: '🏠', subs: ['Malzeme', 'Üslup']),
  BilgiCategory(id: 'moda', group: 'G. Yaşam ve Pratik', name: 'Moda', emoji: '👗', subs: ['Kumaş', 'Tarih']),
  BilgiCategory(id: 'unlu', group: 'H. Popüler Kültür', name: 'Ünlüler', emoji: '🌟', subs: ['Sahne', 'Spor']),
  BilgiCategory(id: 'dizi', group: 'H. Popüler Kültür', name: 'Diziler', emoji: '📺', subs: ['Türler', 'Yapım']),
  BilgiCategory(id: 'yarisma', group: 'H. Popüler Kültür', name: 'Yarışmalar', emoji: '🎤', subs: ['Müzik', 'Bilgi']),
  BilgiCategory(id: 'guncel', group: 'H. Popüler Kültür', name: 'Güncel', emoji: '📰', subs: ['Kurumlar', 'Kavramlar']),
  BilgiCategory(id: 'etkinlik', group: 'H. Popüler Kültür', name: 'Etkinlikler', emoji: '🎉', subs: ['Festivaller', 'Günler']),
  BilgiCategory(id: 'internet', group: 'H. Popüler Kültür', name: 'İnternet Kültürü', emoji: '🌐', subs: ['Terimler', 'Platformlar']),
  BilgiCategory(id: 'karma', group: 'H. Popüler Kültür', name: 'Genel Karma', emoji: '🃏', subs: ['Karışık']),
];

const bilgiSubEmoji = <String, String>{
  'Antik Yunan Felsefesi': '🏺',
  'Roma Felsefesi': '🏛️',
  'Orta Çağ Felsefesi': '⛪',
  'Modern Felsefe': '🧬',
  'İslam Felsefesi': '🕌',
  'Çağdaş Felsefe': '🌐',
  'Doğu Felsefesi': '☯️',
  'Etik': '⚖️',
  'Metafizik': '🌌',
  'Epistemoloji': '🔍',
  'Siyaset Felsefesi': '🗳️',
  'Estetik': '🎨',
  'Zihin Felsefesi': '🧠',
  'Dil Felsefesi': '🗣️',
  'Yunan Mitolojisi': '🇬🇷',
  'Roma Mitolojisi': '🇮🇹',
  'Mısır Mitolojisi': '🇪🇬',
  'Norse Mitolojisi': '🪓',
  'Mezopotamya Mitolojisi': '🏺',
  'Hint Mitolojisi': '🕉️',
  'Çin Mitolojisi': '🐉',
  'Japon Mitolojisi': '⛩️',
  'Kelt Mitolojisi': '🍀',
  'Slav Mitolojisi': '🌲',
  'Türk Mitolojisi': '🐺',
  'Aztek-Maya-İnka Mitolojisi': '🌞',
  'Afrika Mitolojisi': '🥁',
  'Polinezya Mitolojisi': '🌊',
  'Tanrılar ve Tanrıçalar': '⚡',
  'Yaratıklar ve Canavarlar': '🐲',
  'Kahramanlar ve Yarı-Tanrılar': '🗡️',
  'Efsanevi Yerler': '🏝️',
  'Yaratılış Mitleri': '🌌',
  'Kıyamet Mitleri': '🔥',
  'Ölüm ve Yeraltı': '💀',
  'Destanlar': '📜',
  'Kutsal Metinler': '📖',
  'Halk Hikâyeleri': '🗣️',
};

String bilgiSubIcon(String name, String fallback) => bilgiSubEmoji[name] ?? fallback;

BilgiCategory? bilgiCategoryById(String id) {
  for (final category in bilgiCategories) {
    if (category.id == id) return category;
  }
  return null;
}

/// Kategoriler ve alt kategoriler, sunucunun açık listesinde yoksa kapalıdır.
Map<String, dynamic> bilgiCatalogClosedUnless(
  Map<String, dynamic>? catalog,
  Set<String> openCategories,
  Set<String> openSubs,
) {
  final resolved = resolveBilgiCategories(catalog);
  return {
    ...?catalog,
    'inactive': [
      for (final category in resolved)
        if (!openCategories.contains(category.id)) category.id,
    ],
    'inactiveSubs': [
      for (final category in resolved)
        for (final sub in category.subs)
          if (!openSubs.contains('${category.id}|$sub')) '${category.id}|$sub',
    ],
  };
}

List<BilgiCategory> resolveBilgiCategories(Map<String, dynamic>? catalog, {bool playableOnly = false}) {
  final hidden = _catalogIds(catalog?['hidden']);
  final inactive = _catalogIds(catalog?['inactive']);
  final inactiveSubs = _catalogIds(catalog?['inactiveSubs']);
  final removedSubs = _catalogIds(catalog?['removedSubs']);
  final renames = catalog?['subRenames'] is Map ? catalog!['subRenames'] as Map : const {};
  final edits = catalog?['edits'] is Map ? catalog!['edits'] as Map : const {};
  final extra = catalog?['extraSubs'] is Map ? catalog!['extraSubs'] as Map : const {};
  final out = <BilgiCategory>[
    for (final category in bilgiCategories)
      if (!hidden.contains(category.id))
        _patchedCategory(
          category,
          edits[category.id],
          extra[category.id],
          active: !inactive.contains(category.id),
          inactiveSubs: inactiveSubs,
          removedSubs: removedSubs,
          renames: renames,
          playableOnly: playableOnly,
        ),
  ];
  final custom = catalog?['custom'];
  if (custom is List) {
    for (final raw in custom) {
      if (raw is! Map) continue;
      final id = '${raw['id'] ?? ''}'.trim();
      if (id.isEmpty || hidden.contains(id)) continue;
      final active = raw['active'] != false && !inactive.contains(id);
      if (playableOnly && !active) continue;
      final name = '${raw['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      out.add(
        BilgiCategory(
          id: id,
          group: '${raw['group'] ?? bilgiGroups.first}',
          name: name,
          emoji: '${raw['emoji'] ?? '📚'}'.trim().isEmpty ? '📚' : '${raw['emoji']}'.trim(),
          subs: _mergedSubs(id, [for (final item in raw['subs'] as List? ?? const []) '$item'], const [], inactiveSubs, removedSubs, renames, playableOnly),
          active: active,
        ),
      );
    }
  }
  if (playableOnly) return [for (final category in out) if (category.active) category];
  return out;
}

BilgiCategory _patchedCategory(
  BilgiCategory category,
  Object? raw,
  Object? extra, {
  required bool active,
  required Set<String> inactiveSubs,
  required Set<String> removedSubs,
  required Map renames,
  required bool playableOnly,
}) {
  if (playableOnly && !active) {
    return BilgiCategory(id: category.id, group: category.group, name: category.name, emoji: category.emoji, subs: const [], active: false);
  }
  final edit = raw is Map ? raw : const {};
  final name = edit['name'];
  final emoji = edit['emoji'];
  final group = edit['group'];
  return BilgiCategory(
    id: category.id,
    group: group is String && group.trim().isNotEmpty ? group.trim() : category.group,
    name: name is String && name.trim().isNotEmpty ? name.trim() : category.name,
    emoji: emoji is String && emoji.trim().isNotEmpty ? emoji.trim() : category.emoji,
    subs: _mergedSubs(category.id, category.subs, extra, inactiveSubs, removedSubs, renames, playableOnly),
    active: active,
  );
}

List<String> _mergedSubs(
  String categoryId,
  List<String> base,
  Object? extra,
  Set<String> inactiveSubs,
  Set<String> removedSubs,
  Map renames,
  bool playableOnly,
) {
  final added = extra is List ? [for (final item in extra) '$item'.trim()] : const <String>[];
  final seen = <String>{};
  final out = <String>[];
  String shown(String source) {
    final renamed = renames['$categoryId|$source'];
    return renamed is String && renamed.trim().isNotEmpty ? renamed.trim() : source;
  }

  for (final name in [...base, ...added]) {
    final source = name.trim();
    if (source.isEmpty || removedSubs.contains('$categoryId|$source')) continue;
    final display = shown(source);
    if (display.isEmpty || removedSubs.contains('$categoryId|$display') || !seen.add(display.toLowerCase())) continue;
    if (playableOnly && inactiveSubs.contains('$categoryId|$display')) continue;
    out.add(display);
  }
  return out;
}

Set<String> _catalogIds(Object? raw) => {
      for (final item in raw is List ? raw : const []) '$item',
    };
