
/// Represents a queued offline attendance punch (check-in or check-out).
class AttendanceQueueItem {
  final String id;
  final String type; // 'check_in' or 'check_out'
  final String attendanceType; // 'face' or 'fingerprint'
  final String? photoPath;
  final double lat;
  final double lng;
  final double? accuracy;
  final String? workDescription;
  final String? workAudioPath;
  final String? deviceId;
  final int? challengeId;
  final String? signature;
  final DateTime timestamp;
  final int retryCount;

  AttendanceQueueItem({
    required this.id,
    required this.type,
    required this.attendanceType,
    this.photoPath,
    required this.lat,
    required this.lng,
    this.accuracy,
    this.workDescription,
    this.workAudioPath,
    this.deviceId,
    this.challengeId,
    this.signature,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'attendanceType': attendanceType,
        'photoPath': photoPath,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'workDescription': workDescription,
        'workAudioPath': workAudioPath,
        'deviceId': deviceId,
        'challengeId': challengeId,
        'signature': signature,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory AttendanceQueueItem.fromJson(Map<String, dynamic> json) {
    return AttendanceQueueItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: json['type'] as String? ?? 'check_in',
      attendanceType: json['attendanceType'] as String? ?? 'face',
      photoPath: json['photoPath'] as String?,
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      workDescription: json['workDescription'] as String?,
      workAudioPath: json['workAudioPath'] as String?,
      deviceId: json['deviceId'] as String?,
      challengeId: (json['challengeId'] as num?)?.toInt(),
      signature: json['signature'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  AttendanceQueueItem copyWith({int? retryCount}) {
    return AttendanceQueueItem(
      id: id,
      type: type,
      attendanceType: attendanceType,
      photoPath: photoPath,
      lat: lat,
      lng: lng,
      accuracy: accuracy,
      workDescription: workDescription,
      workAudioPath: workAudioPath,
      deviceId: deviceId,
      challengeId: challengeId,
      signature: signature,
      timestamp: timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}

/// Represents a queued offline task modification (lifecycle, progress, checklist, attachment).
class TaskQueueItem {
  final String id;
  final int taskId;
  final String actionType; // 'lifecycle', 'progress', 'checklist', 'attachment'
  final String? action; // 'accept', 'start', 'pause', 'unblock', 'block', 'submit'
  final Map<String, dynamic>? payload;
  final int? itemId; // checklist item ID
  final bool? done; // checklist state
  final List<Map<String, String>>? files; // [ { 'path': ..., 'name': ... } ]
  final String? caption;
  final DateTime timestamp;
  final int retryCount;

  TaskQueueItem({
    required this.id,
    required this.taskId,
    required this.actionType,
    this.action,
    this.payload,
    this.itemId,
    this.done,
    this.files,
    this.caption,
    required this.timestamp,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'taskId': taskId,
        'actionType': actionType,
        'action': action,
        'payload': payload,
        'itemId': itemId,
        'done': done,
        'files': files,
        'caption': caption,
        'timestamp': timestamp.toIso8601String(),
        'retryCount': retryCount,
      };

  factory TaskQueueItem.fromJson(Map<String, dynamic> json) {
    List<Map<String, String>>? parsedFiles;
    if (json['files'] is List) {
      parsedFiles = (json['files'] as List)
          .whereType<Map>()
          .map((f) => f.map((k, v) => MapEntry(k.toString(), v.toString())))
          .toList();
    }

    return TaskQueueItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      taskId: (json['taskId'] as num?)?.toInt() ?? 0,
      actionType: json['actionType'] as String? ?? 'lifecycle',
      action: json['action'] as String?,
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : null,
      itemId: (json['itemId'] as num?)?.toInt(),
      done: json['done'] as bool?,
      files: parsedFiles,
      caption: json['caption'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      retryCount: (json['retryCount'] as num?)?.toInt() ?? 0,
    );
  }

  TaskQueueItem copyWith({int? retryCount}) {
    return TaskQueueItem(
      id: id,
      taskId: taskId,
      actionType: actionType,
      action: action,
      payload: payload,
      itemId: itemId,
      done: done,
      files: files,
      caption: caption,
      timestamp: timestamp,
      retryCount: retryCount ?? this.retryCount,
    );
  }
}
