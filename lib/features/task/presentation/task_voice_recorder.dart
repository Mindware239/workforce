import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/task/data/task_repository.dart';

/// Result returned when user records a voice note proof.
typedef VoiceProofResult = ({
  String path,
  String name,
  String? caption,
});

/// Dialog to record an audio note as task evidence / proof of work.
class TaskVoiceRecorderDialog extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;

  const TaskVoiceRecorderDialog({
    super.key,
    this.title = 'Record Voice Proof',
    this.subtitle = 'Explain what was completed or record work notes.',
  });

  static Future<VoiceProofResult?> show(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) {
    return showDialog<VoiceProofResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TaskVoiceRecorderDialog(
        title: title ?? 'Record Voice Proof',
        subtitle: subtitle ?? 'Explain what was completed or record work notes.',
      ),
    );
  }

  @override
  ConsumerState<TaskVoiceRecorderDialog> createState() =>
      _TaskVoiceRecorderDialogState();
}

class _TaskVoiceRecorderDialogState
    extends ConsumerState<TaskVoiceRecorderDialog> {
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  final TextEditingController _captionController = TextEditingController();

  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _recordedPath;

  bool _isPlaying = false;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  String? _error;

  @override
  void initState() {
    super.initState();

    _posSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _playbackPosition = p);
    });

    _durSub = _player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _playbackDuration = d);
    });

    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _isPlaying = false;
            _playbackPosition = Duration.zero;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _recorder.dispose();
    _player.dispose();
    _captionController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        setState(() => _error = 'Microphone permission denied.');
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final path =
          '${tempDir.path}/task_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordedPath = null;
        _recordDuration = Duration.zero;
        _error = null;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording) return;
        setState(() => _recordDuration += const Duration(seconds: 1));
        if (_recordDuration.inSeconds >= 120) {
          _stopRecording();
        }
      });
    } catch (e) {
      setState(() => _error = 'Could not start recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    try {
      final path = await _recorder.stop();
      _recordTimer?.cancel();
      _recordTimer = null;

      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });

      if (path != null && File(path).existsSync()) {
        await _player.setFilePath(path);
      }
    } catch (e) {
      setState(() => _error = 'Could not stop recording: $e');
    }
  }

  Future<void> _togglePlayback() async {
    if (_recordedPath == null) return;
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_player.processingState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  void _discardRecording() {
    _player.stop();
    setState(() {
      _recordedPath = null;
      _recordDuration = Duration.zero;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
      _isPlaying = false;
    });
  }

  void _confirm() {
    if (_recordedPath == null) return;
    final name = 'voice_proof_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final caption = _captionController.text.trim();
    Navigator.of(context).pop<VoiceProofResult>((
      path: _recordedPath!,
      name: name,
      caption: caption.isNotEmpty ? caption : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final hasRecording = _recordedPath != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.saffronTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.mic, color: AppColors.saffronText, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.title,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.red),
                ),
              ),
              const SizedBox(height: 12),
            ],

            if (!hasRecording) ...[
              // RECORDING STATE
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isRecording
                        ? Colors.redAccent
                        : AppColors.primaryFillColor,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording
                                ? Colors.redAccent
                                : AppColors.primaryFillColor)
                            .withValues(alpha: 0.35),
                        blurRadius: _isRecording ? 18 : 8,
                        spreadRadius: _isRecording ? 4 : 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRecording
                    ? 'Recording: ${_formatDuration(_recordDuration)} (Tap to stop)'
                    : 'Tap microphone to start recording',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight:
                      _isRecording ? FontWeight.w600 : FontWeight.normal,
                  color: _isRecording ? Colors.redAccent : AppColors.textColor,
                ),
              ),
            ] else ...[
              // PREVIEW & PLAYBACK STATE
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _togglePlayback,
                          icon: Icon(
                            _isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: AppColors.primaryFillColor,
                            size: 36,
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Voice Proof Recorded',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${_formatDuration(_playbackPosition)} / ${_formatDuration(_playbackDuration > Duration.zero ? _playbackDuration : _recordDuration)}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.mutedColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete recording',
                          onPressed: _discardRecording,
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _captionController,
                maxLength: 200,
                decoration: featureInputDecoration(
                  'Optional note / caption for this voice recording',
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ref.tr('common.cancel')),
        ),
        if (hasRecording)
          ElevatedButton.icon(
            onPressed: _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryFillColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Use Voice Proof'),
          ),
      ],
    );
  }
}

/// Dialog to listen to an existing audio attachment on a task.
class TaskAudioPlayerDialog extends ConsumerStatefulWidget {
  final int taskId;
  final int attachmentId;
  final String fileName;
  final String? caption;

  const TaskAudioPlayerDialog({
    super.key,
    required this.taskId,
    required this.attachmentId,
    required this.fileName,
    this.caption,
  });

  static Future<void> show(
    BuildContext context, {
    required int taskId,
    required int attachmentId,
    required String fileName,
    String? caption,
  }) {
    return showDialog(
      context: context,
      builder: (_) => TaskAudioPlayerDialog(
        taskId: taskId,
        attachmentId: attachmentId,
        fileName: fileName,
        caption: caption,
      ),
    );
  }

  @override
  ConsumerState<TaskAudioPlayerDialog> createState() =>
      _TaskAudioPlayerDialogState();
}

class _TaskAudioPlayerDialogState
    extends ConsumerState<TaskAudioPlayerDialog> {
  final AudioPlayer _player = AudioPlayer();
  bool _loading = true;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _error;

  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      final repo = ref.read(taskRepositoryProvider);
      final path = await repo.cacheAttachmentLocally(
        widget.taskId,
        widget.attachmentId,
        widget.fileName,
      );

      if (!mounted) return;

      await _player.setFilePath(path);

      _posSub = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });

      _durSub = _player.durationStream.listen((d) {
        if (mounted && d != null) setState(() => _duration = d);
      });

      _stateSub = _player.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing;
            if (state.processingState == ProcessingState.completed) {
              _isPlaying = false;
              _position = Duration.zero;
            }
          });
        }
      });

      setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to play recording: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.saffronTint,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.graphic_eq_rounded,
              color: AppColors.saffronText,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.caption != null && widget.caption!.isNotEmpty) ...[
            Text(
              widget.caption!,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (_error != null)
            Text(
              _error!,
              style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
            )
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () {
                    if (_isPlaying) {
                      _player.pause();
                    } else {
                      if (_player.processingState == ProcessingState.completed) {
                        _player.seek(Duration.zero);
                      }
                      _player.play();
                    }
                  },
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: AppColors.primaryFillColor,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_format(_position)} / ${_format(_duration)}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(ref.tr('common.close')),
        ),
      ],
    );
  }
}
