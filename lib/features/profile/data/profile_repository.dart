
import 'package:workforce/core/network/api_client.dart';

class ProfileRepository {
  final ApiClient apiClient;

  ProfileRepository({required this.apiClient});

  Future<Map<String, dynamic>> getProfile() async {
    final response = await apiClient.get('/auth/profile');
    // debugPrint('✅ Status Code: ${response.statusCode}');
    // debugPrint('📦 Full Response: ${response.data}');

    final responseData = response.data;

    if (responseData is! Map) {
      throw Exception('Invalid profile response.');
    }

    final data = responseData['data'];

    if (data is! Map) {
      throw Exception('Profile data not found.');
    }

    return Map<String, dynamic>.from(data);
  }
}
