/// Ring for an incoming call, ringback for an outgoing one — the web's two
/// tones (frontend/src/lib/realtime/tones.ts: 440 + 480 Hz), synthesised
/// into small WAV files in the temp folder and looped with just_audio, so
/// there is no audio asset to ship.
///
/// * Ring: 1.2 s every 2.5 s. On Android it plays with the ringtone usage
///   (USAGE_NOTIFICATION_RINGTONE), so it follows the ringer volume and is
///   silent when the phone is on silent / vibrate. Plus a vibration pulse
///   from [HapticFeedback] — the platform's haptic feedback: short pulses
///   that follow the system haptics setting, not a ringer vibration pattern
///   (no vibration package is in the app).
/// * Ringback: 0.9 s every 4 s, quietly, while an outgoing call rings.
///
/// (flutter_ringtone_player was tried for the system ringtone and dropped:
/// its Android module compiles against SDK 33 and fails this app's build.)
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

enum CallTone { none, ring, ringback }

class CallTones {
  CallTones._();

  static final CallTones instance = CallTones._();

  CallTone _current = CallTone.none;
  Timer? _vibration;
  AudioPlayer? _player;
  final Map<CallTone, File> _files = {};

  Future<void> play(CallTone tone) async {
    if (tone == _current) return;
    await stop();
    _current = tone;
    if (tone == CallTone.none) return;
    if (tone == CallTone.ring) {
      _pulse();
      _vibration = Timer.periodic(const Duration(milliseconds: 2500), (_) => _pulse());
    }
    try {
      final file = await _tone(tone);
      if (_current != tone) return;
      // The call owns the audio session (flutter_webrtc); these players only
      // make a sound and leave the session alone.
      final player = _player ??= AudioPlayer(
        handleInterruptions: false,
        handleAudioSessionActivation: false,
        androidApplyAudioAttributes: false,
      );
      await player.setAndroidAudioAttributes(tone == CallTone.ring
          ? const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.sonification,
              usage: AndroidAudioUsage.notificationRingtone,
            )
          : const AndroidAudioAttributes(
              contentType: AndroidAudioContentType.sonification,
              usage: AndroidAudioUsage.voiceCommunicationSignalling,
            ));
      await player.setFilePath(file.path);
      await player.setLoopMode(LoopMode.one);
      await player.setVolume(tone == CallTone.ring ? 1.0 : 0.5);
      if (_current != tone) return;
      unawaited(player.play().catchError((Object _) {}));
    } catch (err) {
      debugPrint('[call] tone $tone failed: $err');
    }
  }

  Future<void> stop() async {
    _current = CallTone.none;
    _vibration?.cancel();
    _vibration = null;
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void _pulse() {
    HapticFeedback.vibrate();
    Timer(const Duration(milliseconds: 350), HapticFeedback.vibrate);
    Timer(const Duration(milliseconds: 700), HapticFeedback.vibrate);
  }

  Future<File> _tone(CallTone tone) async {
    final cached = _files[tone];
    if (cached != null && cached.existsSync()) return cached;
    final ring = tone == CallTone.ring;
    final bytes = _wav(
      onSeconds: ring ? 1.2 : 0.9,
      periodSeconds: ring ? 2.5 : 4.0,
      amplitude: ring ? 0.7 : 0.5,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/call_${tone.name}.wav');
    await file.writeAsBytes(bytes, flush: true);
    return _files[tone] = file;
  }

  /// 16-bit mono PCM at 8 kHz: 440 + 480 Hz for [onSeconds], then silence
  /// to the end of [periodSeconds].
  static Uint8List _wav({required double onSeconds, required double periodSeconds, required double amplitude}) {
    const rate = 8000;
    final total = (rate * periodSeconds).round();
    final on = (rate * onSeconds).round();
    final samples = Int16List(total);
    final fade = rate * 0.03; // 30 ms in and out, so the tone does not click
    for (var i = 0; i < on; i++) {
      final t = i / rate;
      final edge = min(1.0, min(i, on - i) / fade);
      final v = (sin(2 * pi * 440 * t) + sin(2 * pi * 480 * t)) / 2 * edge * amplitude;
      samples[i] = (v * 32767).round();
    }
    final data = samples.buffer.asUint8List();
    final header = ByteData(44);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        header.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    header.setUint32(4, 36 + data.length, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little); // PCM
    header.setUint16(22, 1, Endian.little); // mono
    header.setUint32(24, rate, Endian.little);
    header.setUint32(28, rate * 2, Endian.little);
    header.setUint16(32, 2, Endian.little);
    header.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    header.setUint32(40, data.length, Endian.little);
    return Uint8List.fromList([...header.buffer.asUint8List(), ...data]);
  }
}
