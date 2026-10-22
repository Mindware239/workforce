/// The one Socket.IO connection the app holds, for chat now and calls next.
///
/// Mirrors the web client (frontend/src/lib/realtime/socket.ts) and the
/// server in backend/realtime/index.js.
///
/// ## Transport
/// * Origin: derived from [ApiClient.baseUrl] (scheme://host:port), path
///   `/api/socket.io`, WebSocket transport only.
/// * Auth: `{ token }` in the Socket.IO handshake `auth`, read from
///   [SecureStorage] at every connection attempt, so a reconnect after
///   signing in again (or a password change) carries the new token.
/// * One room per user on the server; every event arrives on the default
///   namespace. There is nothing to join or leave on the client.
/// * Reconnect: the manager retries transport failures with backoff
///   (1 s → 10 s, ±50 %). A handshake the server refuses with 429/500 is
///   retried by this class with its own backoff (up to 30 s). A refusal that
///   retrying cannot fix (401 / 403: token expired, session revoked, account
///   or subscription off) stops the loop: status becomes
///   [RealtimeStatus.refused] until [connect] / [reconnect] is called again
///   (login, token change) or the app is resumed (one attempt).
/// * The server ends sockets whose session was revoked by emitting
///   `session:ended { reason }` and disconnecting; that also lands in
///   [RealtimeStatus.refused] and on [sessionEnded].
/// * Lifecycle: the socket is closed once the app has been paused
///   (backgrounded) for [pauseGrace] and reopened on resume; every
///   (re)connect fires [onConnected], which is the cue to catch up on
///   whatever was missed (see chat_realtime.dart). [onResumed] fires on
///   every return to the foreground. [holdOpen] keeps the socket open in
///   the background regardless (a ringing or connected call); once the
///   last hold is released while still backgrounded, the grace restarts.
///
/// ## API (for chat, calls and anything else)
/// ```dart
/// final rt = RealtimeService.instance;           // or ref.read(realtimeServiceProvider)
/// await rt.connect();                             // idempotent; after login / on start
/// rt.on('message:new').listen((data) { ... });    // one server event, payload as sent
/// rt.events.listen((e) => print(e.name));         // every server event
/// rt.onConnected.listen((_) { /* catch up */ });  // each connect and reconnect
/// rt.onResumed / rt.sessionEnded                  // foreground again / signed out by server
/// rt.statusStream / rt.status / realtimeStatusProvider
/// final reply = await rt.emitWithAck('message:send', {...},
///     timeout: const Duration(seconds: 8));       // Map with ok: true, or throws
/// rt.emitQuiet('typing', {...});                  // fire and forget, dropped if offline
/// RealtimeService.newClientId();                  // idempotency key for sends
/// await rt.reconnect();                           // drop and reopen with a fresh token
/// rt.disconnect();                                // logout: close, stop, forget
/// ```
/// [emitWithAck] throws [RealtimeException] with `code`:
/// `OFFLINE` (not connected), `TIMEOUT`, or the server's own code
/// (`RATE_LIMITED`, `BAD_REQUEST`, `FORBIDDEN`, `NOT_FOUND`, `CONFLICT`,
/// `UNAUTHORIZED`, `SERVER_ERROR`, ...). Server acks are always
/// `{ ok: true, ...result }` or `{ ok: false, code, error }`.
///
/// Per-socket budgets on the server (burst, refill/s): message:send 20/2,
/// message:delivered 60/10, message:read 30/3, typing 10/1,
/// presence:query 10/1, call:invite 5/0.1, call:signal 300/50,
/// call:media 20/2, anything else 30/5. Persistent flooding gets the socket
/// disconnected by the server.
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/services/secure_storage.dart';

enum RealtimeStatus {
  /// Not started, or signed out.
  idle,

  /// First connection attempt in progress.
  connecting,

  /// Open; events flow.
  connected,

  /// Was connected, lost it, retrying.
  reconnecting,

  /// The server refused (auth) or ended the session; not retrying.
  refused,

  /// Closed on purpose while the app is in the background.
  paused,
}

/// A server → client event as it arrived.
class RealtimeEvent {
  final String name;
  final dynamic data;

  const RealtimeEvent(this.name, this.data);
}

class RealtimeException implements Exception {
  final String code;
  final String message;

  const RealtimeException(this.code, this.message);

  @override
  String toString() => message;
}

class RealtimeService {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  static const String socketPath = '/api/socket.io';

  /// scheme://host:port of the API, without the `/api` path. Replaceable for
  /// tests; takes effect on the next connection.
  String origin = Uri.parse(ApiClient.baseUrl).origin;

  /// Where the token comes from. Replaceable for tests.
  Future<String?> Function() readToken = () => SecureStorage().getToken();

  sio.Socket? _socket;
  Future<void>? _opening;
  bool _wanted = false;
  bool _paused = false;
  bool _everConnected = false;
  int _refusals = 0;
  Timer? _retryTimer;
  AppLifecycleListener? _lifecycle;

  final ValueNotifier<RealtimeStatus> _status =
      ValueNotifier(RealtimeStatus.idle);
  final StreamController<RealtimeStatus> _statusCtrl =
      StreamController.broadcast();
  final StreamController<RealtimeEvent> _eventsCtrl =
      StreamController.broadcast();
  final StreamController<void> _connectedCtrl = StreamController.broadcast();
  final StreamController<String> _sessionEndedCtrl =
      StreamController.broadcast();
  final StreamController<void> _resumedCtrl = StreamController.broadcast();

  // ---------------------------------------------------------------------------
  // Public surface
  // ---------------------------------------------------------------------------

  RealtimeStatus get status => _status.value;
  ValueListenable<RealtimeStatus> get statusListenable => _status;
  Stream<RealtimeStatus> get statusStream => _statusCtrl.stream;
  bool get isConnected => _socket?.connected == true;

  /// Every server event.
  Stream<RealtimeEvent> get events => _eventsCtrl.stream;

  /// One server event's payloads.
  Stream<dynamic> on(String event) =>
      _eventsCtrl.stream.where((e) => e.name == event).map((e) => e.data);

  /// Fires on every successful connect, first or re-.
  Stream<void> get onConnected => _connectedCtrl.stream;

  /// The server closed this session (`session:ended`), with its reason.
  Stream<String> get sessionEnded => _sessionEndedCtrl.stream;

  /// The app came back to the foreground (socket may or may not have
  /// stayed open meanwhile; [onConnected] fires too if it had to reopen).
  Stream<void> get onResumed => _resumedCtrl.stream;

  /// Opens the connection if it is not open. Safe to call repeatedly.
  Future<void> connect() {
    _wanted = true;
    _ensureLifecycle();
    if (_paused) return Future.value();
    if (_socket != null) {
      if (!_socket!.connected && status == RealtimeStatus.refused) {
        _setStatus(_everConnected
            ? RealtimeStatus.reconnecting
            : RealtimeStatus.connecting);
        _socket!.connect();
      }
      return Future.value();
    }
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  /// Closes and reopens with whatever token is stored now.
  Future<void> reconnect() {
    _teardown();
    _refusals = 0;
    // The old socket is gone; say so while the new one is being opened.
    if (status == RealtimeStatus.connected) _setStatus(RealtimeStatus.reconnecting);
    return connect();
  }

  /// Sign-out: closes the socket and stops every retry.
  void disconnect() {
    _wanted = false;
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _teardown();
    _everConnected = false;
    _refusals = 0;
    _setStatus(RealtimeStatus.idle);
  }

  /// Emits and waits for the server's acknowledgement.
  Future<Map<String, dynamic>> emitWithAck(
    String event,
    Object? payload, {
    Duration timeout = const Duration(seconds: 8),
  }) {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return Future.error(
        const RealtimeException('OFFLINE', 'Not connected'),
      );
    }

    final completer = Completer<Map<String, dynamic>>();
    final timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(
          const RealtimeException(
            'TIMEOUT',
            'The server did not answer in time',
          ),
        );
      }
    });

    socket.emitWithAck(
      event,
      payload,
      ack: ([dynamic reply]) {
        timer.cancel();
        if (completer.isCompleted) return;
        final map = reply is Map ? Map<String, dynamic>.from(reply) : null;
        if (map == null || map['ok'] != true) {
          completer.completeError(
            RealtimeException(
              map?['code']?.toString() ?? 'ERROR',
              map?['error']?.toString() ?? 'Request failed',
            ),
          );
        } else {
          completer.complete(map);
        }
      },
    );

    return completer.future;
  }

  /// Fire and forget, for events whose loss is harmless (typing, delivered).
  void emitQuiet(String event, Object? payload) {
    final socket = _socket;
    if (socket != null && socket.connected) {
      socket.emitWithAck(event, payload, ack: ([dynamic _]) {});
    }
  }

  /// While any holder holds it, backgrounding does not close the socket:
  /// a call that is ringing or connected must not drop because the person
  /// switched apps. Releasing the last hold while the app is still in the
  /// background starts the usual [pauseGrace] countdown.
  void holdOpen(Object holder, bool hold) {
    if (hold) {
      _holds.add(holder);
      return;
    }
    if (!_holds.remove(holder) || _holds.isNotEmpty) return;
    if (_paused && _pauseTimer == null && _socket != null) _armPauseTimer();
  }

  final Set<Object> _holds = {};

  /// A short random id for a message, so a retried send lands once.
  /// Matches the server's /^[A-Za-z0-9_-]{8,64}$/.
  static String newClientId() {
    final random = Random.secure();
    final bytes = List<int>.generate(12, (_) => random.nextInt(256));
    return 'c${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _open() async {
    final token = await readToken();
    if (!_wanted || _paused || _socket != null) return;
    if (token == null || token.isEmpty) {
      _setStatus(RealtimeStatus.idle);
      return;
    }

    final socket = sio.io(
      origin,
      sio.OptionBuilder()
          .setPath(socketPath)
          .setTransports(['websocket'])
          .disableAutoConnect()
          .enableForceNew()
          .enableReconnection()
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(10000)
          .setRandomizationFactor(0.5)
          .setTimeout(15000)
          .setAuthFn((callback) {
            readToken().then(
              (t) => callback({'token': t ?? ''}),
              onError: (_) => callback({'token': ''}),
            );
          })
          .build(),
    );

    socket.onConnect((_) {
      _everConnected = true;
      _refusals = 0;
      _setStatus(RealtimeStatus.connected);
      _connectedCtrl.add(null);
    });

    socket.onDisconnect((reason) {
      if (!identical(socket, _socket)) return;
      // The server closing us on purpose does not reconnect by itself.
      if (reason == 'io server disconnect') {
        _setStatus(RealtimeStatus.refused);
      } else if (reason != 'io client disconnect') {
        _setStatus(_everConnected
            ? RealtimeStatus.reconnecting
            : RealtimeStatus.connecting);
      }
    });

    socket.onConnectError((err) {
      if (!identical(socket, _socket)) return;
      final httpStatus = _statusOf(err);
      if (httpStatus == 401 || httpStatus == 403) {
        _setStatus(RealtimeStatus.refused);
        return;
      }
      _setStatus(_everConnected
          ? RealtimeStatus.reconnecting
          : RealtimeStatus.connecting);
      // A middleware refusal (CONNECT_ERROR packet: 429, 500) destroys the
      // socket and the manager does not retry it; this does.
      if (err is Map) _scheduleRetry();
    });

    socket.on('session:ended', (data) {
      final reason = data is Map ? data['reason']?.toString() : null;
      _setStatus(RealtimeStatus.refused);
      _sessionEndedCtrl.add(reason ?? 'session_ended');
    });

    socket.onAny((String event, [dynamic data]) {
      _eventsCtrl.add(RealtimeEvent(event, data));
    });

    _socket = socket;
    _setStatus(_everConnected
        ? RealtimeStatus.reconnecting
        : RealtimeStatus.connecting);
    socket.connect();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final step = min(_refusals, 5);
    _refusals += 1;
    final base = 1000 * pow(2, step).toInt();
    final jitter = (base * 0.5 * (Random().nextDouble() * 2 - 1)).round();
    final delay = Duration(milliseconds: min(30000, base + jitter));
    _retryTimer = Timer(delay, () {
      final socket = _socket;
      if (!_wanted || _paused || socket == null || socket.connected) return;
      if (status == RealtimeStatus.refused) return;
      socket.connect();
    });
  }

  static int? _statusOf(dynamic err) {
    if (err is Map) {
      final data = err['data'];
      if (data is Map) return int.tryParse(data['status']?.toString() ?? '');
    }
    return null;
  }

  void _teardown() {
    _retryTimer?.cancel();
    _retryTimer = null;
    final socket = _socket;
    _socket = null;
    if (socket != null) {
      socket.clearListeners();
      socket.offAny();
      socket.dispose();
    }
  }

  void _setStatus(RealtimeStatus next) {
    if (_status.value == next) return;
    _status.value = next;
    _statusCtrl.add(next);
  }

  void _ensureLifecycle() {
    if (_lifecycle != null) return;
    _lifecycle = AppLifecycleListener(
      onPause: _pause,
      onResume: _resume,
    );
  }

  /// How long the socket stays open after the app is backgrounded. Android
  /// pauses the app for the camera and the file / photo pickers too; a short
  /// trip there should not cost a reconnect.
  static const pauseGrace = Duration(seconds: 30);
  Timer? _pauseTimer;

  void _pause() {
    if (_paused) return;
    _paused = true;
    _armPauseTimer();
  }

  void _armPauseTimer() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(pauseGrace, () {
      _pauseTimer = null;
      if (!_paused || !_wanted) return;
      // A call is ringing or connected: stay open; holdOpen re-arms this.
      if (_holds.isNotEmpty) return;
      _teardown();
      _setStatus(RealtimeStatus.paused);
    });
  }

  void _resume() {
    if (!_paused) return;
    _paused = false;
    _pauseTimer?.cancel();
    _pauseTimer = null;
    _resumedCtrl.add(null);
    if (!_wanted) return;
    if (_socket != null && status != RealtimeStatus.refused) return;
    _refusals = 0;
    unawaited(connect());
  }
}

// ---------------------------------------------------------------------------
// Riverpod
// ---------------------------------------------------------------------------

final realtimeServiceProvider = Provider<RealtimeService>((ref) {
  return RealtimeService.instance;
});

/// The connection status, starting with the current one.
final realtimeStatusProvider = StreamProvider<RealtimeStatus>((ref) async* {
  final service = ref.watch(realtimeServiceProvider);
  yield service.status;
  yield* service.statusStream;
});
