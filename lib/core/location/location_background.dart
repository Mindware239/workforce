import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/services/secure_storage.dart';

import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/services/location_queue.dart';
import 'package:workforce/features/attendence/services/location_sync_service.dart';

bool _isHandlingLocation = false;

void startLocationBackground() {
  WidgetsFlutterBinding.ensureInitialized();

  print('========================================');
  print('🚀 BACKGROUND FLUTTER ISOLATE STARTED');
  print('========================================');

  const channel = MethodChannel(
    'workforce/location_background',
  );

  channel.setMethodCallHandler(
    (call) async {
      print(
        '📡 Background isolate received: ${call.method}',
      );

      if (call.method != 'locationUpdate') {
        return;
      }

      if (_isHandlingLocation) {
        print(
          '⏳ Previous location update still processing.',
        );
        return;
      }

      _isHandlingLocation = true;

      try {
        final arguments = call.arguments;

        if (arguments is! Map) {
          print(
            '❌ Invalid background location arguments.',
          );
          return;
        }

        final data = Map<String, dynamic>.from(
          arguments,
        );

        print(
          '📍 Background location: $data',
        );

        await BackgroundLocationHandler.handle(data);
      } catch (e, stackTrace) {
        print(
          '❌ Background location error: $e',
        );

        print(stackTrace);
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
        print(
          '❌ Invalid latitude/longitude.',
        );
        return;
      }

      final timestamp =
          recordedAt ??
          DateTime.now().toUtc().toIso8601String();

      print('📍 Processing location:');
      print('   lat=$latitude');
      print('   lng=$longitude');
      print('   accuracy=$accuracy');
      print('   recordedAt=$timestamp');

      // --------------------------------------------------
      // Authentication
      // --------------------------------------------------

      final storage = SecureStorage();

      final token = await storage.getToken();

      if (token == null || token.isEmpty) {
        print(
          '⚠️ No authentication token.',
        );

        print(
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

        print(
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

          print(
            '📍 Employee inside geofence: '
            '$isWithinFence',
          );

          print(
            '📍 Distance from geofence: '
            '$distanceMeters m',
          );

          print(
            '📍 Allowed radius: '
            '$allowedRadiusMeters m',
          );
        }
      } catch (e) {
        print(
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

      print(
        '📦 Tracking point queued: $point',
      );

      // --------------------------------------------------
      // 4. Schedule batch synchronization
      //
      // Do NOT immediately send /batch.
      // The sync service will wait before sending.
      // --------------------------------------------------

      await LocationSyncService.scheduleSync();

      print(
        '⏳ Batch tracking sync scheduled.',
      );
    } catch (e, stackTrace) {
      print(
        '❌ BackgroundLocationHandler error: $e',
      );

      print(stackTrace);
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

      print(
        '📍 Location API response: '
        '${response.data}',
      );

      print(
        '✅ /v1/employee/location SUCCESS',
      );

      return true;
    } catch (e) {
      print(
        '❌ /v1/employee/location FAILED: $e',
      );

      return false;
    }
  }
}