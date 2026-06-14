import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  final AuthRepository _repo;

  Future<void> _init() async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _repo.getCurrentUser();
      state = AuthState(user: user, isLoading: false);
    } catch (_) {
      state = const AuthState(isLoading: false);
    }
  }

  Future<bool> login(String email, String password, {bool remember = false}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final auth = await _repo.login(email, password, remember: remember);
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

  Future<void> logoutLocal() async {
    await _repo.clearSession();
    state = const AuthState();
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState();
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(apiClientProvider), ref.watch(storageServiceProvider));
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});

final currentUserProvider = Provider<UserModel?>((ref) => ref.watch(authProvider).user);
