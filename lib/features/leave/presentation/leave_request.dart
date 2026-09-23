import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
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

      case 'Casual Leave':
      default:
        return 'casual';
    }
  }

  // ============================================================
  // API LEAVE TYPE
  // ============================================================

  String get apiLeaveType {
    if (leaveDuration == 'Half Day') {
      return 'partial';
    }

    return 'full_day';
  }

  // ============================================================
  // NUMBER OF DAYS
  // ============================================================

  double get numberOfDays {
    if (leaveDuration == 'Half Day') {
      return 0.5;
    }

    if (startDate == null || endDate == null) {
      return 0;
    }

    final start = DateTime(startDate!.year, startDate!.month, startDate!.day);

    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);

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

    super.dispose();
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
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
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
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),

                const SizedBox(height: 16),

                _buildBalanceCards(leaveState.balances),

                const SizedBox(height: 16),

                _buildNewRequest(leaveState.isLoading),

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
    String getRemaining(String category) {
      for (final balance in balances) {
        if (balance['category']?.toString() == category) {
          return balance['remaining']?.toString() ?? '0';
        }
      }

      return '0';
    }

    return Row(
      children: [
        Expanded(
          child: _BalanceCard(
            title: ref.tr('leave.casualLeaveShort'),
            value: getRemaining('casual'),
            suffix: ref.tr('leave.daysLeft'),
            icon: Icons.event_available_outlined,
            textColor: AppColors.primaryFillColor,
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: _BalanceCard(
            title: ref.tr('leave.sickLeaveShort'),
            value: getRemaining('sick'),
            suffix: ref.tr('leave.daysLeft'),
            icon: Icons.sick_outlined,
            textColor: const Color(0xFF7E3000),
          ),
        ),

        const SizedBox(width: 6),

        Expanded(
          child: _BalanceCard(
            title: ref.tr('leave.earnedLeaveShort'),
            value: getRemaining('earned'),
            suffix: ref.tr('leave.daysLeft'),
            icon: Icons.beach_access_outlined,
            textColor: const Color(0xFF059669),
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
          _sectionTitle(ref.tr('leave.newRequest')),

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
            items: const ['Casual Leave', 'Sick Leave', 'Earned Leave'],
            labels: {
              'Casual Leave': ref.tr('leave.casualLeave'),
              'Sick Leave': ref.tr('leave.sickLeave'),
              'Earned Leave': ref.tr('leave.earnedLeave'),
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

                      if (value == 'Full Day') {
                        // Half-day time fields are no longer
                        // applicable.
                        startTime = null;
                        endTime = null;

                        startTimeController.clear();
                        endTimeController.clear();
                      } else {
                        // Half Day does not use end date.
                        endDate = null;
                        endDateController.clear();
                      }
                    });
                  },
            items: const ['Full Day', 'Half Day'],
            labels: {
              'Full Day': ref.tr('leave.fullDay'),
              'Half Day': ref.tr('leave.halfDay'),
            },
          ),

          const SizedBox(height: 8),

          // ------------------------------------------------------
          // NUMBER OF DAYS
          // ------------------------------------------------------
          if (leaveDuration != 'Half Day') ...[
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
          // HALF DAY → START TIME
          // ------------------------------------------------------
          if (leaveDuration == 'Half Day') ...[
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

          const SizedBox(height: 20),

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
                      color: AppColors.primaryFillColor,
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
                          ref.tr('leave.submitRequest'),
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

  Future<void> _selectStartDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: startDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
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
      if (endDate == null) {
        _showMessage(ref.tr('leave.selectEndDate'));
        return;
      }

      if (endDate!.isBefore(startDate!)) {
        _showMessage(ref.tr('leave.endDateBeforeStart'));
        return;
      }
    }

    // ----------------------------------------------------------
    // HALF DAY VALIDATION
    // ----------------------------------------------------------

    if (leaveDuration == 'Half Day') {
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

    if (reason.isEmpty) {
      _showMessage(ref.tr('leave.provideReason'));
      return;
    }

    // ----------------------------------------------------------
    // API VALUES
    // ----------------------------------------------------------

    final apiStartDate = _formatApiDate(startDate!);

    // Full Day only.
    final String? apiEndDate = leaveDuration == 'Full Day' && endDate != null
        ? _formatApiDate(endDate!)
        : null;

    // Half Day only.
    final String? apiStartTime =
        leaveDuration == 'Half Day' && startTime != null
        ? _formatApiTime(startTime!)
        : null;

    // Half Day only.
    final String? apiEndTime = leaveDuration == 'Half Day' && endTime != null
        ? _formatApiTime(endTime!)
        : null;

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

            reason: reason,
          );

      if (!mounted) return;

      if (success) {
        _showMessage(ref.tr('leave.submittedSuccess'), isError: false);

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
    });
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
              : const Color(0xFF2E7D32),
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

        return _RecentRequest(
          icon: _getLeaveIcon(request['leave_category']?.toString()),
          title: _buildLeaveTitle(request),
          date: _buildLeaveDate(request),
          status: _formatStatus(status),
          statusColor: _getStatusColor(status),
          isLast: index == requests.length - 1,
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
      default:
        return ref.tr('leave.unknown');
    }
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'approved':
        return const Color(0xFF2E7D32);

      case 'rejected':
        return const Color(0xFFB71C1C);

      case 'pending':
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

      case 'casual':
      default:
        categoryName = ref.tr('leave.casualLeave');
        break;
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

  const _BalanceCard({
    required this.title,
    required this.value,
    required this.suffix,
    required this.icon,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
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

              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  suffix,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
            ],
          ),
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
    this.keyboardType,
    this.onTap,
    this.readOnly = false,
  });

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
  final String status;
  final Color statusColor;
  final bool isLast;

  const _RecentRequest({
    required this.icon,
    required this.title,
    required this.date,
    required this.status,
    required this.statusColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
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
              color: Color(0xFFEDE5F7),
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
