/// [CallMediaEngine] on flutter_webrtc: the device's camera and microphone
/// and a real RTCPeerConnection.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import 'package:workforce/features/call/data/call_models.dart';
import 'package:workforce/features/call/session/call_media.dart';

class WebRtcEngine implements CallMediaEngine {
  const WebRtcEngine();

  @override
  Future<LocalMedia> acquire(CallMedia media) async {
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': media == CallMedia.video
          ? {
              'facingMode': 'user',
              'mandatory': {
                'minWidth': '640',
                'minHeight': '480',
                'minFrameRate': '24',
              },
              'optional': [],
            }
          : false,
    };
    try {
      final stream = await navigator.mediaDevices.getUserMedia(constraints);
      if (stream.getAudioTracks().isEmpty) {
        await _stop(stream);
        throw const MediaAccessError('no_device', 'No microphone was found on this device.');
      }
      return _WebRtcLocalMedia(stream);
    } on MediaAccessError {
      rethrow;
    } catch (err) {
      throw _describe(err, media);
    }
  }

  static MediaAccessError _describe(Object err, CallMedia media) {
    final text = (err is PlatformException ? '${err.code} ${err.message}' : '$err').toLowerCase();
    if (text.contains('permission') || text.contains('notallowed') || text.contains('denied')) {
      return MediaAccessError(
        'permission_denied',
        media == CallMedia.video
            ? 'Camera and microphone access is blocked.'
            : 'Microphone access is blocked.',
      );
    }
    if (text.contains('notfound') || text.contains('no camera') || text.contains('not found')) {
      return MediaAccessError(
        'no_device',
        media == CallMedia.video
            ? 'No camera or microphone was found on this device.'
            : 'No microphone was found on this device.',
      );
    }
    if (text.contains('busy') || text.contains('in use') || text.contains('notreadable')) {
      return const MediaAccessError('device_busy', 'The camera or microphone is being used by another app.');
    }
    return const MediaAccessError('unknown', 'Could not start the camera or microphone.');
  }

  static Future<void> _stop(MediaStream stream) async {
    for (final t in stream.getTracks()) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await stream.dispose();
    } catch (_) {}
  }

  @override
  Future<PeerLink> createPeer(RtcConfig config, LocalMedia local, PeerCallbacks callbacks) async {
    final pc = await createPeerConnection({
      'iceServers': config.iceServers.isEmpty ? RtcConfig.fallback.iceServers : config.iceServers,
      'iceTransportPolicy': config.iceTransportPolicy,
      'bundlePolicy': 'max-bundle',
      'sdpSemantics': 'unified-plan',
    });
    final link = _WebRtcPeerLink(pc);

    final stream = (local as _WebRtcLocalMedia)._stream;
    for (final track in stream.getTracks()) {
      await pc.addTrack(track, stream);
    }

    pc.onIceCandidate = (c) {
      if (c.candidate == null || c.candidate!.isEmpty) return;
      callbacks.onIceCandidate({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
      });
    };
    pc.onConnectionState = (s) {
      link._connectionState = _connectionName(s);
      callbacks.onConnectionState(link._connectionState);
    };
    pc.onIceConnectionState = (s) =>
        callbacks.onIceConnectionState?.call(s.name.replaceFirst('RTCIceConnectionState', '').toLowerCase());
    pc.onTrack = (event) {
      final remote = event.streams.isNotEmpty ? event.streams.first : null;
      if (remote == null) return;
      link._remote = remote;
      callbacks.onRemoteStream(remote, remote.getVideoTracks().isNotEmpty);
    };
    return link;
  }

  static String _connectionName(RTCPeerConnectionState s) => switch (s) {
        RTCPeerConnectionState.RTCPeerConnectionStateNew => 'new',
        RTCPeerConnectionState.RTCPeerConnectionStateConnecting => 'connecting',
        RTCPeerConnectionState.RTCPeerConnectionStateConnected => 'connected',
        RTCPeerConnectionState.RTCPeerConnectionStateDisconnected => 'disconnected',
        RTCPeerConnectionState.RTCPeerConnectionStateFailed => 'failed',
        RTCPeerConnectionState.RTCPeerConnectionStateClosed => 'closed',
      };
}

class _WebRtcLocalMedia implements LocalMedia {
  _WebRtcLocalMedia(this._stream);

  final MediaStream _stream;
  bool _released = false;

  @override
  Object? get stream => _stream;

  MediaStreamTrack? get _audio {
    final t = _stream.getAudioTracks();
    return t.isEmpty ? null : t.first;
  }

  MediaStreamTrack? get _video {
    final t = _stream.getVideoTracks();
    return t.isEmpty ? null : t.first;
  }

  @override
  bool get hasAudio => _audio != null;
  @override
  bool get hasVideo => _video != null;
  @override
  bool get audioEnabled => _audio?.enabled ?? false;
  @override
  bool get videoEnabled => _video?.enabled ?? false;

  @override
  set audioEnabled(bool on) => _audio?.enabled = on;
  @override
  set videoEnabled(bool on) => _video?.enabled = on;

  bool _front = true;

  @override
  Future<bool> switchCamera() async {
    final track = _video;
    if (track == null) return _front;
    try {
      _front = await Helper.switchCamera(track);
    } catch (err) {
      debugPrint('[call] switch camera failed: $err');
    }
    return _front;
  }

  @override
  Future<void> setSpeaker(bool on) async {
    try {
      await Helper.setSpeakerphoneOn(on);
    } catch (err) {
      debugPrint('[call] speaker route failed: $err');
    }
  }

  @override
  Future<void> release() async {
    if (_released) return;
    _released = true;
    await WebRtcEngine._stop(_stream);
  }
}

class _WebRtcPeerLink implements PeerLink {
  _WebRtcPeerLink(this._pc);

  final RTCPeerConnection _pc;
  String _connectionState = 'new';
  bool _hasRemote = false;
  MediaStream? _remote;
  bool _closed = false;

  @override
  String get connectionState => _connectionState;
  @override
  bool get hasRemoteDescription => _hasRemote;

  @override
  Future<String> signalingState() async {
    final s = await _pc.getSignalingState();
    return switch (s) {
      RTCSignalingState.RTCSignalingStateStable => 'stable',
      RTCSignalingState.RTCSignalingStateHaveLocalOffer => 'have-local-offer',
      RTCSignalingState.RTCSignalingStateHaveRemoteOffer => 'have-remote-offer',
      RTCSignalingState.RTCSignalingStateHaveLocalPrAnswer => 'have-local-pranswer',
      RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer => 'have-remote-pranswer',
      RTCSignalingState.RTCSignalingStateClosed => 'closed',
      null => 'stable',
    };
  }

  @override
  Future<SdpDesc> createOffer({bool iceRestart = false}) async {
    if (iceRestart) await _pc.restartIce();
    final d = await _pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    return SdpDesc(d.type ?? 'offer', d.sdp ?? '');
  }

  @override
  Future<SdpDesc> createAnswer() async {
    final d = await _pc.createAnswer();
    return SdpDesc(d.type ?? 'answer', d.sdp ?? '');
  }

  @override
  Future<void> setLocalDescription(SdpDesc desc) =>
      _pc.setLocalDescription(RTCSessionDescription(desc.sdp, desc.type));

  @override
  Future<void> setRemoteDescription(SdpDesc desc) async {
    await _pc.setRemoteDescription(RTCSessionDescription(desc.sdp, desc.type));
    _hasRemote = true;
  }

  @override
  Future<void> rollback() => _pc.setLocalDescription(RTCSessionDescription('', 'rollback'));

  @override
  Future<void> addIceCandidate(Map<String, dynamic> c) => _pc.addCandidate(RTCIceCandidate(
        c['candidate']?.toString(),
        c['sdpMid']?.toString(),
        c['sdpMLineIndex'] is int ? c['sdpMLineIndex'] as int : int.tryParse('${c['sdpMLineIndex']}'),
      ));

  @override
  Future<String> describeLocalCandidates() async {
    try {
      final reports = await _pc.getStats();
      final local = reports
          .where((r) => r.type == 'local-candidate')
          .map((r) => '${r.values['candidateType']}/${r.values['protocol']}')
          .join(' ');
      return local.isEmpty ? 'none' : local;
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _pc.onIceCandidate = null;
    _pc.onConnectionState = null;
    _pc.onIceConnectionState = null;
    _pc.onTrack = null;
    try {
      await _pc.close();
    } catch (_) {}
    try {
      await _pc.dispose();
    } catch (_) {}
    try {
      await _remote?.dispose();
    } catch (_) {}
    _remote = null;
  }
}
