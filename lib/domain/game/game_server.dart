import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/entities/app_config.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/match_snapshot.dart';
import 'package:kelimelig/domain/entities/shop_product.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';
import 'package:kelimelig/domain/entities/word_import_result.dart';

abstract class GameServer {
  Future<UserEntity?> currentUser();
  Future<UserEntity> signInAnonymously();
  /// Links a real Google account. Empty [googleId] must not create a user.
  Future<UserEntity> signInWithGoogle({
    required String googleId,
    String? email,
    String? displayName,
  });
  Future<UserEntity> signInWithApple({String? displayName});
  Future<UserEntity> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
    String? avatar,
  });
  Future<UserEntity> signInWithEmail({
    required String email,
    required String password,
  });
  Future<UserEntity> setDisplayName(String name);
  Future<UserEntity> completeOnboarding();
  Future<UserEntity> updateSettings({
    bool? soundOn,
    bool? hapticOn,
    bool? animationsOn,
    bool? notificationsOn,
  });
  Future<void> signOut();
  Future<bool> hasChosenLocale();
  Future<String> activeLocale();
  Future<UserEntity?> setLocale(String localeId);
  Future<UserEntity> setLeague(LeagueTier league);

  Future<HomeSnapshot> homeSnapshot();
  Future<GameSessionView> startDaily();
  Future<GameSessionView> startEndless();
  Future<MatchSnapshot> duelCreate();
  Future<MatchSnapshot> duelJoin(String code);
  Future<MatchSnapshot> duelPoll();
  Future<MatchSnapshot> duelCancel();
  Future<MatchSnapshot> duelStart();
  Future<MatchSnapshot> roomCreate();
  Future<MatchSnapshot> roomJoin(String code);
  Future<MatchSnapshot> roomPoll();
  Future<MatchSnapshot> roomLeave();
  Future<MatchSnapshot> roomStart();
  Future<MatchSnapshot> matchSnapshot(String kind);
  Future<GameSessionView> openAssigned(GameType type);
  Future<GameSessionView> activeSession(GameType type);
  Future<GameSessionView> submitGuess(String sessionId, String guess);
  Future<GameSessionView> requestHint(String sessionId, HintLevel level);
  Future<DailyRewardResult> claimDailyReward();
  Future<int> watchRewardedAd();
  Future<void> restoreEndlessRunAfterAd();
  Future<List<ShopProduct>> listShopProducts();
  /// Grants the catalog item only when [purchaseToken] is a confirmed Play purchase.
  Future<UserEntity> purchaseShopProduct(
    String productId, {
    required String purchaseToken,
  });
  Future<List<ShopProduct>> adminListShopProducts({bool includeInactive = true});
  Future<ShopProduct> adminUpsertShopProduct(ShopProduct product);
  Future<void> adminDeleteShopProduct(String productId);
  Future<List<ShopProduct>> adminResetShopCatalog();
  Future<void> saveWord(String wordId);
  Future<List<SavedWord>> wordBook();
  Future<List<LeaderboardEntry>> leaderboard();
  Future<List<LeaderboardEntry>> leagueStandings();
  Future<CompetitionSnapshot> competitionSnapshot();
  Future<UserEntity> equipCosmetic({String? theme, String? frame});
  Future<List<AchievementView>> achievements();
  Future<UserEntity> profile();
  Future<List<ResultPlace>> resultBoard({
    required GameType type,
    required String wordId,
  });

  Future<List<WordEntity>> adminListWords();
  Future<WordEntity> adminUpsertWord(WordEntity word);
  Future<void> adminDeleteWord(String wordId);

  /// Inserts CSV rows that are not already stored for the same language.
  /// A bad header throws and writes nothing.
  Future<WordImportResult> adminImportWords(String csv);
  Future<void> adminSetDaily({
    required String dateKey,
    required LeagueTier league,
    required String wordId,
    String language = 'tr',
  });
  /// Fills missing daily slots for [year]/[month] in [locale]/[league].
  /// Returns how many days were assigned.
  Future<int> adminAutoAssignMonth({
    required int year,
    required int month,
    required LeagueTier league,
    String locale = 'tr',
  });
  Future<AdminOverview> adminOverview({String locale = 'tr'});
  Future<List<UserEntity>> adminListUsers({
    String query = '',
    AdminUserKind kind = AdminUserKind.all,
  });
  Future<AdminUserDetail> adminUserDetail(String userId);
  Future<List<AdminGameRecord>> adminListGames({
    String? userId,
    GameType? type,
    bool? won,
  });
  Future<AdminSessionDetail?> adminGetSession(String sessionId);
  Future<void> adminBanUser(String userId, bool banned, {String? reason});
  Future<UserEntity> adminSetDisplayName(String userId, String name);
  Future<UserEntity> adminAdjustCoins(String userId, int delta, {String reason = 'ADMIN_GRANT'});
  Future<List<LeaderboardEntry>> adminLeagueStandings(
    LeagueTier league, {
    String locale = 'tr',
    RankPeriod period = RankPeriod.week,
    String? periodId,
  });
  Future<AppConfig> getConfig();
  Future<AppConfig> adminUpdateConfig(AppConfig config);
  Future<Map<String, String>> adminDailyMap();
}
