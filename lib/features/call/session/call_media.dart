/// The seam between [CallSession] and the WebRTC stack.
///
/// The session drives signalling and timing only through these interfaces,
/// so it can run against flutter_webrtc on a device (webrtc_engine.dart) or
/// against a scripted fake in a protocol test, where no media can flow.
library;

import 'package:workforce/features/call/data/call_models.dart';

/// Camera / microphone could not be opened, with a reason the UI turns into
/// words: permission_denied, no_device, device_busy, unknown.
class MediaAccessError implements Exception {
  final String reason;
  final String message;

  const MediaAccessError(this.reason, this.message);

  @override
  String toString() => message;
}

/// An SDP offer or answer, as sent in call:signal (`{ type, sdp }`).
class SdpDesc {
  final String type;
  final String sdp;

  const SdpDesc(this.type, this.sdp);

  Map<String, dynamic> toJson() => {'type': type, 'sdp': sdp};

  static SdpDesc? fromJson(dynamic json) {
    if (json is! Map) return null;
    final type = json['type']?.toString();
    final sdp = json['sdp']?.toString();
    if (type == null || sdp == null) return null;
    return SdpDesc(type, sdp);
  }
}

/// This side's camera and microphone.
abstract class LocalMedia {
  /// The engine's stream object, for the preview.
  Object? get stream;
  bool get hasAudio;
  bool get hasVideo;
  bool get audioEnabled;
  bool get videoEnabled;
  set audioEnabled(bool on);
  set videoEnabled(bool on);

  /// Front ↔ back. Returns whether the front camera is now in use.
  Future<bool> switchCamera();

  /// Earpiece ↔ loudspeaker.
  Future<void> setSpeaker(bool on);

  /// Stops every track. Safe to call more than once.
  Future<void> release();
}

/// What the peer connection reports back.
class PeerCallbacks {
  final void Function(Map<String, dynamic> candidate) onIceCandidate;

  /// new | connecting | connected | disconnected | failed | closed
  final void Function(String state) onConnectionState;
  final void Function(String state)? onIceConnectionState;
  final void Function(Object? stream, bool hasVideo) onRemoteStream;

  const PeerCallbacks({
    required this.onIceCandidate,
    required this.onConnectionState,
    required this.onRemoteStream,
    this.onIceConnectionState,
  });
}

/// One RTCPeerConnection.
abstract class PeerLink {
  /// The last connection state reported.
  String get connectionState;
  bool get hasRemoteDescription;

  /// stable | have-local-offer | have-remote-offer | ... | closed
  Future<String> signalingState();
  Future<SdpDesc> createOffer({bool iceRestart = false});
  Future<SdpDesc> createAnswer();
  Future<void> setLocalDescription(SdpDesc desc);
  Future<void> setRemoteDescription(SdpDesc desc);

  /// Drops an outstanding local offer (signalling state back to stable).
  Future<void> rollback();
  Future<void> addIceCandidate(Map<String, dynamic> candidate);

  /// Candidate types gathered so far, for diagnostics ("host/udp srflx/udp").
  Future<String> describeLocalCandidates();
  Future<void> close();
}

abstract class CallMediaEngine {
  Future<LocalMedia> acquire(CallMedia media);
  Future<PeerLink> createPeer(RtcConfig config, LocalMedia local, PeerCallbacks callbacks);
}
