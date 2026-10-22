import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

final onboardingProvider = StateProvider<int>((ref) {
  return 0;
});

/// GET /api/organizations/terms -> `{ content, updatedAt, updatedByName }`.
///
/// The organization's terms and conditions, which the onboarding form asks
/// the employee to read and accept (as the web onboarding dialog does).
final organizationTermsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final response = await ref.read(apiClientProvider).get(
      '/organizations/terms',
    );

    return asMap(unwrapData(response.data));
  } catch (e) {
    throw apiException(e, 'Could not load the terms.');
  }
});
