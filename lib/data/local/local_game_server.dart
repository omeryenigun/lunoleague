import 'dart:async';
import 'dart:math';

import 'package:kelimelig/core/constants/app_constants.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/constants/user_messages.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/utils/date_keys.dart';
import 'package:kelimelig/core/utils/password_hash.dart';
import 'package:kelimelig/data/local/key_value_store.dart';
import 'package:kelimelig/data/local/seed_words.dart';
import 'package:kelimelig/data/local/en_common_words.dart';
import 'package:kelimelig/data/local/en_extra_words.dart';
import 'package:kelimelig/data/local/en_batch_words.dart';
import 'package:kelimelig/data/local/en_next_words.dart';
import 'package:kelimelig/data/local/en_plus_words.dart';
import 'package:kelimelig/data/local/de_frequency_words.dart';
import 'package:kelimelig/data/local/es_frequency_words.dart';
import 'package:kelimelig/data/local/fr_frequency_words.dart';
import 'package:kelimelig/data/local/it_frequency_words.dart';
import 'package:kelimelig/data/local/pt_frequency_words.dart';
import 'package:kelimelig/data/local/ru_frequency_words.dart';
import 'package:kelimelig/data/local/de_glosses.dart';
import 'package:kelimelig/data/local/en_flow_words.dart';
import 'package:kelimelig/data/local/en_wave_words.dart';
import 'package:kelimelig/data/local/en_more_words.dart';
import 'package:kelimelig/data/local/en_starter_words.dart';
import 'package:kelimelig/data/local/tr_profanity.dart';
import 'package:kelimelig/data/local/word_csv.dart';
import 'package:kelimelig/data/local/seed_words_en.dart';
import 'package:kelimelig/data/local/seed_words_extra.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/entities/cosmetics.dart';
import 'package:kelimelig/domain/entities/app_config.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/game/match_rank.dart';
import 'package:kelimelig/domain/entities/shop_product.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';
import 'package:kelimelig/domain/entities/word_import_result.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/domain/game/progression.dart';
import 'package:kelimelig/domain/game/word_matching_engine.dart';
import 'package:uuid/uuid.dart';

class LocalGameServer implements GameServer {
  LocalGameServer(
    this._store, {
    WordMatchingEngine engine = const WordMatchingEngine(),
    ProgressionCalculator progression = const ProgressionCalculator(),
    Uuid uuid = const Uuid(),
    DateTime Function()? clock,
    Random? random,
    this.confirmPurchase,
    this.grantUnverifiedAds = true,
  })  : _engine = engine,
        _progression = progression,
        _uuid = uuid,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final KeyValueStore _store;
  final WordMatchingEngine _engine;
  final ProgressionCalculator _progression;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final Random _random;
  final Map<String, Future<void>> _dailySlotLocks = {};

  /// When set, a shop token must pass this check before coins are granted.
  /// The live API verifies the Play receipt. Tests leave this unset.
  final Future<bool> Function(String productId, String purchaseToken)?
      confirmPurchase;

  /// Live API sets this false so a client request cannot mint ad coins.
  final bool grantUnverifiedAds;

  static const _currentUserKey = 'currentUserId';
  static const _seededKey = 'seeded';
  static const _localeSeedKey = 'seeded_locales';
  static const _moreLocaleKey = 'more_locales_v1';
  static const _latinLocaleKey = 'more_locales_v2';
  static const _deviceLocaleKey = 'device_locale';
  static const _profanityKey = 'tr_profanity_draft_v1';
  static const _enStarterKey = 'en_starter_words_v1';
  static const _enCommonKey = 'en_common_words_v1';
  static const _enMoreKey = 'en_more_words_v1';
  static const _enExtraKey = 'en_extra_words_v1';
  static const _enNextKey = 'en_next_words_v1';
  static const _enBatchKey = 'en_batch_words_v1';
  static const _enPlusKey = 'en_plus_words_v1';
  static const _enWaveKey = 'en_wave_words_v1';
  static const _enFlowKey = 'en_flow_words_v1';
  static const _enDropNoiseKey = 'en_drop_noise_v1';
  static const _deFrequencyKey = 'de_frequency_words_v1';
  static const _deGlossKey = 'de_definitions_v1';
  static const _deDropUndefinedKey = 'de_drop_undefined_v1';
  static const _esFrequencyKey = 'es_frequency_words_v1';
  static const _frFrequencyKey = 'fr_frequency_words_v1';
  static const _itFrequencyKey = 'it_frequency_words_v1';
  static const _ptFrequencyKey = 'pt_frequency_words_v1';
  static const _ruFrequencyKey = 'ru_frequency_words_v1';
  static const _adCoin15Key = 'ad_coin_reward_15_v1';
  static const _noiseEnglishWords = {
    'thehun',
    'ampland',
    'gratuit',
    'andale',
    'msgid',
    'msgstr',
  };

  Future<void> initialize() async {
    final seeded = await _store.getMeta(_seededKey);
    if (seeded != '1') {
      final now = _clock();
      for (final w in buildSeedWords(now: now)) {
        await _store.put('words', w.id, w.toMap());
      }
      await _store.put('app_config', 'default', AppConfig.defaults().toMap());
      await _seedNpcs();
      await _seedShopCatalog();
      await _store.putMeta(_seededKey, '1');
    }
    await _ensureLocaleContent();
    await _ensureMoreLocales();
    await _ensureLatinLocales();
    await _ensureShopCatalog();
    await _draftTurkishProfanity();
  }

  /// Marks exact Turkish profanity as draft. Word text and definitions stay.
  Future<void> _draftTurkishProfanity() async {
    if (await _store.getMeta(_profanityKey) == '1') return;
    final now = _clock();
    for (final raw in await _store.values('words')) {
      final word = WordEntity.fromMap(raw);
      if (word.language != 'tr') continue;
      if (!isTurkishProfanity(word.word)) continue;
      if (!word.isActive && word.status == WordStatus.draft) continue;
      await _store.put(
        'words',
        word.id,
        word
            .copyWith(
              status: WordStatus.draft,
              isActive: false,
              updatedAt: now,
            )
            .toMap(),
      );
    }
    await _store.putMeta(_profanityKey, '1');
  }

  /// Adds the bundled English sample once. Later imports of the same words are skipped.
  Future<WordImportResult> importStarterEnglishWords() async {
    if (await _store.getMeta(_enStarterKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enStarterWordsCsv);
    await _store.putMeta(_enStarterKey, '1');
    return result;
  }

  /// Adds the common English list once. Words already stored are left as they are.
  Future<WordImportResult> importCommonEnglishWords() async {
    if (await _store.getMeta(_enCommonKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enCommonWordsCsv);
    await _store.putMeta(_enCommonKey, '1');
    return result;
  }

  /// Adds the next English list once. Words already stored are left as they are.
  Future<WordImportResult> importMoreEnglishWords() async {
    if (await _store.getMeta(_enMoreKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enMoreWordsCsv);
    await _store.putMeta(_enMoreKey, '1');
    return result;
  }

  /// Adds the latest English list once. Words already stored are left as they are.
  Future<WordImportResult> importExtraEnglishWords() async {
    if (await _store.getMeta(_enExtraKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enExtraWordsCsv);
    await _store.putMeta(_enExtraKey, '1');
    return result;
  }

  /// Adds another English list once. Words already stored are left as they are.
  Future<WordImportResult> importNextEnglishWords() async {
    if (await _store.getMeta(_enNextKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enNextWordsCsv);
    await _store.putMeta(_enNextKey, '1');
    return result;
  }

  /// Adds the latest English list once. Words already stored are left as they are.
  Future<WordImportResult> importBatchEnglishWords() async {
    if (await _store.getMeta(_enBatchKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enBatchWordsCsv);
    await _store.putMeta(_enBatchKey, '1');
    return result;
  }

  /// Adds another English list once. Words already stored are left as they are.
  Future<WordImportResult> importPlusEnglishWords() async {
    if (await _store.getMeta(_enPlusKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enPlusWordsCsv);
    await _store.putMeta(_enPlusKey, '1');
    return result;
  }

  /// Adds another English list once. Words already stored are left as they are.
  Future<WordImportResult> importWaveEnglishWords() async {
    if (await _store.getMeta(_enWaveKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enWaveWordsCsv);
    await _store.putMeta(_enWaveKey, '1');
    return result;
  }

  /// Adds another English list once. Words already stored are left as they are.
  Future<WordImportResult> importFlowEnglishWords() async {
    if (await _store.getMeta(_enFlowKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(enFlowWordsCsv);
    await _store.putMeta(_enFlowKey, '1');
    return result;
  }

  /// Adds the German frequency list once. Ä, Ö, Ü and ẞ stay as written.
  Future<WordImportResult> importGermanFrequencyWords() async {
    if (await _store.getMeta(_deFrequencyKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(deFrequencyWordsCsv);
    await _store.putMeta(_deFrequencyKey, '1');
    return result;
  }

  /// Replaces the placeholder German gloss once. Words already given a real
  /// definition are left as they are.
  Future<({int updated, int missing})> fillGermanDefinitions() async {
    if (await _store.getMeta(_deGlossKey) == '1') {
      return (updated: 0, missing: 0);
    }
    var updated = 0;
    var missing = 0;
    for (final raw in await _store.values('words')) {
      final word = WordEntity.fromMap(raw);
      if (word.language != 'de' || word.definition != 'Deutsches Wort.') {
        continue;
      }
      final gloss = deGlosses[GameLocale.de.writtenUpper(word.word)];
      if (gloss == null) {
        missing++;
        continue;
      }
      await _store.put(
        'words',
        word.id,
        word.copyWith(definition: gloss, updatedAt: _clock()).toMap(),
      );
      updated++;
    }
    await _store.putMeta(_deGlossKey, '1');
    return (updated: updated, missing: missing);
  }

  /// Drops German rows that still have the placeholder gloss.
  Future<int> dropUndefinedGermanWords() async {
    if (await _store.getMeta(_deDropUndefinedKey) == '1') return 0;
    var removed = 0;
    for (final raw in await _store.values('words')) {
      final word = WordEntity.fromMap(raw);
      if (word.language == 'de' && word.definition == 'Deutsches Wort.') {
        await _store.delete('words', word.id);
        removed++;
      }
    }
    await _store.putMeta(_deDropUndefinedKey, '1');
    return removed;
  }

  /// Adds Spanish words that have a real gloss. Ñ stays. Vowel accents fold.
  Future<WordImportResult> importSpanishFrequencyWords() async {
    if (await _store.getMeta(_esFrequencyKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(esFrequencyWordsCsv);
    await _store.putMeta(_esFrequencyKey, '1');
    return result;
  }

  /// Adds French words that have a real gloss. Accents fold, so école is ECOLE.
  Future<WordImportResult> importFrenchFrequencyWords() async {
    if (await _store.getMeta(_frFrequencyKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(frFrequencyWordsCsv);
    await _store.putMeta(_frFrequencyKey, '1');
    return result;
  }

  /// Adds Italian words that have a real gloss. Accents fold, so città is CITTA.
  Future<WordImportResult> importItalianFrequencyWords() async {
    if (await _store.getMeta(_itFrequencyKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(itFrequencyWordsCsv);
    await _store.putMeta(_itFrequencyKey, '1');
    return result;
  }

  /// Adds Portuguese words that have a real gloss. Accents fold, so ação is ACAO.
  Future<WordImportResult> importPortugueseFrequencyWords() async {
    if (await _store.getMeta(_ptFrequencyKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(ptFrequencyWordsCsv);
    await _store.putMeta(_ptFrequencyKey, '1');
    return result;
  }

  /// Adds Russian words that have a real gloss. Yo stays yo.
  Future<WordImportResult> importRussianFrequencyWords() async {
    if (await _store.getMeta(_ruFrequencyKey) == '1') {
      return const WordImportResult(imported: 0, skipped: 0, invalid: 0);
    }
    final result = await adminImportWords(ruFrequencyWordsCsv);
    await _store.putMeta(_ruFrequencyKey, '1');
    return result;
  }

  /// Sets the rewarded-ad coin grant to 15 once. Other config fields stay.
  Future<int> raiseAdCoinReward() async {
    if (await _store.getMeta(_adCoin15Key) == '1') return 0;
    final config = await _config();
    if (config.adCoinReward != 15) {
      await _store.put(
        'app_config',
        'default',
        config.copyWith(adCoinReward: 15).toMap(),
      );
    }
    await _store.putMeta(_adCoin15Key, '1');
    return 15;
  }

  /// Removes a few non-English tokens from the English dictionary once.
  Future<int> dropNoiseEnglishWords() async {
    if (await _store.getMeta(_enDropNoiseKey) == '1') return 0;
    var removed = 0;
    for (final raw in await _store.values('words')) {
      final word = WordEntity.fromMap(raw);
      if (word.language == 'en' &&
          _noiseEnglishWords.contains(word.word.toLowerCase())) {
        await _store.delete('words', word.id);
        removed++;
      }
    }
    await _store.putMeta(_enDropNoiseKey, '1');
    return removed;
  }

  Future<void> _seedShopCatalog() async {
    for (final p in ShopCatalog.products) {
      await _store.put('shop_products', p.id, p.toMap());
    }
  }

  Future<void> _ensureShopCatalog() async {
    final existing = await _store.values('shop_products');
    if (existing.isEmpty) {
      await _seedShopCatalog();
      return;
    }
    final ids = existing.map((e) => e['id'] as String).toSet();
    for (final p in ShopCatalog.products) {
      if (!ids.contains(p.id)) {
        await _store.put('shop_products', p.id, p.toMap());
      }
    }
  }

  Future<List<ShopProduct>> _loadShopProducts({bool onlyActive = false}) async {
    await _ensureShopCatalog();
    final list = (await _store.values('shop_products'))
        .map(ShopProduct.fromMap)
        .where((p) => !onlyActive || p.active)
        .toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        final byCoins = a.coins.compareTo(b.coins);
        if (byCoins != 0) return byCoins;
        return a.shields.compareTo(b.shields);
      });
    return list;
  }

  Future<void> _ensureLocaleContent() async {
    if (await _store.getMeta(_localeSeedKey) == '2') return;
    final now = _clock();
    for (final w in buildSeedWordsEn(now: now)) {
      if (await _store.get('words', w.id) == null) {
        await _store.put('words', w.id, w.toMap());
      }
    }
    final npcs = await _store.values('npc_players');
    var hasTr = false;
    for (final e in npcs) {
      final locale = e['locale'] as String? ?? 'tr';
      if (locale == 'tr') hasTr = true;
      if (e['locale'] == null) {
        e['locale'] = 'tr';
        await _store.put('npc_players', e['id'] as String, e);
      }
    }
    if (!hasTr) await _putNpcs('tr', _trNpcNames);
    await _putNpcs('en', _enNpcNames);
    await _store.putMeta(_localeSeedKey, '2');
  }

  Future<void> _ensureMoreLocales() async {
    if (await _store.getMeta(_moreLocaleKey) == '1') return;
    final now = _clock();
    for (final word in buildExtraLocaleWords(now: now)) {
      if (await _store.get('words', word.id) == null) {
        await _store.put('words', word.id, word.toMap());
      }
    }
    await _putNpcs('de', _deNpcNames);
    await _putNpcs('es', _esNpcNames);
    await _putNpcs('fr', _frNpcNames);
    await _putNpcs('it', _itNpcNames);
    await _store.putMeta(_moreLocaleKey, '1');
  }

  Future<void> _ensureLatinLocales() async {
    if (await _store.getMeta(_latinLocaleKey) == '1') return;
    final now = _clock();
    for (final word in buildExtraLocaleWords(now: now)) {
      if (word.language != 'ru' &&
          word.language != 'nl' &&
          word.language != 'pt' &&
          word.language != 'pl') {
        continue;
      }
      if (await _store.get('words', word.id) == null) {
        await _store.put('words', word.id, word.toMap());
      }
    }
    await _putNpcs('ru', _ruNpcNames);
    await _putNpcs('nl', _nlNpcNames);
    await _putNpcs('pt', _ptNpcNames);
    await _putNpcs('pl', _plNpcNames);
    await _store.putMeta(_latinLocaleKey, '1');
  }

  static const _trNpcNames = [
    'Ahmet K.', 'Zeynep Y.', 'Mehmet T.', 'Ali R.', 'Elif S.',
    'Can B.', 'Deniz A.', 'Ece N.', 'Burak M.', 'Selin D.',
    'Kerem P.', 'İrem L.', 'Onur C.', 'Merve G.', 'Emre H.',
    'Ceren U.', 'Berk O.', 'Derya F.', 'Yusuf I.', 'Gizem V.',
    'Hakan J.', 'Pınar Q.', 'Serkan W.', 'Nazlı X.', 'Tolga Z.',
    'Aslı K.', 'Umut Y.', 'Melis T.', 'Barış R.', 'Sude S.',
    'Kaan B.', 'Defne A.', 'Arda N.', 'Eylül M.', 'Mert D.',
    'İlayda P.', 'Oğuz L.', 'Büşra C.', 'Tuna G.', 'Lara H.',
    'Kuzey U.', 'Nehir O.', 'Atlas F.', 'Lina I.', 'Rüzgar V.',
    'Ada J.', 'Ege Q.', 'Mina W.', 'Doruk X.',
  ];

  static const _enNpcNames = [
    'Alex K.', 'Jamie Y.', 'Morgan T.', 'Riley R.', 'Casey S.',
    'Quinn B.', 'Avery A.', 'Jordan N.', 'Taylor M.', 'Reese D.',
    'Parker P.', 'Drew L.', 'Cameron C.', 'Hayden G.', 'Finley H.',
    'Rowan U.', 'Sawyer O.', 'Emerson F.', 'Blake I.', 'Harper V.',
    'Logan J.', 'Peyton Q.', 'Sidney W.', 'Marley X.', 'Devon Z.',
    'Ellis K.', 'Lane Y.', 'Charlie T.', 'Robin R.', 'Sky S.',
    'Jules B.', 'Eden A.', 'Gray N.', 'Sam M.', 'Max D.',
    'Remy P.', 'Shay L.', 'Noah C.', 'Owen G.', 'Liam H.',
    'Mason U.', 'Ethan O.', 'Lucas F.', 'Mia I.', 'Ava V.',
    'Zoe J.', 'Leo Q.', 'Nora W.', 'Eli X.',
  ];

  static const _deNpcNames = [
    'Anna K.', 'Lukas Y.', 'Mia T.', 'Jonas R.', 'Lea S.',
    'Felix B.', 'Emma A.', 'Paul N.', 'Lina M.', 'Noah D.',
    'Sofia P.', 'Ben L.',
  ];

  static const _esNpcNames = [
    'Lucia K.', 'Mateo Y.', 'Sofia T.', 'Hugo R.', 'Martina S.',
    'Diego B.', 'Elena A.', 'Pablo N.', 'Carmen M.', 'Leo D.',
    'Nora P.', 'Iker L.',
  ];

  static const _frNpcNames = [
    'Camille K.', 'Louis Y.', 'Chloe T.', 'Hugo R.', 'Lea S.',
    'Adam B.', 'Manon A.', 'Nathan N.', 'Ines M.', 'Jules D.',
    'Lina P.', 'Ethan L.',
  ];

  static const _itNpcNames = [
    'Giulia K.', 'Luca Y.', 'Sofia T.', 'Marco R.', 'Chiara S.',
    'Andrea B.', 'Elena A.', 'Matteo N.', 'Greta M.', 'Leo D.',
    'Nora P.', 'Pietro L.',
  ];

  static const _ruNpcNames = [
    'Анна К.', 'Иван Т.', 'Мария С.', 'Павел Р.', 'Ольга Н.',
    'Сергей Б.', 'Елена А.', 'Никита М.', 'Дарья Д.', 'Лев П.',
    'София Л.', 'Артём Г.',
  ];

  static const _nlNpcNames = [
    'Daan K.', 'Emma Y.', 'Sem T.', 'Luuk R.', 'Sophie S.',
    'Bram B.', 'Noor A.', 'Finn N.', 'Tess M.', 'Lars D.',
    'Fleur P.', 'Milan L.',
  ];

  static const _ptNpcNames = [
    'Ana K.', 'Pedro Y.', 'Maria T.', 'Lucas R.', 'Beatriz S.',
    'Miguel B.', 'Sofia A.', 'Tiago N.', 'Ines M.', 'Lara D.',
    'Rui P.', 'Matilde L.',
  ];

  static const _plNpcNames = [
    'Anna K.', 'Piotr Y.', 'Kasia T.', 'Marek R.', 'Zofia S.',
    'Jan B.', 'Ola A.', 'Tomek N.', 'Basia M.', 'Adam D.',
    'Ewa P.', 'Leon L.',
  ];

  Future<void> _seedNpcs() async {
    await _putNpcs('tr', _trNpcNames);
  }

  Future<void> _putNpcs(String locale, List<String> names) async {
    for (final league in LeagueTier.values) {
      for (var i = 0; i < names.length; i++) {
        final id = 'npc_${locale}_${league.name}_$i';
        if (await _store.get('npc_players', id) != null) continue;
        await _store.put('npc_players', id, {
          'id': id,
          'displayName': names[i],
          'league': league.name,
          'locale': locale,
        });
      }
    }
  }

  String _dailyKey(String date, String language, LeagueTier league) =>
      '${date}_${language}_${league.name}';

  String _weekLeagueId(String week, String language, LeagueTier league) =>
      '${week}_${language}_${league.name}';

  Future<List<Map<String, dynamic>>> _npcsFor(LeagueTier league, String locale) async {
    return (await _store.values('npc_players'))
        .where(
          (e) =>
              e['league'] == league.name &&
              (e['locale'] as String? ?? 'tr') == locale,
        )
        .toList();
  }

  DateTime get _now => _clock();

  Future<AppConfig> _config() async {
    final map = await _store.get('app_config', 'default');
    return map == null ? AppConfig.defaults() : AppConfig.fromMap(map);
  }

  Future<UserEntity?> _userOrNull() async {
    final id = await _store.getMeta(_currentUserKey);
    if (id == null || id.isEmpty) return null;
    final map = await _store.get('users', id);
    return map == null ? null : UserEntity.fromMap(map);
  }

  Future<UserEntity> _requireUser() async {
    final u = await _userOrNull();
    if (u == null) throw AppFailure(UserMessages.serverError, code: 'NO_USER');
    if (u.isBanned) throw AppFailure(UserMessages.banned, code: 'BANNED');
    return u;
  }

  Future<UserEntity> _saveUser(UserEntity user) async {
    final synced = user.stampCurrentLocale();
    await _store.put('users', synced.id, synced.toMap());
    return synced;
  }

  String _runMetaKey(UserEntity user, String name, {LeagueTier? league}) =>
      '${name}_${user.id}_${user.locale}_${(league ?? user.currentLeague).name}';

  Future<String?> _runMeta(UserEntity user, String name, {LeagueTier? league}) async {
    await _migrateEndlessLeague(user);
    return _store.getMeta(_runMetaKey(user, name, league: league));
  }

  /// Moves the old single run onto the player's current league once.
  Future<void> _migrateEndlessLeague(UserEntity user) async {
    final flag = 'endless_league_${user.id}_${user.locale}';
    if (await _store.getMeta(flag) == '1') return;
    final league = user.currentLeague;
    Future<void> copy(String name, String? fallback) async {
      final next = _runMetaKey(user, name, league: league);
      if (await _store.getMeta(next) != null) return;
      final legacy = await _store.getMeta('${name}_${user.id}_${user.locale}');
      final older = legacy ??
          (user.locale == 'tr' ? await _store.getMeta('${name}_${user.id}') : null);
      final value = older ?? fallback;
      if (value != null && value.isNotEmpty) {
        await _store.putMeta(next, value);
      }
    }

    await copy('endless_run', null);
    await copy('endless_run_at_risk', null);
    await copy('endless_wins', null);
    await copy('endless_finished', null);
    await copy('endless_best', user.endlessBest > 0 ? '${user.endlessBest}' : null);
    await _store.putMeta(flag, '1');
  }

  Future<int> _leagueBest(UserEntity user, String locale, LeagueTier league) async {
    final raw = await _store.getMeta(
      'endless_best_${user.id}_${locale}_${league.name}',
    );
    if (raw != null) return int.tryParse(raw) ?? 0;
    if (user.locale == locale && user.currentLeague == league) return user.endlessBest;
    final progress = user.progressByLocale[locale];
    if (progress != null && progress.league == league) return progress.endlessBest;
    return 0;
  }

  String _periodBestKey(
    String userId,
    String locale,
    LeagueTier league,
    String period,
    String periodId,
  ) =>
      'endless_${period}_${periodId}_${userId}_${locale}_${league.name}';

  Future<void> _stampMarathonPeriods(UserEntity user, int run) async {
    final stamps = [
      ('week', DateKeys.weekId(_now)),
      ('month', DateKeys.monthId(_now)),
      ('year', DateKeys.yearId(_now)),
    ];
    for (final stamp in stamps) {
      final key = _periodBestKey(
        user.id,
        user.locale,
        user.currentLeague,
        stamp.$1,
        stamp.$2,
      );
      final previous = int.tryParse(await _store.getMeta(key) ?? '') ?? 0;
      if (run > previous) await _store.putMeta(key, '$run');
    }
  }

  Future<({int best, int? rank})> _periodStanding(
    UserEntity user,
    LeagueTier league,
    String period,
    String periodId,
  ) async {
    final best = int.tryParse(
          await _store.getMeta(
                _periodBestKey(user.id, user.locale, league, period, periodId),
              ) ??
              '',
        ) ??
        0;
    if (best <= 0) return (best: 0, rank: null);
    var better = 0;
    for (final raw in await _store.values('users')) {
      final other = UserEntity.fromMap(raw);
      if (other.id == user.id) continue;
      final otherBest = int.tryParse(
            await _store.getMeta(
                  _periodBestKey(other.id, user.locale, league, period, periodId),
                ) ??
                '',
          ) ??
          0;
      if (otherBest > best) better++;
    }
    return (best: best, rank: better + 1);
  }

  Future<int?> _marathonRank(
    UserEntity user,
    LeagueTier league,
    int best,
    int played,
  ) async {
    if (best <= 0 && played <= 0) return null;
    var better = 0;
    for (final raw in await _store.values('users')) {
      final other = UserEntity.fromMap(raw);
      if (other.id == user.id) continue;
      final otherBest = await _leagueBest(other, user.locale, league);
      if (otherBest > best) better++;
    }
    return better + 1;
  }

  Future<UserEntity> _newUser({
    required AuthProvider provider,
    required bool anonymous,
    String? displayName,
    String? email,
    String? avatar,
  }) async {
    final now = _now;
    final id = _uuid.v4();
    final locale = await activeLocale();
    final user = UserEntity(
      id: id,
      displayName: displayName ??
          (anonymous
              ? await _uniqueGuestName(locale)
              : GameLocale.resolve(locale).playerName),
      email: email,
      authProvider: provider,
      isAnonymous: anonymous,
      level: 1,
      xp: 0,
      coin: 0,
      currentLeague: LeagueTier.bronze,
      streak: 0,
      longestStreak: 0,
      endlessBest: 0,
      shields: 0,
      freeHint1: 0,
      freeHint2: 0,
      isBanned: false,
      createdAt: now,
      lastLoginAt: now,
      locale: locale,
      avatar: avatar,
    );
    await _saveUser(user);
    await _store.put('wallets', id, {'balance': 0, 'updatedAt': now.toIso8601String()});
    await _store.putMeta(_currentUserKey, id);
    return _grantStarterCoins(user, registered: !anonymous);
  }

  static const _guestStartCoins = 175;
  static const _registerCoins = 350;

  Future<UserEntity> _grantStarterCoins(
    UserEntity user, {
    required bool registered,
  }) async {
    final kind = registered ? 'REGISTER_BONUS' : 'GUEST_START';
    final amount = registered ? _registerCoins : _guestStartCoins;
    if (await _store.getMeta('${kind}_${user.id}') == '1') return user;
    await _store.putMeta('${kind}_${user.id}', '1');
    final next = await _saveUser(user.copyWith(coin: user.coin + amount));
    await _creditWallet(user.id, amount, kind, user.id);
    return next;
  }

  @override
  Future<UserEntity?> currentUser() => _userOrNull();

  @override
  Future<UserEntity> signInAnonymously() async {
    final existing = await _userOrNull();
    if (existing != null) {
      if (existing.isAnonymous && _plainGuestName(existing.displayName)) {
        return _saveUser(
          existing.copyWith(
            displayName: await _uniqueGuestName(existing.locale),
            lastLoginAt: _now,
          ),
        );
      }
      return _saveUser(existing.copyWith(lastLoginAt: _now));
    }
    return _newUser(provider: AuthProvider.anonymous, anonymous: true);
  }

  @override
  Future<UserEntity> signInWithGoogle({
    required String googleId,
    String? email,
    String? displayName,
  }) async {
    final id = googleId.trim();
    if (id.isEmpty) {
      throw AppFailure(UserMessages.googleNotConfigured, code: 'NO_GOOGLE');
    }
    final linked = await _store.get('google_accounts', id);
    final linkedUserId = linked?['userId'] as String?;
    if (linkedUserId != null) {
      final map = await _store.get('users', linkedUserId);
      if (map != null) {
        final existing = UserEntity.fromMap(map);
        await _store.putMeta(_currentUserKey, existing.id);
        return _saveUser(
          existing.copyWith(
            lastLoginAt: _now,
            email: email ?? existing.email,
            isAnonymous: false,
          ),
        );
      }
    }
    final typed = displayName?.trim();
    final name = (typed != null && typed.length >= 2) ? typed : 'Oyuncu';
    final user = await _upgradeOrCreate(
      AuthProvider.google,
      name,
      email: email,
    );
    await _store.put('google_accounts', id, {
      'googleId': id,
      'userId': user.id,
      'email': email,
      'createdAt': _now.toIso8601String(),
    });
    return user;
  }

  @override
  Future<UserEntity> signInWithApple({String? displayName}) =>
      _upgradeOrCreate(AuthProvider.apple, displayName ?? 'Apple Oyuncu');

  @override
  Future<UserEntity> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? avatar,
  }) async {
    final normalized = PasswordHash.normalizeEmail(email);
    if (!PasswordHash.isValidEmail(normalized)) {
      throw AppFailure(UserMessages.invalidEmail, code: 'BAD_EMAIL');
    }
    if (password.length < 6) {
      throw AppFailure(UserMessages.weakPassword, code: 'WEAK_PASSWORD');
    }
    if (await _store.get('auth_accounts', normalized) != null) {
      throw AppFailure(UserMessages.emailTaken, code: 'EMAIL_TAKEN');
    }

    final nameFromEmail = normalized.split('@').first;
    final typed = displayName?.trim() ?? '';
    final name = typed.isNotEmpty
        ? _acceptNickname(typed)
        : (nameFromEmail.length >= 2 ? nameFromEmail : 'Oyuncu');

    final salt = _uuid.v4();
    final hash = PasswordHash.hash(password, salt);

    final existing = await _userOrNull();
    final keepId =
        (existing != null && existing.isAnonymous) ? existing.id : null;
    await _ensureNicknameFree(name, exceptUserId: keepId);
    late final UserEntity user;
    if (existing != null && existing.isAnonymous) {
      user = await _grantStarterCoins(
        await _saveUser(
        existing.copyWith(
          authProvider: AuthProvider.email,
          isAnonymous: false,
          email: normalized,
            displayName: name,
            avatar: avatar ?? existing.avatar,
          lastLoginAt: _now,
        ),
        ),
        registered: true,
      );
    } else {
      user = await _newUser(
        provider: AuthProvider.email,
        anonymous: false,
        displayName: name,
        email: normalized,
        avatar: avatar,
      );
    }

    await _store.put('auth_accounts', normalized, {
      'email': normalized,
      'passwordHash': hash,
      'salt': salt,
      'userId': user.id,
      'createdAt': _now.toIso8601String(),
    });
    return user;
  }

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalized = PasswordHash.normalizeEmail(email);
    if (!PasswordHash.isValidEmail(normalized)) {
      throw AppFailure(UserMessages.invalidEmail, code: 'BAD_EMAIL');
    }
    final account = await _store.get('auth_accounts', normalized);
    if (account == null) {
      throw AppFailure(UserMessages.badCredentials, code: 'BAD_CREDENTIALS');
    }
    final salt = account['salt'] as String? ?? '';
    final expected = account['passwordHash'] as String? ?? '';
    if (!PasswordHash.verify(password, salt, expected)) {
      throw AppFailure(UserMessages.badCredentials, code: 'BAD_CREDENTIALS');
    }
    final userId = account['userId'] as String;
    final map = await _store.get('users', userId);
    if (map == null) {
      throw AppFailure(UserMessages.serverError, code: 'NO_USER');
    }
    var user = UserEntity.fromMap(map);
    if (user.isBanned) {
      throw AppFailure(UserMessages.banned, code: 'BANNED');
    }
    user = await _saveUser(
      user.copyWith(
        email: normalized,
        authProvider: AuthProvider.email,
        isAnonymous: false,
        lastLoginAt: _now,
      ),
    );
    await _store.putMeta(_currentUserKey, user.id);
    return user;
  }

  Future<UserEntity> _upgradeOrCreate(
    AuthProvider provider,
    String name, {
    String? email,
  }) async {
    final existing = await _userOrNull();
    if (existing != null && existing.isAnonymous) {
      return _grantStarterCoins(
        await _saveUser(
        existing.copyWith(
          authProvider: provider,
          isAnonymous: false,
            email: email ?? existing.email,
            displayName: _guestLabel(existing.displayName) ? name : existing.displayName,
          lastLoginAt: _now,
        ),
        ),
        registered: true,
      );
    }
    if (existing != null) {
      return _saveUser(
        existing.copyWith(
          lastLoginAt: _now,
          email: email ?? existing.email,
        ),
      );
    }
    return _newUser(
      provider: provider,
      anonymous: false,
      displayName: name,
      email: email,
    );
  }

  @override
  Future<UserEntity> setDisplayName(String name) async {
    final user = await _requireUser();
    final trimmed = _acceptNickname(name);
    await _ensureNicknameFree(trimmed, exceptUserId: user.id);
    return _saveUser(user.copyWith(displayName: trimmed));
  }

  @override
  Future<UserEntity> updateIdentity({
    String? firstName,
    String? lastName,
    String? nickname,
    String? avatar,
  }) async {
    var user = await _requireUser();
    if (user.isAnonymous) {
      throw AppFailure('Ad, soyad ve takma ad hesapta düzenlenir.', code: 'ACCOUNT');
    }
    if (firstName != null) {
      final value = _acceptPersonName(firstName);
      user = user.copyWith(firstName: value, clearFirstName: value == null);
    }
    if (lastName != null) {
      final value = _acceptPersonName(lastName);
      user = user.copyWith(lastName: value, clearLastName: value == null);
    }
    if (nickname != null) {
      final value = _acceptNickname(nickname);
      await _ensureNicknameFree(value, exceptUserId: user.id);
      user = user.copyWith(displayName: value);
    }
    if (avatar != null && avatar.isNotEmpty) {
      user = user.copyWith(avatar: avatar);
    }
    return _saveUser(user);
  }

  String _acceptNickname(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.length < 2) {
      throw AppFailure(UserMessages.nicknameShort, code: 'SHORT_NICK');
    }
    if (name.length > 20) {
      throw AppFailure(UserMessages.nicknameLong, code: 'NICK_LONG');
    }
    if (!RegExp(r'^[\p{L}\p{N}]+(?: [\p{L}\p{N}]+)*$', unicode: true).hasMatch(name)) {
      throw AppFailure(UserMessages.nicknameBad, code: 'NICK_BAD');
    }
    return name;
  }

  String? _acceptPersonName(String raw) {
    final name = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (name.isEmpty) return null;
    if (name.length > 40 ||
        !RegExp(r'^[\p{L}]+(?:[ -][\p{L}]+)*$', unicode: true).hasMatch(name)) {
      throw AppFailure(UserMessages.personNameBad, code: 'NAME_BAD');
    }
    return name;
  }

  Future<void> _ensureNicknameFree(String name, {String? exceptUserId}) async {
    final key = _nickKey(name);
    final users = await _store.values('users');
    for (final map in users) {
      final id = map['id'] as String?;
      if (id == exceptUserId) continue;
      final existing = (map['displayName'] as String? ?? '').trim();
      if (existing.isEmpty) continue;
      final anon = map['isAnonymous'] as bool? ?? false;
      if (anon && _plainGuestName(existing)) continue;
      if (_nickKey(existing) == key) {
        throw AppFailure(UserMessages.nicknameTaken, code: 'NICK_TAKEN');
      }
    }
  }

  String _nickKey(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  @override
  Future<UserEntity> completeOnboarding() async {
    final user = await _requireUser();
    return _saveUser(user.copyWith(onboardingDone: true));
  }

  @override
  Future<UserEntity> updateSettings({
    bool? soundOn,
    bool? hapticOn,
    bool? animationsOn,
    bool? notificationsOn,
  }) async {
    final user = await _requireUser();
    return _saveUser(
      user.copyWith(
        soundOn: soundOn,
        hapticOn: hapticOn,
        animationsOn: animationsOn,
        notificationsOn: notificationsOn,
      ),
    );
  }

  @override
  Future<void> signOut() async {
    await _store.putMeta(_currentUserKey, '');
  }

  @override
  Future<bool> hasChosenLocale() async {
    final stored = await _store.getMeta(_deviceLocaleKey);
    if (stored != null && stored.isNotEmpty) return true;
    return await _userOrNull() != null;
  }

  @override
  Future<String> activeLocale() async {
    final user = await _userOrNull();
    if (user != null) return GameLocale.resolve(user.locale).id;
    return GameLocale.resolve(await _store.getMeta(_deviceLocaleKey)).id;
  }

  @override
  Future<UserEntity?> setLocale(String localeId) async {
    final locale = GameLocale.resolve(localeId);
    await _store.putMeta(_deviceLocaleKey, locale.id);
    final user = await _userOrNull();
    if (user == null) return null;
    return _saveUser(user.switchToLocale(locale.id));
  }

  @override
  Future<UserEntity> setLeague(LeagueTier league) async {
    final user = await _requireUser();
    await _migrateEndlessLeague(user);
    final best = int.tryParse(
          await _store.getMeta(_runMetaKey(user, 'endless_best', league: league)) ?? '',
        ) ??
        0;
    return _saveUser(user.copyWith(currentLeague: league, endlessBest: best));
  }

  Future<UserEntity> _applyMissedStreak(UserEntity user) async {
    final today = DateKeys.dayKey(_now);
    final last = user.lastDailyFor(user.locale);
    if (last == null || last == today) return user;
    final gap = DateKeys.daysBetween(last, today);
    if (gap <= 1) return user;
    var shields = user.shields;
    var streak = user.streak;
    var missed = gap - 1;
    while (missed > 0) {
      if (shields > 0) {
        shields -= 1;
      } else {
        streak = 0;
        break;
      }
      missed -= 1;
    }
    return _saveUser(user.copyWith(shields: shields, streak: streak));
  }

  @override
  Future<HomeSnapshot> homeSnapshot() async {
    var user = await _requireUser();
    user = await _applyMissedStreak(user);
    user = await _maybeRolloverLeague(user);
    final today = DateKeys.dayKey(_now);
    final open = await _findActive(user.id, GameType.daily, language: user.locale);
    final openToday = open != null && _sessionStillOpen(open);
    final finished = await _maxFinishedDailyIndex(user, today);
    final stored = await _storedDailyCount(today, user.locale, user.currentLeague);
    final DailyStatus daily;
    final int dailyIndex;
    final bool dailyNeedsAd;
    if (openToday) {
      daily = DailyStatus.started;
      dailyIndex = _sessionDailyIndex(open);
      dailyNeedsAd = false;
    } else if (finished == 0) {
      daily = DailyStatus.available;
      dailyIndex = 1;
      dailyNeedsAd = false;
    } else if (stored >= finished + 1) {
      daily = DailyStatus.completed;
      dailyIndex = finished + 1;
      dailyNeedsAd = !await _hasDailyPermit(
        user.id,
        today,
        user.locale,
        user.currentLeague,
        finished + 1,
      );
    } else {
      daily = DailyStatus.completed;
      dailyIndex = finished + 1;
      dailyNeedsAd = true;
    }
    final rewardAvailable = user.lastRewardDate != today;
    final week = DateKeys.weekId(_now);
    final standings = user.canJoinLeague ? await _ensureLeague(user) : <LeaderboardEntry>[];
    final me = standings.where((e) => e.isCurrentUser).firstOrNull;
    final periods = user.canJoinLeague
        ? await _homePeriodStandings(user, week)
        : const <PeriodStandingBrief>[];
    return HomeSnapshot(
      user: user,
      dailyStatus: daily,
      dailyRewardAvailable: rewardAvailable,
      rewardCycleDay: user.rewardCycleDay,
      weekId: week,
      leagueRank: me?.rank,
      leaguePoints: me?.points ?? 0,
      offline: false,
      periodStandings: periods,
      dailyIndex: dailyIndex,
      dailyNeedsAd: dailyNeedsAd,
    );
  }

  Future<List<PeriodStandingBrief>> _homePeriodStandings(
    UserEntity user,
    String weekId,
  ) async {
    Future<PeriodStandingBrief> brief(RankPeriod period, String periodId) async {
      final rows = period == RankPeriod.week
          ? await _ensureLeague(user)
          : await _periodStandings(period, periodId, user);
      final mine = rows.where((e) => e.isCurrentUser).firstOrNull;
      return PeriodStandingBrief(
        period: period,
        periodId: periodId,
        rank: mine?.rank,
        points: mine?.points ?? 0,
      );
    }

    return [
      await brief(RankPeriod.week, weekId),
      await brief(RankPeriod.month, DateKeys.monthId(_now)),
      await brief(RankPeriod.season, DateKeys.seasonId(_now)),
      await brief(RankPeriod.year, DateKeys.yearId(_now)),
    ];
  }

  Future<List<WordEntity>> _playable(int length, {String? language}) async {
    final lang = language ?? (await _userOrNull())?.locale ?? 'tr';
    final all = await _store.values('words');
    return all
        .map(WordEntity.fromMap)
        .where((w) => w.playable && w.length == length && w.language == lang)
        .toList();
  }

  Future<WordEntity> _pickWord(LeagueTier league, {String? avoidId, String? language}) async {
    final list = await _playable(league.wordLength, language: language);
    if (list.isEmpty) {
      throw AppFailure('Uygun kelime bulunamadı.', code: 'NO_WORD');
    }
    final filtered = list.where((w) => w.id != avoidId).toList();
    final pool = filtered.isEmpty ? list : filtered;
    return pool[_random.nextInt(pool.length)];
  }

  Future<WordEntity> _dailyWord(UserEntity user) async {
    final day = DateKeys.dayKey(_now);
    final locale = user.locale;
    final league = user.currentLeague;
    final keyed = _dailyKey(day, locale, league);
    final legacy = '${day}_${league.name}';
    var existing = await _store.get('daily_games', keyed);
    if (existing == null && locale == 'tr') {
      existing = await _store.get('daily_games', legacy);
    }
    if (existing != null) {
      final word = await _store.get('words', existing['wordId'] as String);
      if (word != null) {
        final entity = WordEntity.fromMap(word);
        if (entity.playable &&
            entity.language == locale &&
            entity.length == league.wordLength) {
          return entity;
        }
      }
    }
    // Fallback when admin has not assigned (or assignment is invalid).
    final picked = await _pickWord(league, language: locale);
    final row = {
      'date': day,
      'league': league.name,
      'language': locale,
      'wordId': picked.id,
      'index': 1,
      'isActive': true,
      'source': 'auto',
      'createdAt': _now.toIso8601String(),
    };
    await _store.put('daily_games', keyed, row);
    if (locale == 'tr') {
      await _store.put('daily_games', legacy, row);
    }
    return picked;
  }

  Future<GameSessionView> _sessionToView(
    Map<String, dynamic> raw, {
    GameOutcome? outcome,
  }) async {
    final guesses = (raw['guesses'] as List? ?? const [])
        .map((e) {
          final m = Map<String, dynamic>.from(e as Map);
          return EvaluatedGuess(
            guess: m['guess'] as String,
            statuses: (m['statuses'] as List)
                .map((s) => LetterStatus.values.byName(s as String))
                .toList(),
          );
        })
        .toList();
    final wordMap = await _store.get('words', raw['wordId'] as String);
    final locale = GameLocale.resolve(
      wordMap?['language'] as String? ?? raw['language'] as String? ?? 'tr',
    );
    final keyboard = <String, LetterStatus>{};
    for (final g in guesses) {
      final letters = locale.letters(g.guess);
      for (var i = 0; i < letters.length; i++) {
        final ch = letters[i];
        final st = g.statuses[i];
        final prev = keyboard[ch];
        if (prev == null || _rank(st) > _rank(prev)) {
          keyboard[ch] = st;
        }
      }
    }
    final revealedLetters = <int, String>{};
    final hintMap = Map<String, dynamic>.from(raw['revealedLetters'] as Map? ?? {});
    for (final e in hintMap.entries) {
      revealedLetters[int.parse(e.key)] = e.value as String;
    }
    final status = GameStatus.values.byName(raw['status'] as String);
    final finished = status == GameStatus.won ||
        status == GameStatus.lost ||
        status == GameStatus.completed;
    final answer = finished && wordMap != null
        ? WordEntity.fromMap(wordMap).displayWord
        : null;
    final solved = finished ? await _solved(raw) : null;
    return GameSessionView(
      sessionId: raw['id'] as String,
      gameType: GameType.values.byName(raw['gameType'] as String),
      wordLength: raw['wordLength'] as int,
      maxAttempts: raw['maxAttempts'] as int,
      currentAttempt: raw['currentAttempt'] as int,
      guesses: guesses,
      keyboard: keyboard,
      status: status,
      hintUsed: raw['hintUsed'] as bool? ?? false,
      revealedLetters: revealedLetters,
      letterHintsOnRow: raw['letterHintsOnRow'] as int? ?? 0,
      definitionHint: raw['definitionHint'] as String?,
      startedAt: DateTime.parse(raw['startedAt'] as String),
      expiresAt: DateTime.parse(raw['expiresAt'] as String),
      outcome: outcome,
      answer: answer,
      solved: solved,
      dailyIndex: raw['gameType'] == GameType.daily.name ? _sessionDailyIndex(raw) : 1,
      wordId: finished ? (raw['wordId'] as String? ?? '') : '',
    );
  }

  Future<bool?> _solved(Map<String, dynamic> raw) async {
    final stored = raw['won'];
    if (stored is bool) return stored;
    final sessionId = raw['id'] as String?;
    if (sessionId == null) return null;
    for (final row in await _store.values('game_results')) {
      if (row['sessionId'] == sessionId && row['won'] is bool) {
        return row['won'] as bool;
      }
    }
    return null;
  }

  int _rank(LetterStatus s) => switch (s) {
        LetterStatus.correct => 3,
        LetterStatus.present => 2,
        LetterStatus.absent => 1,
        LetterStatus.empty => 0,
      };

  DateTime _expiresAtFor(GameType type) {
    if (type == GameType.daily) {
      final n = _now;
      return DateTime(n.year, n.month, n.day + 1);
    }
    return _now.add(const Duration(minutes: AppConstants.sessionTimeoutMinutes));
  }

  bool _sessionStillOpen(Map<String, dynamic> raw) {
    if (raw['status'] != GameStatus.active.name) return false;
    if (raw['gameType'] == GameType.daily.name) {
      final started = DateTime.parse(raw['startedAt'] as String);
      return DateKeys.dayKey(started) == DateKeys.dayKey(_now);
    }
    return DateTime.parse(raw['expiresAt'] as String).isAfter(_now);
  }

  int _sessionDailyIndex(Map<String, dynamic> raw) {
    final stored = raw['dailyIndex'];
    if (stored is int && stored > 0) return stored;
    return 1;
  }

  bool _dailySessionFinished(Map<String, dynamic> session, UserEntity user, String today) {
    if (session['userId'] != user.id) return false;
    if (session['gameType'] != GameType.daily.name) return false;
    final language = session['language'] as String? ?? 'tr';
    if (language != user.locale) return false;
    final status = session['status'] as String?;
    final finished = status == GameStatus.won.name ||
        status == GameStatus.lost.name ||
        status == GameStatus.completed.name;
    if (!finished) return false;
    final started = DateTime.tryParse(session['startedAt'] as String? ?? '');
    return started != null && DateKeys.dayKey(started) == today;
  }

  Future<int> _maxFinishedDailyIndex(UserEntity user, String today) async {
    var maxIndex = 0;
    for (final session in await _store.values('game_sessions')) {
      if (!_dailySessionFinished(session, user, today)) continue;
      final index = _sessionDailyIndex(session);
      if (index > maxIndex) maxIndex = index;
    }
    return maxIndex;
  }

  Future<Map<String, dynamic>?> _finishedDailySession(
    UserEntity user,
    String today,
    int index,
  ) async {
    Map<String, dynamic>? found;
    for (final session in await _store.values('game_sessions')) {
      if (!_dailySessionFinished(session, user, today)) continue;
      if (_sessionDailyIndex(session) != index) continue;
      found = session;
    }
    return found;
  }

  String _dailySlotKey(String date, String language, LeagueTier league, int index) {
    final base = _dailyKey(date, language, league);
    return index <= 1 ? base : '${base}_$index';
  }

  Future<T> _lockedDaily<T>(String key, Future<T> Function() action) async {
    final previous = _dailySlotLocks[key] ?? Future<void>.value();
    final done = Completer<void>();
    _dailySlotLocks[key] = done.future;
    try {
      await previous;
      return await action();
    } finally {
      done.complete();
      if (identical(_dailySlotLocks[key], done.future)) {
        _dailySlotLocks.remove(key);
      }
    }
  }

  Future<Map<String, dynamic>?> _readDailySlot(
    String day,
    String locale,
    LeagueTier league,
    int index,
  ) async {
    var existing = await _store.get('daily_games', _dailySlotKey(day, locale, league, index));
    if (existing == null && index <= 1 && locale == 'tr') {
      existing = await _store.get('daily_games', '${day}_${league.name}');
    }
    return existing;
  }

  Future<int> _storedDailyCount(String day, String locale, LeagueTier league) async {
    var count = 0;
    while (await _readDailySlot(day, locale, league, count + 1) != null) {
      count++;
      if (count > 200) break;
    }
    return count;
  }

  Future<Set<String>> _usedDailyWordIds(String day, String locale, LeagueTier league) async {
    final ids = <String>{};
    final count = await _storedDailyCount(day, locale, league);
    for (var index = 1; index <= count; index++) {
      final row = await _readDailySlot(day, locale, league, index);
      final id = row?['wordId'] as String?;
      if (id != null) ids.add(id);
    }
    return ids;
  }

  Future<WordEntity> _wordForSlot(Map<String, dynamic> slot) async {
    final word = await _store.get('words', slot['wordId'] as String);
    if (word == null) {
      throw AppFailure(UserMessages.serverError, code: 'NO_WORD');
    }
    return WordEntity.fromMap(word);
  }

  String _dailyPermitKey(
    String userId,
    String day,
    String locale,
    LeagueTier league,
    int index,
  ) =>
      'daily_permit_${userId}_${day}_${locale}_${league.name}_$index';

  Future<bool> _hasDailyPermit(
    String userId,
    String day,
    String locale,
    LeagueTier league,
    int index,
  ) async =>
      await _store.getMeta(_dailyPermitKey(userId, day, locale, league, index)) ==
      '1';

  /// Fills a missing shared word after a finish, when the start did not queue it.
  /// Does not let that player start it. Never writes past [AppConstants.maxDailySlots].
  Future<bool> _ensureNextDailySlot(UserEntity user) async {
    final day = DateKeys.dayKey(_now);
    final locale = user.locale;
    final league = user.currentLeague;
    return _lockedDaily('${day}_${locale}_${league.name}', () async {
      final finished = await _maxFinishedDailyIndex(user, day);
      final stored = await _storedDailyCount(day, locale, league);
      if (finished < 1) return false;
      if (finished < stored) return true;
      if (stored >= AppConstants.maxDailySlots) return false;
      return _putFreshDailySlot(
        day: day,
        locale: locale,
        league: league,
        index: stored + 1,
        source: 'ad',
      );
    });
  }

  /// Writes the next shared word when [startedIndex] begins. A filled slot stays.
  Future<void> _queueFollowingDailySlot({
    required String day,
    required String locale,
    required LeagueTier league,
    required int startedIndex,
  }) async {
    final following = startedIndex + 1;
    if (following > AppConstants.maxDailySlots) return;
    await _lockedDaily('${day}_${locale}_${league.name}', () async {
      await _putFreshDailySlot(
        day: day,
        locale: locale,
        league: league,
        index: following,
        source: 'start',
      );
    });
  }

  Future<bool> _putFreshDailySlot({
    required String day,
    required String locale,
    required LeagueTier league,
    required int index,
    required String source,
  }) async {
    if (index < 1 || index > AppConstants.maxDailySlots) return false;
    if (await _readDailySlot(day, locale, league, index) != null) return true;
    final avoid = await _usedDailyWordIds(day, locale, league);
    final list = await _playable(league.wordLength, language: locale);
    final pool = list.where((word) => !avoid.contains(word.id)).toList();
    if (pool.isEmpty) return false;
    final picked = pool[_random.nextInt(pool.length)];
    await _store.put('daily_games', _dailySlotKey(day, locale, league, index), {
      'date': day,
      'league': league.name,
      'language': locale,
      'wordId': picked.id,
      'index': index,
      'isActive': true,
      'source': source,
      'createdAt': _now.toIso8601String(),
    });
    return true;
  }

  @override
  Future<bool> prepareNextDaily() async {
    final user = await _requireUser();
    return _ensureNextDailySlot(user);
  }

  /// Creates the next shared daily when it is missing and lets this player start it.
  /// Coins stay unchanged. Another player still needs their own proof.
  Future<bool> grantDailyNextProof({
    required String userId,
    required String transactionId,
  }) async {
    if (userId.isEmpty || transactionId.isEmpty) return false;
    final seen = 'admob_$transactionId';
    if (await _store.getMeta(seen) == '1') return true;
    final map = await _store.get('users', userId);
    if (map == null) return false;
    final user = UserEntity.fromMap(map);
    final created = await _ensureNextDailySlot(user);
    if (!created) return false;
    final day = DateKeys.dayKey(_now);
    final next = await _maxFinishedDailyIndex(user, day) + 1;
    if (next > AppConstants.maxDailySlots) return false;
    if (await _readDailySlot(day, user.locale, user.currentLeague, next) == null) {
      return false;
    }
    await _store.putMeta(
      _dailyPermitKey(userId, day, user.locale, user.currentLeague, next),
      '1',
    );
    await _store.putMeta(seen, '1');
    return true;
  }

  Future<Map<String, dynamic>?> _findActive(
    String userId,
    GameType type, {
    String? language,
  }) async {
    final all = await _store.values('game_sessions');
    for (final s in all) {
      if (s['userId'] == userId &&
          s['gameType'] == type.name &&
          s['status'] == GameStatus.active.name) {
        if (language != null) {
          final sessionLang = s['language'] as String? ?? 'tr';
          if (sessionLang != language) continue;
        }
        return s;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _createSession({
    required UserEntity user,
    required GameType type,
    required WordEntity word,
    int dailyIndex = 1,
  }) async {
    final id = _uuid.v4();
    final now = _now;
    final map = <String, dynamic>{
      'id': id,
      'userId': user.id,
      'gameType': type.name,
      'wordId': word.id,
      'language': word.language,
      'wordLength': word.length,
      'maxAttempts': user.currentLeague.maxAttempts,
      'currentAttempt': 0,
      'status': GameStatus.active.name,
      'hintUsed': false,
      'hint1': false,
      'definitionHint': null,
      'revealedLetters': <String, String>{},
      'guesses': <Map<String, dynamic>>[],
      'startedAt': now.toIso8601String(),
      'expiresAt': _expiresAtFor(type).toIso8601String(),
      'endlessStreak': 0,
      if (type == GameType.daily) 'dailyIndex': dailyIndex,
    };
    await _store.put('game_sessions', id, map);
    return map;
  }

  @override
  Future<GameSessionView> startDaily() async {
    var user = await _requireUser();
    if (!user.canPlayDaily) {
      throw AppFailure(UserMessages.banned, code: 'BANNED');
    }
    user = await _applyMissedStreak(user);
    final today = DateKeys.dayKey(_now);
    final existing = await _findActive(user.id, GameType.daily, language: user.locale);
    if (existing != null && _sessionStillOpen(existing)) {
      return _sessionToView(existing);
    }
    final finished = await _maxFinishedDailyIndex(user, today);
    final next = finished + 1;
    final league = user.currentLeague;
    final locale = user.locale;
    if (next > AppConstants.maxDailySlots) {
      final last = await _finishedDailySession(user, today, finished);
      if (last != null) return _sessionToView(last);
      throw AppFailure(UserMessages.dailyCompleted, code: 'DAILY_DONE');
    }
    var slot = await _readDailySlot(today, locale, league, next);
    if (slot == null && next == 1) {
      final word = await _lockedDaily(
        '${today}_${locale}_${league.name}',
        () => _dailyWord(user),
      );
      final session = await _createSession(
        user: user,
        type: GameType.daily,
        word: word,
        dailyIndex: 1,
      );
      await _queueFollowingDailySlot(
        day: today,
        locale: locale,
        league: league,
        startedIndex: 1,
      );
      return _sessionToView(session);
    }
    if (slot == null ||
        (next > 1 &&
            !await _hasDailyPermit(user.id, today, locale, league, next))) {
      final last = await _finishedDailySession(user, today, finished);
      if (last != null) return _sessionToView(last);
      throw AppFailure(UserMessages.dailyCompleted, code: 'DAILY_DONE');
    }
    final word = await _wordForSlot(slot);
    final session = await _createSession(
      user: user,
      type: GameType.daily,
      word: word,
      dailyIndex: next,
    );
    await _queueFollowingDailySlot(
      day: today,
      locale: locale,
      league: league,
      startedIndex: next,
    );
    return _sessionToView(session);
  }

  Future<void> _markFreshMarathonOpen(UserEntity user) async {
    final run = int.tryParse(await _runMeta(user, 'endless_run') ?? '0') ?? 0;
    final atRisk =
        int.tryParse(await _runMeta(user, 'endless_run_at_risk') ?? '') ?? 0;
    if (run == 0 && atRisk == 0) {
      await _store.putMeta(_runMetaKey(user, 'endless_open'), '1');
    }
  }

  @override
  Future<GameSessionView> startEndless() async {
    final user = await _requireUser();
    await _migrateEndlessLeague(user);
    final existing = await _findActive(user.id, GameType.endless, language: user.locale);
    if (existing != null && _sessionStillOpen(existing)) {
      await _markFreshMarathonOpen(user);
      return _sessionToView(existing);
    }
    final word = await _pickWord(user.currentLeague, language: user.locale);
    final session = await _createSession(user: user, type: GameType.endless, word: word);
    final run = int.tryParse(await _runMeta(user, 'endless_run') ?? '0') ?? 0;
    session['endlessStreak'] = run;
    await _store.put('game_sessions', session['id'] as String, session);
    await _markFreshMarathonOpen(user);
    return _sessionToView(session);
  }

  static const _presence = Duration(seconds: 20);
  static const _away = Duration(minutes: 5);
  static const _roomCap = 10;

  @override
  Future<MatchSnapshot> duelCreate() async {
    final user = await _requireUser();
    final open = await _duelFor(user.id, openOnly: true);
    if (open != null) return _duelView(open, user.id);
    final duel = {
      'id': _uuid.v4(),
      'code': await _uniqueCode('duels'),
      'hostId': user.id,
      'locale': user.locale,
      'league': user.currentLeague.name,
      'wordId': null,
      'status': 'lobby',
      'createdAt': _now.toIso8601String(),
      'players': [_slot(user, null)],
    };
    await _store.put('duels', duel['id'] as String, duel);
    return _duelView(duel, user.id);
  }

  @override
  Future<MatchSnapshot> duelJoin(String code) async {
    final user = await _requireUser();
    final duel = await _duelByCode(code);
    if (duel == null) {
      throw AppFailure('Düello kodu bulunamadı.', code: 'DUEL_MISSING');
    }
    final status = duel['status'] as String? ?? '';
    if (status == 'done') {
      throw AppFailure('Bu düello kapandı.', code: 'DUEL_DONE');
    }
    if (status == 'playing') {
      throw AppFailure('Düello başladı.', code: 'DUEL_STARTED');
    }
    if (_hasPlayer(duel, user.id)) return _duelView(duel, user.id);
    final players = _playersOf(duel);
    if (players.length >= 2) {
      throw AppFailure('Bu düelloda yer yok.', code: 'DUEL_FULL');
    }
    await _leaveOtherDuels(user.id, keep: duel['id'] as String);
    players.add(_slot(user, null));
    duel['players'] = players;
    await _store.put('duels', duel['id'] as String, duel);
    return _duelView(duel, user.id);
  }

  @override
  Future<MatchSnapshot> duelPoll() async {
    final user = await _requireUser();
    final open = await _duelFor(user.id, openOnly: true);
    if (open != null) {
      _touch(open, user.id);
      await _sweepLobby(open);
      await _expireAbsent(open);
      if (open['status'] == 'playing' && await _playersDone(_playersOf(open))) {
        open['status'] = 'done';
      }
      await _store.put('duels', open['id'] as String, open);
      return _duelView(open, user.id);
    }
    final done = await _duelFor(user.id, openOnly: false);
    if (done != null) return _duelView(done, user.id);
    return MatchSnapshot(kind: 'duel', status: 'idle', rows: const []);
  }

  @override
  Future<MatchSnapshot> duelCancel() async {
    final user = await _requireUser();
    final open = await _duelFor(user.id, openOnly: true);
    if (open == null || open['status'] == 'playing') {
      if (open == null) {
        return MatchSnapshot(kind: 'duel', status: 'idle', rows: const []);
      }
      return _duelView(open, user.id);
    }
    if (open['hostId'] == user.id) {
      open['status'] = 'done';
      await _store.put('duels', open['id'] as String, open);
      return _duelView(open, user.id);
    }
    open['players'] =
        _playersOf(open).where((p) => p['userId'] != user.id).toList();
    await _store.put('duels', open['id'] as String, open);
    return MatchSnapshot(kind: 'duel', status: 'idle', rows: const []);
  }

  @override
  Future<MatchSnapshot> duelStart() async {
    final user = await _requireUser();
    final duel = await _duelFor(user.id, openOnly: true);
    if (duel == null || duel['status'] != 'lobby') {
      throw AppFailure('Düello kodu bulunamadı.', code: 'DUEL_MISSING');
    }
    if (duel['hostId'] != user.id) {
      throw AppFailure('Sadece davet eden başlatabilir.', code: 'DUEL_HOST');
    }
    final players = _playersOf(duel);
    if (players.length < 2) {
      throw AppFailure('Arkadaşın henüz katılmadı.', code: 'DUEL_WAIT');
    }
    final league = LeagueTier.values.byName(duel['league'] as String);
    final word = await _pickWord(
      league,
      language: duel['locale'] as String? ?? user.locale,
    );
    final startAt = _now.add(const Duration(seconds: 3));
    final next = <Map<String, dynamic>>[];
    for (final p in players) {
      final map = await _store.get('users', p['userId'] as String);
      if (map == null) continue;
      final member = UserEntity.fromMap(map);
      final session = await _createSession(
        user: member,
        type: GameType.duel,
        word: word,
      );
      session['startedAt'] = startAt.toIso8601String();
      await _store.put('game_sessions', session['id'] as String, session);
      p['sessionId'] = session['id'];
      p['lastSeen'] = _now.toIso8601String();
      next.add(p);
    }
    duel['players'] = next;
    duel['wordId'] = word.id;
    duel['status'] = 'playing';
    duel['startedAt'] = startAt.toIso8601String();
    await _store.put('duels', duel['id'] as String, duel);
    return _duelView(duel, user.id);
  }

  @override
  Future<MatchSnapshot> roomCreate() async {
    final user = await _requireUser();
    final open = await _roomFor(user.id, openOnly: true);
    if (open != null) return _roomView(open, user.id);
    final room = {
      'id': _uuid.v4(),
      'code': await _uniqueRoomCode(),
      'hostId': user.id,
      'locale': user.locale,
      'league': user.currentLeague.name,
      'wordId': null,
      'status': 'lobby',
      'createdAt': _now.toIso8601String(),
      'players': [_slot(user, null)],
    };
    await _store.put('rooms', room['id'] as String, room);
    return _roomView(room, user.id);
  }

  @override
  Future<MatchSnapshot> roomJoin(String code) async {
    final user = await _requireUser();
    final normalized = code.trim();
    Map<String, dynamic>? room;
    for (final row in await _store.values('rooms')) {
      if (row['code'] == normalized) {
        room = Map<String, dynamic>.from(row);
        break;
      }
    }
    if (room == null) throw AppFailure('Oda bulunamadı.', code: 'ROOM_MISSING');
    final status = room['status'] as String? ?? '';
    if (status == 'done') throw AppFailure('Bu oda kapandı.', code: 'ROOM_DONE');
    if (status == 'playing') {
      throw AppFailure('Oyun başladı.', code: 'ROOM_STARTED');
    }
    if (_hasPlayer(room, user.id)) return _roomView(room, user.id);
    final players = _playersOf(room);
    if (players.length >= _roomCap) {
      throw AppFailure('Oda dolu.', code: 'ROOM_FULL');
    }
    await _leaveOtherLobbies(user.id, keep: room['id'] as String);
    players.add(_slot(user, null));
    room['players'] = players;
    await _store.put('rooms', room['id'] as String, room);
    return _roomView(room, user.id);
  }

  @override
  Future<MatchSnapshot> roomPoll() async {
    final user = await _requireUser();
    final open = await _roomFor(user.id, openOnly: true);
    if (open != null) {
      _touch(open, user.id);
      await _sweepLobby(open);
      await _expireAbsent(open);
      if (open['status'] == 'playing' && await _playersDone(_playersOf(open))) {
        open['status'] = 'done';
      }
      await _store.put('rooms', open['id'] as String, open);
      return _roomView(open, user.id);
    }
    final done = await _roomFor(user.id, openOnly: false);
    if (done != null) return _roomView(done, user.id);
    return MatchSnapshot(kind: 'room', status: 'idle', rows: const []);
  }

  @override
  Future<MatchSnapshot> roomLeave() async {
    final user = await _requireUser();
    final open = await _roomFor(user.id, openOnly: true);
    if (open == null || open['status'] == 'playing') {
      if (open == null) {
        return MatchSnapshot(kind: 'room', status: 'idle', rows: const []);
      }
      return _roomView(open, user.id);
    }
    if (open['hostId'] == user.id) {
      open['status'] = 'done';
      await _store.put('rooms', open['id'] as String, open);
      return _roomView(open, user.id);
    }
    open['players'] =
        _playersOf(open).where((p) => p['userId'] != user.id).toList();
    await _store.put('rooms', open['id'] as String, open);
    return MatchSnapshot(kind: 'room', status: 'idle', rows: const []);
  }

  @override
  Future<MatchSnapshot> roomStart() async {
    final user = await _requireUser();
    final room = await _roomFor(user.id, openOnly: true);
    if (room == null || room['status'] != 'lobby') {
      throw AppFailure('Oda bulunamadı.', code: 'ROOM_MISSING');
    }
    if (room['hostId'] != user.id) {
      throw AppFailure('Sadece ev sahibi başlatabilir.', code: 'ROOM_HOST');
    }
    final players = _playersOf(room);
    if (players.isEmpty) {
      throw AppFailure('Oda bulunamadı.', code: 'ROOM_MISSING');
    }
    final league = LeagueTier.values.byName(room['league'] as String);
    final word = await _pickWord(
      league,
      language: room['locale'] as String? ?? user.locale,
    );
    final startAt = _now.add(const Duration(seconds: 3));
    final next = <Map<String, dynamic>>[];
    for (final p in players) {
      final map = await _store.get('users', p['userId'] as String);
      if (map == null) continue;
      final member = UserEntity.fromMap(map);
      final session = await _createSession(
        user: member,
        type: GameType.room,
        word: word,
      );
      session['startedAt'] = startAt.toIso8601String();
      await _store.put('game_sessions', session['id'] as String, session);
      p['sessionId'] = session['id'];
      p['lastSeen'] = _now.toIso8601String();
      next.add(p);
    }
    room['players'] = next;
    room['wordId'] = word.id;
    room['status'] = 'playing';
    room['startedAt'] = startAt.toIso8601String();
    await _store.put('rooms', room['id'] as String, room);
    return _roomView(room, user.id);
  }

  @override
  Future<MatchSnapshot> matchSnapshot(String kind) {
    if (kind == 'room') return roomPoll();
    return duelPoll();
  }

  @override
  Future<GameSessionView> openAssigned(GameType type) async {
    final user = await _requireUser();
    final row = type == GameType.room
        ? await _roomFor(user.id, openOnly: false)
        : await _duelFor(user.id, openOnly: false);
    if (row == null) throw AppFailure('Eşleşme yok.', code: 'NO_MATCH');
    String? sessionId;
    for (final p in _playersOf(row)) {
      if (p['userId'] == user.id) sessionId = p['sessionId'] as String?;
    }
    if (sessionId == null) {
      throw AppFailure('Oyun henüz başlamadı.', code: 'NOT_STARTED');
    }
    final raw = await _store.get('game_sessions', sessionId);
    if (raw == null) throw AppFailure('Eşleşme yok.', code: 'NO_MATCH');
    return _sessionToView(raw);
  }

  Map<String, dynamic> _slot(UserEntity user, String? sessionId) => {
        'userId': user.id,
        'name': user.displayName,
        'sessionId': sessionId,
        'lastSeen': _now.toIso8601String(),
      };

  List<Map<String, dynamic>> _playersOf(Map<String, dynamic> row) {
    final raw = row['players'];
    if (raw is! List) return [];
    return [
      for (final e in raw)
        if (e is Map) Map<String, dynamic>.from(e),
    ];
  }

  bool _hasPlayer(Map<String, dynamic> row, String userId) =>
      _playersOf(row).any((p) => p['userId'] == userId);

  void _touch(Map<String, dynamic> row, String userId) {
    final players = _playersOf(row);
    for (final p in players) {
      if (p['userId'] == userId) p['lastSeen'] = _now.toIso8601String();
    }
    row['players'] = players;
  }

  Future<Map<String, dynamic>?> _duelByCode(String code) async {
    final normalized = code.trim();
    for (final row in await _store.values('duels')) {
      if (row['code'] == normalized) return Map<String, dynamic>.from(row);
    }
    return null;
  }

  Future<void> _leaveOtherDuels(String userId, {required String keep}) async {
    for (final row in await _store.values('duels')) {
      if (row['id'] == keep || row['status'] != 'lobby') continue;
      if (!_hasPlayer(row, userId)) continue;
      final copy = Map<String, dynamic>.from(row);
      if (copy['hostId'] == userId) {
        copy['status'] = 'done';
      } else {
        copy['players'] =
            _playersOf(copy).where((p) => p['userId'] != userId).toList();
      }
      await _store.put('duels', copy['id'] as String, copy);
    }
  }

  Future<Map<String, dynamic>?> _duelFor(
    String userId, {
    required bool openOnly,
  }) async {
    Map<String, dynamic>? latest;
    DateTime? latestAt;
    for (final row in await _store.values('duels')) {
      if (!_hasPlayer(row, userId)) continue;
      final copy = Map<String, dynamic>.from(row);
      if (copy['status'] != 'done') return copy;
      if (openOnly) continue;
      final at = DateTime.tryParse(copy['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (latestAt == null || at.isAfter(latestAt)) {
        latest = copy;
        latestAt = at;
      }
    }
    return latest;
  }

  Future<Map<String, dynamic>?> _roomFor(
    String userId, {
    required bool openOnly,
  }) async {
    Map<String, dynamic>? latest;
    DateTime? latestAt;
    for (final row in await _store.values('rooms')) {
      if (!_hasPlayer(row, userId)) continue;
      final copy = Map<String, dynamic>.from(row);
      final status = copy['status'] as String? ?? '';
      if (status == 'lobby' || status == 'playing') return copy;
      if (openOnly) continue;
      final at = DateTime.tryParse(copy['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      if (latestAt == null || at.isAfter(latestAt)) {
        latest = copy;
        latestAt = at;
      }
    }
    return latest;
  }

  Future<void> _sweepLobby(Map<String, dynamic> room) async {
    if (room['status'] != 'lobby') return;
    final hostId = room['hostId'] as String?;
    final fresh = <Map<String, dynamic>>[];
    for (final p in _playersOf(room)) {
      final seen = DateTime.tryParse(p['lastSeen'] as String? ?? '');
      final stale = seen == null || _now.difference(seen) >= _presence;
      if (p['userId'] == hostId) {
        if (stale) {
          room['status'] = 'done';
          return;
        }
        fresh.add(p);
        continue;
      }
      if (!stale) fresh.add(p);
    }
    room['players'] = fresh;
  }

  Future<void> _leaveOtherLobbies(String userId, {required String keep}) async {
    for (final row in await _store.values('rooms')) {
      if (row['id'] == keep || row['status'] != 'lobby') continue;
      if (!_hasPlayer(row, userId)) continue;
      final copy = Map<String, dynamic>.from(row);
      if (copy['hostId'] == userId) {
        copy['status'] = 'done';
      } else {
        copy['players'] =
            _playersOf(copy).where((p) => p['userId'] != userId).toList();
      }
      await _store.put('rooms', copy['id'] as String, copy);
    }
  }

  Future<String> _uniqueRoomCode() => _uniqueCode('rooms');

  Future<String> _uniqueCode(String box) async {
    final taken = (await _store.values(box))
        .map((r) => r['code'] as String?)
        .whereType<String>()
        .toSet();
    for (var i = 0; i < 40; i++) {
      final code = '${100000 + _random.nextInt(900000)}';
      if (!taken.contains(code)) return code;
    }
    throw AppFailure('Oda kodu üretilemedi.', code: 'ROOM_CODE');
  }

  bool _plainGuestName(String name) {
    final trimmed = name.trim();
    return const {
      'Misafir',
      'Guest',
      'Gast',
      'Invitado',
      'Invite',
      'Ospite',
      'Гость',
      'Convidado',
      'Gość',
    }.contains(trimmed);
  }

  bool _guestLabel(String name) {
    final trimmed = name.trim();
    return _plainGuestName(trimmed) ||
        RegExp(
          r'^(Misafir|Guest|Gast|Invitado|Invite|Ospite|Гость|Convidado|Gość)\d+$',
        )
            .hasMatch(trimmed);
  }

  Future<String> _uniqueGuestName(String locale) async {
    final prefix = GameLocale.resolve(locale).guestPrefix;
    final taken = <String>{};
    for (final map in await _store.values('users')) {
      final name = (map['displayName'] as String? ?? '').trim().toLowerCase();
      if (name.isNotEmpty) taken.add(name);
    }
    for (var i = 0; i < 40; i++) {
      final candidate = '$prefix${1000 + _random.nextInt(9000)}';
      if (!taken.contains(candidate.toLowerCase())) return candidate;
    }
    return '$prefix${100000 + _random.nextInt(900000)}';
  }

  /// A player who left the match is finished as a timeout after five minutes.
  Future<void> _expireAbsent(Map<String, dynamic> match) async {
    if (match['status'] != 'playing') return;
    for (final p in _playersOf(match)) {
      final seen = DateTime.tryParse(p['lastSeen'] as String? ?? '');
      if (seen != null && _now.difference(seen) < _away) continue;
      final id = p['sessionId'] as String?;
      if (id == null || await _sessionFinished(id)) continue;
      final raw = await _store.get('game_sessions', id);
      if (raw == null) continue;
      raw['status'] = GameStatus.lost.name;
      raw['won'] = false;
      raw['timedOut'] = true;
      raw['finishedAt'] = _now.toIso8601String();
      await _store.put('game_sessions', id, raw);
    }
  }

  Future<bool> _playersDone(List<Map<String, dynamic>> players) async {
    if (players.isEmpty) return false;
    for (final p in players) {
      if (!await _sessionFinished(p['sessionId'] as String?)) return false;
    }
    return true;
  }

  Future<bool> _sessionFinished(String? id) async {
    if (id == null) return false;
    final raw = await _store.get('game_sessions', id);
    if (raw == null) return false;
    final status = raw['status'] as String?;
    if (status == GameStatus.completed.name ||
        status == GameStatus.won.name ||
        status == GameStatus.lost.name ||
        status == GameStatus.expired.name) {
      return true;
    }
    final exp = DateTime.tryParse(raw['expiresAt'] as String? ?? '');
    return exp != null && !exp.isAfter(_now);
  }

  Future<MatchRow> _score(Map<String, dynamic> player) async {
    final id = player['sessionId'] as String?;
    final raw = id == null ? null : await _store.get('game_sessions', id);
    var finished = false;
    var solved = false;
    var guesses = 0;
    var millis = 0;
    var greens = 0;
    var yellows = 0;
    if (raw != null) {
      finished = await _sessionFinished(id);
      solved = raw['won'] == true;
      guesses = raw['currentAttempt'] as int? ?? 0;
      final played = raw['guesses'] as List? ?? const [];
      if (played.isNotEmpty && played.last is Map) {
        final statuses = (played.last as Map)['statuses'] as List? ?? const [];
        for (final status in statuses) {
          if (status == 'correct') greens++;
          if (status == 'present') yellows++;
        }
      }
      if (finished) {
        final start = DateTime.parse(raw['startedAt'] as String);
        final endRaw = raw['finishedAt'] as String?;
        final end = endRaw == null ? _now : DateTime.parse(endRaw);
        final span = end.difference(start).inMilliseconds;
        millis = span < 0 ? 0 : span;
      }
    }
    return MatchRow(
      userId: player['userId'] as String? ?? '',
      name: player['name'] as String? ?? '',
      finished: finished,
      solved: solved,
      guesses: guesses,
      millis: millis,
      left: raw?['timedOut'] == true,
      rank: 0,
      greens: greens,
      yellows: yellows,
    );
  }

  Future<MatchSnapshot> _duelView(Map<String, dynamic> duel, String userId) async {
    final scored = <MatchRow>[];
    String? opponent;
    String? sessionId;
    for (final p in _playersOf(duel)) {
      scored.add(await _score(p));
      if (p['userId'] == userId) {
        sessionId = p['sessionId'] as String?;
      } else {
        opponent = p['name'] as String?;
      }
    }
    return MatchSnapshot(
      kind: 'duel',
      status: duel['status'] as String? ?? 'ready',
      rows: rankMatch(scored),
      id: duel['id'] as String?,
      code: duel['code'] as String?,
      hostId: duel['hostId'] as String?,
      opponentName: opponent,
      sessionId: sessionId,
    );
  }

  Future<MatchSnapshot> _roomView(Map<String, dynamic> room, String userId) async {
    final scored = <MatchRow>[];
    String? sessionId;
    for (final p in _playersOf(room)) {
      scored.add(await _score(p));
      if (p['userId'] == userId) sessionId = p['sessionId'] as String?;
    }
    return MatchSnapshot(
      kind: 'room',
      status: room['status'] as String? ?? 'lobby',
      rows: rankMatch(scored),
      id: room['id'] as String?,
      code: room['code'] as String?,
      hostId: room['hostId'] as String?,
      sessionId: sessionId,
    );
  }

  @override
  Future<GameSessionView> activeSession(GameType type) async {
    final user = await _requireUser();
    final existing = await _findActive(user.id, type, language: user.locale);
    if (existing == null) {
      throw AppFailure(UserMessages.sessionExpired, code: 'NO_SESSION');
    }
    return _sessionToView(existing);
  }

  @override
  Future<GameSessionView> submitGuess(String sessionId, String guess) async {
    final user = await _requireUser();
    final raw = await _store.get('game_sessions', sessionId);
    if (raw == null || raw['userId'] != user.id) {
      throw AppFailure(UserMessages.serverError, code: 'NO_SESSION');
    }
    if (raw['status'] != GameStatus.active.name) {
      return _sessionToView(raw);
    }
    if (!_sessionStillOpen(raw)) {
      raw['status'] = GameStatus.expired.name;
      await _store.put('game_sessions', sessionId, raw);
      throw AppFailure(UserMessages.sessionExpired, code: 'EXPIRED');
    }
    final started = DateTime.parse(raw['startedAt'] as String);
    if (started.isAfter(_now)) {
      throw AppFailure('Oyun henüz başlamadı.', code: 'NOT_STARTED');
    }

    final wordMap = await _store.get('words', raw['wordId'] as String);
    if (wordMap == null) throw AppFailure(UserMessages.serverError);
    final secret = WordEntity.fromMap(wordMap);
    final locale = GameLocale.resolve(secret.language);
    final length = raw['wordLength'] as int;
    final letters = locale.letters(guess);
    if (letters.length < length) {
      throw AppFailure(UserMessages.tooShort(length), code: 'SHORT');
    }
    if (letters.length > length) {
      throw AppFailure(UserMessages.tooLong(length), code: 'LONG');
    }
    if (!locale.isAllowedWord(guess)) {
      throw AppFailure(UserMessages.invalidGuess, code: 'CHARS');
    }
    final dictionary = await _playable(length, language: secret.language);
    final valid = dictionary.any((w) => locale.equals(w.word, guess));
    if (!valid) {
      throw AppFailure(UserMessages.invalidWord, code: 'DICT');
    }

    final evaluated = _engine.evaluate(guess, secret.word, locale: locale);
    final guesses = List<Map<String, dynamic>>.from(raw['guesses'] as List? ?? []);
    guesses.add({
      'guess': evaluated.guess,
      'statuses': evaluated.statuses.map((s) => s.name).toList(),
    });
    raw['guesses'] = guesses;
    raw['currentAttempt'] = (raw['currentAttempt'] as int) + 1;
    raw['letterHintsOnRow'] = 0;

    final won = evaluated.isWin;
    final lost = !won && (raw['currentAttempt'] as int) >= (raw['maxAttempts'] as int);
    if (won) {
      raw['status'] = GameStatus.won.name;
    } else if (lost) {
      raw['status'] = GameStatus.lost.name;
    }
    await _store.put('game_sessions', sessionId, raw);

    if (!won && !lost) {
      return _sessionToView(raw);
    }
    final outcome = await _finalize(user, raw, secret, won);
    return _sessionToView(raw, outcome: outcome);
  }

  Future<GameOutcome> _finalize(
    UserEntity user,
    Map<String, dynamic> raw,
    WordEntity secret,
    bool won,
  ) async {
    final config = await _config();
    final type = GameType.values.byName(raw['gameType'] as String);
    final guesses = raw['currentAttempt'] as int;
    final hintUsed = raw['hintUsed'] as bool? ?? false;
    final started = DateTime.parse(raw['startedAt'] as String);
    final seconds = _now.difference(started).inSeconds.clamp(1, 3600);
    final perfect = won && guesses == 1;

    var xp = 0;
    var coins = 0;
    var leaguePts = 0;
    var streak = user.streak;
    var next = user;

    if (type == GameType.daily) {
      final today = DateKeys.dayKey(_now);
      final firstToday = !user.playedDailyOn(today);
      if (firstToday) {
        final last = user.lastDailyFor(user.locale);
        if (last != null && DateKeys.daysBetween(last, today) == 1) {
          streak = user.streak + 1;
        } else if (last == null || user.streak == 0) {
          streak = 1;
        } else {
          streak = user.streak + 1;
        }
        next = user.copyWith(
          lastDailyDate: today,
          lastDailyByLocale: {...user.lastDailyByLocale, user.locale: today},
          streak: streak,
          longestStreak: streak > user.longestStreak ? streak : user.longestStreak,
        );
      } else {
        streak = user.streak;
        }
        xp = _progression.dailyXp(
          config: config,
          won: won,
          hintUsed: hintUsed,
          perfect: perfect,
          streakAfter: streak,
        );
        coins = _progression.dailyCoins(config: config, won: won);
        leaguePts = user.canJoinLeague
            ? _progression.leaguePoints(
                guesses: guesses,
                won: won,
                hintUsed: hintUsed,
              )
            : 0;
    } else if (type == GameType.endless) {
      if (won) {
        xp = _progression.endlessXp(config);
        coins = _progression.endlessCoins(config);
        await _migrateEndlessLeague(user);
        final run = (raw['endlessStreak'] as int? ?? 0) + 1;
        raw['endlessStreak'] = run;
        final previousBest = int.tryParse(
              await _store.getMeta(_runMetaKey(user, 'endless_best')) ?? '',
            ) ??
            0;
        final best = run > previousBest ? run : previousBest;
        await _store.putMeta(_runMetaKey(user, 'endless_run'), '$run');
        await _store.putMeta(_runMetaKey(user, 'endless_run_at_risk'), '');
        await _store.putMeta(_runMetaKey(user, 'endless_best'), '$best');
        await _stampMarathonPeriods(user, run);
        next = user.copyWith(endlessBest: best);
      } else {
        await _migrateEndlessLeague(user);
        final prev = int.tryParse(await _runMeta(user, 'endless_run') ?? '0') ?? 0;
        if (prev > 0) {
          await _store.putMeta(_runMetaKey(user, 'endless_run_at_risk'), '$prev');
        } else {
          await _store.putMeta(_runMetaKey(user, 'endless_run_at_risk'), '');
        }
        await _store.putMeta(_runMetaKey(user, 'endless_run'), '0');
        if (prev <= 0) {
          await _store.putMeta(_runMetaKey(user, 'endless_open'), '');
        }
      }
      final finished =
          (int.tryParse(await _runMeta(user, 'endless_finished') ?? '0') ?? 0) + 1;
        await _store.putMeta(_runMetaKey(user, 'endless_finished'), '$finished');
        if (won) {
          final wins =
              (int.tryParse(await _runMeta(user, 'endless_wins') ?? '0') ?? 0) + 1;
          await _store.putMeta(_runMetaKey(user, 'endless_wins'), '$wins');
        }
    }

    if (type == GameType.duel && user.canJoinLeague) {
      leaguePts = _progression.leaguePoints(
        guesses: guesses,
        won: won,
        hintUsed: hintUsed,
      );
    }

    final newXp = next.xp + xp;
    final newLevel = _progression.levelForXp(newXp, config.levelXpThresholds);
    next = next.copyWith(
      xp: newXp,
      level: newLevel,
      coin: next.coin + coins,
      gamesPlayed: next.gamesPlayed + 1,
      gamesWon: next.gamesWon + (won ? 1 : 0),
      totalGuessesOnWins: next.totalGuessesOnWins + (won ? guesses : 0),
      fastestSolveSeconds: won
          ? (next.fastestSolveSeconds == null
              ? seconds
              : (seconds < next.fastestSolveSeconds! ? seconds : next.fastestSolveSeconds))
          : next.fastestSolveSeconds,
      firstGuessWins: next.firstGuessWins + (perfect ? 1 : 0),
    );
    await _creditWallet(next.id, coins, won ? 'GAME_WIN' : 'GAME_LOSE', raw['id'] as String);
    await _saveUser(next);

    if ((type == GameType.daily || type == GameType.duel) && leaguePts != 0) {
      await _addLeaguePoints(next, leaguePts);
    }

    final unlocked = await _checkAchievements(next, seconds: seconds, perfect: perfect);
    if (unlocked.isNotEmpty) {
      next = (await _userOrNull())!;
    }

    await _store.put(
      'words',
      secret.id,
      secret.copyWith(usedCount: secret.usedCount + 1).toMap(),
    );

    await _store.put('game_results', _uuid.v4(), {
      'userId': next.id,
      'sessionId': raw['id'],
      'gameType': type.name,
      'wordId': secret.id,
      'language': secret.language,
      'guesses': guesses,
      'won': won,
      'timeSpent': seconds,
      'hintUsed': hintUsed,
      'xpEarned': xp,
      'coinEarned': coins,
      'leaguePoints': leaguePts,
      'createdAt': _now.toIso8601String(),
    });

    raw['status'] = GameStatus.completed.name;
    raw['won'] = won;
    raw['finishedAt'] = _now.toIso8601String();
    await _store.put('game_sessions', raw['id'] as String, raw);

    final standings = next.canJoinLeague ? await leagueStandings() : <LeaderboardEntry>[];
    final me = standings.where((e) => e.isCurrentUser).firstOrNull;

    var endlessRun = 0;
    var canRevive = false;
    var showBreakAd = false;
    if (type == GameType.endless) {
      final currentRun =
          int.tryParse(await _runMeta(next, 'endless_run') ?? '0') ?? 0;
      final atRisk =
          int.tryParse(await _runMeta(next, 'endless_run_at_risk') ?? '') ?? 0;
      endlessRun = won ? currentRun : atRisk;
      canRevive = !won && atRisk > 0;
      final wins = int.tryParse(await _runMeta(next, 'endless_wins') ?? '0') ?? 0;
      showBreakAd = won && wins > 0 && wins % AppConstants.endlessBreakAdEvery == 0;
    }

    return GameOutcome(
      won: won,
      word: secret.displayWord,
      definition: secret.definition,
      exampleSentence: secret.exampleSentence,
      englishTranslation: secret.englishTranslation,
      wordId: secret.id,
      xpEarned: xp,
      coinEarned: coins,
      leaguePoints: leaguePts,
      streak: next.streak,
      level: next.level,
      guesses: guesses,
      timeSpentSeconds: seconds,
      unlockedAchievements: unlocked,
      rankAfter: me?.rank,
      endlessRun: endlessRun,
      canReviveEndlessWithAd: canRevive,
      showEndlessBreakAd: showBreakAd,
    );
  }

  Future<void> _creditWallet(String userId, int amount, String reason, String ref) async {
    if (amount == 0) return;
    final wallet = await _store.get('wallets', userId) ?? {'balance': 0};
    final balance = (wallet['balance'] as int? ?? 0) + amount;
    await _store.put('wallets', userId, {
      'balance': balance,
      'updatedAt': _now.toIso8601String(),
    });
    await _store.put('wallet_transactions', _uuid.v4(), {
      'userId': userId,
      'type': amount >= 0 ? TransactionType.earn.name : TransactionType.spend.name,
      'amount': amount.abs(),
      'reason': reason,
      'referenceId': ref,
      'createdAt': _now.toIso8601String(),
    });
  }

  @override
  Future<GameSessionView> requestHint(String sessionId, HintLevel level) async {
    var user = await _requireUser();
    final raw = await _store.get('game_sessions', sessionId);
    if (raw == null || raw['status'] != GameStatus.active.name) {
      throw AppFailure(UserMessages.serverError);
    }
    final config = await _config();
    final cost = _progression.hintCost(config, level);
    final free = level == HintLevel.letter ? user.freeHint1 : user.freeHint2;
    if (free <= 0 && user.coin < cost) {
      throw AppFailure(UserMessages.insufficientCoins, code: 'COINS');
    }
    final wordMap = await _store.get('words', raw['wordId'] as String);
    final secret = WordEntity.fromMap(wordMap!);
    final letters = GameLocale.resolve(secret.language).letters(secret.word);

    var lostOnHint = false;
    if (level == HintLevel.letter) {
      final revealed = Map<String, dynamic>.from(raw['revealedLetters'] as Map? ?? {});
      final open = <int>[];
      for (var i = 0; i < letters.length; i++) {
        if (!revealed.containsKey('$i')) open.add(i);
      }
      if (open.isEmpty) throw AppFailure('Tüm harfler zaten açık.');
      final idx = open[_random.nextInt(open.length)];
      revealed['$idx'] = letters[idx];
      raw['revealedLetters'] = revealed;
      raw['hint1'] = true;
      final already = raw['letterHintsOnRow'] as int? ?? 0;
      if (already >= 1) {
        final attempt = (raw['currentAttempt'] as int? ?? 0) + 1;
        raw['currentAttempt'] = attempt;
        if (attempt >= (raw['maxAttempts'] as int)) {
          raw['status'] = GameStatus.lost.name;
          lostOnHint = true;
        }
      }
      raw['letterHintsOnRow'] = 1;
    } else {
      raw['definitionHint'] = secret.definition;
    }
    raw['hintUsed'] = true;
    await _store.put('game_sessions', sessionId, raw);

    if (free > 0) {
      user = await _saveUser(
        level == HintLevel.letter
            ? user.copyWith(freeHint1: free - 1)
            : user.copyWith(freeHint2: free - 1),
      );
    } else {
      user = await _saveUser(user.copyWith(coin: user.coin - cost));
      await _creditWallet(user.id, -cost, 'HINT_PURCHASE', sessionId);
    }
    if (lostOnHint) {
      final outcome = await _finalize(user, raw, secret, false);
      return _sessionToView(raw, outcome: outcome);
    }
    return _sessionToView(raw);
  }

  @override
  Future<DailyRewardResult> claimDailyReward() async {
    var user = await _requireUser();
    final today = DateKeys.dayKey(_now);
    if (user.lastRewardDate == today) {
      throw AppFailure('Günlük ödülü zaten aldın.');
    }
    final config = await _config();
    final day = user.rewardCycleDay.clamp(1, 7);
    final spec = config.dailyRewardCycle.firstWhere((e) => e.day == day);
    user = await _saveUser(
      user.copyWith(
        coin: user.coin + spec.coins,
        freeHint1: user.freeHint1 + spec.hintLevel1,
        freeHint2: user.freeHint2 + spec.hintLevel2,
        shields: (user.shields + spec.shield).clamp(0, AppConstants.maxStreakShields),
        leagueShields: spec.shield > 0
            ? (user.leagueShields + spec.shield).clamp(0, AppConstants.maxLeagueShields)
            : user.leagueShields,
        lastRewardDate: today,
        rewardCycleDay: day == 7 ? 1 : day + 1,
      ),
    );
    await _creditWallet(user.id, spec.coins, 'DAILY_REWARD', today);
    return DailyRewardResult(
      day: day,
      coins: spec.coins,
      hintLevel1: spec.hintLevel1,
      hintLevel2: spec.hintLevel2,
      shield: spec.shield,
    );
  }

  @override
  Future<int> watchRewardedAd() async {
    if (!grantUnverifiedAds) {
      throw AppFailure(UserMessages.adUnavailable, code: 'NO_AD_PROOF');
    }
    final user = await _requireUser();
    final config = await _config();
    await _saveUser(user.copyWith(coin: user.coin + config.adCoinReward));
    await _creditWallet(user.id, config.adCoinReward, 'AD_REWARD', _uuid.v4());
    return config.adCoinReward;
  }

  /// Grants the configured ad reward once for an AdMob transaction.
  Future<bool> grantRewardedAdProof({
    required String userId,
    required String transactionId,
  }) async {
    if (userId.isEmpty || transactionId.isEmpty) return false;
    final seen = 'admob_$transactionId';
    if (await _store.getMeta(seen) == '1') return true;
    final config = await _config();
    final map = await _store.get('users', userId);
    if (map == null) return false;
    final user = UserEntity.fromMap(map);
    await _saveUser(user.copyWith(coin: user.coin + config.adCoinReward));
    await _creditWallet(user.id, config.adCoinReward, 'AD_REWARD', transactionId);
    await _store.putMeta(seen, '1');
    return true;
  }

  @override
  Future<void> restoreEndlessRunAfterAd() async {
    final user = await _requireUser();
    await _migrateEndlessLeague(user);
    try {
    await watchRewardedAd();
    } on AppFailure {
      // A signed ad may already have granted coins. The run still resumes.
    }
    final atRisk = int.tryParse(await _runMeta(user, 'endless_run_at_risk') ?? '') ?? 0;
    if (atRisk > 0) {
      await _store.putMeta(_runMetaKey(user, 'endless_run'), '$atRisk');
    }
    await _store.putMeta(_runMetaKey(user, 'endless_run_at_risk'), '');
  }

  @override
  Future<bool> endEndlessRun() async {
    final user = await _requireUser();
    await _migrateEndlessLeague(user);
    final atRisk = int.tryParse(await _runMeta(user, 'endless_run_at_risk') ?? '') ?? 0;
    if (atRisk <= 0) return false;
    await _store.putMeta(_runMetaKey(user, 'endless_run_at_risk'), '');
    await _store.putMeta(_runMetaKey(user, 'endless_open'), '');
    return true;
  }

  @override
  Future<MarathonSnapshot> marathonSnapshot() async {
    final user = await _requireUser();
    await _migrateEndlessLeague(user);
    final leagues = <MarathonLeagueStatus>[];
    for (final league in LeagueTier.values) {
      final run = int.tryParse(await _runMeta(user, 'endless_run', league: league) ?? '') ?? 0;
      final atRisk =
          int.tryParse(await _runMeta(user, 'endless_run_at_risk', league: league) ?? '') ?? 0;
      final played =
          int.tryParse(await _runMeta(user, 'endless_finished', league: league) ?? '') ?? 0;
      final open =
          await _runMeta(user, 'endless_open', league: league) == '1';
      final best = await _leagueBest(user, user.locale, league);
      final week = await _periodStanding(user, league, 'week', DateKeys.weekId(_now));
      final month = await _periodStanding(user, league, 'month', DateKeys.monthId(_now));
      final year = await _periodStanding(user, league, 'year', DateKeys.yearId(_now));
      final state = run > 0
          ? MarathonRunState.running
          : atRisk > 0
              ? MarathonRunState.paused
              : open
                  ? MarathonRunState.running
                  : MarathonRunState.none;
      leagues.add(
        MarathonLeagueStatus(
          league: league,
          state: state,
          series: run > 0 ? run : atRisk,
          best: best,
          played: played,
          current: league == user.currentLeague,
          rank: await _marathonRank(user, league, best, played),
          weekBest: week.best,
          weekRank: week.rank,
          monthBest: month.best,
          monthRank: month.rank,
          yearBest: year.best,
          yearRank: year.rank,
        ),
      );
    }
    return MarathonSnapshot(leagues: leagues);
  }

  @override
  Future<List<ShopProduct>> listShopProducts() =>
      _loadShopProducts(onlyActive: true);

  @override
  Future<UserEntity> purchaseShopProduct(
    String productId, {
    required String purchaseToken,
  }) async {
    final token = purchaseToken.trim();
    if (token.isEmpty) {
      throw AppFailure(UserMessages.billingUnavailable, code: 'NO_PURCHASE');
    }
    final proof = confirmPurchase;
    if (proof != null && !await proof(productId, token)) {
      throw AppFailure(
        UserMessages.billingUnavailable,
        code: 'UNVERIFIED_PURCHASE',
      );
    }
    final user = await _requireUser();
    if (user.isBanned) {
      throw AppFailure(UserMessages.banned, code: 'BANNED');
    }
    if (await _store.get('purchases', token) != null) {
      return user;
    }
    final map = await _store.get('shop_products', productId);
    final product = map == null ? null : ShopProduct.fromMap(map);
    if (product == null ||
        !product.active ||
        (!product.grantsCoins && !product.grantsShields)) {
      throw AppFailure(UserMessages.serverError, code: 'NO_PRODUCT');
    }
    if (product.grantsShields &&
        user.shields >= AppConstants.maxStreakShields) {
      throw AppFailure(UserMessages.shieldsFull, code: 'SHIELDS_FULL');
    }
    final shields = product.grantsShields
        ? (user.shields + product.shields)
            .clamp(0, AppConstants.maxStreakShields)
        : user.shields;
    final next = await _saveUser(
      user.copyWith(
        coin: user.coin + product.coins,
        shields: shields,
      ),
    );
    await _store.put('purchases', token, {
      'productId': product.id,
      'userId': user.id,
      'createdAt': _now.toIso8601String(),
    });
    if (product.grantsCoins) {
      await _creditWallet(user.id, product.coins, 'IAP_${product.id}', token);
    }
    return next;
  }

  @override
  Future<List<ShopProduct>> adminListShopProducts({
    bool includeInactive = true,
  }) =>
      _loadShopProducts(onlyActive: !includeInactive);

  @override
  Future<ShopProduct> adminUpsertShopProduct(ShopProduct product) async {
    final id = product.id.trim();
    if (id.isEmpty) {
      throw AppFailure('Ürün id zorunlu', code: 'BAD_PRODUCT');
    }
    if (product.coins < 0 || product.shields < 0) {
      throw AppFailure('Coin / kalkan negatif olamaz', code: 'BAD_PRODUCT');
    }
    if (product.coins <= 0 && product.shields <= 0) {
      throw AppFailure(
        'Coin veya streak kalkanı miktarı girilmeli',
        code: 'BAD_PRODUCT',
      );
    }
    if (product.priceTry.trim().isEmpty || product.priceUsd.trim().isEmpty) {
      throw AppFailure('TRY ve USD fiyatları zorunlu', code: 'BAD_PRODUCT');
    }
    final saved = product.copyWith(id: id);
    await _store.put('shop_products', id, saved.toMap());
    return saved;
  }

  @override
  Future<void> adminDeleteShopProduct(String productId) async {
    await _store.delete('shop_products', productId);
  }

  @override
  Future<List<ShopProduct>> adminResetShopCatalog() async {
    final existing = await _store.values('shop_products');
    for (final row in existing) {
      await _store.delete('shop_products', row['id'] as String);
    }
    await _seedShopCatalog();
    return _loadShopProducts();
  }

  @override
  Future<void> saveWord(String wordId) async {
    final user = await _requireUser();
    final existing = await _store.values('user_words');
    if (existing.any((e) => e['userId'] == user.id && e['wordId'] == wordId)) {
      return;
    }
    await _store.put('user_words', _uuid.v4(), {
      'userId': user.id,
      'wordId': wordId,
      'savedAt': _now.toIso8601String(),
    });
    await _saveUser(user.copyWith(wordsLearned: user.wordsLearned + 1));
  }

  @override
  Future<List<SavedWord>> wordBook() async {
    final user = await _requireUser();
    final rows = await _store.values('user_words');
    final mine = rows.where((e) => e['userId'] == user.id).toList();
    final out = <SavedWord>[];
    for (final r in mine) {
      final w = await _store.get('words', r['wordId'] as String);
      if (w == null) continue;
      final word = WordEntity.fromMap(w);
      if (word.language != user.locale) continue;
      out.add(
        SavedWord(
          id: word.id,
          word: word.displayWord,
          definition: word.definition,
          exampleSentence: word.exampleSentence,
          englishTranslation: word.englishTranslation,
          savedAt: DateTime.parse(r['savedAt'] as String),
        ),
      );
    }
    out.sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return out;
  }

  Future<String> _seedLeagueNpcs(LeagueTier league, {String locale = 'tr'}) async {
    final week = DateKeys.weekId(_now);
    final leagueId = _weekLeagueId(week, locale, league);
    await _store.put('weekly_leagues', leagueId, {
      'league': league.name,
      'week': week,
      'locale': locale,
      'isActive': true,
    });
    final npcs = await _npcsFor(league, locale);
    final seed = week.hashCode ^ league.index;
    final rnd = Random(seed);
    for (final npc in npcs) {
      final id = '${leagueId}_${npc['id']}';
      final existing = await _store.get('league_players', id);
      if (existing == null) {
        await _store.put('league_players', id, {
          'userId': npc['id'],
          'displayName': npc['displayName'],
          'leagueId': leagueId,
          'points': 50 + rnd.nextInt(351),
          'week': week,
          'isNpc': true,
        });
      }
    }
    return leagueId;
  }

  Future<List<LeaderboardEntry>> _ensureLeague(UserEntity user) async {
    final leagueId = await _seedLeagueNpcs(user.currentLeague, locale: user.locale);
    final week = DateKeys.weekId(_now);
    final meId = '${leagueId}_${user.id}';
    final me = await _store.get('league_players', meId);
    if (me == null) {
      await _store.put('league_players', meId, {
        'userId': user.id,
        'displayName': user.displayName,
        'leagueId': leagueId,
        'points': 0,
        'week': week,
        'isNpc': false,
      });
    } else if (me['displayName'] != user.displayName) {
      me['displayName'] = user.displayName;
      await _store.put('league_players', meId, me);
    }
    final rows = (await _store.values('league_players'))
        .where((e) => e['leagueId'] == leagueId)
        .toList()
      ..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < rows.length; i++) {
      entries.add(
        LeaderboardEntry(
          userId: rows[i]['userId'] as String,
          displayName: rows[i]['displayName'] as String,
          points: rows[i]['points'] as int,
          rank: i + 1,
          isCurrentUser: rows[i]['userId'] == user.id,
        ),
      );
    }
    return entries;
  }

  Future<void> _addLeaguePoints(UserEntity user, int points) async {
    final week = DateKeys.weekId(_now);
    final leagueId = _weekLeagueId(week, user.locale, user.currentLeague);
    await _ensureLeague(user);
    final meId = '${leagueId}_${user.id}';
    final me = await _store.get('league_players', meId);
    if (me == null) return;
    me['points'] = (me['points'] as int) + points;
    await _store.put('league_players', meId, me);
    await _addPeriodPoints(user, RankPeriod.month, DateKeys.monthId(_now), points);
    await _addPeriodPoints(user, RankPeriod.season, DateKeys.seasonId(_now), points);
    await _addPeriodPoints(user, RankPeriod.year, DateKeys.yearId(_now), points);
  }

  Future<UserEntity> _maybeRolloverLeague(UserEntity user) async {
    if (!user.canJoinLeague) return user;
    final week = DateKeys.weekId(_now);
    final month = DateKeys.monthId(_now);
    final season = DateKeys.seasonId(_now);
    final year = DateKeys.yearId(_now);

    if (user.lastPlayedWeek == null) {
      return _saveUser(
        user.copyWith(
          lastPlayedWeek: week,
          lastSettledWeek: week,
          lastSettledMonth: month,
          lastSettledSeason: season,
          lastSettledYear: year,
        ),
      );
    }

    if (user.lastPlayedWeek != week) {
      final oldWeek = user.lastPlayedWeek!;
      user = await _settleWeeklyAndPromote(user, oldWeek);
      user = await _saveUser(user.copyWith(lastPlayedWeek: week, lastSettledWeek: week));
    }

    if (user.lastSettledMonth != month) {
      if (user.lastSettledMonth != null) {
        user = await _settleMonth(user, user.lastSettledMonth!);
      }
      user = await _saveUser(user.copyWith(lastSettledMonth: month));
    }
    if (user.lastSettledSeason != season) {
      if (user.lastSettledSeason != null) {
        user = await _settleSeason(user, user.lastSettledSeason!);
      }
      user = await _saveUser(user.copyWith(lastSettledSeason: season));
    }
    if (user.lastSettledYear != year) {
      if (user.lastSettledYear != null) {
        user = await _settleYear(user, user.lastSettledYear!);
      }
      user = await _saveUser(user.copyWith(lastSettledYear: year));
    }
    return user;
  }

  Future<UserEntity> _settleWeeklyAndPromote(UserEntity user, String oldWeek) async {
    final leagueId = _weekLeagueId(oldWeek, user.locale, user.currentLeague);
    final rows = (await _store.values('league_players'))
        .where((e) => e['leagueId'] == leagueId)
        .toList()
      ..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
    if (rows.isEmpty) return user;
    final idx = rows.indexWhere((e) => e['userId'] == user.id);
    if (idx < 0) return user;
    final rank = idx + 1;
    final total = rows.length;
    final topCut = (total * 0.2).ceil().clamp(1, total);
    final myPoints = rows[idx]['points'] as int? ?? 0;
    if (myPoints <= 0) return user;

    var coins = 0;
    var weekTitleUntil = user.weekTitleUntil;
    var wins = user.leagueWins;
    if (rank == 1) {
      coins += user.currentLeague == LeagueTier.gold ? 60 : 40;
      weekTitleUntil = _now.add(const Duration(days: 7));
      wins += 1;
    } else if (rank <= topCut) {
      coins += 20;
    }

    if (coins > 0) {
      await _creditWallet(user.id, coins, 'WEEK_LEAGUE', oldWeek);
    }
    return user.copyWith(
      leagueWins: wins,
      coin: user.coin + coins,
      weekTitleUntil: weekTitleUntil,
    );
  }

  Future<UserEntity> _settleMonth(UserEntity user, String monthId) async {
    final rows = await _periodRows(RankPeriod.month, monthId, user.currentLeague, user.locale);
    if (rows.isEmpty) return user;
    final idx = rows.indexWhere((e) => e['userId'] == user.id);
    if (idx < 0) return user;
    final rank = idx + 1;
    final topCut = (rows.length * 0.1).ceil().clamp(1, rows.length);
    if (rank > topCut) return user;
    final unlocked = _unlock(user.unlockedCosmetics, Cosmetics.frameMonth);
    await _creditWallet(user.id, 50, 'MONTH_CUP', monthId);
    return user.copyWith(
      coin: user.coin + 50,
      unlockedCosmetics: unlocked,
      badges: _unlock(user.badges, 'month_$monthId'),
    );
  }

  Future<UserEntity> _settleSeason(UserEntity user, String seasonId) async {
    final rows = await _periodRows(RankPeriod.season, seasonId, user.currentLeague, user.locale);
    if (rows.isEmpty) return user;
    final idx = rows.indexWhere((e) => e['userId'] == user.id);
    var cosmetics = List<String>.from(user.unlockedCosmetics);
    var badges = List<String>.from(user.badges);
    if (idx >= 0) {
      final rank = idx + 1;
      final top1 = (rows.length * 0.01).ceil().clamp(1, rows.length);
      final top10 = (rows.length * 0.1).ceil().clamp(1, rows.length);
      final points = rows[idx]['points'] as int? ?? 0;
      if (rank <= top1) {
        cosmetics = _unlock(cosmetics, Cosmetics.frameSeason);
        badges = _unlock(badges, 'season_legend');
      }
      if (rank <= top10) {
        cosmetics = _unlock(cosmetics, Cosmetics.themeSeason);
        badges = _unlock(badges, 'season_epic');
      }
      if (points > 0) {
        badges = _unlock(badges, 'season_play');
      }
    }
    return user.copyWith(
      unlockedCosmetics: cosmetics,
      badges: badges,
    );
  }

  Future<UserEntity> _settleYear(UserEntity user, String yearId) async {
    final rows = await _periodRows(RankPeriod.year, yearId, user.currentLeague, user.locale);
    if (rows.isEmpty) return user;
    final idx = rows.indexWhere((e) => e['userId'] == user.id);
    if (idx != 0) return user;
    return user.copyWith(
      unlockedCosmetics: _unlock(user.unlockedCosmetics, Cosmetics.frameHonor),
      badges: _unlock(user.badges, 'year_honor'),
    );
  }

  List<String> _unlock(List<String> have, String id) =>
      have.contains(id) ? have : [...have, id];

  String _periodKey(
    RankPeriod period,
    String periodId,
    LeagueTier league,
    String userId, {
    String locale = 'tr',
  }) =>
      '${period.name}_${periodId}_${locale}_${league.name}_$userId';

  Future<void> _seedPeriodNpcs(
    RankPeriod period,
    String periodId,
    LeagueTier league,
    String locale,
  ) async {
    final npcs = await _npcsFor(league, locale);
    final seed = periodId.hashCode ^ period.index ^ league.index ^ locale.hashCode;
    final rnd = Random(seed);
    final band = switch (period) {
      RankPeriod.month => (120, 500),
      RankPeriod.season => (350, 1500),
      RankPeriod.year => (700, 3000),
      RankPeriod.week => (50, 351),
    };
    for (final npc in npcs) {
      final id = npc['id'] as String;
      final key = _periodKey(period, periodId, league, id, locale: locale);
      if (await _store.get('period_scores', key) != null) continue;
      await _store.put('period_scores', key, {
        'userId': id,
        'displayName': npc['displayName'],
        'period': period.name,
        'periodId': periodId,
        'league': league.name,
        'locale': locale,
        'points': band.$1 + rnd.nextInt(band.$2),
        'isNpc': true,
      });
    }
  }

  Future<void> _ensurePeriodBoard(RankPeriod period, String periodId, UserEntity user) async {
    await _seedPeriodNpcs(period, periodId, user.currentLeague, user.locale);
    final meKey = _periodKey(period, periodId, user.currentLeague, user.id, locale: user.locale);
    if (await _store.get('period_scores', meKey) == null) {
      await _store.put('period_scores', meKey, {
        'userId': user.id,
        'displayName': user.displayName,
        'period': period.name,
        'periodId': periodId,
        'league': user.currentLeague.name,
        'locale': user.locale,
        'points': 0,
        'isNpc': false,
      });
    }
  }

  Future<void> _addPeriodPoints(
    UserEntity user,
    RankPeriod period,
    String periodId,
    int points,
  ) async {
    await _ensurePeriodBoard(period, periodId, user);
    final key = _periodKey(period, periodId, user.currentLeague, user.id, locale: user.locale);
    final row = await _store.get('period_scores', key);
    if (row == null) return;
    row['points'] = (row['points'] as int? ?? 0) + points;
    row['displayName'] = user.displayName;
    await _store.put('period_scores', key, row);
  }

  Future<List<Map<String, dynamic>>> _periodRows(
    RankPeriod period,
    String periodId,
    LeagueTier league,
    String locale,
  ) async {
    final rows = (await _store.values('period_scores'))
        .where(
          (e) =>
              e['period'] == period.name &&
              e['periodId'] == periodId &&
              e['league'] == league.name &&
              (e['locale'] as String? ?? 'tr') == locale,
        )
        .toList()
      ..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
    return rows;
  }

  Future<List<LeaderboardEntry>> _periodStandings(
    RankPeriod period,
    String periodId,
    UserEntity user,
  ) async {
    await _ensurePeriodBoard(period, periodId, user);
    final rows = await _periodRows(period, periodId, user.currentLeague, user.locale);
    return [
      for (var i = 0; i < rows.length; i++)
        LeaderboardEntry(
          userId: rows[i]['userId'] as String,
          displayName: rows[i]['displayName'] as String,
          points: rows[i]['points'] as int,
          rank: i + 1,
          isCurrentUser: rows[i]['userId'] == user.id,
        ),
    ];
  }

  @override
  Future<List<LeaderboardEntry>> leaderboard() async {
    final user = await _requireUser();
    if (!user.canJoinLeague) return [];
    return _ensureLeague(user);
  }

  @override
  Future<List<LeaderboardEntry>> leagueStandings() => leaderboard();

  @override
  Future<CompetitionSnapshot> competitionSnapshot() async {
    var user = await _requireUser();
    user = await _applyMissedStreak(user);
    user = await _maybeRolloverLeague(user);
    if (!user.canJoinLeague) {
      return CompetitionSnapshot(
        guest: true,
        league: user.currentLeague,
        weekId: DateKeys.weekId(_now),
        monthId: DateKeys.monthId(_now),
        seasonId: DateKeys.seasonId(_now),
        yearId: DateKeys.yearId(_now),
        week: const [],
        month: const [],
        season: const [],
        year: const [],
        unlockedCosmetics: user.unlockedCosmetics,
        equippedTheme: user.equippedTheme,
        equippedFrame: user.equippedFrame,
        badges: user.badges,
      );
    }
    final week = await leagueStandings();
    return CompetitionSnapshot(
      guest: false,
      league: user.currentLeague,
      weekId: DateKeys.weekId(_now),
      monthId: DateKeys.monthId(_now),
      seasonId: DateKeys.seasonId(_now),
      yearId: DateKeys.yearId(_now),
      week: week,
      month: await _periodStandings(RankPeriod.month, DateKeys.monthId(_now), user),
      season: await _periodStandings(RankPeriod.season, DateKeys.seasonId(_now), user),
      year: await _periodStandings(RankPeriod.year, DateKeys.yearId(_now), user),
      weekTitleActive: user.weekTitleUntil != null && user.weekTitleUntil!.isAfter(_now),
      badges: user.badges,
      unlockedCosmetics: user.unlockedCosmetics,
      equippedTheme: user.equippedTheme,
      equippedFrame: user.equippedFrame,
    );
  }

  @override
  Future<UserEntity> equipCosmetic({String? theme, String? frame}) async {
    var user = await _requireUser();
    final unlocked = user.unlockedCosmetics;
    if (theme != null && !unlocked.contains(theme)) {
      throw AppFailure('Bu tema kilitli.');
    }
    if (frame != null && !unlocked.contains(frame)) {
      throw AppFailure('Bu çerçeve kilitli.');
    }
    return _saveUser(
      user.copyWith(
        equippedTheme: theme ?? user.equippedTheme,
        equippedFrame: frame ?? user.equippedFrame,
      ),
    );
  }

  Future<List<String>> _checkAchievements(
    UserEntity user, {
    required int seconds,
    required bool perfect,
  }) async {
    const defs = [
      _Ach('first_step', 'İlk Adım', 'İlk oyunu tamamla', '🟢', 10),
      _Ach('fire_started', 'Ateş Başladı', '3 günlük streak', '🔥', 25),
      _Ach('professor', 'Profesör', '100 kelime çöz', '🧠', 50),
      _Ach('lightning', 'Şimşek', '20 saniyeden kısa sürede çöz', '⚡', 30),
      _Ach('perfectionist', 'Mükemmeliyetçi', '10 kez ilk tahminde çöz', '🎯', 75),
      _Ach('gold_league', 'Altın', 'Altın lige ulaş', '🥇', 100),
    ];
    final have = (await _store.values('user_achievements'))
        .where((e) => e['userId'] == user.id)
        .map((e) => e['achievementId'] as String)
        .toSet();
    final unlocked = <String>[];
    bool cond(_Ach a) => switch (a.id) {
          'first_step' => user.gamesPlayed >= 1,
          'fire_started' => user.streak >= 3,
          'professor' => user.gamesWon >= 100,
          'lightning' => seconds > 0 && seconds < 20 && user.gamesWon > 0,
          'perfectionist' => user.firstGuessWins >= 10,
          'gold_league' => user.currentLeague == LeagueTier.gold,
          _ => false,
        };
    for (final a in defs) {
      if (have.contains(a.id) || !cond(a)) continue;
      await _store.put('user_achievements', _uuid.v4(), {
        'userId': user.id,
        'achievementId': a.id,
        'unlockedAt': _now.toIso8601String(),
      });
      final fresh = await _requireUser();
      await _saveUser(fresh.copyWith(coin: fresh.coin + a.coins));
      await _creditWallet(user.id, a.coins, 'ACHIEVEMENT', a.id);
      unlocked.add(a.name);
    }
    return unlocked;
  }

  @override
  Future<List<AchievementView>> achievements() async {
    final user = await _requireUser();
    const defs = [
      _Ach('first_step', 'İlk Adım', 'İlk oyunu tamamla', '🟢', 10),
      _Ach('fire_started', 'Ateş Başladı', '3 günlük streak', '🔥', 25),
      _Ach('professor', 'Profesör', '100 kelime çöz', '🧠', 50),
      _Ach('lightning', 'Şimşek', '20 saniyeden kısa sürede çöz', '⚡', 30),
      _Ach('perfectionist', 'Mükemmeliyetçi', '10 kez ilk tahminde çöz', '🎯', 75),
      _Ach('gold_league', 'Altın', 'Altın lige ulaş', '🥇', 100),
    ];
    final have = {
      for (final e in await _store.values('user_achievements'))
        if (e['userId'] == user.id)
          e['achievementId'] as String: DateTime.parse(e['unlockedAt'] as String),
    };
    return [
      for (final a in defs)
        AchievementView(
          id: a.id,
          name: a.name,
          description: a.desc,
          icon: a.icon,
          rewardCoin: a.coins,
          unlocked: have.containsKey(a.id),
          unlockedAt: have[a.id],
        ),
    ];
  }

  @override
  Future<UserEntity> profile() async {
    var user = await _requireUser();
    user = await _applyMissedStreak(user);
    user = await _maybeRolloverLeague(user);
    return user;
  }

  @override
  Future<List<ResultPlace>> resultBoard({
    required GameType type,
    required String wordId,
  }) async {
    final user = await _requireUser();
    if (type == GameType.endless) return _endlessBoard(user);
    return _dailyBoard(user, wordId);
  }

  Future<List<ResultPlace>> _dailyBoard(UserEntity user, String wordId) async {
    if (wordId.isEmpty) return const [];
    final today = DateKeys.dayKey(_now);
    final best = <String, Map<dynamic, dynamic>>{};
    for (final raw in await _store.values('game_results')) {
      if (raw['gameType'] != GameType.daily.name) continue;
      if (raw['wordId'] != wordId) continue;
      if ((raw['language'] as String? ?? 'tr') != user.locale) continue;
      final created = DateTime.tryParse(raw['createdAt'] as String? ?? '');
      if (created == null || DateKeys.dayKey(created) != today) continue;
      final id = raw['userId'] as String? ?? '';
      if (id.isEmpty) continue;
      final prev = best[id];
      if (prev == null || _betterDaily(raw, prev)) best[id] = raw;
    }
    final ranked = best.entries.toList()
      ..sort((a, b) => _dailyOrder(a.value, b.value));
    final firstSolved = ranked
        .where(
          (entry) =>
              entry.value['won'] == true && (entry.value['guesses'] as int? ?? 0) == 1,
        )
        .length;
    final secondSolved = ranked
        .where(
          (entry) =>
              entry.value['won'] == true && (entry.value['guesses'] as int? ?? 0) == 2,
        )
        .length;
    final places = <ResultPlace>[];
    for (var i = 0; i < ranked.length; i++) {
      final row = ranked[i].value;
      final won = row['won'] == true;
      final mine = ranked[i].key == user.id;
      places.add(ResultPlace(
        rank: i + 1,
        displayName: await _boardName(ranked[i].key),
        score: won ? '${row['guesses'] ?? ''}' : '—',
        isCurrentUser: mine,
        firstSolved: mine ? firstSolved : null,
        secondSolved: mine ? secondSolved : null,
      ));
    }
    return _capBoard(places);
  }

  bool _betterDaily(Map<dynamic, dynamic> next, Map<dynamic, dynamic> prev) =>
      _dailyOrder(next, prev) < 0;

  int _dailyOrder(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
    final aw = a['won'] == true;
    final bw = b['won'] == true;
    if (aw != bw) return aw ? -1 : 1;
    final guesses = (a['guesses'] as int? ?? 99).compareTo(b['guesses'] as int? ?? 99);
    if (aw && guesses != 0) return guesses;
    final time = (a['timeSpent'] as int? ?? 1 << 30).compareTo(
      b['timeSpent'] as int? ?? 1 << 30,
    );
    if (time != 0) return time;
    return 0;
  }

  Future<List<ResultPlace>> _endlessBoard(UserEntity user) async {
    await _migrateEndlessLeague(user);
    final scored = <({String id, String name, int best})>[];
    for (final raw in await _store.values('users')) {
      final other = UserEntity.fromMap(raw);
      final best = await _leagueBest(other, user.locale, user.currentLeague);
      if (best <= 0 && other.id != user.id) continue;
      scored.add((id: other.id, name: other.displayName, best: best));
    }
    scored.sort((a, b) {
      final byBest = b.best.compareTo(a.best);
      if (byBest != 0) return byBest;
      return a.name.compareTo(b.name);
    });
    final places = <ResultPlace>[
      for (var i = 0; i < scored.length; i++)
        ResultPlace(
          rank: i + 1,
          displayName: scored[i].name.isEmpty ? 'Oyuncu' : scored[i].name,
          score: '${scored[i].best}',
          isCurrentUser: scored[i].id == user.id,
        ),
    ];
    return _capBoard(places);
  }

  List<ResultPlace> _capBoard(List<ResultPlace> places) {
    final top = places.where((e) => e.rank <= 20).toList();
    final mine = places.where((e) => e.isCurrentUser);
    if (mine.isEmpty) return top;
    final me = mine.first;
    if (me.rank <= 20) return top;
    return [...top, me];
  }

  Future<String> _boardName(String userId) async {
    final raw = await _store.get('users', userId);
    final name = raw?['displayName'] as String? ?? '';
    return name.isEmpty ? 'Oyuncu' : name;
  }

  @override
  Future<List<WordEntity>> adminListWords() async {
    final all = await _store.values('words');
    final list = all.map(WordEntity.fromMap).toList()
      ..sort((a, b) => a.word.compareTo(b.word));
    return list;
  }

  @override
  Future<WordEntity> adminUpsertWord(WordEntity word) async {
    final now = _now;
    final locale = GameLocale.resolve(word.language);
    final saved = WordEntity(
      id: word.id.isEmpty ? 'word_${_uuid.v4()}' : word.id,
      word: word.word,
      language: locale.id,
      length: locale.letterCount(word.word),
      difficulty: word.difficulty,
      frequency: word.frequency,
      category: word.category,
      definition: word.definition,
      exampleSentence: word.exampleSentence,
      englishTranslation: word.englishTranslation,
      status: word.status,
      isActive: word.isActive,
      usedCount: word.usedCount,
      createdAt: word.createdAt,
      updatedAt: now,
    );
    await _store.put('words', saved.id, saved.toMap());
    return saved;
  }

  @override
  Future<void> adminDeleteWord(String wordId) async {
    await _store.delete('words', wordId);
  }

  @override
  Future<WordImportResult> adminImportWords(String csv) async {
    final doc = parseWordCsv(csv);
    if (doc.headerError != null) {
      throw AppFailure(doc.headerError!, code: 'CSV_HEADER');
    }
    final known = <String>{};
    for (final raw in await _store.values('words')) {
      final word = WordEntity.fromMap(raw);
      known.add(_importKey(word.language, word.word));
    }
    var imported = 0;
    var skipped = 0;
    var invalid = 0;
    final now = _now;
    for (final cells in doc.rows) {
      final row = _csvWord(cells);
      if (row == null) {
        invalid++;
        continue;
      }
      final key = _importKey(row.language, row.word);
      if (known.contains(key)) {
        skipped++;
        continue;
      }
      await adminUpsertWord(
        WordEntity(
          id: '',
          word: row.word,
          language: row.language,
          length: row.length,
          difficulty: row.difficulty,
          frequency: row.frequency,
          category: row.category,
          definition: row.definition,
          exampleSentence: row.example,
          englishTranslation: row.english,
          status: row.status,
          isActive: row.status == WordStatus.active,
          usedCount: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      known.add(key);
      imported++;
    }
    return WordImportResult(
      imported: imported,
      skipped: skipped,
      invalid: invalid,
    );
  }

  String _importKey(String language, String word) {
    final locale = GameLocale.resolve(language);
    return '${locale.id}|${locale.toUpper(word)}';
  }

  _CsvWord? _csvWord(List<String> cells) {
    if (cells.length != wordCsvHeaders.length) return null;
    final word = cells[0].trim();
    final language = cells[1].trim().toLowerCase();
    final definition = cells[2].trim();
    if (word.isEmpty || definition.isEmpty) return null;
    if (!GameLocale.known(language)) return null;
    final locale = GameLocale.resolve(language);
    if (!locale.isAllowedWord(word)) return null;
    final length = locale.letterCount(word);
    if (length < 3 || length > 7) return null;
    final difficulty = _csvScale(cells[6], fallback: 2);
    final frequency = _csvScale(cells[7], fallback: 3);
    final status = _csvStatus(cells[8]);
    if (difficulty == null || frequency == null || status == null) return null;
    final category = cells[5].trim();
    return _CsvWord(
      word: word,
      language: language,
      definition: definition,
      example: cells[3].trim(),
      english: cells[4].trim(),
      category: category.isEmpty ? 'genel' : category,
      difficulty: difficulty,
      frequency: frequency,
      status: status,
      length: length,
    );
  }

  int? _csvScale(String raw, {required int fallback}) {
    final text = raw.trim();
    if (text.isEmpty) return fallback;
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 5) return null;
    return value;
  }

  WordStatus? _csvStatus(String raw) {
    final text = raw.trim().toLowerCase();
    if (text.isEmpty) return WordStatus.active;
    for (final status in WordStatus.values) {
      if (status.name == text) return status;
    }
    return null;
  }

  @override
  Future<void> adminSetDaily({
    required String dateKey,
    required LeagueTier league,
    required String wordId,
    String language = 'tr',
  }) async {
    final locale = GameLocale.resolve(language).id;
    final wordMap = await _store.get('words', wordId);
    if (wordMap == null) {
      throw AppFailure(UserMessages.serverError, code: 'NO_WORD');
    }
    final word = WordEntity.fromMap(wordMap);
    if (word.language != locale) {
      throw AppFailure(
        'Kelime dili ${word.language.toUpperCase()}, beklenen ${locale.toUpperCase()}.',
        code: 'WORD_LOCALE',
      );
    }
    if (word.length != league.wordLength) {
      throw AppFailure(
        'Kelime ${word.length} harf; ${league.label} için ${league.wordLength} harf gerekir.',
        code: 'WORD_LENGTH',
      );
    }
    final row = {
      'date': dateKey,
      'league': league.name,
      'language': locale,
      'wordId': wordId,
      'index': 1,
      'isActive': true,
      'source': 'admin',
      'createdAt': _now.toIso8601String(),
    };
    await _store.put('daily_games', _dailyKey(dateKey, locale, league), row);
    if (locale == 'tr') {
      await _store.put('daily_games', '${dateKey}_${league.name}', row);
    }
  }

  @override
  Future<int> adminAutoAssignMonth({
    required int year,
    required int month,
    required LeagueTier league,
    String locale = 'tr',
  }) async {
    final lang = GameLocale.resolve(locale).id;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final map = await adminDailyMap();
    final byId = {
      for (final word in (await _store.values('words')).map(WordEntity.fromMap))
        word.id: word,
    };
    final pool = byId.values
        .where(
          (w) =>
              w.playable && w.length == league.wordLength && w.language == lang,
        )
        .toList()
      ..shuffle(_random);
    if (pool.isEmpty) {
      throw AppFailure(
        'Uygun kelime yok (${lang.toUpperCase()}, ${league.wordLength} harf).',
        code: 'NO_WORD',
      );
    }
    bool held(String? wordId) {
      final word = wordId == null ? null : byId[wordId];
      return word != null &&
          word.playable &&
          word.language == lang &&
          word.length == league.wordLength;
    }

    String? liveId(String key) {
      final id = map['${key}_${lang}_${league.name}'] ??
          (lang == 'tr' ? map['${key}_${league.name}'] : null);
      return held(id) ? id : null;
    }

    final usedInMonth = <String>{};
    for (var day = 1; day <= daysInMonth; day++) {
      final id = liveId(DateKeys.dayKey(DateTime(year, month, day)));
      if (id != null) usedInMonth.add(id);
    }
    var assigned = 0;
    var poolIndex = 0;
    for (var day = 1; day <= daysInMonth; day++) {
      final key = DateKeys.dayKey(DateTime(year, month, day));
      final existing = liveId(key);
      if (existing != null) continue;
      WordEntity? pick;
      for (var tries = 0; tries < pool.length; tries++) {
        final candidate = pool[(poolIndex + tries) % pool.length];
        if (!usedInMonth.contains(candidate.id)) {
          pick = candidate;
          poolIndex = (poolIndex + tries + 1) % pool.length;
          break;
        }
      }
      pick ??= pool[poolIndex % pool.length];
      poolIndex = (poolIndex + 1) % pool.length;
      await adminSetDaily(
        dateKey: key,
        league: league,
        wordId: pick.id,
        language: lang,
      );
      usedInMonth.add(pick.id);
      assigned++;
    }
    return assigned;
  }

  @override
  Future<AdminOverview> adminOverview({String locale = 'tr'}) async {
    final users = (await _store.values('users')).map(UserEntity.fromMap).toList();
    final today = DateKeys.dayKey(_now);
    final results = await _store.values('game_results');
    var dailyDone = 0;
    var endlessDone = 0;
    for (final r in results) {
      final created = DateTime.parse(r['createdAt'] as String);
      if (DateKeys.dayKey(created) != today) continue;
      final lang = r['language'] as String? ?? 'tr';
      if (lang != locale) continue;
      if (r['gameType'] == GameType.daily.name) {
        dailyDone++;
      } else if (r['gameType'] == GameType.endless.name) {
        endlessDone++;
      }
    }
    final words = (await _store.values('words')).map(WordEntity.fromMap);
    final pool = <int, int>{for (var len = 4; len <= 8; len++) len: 0};
    for (final w in words) {
      if (!w.playable) continue;
      if (w.language != locale) continue;
      pool[w.length] = (pool[w.length] ?? 0) + 1;
    }
    final dailyMap = await adminDailyMap();
    final missing = LeagueTier.values
        .where((l) {
          final keyed = dailyMap['${today}_${locale}_${l.name}'];
          if (keyed != null) return false;
          if (locale == 'tr' && dailyMap['${today}_${l.name}'] != null) {
            return false;
          }
          return true;
        })
        .toList();
    return AdminOverview(
      registeredCount: users.where((u) => !u.isAnonymous).length,
      guestCount: users.where((u) => u.isAnonymous).length,
      bannedCount: users.where((u) => u.isBanned).length,
      todayDailyCompleted: dailyDone,
      todayEndlessCompleted: endlessDone,
      wordPoolByLength: pool,
      missingDailyLeagues: missing,
      weekId: DateKeys.weekId(_now),
    );
  }

  @override
  Future<List<UserEntity>> adminListUsers({
    String query = '',
    AdminUserKind kind = AdminUserKind.all,
  }) async {
    final q = query.trim().toLowerCase();
    final list = (await _store.values('users')).map(UserEntity.fromMap).where((u) {
      switch (kind) {
        case AdminUserKind.registered:
          if (u.isAnonymous) return false;
        case AdminUserKind.guest:
          if (!u.isAnonymous) return false;
        case AdminUserKind.banned:
          if (!u.isBanned) return false;
        case AdminUserKind.all:
          break;
      }
      if (q.isEmpty) return true;
      return u.displayName.toLowerCase().contains(q) ||
          u.id.toLowerCase().contains(q) ||
          u.authProvider.name.contains(q);
    }).toList()
      ..sort((a, b) => b.lastLoginAt.compareTo(a.lastLoginAt));
    return list;
  }

  Future<AdminGameRecord> _recordFromResult(Map<String, dynamic> r) async {
    final userId = r['userId'] as String;
    final wordId = r['wordId'] as String;
    final userMap = await _store.get('users', userId);
    final wordMap = await _store.get('words', wordId);
    final displayWord = wordMap != null
        ? WordEntity.fromMap(wordMap).displayWord
        : wordId;
    final createdAt = DateTime.parse(r['createdAt'] as String);
    final timeSpent = r['timeSpent'] as int? ?? 0;
    final authName = userMap?['authProvider'] as String? ?? 'anonymous';
    final isGuest = userMap == null || authName == AuthProvider.anonymous.name;
    final displayName = userMap == null
        ? 'Silindi'
        : (isGuest
            ? 'Misafir'
            : (userMap['displayName'] as String? ?? 'Oyuncu'));
    return AdminGameRecord(
      sessionId: r['sessionId'] as String,
      userId: userId,
      displayName: displayName,
      gameType: GameType.values.byName(r['gameType'] as String),
      wordId: wordId,
      word: displayWord,
      guesses: r['guesses'] as int? ?? 0,
      won: r['won'] as bool? ?? false,
      timeSpent: timeSpent,
      hintUsed: r['hintUsed'] as bool? ?? false,
      xpEarned: r['xpEarned'] as int? ?? 0,
      coinEarned: r['coinEarned'] as int? ?? 0,
      leaguePoints: r['leaguePoints'] as int? ?? 0,
      createdAt: createdAt,
      startedAt: createdAt.subtract(Duration(seconds: timeSpent)),
      endedAt: createdAt,
      inProgress: false,
      isGuest: isGuest,
    );
  }

  @override
  Future<AdminUserDetail> adminUserDetail(String userId) async {
    final map = await _store.get('users', userId);
    if (map == null) {
      throw AppFailure(UserMessages.serverError, code: 'NO_USER');
    }
    final games = await adminListGames(userId: userId);
    return AdminUserDetail(
      user: UserEntity.fromMap(map),
      recentGames: games.take(20).toList(),
    );
  }

  @override
  Future<List<AdminGameRecord>> adminListGames({
    String? userId,
    GameType? type,
    bool? won,
  }) async {
    final rows = await _store.values('game_results');
    final filtered = rows.where((r) {
      if (userId != null && r['userId'] != userId) return false;
      if (type != null && r['gameType'] != type.name) return false;
      if (won != null && r['won'] != won) return false;
      return true;
    }).toList();
    final out = <AdminGameRecord>[];
    for (final r in filtered) {
      out.add(await _recordFromResult(r));
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  @override
  Future<AdminSessionDetail?> adminGetSession(String sessionId) async {
    final raw = await _store.get('game_sessions', sessionId);
    if (raw == null) return null;
    final userId = raw['userId'] as String;
    final wordId = raw['wordId'] as String;
    final userMap = await _store.get('users', userId);
    final wordMap = await _store.get('words', wordId);
    final authName = userMap?['authProvider'] as String? ?? 'anonymous';
    final isGuest = userMap == null || authName == AuthProvider.anonymous.name;
    return AdminSessionDetail(
      session: await _sessionToView(raw),
      userId: userId,
      displayName: userMap == null
          ? 'Silindi'
          : (isGuest
              ? 'Misafir'
              : (userMap['displayName'] as String? ?? 'Oyuncu')),
      wordId: wordId,
      word: wordMap == null ? wordId : WordEntity.fromMap(wordMap).displayWord,
    );
  }

  @override
  Future<UserEntity> adminSetDisplayName(String userId, String name) async {
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      throw AppFailure('Kullanıcı adı en az 2 karakter olmalı.');
    }
    final map = await _store.get('users', userId);
    if (map == null) {
      throw AppFailure(UserMessages.serverError, code: 'NO_USER');
    }
    return _saveUser(UserEntity.fromMap(map).copyWith(displayName: trimmed));
  }

  @override
  Future<void> adminBanUser(String userId, bool banned, {String? reason}) async {
    final map = await _store.get('users', userId);
    if (map == null) return;
    final user = UserEntity.fromMap(map);
    await _saveUser(
      user.copyWith(
        isBanned: banned,
        banReason: banned ? (reason ?? user.banReason) : null,
        clearBanReason: !banned,
      ),
    );
  }

  @override
  Future<UserEntity> adminAdjustCoins(
    String userId,
    int delta, {
    String reason = 'ADMIN_GRANT',
  }) async {
    final map = await _store.get('users', userId);
    if (map == null) {
      throw AppFailure(UserMessages.serverError, code: 'NO_USER');
    }
    final user = UserEntity.fromMap(map);
    final nextCoin = (user.coin + delta).clamp(0, 1 << 30);
    final applied = nextCoin - user.coin;
    final next = await _saveUser(user.copyWith(coin: nextCoin));
    if (applied != 0) {
      await _creditWallet(userId, applied, reason, 'admin');
    }
    return next;
  }

  @override
  Future<List<LeaderboardEntry>> adminLeagueStandings(
    LeagueTier league, {
    String locale = 'tr',
    RankPeriod period = RankPeriod.week,
    String? periodId,
  }) async {
    final lang = GameLocale.resolve(locale).id;
    final id = periodId ?? switch (period) {
          RankPeriod.week => DateKeys.weekId(_now),
          RankPeriod.month => DateKeys.monthId(_now),
          RankPeriod.season => DateKeys.seasonId(_now),
          RankPeriod.year => DateKeys.yearId(_now),
        };

    if (period == RankPeriod.week) {
      final leagueId = await _seedLeagueNpcs(league, locale: lang);
      final rows = (await _store.values('league_players'))
          .where((e) => e['leagueId'] == leagueId)
          .toList()
        ..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));
      return [
        for (var i = 0; i < rows.length; i++)
          LeaderboardEntry(
            userId: rows[i]['userId'] as String,
            displayName: rows[i]['displayName'] as String,
            points: rows[i]['points'] as int,
            rank: i + 1,
            isCurrentUser: false,
          ),
      ];
    }

    await _seedPeriodNpcs(period, id, league, lang);
    final rows = await _periodRows(period, id, league, lang);
    return [
      for (var i = 0; i < rows.length; i++)
        LeaderboardEntry(
          userId: rows[i]['userId'] as String,
          displayName: rows[i]['displayName'] as String,
          points: rows[i]['points'] as int,
          rank: i + 1,
          isCurrentUser: false,
        ),
    ];
  }

  @override
  Future<AppConfig> getConfig() => _config();

  @override
  Future<AppConfig> adminUpdateConfig(AppConfig config) async {
    await _store.put('app_config', 'default', config.toMap());
    return config;
  }

  @override
  Future<Map<String, String>> adminDailyMap() async {
    final rows = await _store.values('daily_games');
    final map = <String, String>{};
    for (final r in rows) {
      final date = r['date'] as String;
      final league = r['league'] as String;
      final wordId = r['wordId'] as String;
      final lang = r['language'] as String? ?? 'tr';
      final index = r['index'] as int? ?? 1;
      final base = '${date}_${lang}_$league';
      if (index <= 1) {
        map[base] = wordId;
        if (lang == 'tr') map['${date}_$league'] = wordId;
      } else {
        map['${base}_$index'] = wordId;
        final opened = r['createdAt'] as String?;
        if (opened != null && opened.isNotEmpty) {
          map['${base}_${index}_at'] = opened;
        }
      }
    }
    return map;
  }
}

class _Ach {
  const _Ach(this.id, this.name, this.desc, this.icon, this.coins);
  final String id, name, desc, icon;
  final int coins;
}

class _CsvWord {
  const _CsvWord({
    required this.word,
    required this.language,
    required this.definition,
    required this.example,
    required this.english,
    required this.category,
    required this.difficulty,
    required this.frequency,
    required this.status,
    required this.length,
  });

  final String word;
  final String language;
  final String definition;
  final String example;
  final String english;
  final String category;
  final int difficulty;
  final int frequency;
  final WordStatus status;
  final int length;
}
