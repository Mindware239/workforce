import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/network_providers.dart';

import '../data/operations_repository.dart';

final operationsRepositoryProvider = Provider<OperationsRepository>((ref) {
  return OperationsRepository(apiClient: ref.read(apiClientProvider));
});

/// The organization's plan features (`production`, `inventory`, ...).
///
/// Mirrors the web's `useEntitlements`: an entry point that needs a feature
/// is shown only once the features are known and that one is on.
final entitlementsProvider =
    FutureProvider.autoDispose<Map<String, bool>>((ref) {
  return ref.read(operationsRepositoryProvider).getFeatures();
});

/// The two operations features the employee app has screens for.
const String productionFeature = 'production';
const String inventoryFeature = 'inventory';

/// True only when the features are loaded and [feature] is on — the rule the
/// web home uses for its quick actions.
bool featureEnabled(AsyncValue<Map<String, bool>> entitlements, String feature) {
  return entitlements.valueOrNull?[feature] == true;
}

/// True once the features are known and [feature] is off — the web's
/// `useFeatureLocked`. Unknown (loading, or the call failed) reads as
/// available so a screen never flickers locked; the backend still refuses.
bool featureLocked(AsyncValue<Map<String, bool>> entitlements, String feature) {
  final features = entitlements.valueOrNull;

  return features != null && features[feature] != true;
}
