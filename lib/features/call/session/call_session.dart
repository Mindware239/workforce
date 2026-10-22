/// One audio or video call: the peer connection, the local camera and
/// microphone, and the signalling that goes with them over the app's one
/// socket ([RealtimeService]).
///
/// A Dart port of the web's CallSession
/// (frontend/src/lib/realtime/call-session.ts), with the same protocol
/// (backend/modules/chat/realtime/calls.socket.js):
///
///   client → server (acked `{ ok, ... }`)
///     call:invite { conversationId, media }   → { call, rtc, calleeOnline }
///     call:accept { callId }                  → { call, rtc }
///     call:reject { callId }                  (callee declines, or caller cancels while ringing)
///     call:end    { callId, reason? }         hangup | media_failed | permission_denied | ice_failed
///     call:signal { callId, kind, data }      offer | answer | candidate | restart
///     call:media  { callId, audio, video }
///     call:resume { callId }                  → { call, role, rtc? } after the socket reconnected
///
///   server → client (delivered to the methods named on*)
///     call:incoming, call:accepted, call:handled-elsewhere, call:ended,
///     call:signal, call:media, call:peer-disconnected, call:peer-reconnected
///
/// Roles are fixed for the life of the call. The caller makes every offer —
/// the first, and each ICE restart — and the callee only answers, so the two
/// sides never offer at once. When the callee sees the path break it asks the
/// caller to restart with a `restart` signal.
///
/// Recovery, in order of how often it happens:
///  - the socket drops but media keeps flowing peer to peer: on reconnect the
///    call is re-claimed with call:resume (the server holds each side for
///    RTC_RECONNECT_GRACE_SECONDS, default 30 s, before ending it with
///    reason connection_lost)
///  - the network changes and ICE disconnects: an ICE restart after a short
///    wait, again if it fails, and the call ends (ice_failed) if nothing has
///    recovered within [CallTimings.recoveryLimit]
///  - the first connection never comes up: renegotiate every
///    [CallTimings.setupRetry]; give up after [CallTimings.setupLimit] with
///    call:end reason ice_failed and the outcome could_not_connect.
///
/// Everything acquired is released in one place, [teardown], whatever ended
/// the call.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:workforce/core/realtime/realtime_service.dart';
import 'package:workforce/features/call/data/call_models.dart';
import 'package:workforce/features/call/session/call_media.dart';

class CallTimings {
  /// How long the path may stay broken, across restarts, before the call is given up.
  final Duration recoveryLimit;

  /// A brief "disconnected" often heals by itself; restart only if it does not.
  final Duration disconnectRestart;

  /// A first connection not up by now is negotiated again.
  final Duration setupRetry;

  /// How long an offer may wait for its answer before a forced re-offer replaces it.
  final Duration offerAnswerWait;

  /// A first connection not up by now is given up, with a reason.
  final Duration setupLimit;

  /// How long "Call ended" stays on screen.
  final Duration endedLinger;

  /// The same, for outcomes that need reading (could not connect, blocked).
  final Duration endedLingerLong;

  const CallTimings({
    this.recoveryLimit = const Duration(seconds: 25),
    this.disconnectRestart = const Duration(milliseconds: 2500),
    this.setupRetry = const Duration(seconds: 8),
    this.offerAnswerWait = const Duration(seconds: 3),
    this.setupLimit = const Duration(seconds: 30),
    this.endedLinger = const Duration(milliseconds: 2500),
    this.endedLingerLong = const Duration(milliseconds: 4500),
  });
}

typedef CallListener = void Function(CallState state);

class _Signal {
  final int callId;
  final String kind;
  final dynamic data;

  const _Signal(this.callId, this.kind, this.data);
}

class CallSession {
  CallSession({
    required this.realtime,
    required this.engine,
    required this.listener,
    this.fetchRtcConfig,
    this.timings = const CallTimings(),
    void Function(String line)? trace,
  }) : _trace = trace ?? ((line) => debugPrint('[call] $line'));

  final RealtimeService realtime;
  final CallMediaEngine engine;
  final CallTimings timings;

  /// GET /api/chat/rtc-config, for when an ack carried no ICE servers.
  final Future<RtcConfig?> Function()? fetchRtcConfig;

  final CallListener listener;
  final void Function(String line) _trace;

  CallState state = CallState.idle;
  LocalMedia? _local;
  PeerLink? _pc;
  RtcConfig? _rtc;

  /// Bumped by [teardown]; async work started for an older call drops its result.
  int _generation = 0;
  bool _creatingPeer = false;

  final List<Map<String, dynamic>> _pendingCandidates = [];

  /// Signals that beat this side's own peer connection (the offer can outrun the accept's ack).
  final List<_Signal> _earlySignals = [];

  /// An accept that beat the invite's own ack.
  int? _earlyAccept;
  bool _makingOffer = false;

  /// When the outstanding offer went out; a forced re-offer leaves a fresh one alone.
  DateTime _offerSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _restartQueued = false;

  /// Remote signals are applied one at a time, in arrival order.
  Future<void> _signalChain = Future.value();

  Timer? _disconnectTimer;
  Timer? _recoveryTimer;
  Timer? _setupRetryTimer;
  Timer? _setupLimitTimer;
  Timer? _lingerTimer;

  void _set(CallState next) {
    state = next;
    listener(next);
  }

  bool get busy => state.busy;

  // --- outgoing --------------------------------------------------------------

  /// Rings [peer]. Throws [MediaAccessError] (camera / microphone) or
  /// [RealtimeException] (BUSY, OFFLINE, FORBIDDEN, ...).
  Future<void> start(int conversationId, CallMedia media, CallPeer peer) async {
    if (busy) throw const RealtimeException('BUSY', 'You are already on a call');
    _clearLinger();
    final local = await engine.acquire(media);
    if (busy) {
      // A call rang in while the camera was opening.
      await local.release();
      throw const RealtimeException('BUSY', 'You are already on a call');
    }
    _local = local;
    final generation = _generation;
    _set(CallState(
      phase: CallPhase.outgoing,
      conversationId: conversationId,
      media: media,
      role: CallRole.caller,
      peer: peer,
      localStream: local.stream,
      camOn: media == CallMedia.video,
      speakerOn: media == CallMedia.video,
    ));
    unawaited(local.setSpeaker(media == CallMedia.video));
    try {
      final reply = await realtime.emitWithAck(
        'call:invite',
        {'conversationId': conversationId, 'media': media.wire},
        timeout: const Duration(seconds: 10),
      );
      final call = CallView.fromJson(reply['call']);
      if (call == null) throw const RealtimeException('BAD_REPLY', 'The server sent an unexpected reply');
      _rtc = RtcConfig.fromJson(reply['rtc']);
      // The call may have been torn down while the invite was in flight.
      if (generation != _generation || state.phase != CallPhase.outgoing) {
        realtime.emitQuiet('call:end', {'callId': call.callId});
        return;
      }
      _set(state.copyWith(callId: call.callId, calleeOnline: reply['calleeOnline'] == true));
      if (_earlyAccept == call.callId) {
        _earlyAccept = null;
        await onAccepted(call.callId);
      }
    } catch (err) {
      if (generation == _generation) {
        teardown();
        _set(CallState.idle);
      }
      rethrow;
    }
  }

  /// The callee picked up: build the connection and make the first offer.
  Future<void> onAccepted(int callId) async {
    if (state.phase == CallPhase.outgoing && state.callId == null) {
      _earlyAccept = callId;
      return;
    }
    if (callId != state.callId || state.role != CallRole.caller) return;
    if (state.phase != CallPhase.outgoing) return;
    _set(state.copyWith(phase: CallPhase.connecting));
    if (!await _createPeerConnection()) return;
    _startSetupClock();
    await _makeOffer(false);
  }

  // --- incoming --------------------------------------------------------------

  void onIncoming(CallView call) {
    // The server does not ring a busy person; a second device may still hear it.
    if (busy) return;
    _clearLinger();
    _set(CallState(
      phase: CallPhase.incoming,
      callId: call.callId,
      conversationId: call.conversationId,
      media: call.media,
      role: CallRole.callee,
      peer: call.caller,
      camOn: call.media == CallMedia.video,
      speakerOn: call.media == CallMedia.video,
    ));
  }

  /// Answers the ringing call. Throws [MediaAccessError] when the camera or
  /// microphone cannot be opened (the call is then ended as
  /// permission_denied), or [RealtimeException] when the server refuses.
  Future<void> accept() async {
    final callId = state.callId;
    if (state.phase != CallPhase.incoming || callId == null) return;
    final generation = _generation;
    final LocalMedia local;
    try {
      local = await engine.acquire(state.media);
    } catch (err) {
      if (state.callId == callId && state.phase == CallPhase.incoming) {
        refuseForPermission();
      }
      rethrow;
    }
    if (generation != _generation || state.callId != callId || state.phase != CallPhase.incoming) {
      await local.release();
      return;
    }
    _local = local;
    _set(state.copyWith(localStream: local.stream, phase: CallPhase.connecting));
    unawaited(local.setSpeaker(state.speakerOn));
    try {
      final reply = await realtime.emitWithAck('call:accept', {'callId': callId});
      if (generation != _generation) return;
      _rtc = RtcConfig.fromJson(reply['rtc']) ?? _rtc;
      if (!await _createPeerConnection()) return;
      _startSetupClock();
      _drainEarlySignals();
    } catch (err) {
      if (generation == _generation) {
        _finish(err is RealtimeException ? err.code.toLowerCase() : 'failed');
      }
      rethrow;
    }
  }

  /// Ends a ringing call because this device may not use the microphone /
  /// camera (the web's accept() failure path).
  void refuseForPermission() {
    final callId = state.callId;
    if (callId == null || !busy) return;
    realtime.emitQuiet('call:end', {'callId': callId, 'reason': 'permission_denied'});
    _finish('permission_denied');
  }

  void reject() {
    final callId = state.callId;
    if (state.phase != CallPhase.incoming || callId == null) return;
    realtime.emitQuiet('call:reject', {'callId': callId});
    _finish('declined_by_me');
  }

  /// Another of this person's devices answered.
  void onHandledElsewhere(int callId) {
    if (callId == state.callId && state.phase == CallPhase.incoming) {
      teardown();
      _set(CallState.idle);
    }
  }

  // --- in call ---------------------------------------------------------------

  void hangUp([String reason = 'hangup']) {
    final callId = state.callId;
    if (!busy) return;
    if (callId != null) realtime.emitQuiet('call:end', {'callId': callId, 'reason': reason});
    _finish(reason == 'hangup' ? 'hangup_by_me' : reason);
  }

  void toggleMic() {
    final local = _local;
    if (local == null || !local.hasAudio) return;
    local.audioEnabled = !local.audioEnabled;
    _set(state.copyWith(micOn: local.audioEnabled));
    _announceMedia();
  }

  void toggleCam() {
    final local = _local;
    if (local == null || !local.hasVideo) return;
    local.videoEnabled = !local.videoEnabled;
    _set(state.copyWith(camOn: local.videoEnabled));
    _announceMedia();
  }

  Future<void> switchCamera() async {
    final local = _local;
    if (local == null || !local.hasVideo) return;
    final front = await local.switchCamera();
    if (identical(local, _local)) _set(state.copyWith(frontCamera: front));
  }

  Future<void> toggleSpeaker() async {
    final on = !state.speakerOn;
    _set(state.copyWith(speakerOn: on));
    await _local?.setSpeaker(on);
  }

  void _announceMedia() {
    final callId = state.callId;
    if (callId != null) {
      realtime.emitQuiet('call:media', {'callId': callId, 'audio': state.micOn, 'video': state.camOn});
    }
  }

  void onRemoteMedia(int callId, bool audio, bool video) {
    if (callId == state.callId) _set(state.copyWith(remoteMicOn: audio, remoteCamOn: video));
  }

  /// A call:signal from the other side. Applied in arrival order.
  Future<void> onSignal(int callId, String kind, dynamic data) {
    final next = _signalChain.then((_) => _applySignal(_Signal(callId, kind, data)));
    _signalChain = next.catchError((_) {});
    return next;
  }

  void _drainEarlySignals() {
    final early = List<_Signal>.of(_earlySignals);
    _earlySignals.clear();
    for (final s in early) {
      unawaited(onSignal(s.callId, s.kind, s.data));
    }
  }

  Future<void> _applySignal(_Signal signal) async {
    if (signal.callId != state.callId) return;
    final pc = _pc;
    if (pc == null) {
      if (state.phase == CallPhase.connecting) _earlySignals.add(signal);
      return;
    }
    final data = signal.data;
    try {
      if (signal.kind == 'offer' && state.role == CallRole.callee) {
        final offer = SdpDesc.fromJson(data);
        if (offer == null) return;
        await pc.setRemoteDescription(offer);
        await _flushCandidates();
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        if (!identical(pc, _pc)) return;
        _sendSignal('answer', {'type': 'answer', 'sdp': answer.sdp});
      } else if (signal.kind == 'answer' && state.role == CallRole.caller) {
        if (await pc.signalingState() != 'have-local-offer') return;
        final answer = SdpDesc.fromJson(data);
        if (answer == null) return;
        await pc.setRemoteDescription(answer);
        await _flushCandidates();
        if (_restartQueued) {
          _restartQueued = false;
          unawaited(_makeOffer(true));
        }
      } else if (signal.kind == 'candidate' && data is Map) {
        final candidate = Map<String, dynamic>.from(data);
        if (pc.hasRemoteDescription) {
          await pc.addIceCandidate(candidate);
        } else {
          _pendingCandidates.add(candidate);
        }
      } else if (signal.kind == 'restart' && state.role == CallRole.caller) {
        unawaited(_makeOffer(true, force: true));
      }
    } catch (err) {
      // A candidate for a stale generation, or an offer racing a restart:
      // the next restart cycle recovers, and the recovery timer bounds it.
      _trace('${signal.kind} not applied: $err');
    }
  }

  void onPeerAway(int callId, bool away) {
    if (callId != state.callId) return;
    _set(state.copyWith(peerAway: away));
    if (!away) _recoverIfNeeded();
  }

  /// The socket came back: re-claim the call on the server, then mend the path if it broke.
  Future<void> onSocketReconnected() async {
    final callId = state.callId;
    if (callId == null || !busy) return;
    final generation = _generation;
    try {
      final reply = await realtime.emitWithAck('call:resume', {'callId': callId});
      if (generation != _generation) return;
      _rtc = RtcConfig.fromJson(reply['rtc']) ?? _rtc;
      // Signals sent while away were dropped; a call still setting up renegotiates.
      if (state.phase == CallPhase.connecting) {
        _requestRestart(force: true);
      } else {
        _recoverIfNeeded();
      }
    } catch (err) {
      if (generation != _generation) return;
      // An OFFLINE / TIMEOUT here is another blip; the next connect retries.
      if (err is RealtimeException && (err.code == 'OFFLINE' || err.code == 'TIMEOUT')) return;
      // The server no longer has the call: it ended while this side was away.
      _finish('connection_lost');
    }
  }

  void onSocketLost() {
    if (state.phase == CallPhase.active) _set(state.copyWith(phase: CallPhase.reconnecting));
  }

  /// The server says the call is over.
  void onEnded(int callId, String status, String? reason, int? durationSeconds) {
    if (callId != state.callId) return;
    final String key;
    if (status == 'missed') {
      key = reason == 'busy' ? 'busy' : 'no_answer';
    } else if (status == 'rejected') {
      key = 'declined';
    } else if (status == 'cancelled') {
      key = 'cancelled';
    } else if (status == 'failed' && reason == 'ice_failed' && state.connectedAt == null) {
      key = 'could_not_connect';
    } else if (status == 'failed') {
      key = 'failed';
    } else if (reason == 'connection_lost') {
      key = 'connection_lost';
    } else {
      key = 'ended';
    }
    _finish(key, durationSeconds);
  }

  // --- peer connection -------------------------------------------------------

  Future<bool> _createPeerConnection() async {
    if (_pc != null || _creatingPeer) return _pc != null;
    final local = _local;
    if (local == null) return false;
    final generation = _generation;
    _creatingPeer = true;
    try {
      var rtc = _rtc;
      if (rtc == null || rtc.iceServers.isEmpty) {
        rtc = await fetchRtcConfig?.call().catchError((_) => null) ?? rtc;
      }
      final callbacks = PeerCallbacks(
        onIceCandidate: (c) {
          if (generation == _generation && state.callId != null) _sendSignal('candidate', c);
        },
        onConnectionState: (s) {
          if (generation == _generation) _onConnectionState(s);
        },
        onIceConnectionState: (s) => _trace('ice $s'),
        onRemoteStream: (stream, hasVideo) {
          if (generation == _generation) {
            _set(state.copyWith(remoteStream: stream, remoteHasVideo: hasVideo));
          }
        },
      );
      final pc = await engine.createPeer(rtc ?? RtcConfig.fallback, local, callbacks);
      if (generation != _generation) {
        await pc.close();
        return false;
      }
      _pc = pc;
      return true;
    } catch (err) {
      _trace('peer connection failed: $err');
      if (generation == _generation) hangUp('media_failed');
      return false;
    } finally {
      _creatingPeer = false;
    }
  }

  void _onConnectionState(String s) {
    _trace('connection $s');
    if (s == 'connected') {
      _clearRecovery();
      // The audio route is settled once media flows; apply the chosen one again.
      if (state.connectedAt == null) unawaited(_local?.setSpeaker(state.speakerOn));
      _set(state.copyWith(phase: CallPhase.active, connectedAt: state.connectedAt ?? DateTime.now()));
    } else if (state.phase == CallPhase.connecting && s != 'failed') {
      // Still setting up: the setup clock, not the recovery one, owns this.
    } else if (s == 'disconnected') {
      _set(state.copyWith(phase: CallPhase.reconnecting));
      _startRecoveryClock();
      _disconnectTimer?.cancel();
      _disconnectTimer = Timer(timings.disconnectRestart, () {
        if (_pc?.connectionState == 'disconnected') _requestRestart();
      });
    } else if (s == 'failed') {
      final pc = _pc;
      if (pc != null) unawaited(pc.describeLocalCandidates().then((d) => _trace('local candidates $d')));
      if (state.phase == CallPhase.connecting) {
        // Never connected: retry now rather than wait for the next setup tick.
        _requestRestart();
        return;
      }
      _set(state.copyWith(phase: CallPhase.reconnecting));
      _startRecoveryClock();
      _requestRestart();
    }
  }

  /// [force]: replace an offer still waiting for its answer — that answer
  /// (or the offer itself) was lost, and waiting for it would wait for ever.
  Future<void> _makeOffer(bool iceRestart, {bool force = false}) async {
    final pc = _pc;
    final callId = state.callId;
    if (pc == null || callId == null || state.role != CallRole.caller) return;
    if (_makingOffer) {
      if (iceRestart) _restartQueued = true;
      return;
    }
    _makingOffer = true;
    try {
      final answerOverdue = DateTime.now().difference(_offerSentAt) > timings.offerAnswerWait;
      final signaling = await pc.signalingState();
      if (signaling != 'stable' && !(force && answerOverdue)) {
        // An offer is already out; restart once its answer lands.
        if (iceRestart) _restartQueued = true;
        return;
      }
      if (signaling == 'have-local-offer') {
        _trace('answer overdue; rolling back the outstanding offer');
        await pc.rollback();
      }
      final offer = await pc.createOffer(iceRestart: iceRestart);
      await pc.setLocalDescription(offer);
      if (!identical(pc, _pc)) return;
      _offerSentAt = DateTime.now();
      _sendSignal('offer', {'type': 'offer', 'sdp': offer.sdp});
    } catch (err) {
      // The setup / recovery clock bounds a failure here.
      _trace('offer failed: $err');
    } finally {
      _makingOffer = false;
    }
  }

  void _requestRestart({bool force = false}) {
    if (_pc == null || state.callId == null) return;
    _trace('restart${force ? ' (renegotiate)' : ''}');
    if (state.role == CallRole.caller) {
      unawaited(_makeOffer(true, force: force));
    } else {
      _sendSignal('restart', null);
    }
  }

  /// Sends one signalling message. A refusal is not retried here — the setup
  /// and recovery clocks renegotiate — but it is logged, because a refused
  /// signal is otherwise invisible and the call just never connects.
  void _sendSignal(String kind, Object? data) {
    final callId = state.callId;
    if (callId == null) return;
    if (!realtime.isConnected) {
      _trace('$kind not sent: offline (renegotiated after reconnect)');
      return;
    }
    realtime
        .emitWithAck('call:signal', {'callId': callId, 'kind': kind, 'data': data},
            timeout: const Duration(seconds: 8))
        .then((_) {}, onError: (Object err) {
      if (err is RealtimeException && err.code == 'TIMEOUT') {
        _trace('$kind not acknowledged');
      } else if (err is RealtimeException) {
        _trace('$kind refused: ${err.code} ${err.message}');
      } else {
        _trace('$kind failed: $err');
      }
    });
  }

  /// Bounds the first connection: renegotiate while it is not up, give up after the setup limit.
  void _startSetupClock() {
    _clearSetupClock();
    _setupRetryTimer = Timer.periodic(timings.setupRetry, (_) {
      if (_pc?.connectionState == 'connected') {
        _clearSetupClock();
        return;
      }
      _trace('not connected yet; negotiating again');
      _requestRestart(force: true);
    });
    _setupLimitTimer = Timer(timings.setupLimit, () {
      _clearSetupClock();
      final pc = _pc;
      if (pc != null && pc.connectionState != 'connected') {
        _trace('could not connect within ${timings.setupLimit.inSeconds} s');
        unawaited(pc.describeLocalCandidates().then((d) => _trace('local candidates $d')));
        final callId = state.callId;
        if (callId != null) realtime.emitQuiet('call:end', {'callId': callId, 'reason': 'ice_failed'});
        _finish('could_not_connect');
      }
    });
  }

  void _clearSetupClock() {
    _setupRetryTimer?.cancel();
    _setupLimitTimer?.cancel();
    _setupRetryTimer = null;
    _setupLimitTimer = null;
  }

  void _recoverIfNeeded() {
    final s = _pc?.connectionState;
    if (s == 'disconnected' || s == 'failed') {
      _startRecoveryClock();
      _requestRestart();
    } else if (s == 'connected' && state.phase == CallPhase.reconnecting) {
      _set(state.copyWith(phase: CallPhase.active));
    }
  }

  void _startRecoveryClock() {
    if (_recoveryTimer != null) return;
    _recoveryTimer = Timer(timings.recoveryLimit, () {
      _recoveryTimer = null;
      final pc = _pc;
      if (pc != null && pc.connectionState != 'connected') hangUp('ice_failed');
    });
  }

  void _clearRecovery() {
    _clearSetupClock();
    _recoveryTimer?.cancel();
    _disconnectTimer?.cancel();
    _recoveryTimer = null;
    _disconnectTimer = null;
  }

  Future<void> _flushCandidates() async {
    final pc = _pc;
    if (pc == null) return;
    final queued = List<Map<String, dynamic>>.of(_pendingCandidates);
    _pendingCandidates.clear();
    for (final c in queued) {
      try {
        await pc.addIceCandidate(c);
      } catch (_) {
        // stale candidate
      }
    }
  }

  // --- the end ---------------------------------------------------------------

  void _finish(String reason, [int? durationSeconds]) {
    final connectedAt = state.connectedAt;
    final duration = durationSeconds ??
        (connectedAt != null ? (DateTime.now().difference(connectedAt).inMilliseconds / 1000).round() : null);
    final before = state;
    teardown();
    _set(CallState(
      phase: CallPhase.ended,
      callId: before.callId,
      conversationId: before.conversationId,
      media: before.media,
      role: before.role,
      peer: before.peer,
      endReason: reason,
      durationSeconds: duration,
    ));
    final long = reason == 'could_not_connect' || reason == 'permission_denied';
    _lingerTimer = Timer(long ? timings.endedLingerLong : timings.endedLinger, () {
      _lingerTimer = null;
      if (state.phase == CallPhase.ended) _set(CallState.idle);
    });
  }

  void _clearLinger() {
    _lingerTimer?.cancel();
    _lingerTimer = null;
  }

  /// Releases everything the call holds. Safe to call more than once.
  void teardown() {
    _generation += 1;
    _clearRecovery();
    _pendingCandidates.clear();
    _earlySignals.clear();
    _earlyAccept = null;
    _makingOffer = false;
    _restartQueued = false;
    final pc = _pc;
    _pc = null;
    if (pc != null) unawaited(pc.close());
    final local = _local;
    _local = null;
    if (local != null) unawaited(local.release());
    _rtc = null;
  }

  /// Signed out, or the app is going away: the server is told while the
  /// socket can still say it.
  void dispose() {
    final callId = state.callId;
    if (busy && callId != null) {
      realtime.emitQuiet(state.phase == CallPhase.incoming ? 'call:reject' : 'call:end', {'callId': callId});
    }
    _clearLinger();
    teardown();
    if (state.phase != CallPhase.idle) _set(CallState.idle);
  }
}
