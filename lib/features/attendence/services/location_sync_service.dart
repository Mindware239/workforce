import 'dart:async';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/services/secure_storage.dart';

import 'location_queue.dart';

class LocationSyncService {
  static bool _isSyncing = false;
  static Timer? _syncTimer;

  // Temporary client-side delay.
  // Backend should ideally provide retryAfterSeconds.
  static const Duration syncDelay = Duration(seconds: 60);

  static Future<void> scheduleSync() async {
    if (_syncTimer != null && _syncTimer!.isActive) {
      print('⏳ Batch sync already scheduled.');
      return;
    }

    print('⏳ Scheduling batch sync in ${syncDelay.inSeconds}s.');

    _syncTimer = Timer(syncDelay, () async {
      _syncTimer = null;
      await sync();
    });
  }

  static Future<bool> sync() async {
    if (_isSyncing) {
      print('⏳ Location sync already running.');
      return false;
    }

    _isSyncing = true;

    try {
      final storage = SecureStorage();
      final queue = LocationQueue(storage: storage);

      final locations = await queue.getAll();

      if (locations.isEmpty) {
        print('📦 Location queue is empty.');
        return true;
      }

      print('📦 Syncing ${locations.length} tracking point(s).');

      final apiClient = ApiClient(
        secureStorage: storage,
      );

      try {
        final response = await apiClient.post(
          '/v1/employee/location/batch',
          data: {
            'points': locations,
          },
        );

        final responseData = response.data;

        if (responseData is! Map) {
          print('❌ Invalid batch response.');
          return false;
        }

        final data = responseData['data'];

        if (data is! Map) {
          print('❌ Invalid batch response data.');
          return false;
        }

        final accepted =
            (data['accepted'] as num?)?.toInt() ?? 0;

        final rejected = data['rejected'];

        final throttled =
            data['throttled'] == true;

        print('📦 Accepted: $accepted');
        print(
          '📦 Rejected: '
          '${rejected is List ? rejected.length : 0}',
        );
        print('📦 Throttled: $throttled');

        // Backend returned rejected indexes.
        if (rejected is List && rejected.isNotEmpty) {
          final rejectedIndexes = <int>{};

          for (final item in rejected) {
            if (item is Map && item['index'] != null) {
              rejectedIndexes.add(
                (item['index'] as num).toInt(),
              );
            }
          }

          // Keep only rejected points.
          final remaining = <Map<String, dynamic>>[];

          for (var i = 0; i < locations.length; i++) {
            if (rejectedIndexes.contains(i)) {
              remaining.add(locations[i]);
            }
          }

          await queue.replace(remaining);

          print(
            '📦 Kept ${remaining.length} rejected '
            'point(s) for retry.',
          );

          return accepted > 0;
        }

        // No rejected points means everything was accepted.
        if (accepted == locations.length) {
          await queue.clear();

          print(
            '✅ All ${locations.length} tracking '
            'point(s) synchronized.',
          );

          return true;
        }

        // Backend accepted something but didn't tell us
        // which points were accepted.
        print(
          '⚠️ Partial batch response without indexes. '
          'Keeping queue to avoid losing tracking data.',
        );

        return false;
      } catch (e) {
        print('❌ Batch sync failed: $e');
        print('📦 Keeping queue for retry.');
        return false;
      }
    } finally {
      _isSyncing = false;
    }
  }

  static void dispose() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }
}