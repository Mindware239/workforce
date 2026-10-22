import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/leave/providers/leave_provider.dart';

class LeaveRequestScreen extends ConsumerStatefulWidget {
  const LeaveRequestScreen({super.key});

  @override
  ConsumerState<LeaveRequestScreen> createState() => _LeaveRequestScreenState();
}

class _LeaveRequestScreenState extends ConsumerState<LeaveRequestScreen> {
  // ============================================================
  // FORM VALUES
  // ============================================================

  String leaveType = 'Casual Leave';
  String leaveDuration = 'Full Day';

  DateTime? startDate;
  DateTime? endDate;

  TimeOfDay? startTime;
  TimeOfDay? endTime;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController startDateController = TextEditingController();

  final TextEditingController endDateController = TextEditingController();

  final TextEditingController startTimeController = TextEditingController();

  final TextEditingController endTimeController = TextEditingController();

  final TextEditingController reasonController = TextEditingController();

  /// FIRST | SECOND, for a half day.
  String halfDaySession = 'FIRST';

  /// Set while answering a request that was sent back for changes.
  int? editingId;

  // Optional recorded reason (voice note), as on the web.
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _voiceNotePath;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _formKey = GlobalKey();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final notifier = ref.read(leaveProvider.notifier);

      notifier.getMyLeaveRequests();
      notifier.getLeaveBalances();
    });
  }

  // ============================================================
  // LEAVE CATEGORY
  // ============================================================

  String get leaveCategory {
    switch (leaveType) {
      case 'Sick Leave':
        return 'sick';

      case 'Earned Leave':
        return 'earned';

      case 'Unpaid Leave':
        return 'unpaid';

      case 'Comp Off':
        return 'comp_off';

      case 'Casual Leave':
      default:
        return 'casual';
    }
  }

  static String _leaveTypeForCategory(String? category) {
    switch (category) {
      case 'sick':
        return 'Sick Leave';
      case 'earned':
        return 'Earned Leave';
      case 'unpaid':
        return 'Unpaid Leave';
      case 'comp_off':
        return 'Comp Off';
      default:
        return 'Casual Leave';
    }
  }

  // ============================================================
  // API LEAVE TYPE
  // ============================================================

  /// full_day | half_day (one date, a session) | partial (a few hours:
  /// "permission").
  String get apiLeaveType {
    if (leaveDuration == 'Half Day') {
      return 'half_day';
    }

    if (leaveDuration == 'Permission') {
      return 'partial';
    }

    return 'full_day';
  }

  bool get _usesTimes => leaveDuration == 'Permission';

  // ============================================================
  // NUMBER OF DAYS
  // ============================================================

  double get numberOfDays {
    if (leaveDuration == 'Half Day') {
      return 0.5;
    }

    if (leaveDuration == 'Permission') {
      return 0;
    }

    if (startDate == null) {
      return 0;
    }

    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);

    final last = endDate ?? startDate!;

    final end = DateTime(last.year, last.month, last.day);

    if (end.isBefore(start)) {
      return 0;
    }

    return end.difference(start).inDays + 1;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    startDateController.dispose();
    endDateController.dispose();
    startTimeController.dispose();
    endTimeController.dispose();
    reasonController.dispose();
    _recordingTimer?.cancel();
    _recorder.dispose();
    _previewPlayer.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  // ============================================================
  // VOICE NOTE
  // ============================================================

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      if (!await _recorder.hasPermission()) {
        _showMessage(ref.tr('leavex.micPermission'));
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/leave_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _previewPlayer.stop();

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: path,
      );

      if (!mounted) return;

      setState(() {
        _isRecording = true;
        _voiceNotePath = null;
        _recordingDuration = Duration.zero;
      });

      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || !_isRecording) return;

        setState(() => _recordingDuration += const Duration(seconds: 1));

        // The upload limit is generous, but a reason is not a podcast.
        if (_recordingDuration.inSeconds >= 120) _stopRecording();
      });
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _recorder.stop();

      _recordingTimer?.cancel();
      _recordingTimer = null;

      if (!mounted) return;

      setState(() {
        _isRecording = false;
        _voiceNotePath =
            (path != null && path.isNotEmpty && File(path).existsSync())
            ? path
            : null;
      });
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _playPreview() async {
    final path = _voiceNotePath;

    if (path == null) return;

    try {
      if (_previewPlayer.playing) {
        await _previewPlayer.stop();
        if (mounted) setState(() {});
        return;
      }

      await _previewPlayer.setFilePath(path);
      if (mounted) setState(() {});
      await _previewPlayer.play();
      if (mounted) setState(() {});
    } catch (_) {
      _showMessage(ref.tr('leavex.couldNotPlay'));
    }
  }

  void _clearVoiceNote() {
    _previewPlayer.stop();

    setState(() => _voiceNotePath = null);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return '$minutes:$seconds';
  }

  Widget _buildVoiceNote(bool isLoading) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: isLoading ? null : _toggleRecording,
          style: OutlinedButton.styleFrom(
            foregroundColor: _isRecording
                ? const Color(0xFFB71C1C)
                : AppColors.saffronText,
            side: BorderSide(
              color: _isRecording
                  ? const Color(0xFFB71C1C)
                  : AppColors.borderColor,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: Icon(
            _isRecording ? Icons.stop_rounded : Icons.mic_none_rounded,
            size: 18,
          ),
          label: Text(
            _isRecording
                ? fill(ref.tr('leavex.stopRecording'), {
                    'time': _formatDuration(_recordingDuration),
                  })
                : ref.tr('leavex.recordReason'),
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        if (_voiceNotePath != null) ...[
          IconButton(
            tooltip: ref.tr('leavex.playVoiceNote'),
            onPressed: _playPreview,
            icon: Icon(
              _previewPlayer.playing
                  ? Icons.stop_circle_outlined
                  : Icons.play_circle_outline_rounded,
              color: AppColors.primaryFillColor,
            ),
          ),
          Text(
            ref.tr('leavex.voiceNoteAttached'),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          IconButton(
            tooltip: ref.tr('common.delete'),
            onPressed: isLoading ? null : _clearVoiceNote,
            icon: const Icon(
              Icons.close_rounded,
              size: 18,
              color: AppColors.mutedColor,
            ),
          ),
        ],
      ],
    );
  }

  // ============================================================
  // SENT BACK FOR CHANGES
  // ============================================================

  /// Loads a sent-back request into the form so it can be answered in place.
  void _startEditing(Map<String, dynamic> leave) {
    final start = DateTime.tryParse(leave['start_date']?.toString() ?? '');
    final end = DateTime.tryParse(leave['end_date']?.toString() ?? '');
    final type = leave['leave_type']?.toString();

    TimeOfDay? parseTime(dynamic value) {
      final parts = (value?.toString() ?? '').split(':');

      if (parts.length < 2) return null;

      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);

      return h == null || m == null ? null : TimeOfDay(hour: h, minute: m);
    }

    setState(() {
      editingId = toInt(leave['id']);
      leaveType = _leaveTypeForCategory(leave['leave_category']?.toString());
      leaveDuration = type == 'half_day'
          ? 'Half Day'
          : type == 'partial'
          ? 'Permission'
          : 'Full Day';
      halfDaySession = leave['half_day_session']?.toString() == 'SECOND'
          ? 'SECOND'
          : 'FIRST';

      startDate = start == null ? null : DateTime(start.year, start.month, start.day);
      endDate = end == null ? null : DateTime(end.year, end.month, end.day);
      startDateController.text =
          startDate == null ? '' : _formatDisplayDate(startDate!);
      endDateController.text =
          endDate == null ? '' : _formatDisplayDate(endDate!);

      startTime = parseTime(leave['start_time']);
      endTime = parseTime(leave['end_time']);
      startTimeController.text =
          startTime == null ? '' : startTime!.format(context);
      endTimeController.text = endTime == null ? '' : endTime!.format(context);

      reasonController.text = leave['reason']?.toString() ?? '';
      _voiceNotePath = null;
    });

    final formContext = _formKey.currentContext;

    if (formContext != null) {
      Scrollable.ensureVisible(
        formContext,
        duration: const Duration(milliseconds: 350),
      );
    }
  }

  Widget _buildChangesRequested(List<Map<String, dynamic>> requests) {
    final sentBack = requests
        .where((r) => r['status']?.toString() == 'changes_requested')
        .toList();

    if (sentBack.isEmpty) return const SizedBox.shrink();

    return Column(
      children: sentBack.map((leave) {
        final remarks = leave['admin_remarks']?.toString().trim() ?? '';
        final id = toInt(leave['id']);

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.saffronTint,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.saffronLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: AppColors.saffronText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${ref.tr('leavex.changesNeeded')} · ${_buildLeaveTitle(leave)}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.saffronText,
                      ),
                    ),
                  ),
                ],
              ),
              if (remarks.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  remarks,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: AppColors.textColor,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: () => _startEditing(leave),
                    child: Text(ref.tr('leavex.updateRequest')),
                  ),
                  if (id != null)
                    OutlinedButton(
                      onPressed: () => _openDetail(id),
                      child: Text(ref.tr('leavex.viewDetails')),
                    ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openDetail(int id) async {
    await context.push(AppRoutes.leaveDetailPath(id));

    if (!mounted) return;

    ref.read(leaveProvider.notifier).loadLeaveData();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final leaveState = ref.watch(leaveProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.appBarColor,
        surfaceTintColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        bottom: const TricolourStrip(),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            final notifier = ref.read(leaveProvider.notifier);

            await Future.wait([
              notifier.getMyLeaveRequests(),
              notifier.getLeaveBalances(),
            ]);
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                const SizedBox(height: 16),

                // A request sent back is the one thing here that needs doing.
                _buildChangesRequested(leaveState.requests),

                _buildBalanceCards(leaveState.balances),

                const SizedBox(height: 16),

                KeyedSubtree(
                  key: _formKey,
                  child: _buildNewRequest(leaveState.isLoading),
                ),

                const SizedBox(height: 16),

                _buildRecentRequests(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.tr('leave.title'),
          style: GoogleFonts.inter(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          ref.tr('leave.subtitle'),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
        ),
      ],
    );
  }

  // ============================================================
  // BALANCE CARDS
  // ============================================================

  Widget _buildBalanceCards(List<Map<String, dynamic>> balances) {
    Map<String, dynamic>? balanceOf(String category) {
      for (final balance in balances) {
        if (balance['category']?.toString() == category) return balance;
      }

      return null;
    }

    String trimNum(dynamic value) {
      final n = toNum(value);

      if (n == null) return '0';

      return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
    }

    // A null remaining is an untracked entitlement: unlimited.
    Widget card(String category, String title, IconData icon, Color color) {
      final balance = balanceOf(category);
      final tracked = balance == null || balance['remaining'] != null;
      final pending = toNum(balance?['pending']) ?? 0;

      return _BalanceCard(
        title: title,
        value: tracked ? trimNum(balance?['remaining']) : '∞',
        suffix: tracked ? ref.tr('leave.daysLeft') : ref.tr('leavex.notTracked'),
        icon: icon,
        textColor: color,
        footnote: balance == null || balance['total'] == null
            ? null
            : [
                fill(ref.tr('leavex.usedCount'), {
                  'n': trimNum(balance['used']),
                }),
                if (pending > 0)
                  fill(ref.tr('leavex.pendingCount'), {'n': trimNum(pending)}),
              ].join(' · '),
      );
    }

    return Row(
      children: [
        Expanded(
          child: card(
            'casual',
            ref.tr('leave.casualLeaveShort'),
            Icons.event_available_outlined,
            AppColors.primaryFillColor,
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: card(
            'sick',
            ref.tr('leave.sickLeaveShort'),
            Icons.sick_outlined,
            const Color(0xFF7E3000),
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: card(
            'earned',
            ref.tr('leave.earnedLeaveShort'),
            Icons.beach_access_outlined,
            AppColors.successColor,
          ),
        ),
      ],
    );
  }
  // ============================================================
  // NEW REQUEST
  // ============================================================

  Widget _buildNewRequest(bool isLoading) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _sectionTitle(
                  editingId != null
                      ? ref.tr('leavex.updatingRequest')
                      : ref.tr('leave.newRequest'),
                ),
              ),
              if (editingId != null)
                TextButton(
                  onPressed: isLoading ? null : _cancelRequest,
                  child: Text(ref.tr('common.cancel')),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // ------------------------------------------------------
          // LEAVE TYPE
          // ------------------------------------------------------
          _FieldLabel(ref.tr('leave.leaveType')),

          _DropdownField(
            value: leaveType,
            onChanged: isLoading
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      leaveType = value;
                    });
                  },
            items: const [
              'Casual Leave',
              'Sick Leave',
              'Earned Leave',
              'Unpaid Leave',
              'Comp Off',
            ],
            labels: {
              'Casual Leave': ref.tr('leave.casualLeave'),
              'Sick Leave': ref.tr('leave.sickLeave'),
              'Earned Leave': ref.tr('leave.earnedLeave'),
              'Unpaid Leave': ref.tr('leavex.unpaidLeave'),
              'Comp Off': ref.tr('leavex.compOff'),
            },
          ),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // LEAVE DURATION
          // ------------------------------------------------------
          _FieldLabel(ref.tr('leave.leaveDuration')),

          _DropdownField(
            value: leaveDuration,
            onChanged: isLoading
                ? null
                : (value) {
                    if (value == null) return;

                    setState(() {
                      leaveDuration = value;

                      if (value != 'Permission') {
                        // Times only apply to a permission.
                        startTime = null;
                        endTime = null;

                        startTimeController.clear();
                        endTimeController.clear();
                      }

                      if (value != 'Full Day') {
                        // A half day / permission is one date.
                        endDate = null;
                        endDateController.clear();
                      }
                    });
                  },
            items: const ['Full Day', 'Half Day', 'Permission'],
            labels: {
              'Full Day': ref.tr('leave.fullDay'),
              'Half Day': ref.tr('leave.halfDay'),
              'Permission': ref.tr('leavex.permission'),
            },
          ),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // HALF DAY → SESSION
          // ------------------------------------------------------
          if (leaveDuration == 'Half Day') ...[
            _FieldLabel(ref.tr('leavex.session')),
            _DropdownField(
              value: halfDaySession,
              onChanged: isLoading
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => halfDaySession = value);
                    },
              items: const ['FIRST', 'SECOND'],
              labels: {
                'FIRST': ref.tr('leavex.firstHalf'),
                'SECOND': ref.tr('leavex.secondHalf'),
              },
            ),
            const SizedBox(height: 8),
          ],

          // ------------------------------------------------------
          // NUMBER OF DAYS
          // ------------------------------------------------------
          if (leaveDuration == 'Full Day') ...[
            _FieldLabel(ref.tr('leave.numberOfDays')),
            _DaysField(value: numberOfDays),
            const SizedBox(height: 8),
          ],

          // ------------------------------------------------------
          // START DATE
          // ------------------------------------------------------
          _FieldLabel(ref.tr('leave.startDate')),

          _TextField(
            controller: startDateController,
            hint: ref.tr('leave.dateHint'),
            suffixIcon: Icons.calendar_today_outlined,
            readOnly: true,
            onTap: isLoading ? null : _selectStartDate,
          ),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // FULL DAY → END DATE
          // ------------------------------------------------------
          if (leaveDuration == 'Full Day') ...[
            _FieldLabel(ref.tr('leave.endDate')),

            _TextField(
              controller: endDateController,
              hint: ref.tr('leave.dateHint'),
              suffixIcon: Icons.calendar_today_outlined,
              readOnly: true,
              onTap: isLoading ? null : _selectEndDate,
            ),

            const SizedBox(height: 8),
          ],

          // ------------------------------------------------------
          // PERMISSION → START TIME
          // ------------------------------------------------------
          if (_usesTimes) ...[
            _FieldLabel(ref.tr('leave.startTime')),

            _TextField(
              controller: startTimeController,
              hint: ref.tr('leave.startTimeHint'),
              suffixIcon: Icons.access_time_outlined,
              readOnly: true,
              onTap: isLoading ? null : _selectStartTime,
            ),

            const SizedBox(height: 8),

            // ----------------------------------------------------
            // HALF DAY → END TIME
            // ----------------------------------------------------
            _FieldLabel(ref.tr('leave.endTime')),

            _TextField(
              controller: endTimeController,
              hint: ref.tr('leave.endTimeHint'),
              suffixIcon: Icons.access_time_outlined,
              readOnly: true,
              onTap: isLoading ? null : _selectEndTime,
            ),

            const SizedBox(height: 8),
          ],

          if (_durationHint() != null) ...[
            Text(
              _durationHint()!,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ------------------------------------------------------
          // REASON
          // ------------------------------------------------------
          _FieldLabel(ref.tr('leave.reason')),

          _TextField(
            controller: reasonController,
            hint: ref.tr('leave.reasonHint'),
            maxLines: 4,
            readOnly: isLoading,
          ),

          const SizedBox(height: 10),

          // Optional recorded reason, sent as `voiceNote`.
          _buildVoiceNote(isLoading),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // BUTTONS
          // ------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 94,
                height: 48,
                child: OutlinedButton(
                  onPressed: isLoading ? null : _cancelRequest,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    side: const BorderSide(
                      color: AppColors.borderColor,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    ref.tr('leave.cancel'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.saffronText,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              SizedBox(
                width: 148,
                height: 48,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryFillColor,
                    disabledBackgroundColor: AppColors.primaryFillColor
                        .withValues(alpha: 0.5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          editingId != null
                              ? ref.tr('leavex.resubmit')
                              : ref.tr('leave.submitRequest'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SELECT START DATE
  // ============================================================

  String? _durationHint() {
    if (leaveDuration == 'Permission') {
      final permission = ref.read(leaveProvider).permission;

      if (permission == null) return null;

      return fill(ref.tr('leavex.permissionHint'), {
        'left': permission['remaining'],
        'cap': permission['cap'],
        'max': permission['perRequest'],
      });
    }

    if (leaveDuration == 'Half Day') return ref.tr('leavex.halfDayHint');

    return null;
  }

  Future<void> _selectStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // A request being answered may legitimately start in the past by now,
    // so the floor only applies to a new one.
    final first = editingId != null && startDate != null && startDate!.isBefore(today)
        ? startDate!
        : today;

    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? now,
      firstDate: first,
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) return;

    setState(() {
      startDate = DateTime(picked.year, picked.month, picked.day);

      startDateController.text = _formatDisplayDate(startDate!);

      if (endDate != null && endDate!.isBefore(startDate!)) {
        endDate = null;
        endDateController.clear();
      }
    });
  }

  // ============================================================
  // SELECT END DATE
  // ============================================================

  Future<void> _selectEndDate() async {
    if (startDate == null) {
      _showMessage(ref.tr('leave.selectStartDateFirst'));
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: endDate ?? startDate!,
      firstDate: startDate!,
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) return;

    setState(() {
      endDate = DateTime(picked.year, picked.month, picked.day);

      endDateController.text = _formatDisplayDate(endDate!);
    });
  }

  // ============================================================
  // SELECT START TIME
  // ============================================================

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime ?? TimeOfDay.now(),
    );

    if (picked == null || !mounted) return;

    setState(() {
      startTime = picked;

      startTimeController.text = picked.format(context);

      // If an existing end time is now invalid,
      // clear it.
      if (endTime != null) {
        final startMinutes = picked.hour * 60 + picked.minute;

        final endMinutes = endTime!.hour * 60 + endTime!.minute;

        if (endMinutes <= startMinutes) {
          endTime = null;
          endTimeController.clear();
        }
      }
    });
  }

  // ============================================================
  // SELECT END TIME
  // ============================================================

  Future<void> _selectEndTime() async {
    if (startTime == null) {
      _showMessage(ref.tr('leave.selectStartTimeFirst'));
      return;
    }

    final defaultEndHour = startTime!.hour + 1 < 24
        ? startTime!.hour + 1
        : startTime!.hour;

    final picked = await showTimePicker(
      context: context,
      initialTime:
          endTime ?? TimeOfDay(hour: defaultEndHour, minute: startTime!.minute),
    );

    if (picked == null || !mounted) return;

    final startMinutes = startTime!.hour * 60 + startTime!.minute;

    final endMinutes = picked.hour * 60 + picked.minute;

    if (endMinutes <= startMinutes) {
      _showMessage(ref.tr('leave.endTimeAfterStart'));
      return;
    }

    setState(() {
      endTime = picked;

      endTimeController.text = picked.format(context);
    });
  }

  // ============================================================
  // FORMAT DISPLAY DATE
  // ============================================================

  String _formatDisplayDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');

    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // ============================================================
  // FORMAT API DATE
  // ============================================================

  String _formatApiDate(DateTime date) {
    final year = date.year.toString();

    final month = date.month.toString().padLeft(2, '0');

    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  }

  // ============================================================
  // FORMAT API TIME
  // ============================================================

  String _formatApiTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');

    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  // ============================================================
  // SUBMIT REQUEST
  // ============================================================

  Future<void> _submitRequest() async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // START DATE
    // ----------------------------------------------------------

    if (startDate == null) {
      _showMessage(ref.tr('leave.selectStartDate'));
      return;
    }

    // ----------------------------------------------------------
    // FULL DAY VALIDATION
    // ----------------------------------------------------------

    if (leaveDuration == 'Full Day') {
      // A single day needs no end date: it ends where it starts.
      if (endDate != null && endDate!.isBefore(startDate!)) {
        _showMessage(ref.tr('leave.endDateBeforeStart'));
        return;
      }
    }

    // ----------------------------------------------------------
    // PERMISSION VALIDATION
    // ----------------------------------------------------------

    if (_usesTimes) {
      if (startTime == null) {
        _showMessage(ref.tr('leave.selectStartTime'));
        return;
      }

      if (endTime == null) {
        _showMessage(ref.tr('leave.selectEndTime'));
        return;
      }

      final startMinutes = startTime!.hour * 60 + startTime!.minute;

      final endMinutes = endTime!.hour * 60 + endTime!.minute;

      if (endMinutes <= startMinutes) {
        _showMessage(ref.tr('leave.endTimeAfterStart'));
        return;
      }
    }

    // ----------------------------------------------------------
    // REASON
    // ----------------------------------------------------------

    final reason = reasonController.text.trim();

    if (reason.length < 3) {
      _showMessage(
        reason.isEmpty
            ? ref.tr('leave.provideReason')
            : ref.tr('leavex.reasonTooShort'),
      );
      return;
    }

    if (_isRecording) await _stopRecording();

    if (!mounted) return;

    // ----------------------------------------------------------
    // API VALUES
    // ----------------------------------------------------------

    final apiStartDate = _formatApiDate(startDate!);

    // A half day / permission is one date.
    final String apiEndDate = leaveDuration == 'Full Day' && endDate != null
        ? _formatApiDate(endDate!)
        : apiStartDate;

    // Permission only.
    final String? apiStartTime = _usesTimes && startTime != null
        ? _formatApiTime(startTime!)
        : null;

    // Permission only.
    final String? apiEndTime = _usesTimes && endTime != null
        ? _formatApiTime(endTime!)
        : null;

    final wasEditing = editingId != null;

    try {
      final success = await ref
          .read(leaveProvider.notifier)
          .applyLeave(
            leaveType: apiLeaveType,
            leaveCategory: leaveCategory,
            startDate: apiStartDate,

            // Full Day:
            // sends endDate
            //
            // Half Day:
            // sends null
            endDate: apiEndDate,

            // Half Day:
            // sends startTime/endTime
            //
            // Full Day:
            // sends null
            startTime: apiStartTime,
            endTime: apiEndTime,

            halfDaySession:
                leaveDuration == 'Half Day' ? halfDaySession : null,

            reason: reason,
            voiceNotePath: _voiceNotePath,
            resubmitId: editingId,
          );

      if (!mounted) return;

      if (success) {
        _showMessage(
          wasEditing
              ? ref.tr('leavex.resubmitted')
              : ref.tr('leave.submittedSuccess'),
          isError: false,
        );

        _clearForm();
      } else {
        final error =
            ref.read(leaveProvider).error ?? ref.tr('leave.submitError');

        _showMessage(error);
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // CANCEL REQUEST
  // ============================================================

  void _cancelRequest() {
    FocusScope.of(context).unfocus();

    _clearForm();
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    setState(() {
      leaveType = 'Casual Leave';
      leaveDuration = 'Full Day';

      startDate = null;
      endDate = null;

      startTime = null;
      endTime = null;

      startDateController.clear();
      endDateController.clear();

      startTimeController.clear();
      endTimeController.clear();

      reasonController.clear();

      halfDaySession = 'FIRST';
      editingId = null;
      _voiceNotePath = null;
    });

    _previewPlayer.stop();
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFFB71C1C)
              : AppColors.successColor,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
  }

  // ============================================================
  // RECENT REQUESTS
  // ============================================================

  Widget _buildRecentRequests() {
    final leaveState = ref.watch(leaveProvider);

    final requests = leaveState.requests;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          ref.tr('leave.recentRequests'),
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textColor,
          ),
        ),

        const SizedBox(height: 8),

        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor, width: 1),
          ),
          child: _buildRequestsContent(leaveState, requests),
        ),
      ],
    );
  }

  // ============================================================
  // REQUEST CONTENT
  // ============================================================

  Widget _buildRequestsContent(
    LeaveState leaveState,
    List<Map<String, dynamic>> requests,
  ) {
    // ----------------------------------------------------------
    // LOADING
    // ----------------------------------------------------------

    if (leaveState.isLoadingRequests) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // ERROR
    // ----------------------------------------------------------

    if (leaveState.error != null && requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 28, color: Color(0xFFB71C1C)),

            const SizedBox(height: 8),

            Text(
              leaveState.error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: () {
                ref.read(leaveProvider.notifier).getMyLeaveRequests();
              },
              child: Text(ref.tr('leave.retry')),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // EMPTY
    // ----------------------------------------------------------

    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.event_available_outlined,
              size: 30,
              color: AppColors.mutedColor,
            ),

            const SizedBox(height: 8),

            Text(
              ref.tr('leave.noRequests'),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.mutedColor,
              ),
            ),
          ],
        ),
      );
    }

    // ----------------------------------------------------------
    // REQUEST LIST
    // ----------------------------------------------------------

    return Column(
      children: List.generate(requests.length, (index) {
        final request = requests[index];

        final status = request['status']?.toString();

        final id = toInt(request['id']);

        return _RecentRequest(
          icon: _getLeaveIcon(request['leave_category']?.toString()),
          title: _buildLeaveTitle(request),
          date: _buildLeaveDate(request),
          note: _buildRequestNote(request),
          status: _formatStatus(status),
          statusColor: _getStatusColor(status),
          isLast: index == requests.length - 1,
          onTap: id == null ? null : () => _openDetail(id),
        );
      }),
    );
  }

  // ============================================================
  // FORMAT STATUS
  // ============================================================

  String _formatStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return ref.tr('leave.approved');
      case 'rejected':
        return ref.tr('leave.rejected');
      case 'pending':
        return ref.tr('leave.pending');
      case 'cancelled':
        return ref.tr('leave.cancelled');
      case 'changes_requested':
        return ref.tr('leavex.changesRequested');
      default:
        return ref.tr('leave.unknown');
    }
  }

  /// Who has a pending request, or who decided it, and the remarks.
  String? _buildRequestNote(Map<String, dynamic> request) {
    final status = request['status']?.toString();
    final lines = <String>[];

    final approver = (request['currentApproverName'] ??
            request['currentStepLabel'])
        ?.toString();

    if (status == 'pending' && approver != null && approver.isNotEmpty) {
      final total = toInt(request['totalLevels']) ?? 1;

      lines.add(
        total > 1
            ? fill(ref.tr('leavex.withApprover'), {
                'level': toInt(request['current_level']) ?? 1,
                'total': total,
                'name': approver,
              })
            : fill(ref.tr('leavex.withApproverSingle'), {'name': approver}),
      );
    }

    if (status != 'pending' && request['reviewed_at'] != null) {
      lines.add(
        fill(ref.tr('leavex.decidedBy'), {
          'name': request['reviewedByName'] ?? '-',
          'date': formatApiDate(request['reviewed_at']),
        }),
      );
    }

    final remarks = request['admin_remarks']?.toString().trim() ?? '';

    if (remarks.isNotEmpty) lines.add('“$remarks”');

    return lines.isEmpty ? null : lines.join('\n');
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return AppColors.successColor;

      case 'rejected':
        return const Color(0xFFB71C1C);

      case 'pending':
      case 'changes_requested':
        return const Color(0xFFE68A00);

      case 'cancelled':
        return const Color(0xFF757575);

      default:
        return AppColors.mutedColor;
    }
  }

  // ============================================================
  // LEAVE ICON
  // ============================================================

  IconData _getLeaveIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'sick':
        return Icons.sick_outlined;

      case 'earned':
        return Icons.beach_access_outlined;

      case 'casual':
      default:
        return Icons.event_available_outlined;
    }
  }

  // ============================================================
  // LEAVE TITLE
  // ============================================================

  String _buildLeaveTitle(Map<String, dynamic> request) {
    final category = request['leave_category']?.toString() ?? '';

    final rawTotalDays = request['total_days'];

    final double totalDays = rawTotalDays is num
        ? rawTotalDays.toDouble()
        : double.tryParse(rawTotalDays?.toString() ?? '') ?? 0;

    String categoryName;

    switch (category.toLowerCase()) {
      case 'sick':
        categoryName = ref.tr('leave.sickLeave');
        break;

      case 'earned':
        categoryName = ref.tr('leave.earnedLeave');
        break;

      case 'unpaid':
        categoryName = ref.tr('leavex.unpaidLeave');
        break;

      case 'comp_off':
        categoryName = ref.tr('leavex.compOff');
        break;

      case 'casual':
      default:
        categoryName = ref.tr('leave.casualLeave');
        break;
    }

    if (request['leave_type']?.toString() == 'partial') {
      final from = request['start_time']?.toString() ?? '';
      final to = request['end_time']?.toString() ?? '';

      String hm(String t) => t.length >= 5 ? t.substring(0, 5) : t;

      return from.isEmpty
          ? '$categoryName (${ref.tr('leavex.permission')})'
          : '$categoryName (${ref.tr('leavex.permission')} ${hm(from)}–${hm(to)})';
    }

    if (totalDays == 0.5) {
      return '$categoryName (${ref.tr('leave.halfDayLabel')})';
    }

    final int days = totalDays.round();

    final dayLabel = days == 1 ? ref.tr('leave.day') : ref.tr('leave.days');

    return '$categoryName ($days $dayLabel)';
  }

  // ============================================================
  // LEAVE DATE
  // ============================================================

  String _buildLeaveDate(Map<String, dynamic> request) {
    final start = DateTime.tryParse(request['start_date']?.toString() ?? '');

    final end = DateTime.tryParse(request['end_date']?.toString() ?? '');

    if (start == null) {
      return ref.tr('leave.dateUnavailable');
    }

    final startText = _formatShortDate(start);

    // Half-day / single-day request.
    if (end == null || DateUtils.isSameDay(start, end)) {
      return '$startText, ${start.year}';
    }

    final endText = _formatShortDate(end);

    if (start.year == end.year) {
      return '$startText - $endText, ${start.year}';
    }

    return '$startText, ${start.year} - '
        '$endText, ${end.year}';
  }

  // ============================================================
  // SHORT DATE
  // ============================================================

  String _formatShortDate(DateTime date) {
    const keys = [
      'leave.jan',
      'leave.feb',
      'leave.mar',
      'leave.apr',
      'leave.may',
      'leave.jun',
      'leave.jul',
      'leave.aug',
      'leave.sep',
      'leave.oct',
      'leave.nov',
      'leave.dec',
    ];

    return '${date.day} ${ref.tr(keys[date.month - 1])}';
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textColor,
      ),
    );
  }
}

// ============================================================================
// BALANCE CARD
// ============================================================================

class _BalanceCard extends StatelessWidget {
  final String title;
  final String value;
  final String suffix;
  final IconData icon;
  final Color textColor;

  /// "2 used · 1 awaiting approval" — days taken kept apart from days held
  /// by a request still being approved.
  final String? footnote;

  const _BalanceCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.textColor,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: footnote == null ? 104 : 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.mutedColor,
            ),
          ),

          const Spacer(),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  height: .9,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),

              const SizedBox(width: 4),

              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 1),
                  child: Text(
                    suffix,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

          if (footnote != null) ...[
            const SizedBox(height: 6),
            Text(
              footnote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10,
                height: 1.2,
                color: AppColors.mutedColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION CARD
// ============================================================================

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: child,
    );
  }
}

// ============================================================================
// FIELD LABEL
// ============================================================================

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedColor,
        ),
      ),
    );
  }
}

// ============================================================================
// TEXT FIELD
// ============================================================================

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final IconData? suffixIcon;
  final int maxLines;
  final TextInputType? keyboardType;
  final VoidCallback? onTap;
  final bool readOnly;

  const _TextField({
    required this.controller,
    this.hint,
    this.suffixIcon,
    this.maxLines = 1,
    this.onTap,
    this.readOnly = false,
  }) : keyboardType = null;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedColor),
        suffixIcon: suffixIcon == null
            ? null
            : Icon(suffixIcon, size: 16, color: AppColors.mutedColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: .8),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: .8),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryFillColor,
            width: 1,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DAYS FIELD
// ============================================================================

class _DaysField extends StatelessWidget {
  final double value;

  const _DaysField({required this.value});

  @override
  Widget build(BuildContext context) {
    String text;

    if (value == 0.5) {
      text = '0.5';
    } else if (value == value.roundToDouble()) {
      text = value.toInt().toString();
    } else {
      text = value.toString();
    }

    return Container(
      width: double.infinity,
      height: 40,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: .8),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
      ),
    );
  }
}

// ============================================================================
// DROPDOWN
// ============================================================================

class _DropdownField extends StatelessWidget {
  final String value;
  final ValueChanged<String?>? onChanged;
  final List<String> items;
  final Map<String, String>? labels;

  const _DropdownField({
    required this.value,
    required this.onChanged,
    required this.items,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // Keyed on the value so a request loaded into the form shows it.
      key: ValueKey(value),
      initialValue: value,
      onChanged: onChanged,
      style: GoogleFonts.inter(fontSize: 12, color: AppColors.textColor),
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        size: 16,
        color: AppColors.mutedColor,
      ),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
      ),
      items: items
          .map(
            (item) => DropdownMenuItem<String>(
              value: item,
              child: Text(labels?[item] ?? item),
            ),
          )
          .toList(),
    );
  }
}

// ============================================================================
// RECENT REQUEST
// ============================================================================

class _RecentRequest extends StatelessWidget {
  final IconData icon;
  final String title;
  final String date;
  final String? note;
  final String status;
  final Color statusColor;
  final bool isLast;
  final VoidCallback? onTap;

  const _RecentRequest({
    required this.icon,
    required this.title,
    required this.date,
    this.note,
    required this.status,
    required this.statusColor,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: _content(),
    );
  }

  Widget _content() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: AppColors.borderColor, width: .7),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryTintColor,
            ),
            child: Icon(icon, size: 20, color: AppColors.mutedColor),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  date,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),

                if (note != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    note!,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      height: 1.3,
                      color: AppColors.mutedColor,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              status,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
