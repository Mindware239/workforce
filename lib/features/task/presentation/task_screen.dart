import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/task/providers/task_provider.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  int selectedFilter = 0;

  String selectedAssignee = 'Assigned to me';

  final List<String> filters = ['All', 'To Do', 'In progress', 'Completed'];

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
    switch (selectedFilter) {
      case 1:
        return 'pending';

      case 2:
        return 'in_progress';

      case 3:
        return 'completed';

      default:
        return null;
    }
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
                      onStart: () => _startTask(task),
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
        Text(
          'My Tasks',
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
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
                      filters[index],
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
            return const [
              PopupMenuItem(
                value: 'Assigned to me',
                child: Text('Assigned to me'),
              ),
              PopupMenuItem(
                value: 'Assigned by me',
                child: Text('Assigned by me'),
              ),
              PopupMenuItem(value: 'All tasks', child: Text('All tasks')),
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

  Future<void> _startTask(
  Map<String, dynamic> task,
) async {
  final taskId =
      int.tryParse(task['id']?.toString() ?? '');

  if (taskId == null) return;

  final success = await ref
      .read(taskProvider.notifier)
      .updateTaskStatus(
        taskId: taskId,
        status: 'in_progress',
      );

  if (!mounted) return;

  final message =
      ref.read(taskProvider).message;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        success
            ? 'Task started successfully'
            : message ?? 'Unable to start task.',
      ),
    ),
  );
}
  Future<void> _openTaskDetails(Map<String, dynamic> task) async {
    final taskId = int.tryParse(task['id']?.toString() ?? '');

    if (taskId == null) {
      return;
    }

    final notifier = ref.read(taskProvider.notifier);

    final success = await notifier.fetchTask(taskId);

    if (!success) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.read(taskProvider).message ?? 'Unable to load task.',
          ),
        ),
      );

      return;
    }

    await notifier.fetchComments(taskId);

    if (!mounted) return;

    _showTaskDetails();
  }

  void _showTaskDetails() {
    final state = ref.read(taskProvider);
    final task = state.selectedTask;

    if (task == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _TaskDetailsSheet();
      },
    );
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
            'No tasks found',
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
            message ?? 'Unable to load tasks.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF3D3742),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: _loadTasks, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final Map<String, dynamic> task;

  final VoidCallback onStart;
  final VoidCallback onDetails;

  const _TaskCard({
    required this.task,
    required this.onStart,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final title = task['title']?.toString() ?? '';

    final description = task['description']?.toString() ?? '';

    final priority = task['priority']?.toString() ?? '';

    final status = task['status']?.toString() ?? '';

    final assignedToName = task['assignedToName']?.toString() ?? '';

    final assignedByName = task['assignedByName']?.toString() ?? '';

    final dueDate = task['dueDate']?.toString() ?? '';

    final voiceNotePath = task['voiceNotePath']?.toString();

    final isCompleted = status == 'completed';

    final isPending = status == 'pending';

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
                      _PriorityBadge(text: _formatPriority(priority)),
                    ],
                  ],
                ),

                const SizedBox(height: 8),

                _StatusBadge(
                  text: _formatStatus(status),
                  completed: isCompleted,
                ),

                if (voiceNotePath != null && voiceNotePath.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _AudioPlayer(audioUrl: voiceNotePath),
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
                  '${dueDate.isNotEmpty ? ' • due ${_formatDate(dueDate)}' : ''}',
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
              if (isPending)
                SizedBox(
                  height: 35,
                  child: ElevatedButton(
                    onPressed: onStart,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6645F5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Start',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),

              if (isPending) const SizedBox(height: 8),

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

  const _PriorityBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color textColor;

    switch (text.toLowerCase()) {
      case 'high':
        background = const Color(0xFFFFE9C8);
        textColor = const Color(0xFFB96900);
        break;

      case 'medium':
        background = const Color(0xFFDDEBFF);
        textColor = const Color(0xFF2765B5);
        break;

      case 'urgent':
        background = const Color(0xFFFFDCDC);
        textColor = const Color(0xFFC62828);
        break;

      case 'low':
        background = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF39843C);
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

class _StatusBadge extends StatelessWidget {
  final String text;
  final bool completed;

  const _StatusBadge({required this.text, required this.completed});

  @override
  Widget build(BuildContext context) {
    Color background;
    Color textColor;

    if (completed) {
      background = const Color(0xFFD9F5E9);
      textColor = const Color(0xFF15915C);
    } else if (text.toLowerCase() == 'in progress') {
      background = const Color(0xFFE8D8FF);
      textColor = AppColors.primaryFillColor;
    } else if (text.toLowerCase() == 'cancelled') {
      background = const Color(0xFFFFE1E1);
      textColor = const Color(0xFFC62828);
    } else {
      background = const Color(0xFFECE9EE);
      textColor = const Color(0xFF716A76);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
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

class _DetailsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DetailsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
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
          'Details',
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

class _AudioPlayer extends StatefulWidget {
  final String audioUrl;

  const _AudioPlayer({required this.audioUrl});

  @override
  State<_AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<_AudioPlayer> {
  late final AudioPlayer _player;

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = false;

  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();

    _player = AudioPlayer();

    _positionSubscription = _player.positionStream.listen((position) {
      if (!mounted) return;

      setState(() {
        _position = position;
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

      setState(() {
        _isPlaying = playerState.playing;
      });
    });

    _initializeAudio();
  }

  Future<void> _initializeAudio() async {
  try {


    final duration = await _player.setUrl(
      widget.audioUrl,
    );

  

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hasError = false;
    });
  } catch (e, stackTrace) {
    

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }
}
  Future<void> _togglePlay() async {
  

    if (_isLoading || _hasError) {
      debugPrint('⚠️ Player is not ready');
      return;
    }

    try {
      if (_player.playing) {
        debugPrint('⏸ Pausing audio');

        await _player.pause();
      } else {
        if (_player.processingState == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }

        debugPrint('▶️ Starting audio');

        await _player.play();

        debugPrint('✅ Play command completed');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ PLAYBACK ERROR');
      debugPrint('$e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _hasError = true;
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
    final maxSeconds = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;

    final currentSeconds = _position.inMilliseconds
        .clamp(0, _duration.inMilliseconds)
        .toDouble();

    return Container(
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
                child: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 18,
                  color: _isLoading || _hasError
                      ? const Color(0xFFAAAAAA)
                      : Colors.black,
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          Text(
            '${_formatDuration(_position)} / '
            '${_formatDuration(_duration)}',
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
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
                  padding: EdgeInsets.zero,
                ),
                child: Slider(
                  min: 0,
                  max: maxSeconds,
                  value: currentSeconds.clamp(0, maxSeconds),
                  onChanged: _duration.inMilliseconds == 0
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
            onTap: () async {
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
    );
  }
}

class _TaskDetailsSheet extends ConsumerStatefulWidget {
  const _TaskDetailsSheet();

  @override
  ConsumerState<_TaskDetailsSheet> createState() => _TaskDetailsSheetState();
}

class _TaskDetailsSheetState extends ConsumerState<_TaskDetailsSheet> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(taskProvider);
    final task = state.selectedTask;

    if (task == null) {
      return const SizedBox.shrink();
    }

    final title = task['title']?.toString() ?? 'Task';
    final description = task['description']?.toString() ?? '';
    final priority = task['priority']?.toString() ?? '';
    final status = task['status']?.toString() ?? '';
    final dueDate = task['dueDate']?.toString() ?? '';
    final assignedTo = task['assignedToName']?.toString() ?? '';
    final assignedBy = task['assignedByName']?.toString() ?? '';

    final taskId = int.tryParse(task['id']?.toString() ?? '');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.65,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // HEADER
            // =====================================================

            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor,
                      ),
                    ),
                  ),

                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Color(0xFF77707A),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFFE9E5EA)),

            // =====================================================
            // CONTENT
            // =====================================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =================================================
                    // BADGES
                    // =================================================

                    Row(
                      children: [
                        _PriorityBadge(text: _formatPriority(priority)),

                        const SizedBox(width: 8),

                        _StatusBadge(
                          text: _formatStatus(status),
                          completed: status == 'completed',
                        ),

                        const SizedBox(width: 8),

                        if (dueDate.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1EDF2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Due ${_formatDate(dueDate)}',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF5E5662),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // =================================================
                    // DESCRIPTION
                    // =================================================
                    if (description.isNotEmpty) ...[
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.5,
                          color: AppColors.mutedColor,
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],

                    // =================================================
                    // ASSIGNMENT
                    // =================================================
                    if (assignedTo.isNotEmpty || assignedBy.isNotEmpty) ...[
                      Text(
                        'For ${assignedTo.isEmpty ? '-' : assignedTo}'
                        '${assignedBy.isNotEmpty ? ' · assigned by $assignedBy' : ''}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedColor,
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],

                    // =================================================
                    // STATUS
                    // =================================================
                    Text(
                      'Status',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      height: 45,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value:
                              [
                                'pending',
                                'in_progress',
                                'completed',
                                'cancelled',
                              ].contains(status)
                              ? status
                              : null,
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 18),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textColor,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'pending',
                              child: Text('To Do'),
                            ),
                            DropdownMenuItem(
                              value: 'in_progress',
                              child: Text('In progress'),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Completed'),
                            ),
                            DropdownMenuItem(
                              value: 'cancelled',
                              child: Text('Cancelled'),
                            ),
                          ],
                          onChanged: taskId == null
                              ? null
                              : (newStatus) async {
                                  if (newStatus == null ||
                                      newStatus == status) {
                                    return;
                                  }

                                  await ref
                                      .read(taskProvider.notifier)
                                      .updateTaskStatus(
                                        taskId: taskId,
                                        status: newStatus,
                                      );
                                },
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // =================================================
                    // NOTES
                    // =================================================
                    Row(
                      children: [
                        Text(
                          'Notes',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textColor,
                          ),
                        ),

                        const Spacer(),

                        Text(
                          '${state.comments.length}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppColors.mutedColor,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // =================================================
                    // COMMENTS - REAL TIME
                    // =================================================
                    if (state.isLoadingComments)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (state.comments.isEmpty)
                      Text(
                        'No notes yet.',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedColor,
                        ),
                      )
                    else
                      ...state.comments.map((comment) {
                        final userName =
                            comment['userName']?.toString() ?? 'User';

                        final body = comment['body']?.toString() ?? '';

                        final createdAt =
                            comment['createdAt']?.toString() ?? '';

                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textColor,
                                ),
                              ),

                              const SizedBox(height: 3),

                              Text(
                                body,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  height: 1.4,
                                  color: AppColors.mutedColor,
                                ),
                              ),

                              if (createdAt.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _formatDateTime(createdAt),
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: const Color(0xFF8B838F),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 16),

                    // =================================================
                    // ADD NOTE
                    // =================================================
                    if (taskId != null) _AddTaskComment(taskId: taskId),

                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTaskComment extends ConsumerStatefulWidget {
  final int? taskId;

  const _AddTaskComment({required this.taskId});

  @override
  ConsumerState<_AddTaskComment> createState() => _AddTaskCommentState();
}

class _AddTaskCommentState extends ConsumerState<_AddTaskComment> {
  final TextEditingController _controller = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _postComment() async {
    final body = _controller.text.trim();

    if (body.isEmpty || widget.taskId == null || _isPosting) {
      return;
    }

    setState(() {
      _isPosting = true;
    });

    final success = await ref
        .read(taskProvider.notifier)
        .addComment(taskId: widget.taskId!, body: body);

    if (!mounted) return;

    setState(() {
      _isPosting = false;
    });

    if (success) {
      _controller.clear();
    } else {
      final message = ref.read(taskProvider).message;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message ?? 'Unable to add note.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _postComment(),
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textColor,
              ),
              decoration: InputDecoration(
                hintText: 'Add a note...',
                hintStyle: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF9A929D),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.primaryFillColor,
                    width: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          child: ElevatedButton(
            onPressed: _isPosting ? null : _postComment,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryFillColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isPosting
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  )
                : Text(
                    'Post',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

// ================================================================
// HELPERS
// ================================================================

String _formatPriority(String value) {
  if (value.isEmpty) return '';

  return value[0].toUpperCase() + value.substring(1);
}

String _formatStatus(String value) {
  switch (value) {
    case 'in_progress':
      return 'In progress';

    case 'completed':
      return 'Completed';

    case 'cancelled':
      return 'Cancelled';

    case 'pending':
    default:
      return 'To Do';
  }
}

String _formatDate(String value) {
  try {
    final date = DateTime.parse(value);

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} ${months[date.month - 1]}';
  } catch (_) {
    return value;
  }
}

String _formatDateTime(String value) {
  try {
    final date = DateTime.parse(value).toLocal();
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
        ? date.hour - 12
        : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '${_formatDate(value)} at $hour:$minute $period';
  } catch (_) {
    return value;
  }
}
