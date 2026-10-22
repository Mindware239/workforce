/// The live half of calls: owns the one [CallSession], feeds it every call:*
/// event from the app's socket, and does what a call needs around it —
/// ring / ringback, keeping the screen awake for video, keeping the socket
/// open while the app is backgrounded mid-call, runtime permissions, and
/// refreshing the call history in the thread when a call ends.
///
/// Parity target: frontend/src/components/realtime/realtime-provider.tsx.
///
///   server → client handled here
///     call:incoming          { call }
///     call:accepted          { callId }
///     call:handled-elsewhere { callId }
///     call:signal            { callId, kind, data }
///     call:media             { callId, userId, audio, video }
///     call:peer-disconnected / call:peer-reconnected { callId }
///     call:ended             { callId, status, reason, endedBy, durationSeconds }
///
/// [callManagerProvider] is watched at the app root (CallLayer in main.dart),
/// so a call rings over whatever page is open while the socket is connected.
/// Without push, nothing rings once the socket has closed in the background.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/realtime/realtime_service.dart';
import 'package:workforce/features/call/data/call_models.dart';
import 'package:workforce/features/call/data/call_repository.dart';
import 'package:workforce/features/call/services/call_tones.dart';
import 'package:workforce/features/call/session/call_media.dart';
import 'package:workforce/features/call/session/call_session.dart';
import 'package:workforce/features/call/session/webrtc_engine.dart';

int? _asInt(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '');

class CallManager extends StateNotifier<CallState> {
  CallManager(this._ref)
      : _realtime = _ref.read(realtimeServiceProvider),
        super(CallState.idle) {
    session = CallSession(
      realtime: _realtime,
      engine: _ref.read(callMediaEngineProvider),
      timings: _ref.read(callTimingsProvider),
      listener: _onState,
      fetchRtcConfig: () => _ref.read(callRepositoryProvider).rtcConfig(),
    );
    _start();
  }

  final Ref _ref;
  late final CallSession session;
  final List<StreamSubscription<dynamic>> _subs = [];
  CallPhase _lastPhase = CallPhase.idle;
  bool _wakelock = false;
  bool _disposed = false;

  final RealtimeService _realtime;
  String _tr(String key) => _ref.read(appLocalizationProvider).tr(key);

  void _start() {
    final rt = _realtime;
    void on(String event, void Function(Map data) fn) {
      _subs.add(rt.on(event).listen((d) {
        if (d is! Map) return;
        try {
          fn(d);
        } catch (err) {
          debugPrint('[call] $event failed: $err');
        }
      }));
    }

    on('call:incoming', (d) {
      final call = CallView.fromJson(d['call']);
      if (call != null) session.onIncoming(call);
    });
    on('call:accepted', (d) {
      final id = _asInt(d['callId']);
      if (id != null) unawaited(session.onAccepted(id));
    });
    on('call:handled-elsewhere', (d) {
      final id = _asInt(d['callId']);
      if (id != null) session.onHandledElsewhere(id);
    });
    on('call:signal', (d) {
      final id = _asInt(d['callId']);
      final kind = d['kind']?.toString();
      if (id != null && kind != null) unawaited(session.onSignal(id, kind, d['data']));
    });
    on('call:media', (d) {
      final id = _asInt(d['callId']);
      if (id != null) session.onRemoteMedia(id, d['audio'] != false, d['video'] != false);
    });
    on('call:peer-disconnected', (d) {
      final id = _asInt(d['callId']);
      if (id != null) session.onPeerAway(id, true);
    });
    on('call:peer-reconnected', (d) {
      final id = _asInt(d['callId']);
      if (id != null) session.onPeerAway(id, false);
    });
    on('call:ended', (d) {
      final id = _asInt(d['callId']);
      if (id == null) return;
      final conversationId = session.state.callId == id ? session.state.conversationId : null;
      session.onEnded(id, d['status']?.toString() ?? 'ended', d['reason']?.toString(), _asInt(d['durationSeconds']));
      _refreshHistory(conversationId);
    });

    _subs.add(rt.onConnected.listen((_) {
      unawaited(session.onSocketReconnected());
      _ref.read(callHistoryProvider.notifier).refreshLoaded();
    }));
    _subs.add(rt.statusStream.listen((status) {
      if (status == RealtimeStatus.connected) return;
      if (status == RealtimeStatus.idle) {
        // Signed out: the call goes with the session.
        session.dispose();
        _ref.read(callHistoryProvider.notifier).reset();
        return;
      }
      session.onSocketLost();
    }));
  }

  void _refreshHistory(int? conversationId) {
    final history = _ref.read(callHistoryProvider.notifier);
    if (conversationId != null) {
      unawaited(history.load(conversationId));
    } else {
      history.refreshLoaded();
    }
  }

  void _onState(CallState next) {
    if (_disposed || !mounted) return;
    state = next;
    if (next.phase == _lastPhase) return;
    _lastPhase = next.phase;

    unawaited(CallTones.instance.play(switch (next.phase) {
      CallPhase.incoming => CallTone.ring,
      CallPhase.outgoing => CallTone.ringback,
      _ => CallTone.none,
    }));

    // Ringing or on a call: backgrounding must not close the socket.
    _realtime.holdOpen(this, next.busy);

    final awake = next.busy && next.media == CallMedia.video && next.phase != CallPhase.incoming;
    if (awake != _wakelock) {
      _wakelock = awake;
      unawaited((awake ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((_) {}));
    }
  }

  // --- actions ---------------------------------------------------------------

  /// Rings the other person of a direct conversation. Returns a message to
  /// show when the call could not start, else null.
  Future<String?> startCall(int conversationId, CallMedia media, CallPeer peer) async {
    if (session.busy) return _tr('call.errSelfBusy');
    if (!_realtime.isConnected) return _tr('call.errOffline');
    final denied = await _ensurePermissions(media);
    if (denied != null) return denied;
    try {
      await session.start(conversationId, media, peer);
      return null;
    } on MediaAccessError catch (err) {
      return _mediaMessage(err, media);
    } on RealtimeException catch (err) {
      // A busy callee is recorded as a missed call: show it in the thread.
      _refreshHistory(conversationId);
      return _realtimeMessage(err, peer.fullName);
    } catch (_) {
      return _tr('chat.callFailed');
    }
  }

  /// Answers the ringing call. Returns a message when it could not be answered.
  Future<String?> accept() async {
    final media = session.state.media;
    final denied = await _ensurePermissions(media);
    if (denied != null) {
      session.refuseForPermission();
      return denied;
    }
    try {
      await session.accept();
      return null;
    } on MediaAccessError catch (err) {
      return _mediaMessage(err, media);
    } on RealtimeException catch (err) {
      return err.code == 'ALREADY_ANSWERED' || err.code == 'CALL_ENDED' ? null : _realtimeMessage(err, '');
    } catch (_) {
      return _tr('call.couldNotAnswer');
    }
  }

  void reject() => session.reject();
  void hangUp() => session.hangUp();
  void toggleMic() => session.toggleMic();
  void toggleCam() => session.toggleCam();
  Future<void> switchCamera() => session.switchCamera();
  Future<void> toggleSpeaker() => session.toggleSpeaker();

  /// Microphone (and camera for video) before the call starts. Android asks
  /// here; on iOS the system asks when the microphone first opens (the
  /// permission_handler pods are not configured), and a refusal surfaces
  /// as a [MediaAccessError] from the engine.
  Future<String?> _ensurePermissions(CallMedia media) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final wanted = [Permission.microphone, if (media == CallMedia.video) Permission.camera];
    final result = await wanted.request();
    // Bluetooth headsets need BLUETOOTH_CONNECT on Android 12+; a refusal only
    // means the call stays on the phone's own speaker / earpiece.
    unawaited(Permission.bluetoothConnect.request().then((_) {}, onError: (_) {}));

    final mic = result[Permission.microphone];
    final cam = result[Permission.camera];
    final micOk = mic == PermissionStatus.granted || mic == PermissionStatus.limited;
    final camOk = media == CallMedia.audio || cam == PermissionStatus.granted || cam == PermissionStatus.limited;
    if (micOk && camOk) return null;
    final permanently = mic == PermissionStatus.permanentlyDenied || cam == PermissionStatus.permanentlyDenied;
    final key = media == CallMedia.video ? 'call.permissionCamMic' : 'call.permissionMic';
    return permanently ? '${_tr(key)} ${_tr('call.permissionSettings')}' : _tr(key);
  }

  /// Opens the app's system settings page (permissions).
  Future<void> openSettings() => openAppSettings();

  String _mediaMessage(MediaAccessError err, CallMedia media) => switch (err.reason) {
        'permission_denied' => _tr(media == CallMedia.video ? 'call.permissionCamMic' : 'call.permissionMic'),
        'no_device' => _tr(media == CallMedia.video ? 'call.errNoCamera' : 'call.errNoMic'),
        'device_busy' => _tr('call.errDeviceBusy'),
        _ => _tr('call.errMedia'),
      };

  String _realtimeMessage(RealtimeException err, String peerName) {
    switch (err.code) {
      case 'BUSY':
        return err.message.contains('already')
            ? _tr('call.errSelfBusy')
            : _tr('call.errPeerBusy').replaceAll('{name}', peerName);
      case 'OFFLINE':
      case 'TIMEOUT':
        return _tr('call.errOffline');
      case 'RATE_LIMITED':
        return _tr('call.errRateLimited');
      default:
        return err.message.isNotEmpty ? err.message : _tr('chat.callFailed');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    session.dispose();
    _realtime.holdOpen(this, false);
    unawaited(CallTones.instance.stop());
    if (_wakelock) unawaited(WakelockPlus.disable().catchError((_) {}));
    super.dispose();
  }
}

/// The WebRTC stack; replaced by a scripted fake in protocol tests.
final callMediaEngineProvider = Provider<CallMediaEngine>((ref) => const WebRtcEngine());

/// Setup / recovery clocks; shortened in protocol tests.
final callTimingsProvider = Provider<CallTimings>((ref) => const CallTimings());

final callManagerProvider = StateNotifierProvider<CallManager, CallState>((ref) => CallManager(ref));
