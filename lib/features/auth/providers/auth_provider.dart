import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';

enum AuthStatus {
  initial,
  loading,
  success,
  error,
}

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    Map<String, dynamic>? user,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository repository;

  @override
  AuthState build() {
    repository = ref.read(authRepositoryProvider);

    return const AuthState();
  }

  Future<void> login({
    required String mobileNumber,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
      errorMessage: null,
    );

    try {
      final user = await repository.login(
        mobileNumber: mobileNumber,
      );

      state = state.copyWith(
        status: AuthStatus.success,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  // Restore employee data after app restart
  Future<void> restoreSession() async {
    try {
      final user = await repository.getSavedUser();

      if (user == null) {
        return;
      }

      state = state.copyWith(
        status: AuthStatus.success,
        user: user,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() {
    state = const AuthState();
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);