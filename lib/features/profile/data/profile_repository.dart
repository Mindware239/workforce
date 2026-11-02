import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

class ProfileRepository {
  final ApiClient apiClient;

  ProfileRepository({required this.apiClient});

  Future<Map<String, dynamic>> getProfile() async {
    try {
      final response = await apiClient.get('/auth/profile');

      final responseData = response.data;

      if (responseData is! Map) {
        throw Exception('Invalid profile response.');
      }

      final data = responseData['data'];

      if (data is! Map) {
        throw Exception('Profile data not found.');
      }

      return Map<String, dynamic>.from(data);
    } catch (e) {
      throw apiException(e, 'Unable to load profile.');
    }
  }
}
