import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/services/secure_storage.dart';

/// Device-management client.
///
/// Enrolls this device with the server, then polls for admin commands and runs
/// each through the native [MethodChannel] (DevicePolicyManager lives on the
/// Kotlin side — see MdmCommandExecutor.kt), reporting the result back.
///
/// Consent gate: the server refuses to issue commands until the device has
/// recorded the user's consent, captured once by the consent screen. This
/// client never acts on its own; it only carries out what the admin issued.
class MdmService {
  MdmService({ApiClient? apiClient, SecureStorage? storage})
      : _api = apiClient ?? ApiClient(secureStorage: storage ?? SecureStorage());

  static const _channel = MethodChannel('workforce/mdm');
  static const _consentKey = 'mdm_consent_version';

  /// Must match the backend's CURRENT_CONSENT_VERSION.
  static const consentVersion = '1';

  final ApiClient _api;

  Future<Map<String, dynamic>> _deviceInfo() async {
    final info = await _channel.invokeMapMethod<String, dynamic>('getDeviceInfo');
    return info ?? <String, dynamic>{};
  }

  Future<bool> hasConsent() async {
    final stored = await SecureStorage().read(key: _consentKey);
    return stored == consentVersion;
  }

  Future<void> recordConsent() async {
    await SecureStorage().write(key: _consentKey, value: consentVersion);
    await enroll();
  }

  /// Enroll (or refresh) this device. Safe to call on every app start.
  Future<void> enroll() async {
    try {
      final info = await _deviceInfo();
      if (info['deviceUid'] == null) return;
      await _api.post('/mdm/devices/enroll', data: {
        ...info,
        'consentGiven': await hasConsent(),
        'consentVersion': consentVersion,
      });
    } catch (e) {
      debugPrint('⚠️ MDM enroll failed: $e');
    }
  }

  /// Fetch pending commands, run each natively, and acknowledge the outcome.
  /// Called on app start, on resume, and when an `mdm-command` FCM arrives.
  Future<void> syncCommands() async {
    try {
      final info = await _deviceInfo();
      final deviceUid = info['deviceUid'] as String?;
      if (deviceUid == null) return;

      final response = await _api.get(
        '/mdm/devices/commands',
        queryParameters: {'deviceUid': deviceUid},
      );
      final data = response.data['data'] as Map<String, dynamic>?;
      final commands = (data?['commands'] as List?) ?? const [];

      for (final raw in commands) {
        final command = raw as Map<String, dynamic>;
        final id = command['id'];
        final name = command['command'] as String?;
        if (id == null || name == null) continue;

        Map<String, dynamic> outcome;
        try {
          final res = await _channel.invokeMapMethod<String, dynamic>(
            'executeCommand',
            {'command': name},
          );
          outcome = res ?? {'ok': false, 'detail': 'no response'};
        } catch (e) {
          outcome = {'ok': false, 'detail': 'channel error: $e'};
        }

        await _api.post('/mdm/devices/commands/$id/ack', data: {
          'deviceUid': deviceUid,
          'ok': outcome['ok'] == true,
          'result': outcome['detail'],
        });
      }
    } catch (e) {
      debugPrint('⚠️ MDM command sync failed: $e');
    }
  }
}
