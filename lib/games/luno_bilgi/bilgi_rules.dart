class BilgiScore {
  const BilgiScore({
    required this.points,
    required this.timeBonus,
    required this.streakBonus,
  });

  final int points;
  final int timeBonus;
  final int streakBonus;
}

int difficultyPoints(
  String difficulty, {
  int kolay = 10,
  int orta = 15,
  int zor = 25,
  int efsane = 40,
}) {
  return switch (difficulty) {
    'orta' => orta,
    'zor' => zor,
    'efsane' => efsane,
    _ => kolay,
  };
}

const bilgiMixDifficulty = 'karisik';

/// Günün Yarışması: 8 kolay, 6 orta, 4 zor, 2 efsane.
const bilgiDailyQuotas = <int>[8, 6, 4, 2];

/// Değiştir jokeri için 20 sorunun dışında: kolay, orta, zor 3; efsane 2.
const bilgiContestSpareCounts = <int>[3, 3, 3, 2];

const bilgiDifficultyLevels = ['kolay', 'orta', 'zor', 'efsane'];

/// Shares [count] across the four difficulties. The first remainder levels get one extra.
List<int> bilgiMixQuotas(int count) {
  if (count <= 0) return const [0, 0, 0, 0];
  final base = count ~/ 4;
  final extra = count % 4;
  return [for (var i = 0; i < 4; i++) base + (i < extra ? 1 : 0)];
}

int difficultySeconds(String difficulty) {
  return switch (difficulty) {
    'orta' => 15,
    'zor' => 12,
    'efsane' => 10,
    _ => 20,
  };
}

/// Zorluk puanı × katsayı + (kalan / toplam) × 5 + seri × 2 (en fazla 20).
BilgiScore scoreQuestion({
  required String difficulty,
  required double modeMultiplier,
  required int timeLeft,
  required int totalTime,
  required int streak,
  int kolay = 10,
  int orta = 15,
  int zor = 25,
  int efsane = 40,
  int timeBonusScale = 5,
}) {
  final base = (difficultyPoints(difficulty, kolay: kolay, orta: orta, zor: zor, efsane: efsane) * modeMultiplier).round();
  final time = totalTime <= 0
      ? 0
      : ((timeLeft.clamp(0, totalTime) / totalTime) * timeBonusScale).round();
  final streakBonus = (streak * 2).clamp(0, 20);
  return BilgiScore(
    points: base + time + streakBonus,
    timeBonus: time,
    streakBonus: streakBonus,
  );
}

int goldForScore(int totalScore, double modeMultiplier) {
  if (totalScore <= 0) return 0;
  return ((totalScore / 10) * modeMultiplier).floor();
}

/// Günün Yarışması: doğru başına 10 altın, tavan 200.
int bilgiContestGold(int correct) {
  if (correct <= 0) return 0;
  final gold = correct * 10;
  return gold > 200 ? 200 : gold;
}

/// Günün Yarışması: doğru başına 5 XP, tavan 100.
int bilgiContestXp(int correct) {
  if (correct <= 0) return 0;
  final xp = correct * 5;
  return xp > 100 ? 100 : xp;
}

/// `YYYY-MM` içindeki gün anahtarları. Geçersiz ay boş liste döner.
List<String> bilgiContestMonthDays(String month) {
  final parts = month.split('-');
  if (parts.length != 2) return const [];
  final year = int.tryParse(parts[0]);
  final mon = int.tryParse(parts[1]);
  if (year == null || mon == null || mon < 1 || mon > 12 || year < 2000 || year > 2100) {
    return const [];
  }
  final last = DateTime(year, mon + 1, 0).day;
  return [
    for (var day = 1; day <= last; day++)
      '$year-${mon.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
  ];
}

/// True when [message] is an existing “not enough gold” refusal.
bool bilgiNoticeIsGoldShort(String? message) {
  if (message == null || message.isEmpty) return false;
  return message.contains('Yeterli altın');
}

/// A gold source the player can open from the insufficient-gold dialog.
/// Lives refill on a timer; gold does not, so there is no wait row.
enum BilgiGoldHelpKind { ad, shop, daily }

class BilgiGoldHelpOption {
  const BilgiGoldHelpOption({
    required this.kind,
    required this.title,
    required this.subtitle,
  });

  final BilgiGoldHelpKind kind;
  final String title;
  final String subtitle;
}

/// Shop packs and the rewarded-ad grant are always listed.
/// Daily reward is listed only when today’s unclaimed payout includes gold.
List<BilgiGoldHelpOption> bilgiGoldHelpOptions({
  required int rewardedGold,
  required int shopGoldA,
  required int shopGoldB,
  required bool dailyGoldReady,
  required int dailyGold,
}) {
  final options = <BilgiGoldHelpOption>[
    BilgiGoldHelpOption(
      kind: BilgiGoldHelpKind.ad,
      title: 'Reklam izle',
      subtitle: '$rewardedGold altın',
    ),
    BilgiGoldHelpOption(
      kind: BilgiGoldHelpKind.shop,
      title: 'Altın satın al',
      subtitle: '$shopGoldA veya $shopGoldB altın',
    ),
  ];
  if (dailyGoldReady && dailyGold > 0) {
    options.add(
      BilgiGoldHelpOption(
        kind: BilgiGoldHelpKind.daily,
        title: 'Günlük ödül',
        subtitle: '$dailyGold altın',
      ),
    );
  }
  return options;
}

int xpForScore(int totalScore) {
  if (totalScore <= 0) return 0;
  return totalScore ~/ 2;
}

class LevelStep {
  const LevelStep({
    required this.level,
    required this.xp,
    required this.diamondsGained,
  });

  final int level;
  final int xp;
  final int diamondsGained;
}

LevelStep applyXp({required int level, required int xp, required int gained}) {
  var nextLevel = level;
  var nextXp = xp + gained;
  var diamonds = 0;
  while (nextXp >= 5000 && nextLevel < 100) {
    nextXp -= 5000;
    nextLevel += 1;
    if (nextLevel % 5 == 0) diamonds += 1;
  }
  if (nextLevel >= 100) {
    nextLevel = 100;
    nextXp = nextXp.clamp(0, 4999);
  }
  return LevelStep(level: nextLevel, xp: nextXp, diamondsGained: diamonds);
}

int regeneratedLives({
  required int lives,
  required DateTime livesAt,
  required DateTime now,
  int maxLives = 5,
  int minutesPerLife = 30,
}) {
  if (lives >= maxLives) return maxLives;
  final gained = now.difference(livesAt).inMinutes ~/ minutesPerLife;
  if (gained <= 0) return lives;
  return (lives + gained).clamp(0, maxLives);
}

DateTime livesClockAfterRegen({
  required int lives,
  required DateTime livesAt,
  required DateTime now,
  int maxLives = 5,
  int minutesPerLife = 30,
}) {
  if (lives >= maxLives) return now;
  final gained = now.difference(livesAt).inMinutes ~/ minutesPerLife;
  if (gained <= 0) return livesAt;
  return livesAt.add(Duration(minutes: gained * minutesPerLife));
}

String bilgiNoLivesNotice(int minutes) {
  return '❤️ Canın bitti! Yenilenmesini bekle veya satın al. ($minutes dk\'da bir can otomatik yüklenir.)';
}

/// First page after boot. Language comes before intro/home.
String bilgiBootPage({
  required bool maintenance,
  required bool localeChosen,
  required bool seenIntro,
}) {
  if (maintenance) return 'maintenance';
  if (!localeChosen) return 'language';
  if (!seenIntro) return 'intro';
  return 'home';
}

/// Shown when the explanation cannot be turned into a clue that hides the answer.
const bilgiHintWithheld = 'Bu soruda ipucu, doğru şıkkı söylemez.';

const _hintAnswerPhrases = [
  'doğru cevap',
  'dogru cevap',
  'doğru yanıt',
  'dogru yanit',
  'doğru şıkkı',
  'dogru sikki',
  'doğru şık',
  'dogru sik',
  'doğru seçenek',
  'dogru secenek',
  'correct answer',
  'right answer',
  'richtige antwort',
  'respuesta correcta',
  'bonne réponse',
  'bonne reponse',
  'risposta corretta',
  'resposta correta',
  'juiste antwoord',
  'poprawna odpowiedź',
  'poprawna odpowiedz',
  'правильный ответ',
  'cevap',
  'yanıt',
  'yanit',
  'answer',
  'antwort',
  'respuesta',
  'réponse',
  'reponse',
  'risposta',
  'resposta',
  'antwoord',
  'odpowiedź',
  'odpowiedz',
  'ответ',
];

/// One short clue from [explanation]. The correct option text, its letter, and
/// phrases that announce the answer are removed. If nothing safe remains, the
/// fixed line is returned and the answer is not stated.
String bilgiHintClue({
  required String explanation,
  required List<String> options,
  required int correct,
}) {
  final raw = explanation.trim();
  if (raw.isEmpty) return bilgiHintWithheld;
  final answer = (correct >= 0 && correct < options.length) ? options[correct].trim() : '';
  final letter = (correct >= 0 && correct <= 3) ? ['A', 'B', 'C', 'D'][correct] : '';
  var text = raw;
  for (final phrase in _hintAnswerPhrases) {
    text = _removeHintToken(text, phrase, gluedSuffix: true);
  }
  if (answer.isNotEmpty) {
    text = _removeHintToken(text, answer, apostropheSuffix: true);
  }
  text = _stripHintLetter(text, letter);
  for (final part in text.split(RegExp(r'[.!?…\n]+'))) {
    final sentence = _tidyHintSentence(part);
    if (sentence.isEmpty) continue;
    if (_hintLetterCount(sentence) < 8) continue;
    if (_hintLeaks(sentence, answer, letter)) continue;
    return _shortHintSentence(sentence);
  }
  return bilgiHintWithheld;
}

String _stripHintLetter(String text, String letter) {
  final mark = letter.trim().toUpperCase();
  if (mark.length != 1) return text;
  var next = text;
  for (final form in ['($mark)', '$mark)', '$mark.', '$mark:', '$mark-']) {
    next = _removeHintToken(next, form);
  }
  for (final prefix in ['şıkkı', 'sikki', 'seçenek', 'secenek', 'şık', 'sik', 'option']) {
    next = _removeHintToken(next, '$prefix $mark');
    next = _removeHintToken(next, '$mark $prefix', gluedSuffix: true);
  }
  return _removeHintToken(next, mark);
}

String _removeHintToken(
  String text,
  String token, {
  bool gluedSuffix = false,
  bool apostropheSuffix = false,
}) {
  final needle = token.trim();
  if (needle.isEmpty || text.isEmpty) return text;
  final foldedNeedle = _hintLoose(needle);
  if (foldedNeedle.isEmpty) return text;
  final buffer = StringBuffer();
  var i = 0;
  while (i < text.length) {
    final folded = _hintLoose(text);
    final at = folded.indexOf(foldedNeedle, i);
    if (at < 0) {
      buffer.write(text.substring(i));
      break;
    }
    final beforeOk = at == 0 || !_hintTokenChar(text[at - 1]);
    var end = at + foldedNeedle.length;
    if (end > text.length) end = text.length;
    if (beforeOk) {
      if (apostropheSuffix && end < text.length && _hintApostrophe(text[end])) {
        end++;
        while (end < text.length && _hintLetter(text[end])) {
          end++;
        }
      } else if (gluedSuffix) {
        while (end < text.length && _hintLetter(text[end])) {
          end++;
        }
      }
      final afterOk = end >= text.length || !_hintTokenChar(text[end]);
      if (afterOk) {
        buffer.write(text.substring(i, at));
        i = end;
        continue;
      }
    }
    final step = at + 1;
    buffer.write(text.substring(i, step > text.length ? text.length : step));
    i = step > text.length ? text.length : step;
  }
  return buffer.toString();
}

String _tidyHintSentence(String raw) {
  var text = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'''^[\s,;:.\-–—|/\\'"“”‘’()\[\]·•]+'''), '');
  text = text.replaceAll(RegExp(r'''[\s,;:.\-–—|/\\'"“”‘’()\[\]·•]+$'''), '');
  text = text.replaceFirst(
    RegExp("^(?:dır|dir|dur|dür|tır|tir|tur|tür)\\b", caseSensitive: false),
    '',
  );
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  text = text.replaceAll(RegExp(r'\s+([,;:])'), r'$1');
  text = text.replaceAll(RegExp(r'([(\[])\s+'), r'$1');
  text = text.replaceAll(RegExp(r'\(\s*\)'), '');
  text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  if (text.isEmpty) return '';
  final sentence = _hintUpperFirst(text);
  if (RegExp(r'[.!?…]$').hasMatch(sentence)) return sentence;
  return '$sentence.';
}

String _shortHintSentence(String sentence) {
  if (sentence.length <= 180) return sentence;
  final cut = sentence.lastIndexOf(' ', 160);
  final end = cut >= 40 ? cut : 160;
  return sentence.substring(0, end).trim();
}

bool _hintLeaks(String text, String answer, String letter) {
  final foldedAnswer = _hintLoose(answer.trim());
  if (foldedAnswer.isNotEmpty) {
    final folded = _hintLoose(text);
    final named = foldedAnswer.length >= 4
        ? folded.contains(foldedAnswer)
        : _hintHasToken(folded, foldedAnswer);
    if (named) return true;
  }
  final mark = letter.trim();
  if (mark.length == 1 && _hintHasToken(_hintLoose(text), _hintLoose(mark))) return true;
  return false;
}

bool _hintHasToken(String foldedText, String foldedNeedle) {
  if (foldedNeedle.isEmpty) return false;
  var start = 0;
  while (start < foldedText.length) {
    final at = foldedText.indexOf(foldedNeedle, start);
    if (at < 0) return false;
    final beforeOk = at == 0 || !_hintTokenChar(foldedText[at - 1]);
    final end = at + foldedNeedle.length;
    final afterOk = end >= foldedText.length || !_hintTokenChar(foldedText[end]);
    if (beforeOk && afterOk) return true;
    start = at + 1;
  }
  return false;
}

int _hintLetterCount(String text) {
  var count = 0;
  for (var i = 0; i < text.length; i++) {
    if (_hintLetter(text[i])) count++;
  }
  return count;
}

String _hintUpperFirst(String text) {
  if (text.isEmpty) return text;
  final first = text[0];
  final upper = switch (first) {
    'i' => 'İ',
    'ı' => 'I',
    'ş' => 'Ş',
    'ğ' => 'Ğ',
    'ü' => 'Ü',
    'ö' => 'Ö',
    'ç' => 'Ç',
    _ => first.toUpperCase().length == 1 ? first.toUpperCase() : first,
  };
  if (upper == first) return text;
  return upper + text.substring(1);
}

String _hintLoose(String input) {
  final out = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    out.write(_hintLooseChar(input[i]));
  }
  return out.toString();
}

String _hintLooseChar(String ch) {
  switch (ch) {
    case 'İ':
    case 'I':
    case 'ı':
    case 'i':
      return 'i';
    case 'Ş':
    case 'ş':
      return 'ş';
    case 'Ğ':
    case 'ğ':
      return 'ğ';
    case 'Ü':
    case 'ü':
      return 'ü';
    case 'Ö':
    case 'ö':
      return 'ö';
    case 'Ç':
    case 'ç':
      return 'ç';
    default:
      final lower = ch.toLowerCase();
      return lower.length == 1 ? lower : ch;
  }
}

bool _hintLetter(String ch) {
  if (ch.isEmpty) return false;
  final loose = _hintLooseChar(ch);
  final code = loose.codeUnitAt(0);
  if (code >= 0x61 && code <= 0x7a) return true;
  return 'çğıöşü'.contains(loose);
}

bool _hintTokenChar(String ch) {
  if (_hintLetter(ch)) return true;
  if (ch.isEmpty) return false;
  final code = ch.codeUnitAt(0);
  return code >= 0x30 && code <= 0x39;
}

bool _hintApostrophe(String ch) => ch == "'" || ch == '’' || ch == '‘' || ch == '`';
