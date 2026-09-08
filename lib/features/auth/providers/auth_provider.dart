import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/services/auth_service.dart';
import 'package:workforce/features/auth/data/auth_repository.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final bool onboardingPending;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? onboardingStatus;
  final String? error;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.onboardingPending = false,
    this.user,
    this.onboardingStatus,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? onboardingPending,
    Map<String, dynamic>? user,
    Map<String, dynamic>? onboardingStatus,
    String? error,
  }) {
    return AuthState(
      isLoading:
          isLoading ?? this.isLoading,
      isAuthenticated:
          isAuthenticated ??
          this.isAuthenticated,
      onboardingPending:
          onboardingPending ??
          this.onboardingPending,
      user: user ?? this.user,
      onboardingStatus:
          onboardingStatus ??
          this.onboardingStatus,
      error: error,
    );
  }
}

class AuthNotifier
    extends StateNotifier<AuthState> {
  final AuthRepository repository;

  AuthNotifier({
    required this.repository,
  }) : super(const AuthState());

  Future<void> restoreSession() async {
  try {
    final user = await repository.getSavedUser();

    if (user == null) {
      state = const AuthState();
      return;
    }

    final onboardingStatus =
        await repository.getOnboardingStatus();

    final pending =
        onboardingStatus['pending'] == true;

    state = state.copyWith(
      isLoading: false,
      isAuthenticated: true,
      onboardingPending: pending,
      user: user,
      onboardingStatus: onboardingStatus,
    );
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: e.toString(),
    );
  }
}

  Future<bool> login({
    required String mobileNumber,
  }) async {
    state = state.copyWith(
      isLoading: true,
    );

    try {
      final user =
          await repository.login(
        mobileNumber: mobileNumber,
      );

      // -----------------------------------------------
      // IMPORTANT:
      // Token is already saved here.
      // Now check onboarding status.
      // -----------------------------------------------

      final onboardingStatus =
          await repository
              .getOnboardingStatus();

      final pending =
          onboardingStatus['pending'] == true;

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        onboardingPending: pending,
        user: user,
        onboardingStatus:
            onboardingStatus,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );

      rethrow;
    }
  }

  // ------------------------------------------------------
  // Refresh onboarding status
  // ------------------------------------------------------

  Future<bool> checkOnboardingStatus() async {
    try {
      final status =
          await repository
              .getOnboardingStatus();

      final pending =
          status['pending'] == true;

      state = state.copyWith(
        onboardingPending: pending,
        onboardingStatus: status,
      );

      return pending;
    } catch (e) {
      rethrow;
    }
  }

  // ------------------------------------------------------
  // Submit onboarding
  // ------------------------------------------------------

  Future<void> submitOnboarding({
    required String emergencyContact1Relation,
    required String emergencyContact1Number,
    required String emergencyContact2Relation,
    required String emergencyContact2Number,
    required String permanentAddress,
    required String correspondenceAddress,
    required bool termsAccepted,
    String? fullName,
    String? mobileNumber,
    String? email,
  }) async {
    state = state.copyWith(
      isLoading: true,
    );

    try {
      final result =
          await repository.submitOnboarding(
        emergencyContact1Relation:
            emergencyContact1Relation,
        emergencyContact1Number:
            emergencyContact1Number,
        emergencyContact2Relation:
            emergencyContact2Relation,
        emergencyContact2Number:
            emergencyContact2Number,
        permanentAddress:
            permanentAddress,
        correspondenceAddress:
            correspondenceAddress,
        termsAccepted:
            termsAccepted,
        fullName: fullName,
        mobileNumber: mobileNumber,
        email: email,
      );

      final pending =
          result['pending'] == true;

      state = state.copyWith(
        isLoading: false,
        onboardingPending: pending,
        onboardingStatus: result,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );

      rethrow;
    }
  }

  // ------------------------------------------------------
  // Logout
  // ------------------------------------------------------

  Future<void> logout() async {
    await repository.secureStorage
        .clearAuth();

    AuthService.logout();

    state = const AuthState();
  }
}

final authProvider =
    StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) {
    return AuthNotifier(
      repository:
          ref.read(authRepositoryProvider),
    );
  },
);