import 'package:kelimelig/core/constants/enums.dart';

/// Ordered easy → hard. Coins scale with difficulty.
class AchDef {
  const AchDef({
    required this.id,
    required this.nameTr,
    required this.nameEn,
    required this.descTr,
    required this.descEn,
    required this.icon,
    required this.coins,
  });

  final String id;
  final String nameTr;
  final String nameEn;
  final String descTr;
  final String descEn;
  final String icon;
  final int coins;

  String name(String locale) => locale == 'tr' ? nameTr : nameEn;
  String desc(String locale) => locale == 'tr' ? descTr : descEn;
}

/// Single source of truth for achievement list + rewards.
class AchievementsCatalog {
  static const all = <AchDef>[
    // —— Easy ——
    AchDef(
      id: 'first_step',
      nameTr: 'İlk Adım',
      nameEn: 'First Step',
      descTr: 'İlk oyunu tamamla',
      descEn: 'Finish your first game',
      icon: '🟢',
      coins: 10,
    ),
    AchDef(
      id: 'first_win',
      nameTr: 'İlk Zafer',
      nameEn: 'First Win',
      descTr: 'İlk kez bir kelimeyi bul',
      descEn: 'Win a game for the first time',
      icon: '✨',
      coins: 15,
    ),
    AchDef(
      id: 'bookmark',
      nameTr: 'Kelime Defteri',
      nameEn: 'Word Book',
      descTr: 'İlk kelimeyi kaydet',
      descEn: 'Save your first word',
      icon: '📖',
      coins: 10,
    ),
    AchDef(
      id: 'curious',
      nameTr: 'Meraklı',
      nameEn: 'Curious',
      descTr: '5 oyun oyna',
      descEn: 'Play 5 games',
      icon: '👀',
      coins: 15,
    ),
    AchDef(
      id: 'getting_hot',
      nameTr: 'Isınıyor',
      nameEn: 'Warming Up',
      descTr: '5 galibiyet kazan',
      descEn: 'Win 5 games',
      icon: '🌤️',
      coins: 20,
    ),
    AchDef(
      id: 'fire_started',
      nameTr: 'Ateş Başladı',
      nameEn: 'On Fire',
      descTr: '3 günlük streak yap',
      descEn: 'Reach a 3-day streak',
      icon: '🔥',
      coins: 25,
    ),
    AchDef(
      id: 'clean_win',
      nameTr: 'Temiz Zafer',
      nameEn: 'Clean Win',
      descTr: 'İpucu kullanmadan bir oyun kazan',
      descEn: 'Win a game without hints',
      icon: '🧼',
      coins: 20,
    ),
    AchDef(
      id: 'speed_minute',
      nameTr: 'Dakika Adamı',
      nameEn: 'Under a Minute',
      descTr: '60 saniyeden kısa sürede çöz',
      descEn: 'Solve in under 60 seconds',
      icon: '⏱️',
      coins: 20,
    ),
    AchDef(
      id: 'ten_wins',
      nameTr: 'Onluk',
      nameEn: 'Ten Wins',
      descTr: '10 galibiyet kazan',
      descEn: 'Win 10 games',
      icon: '🔟',
      coins: 25,
    ),
    AchDef(
      id: 'wordbook_10',
      nameTr: 'Koleksiyoncu',
      nameEn: 'Collector',
      descTr: '10 kelime kaydet',
      descEn: 'Save 10 words',
      icon: '📚',
      coins: 30,
    ),
    // —— Medium ——
    AchDef(
      id: 'endless_starter',
      nameTr: 'Seri Başladı',
      nameEn: 'Run Starter',
      descTr: 'Maraton’da 3’lü seri yap',
      descEn: 'Reach an endless run of 3',
      icon: '🎢',
      coins: 30,
    ),
    AchDef(
      id: 'silver_league',
      nameTr: 'Gümüş',
      nameEn: 'Silver',
      descTr: 'Gümüş lige çık',
      descEn: 'Reach Silver league',
      icon: '🥈',
      coins: 40,
    ),
    AchDef(
      id: 'fire_week',
      nameTr: 'Haftalık Ateş',
      nameEn: 'Week on Fire',
      descTr: '7 günlük streak yap',
      descEn: 'Reach a 7-day streak',
      icon: '🗓️',
      coins: 50,
    ),
    AchDef(
      id: 'lightning',
      nameTr: 'Şimşek',
      nameEn: 'Lightning',
      descTr: '20 saniyeden kısa sürede çöz',
      descEn: 'Solve in under 20 seconds',
      icon: '⚡',
      coins: 35,
    ),
    AchDef(
      id: 'sharp_eye',
      nameTr: 'Keskin Göz',
      nameEn: 'Sharp Eye',
      descTr: 'İlk tahminde bir kez çöz',
      descEn: 'Solve in one guess once',
      icon: '🎯',
      coins: 40,
    ),
    AchDef(
      id: 'veteran',
      nameTr: 'Kıdemli',
      nameEn: 'Veteran',
      descTr: '25 galibiyet kazan',
      descEn: 'Win 25 games',
      icon: '🏅',
      coins: 45,
    ),
    AchDef(
      id: 'clean_five',
      nameTr: 'Saf Oyuncu',
      nameEn: 'Pure Player',
      descTr: '5 oyunu ipucusuz kazan',
      descEn: 'Win 5 games without hints',
      icon: '💎',
      coins: 50,
    ),
    AchDef(
      id: 'endless_ten',
      nameTr: 'Onlu Seri',
      nameEn: 'Ten Run',
      descTr: 'Maraton’da 10’lu seri yap',
      descEn: 'Reach an endless run of 10',
      icon: '🌀',
      coins: 60,
    ),
    AchDef(
      id: 'wordbook_50',
      nameTr: 'Bilgin',
      nameEn: 'Scholar',
      descTr: '50 kelime kaydet',
      descEn: 'Save 50 words',
      icon: '🧠',
      coins: 55,
    ),
    AchDef(
      id: 'bilingual',
      nameTr: 'Çift Dil',
      nameEn: 'Bilingual',
      descTr: 'Hem Türkçe hem İngilizce oyna',
      descEn: 'Play in both Turkish and English',
      icon: '🌍',
      coins: 70,
    ),
    // —— Hard ——
    AchDef(
      id: 'perfectionist',
      nameTr: 'Mükemmeliyetçi',
      nameEn: 'Perfectionist',
      descTr: '10 kez ilk tahminde çöz',
      descEn: 'Solve in one guess 10 times',
      icon: '🎯',
      coins: 75,
    ),
    AchDef(
      id: 'gold_league',
      nameTr: 'Altın',
      nameEn: 'Gold',
      descTr: 'Altın lige ulaş',
      descEn: 'Reach Gold league',
      icon: '🥇',
      coins: 100,
    ),
    AchDef(
      id: 'lightning_10',
      nameTr: 'Işık Hızı',
      nameEn: 'Light Speed',
      descTr: '10 saniyeden kısa sürede çöz',
      descEn: 'Solve in under 10 seconds',
      icon: '💨',
      coins: 80,
    ),
    AchDef(
      id: 'fire_month',
      nameTr: 'Aylık Efsane',
      nameEn: 'Monthly Legend',
      descTr: '30 günlük streak yap',
      descEn: 'Reach a 30-day streak',
      icon: '🌋',
      coins: 120,
    ),
    AchDef(
      id: 'professor',
      nameTr: 'Profesör',
      nameEn: 'Professor',
      descTr: '100 galibiyet kazan',
      descEn: 'Win 100 games',
      icon: '🎓',
      coins: 100,
    ),
    AchDef(
      id: 'endless_25',
      nameTr: 'Usta Seri',
      nameEn: 'Master Run',
      descTr: 'Maraton’da 25’li seri yap',
      descEn: 'Reach an endless run of 25',
      icon: '🏆',
      coins: 150,
    ),
    AchDef(
      id: 'gold_perfect',
      nameTr: 'Altın Dokunuş',
      nameEn: 'Golden Touch',
      descTr: 'Altın ligde (7 harf) ilk tahminde çöz',
      descEn: 'One-guess a 7-letter Gold word',
      icon: '👑',
      coins: 150,
    ),
    AchDef(
      id: 'clean_fifty',
      nameTr: 'Keşiş',
      nameEn: 'Monk',
      descTr: '50 oyunu ipucusuz kazan',
      descEn: 'Win 50 games without hints',
      icon: '🧘',
      coins: 200,
    ),
    AchDef(
      id: 'legend',
      nameTr: 'Efsane',
      nameEn: 'Legend',
      descTr: 'Altın ligdeyken 30 günlük streak tut',
      descEn: 'Hold a 30-day streak in Gold',
      icon: '🌟',
      coins: 250,
    ),
    AchDef(
      id: 'grandmaster',
      nameTr: 'Büyükusta',
      nameEn: 'Grandmaster',
      descTr: '250 galibiyet kazan',
      descEn: 'Win 250 games',
      icon: '♟️',
      coins: 300,
    ),
  ];

  static AchDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static bool leagueAtLeast(LeagueTier current, LeagueTier min) {
    return current.index >= min.index;
  }
}
