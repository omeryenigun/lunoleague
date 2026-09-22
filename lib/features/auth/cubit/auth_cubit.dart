import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/theme/appearance.dart';
import 'package:kelimelig/core/services/logger_service.dart';
import 'package:kelimelig/domain/entities/user_entity.dart';
import 'package:kelimelig/domain/game/game_server.dart';
import 'package:kelimelig/injection.dart';

class AuthState extends Equatable {
  const AuthState({
    this.loading = true,
    this.user,
    this.error,
  });

  final bool loading;
  final UserEntity? user;
  final String? error;

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    bool? loading,
    UserEntity? user,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      loading: loading ?? this.loading,
      user: clearUser ? null : (user ?? this.user),
      error: clearError ? null : error,
    );
  }

  @override
  List<Object?> get props => [loading, user, error];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._server) : super(const AuthState());

  final GameServer _server;

  Future<void> bootstrap() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final user = await _server.currentUser();
      sl<Appearance>().sync(user);
      if (sl.isRegistered<L10n>()) {
        await sl<L10n>().hydrate(_server);
      }
      emit(AuthState(loading: false, user: user));
    } catch (e) {
      emit(AuthState(loading: false, error: _msg(e)));
    }
  }

  Future<void> anonymous() {
    sl<AnalyticsService>().event('signup', {'provider': 'anonymous'});
    return _run(() => _server.signInAnonymously());
  }

  Future<void> google() {
    sl<AnalyticsService>().event('signup', {'provider': 'google'});
    return _run(() => _server.signInWithGoogle());
  }

  Future<void> devBypass({String? displayName}) {
    sl<AnalyticsService>().event('signup', {'provider': 'dev_bypass'});
    final name = displayName?.trim();
    return _run(
      () => _server.signInWithGoogle(
        displayName: (name != null && name.length >= 2) ? name : 'Test Oyuncu',
      ),
    );
  }

  Future<void> apple() {
    sl<AnalyticsService>().event('signup', {'provider': 'apple'});
    return _run(() => _server.signInWithApple());
  }

  Future<void> setName(String name) => _run(() => _server.setDisplayName(name));
  Future<void> finishOnboarding() => _run(() => _server.completeOnboarding());

  Future<void> signOut() async {
    await _server.signOut();
    emit(const AuthState(loading: false));
  }

  Future<void> _run(Future<UserEntity> Function() action) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final user = await action();
      sl<Appearance>().sync(user);
      if (sl.isRegistered<L10n>()) {
        await sl<L10n>().hydrate(_server);
      }
      emit(AuthState(loading: false, user: user));
    } catch (e) {
      emit(state.copyWith(loading: false, error: _msg(e)));
    }
  }

  String _msg(Object e) => e is AppFailure ? e.message : 'Bir sorun oluştu. Lütfen tekrar dene.';
}
