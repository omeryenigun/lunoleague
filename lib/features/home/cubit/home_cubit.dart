import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/domain/entities/game_models.dart';
import 'package:kelimelig/domain/game/game_server.dart';

class HomeState extends Equatable {
  const HomeState({
    this.loading = true,
    this.snapshot,
    this.error,
    this.offline = false,
  });

  final bool loading;
  final HomeSnapshot? snapshot;
  final String? error;
  final bool offline;

  @override
  List<Object?> get props => [loading, snapshot, error, offline];
}

class HomeCubit extends Cubit<HomeState> {
  HomeCubit(this._server) : super(const HomeState());

  final GameServer _server;

  void showOffline() {
    emit(const HomeState(loading: false, offline: true));
  }

  Future<void> load() async {
    emit(const HomeState(loading: true));
    try {
      final snap = await _server.homeSnapshot();
      emit(HomeState(loading: false, snapshot: snap));
    } catch (e) {
      emit(HomeState(
        loading: false,
        error: e is AppFailure ? e.message : 'Bir sorun oluştu. Lütfen tekrar dene.',
      ));
    }
  }

  Future<DailyRewardResult?> claimReward() async {
    try {
      final r = await _server.claimDailyReward();
      await load();
      return r;
    } catch (e) {
      emit(HomeState(
        loading: false,
        snapshot: state.snapshot,
        error: e is AppFailure ? e.message : 'Bir sorun oluştu. Lütfen tekrar dene.',
      ));
      return null;
    }
  }
}
