const GAME_PAGES = {
  luno_league: {
    tr: {
      about: [
        'Luno League, gizli bir kelimeyi harf harf çözdüğün bir kelime oyunudur. Her tahmin, sözlükte bulunan ve gizli kelimeyle aynı uzunlukta bir kelime olmalıdır. Doğru yerdeki harf yeşil yanar, kelimede olup yeri yanlış olan sarı, hiç olmayan gri. Amaç, az denemeyle doğru kelimeye varmaktır.',
        'Oyun ücretsiz indirilir. Daily’ye misafir olarak da girebilirsin. Lig, sıralama ve ödüller bir hesaba bağlanır. Dil değişince sözlük, klavye ve lig birlikte değişir; her dilin skoru ayrı durur.',
      ],
      steps: [
        'Zorluğu seç. Bronz 5, Gümüş 6, Altın 7 harfli kelime kullanır.',
        'Sözlükteki bir kelimeyi yaz ve gönder.',
        'Renkleri oku. Yeşil yerinde, sarı kelimede ama yanlış yerde, gri yok.',
        'Kalan hakla kelimeyi bul. Bronz ligde 6 deneme vardır.',
        'Takılırsan harf veya anlam ipucu aç. İpucu coin harcar.',
      ],
      modes: [
        { t: 'Daily', p: 'Günün kelimesi günde bir kez gelir. Gece yarısı yenilenir. Misafir de oynayabilir.' },
        { t: 'Maraton', p: 'Kaybedene kadar yeni kelime gelir. Seriyi, istersen kısa bir reklamla koruyabilirsin.' },
        { t: 'Lig', p: 'Haftalık sıralama, ay, sezon ve yıl tutulur. Üst sıralar coin ve unvan getirir. Zorluk kendiliğinden yükselmez; ayarlardan değiştirirsin.' },
        { t: 'Düello', p: 'Arkadaşına bir kod gönderirsin. İkiniz de aynı kelimeyi çözersiniz.' },
      ],
      age: '13 yaş ve üzeri',
      ageNote: 'Kurallar kısadır, okuma bilen herkes çabuk öğrenir. Uygulama 13 yaşın altındaki çocuklara yönelik değildir.',
      ads: 'yes',
      adsNote: 'Reklam vardır. Ödüllü reklam isteğe bağlıdır: izlersen coin kazanırsın, izlemek zorunda değilsin.',
      iap: 'yes',
      iapNote: 'İndirmek ücretsizdir. Mağazada coin ve seri kalkanı Google Play üzerinden alınır. Ödemeyi mağaza alır. Coin, oyun ve reklamla da kazanılır.',
    },
    en: {
      about: [
        'Luno League is a word game: you solve a hidden word one letter at a time. Every guess must be a real dictionary word of the same length. A letter in the right place turns green, a letter that belongs elsewhere turns yellow, and a letter that is absent turns gray. The aim is to reach the word in as few tries as you can.',
        'The game is free to download. Daily is open to guests. League, rankings, and rewards sit on an account. Changing the language changes the dictionary, the keyboard, and the league together. Each language keeps its own scores.',
      ],
      steps: [
        'Pick a difficulty. Bronze uses 5 letters, Silver 6, Gold 7.',
        'Type a dictionary word and send it.',
        'Read the colors. Green is in place, yellow is in the word but in the wrong place, gray is absent.',
        'Find the word with the tries you have left. Bronze gives 6 tries.',
        'If you stall, open a letter hint or a meaning hint. Hints spend coins.',
      ],
      modes: [
        { t: 'Daily', p: 'One word for the day. It refreshes at midnight. Guests can play.' },
        { t: 'Marathon', p: 'A new word arrives until you lose. You can keep a streak with a short ad if you want.' },
        { t: 'League', p: 'Rankings run by week, month, season, and year. The top places earn coins and titles. Difficulty does not climb on its own; you change it in settings.' },
        { t: 'Duel', p: 'Send a friend a code. You both solve the same word.' },
      ],
      age: 'Ages 13 and up',
      ageNote: 'The rules are short, so anyone who can read learns them quickly. The app is not directed at children under 13.',
      ads: 'yes',
      adsNote: 'The game has ads. A rewarded ad is optional: watch one and you earn coins. You do not have to watch.',
      iap: 'yes',
      iapNote: 'Download is free. The shop sells coins and a streak shield through Google Play. The store handles payment. Coins are also earned by playing and by watching ads.',
    },
  },
  luno_fall: {
    tr: {
      about: [
        'Luno Fall, harflerin düştüğü ve kelimelerin ortaya çıktığı sıradaki oyundur. Luno League ile aynı çizgidedir: ilk bakışta anlaşılan, kısa süren, kelimeyi merkeze alan bir oyun.',
        'Ayrıntılı kurallar oyun yayına girince bu başlıkların altında duracak. Şimdilik kartta gördüğün durum geçerlidir: yakında.',
      ],
      steps: [
        'Oynanış adımları yayınla birlikte bu listede açılacak.',
      ],
      modes: [
        { t: 'Yakında', p: 'Bölümler oyun çıktığında burada, aynı kart düzeninde listelenecek.' },
      ],
      age: 'Yaş sınırı çıkışta',
      ageNote: 'Mağaza yaşı oyun yayınlanınca bu kutuda netleşir. Stüdyonun yayındaki oyunu 13 yaş altına yönelik değildir.',
      ads: 'later',
      adsNote: 'Reklam olup olmayacağı oyun çıkınca burada yazılacak.',
      iap: 'later',
      iapNote: 'Oyun içi satın alma olup olmayacağı oyun çıkınca burada yazılacak.',
    },
    en: {
      about: [
        'Luno Fall is the next game: letters fall, and words appear. It stays on the same line as Luno League — clear at a glance, short to play, and built around words.',
        'The full rules will sit under these same headings when the game goes live. Until then, the card status stands: soon.',
      ],
      steps: [
        'The steps will open in this list with the release.',
      ],
      modes: [
        { t: 'Soon', p: 'Modes will be listed here, in the same cards, when the game ships.' },
      ],
      age: 'Age rating at launch',
      ageNote: 'The store age will be written in this box when the game is released. The studio’s live game is not directed at children under 13.',
      ads: 'later',
      adsNote: 'Whether the game has ads will be written here at launch.',
      iap: 'later',
      iapNote: 'Whether the game has in-app purchases will be written here at launch.',
    },
  },
};
