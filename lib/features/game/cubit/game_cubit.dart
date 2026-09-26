import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelimelig/core/constants/enums.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/game_locale.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/logger_service.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class GameState extends Equatable {
  const GameState({
    this.loading = true,
    this.session,
    this.input = const [],
    this.flipping = false,
    this.error,
    this.errorCode,
    this.league,
    this.coins = 0,
    this.locale = 'tr',
  });

  final bool loading;
  final GameSessionView? session;
  final List<String> input;
  final bool flipping;
  final String? error;
  final String? errorCode;
  final LeagueTier? league;
  final int coins;
  final String locale;

  GameLocale get gameLocale => GameLocale.resolve(locale);

  @override
  List<Object?> get props =>
      [loading, session, input, flipping, error, errorCode, league, coins, locale];

  GameState copyWith({
    bool? loading,
    GameSessionView? session,
    List<String>? input,
    bool? flipping,
    String? error,
    String? errorCode,
    bool clearError = false,
    LeagueTier? league,
    int? coins,
    String? locale,
  }) {
    return GameState(
      loading: loading ?? this.loading,
      session: session ?? this.session,
      input: input ?? this.input,
      flipping: flipping ?? this.flipping,
      error: clearError ? null : error,
      errorCode: clearError ? null : errorCode,
      league: league ?? this.league,
      coins: coins ?? this.coins,
      locale: locale ?? this.locale,
    );
  }
}

class GameCubit extends Cubit<GameState> {
  GameCubit(this._server, this.type) : super(const GameState());

  final GameServer _server;
  final GameType type;

  Future<void> start() async {
    emit(const GameState(loading: true));
    try {
      final session = switch (type) {
        GameType.daily => await _server.startDaily(),
        GameType.endless => await _server.startEndless(),
        GameType.duel || GameType.room => await _server.openAssigned(type),
      };
      final user = await _server.currentUser();
      final locale = user?.locale ?? await _server.activeLocale();
      emit(GameState(
        loading: false,
        session: session,
        league: user != null && user.canJoinLeague ? user.currentLeague : null,
        coins: user?.coin ?? 0,
        locale: locale,
      ));
    } on AppFailure catch (e) {
      emit(GameState(loading: false, error: e.message, errorCode: e.code));
    } catch (e) {
      emit(GameState(loading: false, error: _msg(e)));
    }
  }

  Future<void> reviveAndStart() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      await _server.restoreEndlessRunAfterAd();
      await start();
    } catch (e) {
      emit(state.copyWith(loading: false, error: _msg(e)));
    }
  }

  void tapLetter(String letter) {
    final s = state.session;
    if (s == null || s.isFinished || state.flipping) return;
    if (state.input.length >= s.wordLength) return;
    if (!state.gameLocale.isAllowedLetter(letter)) return;
    emit(state.copyWith(input: [...state.input, state.gameLocale.toUpper(letter)], clearError: true));
  }

  void backspace() {
    if (state.input.isEmpty || state.flipping) return;
    emit(state.copyWith(input: [...state.input]..removeLast(), clearError: true));
  }

  Future<void> submit() async {
    final s = state.session;
    if (s == null || s.isFinished || state.flipping) return;
    if (state.input.length != s.wordLength) {
      emit(state.copyWith(error: _tooShort(s.wordLength)));
      return;
    }
    emit(state.copyWith(flipping: true, clearError: true));
    try {
      final next = await _server.submitGuess(s.sessionId, state.input.join());
      sl<AnalyticsService>().event('guess_submitted', {'won': next.outcome?.won});
      if (next.outcome?.won == true) sl<AnalyticsService>().event('game_won');
      if (next.outcome?.won == false) sl<AnalyticsService>().event('game_lost');
      emit(state.copyWith(session: next, flipping: false, loading: false, input: const []));
    } catch (e) {
      emit(state.copyWith(flipping: false, error: _msg(e), input: state.input));
    }
  }

  void setCoins(int coins) => emit(state.copyWith(coins: coins));

  Future<void> hint(HintLevel level) async {
    final s = state.session;
    if (s == null || s.isFinished) return;
    try {
      final next = await _server.requestHint(s.sessionId, level);
      final user = await _server.currentUser();
      final rowChanged = level == HintLevel.letter &&
          next.currentAttempt != s.currentAttempt;
      emit(state.copyWith(
        session: next,
        clearError: true,
        coins: user?.coin,
        input: rowChanged ? const [] : null,
      ));
    } catch (e) {
      emit(state.copyWith(error: _msg(e)));
    }
  }

  String _tooShort(int n) {
    if (sl.isRegistered<L10n>()) {
      return sl<L10n>().t('too_short').replaceAll('{n}', '$n');
    }
    return 'Lütfen $n harfli bir kelime gir.';
  }

  String _msg(Object e) =>
      e is AppFailure ? e.message : 'Bir sorun oluştu. Lütfen tekrar dene.';
}
