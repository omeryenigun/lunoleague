import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/domain/entities/admin_models.dart';
import 'package:kelimelig/domain/entities/app_config.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';

abstract class GameServer {
  Future<UserEntity?> currentUser();
  Future<UserEntity> signInAnonymously();
  Future<UserEntity> signInWithGoogle({String? displayName});
  Future<UserEntity> signInWithApple({String? displayName});
  Future<UserEntity> setDisplayName(String name);
  Future<UserEntity> completeOnboarding();
  Future<UserEntity> updateSettings({
    bool? soundOn,
    bool? hapticOn,
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
  Future<GameSessionView> activeSession(GameType type);
  Future<GameSessionView> submitGuess(String sessionId, String guess);
  Future<GameSessionView> requestHint(String sessionId, HintLevel level);
  Future<DailyRewardResult> claimDailyReward();
  Future<int> watchRewardedAd();
  Future<void> restoreEndlessRunAfterAd();
  Future<void> saveWord(String wordId);
  Future<List<SavedWord>> wordBook();
  Future<List<LeaderboardEntry>> leaderboard();
  Future<List<LeaderboardEntry>> leagueStandings();
  Future<CompetitionSnapshot> competitionSnapshot();
  Future<UserEntity> equipCosmetic({String? theme, String? frame});
  Future<List<AchievementView>> achievements();
  Future<UserEntity> profile();

  Future<List<WordEntity>> adminListWords();
  Future<WordEntity> adminUpsertWord(WordEntity word);
  Future<void> adminDeleteWord(String wordId);
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
  Future<UserEntity> adminAdjustCoins(String userId, int delta, {String reason = 'ADMIN_GRANT'});
  Future<List<LeaderboardEntry>> adminLeagueStandings(
    LeagueTier league, {
    String locale = 'tr',
  });
  Future<AppConfig> getConfig();
  Future<AppConfig> adminUpdateConfig(AppConfig config);
  Future<Map<String, String>> adminDailyMap();
}
