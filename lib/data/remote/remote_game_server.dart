import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:kelimelig/api/game_wire.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/data/remote/api_session.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/entities/app_config.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/shop_product.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';
import 'package:kelimelig/domain/entities/word_import_result.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _playerTokenKey = 'luno_player_token';

Future<void> restorePlayerToken(ApiSession session) async {
  final prefs = await SharedPreferences.getInstance();
  session.playerToken = prefs.getString(_playerTokenKey);
}

class RemoteGameServer implements GameServer {
  RemoteGameServer(String baseUrl, this._session)
      : _root = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

  final String _root;
  final ApiSession _session;

  Future<Object?> _call(
    String op,
    Map<String, dynamic> args, {
    bool admin = false,
    bool retried = false,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    final token = admin ? _session.adminToken : _session.playerToken;
    if (token != null && token.isNotEmpty) {
      headers['authorization'] = 'Bearer $token';
    }
    final response = await http
        .post(
          Uri.parse('$_root/v1/game'),
          headers: headers,
          body: jsonEncode({
            'op': op,
            'args': {
              ...args,
              'tzOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
            },
          }),
        )
        .timeout(timeout);
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : decoded is Map
            ? Map<String, dynamic>.from(decoded)
            : <String, dynamic>{};
    if (response.statusCode == 401 && !admin && !retried) {
      await _savePlayer(null);
      return _call(op, args, retried: true, timeout: timeout);
    }
    if (!admin && body.containsKey('token')) {
      final next = body['token'];
      await _savePlayer(next is String && next.isNotEmpty ? next : null);
    }
    if (response.statusCode >= 400) {
      throw AppFailure(
        body['error'] as String? ?? 'İstek başarısız',
        code: body['code'] as String?,
      );
    }
    return body['data'];
  }

  Future<void> _savePlayer(String? token) async {
    _session.playerToken = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await prefs.remove(_playerTokenKey);
    } else {
      await prefs.setString(_playerTokenKey, token);
    }
  }

  Map<String, dynamic> _userMap(Object? raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    throw AppFailure('Sunucu yanıtı okunamadı.');
  }

  UserEntity _user(Object? raw) => UserEntity.fromMap(_userMap(raw));

  List<ShopProduct> _shop(Object? raw) => [
        for (final item in raw as List? ?? const [])
          ShopProduct.fromMap(item as Map),
      ];

  List<WordEntity> _words(Object? raw) => [
        for (final item in raw as List? ?? const [])
          WordEntity.fromMap(item as Map),
      ];

  List<LeaderboardEntry> _board(Object? raw) => [
        for (final item in raw as List? ?? const []) readBoard(item),
      ];

  @override
  Future<UserEntity?> currentUser() async {
    final data = await _call('currentUser', {});
    if (data == null) return null;
    return _user(data);
  }

  @override
  Future<UserEntity> signInAnonymously() async =>
      _user(await _call('signInAnonymously', {}));

  @override
  Future<UserEntity> signInWithGoogle({
    required String googleId,
    String? email,
    String? displayName,
  }) async =>
      _user(await _call('signInWithGoogle', {
        'googleId': googleId,
        'email': email,
        'displayName': displayName,
      }));

  @override
  Future<UserEntity> signInWithApple({String? displayName}) async =>
      _user(await _call('signInWithApple', {'displayName': displayName}));

  @override
  Future<UserEntity> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? avatar,
  }) async =>
      _user(await _call('registerWithEmail', {
        'email': email,
        'password': password,
        'displayName': displayName,
        'avatar': avatar,
      }));

  @override
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  }) async =>
      _user(await _call('signInWithEmail', {
        'email': email,
        'password': password,
      }));

  @override
  Future<UserEntity> setDisplayName(String name) async =>
      _user(await _call('setDisplayName', {'name': name}));

  @override
  Future<UserEntity> completeOnboarding() async =>
      _user(await _call('completeOnboarding', {}));

  @override
  Future<UserEntity> updateSettings({
    bool? soundOn,
    bool? hapticOn,
    bool? animationsOn,
    bool? notificationsOn,
  }) async =>
      _user(await _call('updateSettings', {
        'soundOn': soundOn,
        'hapticOn': hapticOn,
        'animationsOn': animationsOn,
        'notificationsOn': notificationsOn,
      }));

  @override
  Future<void> signOut() async {
    await _call('signOut', {});
  }

  @override
  Future<bool> hasChosenLocale() async =>
      await _call('hasChosenLocale', {}) as bool? ?? false;

  @override
  Future<String> activeLocale() async =>
      await _call('activeLocale', {}) as String? ?? 'tr';

  @override
  Future<UserEntity?> setLocale(String localeId) async {
    final data = await _call('setLocale', {'localeId': localeId});
    if (data == null) return null;
    return _user(data);
  }

  @override
  Future<UserEntity> setLeague(LeagueTier league) async =>
      _user(await _call('setLeague', {'league': league.name}));

  @override
  Future<HomeSnapshot> homeSnapshot() async =>
      readHome(await _call('homeSnapshot', {}));

  @override
  Future<GameSessionView> startDaily() async =>
      readSession(await _call('startDaily', {}));

  @override
  Future<GameSessionView> startEndless() async =>
      readSession(await _call('startEndless', {}));

  @override
  Future<GameSessionView> activeSession(GameType type) async =>
      readSession(await _call('activeSession', {'type': type.name}));

  @override
  Future<GameSessionView> submitGuess(String sessionId, String guess) async =>
      readSession(await _call('submitGuess', {
        'sessionId': sessionId,
        'guess': guess,
      }));

  @override
  Future<GameSessionView> requestHint(String sessionId, HintLevel level) async =>
      readSession(await _call('requestHint', {
        'sessionId': sessionId,
        'level': level.name,
      }));

  @override
  Future<DailyRewardResult> claimDailyReward() async =>
      readReward(await _call('claimDailyReward', {}));

  @override
  Future<int> watchRewardedAd() async =>
      await _call('watchRewardedAd', {}) as int? ?? 0;

  @override
  Future<void> restoreEndlessRunAfterAd() async {
    await _call('restoreEndlessRunAfterAd', {});
  }

  @override
  Future<List<ShopProduct>> listShopProducts() async =>
      _shop(await _call('listShopProducts', {}));

  @override
  Future<UserEntity> purchaseShopProduct(
    String productId, {
    required String purchaseToken,
  }) async =>
      _user(await _call('purchaseShopProduct', {
        'productId': productId,
        'purchaseToken': purchaseToken,
      }));

  @override
  Future<void> saveWord(String wordId) async {
    await _call('saveWord', {'wordId': wordId});
  }

  @override
  Future<List<SavedWord>> wordBook() async => [
        for (final item in await _call('wordBook', {}) as List? ?? const [])
          readSaved(item),
      ];

  @override
  Future<List<LeaderboardEntry>> leaderboard() async =>
      _board(await _call('leaderboard', {}));

  @override
  Future<List<LeaderboardEntry>> leagueStandings() async =>
      _board(await _call('leagueStandings', {}));

  @override
  Future<CompetitionSnapshot> competitionSnapshot() async =>
      readCompetition(await _call('competitionSnapshot', {}));

  @override
  Future<UserEntity> equipCosmetic({String? theme, String? frame}) async =>
      _user(await _call('equipCosmetic', {'theme': theme, 'frame': frame}));

  @override
  Future<List<AchievementView>> achievements() async => [
        for (final item in await _call('achievements', {}) as List? ?? const [])
          readAchievement(item),
      ];

  @override
  Future<UserEntity> profile() async => _user(await _call('profile', {}));

  @override
  Future<AppConfig> getConfig() async =>
      AppConfig.fromMap(_userMap(await _call('getConfig', {})));

  @override
  Future<List<ShopProduct>> adminListShopProducts({
    bool includeInactive = true,
  }) async =>
      _shop(await _call(
        'adminListShopProducts',
        {'includeInactive': includeInactive},
        admin: true,
      ));

  @override
  Future<ShopProduct> adminUpsertShopProduct(ShopProduct product) async =>
      ShopProduct.fromMap(_userMap(await _call(
        'adminUpsertShopProduct',
        {'product': product.toMap()},
        admin: true,
      )));

  @override
  Future<void> adminDeleteShopProduct(String productId) async {
    await _call('adminDeleteShopProduct', {'productId': productId}, admin: true);
  }

  @override
  Future<List<ShopProduct>> adminResetShopCatalog() async =>
      _shop(await _call('adminResetShopCatalog', {}, admin: true));

  @override
  Future<List<WordEntity>> adminListWords() async =>
      _words(await _call('adminListWords', {}, admin: true));

  @override
  Future<WordEntity> adminUpsertWord(WordEntity word) async =>
      WordEntity.fromMap(_userMap(await _call(
        'adminUpsertWord',
        {'word': word.toMap()},
        admin: true,
      )));

  @override
  Future<void> adminDeleteWord(String wordId) async {
    await _call('adminDeleteWord', {'wordId': wordId}, admin: true);
  }

  @override
  Future<WordImportResult> adminImportWords(String csv) async {
    final data = await _call(
      'adminImportWords',
      {'csv': csv},
      admin: true,
      timeout: const Duration(minutes: 3),
    );
    final map = data is Map ? Map<dynamic, dynamic>.from(data) : const {};
    return WordImportResult.fromMap(map);
  }

  @override
  Future<void> adminSetDaily({
    required String dateKey,
    required LeagueTier league,
    required String wordId,
    String language = 'tr',
  }) async {
    await _call('adminSetDaily', {
      'dateKey': dateKey,
      'league': league.name,
      'wordId': wordId,
      'language': language,
    }, admin: true);
  }

  @override
  Future<int> adminAutoAssignMonth({
    required int year,
    required int month,
    required LeagueTier league,
    String locale = 'tr',
  }) async =>
      await _call('adminAutoAssignMonth', {
        'year': year,
        'month': month,
        'league': league.name,
        'locale': locale,
      }, admin: true) as int? ??
      0;

  @override
  Future<AdminOverview> adminOverview({String locale = 'tr'}) async =>
      readOverview(await _call('adminOverview', {'locale': locale}, admin: true));

  @override
  Future<List<UserEntity>> adminListUsers({
    String query = '',
    AdminUserKind kind = AdminUserKind.all,
  }) async =>
      [
        for (final item in await _call('adminListUsers', {
              'query': query,
              'kind': kind.name,
            }, admin: true) as List? ??
            const [])
          _user(item),
      ];

  @override
  Future<AdminUserDetail> adminUserDetail(String userId) async =>
      readUserDetail(await _call('adminUserDetail', {'userId': userId}, admin: true));

  @override
  Future<List<AdminGameRecord>> adminListGames({
    String? userId,
    GameType? type,
    bool? won,
  }) async =>
      [
        for (final item in await _call('adminListGames', {
              'userId': userId,
              'type': type?.name,
              'won': won,
            }, admin: true) as List? ??
            const [])
          readGameRecord(item),
      ];

  @override
  Future<AdminSessionDetail?> adminGetSession(String sessionId) async {
    final data = await _call('adminGetSession', {'sessionId': sessionId}, admin: true);
    if (data == null) return null;
    return readSessionDetail(data);
  }

  @override
  Future<void> adminBanUser(String userId, bool banned, {String? reason}) async {
    await _call('adminBanUser', {
      'userId': userId,
      'banned': banned,
      'reason': reason,
    }, admin: true);
  }

  @override
  Future<UserEntity> adminSetDisplayName(String userId, String name) async =>
      _user(await _call('adminSetDisplayName', {
        'userId': userId,
        'name': name,
      }, admin: true));

  @override
  Future<UserEntity> adminAdjustCoins(
    String userId,
    int delta, {
    String reason = 'ADMIN_GRANT',
  }) async =>
      _user(await _call('adminAdjustCoins', {
        'userId': userId,
        'delta': delta,
        'reason': reason,
      }, admin: true));

  @override
  Future<List<LeaderboardEntry>> adminLeagueStandings(
    LeagueTier league, {
    String locale = 'tr',
    RankPeriod period = RankPeriod.week,
    String? periodId,
  }) async =>
      _board(await _call('adminLeagueStandings', {
        'league': league.name,
        'locale': locale,
        'period': period.name,
        'periodId': periodId,
      }, admin: true));

  @override
  Future<AppConfig> adminUpdateConfig(AppConfig config) async =>
      AppConfig.fromMap(_userMap(await _call(
        'adminUpdateConfig',
        {'config': config.toMap()},
        admin: true,
      )));

  @override
  Future<Map<String, String>> adminDailyMap() async {
    final data = await _call('adminDailyMap', {}, admin: true);
    if (data is! Map) return {};
    return {for (final e in data.entries) '${e.key}': '${e.value}'};
  }
}
