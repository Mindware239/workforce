/// The call screen: full-screen over whatever page is open, because a call
/// can ring on any of them. Incoming shows answer / decline; outgoing shows
/// the ring and a cancel; a connected call shows the other side (their
/// video, or their initials) with this side's camera in a corner, and the
/// controls. Mirrors frontend/src/components/realtime/call-overlay.tsx.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/services/navigation_service.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/call/data/call_models.dart';
import 'package:workforce/features/call/providers/call_manager.dart';

const _callBackground = Color(0xFF0B1220);
const _danger = Color(0xFFD93025);

String initialsOf(String? name) {
  final words = (name ?? '?').trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2);
  final text = words.map((w) => w[0]).join().toUpperCase();
  return text.isEmpty ? '?' : text;
}

String formatCallDuration(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final sec = (s % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$sec' : '$m:$sec';
}

/// Wraps the app (MaterialApp.router's builder): the call screen sits above
/// the router's pages while a call is ringing, live or just ended.
class CallLayer extends ConsumerWidget {
  const CallLayer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(callManagerProvider.select((s) => s.phase));
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (phase != CallPhase.idle) const Positioned.fill(child: CallScreen()),
      ],
    );
  }
}

class CallScreen extends ConsumerStatefulWidget {
  const CallScreen({super.key});

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  final RTCVideoRenderer _local = RTCVideoRenderer();
  final RTCVideoRenderer _remote = RTCVideoRenderer();
  bool _renderersReady = false;
  Object? _localBound;
  Object? _remoteBound;
  Timer? _ticker;
  String? _error;
  bool _answering = false;

  /// The call screen sits above the router; the back button must not pop
  /// the page underneath it.
  ChildBackButtonDispatcher? _back;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    try {
      _back = NavigationService.router.backButtonDispatcher.createChildBackButtonDispatcher()
        ..addCallback(() async => true)
        ..takePriority();
    } catch (_) {
      // No router listening yet (never the case under the app's router).
      _back = null;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final phase = ref.read(callManagerProvider).phase;
      if (mounted && (phase == CallPhase.active || phase == CallPhase.reconnecting)) setState(() {});
    });
  }

  Future<void> _initRenderers() async {
    try {
      await _local.initialize();
      await _remote.initialize();
      if (!mounted) return;
      setState(() => _renderersReady = true);
    } catch (err) {
      debugPrint('[call] renderers: $err');
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    final back = _back;
    if (back != null) back.parent.forget(back);
    for (final renderer in [_local, _remote]) {
      try {
        if (_renderersReady) renderer.srcObject = null;
        renderer.dispose();
      } catch (_) {
        // Never initialised (the call ended before the renderer was ready).
      }
    }
    super.dispose();
  }

  void _bind(CallState s) {
    if (!_renderersReady) return;
    if (!identical(s.localStream, _localBound)) {
      _localBound = s.localStream;
      _local.srcObject = s.localStream is MediaStream ? s.localStream as MediaStream : null;
    }
    if (!identical(s.remoteStream, _remoteBound)) {
      _remoteBound = s.remoteStream;
      _remote.srcObject = s.remoteStream is MediaStream ? s.remoteStream as MediaStream : null;
    }
  }

  String _status(CallState s) {
    final video = s.media == CallMedia.video;
    switch (s.phase) {
      case CallPhase.incoming:
        return ref.tr(video ? 'call.incomingVideo' : 'call.incomingAudio');
      case CallPhase.outgoing:
        return ref.tr(s.calleeOnline ? 'call.ringing' : 'call.calling');
      case CallPhase.connecting:
        return ref.tr('call.connecting');
      case CallPhase.reconnecting:
        return ref.tr(s.peerAway ? 'call.peerReconnecting' : 'call.reconnecting');
      case CallPhase.active:
        final at = s.connectedAt;
        return at == null ? '' : formatCallDuration(DateTime.now().difference(at).inSeconds);
      case CallPhase.ended:
        final key = 'call.ended_${s.endReason ?? 'ended'}';
        var text = ref.tr(key);
        if (text == key) text = ref.tr('call.ended_ended');
        final d = s.durationSeconds;
        return d != null && d > 0 ? '$text · ${formatCallDuration(d)}' : text;
      case CallPhase.idle:
        return '';
    }
  }

  Future<void> _answer() async {
    if (_answering) return;
    setState(() {
      _answering = true;
      _error = null;
    });
    final message = await ref.read(callManagerProvider.notifier).accept();
    if (!mounted) return;
    setState(() {
      _answering = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(callManagerProvider);
    final calls = ref.read(callManagerProvider.notifier);
    _bind(s);

    final video = s.media == CallMedia.video;
    final inCall = s.phase == CallPhase.active || s.phase == CallPhase.reconnecting;
    final showRemoteVideo = _renderersReady && video && inCall && s.remoteCamOn && s.remoteHasVideo;
    final showLocalVideo = _renderersReady &&
        video &&
        s.camOn &&
        s.localStream != null &&
        s.phase != CallPhase.incoming &&
        s.phase != CallPhase.ended;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Material(
        color: _callBackground,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          label: ref.tr('call.dialogLabel').replaceAll('{name}', s.peer?.fullName ?? ''),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // the other side
              if (showRemoteVideo)
                RTCVideoView(_remote, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
              else
                Center(child: _Avatar(name: s.peer?.fullName, pulse: s.phase == CallPhase.incoming || s.phase == CallPhase.outgoing)),

              // header
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x99000000), Color(0x00000000)],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 24, 20, 40),
                  child: Column(
                    children: [
                      Text(
                        s.peer?.fullName ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _status(s),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(fontSize: 14, color: Colors.white.withValues(alpha: .85)),
                        ),
                      ),
                      if (s.phase == CallPhase.connecting || s.phase == CallPhase.reconnecting) ...[
                        const SizedBox(height: 10),
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.saffron),
                        ),
                      ],
                      if (inCall && (!s.remoteMicOn || (video && !s.remoteCamOn))) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            if (!s.remoteMicOn) _Chip(ref.tr('call.peerMuted'), Icons.mic_off_rounded),
                            if (video && !s.remoteCamOn) _Chip(ref.tr('call.peerCameraOff'), Icons.videocam_off_rounded),
                          ],
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.saffronTint,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _error!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.saffronText),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // this side's camera
              if (showLocalVideo)
                Positioned(
                  right: 16,
                  top: MediaQuery.paddingOf(context).top + 130,
                  width: 108,
                  height: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: DecoratedBox(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white24)),
                      child: RTCVideoView(
                        _local,
                        mirror: s.frontCamera,
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  ),
                ),

              // controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xB3000000), Color(0x00000000)],
                    ),
                  ),
                  padding: EdgeInsets.fromLTRB(16, 48, 16, MediaQuery.paddingOf(context).bottom + 36),
                  child: _controls(s, calls, video),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _controls(CallState s, CallManager calls, bool video) {
    switch (s.phase) {
      case CallPhase.incoming:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              label: ref.tr('call.decline'),
              icon: Icons.call_end_rounded,
              color: _danger,
              showLabel: true,
              onTap: calls.reject,
            ),
            _RoundButton(
              label: ref.tr('call.answer'),
              icon: video ? Icons.videocam_rounded : Icons.call_rounded,
              color: AppColors.indiaGreen,
              showLabel: true,
              busy: _answering,
              onTap: _answer,
            ),
          ],
        );
      case CallPhase.outgoing:
        return Center(
          child: _RoundButton(
            label: ref.tr('call.cancel'),
            icon: Icons.call_end_rounded,
            color: _danger,
            showLabel: true,
            onTap: calls.hangUp,
          ),
        );
      case CallPhase.connecting:
      case CallPhase.active:
      case CallPhase.reconnecting:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 18,
              runSpacing: 14,
              children: [
                _RoundButton(
                  label: ref.tr(s.micOn ? 'call.mute' : 'call.unmute'),
                  icon: s.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                  pressed: !s.micOn,
                  onTap: calls.toggleMic,
                ),
                if (video)
                  _RoundButton(
                    label: ref.tr(s.camOn ? 'call.cameraOff' : 'call.cameraOn'),
                    icon: s.camOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    pressed: !s.camOn,
                    onTap: calls.toggleCam,
                  ),
                if (video)
                  _RoundButton(
                    label: ref.tr('call.switchCamera'),
                    icon: Icons.cameraswitch_rounded,
                    onTap: s.camOn ? calls.switchCamera : null,
                  ),
                _RoundButton(
                  label: ref.tr(s.speakerOn ? 'call.speakerOff' : 'call.speakerOn'),
                  icon: s.speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
                  pressed: s.speakerOn,
                  onTap: calls.toggleSpeaker,
                ),
              ],
            ),
            const SizedBox(height: 22),
            _RoundButton(
              label: ref.tr('call.hangUp'),
              icon: Icons.call_end_rounded,
              color: _danger,
              size: 64,
              onTap: calls.hangUp,
            ),
          ],
        );
      case CallPhase.ended:
      case CallPhase.idle:
        return const SizedBox(height: 64);
    }
  }
}

class _Avatar extends StatefulWidget {
  const _Avatar({required this.name, required this.pulse});

  final String? name;
  final bool pulse;

  @override
  State<_Avatar> createState() => _AvatarState();
}

class _AvatarState extends State<_Avatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Avatar old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.pulse && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.scale(scale: 1 + _c.value * 0.06, child: child),
        child: Container(
          width: 120,
          height: 120,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.saffronDeep, AppColors.indiaGreen],
            ),
          ),
          child: Text(
            initialsOf(widget.name),
            style: GoogleFonts.inter(fontSize: 38, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text, this.icon);

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.pressed = false,
    this.showLabel = false,
    this.busy = false,
    this.size = 56,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool pressed;
  final bool showLabel;
  final bool busy;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fill = color ?? (pressed ? Colors.white : Colors.white.withValues(alpha: .16));
    final fg = color != null ? Colors.white : (pressed ? AppColors.navy : Colors.white);
    final enabled = onTap != null && !busy;
    return Semantics(
      button: true,
      label: label,
      toggled: color == null ? pressed : null,
      enabled: enabled,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Opacity(
            opacity: enabled || busy ? 1 : .45,
            child: Material(
              color: fill,
              shape: const CircleBorder(),
              elevation: 4,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: enabled ? onTap : null,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: busy
                      ? Padding(
                          padding: EdgeInsets.all(size * .3),
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: fg),
                        )
                      : Icon(icon, color: fg, size: size * .43),
                ),
              ),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(height: 8),
            Text(label, style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }
}
