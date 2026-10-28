import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/task/data/task_repository.dart';
import 'offline_queue_models.dart';

/// Checks if an error is due to network failure, connection timeout,
/// or unreachable host (where offline queueing should take over).
bool isNetworkError(Object error) {
  if (error is DioException) {
    if (error.response == null) return true;
    return error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.error is SocketException;
  }
  if (error is SocketException) return true;
  final str = error.toString().toLowerCase();
  return str.contains('connection error') ||
      str.contains('connection errored') ||
      str.contains('the connection error') ||
      str.contains('socketexception') ||
      str.contains('connection refused') ||
      str.contains('network is unreachable') ||
      str.contains('failed host lookup') ||
      str.contains('connection timed out') ||
      str.contains('unable to reach the server') ||
      str.contains('clientexception') ||
      str.contains('no internet') ||
      str.contains('offline') ||
      str.contains('handshakeexception') ||
      str.contains('timed out') ||
      str.contains('time out') ||
      str.contains('os error') ||
      str.contains('network error') ||
      str.contains('failed to connect') ||
      str.contains('errno = 101') ||
      str.contains('errno = 111') ||
      str.contains('errno = 7');
}

/// State for the offline sync monitor.
class OfflineSyncState {
  final int pendingAttendanceCount;
  final int pendingTaskCount;
  final bool isSyncing;
  final String? lastSyncMessage;
  final DateTime? lastSyncTime;

  const OfflineSyncState({
    this.pendingAttendanceCount = 0,
    this.pendingTaskCount = 0,
    this.isSyncing = false,
    this.lastSyncMessage,
    this.lastSyncTime,
  });

  int get totalPendingCount => pendingAttendanceCount + pendingTaskCount;

  OfflineSyncState copyWith({
    int? pendingAttendanceCount,
    int? pendingTaskCount,
    bool? isSyncing,
    String? lastSyncMessage,
    bool clearMessage = false,
    DateTime? lastSyncTime,
  }) {
    return OfflineSyncState(
      pendingAttendanceCount:
          pendingAttendanceCount ?? this.pendingAttendanceCount,
      pendingTaskCount: pendingTaskCount ?? this.pendingTaskCount,
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncMessage:
          clearMessage ? null : lastSyncMessage ?? this.lastSyncMessage,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }
}

class OfflineSyncNotifier extends Notifier<OfflineSyncState> {
  static const String _attQueueKey = 'workforce_offline_attendance_queue';
  static const String _taskQueueKey = 'workforce_offline_task_queue';

  Timer? _autoSyncTimer;

  @override
  OfflineSyncState build() {
    // Schedule initial load and periodic background sync check.
    Future.microtask(() async {
      await refreshCounts();
      if (state.totalPendingCount > 0 && !state.isSyncing) {
        syncAll();
      }
    });
    _startPeriodicSync();

    ref.onDispose(() {
      _autoSyncTimer?.cancel();
    });

    return const OfflineSyncState();
  }

  void _startPeriodicSync() {
    _autoSyncTimer?.cancel();
    // Check every 30 seconds for pending items to sync
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (state.totalPendingCount > 0 && !state.isSyncing) {
        syncAll();
      }
    });
  }

  // ============================================================
  // DURABLE FILE STORAGE HELPER
  // ============================================================

  /// Copies temporary files to a persistent app directory so that OS
  /// cache cleaners don't delete them while the device is offline.
  Future<String> persistOfflineFile(String sourcePath, {String prefix = 'offline_'}) async {
    try {
      final file = File(sourcePath);
      if (!await file.exists()) return sourcePath;

      final docsDir = await getApplicationDocumentsDirectory();
      final offlineDir = Directory('${docsDir.path}/offline_queue');
      if (!await offlineDir.exists()) {
        await offlineDir.create(recursive: true);
      }

      final ext = sourcePath.split('.').last;
      final targetPath =
          '${offlineDir.path}/$prefix${DateTime.now().millisecondsSinceEpoch}.$ext';
      final saved = await file.copy(targetPath);
      return saved.path;
    } catch (e) {
      debugPrint('⚠️ Failed to copy offline file to persistent dir: $e');
      return sourcePath;
    }
  }

  Future<void> _deleteLocalFile(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final file = File(path);
      if (await file.exists() && path.contains('offline_queue')) {
        await file.delete();
      }
    } catch (_) {}
  }

  // ============================================================
  // ATTENDANCE QUEUE MANAGEMENT
  // ============================================================

  Future<List<AttendanceQueueItem>> getAttendanceQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_attQueueKey);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => AttendanceQueueItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error reading attendance queue: $e');
      return [];
    }
  }

  Future<void> queueAttendance(AttendanceQueueItem item) async {
    try {
      // Make sure photo / audio files are safely preserved
      String? durablePhoto = item.photoPath;
      if (durablePhoto != null && durablePhoto.isNotEmpty) {
        durablePhoto = await persistOfflineFile(durablePhoto, prefix: 'att_photo_');
      }

      String? durableAudio = item.workAudioPath;
      if (durableAudio != null && durableAudio.isNotEmpty) {
        durableAudio = await persistOfflineFile(durableAudio, prefix: 'att_audio_');
      }

      final durableItem = AttendanceQueueItem(
        id: item.id,
        type: item.type,
        attendanceType: item.attendanceType,
        photoPath: durablePhoto,
        lat: item.lat,
        lng: item.lng,
        accuracy: item.accuracy,
        workDescription: item.workDescription,
        workAudioPath: durableAudio,
        deviceId: item.deviceId,
        challengeId: item.challengeId,
        signature: item.signature,
        timestamp: item.timestamp,
      );

      final queue = await getAttendanceQueue();
      queue.add(durableItem);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _attQueueKey,
        jsonEncode(queue.map((e) => e.toJson()).toList()),
      );

      await refreshCounts();
      Future.delayed(const Duration(seconds: 2), () {
        if (state.totalPendingCount > 0 && !state.isSyncing) syncAll();
      });
      debugPrint('📥 Attendance queued offline: ${durableItem.type} (Queue size: ${queue.length})');
    } catch (e) {
      debugPrint('❌ Failed to queue attendance offline: $e');
    }
  }

  // ============================================================
  // TASK QUEUE MANAGEMENT
  // ============================================================

  Future<List<TaskQueueItem>> getTaskQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_taskQueueKey);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((item) => TaskQueueItem.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      debugPrint('❌ Error reading task queue: $e');
      return [];
    }
  }

  Future<void> queueTaskAction(TaskQueueItem item) async {
    try {
      // Preserve attachment files if any
      List<Map<String, String>>? durableFiles;
      if (item.files != null && item.files!.isNotEmpty) {
        durableFiles = [];
        for (final f in item.files!) {
          final p = f['path'];
          final name = f['name'] ?? 'file';
          if (p != null) {
            final dp = await persistOfflineFile(p, prefix: 'task_file_');
            durableFiles.add({'path': dp, 'name': name});
          }
        }
      }

      final durableItem = TaskQueueItem(
        id: item.id,
        taskId: item.taskId,
        actionType: item.actionType,
        action: item.action,
        payload: item.payload,
        itemId: item.itemId,
        done: item.done,
        files: durableFiles ?? item.files,
        caption: item.caption,
        timestamp: item.timestamp,
      );

      final queue = await getTaskQueue();
      queue.add(durableItem);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _taskQueueKey,
        jsonEncode(queue.map((e) => e.toJson()).toList()),
      );

      await refreshCounts();
      Future.delayed(const Duration(seconds: 2), () {
        if (state.totalPendingCount > 0 && !state.isSyncing) syncAll();
      });
      debugPrint('📥 Task action queued offline: ${durableItem.actionType} (Task: ${durableItem.taskId})');
    } catch (e) {
      debugPrint('❌ Failed to queue task action offline: $e');
    }
  }

  // ============================================================
  // REFRESH COUNTS
  // ============================================================

  Future<void> refreshCounts() async {
    final attQueue = await getAttendanceQueue();
    final taskQueue = await getTaskQueue();

    state = state.copyWith(
      pendingAttendanceCount: attQueue.length,
      pendingTaskCount: taskQueue.length,
    );
  }

  // ============================================================
  // SYNCHRONIZATION WORKER
  // ============================================================

  /// Replays all queued attendance punches and task actions in FIFO order.
  Future<bool> syncAll() async {
    if (state.isSyncing) {
      debugPrint('⏳ Offline sync already in progress.');
      return false;
    }

    state = state.copyWith(isSyncing: true, clearMessage: true);

    final attendanceRepo = ref.read(attendanceRepositoryProvider);
    final taskRepo = ref.read(taskRepositoryProvider);
    final prefs = await SharedPreferences.getInstance();

    int syncedCount = 0;
    // tracking retries in item

    try {
      // 1. REPLAY ATTENDANCE PUNCHES
      final attQueue = await getAttendanceQueue();
      final remainingAtt = <AttendanceQueueItem>[];

      for (final item in attQueue) {
        try {
          if (item.type == 'check_in') {
            await attendanceRepo.checkIn(
              attendanceType: item.attendanceType,
              photoPath: item.photoPath,
              lat: item.lat,
              lng: item.lng,
              accuracy: item.accuracy,
              deviceId: item.deviceId,
              challengeId: item.challengeId,
              signature: item.signature,
            );
          } else {
            await attendanceRepo.checkout(
              attendanceType: item.attendanceType,
              photoPath: item.photoPath,
              workAudioPath: item.workAudioPath,
              workDescription: item.workDescription,
              lat: item.lat,
              lng: item.lng,
              accuracy: item.accuracy,
              deviceId: item.deviceId,
              challengeId: item.challengeId,
              signature: item.signature,
            );
          }

          // Success - clean up local files
          await _deleteLocalFile(item.photoPath);
          await _deleteLocalFile(item.workAudioPath);
          syncedCount++;
          debugPrint('✅ Offline attendance ${item.type} synced successfully.');
        } catch (e) {
          debugPrint('⚠️ Attendance sync error: $e');

          // If the server rejected it because it's already marked (409 Conflict),
          // or user already checked in/out today, consider it fulfilled and remove.
          final errorStr = e.toString().toLowerCase();
          final isConflict = errorStr.contains('already checked') ||
              errorStr.contains('409') ||
              errorStr.contains('session was not found');

          if (isConflict) {
            await _deleteLocalFile(item.photoPath);
            await _deleteLocalFile(item.workAudioPath);
            syncedCount++;
            debugPrint('ℹ️ Attendance item skipped/cleared due to server state: $e');
          } else if (isNetworkError(e)) {
            // Still offline, retain for next sync
            remainingAtt.add(item.copyWith(retryCount: item.retryCount + 1));
            
            break; // Stop replaying queue while offline
          } else {
            // Unrecoverable business error after 3 retries -> drop
            if (item.retryCount >= 3) {
              await _deleteLocalFile(item.photoPath);
              await _deleteLocalFile(item.workAudioPath);
              debugPrint('❌ Attendance item dropped after 3 failed retries: $e');
            } else {
              remainingAtt.add(item.copyWith(retryCount: item.retryCount + 1));
              
            }
          }
        }
      }

      await prefs.setString(
        _attQueueKey,
        jsonEncode(remainingAtt.map((e) => e.toJson()).toList()),
      );

      // If any attendance synced, trigger today's refresh silently
      if (syncedCount > 0) {
        try {
          await ref.read(attendanceProvider.notifier).getTodayAttendance();
        } catch (_) {}
      }

      // 2. REPLAY TASK ACTIONS
      final taskQueue = await getTaskQueue();
      final remainingTasks = <TaskQueueItem>[];

      for (final item in taskQueue) {
        try {
          if (item.actionType == 'lifecycle') {
            await taskRepo.runLifecycleAction(
              item.taskId,
              item.action ?? 'start',
              data: item.payload,
            );
          } else if (item.actionType == 'progress') {
            final percent = (item.payload?['progressPercent'] as num?)?.toInt() ?? 0;
            await taskRepo.setProgress(item.taskId, percent);
          } else if (item.actionType == 'checklist') {
            if (item.itemId != null && item.done != null) {
              await taskRepo.tickChecklist(item.taskId, item.itemId!, item.done!);
            }
          } else if (item.actionType == 'attachment') {
            if (item.files != null && item.files!.isNotEmpty) {
              final filesList = item.files!
                  .map((f) => (path: f['path']!, name: f['name'] ?? 'file'))
                  .toList();
              await taskRepo.uploadAttachments(
                item.taskId,
                files: filesList,
                caption: item.caption,
              );
              for (final f in item.files!) {
                await _deleteLocalFile(f['path']);
              }
            }
          } else if (item.actionType == 'comment') {
            final body = item.payload?['body'] as String? ?? '';
            if (body.isNotEmpty) {
              await taskRepo.addTaskComment(taskId: item.taskId, body: body);
            }
          }

          syncedCount++;
          debugPrint('✅ Offline task action synced: ${item.actionType} (Task: ${item.taskId})');
        } catch (e) {
          debugPrint('⚠️ Task sync error: $e');

          if (isNetworkError(e)) {
            // Still offline
            remainingTasks.add(item.copyWith(retryCount: item.retryCount + 1));
            
            break; // Stop replaying queue while network is unreachable
          } else {
            // If already completed or invalid transition after 3 retries, drop
            if (item.retryCount >= 3) {
              if (item.files != null) {
                for (final f in item.files!) {
                  await _deleteLocalFile(f['path']);
                }
              }
              debugPrint('❌ Task action dropped after 3 retries: $e');
            } else {
              remainingTasks.add(item.copyWith(retryCount: item.retryCount + 1));
              
            }
          }
        }
      }

      await prefs.setString(
        _taskQueueKey,
        jsonEncode(remainingTasks.map((e) => e.toJson()).toList()),
      );

      final totalPending = remainingAtt.length + remainingTasks.length;
      final msg = syncedCount > 0
          ? 'Synced $syncedCount item(s) successfully.'
          : (totalPending > 0 ? 'Device is offline. Will sync when online.' : 'All items synced.');

      state = state.copyWith(
        pendingAttendanceCount: remainingAtt.length,
        pendingTaskCount: remainingTasks.length,
        isSyncing: false,
        lastSyncMessage: msg,
        lastSyncTime: DateTime.now(),
      );

      return totalPending == 0;
    } catch (e) {
      debugPrint('❌ General sync failure: $e');
      state = state.copyWith(
        isSyncing: false,
        lastSyncMessage: 'Sync failed: $e',
      );
      return false;
    }
  }

  /// Clears all offline queues (used e.g. on logout).
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_attQueueKey);
    await prefs.remove(_taskQueueKey);
    await refreshCounts();
  }
}

final offlineSyncProvider =
    NotifierProvider<OfflineSyncNotifier, OfflineSyncState>(
  OfflineSyncNotifier.new,
);
