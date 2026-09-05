import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/app_providers.dart';
import '../../../core/utils/api_error.dart';
import '../../../models/user_model.dart';
import '../../../repositories/auth_repository.dart';
import '../../../services/api_client.dart';
import '../../../services/storage_service.dart';

class AuthState {
  const AuthState({this.user, this.isLoading = false, this.error});

  final UserModel? user;
  final bool isLoading;
  final String? error;

  bool get isAuthenticated => user != null;

  AuthState copyWith({UserModel? user, bool? isLoading, String? error, bool clearError = false}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo, this._ref) : super(const AuthState(isLoading: true)) {
    _init();
  }

  final AuthRepository _repo;
  final Ref _ref;

  Future<void> _init() async {
    try {
      final cached = _repo.getCachedUser();
      final hasToken = await _repo.hasToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => false,
      );

      if (cached != null && hasToken) {
        // Leave splash immediately with cached session; refresh in background.
        state = AuthState(user: cached, isLoading: false);
        // ignore: unawaited_futures
        _refreshUserInBackground();
        return;
      }

      if (hasToken) {
        state = state.copyWith(isLoading: true);
        try {
          final user = await _repo.getCurrentUser().timeout(const Duration(seconds: 15));
          if (user != null) {
            state = AuthState(user: user, isLoading: false);
            return;
          }
        } catch (_) {
          // fall through to login
        }
      }

      if (kDebugMode) {
        final ok = await _debugAutoLogin();
        if (ok) return;
      }

      state = const AuthState(isLoading: false);
    } catch (_) {
      // Never leave the user stuck on splash.
      state = const AuthState(isLoading: false);
    }
  }

  /// Debug-only: sign in as admin so testers skip the login screen after DB resets.
  Future<bool> _debugAutoLogin() async {
    const email = String.fromEnvironment(
      'DEV_ADMIN_EMAIL',
      defaultValue: 'admin@chick.com',
    );
    const password = String.fromEnvironment(
      'DEV_ADMIN_PASSWORD',
      defaultValue: 'admin123',
    );
    try {
      await _repo.clearSession();
      final auth = await _repo.login(email, password, remember: true);
      invalidateAllAppData(_ref);
      state = AuthState(user: auth.user, isLoading: false);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshUserInBackground() async {
    try {
      final user = await _repo.getCurrentUser();
      if (user != null) {
        state = AuthState(user: user, isLoading: false);
      } else {
        state = const AuthState(isLoading: false);
      }
    } catch (_) {
      // keep cached user on network errors
    }
  }

  Future<bool> login(String email, String password, {bool remember = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final auth = await _repo.login(email, password, remember: remember);
      invalidateAllAppData(_ref);
      state = AuthState(user: auth.user, isLoading: false);
      return true;
    } on DioException catch (e) {
      final message = _repo.parseError(e) ?? apiErrorMessage(e);
      state = state.copyWith(isLoading: false, error: message);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Clears local session only (used when the token already expired).
  Future<void> refreshUser() async {
    final user = await _repo.getCurrentUser();
    state = AuthState(user: user, isLoading: false);
  }

  /// Escape hatch when splash/init hangs (secure storage or network).
  void forceFinishLoading() {
    if (!state.isLoading) return;
    final cached = _repo.getCachedUser();
    state = AuthState(user: cached, isLoading: false);
  }

  Future<void> logoutLocal() async {
    await _repo.clearSession();
    invalidateAllAppData(_ref);
    state = const AuthState();
  }

  Future<void> logout() async {
    await _repo.logout();
    invalidateAllAppData(_ref);
    state = const AuthState();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(storageServiceProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider), ref);
});

final currentUserProvider = Provider<UserModel?>((ref) => ref.watch(authProvider).user);
