import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/services/secure_storage.dart';
import 'api_client.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    secureStorage: ref.read(secureStorageProvider),
  );
});

final secureStorageProvider = Provider<SecureStorage>((ref) {
  return SecureStorage();
});