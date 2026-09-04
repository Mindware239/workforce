import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/features/attendence/services/fingerprint_service.dart';


final fingerprintServiceProvider =
    Provider<FingerprintService>((ref) {
  return FingerprintService(
    storage: ref.read(secureStorageProvider),
  );
});