/// Plain data for one-to-one calls, shaped like the server's payloads
/// (backend/modules/chat/realtime/calls.socket.js `view()`, and
/// calls.service.js `listCalls`) and the web's CallState
/// (frontend/src/lib/realtime/call-session.ts).
library;

enum CallMedia {
  audio,
  video;

  static CallMedia parse(dynamic value) =>
      value?.toString() == 'video' ? CallMedia.video : CallMedia.audio;

  String get wire => name;
}

enum CallRole { caller, callee }

enum CallPhase { idle, outgoing, incoming, connecting, active, reconnecting, ended }

int? _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');

class CallPeer {
  final int id;
  final String fullName;

  const CallPeer({required this.id, required this.fullName});

  static CallPeer? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = _int(json['id']);
    if (id == null) return null;
    return CallPeer(id: id, fullName: json['fullName']?.toString() ?? '');
  }
}

/// A call as the server describes it in call:incoming and the invite /
/// accept / resume acks.
class CallView {
  final int callId;
  final int conversationId;
  final CallMedia media;
  final String status;
  final CallPeer caller;
  final CallPeer callee;

  const CallView({
    required this.callId,
    required this.conversationId,
    required this.media,
    required this.status,
    required this.caller,
    required this.callee,
  });

  static CallView? fromJson(dynamic json) {
    if (json is! Map) return null;
    final callId = _int(json['callId']);
    final conversationId = _int(json['conversationId']);
    final caller = CallPeer.fromJson(json['caller']);
    final callee = CallPeer.fromJson(json['callee']);
    if (callId == null || conversationId == null || caller == null || callee == null) {
      return null;
    }
    return CallView(
      callId: callId,
      conversationId: conversationId,
      media: CallMedia.parse(json['media']),
      status: json['status']?.toString() ?? '',
      caller: caller,
      callee: callee,
    );
  }
}

/// `{ iceServers, iceTransportPolicy, ttlSeconds }` from GET /api/chat/rtc-config
/// and the call acks.
class RtcConfig {
  final List<Map<String, dynamic>> iceServers;
  final String iceTransportPolicy;
  final int? ttlSeconds;

  const RtcConfig({
    required this.iceServers,
    this.iceTransportPolicy = 'all',
    this.ttlSeconds,
  });

  static const fallback = RtcConfig(iceServers: [
    {'urls': 'stun:stun.l.google.com:19302'},
  ]);

  static RtcConfig? fromJson(dynamic json) {
    if (json is! Map) return null;
    final servers = json['iceServers'];
    return RtcConfig(
      iceServers: servers is List
          ? servers.whereType<Map>().map((s) => Map<String, dynamic>.from(s)).toList()
          : const [],
      iceTransportPolicy: json['iceTransportPolicy']?.toString() == 'relay' ? 'relay' : 'all',
      ttlSeconds: _int(json['ttlSeconds']),
    );
  }
}

/// One row of GET /api/chat/conversations/:id/calls.
class CallRecord {
  final int id;
  final int conversationId;
  final CallMedia media;
  final String status;
  final String? endReason;
  final DateTime createdAt;
  final DateTime? answeredAt;
  final int callerId;
  final String callerName;
  final int calleeId;
  final String calleeName;
  final int? durationSeconds;

  const CallRecord({
    required this.id,
    required this.conversationId,
    required this.media,
    required this.status,
    required this.endReason,
    required this.createdAt,
    required this.answeredAt,
    required this.callerId,
    required this.callerName,
    required this.calleeId,
    required this.calleeName,
    required this.durationSeconds,
  });

  static CallRecord? fromJson(dynamic json) {
    if (json is! Map) return null;
    final id = _int(json['id']);
    final createdAt = DateTime.tryParse(json['createdAt']?.toString() ?? '');
    if (id == null || createdAt == null) return null;
    return CallRecord(
      id: id,
      conversationId: _int(json['conversationId']) ?? 0,
      media: CallMedia.parse(json['media']),
      status: json['status']?.toString() ?? '',
      endReason: json['endReason']?.toString(),
      createdAt: createdAt,
      answeredAt: DateTime.tryParse(json['answeredAt']?.toString() ?? ''),
      callerId: _int(json['callerId']) ?? 0,
      callerName: json['callerName']?.toString() ?? '',
      calleeId: _int(json['calleeId']) ?? 0,
      calleeName: json['calleeName']?.toString() ?? '',
      durationSeconds: _int(json['durationSeconds']),
    );
  }

  bool get live => status == 'ringing' || status == 'active';
}

const Object _keep = Object();

/// What the call screen draws. Mirrors the web's CallState; the streams are
/// the engine's own objects (flutter_webrtc MediaStream on a device).
class CallState {
  final CallPhase phase;
  final int? callId;
  final int? conversationId;
  final CallMedia media;
  final CallRole? role;
  final CallPeer? peer;
  final Object? localStream;
  final Object? remoteStream;
  final bool remoteHasVideo;
  final bool micOn;
  final bool camOn;
  final bool speakerOn;
  final bool frontCamera;
  final bool remoteMicOn;
  final bool remoteCamOn;

  /// The callee's device was online when the call went out ("Ringing" vs "Calling").
  final bool calleeOnline;
  final bool peerAway;
  final DateTime? connectedAt;

  /// Why the call ended, as a key the UI turns into words (`call.ended_<key>`).
  final String? endReason;
  final int? durationSeconds;

  const CallState({
    this.phase = CallPhase.idle,
    this.callId,
    this.conversationId,
    this.media = CallMedia.audio,
    this.role,
    this.peer,
    this.localStream,
    this.remoteStream,
    this.remoteHasVideo = false,
    this.micOn = true,
    this.camOn = true,
    this.speakerOn = false,
    this.frontCamera = true,
    this.remoteMicOn = true,
    this.remoteCamOn = true,
    this.calleeOnline = false,
    this.peerAway = false,
    this.connectedAt,
    this.endReason,
    this.durationSeconds,
  });

  static const idle = CallState();

  bool get busy => phase != CallPhase.idle && phase != CallPhase.ended;

  CallState copyWith({
    CallPhase? phase,
    Object? callId = _keep,
    Object? conversationId = _keep,
    CallMedia? media,
    Object? role = _keep,
    Object? peer = _keep,
    Object? localStream = _keep,
    Object? remoteStream = _keep,
    bool? remoteHasVideo,
    bool? micOn,
    bool? camOn,
    bool? speakerOn,
    bool? frontCamera,
    bool? remoteMicOn,
    bool? remoteCamOn,
    bool? calleeOnline,
    bool? peerAway,
    Object? connectedAt = _keep,
    Object? endReason = _keep,
    Object? durationSeconds = _keep,
  }) {
    return CallState(
      phase: phase ?? this.phase,
      callId: identical(callId, _keep) ? this.callId : callId as int?,
      conversationId:
          identical(conversationId, _keep) ? this.conversationId : conversationId as int?,
      media: media ?? this.media,
      role: identical(role, _keep) ? this.role : role as CallRole?,
      peer: identical(peer, _keep) ? this.peer : peer as CallPeer?,
      localStream: identical(localStream, _keep) ? this.localStream : localStream,
      remoteStream: identical(remoteStream, _keep) ? this.remoteStream : remoteStream,
      remoteHasVideo: remoteHasVideo ?? this.remoteHasVideo,
      micOn: micOn ?? this.micOn,
      camOn: camOn ?? this.camOn,
      speakerOn: speakerOn ?? this.speakerOn,
      frontCamera: frontCamera ?? this.frontCamera,
      remoteMicOn: remoteMicOn ?? this.remoteMicOn,
      remoteCamOn: remoteCamOn ?? this.remoteCamOn,
      calleeOnline: calleeOnline ?? this.calleeOnline,
      peerAway: peerAway ?? this.peerAway,
      connectedAt:
          identical(connectedAt, _keep) ? this.connectedAt : connectedAt as DateTime?,
      endReason: identical(endReason, _keep) ? this.endReason : endReason as String?,
      durationSeconds:
          identical(durationSeconds, _keep) ? this.durationSeconds : durationSeconds as int?,
    );
  }
}
