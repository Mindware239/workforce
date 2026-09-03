
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';

class BankDetailsRepository {
  final ApiClient apiClient;

  BankDetailsRepository({required this.apiClient});

  // GET /api/auth/bank-details
  Future<Map<String, dynamic>?> getBankDetails() async {
    final response = await apiClient.get('/auth/bank-details');

    if (response.data == null) {
      return null;
    }

    return Map<String, dynamic>.from(response.data);
  }

  // PUT /api/auth/bank-details
  Future<Map<String, dynamic>> saveBankDetails({
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    String? branchName,
  }) async {
    final requestData = {
      'accountHolderName': accountHolderName,
      'accountNumber': accountNumber,
      'ifscCode': ifscCode.toUpperCase(),
      'bankName': bankName,
      if (branchName != null && branchName.trim().isNotEmpty)
        'branchName': branchName.trim(),
    };

    final response = await apiClient.put(
      '/auth/bank-details',
      data: requestData,
    );

    return Map<String, dynamic>.from(response.data);
  }
}

final bankDetailsRepositoryProvider = Provider<BankDetailsRepository>((ref) {
  return BankDetailsRepository(apiClient: ref.read(apiClientProvider));
});
