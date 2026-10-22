import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// Account-level calls the settings screens make: the organization's terms,
/// changing the password, saving preferences, and the account deletion
/// request (backend/modules/accountDeletion — nobody deletes their own
/// account; the request waits for the organization that added them).
class AccountRepository {
  final ApiClient apiClient;

  AccountRepository({required this.apiClient});

  /// GET /organizations/terms -> { content, updatedAt, updatedByName }.
  Future<Map<String, dynamic>> getTerms() async {
    try {
      final response = await apiClient.get('/organizations/terms');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not load the terms. Please try again.');
    }
  }

  /// PATCH /auth/password. Returns the fresh token: other sessions are
  /// signed out, this one carries on with the new token.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await apiClient.dio.patch(
        '/auth/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );

      final token = asMap(unwrapData(response.data))['token']?.toString();

      return token == null || token.isEmpty ? null : token;
    } catch (e) {
      throw apiException(e, 'Could not change the password.');
    }
  }

  /// PUT /auth/preferences — the language follows the person to the web.
  Future<void> savePreferences({String? language}) async {
    try {
      await apiClient.put(
        '/auth/preferences',
        data: {'language': ?language},
      );
    } catch (e) {
      throw apiException(e, 'Could not save the preference.');
    }
  }

  /// GET /account-deletion/me — the latest request, or null.
  Future<Map<String, dynamic>?> getMyDeletionRequest() async {
    try {
      final response = await apiClient.get('/account-deletion/me');
      final data = unwrapData(response.data);

      return data is Map ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      throw apiException(e, 'Could not load your request.');
    }
  }

  /// POST /account-deletion/me { reason }.
  Future<Map<String, dynamic>> requestDeletion({String? reason}) async {
    try {
      final trimmed = reason?.trim();
      final response = await apiClient.post(
        '/account-deletion/me',
        data: {
          'reason': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
        },
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(
        e,
        'The request could not be sent. Please try again.',
      );
    }
  }

  /// DELETE /account-deletion/me — withdraws a pending request.
  Future<Map<String, dynamic>> cancelDeletion() async {
    try {
      final response = await apiClient.delete('/account-deletion/me');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not withdraw the request.');
    }
  }
}
