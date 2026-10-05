import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/domain/account/luno_account.dart';
import 'package:kelimelig/domain/game/game_ids.dart';

const bilgiApproveBlocked = 'Onay için seçili dillerde soru, dört şık ve açıklama dolu olmalı.';

/// Liste kaydı çeviriyi taşımaz. Onay, gönderilen boş çevirinin yerine kayıtlı metni kullanır.
String bilgiApproveTranslationsJson({
  required bool keepStored,
  required String submitted,
  String? stored,
}) {
  if (!keepStored) return submitted;
  final kept = stored?.trim() ?? '';
  if (kept.isEmpty) return submitted;
  return kept;
}
const bilgiCategoryBlocked = 'Kategori seçili dillerde adlandırılmadan açılamaz.';
const bilgiSubBlocked = 'Alt kategori seçili dillerde adlandırılmadan açılamaz.';

bool bilgiLanguageFieldsReady(String text, List<String> options, String explanation) {
  if (text.trim().isEmpty || explanation.trim().isEmpty) return false;
  return options.length == 4 && options.every((item) => item.trim().isNotEmpty);
}

/// Yayın listesindeki Türkçe dışındaki diller. null veya boş: dokuz dil.
List<String> bilgiExtraLocales(List<String>? locales) {
  if (locales == null || locales.isEmpty) {
    return [for (final locale in GameLocale.all) if (locale.id != 'tr') locale.id];
  }
  return [for (final locale in GameLocale.all) if (locale.id != 'tr' && locales.contains(locale.id)) locale.id];
}

/// Onay, kategorinin işaretli dillerinde soru, şık ve açıklama doluyken verilir.
/// [locales] boş veya verilmezse on dil istenir (eski kategori).
bool bilgiQuestionLanguagesReady(BilgiQuestion question, {List<String>? locales}) {
  if (!bilgiLanguageFieldsReady(question.text, question.options, question.explanation)) return false;
  for (final id in bilgiExtraLocales(locales)) {
    final row = question.translations[id];
    if (row == null || !bilgiLanguageFieldsReady(row.text, row.options, row.explanation)) return false;
  }
  return true;
}

/// Onay Bekleyenler: yalnızca bekleyen ve seçili dilleri dolu sorular.
bool bilgiPendingApprovalReady(BilgiQuestion question, {List<String>? locales}) =>
    question.status == 'pending' && bilgiQuestionLanguagesReady(question, locales: locales);

/// Admin list approve/reject: persist `approved` or `rejected` (and clear reject reason on approve).
BilgiQuestion bilgiQuestionWithReviewStatus(BilgiQuestion question, String status) {
  return question.copyWith(
    status: status,
    rejectReason: status == 'rejected' ? 'Reddedildi' : '',
  );
}

/// Türkçe ad kaydın kendisidir. İşaretli diğer dillerin görünen adı dolu olmalıdır.
/// [locales] boş veya verilmezse dokuz dil istenir (eski kategori).
bool bilgiNamesReady(Map<String, String> labels, String scope, String key, {List<String>? locales}) {
  for (final id in bilgiExtraLocales(locales)) {
    if ((labels['$id|$scope|$key'] ?? '').trim().isEmpty) return false;
  }
  return true;
}

/// Türkçe ve her çeviri dört şık taşıyorsa harf kaydırılabilir.
bool bilgiLettersRotatable(BilgiQuestion question) {
  if (question.options.length != 4) return false;
  if (question.correct < 0 || question.correct > 3) return false;
  for (final row in question.translations.values) {
    if (row.options.length != 4) return false;
  }
  return true;
}

/// Doğru cümleyi [to] harfine alır. Aynı dönüş her dilin şık listesine uygulanır.
/// Metin, açıklama ve durum değişmez. Dört şık yoksa null.
BilgiQuestion? bilgiMoveCorrectOption(BilgiQuestion question, int to) {
  if (!bilgiLettersRotatable(question) || to < 0 || to > 3) return null;
  final from = question.correct;
  if (from == to) return question;
  final shift = (to - from) % 4;
  final delta = shift < 0 ? shift + 4 : shift;
  List<String> turn(List<String> options) {
    final next = List<String>.filled(4, '');
    for (var i = 0; i < 4; i++) {
      next[(i + delta) % 4] = options[i];
    }
    return next;
  }

  return question.copyWith(
    options: turn(question.options),
    correct: to,
    translations: {
      for (final entry in question.translations.entries)
        entry.key: BilgiTranslation(
          text: entry.value.text,
          options: turn(entry.value.options),
          explanation: entry.value.explanation,
        ),
    },
  );
}

/// Her alt kategoride doğru harf yaklaşık dörtte bir olsun. Değişen soruları döner.
/// Etiketi olmayan sorular, kategorinin etiketsiz kümesinde dengelenir.
List<BilgiQuestion> bilgiBalanceAnswerLetters(Iterable<BilgiQuestion> questions) {
  final latest = <String, BilgiQuestion>{for (final question in questions) question.id: question};
  final groups = <String, List<String>>{};
  for (final question in questions) {
    final tags = [for (final tag in question.tags) if (tag.trim().isNotEmpty) tag.trim()];
    final keys = tags.isEmpty ? ['${question.categoryId}|'] : [for (final tag in tags) '${question.categoryId}|$tag'];
    for (final key in keys) {
      groups.putIfAbsent(key, () => []).add(question.id);
    }
  }
  final changed = <String, BilgiQuestion>{};
  for (final ids in groups.values) {
    for (final moved in _balanceLetterGroup([for (final id in ids) latest[id]!])) {
      latest[moved.id] = moved;
      changed[moved.id] = moved;
    }
  }
  return changed.values.toList();
}

List<BilgiQuestion> _balanceLetterGroup(List<BilgiQuestion> group) {
  final total = group.length;
  final base = total ~/ 4;
  final extra = total % 4;
  final need = [for (var i = 0; i < 4; i++) base + (i < extra ? 1 : 0)];
  for (final question in group) {
    need[question.correct.clamp(0, 3)] -= 1;
  }
  final changed = <BilgiQuestion>[];
  for (final question in group) {
    if (!bilgiLettersRotatable(question)) continue;
    final from = question.correct;
    if (need[from] >= 0) continue;
    var to = -1;
    for (var i = 0; i < 4; i++) {
      if (need[i] > 0) {
        to = i;
        break;
      }
    }
    if (to < 0) continue;
    final moved = bilgiMoveCorrectOption(question, to);
    if (moved == null) continue;
    changed.add(moved);
    need[from] += 1;
    need[to] -= 1;
  }
  return changed;
}

class BilgiQuestion {
  const BilgiQuestion({
    required this.id,
    required this.categoryId,
    required this.text,
    required this.options,
    required this.correct,
    required this.difficulty,
    required this.explanation,
    this.status = 'approved',
    this.tags = const [],
    this.rejectReason = '',
    this.translations = const {},
    this.reviewed = false,
  });

  final String id;
  final String categoryId;
  final String text;
  final List<String> options;
  final int correct;
  final String difficulty;
  final String explanation;
  final String status;
  final List<String> tags;
  final String rejectReason;
  final Map<String, BilgiTranslation> translations;

  /// Admin marks a question reviewed by hand. Missing keys stay unchecked.
  final bool reviewed;

  /// Same question, words for [locale]. Empty text falls back to Turkish.
  BilgiQuestion shown(String locale) {
    if (locale.isEmpty || locale == 'tr') return this;
    final row = translations[locale];
    if (row == null || row.text.trim().isEmpty) return this;
    if (row.options.length != 4 || row.options.any((item) => item.trim().isEmpty)) return this;
    return copyWith(text: row.text, options: row.options, explanation: row.explanation);
  }

  String get correctLetter => ['A', 'B', 'C', 'D'][correct.clamp(0, 3)];

  Map<String, dynamic> toMap() => {
        'id': id,
        'categoryId': categoryId,
        'text': text,
        'options': options,
        'correct': correct,
        'difficulty': difficulty,
        'explanation': explanation,
        'status': status,
        'tags': tags,
        'rejectReason': rejectReason,
        'reviewed': reviewed,
        if (translations.isNotEmpty)
          'translations': {for (final entry in translations.entries) entry.key: entry.value.toMap()},
      };

  factory BilgiQuestion.fromMap(Map<String, dynamic> map) {
    return BilgiQuestion(
      id: map['id'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      options: (map['options'] as List? ?? const []).map((e) => '$e').toList(),
      correct: map['correct'] as int? ?? 0,
      difficulty: map['difficulty'] as String? ?? 'kolay',
      explanation: map['explanation'] as String? ?? '',
      status: map['status'] as String? ?? 'approved',
      tags: (map['tags'] as List? ?? const []).map((e) => '$e').toList(),
      rejectReason: map['rejectReason'] as String? ?? '',
      translations: BilgiTranslation.mapFrom(map['translations']),
      reviewed: map['reviewed'] == true,
    );
  }

  BilgiQuestion copyWith({
    String? categoryId,
    String? text,
    List<String>? options,
    int? correct,
    String? difficulty,
    String? explanation,
    String? status,
    String? rejectReason,
    List<String>? tags,
    Map<String, BilgiTranslation>? translations,
    bool? reviewed,
  }) {
    return BilgiQuestion(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      text: text ?? this.text,
      options: options ?? this.options,
      correct: correct ?? this.correct,
      difficulty: difficulty ?? this.difficulty,
      explanation: explanation ?? this.explanation,
      status: status ?? this.status,
      tags: tags ?? this.tags,
      rejectReason: rejectReason ?? this.rejectReason,
      translations: translations ?? this.translations,
      reviewed: reviewed ?? this.reviewed,
    );
  }
}

class BilgiTranslation {
  const BilgiTranslation({required this.text, required this.options, this.explanation = ''});

  final String text;
  final List<String> options;
  final String explanation;

  Map<String, dynamic> toMap() => {
        'text': text,
        'options': options,
        'explanation': explanation,
      };

  static BilgiTranslation? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final text = '${raw['text'] ?? ''}'.trim();
    final options = (raw['options'] as List? ?? const []).map((item) => '$item').toList();
    if (text.isEmpty || options.length != 4) return null;
    return BilgiTranslation(
      text: text,
      options: options,
      explanation: '${raw['explanation'] ?? ''}',
    );
  }

  static Map<String, BilgiTranslation> mapFrom(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, BilgiTranslation>{};
    for (final entry in raw.entries) {
      final row = fromMap(entry.value);
      if (row == null) continue;
      out['${entry.key}'] = row;
    }
    return out;
  }
}

bool _sameTranslations(Map<String, BilgiTranslation> a, Map<String, BilgiTranslation> b) {
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || other.text != entry.value.text || other.explanation != entry.value.explanation) return false;
    if (!_sameStrings(other.options, entry.value.options)) return false;
  }
  return true;
}

bool sameStoredBilgiQuestion(BilgiQuestion saved, BilgiQuestion wanted) {
  return saved.id == wanted.id &&
      saved.categoryId == wanted.categoryId &&
      saved.text == wanted.text &&
      _sameStrings(saved.options, wanted.options) &&
      saved.correct == wanted.correct &&
      saved.difficulty == wanted.difficulty &&
      saved.explanation == wanted.explanation &&
      saved.status == wanted.status &&
      _sameStrings(saved.tags, wanted.tags) &&
      saved.rejectReason == wanted.rejectReason &&
      saved.reviewed == wanted.reviewed &&
      _sameTranslations(saved.translations, wanted.translations);
}

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Admin edit form snapshot: stored question fields mapped onto the editor.
class BilgiQuestionFormData {
  const BilgiQuestionFormData({
    required this.id,
    required this.text,
    required this.options,
    required this.correct,
    required this.categoryId,
    required this.subcategory,
    required this.difficulty,
    required this.explanation,
    required this.tags,
    required this.status,
    this.translations = const {},
    this.reviewed = false,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correct;
  final String categoryId;
  final String subcategory;
  final String difficulty;
  final String explanation;
  final List<String> tags;
  final String status;
  final Map<String, BilgiTranslation> translations;
  final bool reviewed;

  factory BilgiQuestionFormData.fromQuestion(
    BilgiQuestion question, {
    Iterable<String> categorySubs = const [],
  }) {
    var sub = '';
    for (final tag in question.tags) {
      if (categorySubs.contains(tag)) {
        sub = tag;
        break;
      }
    }
    return BilgiQuestionFormData(
      id: question.id,
      text: question.text,
      options: [
        for (var i = 0; i < 4; i++) i < question.options.length ? question.options[i] : '',
      ],
      correct: question.correct.clamp(0, 3),
      categoryId: question.categoryId,
      subcategory: sub,
      difficulty: question.difficulty,
      explanation: question.explanation,
      tags: [for (final tag in question.tags) if (tag.isNotEmpty && tag != sub) tag],
      status: question.status,
      translations: question.translations,
      reviewed: question.reviewed,
    );
  }

  BilgiQuestion toQuestion({required bool asDraft, String? rejectReason}) {
    return BilgiQuestion(
      id: id,
      categoryId: categoryId,
      text: text,
      options: options,
      correct: correct,
      difficulty: difficulty,
      explanation: explanation,
      status: asDraft ? 'draft' : (status.isEmpty ? 'pending' : status),
      tags: [if (subcategory.isNotEmpty) subcategory, ...tags],
      rejectReason: rejectReason ?? '',
      reviewed: reviewed,
    );
  }
}

class BilgiCategoryPoints {
  const BilgiCategoryPoints({this.total = 0, this.week = 0});

  final int total;
  final int week;

  Map<String, dynamic> toMap() => {'total': total, 'week': week};
}

Map<String, BilgiCategoryPoints> bilgiCategoryPointsFrom(Object? raw) {
  if (raw is! Map) return const {};
  final out = <String, BilgiCategoryPoints>{};
  for (final entry in raw.entries) {
    final value = entry.value;
    if (value is! Map) continue;
    out['${entry.key}'] = BilgiCategoryPoints(
      total: bilgiInt(value['total'], 0),
      week: bilgiInt(value['week'], 0),
    );
  }
  return out;
}

Map<String, int> bilgiIntMapFrom(Object? raw) {
  if (raw is! Map) return const {};
  return {
    for (final entry in raw.entries) '${entry.key}': bilgiInt(entry.value, 0),
  };
}

/// Trim and collapse spaces. Case is compared separately so "Avatar" and "avatar" collide.
String bilgiUsernameNormalized(String raw) => raw.trim().replaceAll(RegExp(r'\s+'), ' ');

/// Thrown when a profile save would store a username another user id already has.
class BilgiUsernameTaken implements Exception {
  const BilgiUsernameTaken();
}

/// True when [name] is already stored on a different user id.
/// An empty name matches nobody, including other empty names.
bool bilgiUsernameTaken(Iterable<Map<String, dynamic>> rows, String name, {required String exceptId}) {
  final key = bilgiUsernameNormalized(name).toLowerCase();
  if (key.isEmpty) return false;
  for (final row in rows) {
    if ('${row['id'] ?? ''}' == exceptId) continue;
    final existing = bilgiUsernameNormalized('${row['username'] ?? ''}').toLowerCase();
    if (existing.isNotEmpty && existing == key) return true;
  }
  return false;
}

/// A user may save the name they already have. A different name must be free.
bool bilgiUsernameChangeTaken(
  Iterable<Map<String, dynamic>> rows, {
  required String nextName,
  required String currentName,
  required String exceptId,
}) {
  final next = bilgiUsernameNormalized(nextName).toLowerCase();
  final current = bilgiUsernameNormalized(currentName).toLowerCase();
  if (next.isEmpty || next == current) return false;
  return bilgiUsernameTaken(rows, nextName, exceptId: exceptId);
}

class BilgiProfile {
  const BilgiProfile({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.avatar,
    required this.level,
    required this.xp,
    required this.gold,
    required this.diamond,
    required this.lives,
    required this.livesAt,
    required this.title,
    required this.premium,
    required this.premiumUntil,
    required this.banned,
    required this.banReason,
    required this.city,
    required this.createdAt,
    required this.jokers,
    required this.gamesPlayed,
    required this.correctTotal,
    required this.bestScore,
    required this.totalScore,
    required this.streak,
    required this.lastReward,
    required this.rewardDay,
    required this.lastPlayDay,
    required this.freePlaysUsed,
    required this.adFreeLeft,
    required this.inviteCode,
    required this.invites,
    required this.friends,
    required this.badges,
    required this.duelWins,
    required this.categoriesPlayed,
    required this.adGoldToday,
    required this.adJokerToday,
    required this.adLifeToday,
    required this.adDoubleToday,
    required this.adDay,
    required this.weekId,
    required this.weekScore,
    this.categoryScores = const {},
    this.heldWeekId = '',
    this.heldWeekScore = 0,
    this.heldCategoryWeeks = const {},
    this.leagueRewardWeek = '',
    this.leagueRewardText = '',
    this.locale = 'tr',
    this.localeChosen = false,
    this.accountId,
    this.accountFirstGame,
    this.accountGames = const [],
    this.accountCreatedAt,
    this.guestHere = false,
  });

  final String id;
  final String username;
  final String email;
  final String passwordHash;
  final String avatar;
  final int level;
  final int xp;
  final int gold;
  final int diamond;
  final int lives;
  final DateTime livesAt;
  final String title;
  final bool premium;
  final DateTime? premiumUntil;
  final bool banned;
  final String banReason;
  final String city;
  final DateTime createdAt;
  final Map<String, int> jokers;
  final int gamesPlayed;
  final int correctTotal;
  final int bestScore;
  final int totalScore;
  final int streak;
  final String lastReward;
  final int rewardDay;
  final String lastPlayDay;
  final int freePlaysUsed;
  final int adFreeLeft;
  final String inviteCode;
  final int invites;
  final List<String> friends;
  final List<String> badges;
  final int duelWins;
  final List<String> categoriesPlayed;
  final int adGoldToday;
  final int adJokerToday;
  final int adLifeToday;
  final int adDoubleToday;
  final String adDay;
  final String weekId;
  final int weekScore;
  final Map<String, BilgiCategoryPoints> categoryScores;
  final String heldWeekId;
  final int heldWeekScore;
  final Map<String, int> heldCategoryWeeks;
  final String leagueRewardWeek;
  final String leagueRewardText;
  final String locale;
  final bool localeChosen;
  final String? accountId;
  final String? accountFirstGame;
  final List<String> accountGames;
  final DateTime? accountCreatedAt;
  final bool guestHere;

  bool rewardReady(String today, String yesterday) {
    if (lastReward == today) return false;
    return true;
  }

  int nextRewardIndex(String today, String yesterday) {
    if (lastReward == today || lastReward == yesterday) return rewardDay % 7;
    return 0;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'email': email,
        'passwordHash': passwordHash,
        'avatar': avatar,
        'level': level,
        'xp': xp,
        'gold': gold,
        'diamond': diamond,
        'lives': lives,
        'livesAt': livesAt.toIso8601String(),
        'title': title,
        'premium': premium,
        'premiumUntil': premiumUntil?.toIso8601String(),
        'banned': banned,
        'banReason': banReason,
        'city': city,
        'createdAt': createdAt.toIso8601String(),
        'jokers': jokers,
        'gamesPlayed': gamesPlayed,
        'correctTotal': correctTotal,
        'bestScore': bestScore,
        'totalScore': totalScore,
        'streak': streak,
        'lastReward': lastReward,
        'rewardDay': rewardDay,
        'lastPlayDay': lastPlayDay,
        'freePlaysUsed': freePlaysUsed,
        'adFreeLeft': adFreeLeft,
        'inviteCode': inviteCode,
        'invites': invites,
        'friends': friends,
        'badges': badges,
        'duelWins': duelWins,
        'categoriesPlayed': categoriesPlayed,
        'adGoldToday': adGoldToday,
        'adJokerToday': adJokerToday,
        'adLifeToday': adLifeToday,
        'adDoubleToday': adDoubleToday,
        'adDay': adDay,
        'weekId': weekId,
        'weekScore': weekScore,
        'categoryScores': {
          for (final entry in categoryScores.entries) entry.key: entry.value.toMap(),
        },
        'heldWeekId': heldWeekId,
        'heldWeekScore': heldWeekScore,
        'heldCategoryWeeks': heldCategoryWeeks,
        'leagueRewardWeek': leagueRewardWeek,
        'leagueRewardText': leagueRewardText,
        'locale': locale,
        'localeChosen': localeChosen,
        'accountId': accountId,
        'accountFirstGame': accountFirstGame,
        'accountGames': accountGames,
        'accountCreatedAt': accountCreatedAt?.toIso8601String(),
        'guestHere': guestHere,
      };

  /// Admin/API payload without credentials.
  Map<String, dynamic> toPublicMap() {
    final map = toMap();
    map.remove('passwordHash');
    return map;
  }

  factory BilgiProfile.fromMap(Map<String, dynamic> map) {
    return BilgiProfile(
      id: map['id'] as String? ?? 'me',
      username: map['username'] as String? ?? 'Oyuncu',
      email: map['email'] as String? ?? '',
      passwordHash: map['passwordHash'] as String? ?? '',
      avatar: map['avatar'] as String? ?? '😎',
      level: map['level'] as int? ?? 1,
      xp: map['xp'] as int? ?? 0,
      gold: map['gold'] as int? ?? 500,
      diamond: map['diamond'] as int? ?? 0,
      lives: bilgiInt(map['lives'], 5),
      livesAt: DateTime.tryParse(map['livesAt'] as String? ?? '') ?? DateTime.now(),
      title: map['title'] as String? ?? 'Çaylak',
      premium: map['premium'] as bool? ?? false,
      premiumUntil: DateTime.tryParse(map['premiumUntil'] as String? ?? ''),
      banned: map['banned'] as bool? ?? false,
      banReason: map['banReason'] as String? ?? '',
      city: map['city'] as String? ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
      jokers: {
        for (final entry in ((map['jokers'] as Map?) ?? const {}).entries)
          entry.key.toString(): bilgiInt(entry.value, 0),
      },
      gamesPlayed: map['gamesPlayed'] as int? ?? 0,
      correctTotal: map['correctTotal'] as int? ?? 0,
      bestScore: map['bestScore'] as int? ?? 0,
      totalScore: map['totalScore'] as int? ?? 0,
      streak: map['streak'] as int? ?? 0,
      lastReward: map['lastReward'] as String? ?? '',
      rewardDay: map['rewardDay'] as int? ?? 0,
      lastPlayDay: map['lastPlayDay'] as String? ?? '',
      freePlaysUsed: map['freePlaysUsed'] as int? ?? 0,
      adFreeLeft: map['adFreeLeft'] as int? ?? 3,
      inviteCode: map['inviteCode'] as String? ?? '',
      invites: map['invites'] as int? ?? 0,
      friends: (map['friends'] as List? ?? const []).map((e) => '$e').toList(),
      badges: (map['badges'] as List? ?? const []).map((e) => '$e').toList(),
      duelWins: map['duelWins'] as int? ?? 0,
      categoriesPlayed: (map['categoriesPlayed'] as List? ?? const []).map((e) => '$e').toList(),
      adGoldToday: map['adGoldToday'] as int? ?? 0,
      adJokerToday: map['adJokerToday'] as int? ?? 0,
      adLifeToday: map['adLifeToday'] as int? ?? 0,
      adDoubleToday: map['adDoubleToday'] as int? ?? 0,
      adDay: map['adDay'] as String? ?? '',
      weekId: map['weekId'] as String? ?? '',
      weekScore: map['weekScore'] as int? ?? 0,
      categoryScores: bilgiCategoryPointsFrom(map['categoryScores']),
      heldWeekId: map['heldWeekId'] as String? ?? '',
      heldWeekScore: map['heldWeekScore'] as int? ?? 0,
      heldCategoryWeeks: bilgiIntMapFrom(map['heldCategoryWeeks']),
      leagueRewardWeek: map['leagueRewardWeek'] as String? ?? '',
      leagueRewardText: map['leagueRewardText'] as String? ?? '',
      locale: map['locale'] as String? ?? 'tr',
      localeChosen: map['localeChosen'] as bool? ?? false,
      accountId: map['accountId'] as String?,
      accountCreatedAt: DateTime.tryParse('${map['accountCreatedAt'] ?? ''}'),
      accountFirstGame: map['accountFirstGame'] as String?,
      accountGames: [
        for (final item in map['accountGames'] as List? ?? const [])
          if ('$item'.isNotEmpty) '$item',
      ],
      guestHere: map['guestHere'] as bool? ?? false,
    );
  }

  BilgiProfile copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    String? avatar,
    int? level,
    int? xp,
    int? gold,
    int? diamond,
    int? lives,
    DateTime? livesAt,
    String? title,
    bool? premium,
    DateTime? premiumUntil,
    bool clearPremiumUntil = false,
    bool? banned,
    String? banReason,
    String? city,
    Map<String, int>? jokers,
    int? gamesPlayed,
    int? correctTotal,
    int? bestScore,
    int? totalScore,
    int? streak,
    String? lastReward,
    int? rewardDay,
    String? lastPlayDay,
    int? freePlaysUsed,
    int? adFreeLeft,
    String? inviteCode,
    int? invites,
    List<String>? friends,
    List<String>? badges,
    int? duelWins,
    List<String>? categoriesPlayed,
    int? adGoldToday,
    int? adJokerToday,
    int? adLifeToday,
    int? adDoubleToday,
    String? adDay,
    String? weekId,
    int? weekScore,
    Map<String, BilgiCategoryPoints>? categoryScores,
    String? heldWeekId,
    int? heldWeekScore,
    Map<String, int>? heldCategoryWeeks,
    String? leagueRewardWeek,
    String? leagueRewardText,
    String? locale,
    bool? localeChosen,
    String? accountId,
    String? accountFirstGame,
    List<String>? accountGames,
    DateTime? accountCreatedAt,
    bool? guestHere,
  }) {
    return BilgiProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      avatar: avatar ?? this.avatar,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      gold: gold ?? this.gold,
      diamond: diamond ?? this.diamond,
      lives: lives ?? this.lives,
      livesAt: livesAt ?? this.livesAt,
      title: title ?? this.title,
      premium: premium ?? this.premium,
      premiumUntil: clearPremiumUntil ? null : premiumUntil ?? this.premiumUntil,
      banned: banned ?? this.banned,
      banReason: banReason ?? this.banReason,
      city: city ?? this.city,
      createdAt: createdAt,
      jokers: jokers ?? this.jokers,
      gamesPlayed: gamesPlayed ?? this.gamesPlayed,
      correctTotal: correctTotal ?? this.correctTotal,
      bestScore: bestScore ?? this.bestScore,
      totalScore: totalScore ?? this.totalScore,
      streak: streak ?? this.streak,
      lastReward: lastReward ?? this.lastReward,
      rewardDay: rewardDay ?? this.rewardDay,
      lastPlayDay: lastPlayDay ?? this.lastPlayDay,
      freePlaysUsed: freePlaysUsed ?? this.freePlaysUsed,
      adFreeLeft: adFreeLeft ?? this.adFreeLeft,
      inviteCode: inviteCode ?? this.inviteCode,
      invites: invites ?? this.invites,
      friends: friends ?? this.friends,
      badges: badges ?? this.badges,
      duelWins: duelWins ?? this.duelWins,
      categoriesPlayed: categoriesPlayed ?? this.categoriesPlayed,
      adGoldToday: adGoldToday ?? this.adGoldToday,
      adJokerToday: adJokerToday ?? this.adJokerToday,
      adLifeToday: adLifeToday ?? this.adLifeToday,
      adDoubleToday: adDoubleToday ?? this.adDoubleToday,
      adDay: adDay ?? this.adDay,
      weekId: weekId ?? this.weekId,
      weekScore: weekScore ?? this.weekScore,
      categoryScores: categoryScores ?? this.categoryScores,
      heldWeekId: heldWeekId ?? this.heldWeekId,
      heldWeekScore: heldWeekScore ?? this.heldWeekScore,
      heldCategoryWeeks: heldCategoryWeeks ?? this.heldCategoryWeeks,
      leagueRewardWeek: leagueRewardWeek ?? this.leagueRewardWeek,
      leagueRewardText: leagueRewardText ?? this.leagueRewardText,
      locale: locale ?? this.locale,
      localeChosen: localeChosen ?? this.localeChosen,
      accountId: accountId ?? this.accountId,
      accountFirstGame: accountFirstGame ?? this.accountFirstGame,
      accountGames: accountGames ?? this.accountGames,
      accountCreatedAt: accountCreatedAt ?? this.accountCreatedAt,
      guestHere: guestHere ?? this.guestHere,
    );
  }
}

/// Registered profiles, device guests, and shared accounts that have not entered this game.
/// A device guest is listed with [BilgiProfile.guestHere] so admin can open the wallet.
List<BilgiProfile> annotateBilgiAccounts(List<BilgiProfile> profiles, List<LunoAccount> accounts) {
  final byId = {for (final account in accounts) account.id: account};
  final byEmail = {
    for (final account in accounts)
      if (account.email.isNotEmpty) account.email: account,
  };
  final out = <BilgiProfile>[];
  final seen = <String>{};
  for (final user in profiles) {
    if (user.email.trim().isEmpty && user.passwordHash.isEmpty && (user.accountId == null || user.accountId!.isEmpty)) {
      out.add(user.copyWith(guestHere: true));
      continue;
    }
    final account = (user.accountId == null ? null : byId[user.accountId]) ??
        (user.email.trim().isEmpty ? null : byEmail[user.email.trim().toLowerCase()]);
    if (account == null) {
      out.add(user);
      continue;
    }
    seen.add(account.id);
    final here = account.activatedGames.contains(GameIds.lunoBilgi);
    out.add(
      user.copyWith(
        accountId: account.id,
        accountFirstGame: account.firstGameId,
        accountGames: account.activatedGames,
        accountCreatedAt: account.createdAt,
        guestHere: !here,
      ),
    );
  }
  for (final account in accounts) {
    if (seen.contains(account.id) || account.activatedGames.contains(GameIds.lunoBilgi)) continue;
    out.add(
      BilgiProfile.fromMap({
        'id': account.id,
        'username': account.displayName.isEmpty ? 'Misafir' : account.displayName,
        'email': account.email,
        'gold': 0,
        'lives': 0,
        'createdAt': account.createdAt.toIso8601String(),
        'accountId': account.id,
        'accountFirstGame': account.firstGameId,
        'accountGames': account.activatedGames,
        'accountCreatedAt': account.createdAt.toIso8601String(),
        'guestHere': true,
      }),
    );
  }
  return out;
}

class BilgiMode {
  const BilgiMode({
    required this.id,
    required this.name,
    required this.emoji,
    required this.blurb,
    required this.questions,
    required this.seconds,
    required this.totalSeconds,
    required this.multiplier,
    required this.lifeCost,
    required this.jokerMax,
    required this.group,
  });

  final String id;
  final String name;
  final String emoji;
  final String blurb;
  final int questions;
  final int seconds;
  final int totalSeconds;
  final double multiplier;
  final int lifeCost;
  final int jokerMax;
  final String group;
}

const bilgiModes = <BilgiMode>[
  BilgiMode(id: 'hizli', name: 'Hızlı Tur', emoji: '⚡', blurb: '10 soru • 15 sn • 1.5x puan', questions: 10, seconds: 15, totalSeconds: 0, multiplier: 1.5, lifeCost: 1, jokerMax: 3, group: 'solo'),
  BilgiMode(id: 'klasik', name: 'Klasik Tur', emoji: '🎯', blurb: '20 soru • 20 sn • 1x puan', questions: 20, seconds: 20, totalSeconds: 0, multiplier: 1, lifeCost: 1, jokerMax: 3, group: 'solo'),
  BilgiMode(id: 'maraton', name: 'Maraton', emoji: '🏃', blurb: '50 soru • 15 dk toplam süre', questions: 50, seconds: 0, totalSeconds: 900, multiplier: 2, lifeCost: 3, jokerMax: 5, group: 'solo'),
  BilgiMode(id: 'sakin', name: 'Sakin Mod', emoji: '🧘', blurb: '10 soru • Süresiz • 0.5x puan', questions: 10, seconds: 0, totalSeconds: 0, multiplier: 0.5, lifeCost: 1, jokerMax: 3, group: 'solo'),
  BilgiMode(id: 'duello', name: 'Düello', emoji: '⚔️', blurb: 'Birebir • 10 sn • Rakip eşleşme', questions: 10, seconds: 10, totalSeconds: 0, multiplier: 1, lifeCost: 1, jokerMax: 2, group: 'multi'),
  BilgiMode(id: 'oda', name: 'Özel Oda', emoji: '🔒', blurb: 'Arkadaşlarınla oda kur', questions: 20, seconds: 15, totalSeconds: 0, multiplier: 1, lifeCost: 1, jokerMax: 3, group: 'multi'),
  BilgiMode(id: 'gunluk', name: 'Günün Sorusu', emoji: '📅', blurb: 'Günde 1 soru • 2x puan', questions: 1, seconds: 30, totalSeconds: 0, multiplier: 2, lifeCost: 0, jokerMax: 0, group: 'special'),
  BilgiMode(id: 'yarisma', name: 'Günün Yarışması', emoji: '🏁', blurb: '20 soru • Günde 1 • Can yok', questions: 20, seconds: 15, totalSeconds: 0, multiplier: 1, lifeCost: 0, jokerMax: 3, group: 'special'),
  BilgiMode(id: 'lig', name: 'Luno Ligi', emoji: '🏆', blurb: 'Haftalık turnuva • 20 soru', questions: 20, seconds: 15, totalSeconds: 0, multiplier: 1, lifeCost: 1, jokerMax: 3, group: 'special'),
];

BilgiMode bilgiModeById(String id) {
  return bilgiModes.firstWhere((mode) => mode.id == id, orElse: () => bilgiModes.first);
}

class BilgiRound {
  BilgiRound({
    required this.id,
    required this.userId,
    required this.modeId,
    required this.categoryId,
    this.subcategory = '',
    required this.difficulty,
    required this.questions,
    required this.multiplier,
    required this.seconds,
    required this.totalSeconds,
    required this.jokerMax,
    required this.lifeCost,
    this.index = 0,
    this.score = 0,
    this.correct = 0,
    this.wrong = 0,
    this.timeBonus = 0,
    this.streak = 0,
    this.jokersUsed = 0,
    this.hidden = const [],
    this.doubleLeft = 0,
    this.paused = false,
    this.finished = false,
    this.gold = 0,
    this.xp = 0,
    this.opponentName = '',
    this.opponentScore = 0,
    this.roomCode = '',
    this.waiting = false,
    this.hint = '',
    this.spare,
    List<BilgiQuestion>? spares,
    this.standings = const [],
    DateTime? startedAt,
  })  : spares = spares ?? <BilgiQuestion>[],
        startedAt = startedAt ?? DateTime.now();

  final String id;
  final String userId;
  final String modeId;
  final String categoryId;
  final String subcategory;
  final String difficulty;
  final List<BilgiQuestion> questions;
  final double multiplier;
  final int seconds;
  final int totalSeconds;
  final int jokerMax;
  final int lifeCost;
  int index;
  int score;
  int correct;
  int wrong;
  int timeBonus;
  int streak;
  int jokersUsed;
  List<int> hidden;
  int doubleLeft;
  bool paused;
  bool finished;
  int gold;
  int xp;
  String opponentName;
  int opponentScore;
  String roomCode;
  bool waiting;
  String hint;
  BilgiQuestion? spare;
  final List<BilgiQuestion> spares;
  List<Map<String, String>> standings;
  final DateTime startedAt;

  BilgiQuestion? get current => index >= 0 && index < questions.length ? questions[index] : null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'userId': userId,
        'modeId': modeId,
        'categoryId': categoryId,
        'subcategory': subcategory,
        'difficulty': difficulty,
        'questions': questions.map((q) => q.toMap()).toList(),
        'multiplier': multiplier,
        'seconds': seconds,
        'totalSeconds': totalSeconds,
        'jokerMax': jokerMax,
        'lifeCost': lifeCost,
        'index': index,
        'score': score,
        'correct': correct,
        'wrong': wrong,
        'timeBonus': timeBonus,
        'streak': streak,
        'jokersUsed': jokersUsed,
        'hidden': hidden,
        'doubleLeft': doubleLeft,
        'paused': paused,
        'finished': finished,
        'gold': gold,
        'xp': xp,
        'opponentName': opponentName,
        'opponentScore': opponentScore,
        'roomCode': roomCode,
        'waiting': waiting,
        'hint': hint,
        'startedAt': startedAt.toIso8601String(),
        if (spare != null) 'spare': spare!.toMap(),
        if (spares.isNotEmpty) 'spares': [for (final question in spares) question.toMap()],
        'standings': standings,
      };
}

class BilgiRoom {
  const BilgiRoom({
    required this.code,
    required this.hostId,
    required this.hostName,
    required this.categoryId,
    required this.questionCount,
    required this.seconds,
    required this.difficulty,
    required this.players,
    required this.kind,
    this.status = 'lobby',
    this.subcategory = '',
  });

  final String code;
  final String hostId;
  final String hostName;
  final String categoryId;
  final int questionCount;
  final int seconds;
  final String difficulty;
  final List<Map<String, String>> players;
  final String kind;
  final String status;
  final String subcategory;

  Map<String, dynamic> toMap() => {
        'code': code,
        'hostId': hostId,
        'hostName': hostName,
        'categoryId': categoryId,
        'questionCount': questionCount,
        'seconds': seconds,
        'difficulty': difficulty,
        'players': players,
        'kind': kind,
        'status': status,
        'subcategory': subcategory,
      };

  factory BilgiRoom.fromMap(Map<String, dynamic> map) {
    final players = <Map<String, String>>[
      for (final row in (map['players'] as List? ?? const []))
        {
          for (final entry in (row as Map).entries) entry.key.toString(): '${entry.value}',
        },
    ];
    final rawHost = map['hostId'];
    var hostId = rawHost == null ? '' : '$rawHost'.trim();
    if (hostId.isEmpty) {
      for (final player in players) {
        final id = (player['id'] ?? '').trim();
        if (player['role'] == 'host' && id.isNotEmpty) {
          hostId = id;
          break;
        }
      }
    }
    return BilgiRoom(
      code: map['code'] as String? ?? '',
      hostId: hostId,
      hostName: map['hostName'] as String? ?? '',
      categoryId: map['categoryId'] as String? ?? tumuFallback,
      questionCount: bilgiInt(map['questionCount'], 20),
      seconds: bilgiInt(map['seconds'], 15),
      difficulty: map['difficulty'] as String? ?? 'orta',
      players: players,
      kind: map['kind'] as String? ?? 'oda',
      status: map['status'] as String? ?? 'lobby',
      subcategory: map['subcategory'] as String? ?? '',
    );
  }
}

const tumuFallback = 'tumu';

int bilgiInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('${value ?? ''}') ?? fallback;
}

int dayRewardAmount(List<int> values, int index) {
  if (index < 0 || index >= values.length) return 0;
  return values[index];
}

bool rewardConfigStored(Map<String, dynamic> stored) {
  bool week(String key) {
    final raw = stored[key];
    return raw is List && raw.length >= 7;
  }

  return week('dailyGold') && week('dailyDiamond') && week('dailyJoker') && stored['rewardedGold'] != null;
}

class BilgiConfig {
  const BilgiConfig({
    this.maintenance = false,
    this.maintenanceMinutes = 30,
    this.registrationsOpen = true,
    this.maxLives = 5,
    this.startLives = 5,
    this.lifeMinutes = 30,
    this.lifePrice = 100,
    this.lifeCostDefault = 1,
    this.lifeCostMarathon = 3,
    this.inviteLifeEvery = 5,
    this.dailyFreeGames = 3,
    this.preGameAdSeconds = 15,
    this.newUserAdFree = 3,
    this.rewardedGold = 50,
    this.rewardedGoldLimit = 10,
    this.rewardedJokerLimit = 3,
    this.rewardedLifeLimit = 2,
    this.rewardedDoubleLimit = 3,
    this.bannerEnabled = true,
    this.livesEnabled = true,
    this.adaptiveDifficulty = false,
    this.scoreKolay = 10,
    this.scoreOrta = 15,
    this.scoreZor = 25,
    this.scoreEfsane = 40,
    this.scoreTimeBonus = 5,
    this.jokerPrices = const {'half': 50, 'double': 75, 'time': 60, 'change': 100, 'hint': 80},
    this.jokerStarts = const {'half': 2, 'double': 1, 'time': 1, 'change': 0, 'hint': 0},
    this.dailyGold = const [100, 200, 0, 300, 0, 500, 1000],
    this.dailyDiamond = const [0, 0, 1, 0, 0, 0, 0],
    this.dailyJoker = const [0, 0, 0, 0, 1, 0, 0],
    this.appName = 'Luno Bilgi',
    this.supportEmail = 'destek@lunobilgi.com',
    this.notificationsEnabled = false,
    this.uiLocale = 'tr',
    this.adminTags = const [],
    this.modeOverrides = const {},
  });

  final bool maintenance;
  final int maintenanceMinutes;
  final bool registrationsOpen;
  final int maxLives;
  final int startLives;
  final int lifeMinutes;
  final int lifePrice;
  final int lifeCostDefault;
  final int lifeCostMarathon;
  final int inviteLifeEvery;
  final int dailyFreeGames;
  final int preGameAdSeconds;
  final int newUserAdFree;
  final int rewardedGold;
  final int rewardedGoldLimit;
  final int rewardedJokerLimit;
  final int rewardedLifeLimit;
  final int rewardedDoubleLimit;
  final bool bannerEnabled;
  final bool livesEnabled;
  final bool adaptiveDifficulty;
  final int scoreKolay;
  final int scoreOrta;
  final int scoreZor;
  final int scoreEfsane;
  final int scoreTimeBonus;
  final Map<String, int> jokerPrices;
  final Map<String, int> jokerStarts;
  final List<int> dailyGold;
  final List<int> dailyDiamond;
  final List<int> dailyJoker;
  final String appName;
  final String supportEmail;
  final bool notificationsEnabled;
  final String uiLocale;
  final List<String> adminTags;
  final Map<String, Map<String, num>> modeOverrides;

  BilgiMode resolvedMode(BilgiMode mode) {
    final raw = modeOverrides[mode.id];
    final life = !livesEnabled || mode.lifeCost == 0
        ? 0
        : raw?['lifeCost']?.toInt() ?? (mode.id == 'maraton' ? lifeCostMarathon : lifeCostDefault);
    return BilgiMode(
      id: mode.id,
      name: mode.name,
      emoji: mode.emoji,
      blurb: mode.blurb,
      questions: raw?['questions']?.toInt() ?? mode.questions,
      seconds: raw?['seconds']?.toInt() ?? mode.seconds,
      totalSeconds: raw?['totalSeconds']?.toInt() ?? mode.totalSeconds,
      multiplier: raw?['multiplier']?.toDouble() ?? mode.multiplier,
      lifeCost: life,
      jokerMax: mode.jokerMax,
      group: mode.group,
    );
  }

  Map<String, dynamic> toMap() => {
        'maintenance': maintenance,
        'maintenanceMinutes': maintenanceMinutes,
        'registrationsOpen': registrationsOpen,
        'maxLives': maxLives,
        'startLives': startLives,
        'lifeMinutes': lifeMinutes,
        'lifePrice': lifePrice,
        'lifeCostDefault': lifeCostDefault,
        'lifeCostMarathon': lifeCostMarathon,
        'inviteLifeEvery': inviteLifeEvery,
        'dailyFreeGames': dailyFreeGames,
        'preGameAdSeconds': preGameAdSeconds,
        'newUserAdFree': newUserAdFree,
        'rewardedGold': rewardedGold,
        'rewardedGoldLimit': rewardedGoldLimit,
        'rewardedJokerLimit': rewardedJokerLimit,
        'rewardedLifeLimit': rewardedLifeLimit,
        'rewardedDoubleLimit': rewardedDoubleLimit,
        'bannerEnabled': bannerEnabled,
        'livesEnabled': livesEnabled,
        'adaptiveDifficulty': false,
        'scoreKolay': scoreKolay,
        'scoreOrta': scoreOrta,
        'scoreZor': scoreZor,
        'scoreEfsane': scoreEfsane,
        'scoreTimeBonus': scoreTimeBonus,
        'modeOverrides': {
          for (final entry in modeOverrides.entries)
            entry.key: {for (final value in entry.value.entries) value.key: value.value},
        },
        'jokerPrices': jokerPrices,
        'jokerStarts': jokerStarts,
        'dailyGold': dailyGold,
        'dailyDiamond': dailyDiamond,
        'dailyJoker': dailyJoker,
        'appName': appName,
        'supportEmail': supportEmail,
        'notificationsEnabled': notificationsEnabled,
        'uiLocale': uiLocale,
        'adminTags': adminTags,
      };

  factory BilgiConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const BilgiConfig();
    List<int> ints(String key, List<int> fallback) {
      final raw = map[key];
      if (raw is! List || raw.isEmpty) return List<int>.from(fallback);
      final values = [for (final item in raw) bilgiInt(item, 0)];
      if (values.length >= fallback.length) return values;
      return [...values, ...fallback.skip(values.length)];
    }

    return BilgiConfig(
      maintenance: map['maintenance'] as bool? ?? false,
      maintenanceMinutes: bilgiInt(map['maintenanceMinutes'], 30),
      registrationsOpen: map['registrationsOpen'] as bool? ?? true,
      maxLives: bilgiInt(map['maxLives'], 5),
      startLives: bilgiInt(map['startLives'], 5),
      lifeMinutes: bilgiInt(map['lifeMinutes'], 30),
      lifePrice: bilgiInt(map['lifePrice'], 100),
      lifeCostDefault: bilgiInt(map['lifeCostDefault'], 1),
      lifeCostMarathon: bilgiInt(map['lifeCostMarathon'], 3),
      inviteLifeEvery: bilgiInt(map['inviteLifeEvery'], 5),
      dailyFreeGames: bilgiInt(map['dailyFreeGames'], 3),
      preGameAdSeconds: bilgiInt(map['preGameAdSeconds'], 15),
      newUserAdFree: bilgiInt(map['newUserAdFree'], 3),
      rewardedGold: bilgiInt(map['rewardedGold'], 50),
      rewardedGoldLimit: bilgiInt(map['rewardedGoldLimit'], 10),
      rewardedJokerLimit: bilgiInt(map['rewardedJokerLimit'], 3),
      rewardedLifeLimit: bilgiInt(map['rewardedLifeLimit'], 2),
      rewardedDoubleLimit: bilgiInt(map['rewardedDoubleLimit'], 3),
      bannerEnabled: map['bannerEnabled'] as bool? ?? true,
      livesEnabled: map['livesEnabled'] as bool? ?? true,
      adaptiveDifficulty: false,
      scoreKolay: bilgiInt(map['scoreKolay'], 10),
      scoreOrta: bilgiInt(map['scoreOrta'], 15),
      scoreZor: bilgiInt(map['scoreZor'], 25),
      scoreEfsane: bilgiInt(map['scoreEfsane'], 40),
      scoreTimeBonus: bilgiInt(map['scoreTimeBonus'], 5),
      modeOverrides: {
        for (final entry in ((map['modeOverrides'] as Map?) ?? const {}).entries)
          entry.key.toString(): {
            for (final value in ((entry.value as Map?) ?? const {}).entries)
              value.key.toString(): value.value as num? ?? 0,
          },
      },
      jokerPrices: {
        for (final entry in ((map['jokerPrices'] as Map?) ?? const BilgiConfig().jokerPrices).entries)
          entry.key.toString(): bilgiInt(entry.value, 0),
      },
      jokerStarts: {
        for (final entry in ((map['jokerStarts'] as Map?) ?? const BilgiConfig().jokerStarts).entries)
          entry.key.toString(): bilgiInt(entry.value, 0),
      },
      dailyGold: ints('dailyGold', const [100, 200, 0, 300, 0, 500, 1000]),
      dailyDiamond: ints('dailyDiamond', const [0, 0, 1, 0, 0, 0, 0]),
      dailyJoker: ints('dailyJoker', const [0, 0, 0, 0, 1, 0, 0]),
      appName: map['appName'] as String? ?? 'Luno Bilgi',
      supportEmail: map['supportEmail'] as String? ?? 'destek@lunobilgi.com',
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? false,
      uiLocale: map['uiLocale'] as String? ?? 'tr',
      adminTags: (map['adminTags'] as List? ?? const []).map((e) => '$e').toList(),
    );
  }
}

class BilgiAchievement {
  const BilgiAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.target,
    required this.rewardGold,
    required this.icon,
  });

  final String id;
  final String title;
  final String description;
  final int target;
  final int rewardGold;
  final String icon;
}

const bilgiAchievements = <BilgiAchievement>[
  BilgiAchievement(id: 'first', title: 'İlk Adım', description: '1 oyun oyna', target: 1, rewardGold: 50, icon: '🎮'),
  BilgiAchievement(id: 'aim', title: 'Keskin Nişancı', description: '10 doğru yap', target: 10, rewardGold: 100, icon: '🎯'),
  BilgiAchievement(id: 'streak', title: 'Seri Ustası', description: '7 gün üst üste gir', target: 7, rewardGold: 300, icon: '🔥'),
  BilgiAchievement(id: 'duel', title: 'Düello Kralı', description: '5 düello kazan', target: 5, rewardGold: 300, icon: '⚔️'),
  BilgiAchievement(id: 'cats', title: 'Kategori Fatihi', description: '5 kategori bitir', target: 5, rewardGold: 500, icon: '📚'),
  BilgiAchievement(id: 'peak', title: 'Zirve', description: 'Seviye 50\'ye ulaş', target: 50, rewardGold: 1000, icon: '👑'),
];

const bilgiBadges = <({String id, String name, String emoji, String type, int value})>[
  (id: 'champ', name: 'Şampiyon', emoji: '🏆', type: 'games', value: 10),
  (id: 'fast', name: 'Hızlı Parmak', emoji: '⚡', type: 'correct', value: 25),
  (id: 'wise', name: 'Bilge', emoji: '🧠', type: 'level', value: 10),
  (id: 'gem', name: 'Elmas', emoji: '💎', type: 'diamond', value: 5),
  (id: 'king', name: 'Kral', emoji: '👑', type: 'level', value: 50),
];
