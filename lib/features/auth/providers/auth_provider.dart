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
      errorMessage: errorMessage ?? this.errorMessage,
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
    required String employeeId,
    required String password,
  }) async {
    state = state.copyWith(
      status: AuthStatus.loading,
    );

    try {
      final result = await repository.login(
        employeeId: employeeId,
        password: password,
      );

      state = state.copyWith(
        status: AuthStatus.success,
        user: result['user'],
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);