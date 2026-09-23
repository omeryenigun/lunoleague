import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:kelimelig/core/errors/failures.dart';
import 'package:kelimelig/core/l10n/l10n.dart';
import 'package:kelimelig/core/services/google_auth.dart';
import 'package:kelimelig/core/services/logger_service.dart';
import 'package:kelimelig/core/services/motion_manager.dart';
import 'package:kelimelig/core/theme/appearance.dart';
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
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [loading, user, error];
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._server) : super(const AuthState());

  final GameServer _server;

  void _syncPrefs(UserEntity? user) {
    sl<Appearance>().sync(user);
    if (sl.isRegistered<MotionManager>()) {
      sl<MotionManager>().enabled = user?.animationsOn ?? true;
    }
  }

  Future<void> bootstrap() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final user = await _server.currentUser();
      _syncPrefs(user);
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

  Future<void> google() async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final profile = await sl<GoogleAuth>().signIn();
      if (profile == null) {
        emit(state.copyWith(loading: false));
        return;
      }
      sl<AnalyticsService>().event('signup', {'provider': 'google'});
      await _run(
        () => _server.signInWithGoogle(
          googleId: profile.id,
          email: profile.email,
          displayName: profile.displayName,
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: _msg(e)));
    }
  }

  Future<void> apple() {
    sl<AnalyticsService>().event('signup', {'provider': 'apple'});
    return _run(() => _server.signInWithApple());
  }

  Future<void> registerEmail({
    required String email,
    required String password,
    String? displayName,
    String? avatar,
  }) {
    sl<AnalyticsService>().event('signup', {'provider': 'email'});
    return _run(
      () => _server.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
        avatar: avatar,
      ),
    );
  }

  Future<void> signInEmail({
    required String email,
    required String password,
  }) {
    sl<AnalyticsService>().event('login', {'provider': 'email'});
    return _run(
      () => _server.signInWithEmail(email: email, password: password),
    );
  }

  Future<void> setName(String name) => _run(() => _server.setDisplayName(name));
  Future<void> finishOnboarding() => _run(() => _server.completeOnboarding());

  Future<void> signOut() async {
    await _server.signOut();
    emit(const AuthState(loading: false));
  }

  Future<void> refreshUser() async {
    try {
      final user = await _server.currentUser();
      _syncPrefs(user);
      emit(state.copyWith(loading: false, user: user, clearError: true));
    } catch (e) {
      emit(state.copyWith(loading: false, error: _msg(e)));
    }
  }

  Future<void> _run(Future<UserEntity> Function() action) async {
    emit(state.copyWith(loading: true, clearError: true));
    try {
      final user = await action();
      _syncPrefs(user);
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
