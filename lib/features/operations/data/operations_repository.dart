import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// What the organization's plan includes — backend/modules/operations.
///
/// GET /api/operations/entitlements -> { features: { production: bool,
/// inventory: bool, ... }, limits, subscription, access, ... }. Anybody signed
/// in may ask; the web employee app uses it to decide whether the production
/// floor (`production`) and the warehouse scanner (`inventory`) are shown.
class OperationsRepository {
  final ApiClient apiClient;

  OperationsRepository({required this.apiClient});

  Future<Map<String, bool>> getFeatures() async {
    try {
      final response = await apiClient.get('/operations/entitlements');

      final data = asMap(unwrapData(response.data));
      final features = asMap(data['features']);

      return features.map((key, value) => MapEntry(key, value == true));
    } catch (e) {
      throw apiException(e, 'Unable to load your plan.');
    }
  }
}
