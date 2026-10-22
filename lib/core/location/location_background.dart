import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/services/secure_storage.dart';

import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/services/location_queue.dart';
import 'package:workforce/features/attendence/services/location_sync_service.dart';
import 'package:workforce/features/field_work/services/field_work_tracker.dart';

bool _isHandlingLocation = false;

void startLocationBackground() {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('========================================');
  debugPrint('🚀 BACKGROUND FLUTTER ISOLATE STARTED');
  debugPrint('========================================');

  const channel = MethodChannel(
    'workforce/location_background',
  );

  channel.setMethodCallHandler(
    (call) async {
      debugPrint(
        '📡 Background isolate received: ${call.method}',
      );

      if (call.method != 'locationUpdate') {
        return;
      }

      if (_isHandlingLocation) {
        debugPrint(
          '⏳ Previous location update still processing.',
        );
        return;
      }

      _isHandlingLocation = true;

      try {
        final arguments = call.arguments;

        if (arguments is! Map) {
          debugPrint(
            '❌ Invalid background location arguments.',
          );
          return;
        }

        final data = Map<String, dynamic>.from(
          arguments,
        );

        debugPrint(
          '📍 Background location: $data',
        );

        await BackgroundLocationHandler.handle(data);
      } catch (e, stackTrace) {
        debugPrint(
          '❌ Background location error: $e',
        );

        debugPrint(stackTrace.toString());
      } finally {
        _isHandlingLocation = false;
      }
    },
  );
}

class BackgroundLocationHandler {
  static Future<void> handle(
    Map<String, dynamic> location,
  ) async {
    try {
      // --------------------------------------------------
      // Parse GPS data
      // --------------------------------------------------

      final latitude =
          (location['latitude'] as num?)?.toDouble();

      final longitude =
          (location['longitude'] as num?)?.toDouble();

      final accuracy =
          (location['accuracy'] as num?)?.toDouble() ?? 0;

      final speed =
          (location['speed'] as num?)?.toDouble() ?? 0;

      final heading =
          (location['heading'] as num?)?.toDouble() ?? 0;

      final recordedAt =
          location['recordedAt']?.toString();

      if (latitude == null || longitude == null) {
        debugPrint(
          '❌ Invalid latitude/longitude.',
        );
        return;
      }

      final timestamp =
          recordedAt ??
          DateTime.now().toUtc().toIso8601String();

      debugPrint('📍 Processing location:');
      debugPrint('   lat=$latitude');
      debugPrint('   lng=$longitude');
      debugPrint('   accuracy=$accuracy');
      debugPrint('   recordedAt=$timestamp');

      // --------------------------------------------------
      // Authentication
      // --------------------------------------------------

      final storage = SecureStorage();

      final token = await storage.getToken();

      if (token == null || token.isEmpty) {
        debugPrint(
          '⚠️ No authentication token.',
        );

        debugPrint(
          '🛑 Skipping location processing.',
        );

        return;
      }

      final apiClient = ApiClient(
        secureStorage: storage,
      );

      final attendanceRepository =
          AttendanceRepository(
        apiClient: apiClient,
      );

      // --------------------------------------------------
      // 1. Geofence check
      //
      // Geofence is ONLY for determining whether
      // employee is inside/outside the allowed area.
      //
      // It does NOT control location tracking.
      // --------------------------------------------------

      try {
        final geofenceResponse =
            await attendanceRepository.checkGeofence(
          lat: latitude,
          lng: longitude,
          accuracy: accuracy,
        );

        debugPrint(
          '📍 Geofence response: '
          '$geofenceResponse',
        );

        final geofenceData =
            geofenceResponse['data'];

        if (geofenceData is Map) {
          final isWithinFence =
              geofenceData['isWithinFence'];

          final distanceMeters =
              geofenceData['distanceMeters'];

          final allowedRadiusMeters =
              geofenceData['allowedRadiusMeters'];

          debugPrint(
            '📍 Employee inside geofence: '
            '$isWithinFence',
          );

          debugPrint(
            '📍 Distance from geofence: '
            '$distanceMeters m',
          );

          debugPrint(
            '📍 Allowed radius: '
            '$allowedRadiusMeters m',
          );
        }
      } catch (e) {
        debugPrint(
          '⚠️ Geofence check failed: $e',
        );

        // Important:
        // Geofence failure must NOT stop tracking.
      }

      // --------------------------------------------------
      // 2. ALWAYS send current/live location
      // --------------------------------------------------

      await _sendCurrentLocation(
        apiClient: apiClient,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
        speed: speed,
        heading: heading,
        recordedAt: timestamp,
      );

      // --------------------------------------------------
      // 2b. Field work: while a field session is active,
      // the same fix is also pinged to that session.
      // --------------------------------------------------

      try {
        await FieldWorkTracker.pingIfActive(
          apiClient: apiClient,
          lat: latitude,
          lng: longitude,
          accuracy: accuracy > 0 ? accuracy : null,
          recordedAt: timestamp,
        );
      } catch (e) {
        debugPrint('⚠️ Field work ping failed: $e');
      }

      // --------------------------------------------------
      // 3. ALWAYS add GPS point to tracking queue
      //
      // Even if employee has NOT moved.
      //
      // Example:
      //
      // 10:00     28.4595,77.0266
      // 10:00:30  28.4595,77.0266
      // 10:01     28.4595,77.0266
      //
      // All three are valid tracking points.
      // --------------------------------------------------

      final queue = LocationQueue(
        storage: storage,
      );

      final point = <String, dynamic>{
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'heading': heading,
        'recordedAt': timestamp,
      };

      await queue.add(point);

      debugPrint(
        '📦 Tracking point queued: $point',
      );

      // --------------------------------------------------
      // 4. Schedule batch synchronization
      //
      // Do NOT immediately send /batch.
      // The sync service will wait before sending.
      // --------------------------------------------------

      await LocationSyncService.scheduleSync();

      debugPrint(
        '⏳ Batch tracking sync scheduled.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        '❌ BackgroundLocationHandler error: $e',
      );

      debugPrint(stackTrace.toString());
    }
  }

  // ======================================================
  // CURRENT LOCATION API
  // ======================================================

  static Future<bool> _sendCurrentLocation({
    required ApiClient apiClient,
    required double latitude,
    required double longitude,
    required double accuracy,
    required double speed,
    required double heading,
    required String recordedAt,
  }) async {
    try {
      final response = await apiClient.post(
        '/v1/employee/location',
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'speed': speed,
          'heading': heading,
          'recordedAt': recordedAt,
        },
      );

      debugPrint(
        '📍 Location API response: '
        '${response.data}',
      );

      debugPrint(
        '✅ /v1/employee/location SUCCESS',
      );

      return true;
    } catch (e) {
      debugPrint(
        '❌ /v1/employee/location FAILED: $e',
      );

      return false;
    }
  }
}