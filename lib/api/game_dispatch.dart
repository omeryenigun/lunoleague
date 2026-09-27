import 'package:kelimelig/api/game_wire.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/data/local/local_game_server.dart';
import 'package:kelimelig/domain/entities/app_config.dart';
import 'package:kelimelig/domain/entities/shop_product.dart';
import 'package:kelimelig/domain/entities/word_entity.dart';

const adminOps = {
  'adminListShopProducts',
  'adminUpsertShopProduct',
  'adminDeleteShopProduct',
  'adminResetShopCatalog',
  'adminListWords',
  'adminUpsertWord',
  'adminDeleteWord',
  'adminImportWords',
  'adminSetDaily',
  'adminAutoAssignMonth',
  'adminOverview',
  'adminListUsers',
  'adminUserDetail',
  'adminListGames',
  'adminGetSession',
  'adminBanUser',
  'adminSetDisplayName',
  'adminAdjustCoins',
  'adminLeagueStandings',
  'adminUpdateConfig',
  'adminDailyMap',
};

int asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.parse('$value');
}

bool? asBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  return null;
}

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected an object');
}

/// Runs one [GameServer] operation and returns a JSON value.
Future<Object?> dispatchGame(
  LocalGameServer game,
  String op,
  Map<String, dynamic> args,
) async {
  switch (op) {
    case 'currentUser':
      return (await game.currentUser())?.toMap();
    case 'signInAnonymously':
      return (await game.signInAnonymously()).toMap();
    case 'signInWithGoogle':
      return (await game.signInWithGoogle(
        googleId: args['googleId'] as String? ?? '',
        email: args['email'] as String?,
        displayName: args['displayName'] as String?,
      ))
          .toMap();
    case 'signInWithApple':
      return (await game.signInWithApple(displayName: args['displayName'] as String?)).toMap();
    case 'registerWithEmail':
      return (await game.registerWithEmail(
        email: args['email'] as String? ?? '',
        password: args['password'] as String? ?? '',
        displayName: args['displayName'] as String?,
        avatar: args['avatar'] as String?,
      ))
          .toMap();
    case 'signInWithEmail':
      return (await game.signInWithEmail(
        email: args['email'] as String? ?? '',
        password: args['password'] as String? ?? '',
      ))
          .toMap();
    case 'setDisplayName':
      return (await game.setDisplayName(args['name'] as String? ?? '')).toMap();
    case 'completeOnboarding':
      return (await game.completeOnboarding()).toMap();
    case 'updateSettings':
      return (await game.updateSettings(
        soundOn: asBool(args['soundOn']),
        hapticOn: asBool(args['hapticOn']),
        animationsOn: asBool(args['animationsOn']),
        notificationsOn: asBool(args['notificationsOn']),
      ))
          .toMap();
    case 'signOut':
      await game.signOut();
      return null;
    case 'hasChosenLocale':
      return game.hasChosenLocale();
    case 'activeLocale':
      return game.activeLocale();
    case 'setLocale':
      return (await game.setLocale(args['localeId'] as String? ?? 'tr'))?.toMap();
    case 'setLeague':
      return (await game.setLeague(LeagueTier.values.byName(args['league'] as String))).toMap();
    case 'homeSnapshot':
      return wireHome(await game.homeSnapshot());
    case 'prepareNextDaily':
      return game.prepareNextDaily();
    case 'startDaily':
      return wireSession(await game.startDaily());
    case 'startEndless':
      return wireSession(await game.startEndless());
    case 'marathonSnapshot':
      return (await game.marathonSnapshot()).toMap();
    case 'endEndlessRun':
      return game.endEndlessRun();
    case 'duelCreate':
      return (await game.duelCreate()).toMap();
    case 'duelJoin':
      return (await game.duelJoin(args['code'] as String? ?? '')).toMap();
    case 'duelPoll':
      return (await game.duelPoll()).toMap();
    case 'duelCancel':
      return (await game.duelCancel()).toMap();
    case 'duelStart':
      return (await game.duelStart()).toMap();
    case 'roomCreate':
      return (await game.roomCreate()).toMap();
    case 'roomJoin':
      return (await game.roomJoin(args['code'] as String? ?? '')).toMap();
    case 'roomPoll':
      return (await game.roomPoll()).toMap();
    case 'roomLeave':
      return (await game.roomLeave()).toMap();
    case 'roomStart':
      return (await game.roomStart()).toMap();
    case 'matchSnapshot':
      return (await game.matchSnapshot(args['kind'] as String? ?? 'duel')).toMap();
    case 'openAssigned':
      return wireSession(
        await game.openAssigned(GameType.values.byName(args['type'] as String)),
      );
    case 'activeSession':
      return wireSession(await game.activeSession(GameType.values.byName(args['type'] as String)));
    case 'submitGuess':
      return wireSession(await game.submitGuess(
        args['sessionId'] as String,
        args['guess'] as String? ?? '',
      ));
    case 'requestHint':
      return wireSession(await game.requestHint(
        args['sessionId'] as String,
        HintLevel.values.byName(args['level'] as String),
      ));
    case 'claimDailyReward':
      return wireReward(await game.claimDailyReward());
    case 'watchRewardedAd':
      return game.watchRewardedAd();
    case 'restoreEndlessRunAfterAd':
      await game.restoreEndlessRunAfterAd();
      return null;
    case 'listShopProducts':
      return (await game.listShopProducts()).map((p) => p.toMap()).toList();
    case 'purchaseShopProduct':
      return (await game.purchaseShopProduct(
        args['productId'] as String,
        purchaseToken: args['purchaseToken'] as String? ?? '',
      ))
          .toMap();
    case 'saveWord':
      await game.saveWord(args['wordId'] as String);
      return null;
    case 'wordBook':
      return (await game.wordBook()).map(wireSaved).toList();
    case 'leaderboard':
      return (await game.leaderboard()).map(wireBoard).toList();
    case 'leagueStandings':
      return (await game.leagueStandings()).map(wireBoard).toList();
    case 'competitionSnapshot':
      return wireCompetition(await game.competitionSnapshot());
    case 'equipCosmetic':
      return (await game.equipCosmetic(
        theme: args['theme'] as String?,
        frame: args['frame'] as String?,
      ))
          .toMap();
    case 'achievements':
      return (await game.achievements()).map(wireAchievement).toList();
    case 'profile':
      return (await game.profile()).toMap();
    case 'resultBoard':
      return (await game.resultBoard(
        type: GameType.values.byName(args['type'] as String? ?? 'daily'),
        wordId: args['wordId'] as String? ?? '',
      ))
          .map((row) => row.toMap())
          .toList();
    case 'getConfig':
      return (await game.getConfig()).toMap();
    case 'adminListShopProducts':
      return (await game.adminListShopProducts(
        includeInactive: args['includeInactive'] as bool? ?? true,
      ))
          .map((p) => p.toMap())
          .toList();
    case 'adminUpsertShopProduct':
      return (await game.adminUpsertShopProduct(
        ShopProduct.fromMap(asMap(args['product'])),
      ))
          .toMap();
    case 'adminDeleteShopProduct':
      await game.adminDeleteShopProduct(args['productId'] as String);
      return null;
    case 'adminResetShopCatalog':
      return (await game.adminResetShopCatalog()).map((p) => p.toMap()).toList();
    case 'adminListWords':
      return (await game.adminListWords()).map((w) => w.toMap()).toList();
    case 'adminUpsertWord':
      return (await game.adminUpsertWord(WordEntity.fromMap(asMap(args['word'])))).toMap();
    case 'adminDeleteWord':
      await game.adminDeleteWord(args['wordId'] as String);
      return null;
    case 'adminImportWords':
      return (await game.adminImportWords(args['csv'] as String? ?? '')).toMap();
    case 'adminSetDaily':
      await game.adminSetDaily(
        dateKey: args['dateKey'] as String,
        league: LeagueTier.values.byName(args['league'] as String),
        wordId: args['wordId'] as String,
        language: args['language'] as String? ?? 'tr',
      );
      return null;
    case 'adminAutoAssignMonth':
      return game.adminAutoAssignMonth(
        year: asInt(args['year']),
        month: asInt(args['month']),
        league: LeagueTier.values.byName(args['league'] as String),
        locale: args['locale'] as String? ?? 'tr',
      );
    case 'adminOverview':
      return wireOverview(await game.adminOverview(locale: args['locale'] as String? ?? 'tr'));
    case 'adminListUsers':
      final users = await game.adminListUsers(
        query: args['query'] as String? ?? '',
        kind: AdminUserKind.values.byName(args['kind'] as String? ?? 'all'),
      );
      return users.map((user) => user.toMap()).toList();
    case 'adminUserDetail':
      return wireUserDetail(await game.adminUserDetail(args['userId'] as String));
    case 'adminListGames':
      final games = await game.adminListGames(
        userId: args['userId'] as String?,
        type: args['type'] == null ? null : GameType.values.byName(args['type'] as String),
        won: asBool(args['won']),
      );
      return games.map(wireGameRecord).toList();
    case 'adminGetSession':
      final detail = await game.adminGetSession(args['sessionId'] as String);
      return detail == null ? null : wireSessionDetail(detail);
    case 'adminBanUser':
      await game.adminBanUser(
        args['userId'] as String,
        args['banned'] as bool? ?? true,
        reason: args['reason'] as String?,
      );
      return null;
    case 'adminSetDisplayName':
      return (await game.adminSetDisplayName(
        args['userId'] as String,
        args['name'] as String? ?? '',
      ))
          .toMap();
    case 'adminAdjustCoins':
      return (await game.adminAdjustCoins(
        args['userId'] as String,
        asInt(args['delta']),
        reason: args['reason'] as String? ?? 'ADMIN_GRANT',
      ))
          .toMap();
    case 'adminLeagueStandings':
      final rows = await game.adminLeagueStandings(
        LeagueTier.values.byName(args['league'] as String),
        locale: args['locale'] as String? ?? 'tr',
        period: RankPeriod.values.byName(args['period'] as String? ?? 'week'),
        periodId: args['periodId'] as String?,
      );
      return rows.map(wireBoard).toList();
    case 'adminUpdateConfig':
      return (await game.adminUpdateConfig(AppConfig.fromMap(asMap(args['config'])))).toMap();
    case 'adminDailyMap':
      return game.adminDailyMap();
    default:
      throw FormatException('Unknown operation');
  }
}
