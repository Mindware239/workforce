import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/task/presentation/task_ui.dart';
import 'package:workforce/features/task/providers/task_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  int selectedFilter = 0;

  String selectedAssignee = 'Assigned to me';

  /// Every state an employee can be in, as the web's filter strip offers
  /// them ('' = all).
  final List<String> filters = [
    '',
    'pending',
    'in_progress',
    'blocked',
    'submitted',
    'changes_requested',
    'completed',
  ];

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      _loadTasks();
    });
  }

  // ============================================================
  // SCOPE
  // ============================================================

  String _getScope() {
    switch (selectedAssignee) {
      case 'Assigned by me':
        return 'assigned';

      case 'All tasks':
        return 'team';

      case 'Assigned to me':
      default:
        return 'mine';
    }
  }

  // ============================================================
  // STATUS
  // ============================================================

  String? _getStatus() {
    final value = filters[selectedFilter];

    return value.isEmpty ? null : value;
  }

  // ============================================================
  // LOAD TASKS
  // ============================================================

  Future<void> _loadTasks() async {
    await ref
        .read(taskProvider.notifier)
        .loadTasks(scope: _getScope(), status: _getStatus());
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTasks,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeader(),

              const SizedBox(height: 16),

              if (taskState.status == TaskStatus.loading &&
                  taskState.tasks.isEmpty)
                const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (taskState.status == TaskStatus.error &&
                  taskState.tasks.isEmpty)
                _buildErrorState(taskState.message)
              else if (taskState.tasks.isEmpty)
                _buildEmptyState()
              else
                ...taskState.tasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _TaskCard(
                      task: task,
                      onAction: (action) => _cardAction(task, action),
                      onDetails: () => _openTaskDetails(task),
                    ),
                  ),
                ),

              if (taskState.status == TaskStatus.loading &&
                  taskState.tasks.isNotEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                ref.tr('tasks.title'),
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),
            ),
            IconButton(
              tooltip: ref.tr('taskx.historyTitle'),
              icon: const Icon(Icons.history, color: AppColors.saffronText),
              onPressed: () => context.push(AppRoutes.taskHistory),
            ),
            IconButton(
              tooltip: ref.tr('taskx.perfTitle'),
              icon: const Icon(Icons.insights, color: AppColors.saffronText),
              onPressed: () => context.push(AppRoutes.taskPerformance),
            ),
          ],
        ),

        const SizedBox(height: 8),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(filters.length, (index) {
              final selected = selectedFilter == index;

              return Padding(
                padding: EdgeInsets.only(
                  right: index == filters.length - 1 ? 0 : 8,
                ),
                child: GestureDetector(
                  onTap: () async {
                    if (selected) return;

                    setState(() {
                      selectedFilter = index;
                    });

                    await _loadTasks();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primaryFillColor
                          : Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      border: Border.all(
                        color: selected
                            ? AppColors.primaryFillColor
                            : AppColors.borderColor,
                      ),
                    ),
                    child: Text(
                      filters[index].isEmpty
                          ? ref.tr('tasks.all')
                          : taskStatusLabel(ref, filters[index]),
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: selected ? Colors.white : AppColors.mutedColor,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),

        const SizedBox(height: 12),

        PopupMenuButton<String>(
          surfaceTintColor: AppColors.backgroundColor,
          onSelected: (value) async {
            setState(() {
              selectedAssignee = value;
            });

            await _loadTasks();
          },
          offset: const Offset(0, 34),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          itemBuilder: (context) {
            return [
              PopupMenuItem(
                value: 'Assigned to me',
                child: Text(ref.tr('tasks.assignedToMe')),
              ),
              PopupMenuItem(
                value: 'Assigned by me',
                child: Text(ref.tr('tasks.assignedByMe')),
              ),
              PopupMenuItem(
                value: 'All tasks',
                child: Text(ref.tr('tasks.allTasks')),
              ),
            ];
          },
          child: Container(
            height: 29,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  {
                        'Assigned to me': ref.tr('tasks.assignedToMe'),
                        'Assigned by me': ref.tr('tasks.assignedByMe'),
                        'All tasks': ref.tr('tasks.allTasks'),
                      }[selectedAssignee] ??
                      selectedAssignee,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF4D4654),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 16,
                  color: Color(0xFF332D39),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The one-tap moves on a card (start, resume, pause, unblock). Moves that
  /// need more (submitting, marking stuck) open the full task instead.
  Future<void> _cardAction(Map<String, dynamic> task, String action) async {
    final taskId = int.tryParse(task['id']?.toString() ?? '');

    if (taskId == null) return;

    if (action == 'submit' || action == 'block') {
      await _openTaskDetails(task);
      return;
    }

    final success = await ref
        .read(taskProvider.notifier)
        .performAction(taskId: taskId, action: action);

    if (!mounted) return;

    final message = ref.read(taskProvider).message;

    showFeatureSnack(
      context,
      success
          ? (action == 'start'
                ? ref.tr('tasks.startedSuccessfully')
                : ref.tr('taskx.updated'))
          : message ?? ref.tr('taskx.couldNotUpdate'),
    );
  }

  Future<void> _openTaskDetails(Map<String, dynamic> task) async {
    final taskId = int.tryParse(task['id']?.toString() ?? '');

    if (taskId == null) return;

    await context.push(AppRoutes.taskDetailPath(taskId));

    if (!mounted) return;

    await _loadTasks();
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(
            Icons.task_alt_outlined,
            size: 42,
            color: Color(0xFFB7AFC0),
          ),
          const SizedBox(height: 10),
          Text(
            ref.tr('tasks.noTasks'),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF3D3742),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String? message) {
    return Container(
      margin: const EdgeInsets.only(top: 30),
      padding: const EdgeInsets.all(30),
      alignment: Alignment.center,
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 42, color: Color(0xFFB7AFC0)),
          const SizedBox(height: 10),
          Text(
            message ?? ref.tr('tasks.unableToLoadTasks'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3D3742),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _loadTasks,
            child: Text(ref.tr('common.retry')),
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final Map<String, dynamic> task;

  final ValueChanged<String> onAction;
  final VoidCallback onDetails;

  const _TaskCard({
    required this.task,
    required this.onAction,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = task['title']?.toString() ?? '';

    final description = task['description']?.toString() ?? '';

    final priority = task['priority']?.toString() ?? '';

    final status = task['status']?.toString() ?? '';

    final assignedToName = task['assignedToName']?.toString() ?? '';

    final assignedByName = task['assignedByName']?.toString() ?? '';

    final dueDate = task['dueDate']?.toString() ?? '';

    final voiceNotePath = task['voiceNotePath']?.toString();
    debugPrint('🎤 ASSIGN TASK AUDIO URL: $voiceNotePath');

    // At most two moves, as the web card offers: the obvious one primary.
    final actions = _cardActions(status);

    final progress = (num.tryParse(task['progressPercent']?.toString() ?? '') ?? 0)
        .toInt();

    final overdue = isTaskOverdue(task);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFB84BC8),
            ),
            child: Text(
              assignedByName.isNotEmpty ? assignedByName[0].toUpperCase() : 'T',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF29232D),
                        ),
                      ),
                    ),

                    if (priority.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      _PriorityBadge(
                        text: _formatPriority(priority, ref),
                        priorityKey: priority,
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    StatusChip(
                      label: taskStatusLabel(ref, status),
                      tone: taskStatusTone(status),
                    ),
                    if (overdue)
                      StatusChip(
                        label: ref.tr('taskx.late'),
                        tone: ChipTone.danger,
                      ),
                    if (progress > 0 && progress < 100)
                      StatusChip(
                        label: fill(ref.tr('taskx.progressValue'), {
                          'n': progress,
                        }),
                        tone: ChipTone.primary,
                      ),
                  ],
                ),

                if (voiceNotePath != null && voiceNotePath.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  TaskVoiceNotePlayer(audioUrl: voiceNotePath),
                ],

                if (description.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF665F6B),
                    ),
                  ),
                ],

                const SizedBox(height: 8),

                Text(
                  'Assigned to '
                  '${assignedToName.isNotEmpty ? assignedToName : 'you'}'
                  '${assignedByName.isNotEmpty ? ' • by $assignedByName' : ''}'
                  '${dueDate.isNotEmpty ? ' • due ${_formatDate(dueDate, ref)}' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF766E7A),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          Column(
            children: [
              for (final action in actions) ...[
                SizedBox(
                  height: 35,
                  child: action.primary
                      ? ElevatedButton(
                          onPressed: () => onAction(action.action),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryFillColor,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            ref.tr(action.labelKey),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : OutlinedButton(
                          onPressed: () => onAction(action.action),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.saffronText,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            ref.tr(action.labelKey),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
              ],

              _DetailsButton(onTap: onDetails),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityBadge extends StatelessWidget {
  final String text;
  final String priorityKey;

  const _PriorityBadge({required this.text, this.priorityKey = ''});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color textColor;

    switch (priorityKey.toLowerCase()) {
      case 'high':
        background = const Color(0xFFFFE9C8);
        textColor = const Color(0xFFB96900);
        break;

      case 'medium':
        background = AppColors.navyLight;
        textColor = AppColors.navy;
        break;

      case 'urgent':
        background = const Color(0xFFFFDCDC);
        textColor = const Color(0xFFC62828);
        break;

      case 'low':
        background = AppColors.indiaGreenLight;
        textColor = AppColors.successColor;
        break;

      default:
        background = const Color(0xFFEDE9F4);
        textColor = const Color(0xFF675E70);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}

class _DetailsButton extends ConsumerWidget {
  final VoidCallback onTap;

  const _DetailsButton({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 35,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Text(
          ref.tr('tasks.details'),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF403844),
          ),
        ),
      ),
    );
  }
}

class TaskVoiceNotePlayer extends StatefulWidget {
  final String audioUrl;

  const TaskVoiceNotePlayer({super.key, required this.audioUrl});

  @override
  State<TaskVoiceNotePlayer> createState() => _TaskVoiceNotePlayerState();
}

class _TaskVoiceNotePlayerState extends State<TaskVoiceNotePlayer> {
  static const String _uploadBaseUrl = 'https://workforce.orkuts.com/uploads/';

  late final AudioPlayer _player;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = false;

  String _resolvedAudioUrl = '';
  String _errorText = '';

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  String _resolveAudioUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    final normalized = trimmed.replaceFirst(RegExp(r'^/+'), '');
    return '$_uploadBaseUrl$normalized';
  }

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();
    _resolvedAudioUrl = _resolveAudioUrl(widget.audioUrl);

    debugPrint('🎵 ORIGINAL AUDIO PATH: ${widget.audioUrl}');
    debugPrint('🎵 RESOLVED AUDIO URL: $_resolvedAudioUrl');

    _positionSubscription = _player
        .createPositionStream(
          minPeriod: const Duration(milliseconds: 200),
          maxPeriod: const Duration(milliseconds: 200),
        )
        .listen((position) {
          if (!mounted) return;

          final duration = _player.duration ?? _duration;
          final safePosition = duration > Duration.zero && position > duration
              ? duration
              : position;

          setState(() {
            _position = safePosition;
          });
        });

    _durationSubscription = _player.durationStream.listen((duration) {
      if (!mounted) return;

      setState(() {
        _duration = duration ?? Duration.zero;
      });
    });

    _playerStateSubscription = _player.playerStateStream.listen((playerState) {
      if (!mounted) return;

      debugPrint(
        '🎵 playing=${playerState.playing}, '
        'state=${playerState.processingState}',
      );

      if (playerState.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _position = _duration;
        });
      } else {
        setState(() {
          _isPlaying = playerState.playing;
        });
      }
    });

    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
    final url = _resolveAudioUrl(widget.audioUrl);

    if (url.isEmpty) {
      debugPrint('❌ AUDIO URL IS EMPTY');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorText = 'Audio URL is empty';
      });
      return;
    }

    _resolvedAudioUrl = url;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorText = '';
      });
    }

    try {
      debugPrint('🎵 INITIALIZING AUDIO');
      debugPrint('🎵 Original path: ${widget.audioUrl}');
      debugPrint('🎵 Resolved URL: $url');

      await _player.stop();

      final uri = Uri.parse(url);

      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        throw Exception('Invalid resolved audio URL: $url');
      }

      final duration = await _player.setAudioSource(AudioSource.uri(uri));

      final finalDuration = duration ?? _player.duration ?? Duration.zero;

      debugPrint('✅ AUDIO LOADED SUCCESSFULLY');
      debugPrint('🎵 Duration: $finalDuration');
      debugPrint('🎵 Final URL: $url');

      if (!mounted) return;

      setState(() {
        _duration = finalDuration;
        _position = Duration.zero;
        _isLoading = false;
        _hasError = false;
        _errorText = '';
      });
    } catch (e, stackTrace) {
      debugPrint('❌ AUDIO INITIALIZATION FAILED');
      debugPrint('❌ Original path: ${widget.audioUrl}');
      debugPrint('❌ Resolved URL: $url');
      debugPrint('❌ ERROR: $e');
      debugPrint('❌ ERROR TYPE: ${e.runtimeType}');
      debugPrint('❌ STACK TRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasError = true;
        _isPlaying = false;
        _errorText = e.toString();
      });
    }
  }

  Future<void> _togglePlay() async {
    if (_isLoading) {
      debugPrint('⏳ Player is still loading...');
      return;
    }

    if (_hasError) {
      debugPrint('🔄 Player failed previously. Retrying...');
      await _initializeAudio();

      if (!mounted || _hasError) {
        debugPrint('❌ Audio still could not be initialized');
        return;
      }
    }

    try {
      if (_player.playing) {
        debugPrint('⏸ Pausing audio');
        await _player.pause();
        return;
      }

      if (_player.processingState == ProcessingState.completed) {
        debugPrint('🔁 Audio completed. Restarting from beginning');
        await _player.seek(Duration.zero);

        if (mounted) {
          setState(() {
            _position = Duration.zero;
          });
        }
      }

      debugPrint('▶️ Starting audio');
      debugPrint('🎵 Playing URL: $_resolvedAudioUrl');

      await _player.play();

      debugPrint('✅ Play command completed');
    } catch (e, stackTrace) {
      debugPrint('❌ PLAYBACK ERROR');
      debugPrint('❌ URL: $_resolvedAudioUrl');
      debugPrint('❌ ERROR: $e');
      debugPrint('❌ ERROR TYPE: ${e.runtimeType}');
      debugPrint('❌ STACK TRACE: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isPlaying = false;
        _hasError = true;
        _errorText = e.toString();
      });
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString();
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maxMilliseconds = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;

    final currentMilliseconds = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();

    return Tooltip(
      message: _hasError && _errorText.isNotEmpty
          ? _errorText
          : _resolvedAudioUrl,
      child: Container(
        width: 224,
        height: 35,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F4),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _togglePlay,
              child: SizedBox(
                width: 24,
                height: 30,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _hasError
                              ? Icons.refresh_rounded
                              : (_isPlaying ? Icons.pause : Icons.play_arrow),
                          size: 18,
                          color: _hasError ? Colors.redAccent : Colors.black,
                        ),
                ),
              ),
            ),

            const SizedBox(width: 8),

            Text(
              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFF3E3A40),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: SizedBox(
                height: 20,
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 3,
                    ),
                    overlayShape: const RoundSliderOverlayShape(
                      overlayRadius: 6,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  child: Slider(
                    min: 0,
                    max: maxMilliseconds,
                    value: currentMilliseconds.clamp(0, maxMilliseconds),
                    onChanged: _duration.inMilliseconds == 0 || _hasError
                        ? null
                        : (value) {
                            _player.seek(Duration(milliseconds: value.toInt()));
                          },
                  ),
                ),
              ),
            ),

            const SizedBox(width: 6),

            GestureDetector(
              onTap: _isLoading
                  ? null
                  : () async {
                      try {
                        await _player.setVolume(_player.volume > 0 ? 0 : 1);

                        if (mounted) {
                          setState(() {});
                        }
                      } catch (e) {
                        debugPrint('❌ Volume error: $e');
                      }
                    },
              child: Icon(
                _player.volume > 0
                    ? Icons.volume_up_outlined
                    : Icons.volume_off_outlined,
                size: 16,
                color: const Color(0xFF8A8A8A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// HELPERS
// ================================================================

String _formatPriority(String value, WidgetRef ref) {
  switch (value.toLowerCase()) {
    case 'high':
      return ref.tr('tasks.priorityHigh');
    case 'medium':
      return ref.tr('tasks.priorityMedium');
    case 'urgent':
      return ref.tr('tasks.priorityUrgent');
    case 'low':
      return ref.tr('tasks.priorityLow');
    default:
      return value.isEmpty ? '' : value[0].toUpperCase() + value.substring(1);
  }
}

String _formatDate(String value, WidgetRef ref) {
  try {
    final date = DateTime.parse(value);

    final months = [
      ref.tr('tasks.jan'),
      ref.tr('tasks.feb'),
      ref.tr('tasks.mar'),
      ref.tr('tasks.apr'),
      ref.tr('tasks.may'),
      ref.tr('tasks.jun'),
      ref.tr('tasks.jul'),
      ref.tr('tasks.aug'),
      ref.tr('tasks.sep'),
      ref.tr('tasks.oct'),
      ref.tr('tasks.nov'),
      ref.tr('tasks.dec'),
    ];

    return '${date.day} ${months[date.month - 1]}';
  } catch (_) {
    return value;
  }
}

/// What a card offers for each status (web: task-status.ts nextActions).
/// submit and block need a note/reason, so they open the full task.
List<({String action, String labelKey, bool primary})> _cardActions(
  String status,
) {
  switch (status) {
    case 'pending':
    case 'accepted':
      return const [
        (action: 'start', labelKey: 'tasks.start', primary: true),
        (action: 'block', labelKey: 'taskx.markBlocked', primary: false),
      ];
    case 'in_progress':
      return const [
        (action: 'submit', labelKey: 'taskx.submitShort', primary: true),
        (action: 'pause', labelKey: 'taskx.pause', primary: false),
      ];
    case 'paused':
      return const [
        (action: 'start', labelKey: 'taskx.resume', primary: true),
        (action: 'submit', labelKey: 'taskx.submitShort', primary: false),
      ];
    case 'blocked':
      return const [
        (action: 'unblock', labelKey: 'taskx.resume', primary: true),
      ];
    case 'changes_requested':
      return const [
        (action: 'start', labelKey: 'taskx.startAgain', primary: true),
        (action: 'submit', labelKey: 'taskx.submitShort', primary: false),
      ];
    default:
      return const [];
  }
}
