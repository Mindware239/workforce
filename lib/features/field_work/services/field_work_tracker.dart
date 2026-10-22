import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/services/secure_storage.dart';

/// Field-work pings, riding on the app's existing location tracker.
///
/// There is no second GPS watch: the native foreground service
/// (LocationTrackingService.kt -> core/location/location_background.dart)
/// already delivers a fix every 15-30 s while the employee is logged in.
/// While a field session is active its id is kept in secure storage, and
/// every fix the background isolate receives is also offered to
/// [pingIfActive], which forwards it to
/// `POST /location/field-sessions/:id/ping` with the web tracker's rules
/// (frontend/src/hooks/use-field-tracker.ts): at most one ping every 15 s
/// unless the person has moved 30 m, and fixes worse than 100 m are noted
/// but not sent.
///
/// The field-work screen, while open, offers its own foreground fixes too,
/// so tracking still works when the background service is not running.
/// Both paths share the throttle through the stored state.
class FieldWorkTracker {
  static const _sessionKey = 'field_work_active_session';
  static const _stateKey = 'field_work_tracker_state';

  static const Duration minInterval = Duration(seconds: 15);
  static const double minDistanceMeters = 30;
  static const double poorAccuracyMeters = 100;
  static const Duration staleAfter = Duration(minutes: 2);

  static SecureStorage get _storage => SecureStorage();

  static Future<int?> activeSessionId() async {
    final value = await _storage.read(key: _sessionKey);

    return int.tryParse(value ?? '');
  }

  static Future<void> setActiveSession(int id) async {
    await _storage.write(key: _sessionKey, value: '$id');
    await _storage.delete(key: _stateKey);
  }

  static Future<void> clear() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _stateKey);
  }

  /// What the last fix did: `{ result: sent|failed|poor, at, lat, lng,
  /// accuracy, message }`, or null before the first one.
  static Future<FieldTrackerSnapshot?> snapshot() async {
    final raw = await _storage.read(key: _stateKey);

    if (raw == null || raw.isEmpty) return null;

    try {
      return FieldTrackerSnapshot.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _save(FieldTrackerSnapshot value) async {
    await _storage.write(key: _stateKey, value: jsonEncode(value.toJson()));
  }

  /// Offers one fix to the active field session, if there is one.
  static Future<void> pingIfActive({
    required ApiClient apiClient,
    required double lat,
    required double lng,
    double? accuracy,
    String? recordedAt,
  }) async {
    final sessionId = await activeSessionId();

    if (sessionId == null) return;

    final now = DateTime.now();
    final previous = await snapshot();

    if (accuracy != null && accuracy > poorAccuracyMeters) {
      await _save(
        FieldTrackerSnapshot(
          result: 'poor',
          at: now,
          lat: lat,
          lng: lng,
          accuracy: accuracy,
          lastSentAt: previous?.lastSentAt,
          lastSentLat: previous?.lastSentLat,
          lastSentLng: previous?.lastSentLng,
        ),
      );
      return;
    }

    final lastSentAt = previous?.lastSentAt;
    final movedEnough = previous?.lastSentLat == null ||
        previous?.lastSentLng == null ||
        Geolocator.distanceBetween(
              previous!.lastSentLat!,
              previous.lastSentLng!,
              lat,
              lng,
            ) >=
            minDistanceMeters;
    final due = lastSentAt == null || now.difference(lastSentAt) >= minInterval;

    // The server refuses pings closer together than ~10 s whatever the
    // distance, so never go below that.
    final tooSoon = lastSentAt != null &&
        now.difference(lastSentAt) < const Duration(seconds: 10);

    if (tooSoon || (!movedEnough && !due)) return;

    try {
      await apiClient.post(
        '/location/field-sessions/$sessionId/ping',
        data: {
          'lat': lat,
          'lng': lng,
          'accuracy': ?accuracy,
          'recordedAt': recordedAt ?? now.toUtc().toIso8601String(),
        },
      );

      await _save(
        FieldTrackerSnapshot(
          result: 'sent',
          at: now,
          lat: lat,
          lng: lng,
          accuracy: accuracy,
          lastSentAt: now,
          lastSentLat: lat,
          lastSentLng: lng,
        ),
      );
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      final data = e is DioException ? e.response?.data : null;
      final message =
          data is Map ? data['message']?.toString() : null;

      // 403 = the session is no longer active (ended elsewhere or by an
      // admin); 404 = not this user's session. Stop offering fixes.
      if (status == 403 || status == 404) {
        debugPrint('Field work session $sessionId no longer active.');
        await clear();
        return;
      }

      await _save(
        FieldTrackerSnapshot(
          result: 'failed',
          at: now,
          lat: lat,
          lng: lng,
          accuracy: accuracy,
          message: message,
          lastSentAt: previous?.lastSentAt,
          lastSentLat: previous?.lastSentLat,
          lastSentLng: previous?.lastSentLng,
        ),
      );
    }
  }
}

class FieldTrackerSnapshot {
  /// sent | failed | poor
  final String result;
  final DateTime at;
  final double? lat;
  final double? lng;
  final double? accuracy;
  final String? message;
  final DateTime? lastSentAt;
  final double? lastSentLat;
  final double? lastSentLng;

  const FieldTrackerSnapshot({
    required this.result,
    required this.at,
    this.lat,
    this.lng,
    this.accuracy,
    this.message,
    this.lastSentAt,
    this.lastSentLat,
    this.lastSentLng,
  });

  Map<String, dynamic> toJson() => {
        'result': result,
        'at': at.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'message': message,
        'lastSentAt': lastSentAt?.toIso8601String(),
        'lastSentLat': lastSentLat,
        'lastSentLng': lastSentLng,
      };

  static double? _d(dynamic v) => v is num ? v.toDouble() : null;

  factory FieldTrackerSnapshot.fromJson(Map<String, dynamic> json) {
    return FieldTrackerSnapshot(
      result: json['result']?.toString() ?? 'failed',
      at: DateTime.tryParse(json['at']?.toString() ?? '') ?? DateTime.now(),
      lat: _d(json['lat']),
      lng: _d(json['lng']),
      accuracy: _d(json['accuracy']),
      message: json['message']?.toString(),
      lastSentAt: DateTime.tryParse(json['lastSentAt']?.toString() ?? ''),
      lastSentLat: _d(json['lastSentLat']),
      lastSentLng: _d(json['lastSentLng']),
    );
  }
}
