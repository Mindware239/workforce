import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/features/profile/data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(
    apiClient: ref.read(apiClientProvider),
  );
});

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(
    repository: ref.read(profileRepositoryProvider),
  );
});

class ProfileState {
  final bool isLoading;
  final Map<String, dynamic>? profile;
  final String? error;

  const ProfileState({
    this.isLoading = false,
    this.profile,
    this.error,
  });

  ProfileState copyWith({
    bool? isLoading,
    Map<String, dynamic>? profile,
    String? error,
    bool clearError = false,
  }) {
    return ProfileState(
      isLoading: isLoading ?? this.isLoading,
      profile: profile ?? this.profile,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class ProfileNotifier extends StateNotifier<ProfileState> {
  final ProfileRepository repository;

  ProfileNotifier({
    required this.repository,
  }) : super(const ProfileState());

  Future<void> getProfile() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    try {
      final profile = await repository.getProfile();

      state = state.copyWith(
        isLoading: false,
        profile: profile,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}