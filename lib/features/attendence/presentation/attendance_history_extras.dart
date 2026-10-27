import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';

/// The parts of the web attendance-history page beyond the calendar and the
/// day cards: the late-arrival policy standing, the compensatory-off
/// balance, and attendance correction (regularisation) requests — ask for a
/// day's entry/exit time to be corrected, see each request's decision, and
/// withdraw one still pending.
///
/// Data comes from GET /attendance/me/history (`latePolicy`, `compOff`,
/// `regularisations` for the month); requests go to
/// /attendance/policy/regularisations.
class AttendanceHistoryExtras extends ConsumerWidget {
  final Map<String, dynamic>? extras;

  /// Reload the month after a request is sent or withdrawn.
  final VoidCallback onChanged;

  const AttendanceHistoryExtras({
    super.key,
    required this.extras,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latePolicy = asMap(extras?['latePolicy']);
    final compOff = asMap(extras?['compOff']);
    final requests = asMapList(extras?['regularisations']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (latePolicy['penaltyEnabled'] == true) ...[
          _latePolicyCard(ref, latePolicy),
          const SizedBox(height: 12),
        ],
        if ((toNum(compOff['available']) ?? 0) > 0 ||
            (toNum(compOff['used']) ?? 0) > 0) ...[
          FeatureCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _caption(ref.tr('attendanceHistory.compOff')),
                const SizedBox(height: 4),
                Text(
                  fill(ref.tr('attendanceHistory.compOffLine'), {
                    'available': _n(compOff['available']),
                    'used': _n(compOff['used']),
                  }),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                ref.tr('attendanceHistory.correctionHint'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.mutedColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => _openRequest(context, ref),
              icon: const Icon(Icons.edit_calendar_outlined, size: 16),
              label: Text(
                ref.tr('attendanceHistory.requestCorrection'),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.saffronText,
                side: const BorderSide(color: AppColors.borderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        for (final r in requests) ...[
          const SizedBox(height: 8),
          _requestTile(context, ref, r),
        ],
      ],
    );
  }

  static String _n(dynamic value) {
    final n = toNum(value) ?? 0;

    return n == n.roundToDouble() ? '${n.toInt()}' : '$n';
  }

  Widget _caption(String text) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.mutedColor,
      ),
    );
  }

  Widget _latePolicyCard(WidgetRef ref, Map<String, dynamic> p) {
    final charged = toInt(p['halfDaysCharged']) ?? 0;
    final every = toInt(p['halfDayAfterOccurrences']) ?? 0;
    final next = toInt(p['latesUntilNextHalfDay']);

    var line = fill(ref.tr('attendanceHistory.latePolicyLine'), {
      'n': toInt(p['lateOccurrences']) ?? 0,
      'grace': toInt(p['graceMinutes']) ?? 0,
    });

    if (every > 0) {
      line +=
          ' ${fill(ref.tr('attendanceHistory.latePolicyRule'), {
            'every': every,
            'tolerated': toInt(p['toleratedOccurrences']) ?? 0,
          })}';
    }

    var verdict = charged > 0
        ? fill(ref.tr('attendanceHistory.latePolicyCharged'), {'n': charged})
        : ref.tr('attendanceHistory.latePolicyClear');

    if (next != null) {
      verdict +=
          ' · ${fill(ref.tr('attendanceHistory.latePolicyNext'), {'n': next})}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: charged > 0
              ? const Color(0xFFF5C2C0)
              : AppColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _caption(ref.tr('attendanceHistory.latePolicy')),
          const SizedBox(height: 4),
          Text(
            line,
            style: GoogleFonts.inter(fontSize: 13, color: AppColors.textColor),
          ),
          const SizedBox(height: 4),
          Text(
            verdict,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: charged > 0
                  ? const Color(0xFFB3261E)
                  : AppColors.indiaGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _requestTile(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> r,
  ) {
    final status = r['status']?.toString() ?? 'pending';
    final note = r['decisionNote']?.toString();
    final id = toInt(r['id']);

    String time(dynamic v) {
      final s = v?.toString() ?? '';

      return s.length >= 5 ? s.substring(0, 5) : '—';
    }

    final tone = switch (status) {
      'approved' => ChipTone.success,
      'rejected' => ChipTone.danger,
      'cancelled' => ChipTone.neutral,
      _ => ChipTone.warning,
    };

    return FeatureCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${formatApiDate(r['date'])} · '
                  '${time(r['requestedEntryTime'])} – '
                  '${time(r['requestedExitTime'])}',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                if ((r['reason']?.toString() ?? '').isNotEmpty)
                  Text(
                    r['reason'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.mutedColor,
                    ),
                  ),
                if (note != null && note.isNotEmpty)
                  Text(
                    note,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppColors.mutedColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              StatusChip(
                label: ref.tr('attendanceHistory.reg_$status'),
                tone: tone,
              ),
              if (status == 'pending' && id != null)
                TextButton(
                  onPressed: () => _withdraw(context, ref, id),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 30),
                  ),
                  child: Text(
                    ref.tr('attendanceHistory.withdraw'),
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, int id) async {
    final ok = await confirmAction(
      context,
      title: ref.tr('attendanceHistory.withdraw'),
      message: ref.tr('attendanceHistory.withdrawConfirm'),
      confirmLabel: ref.tr('attendanceHistory.withdraw'),
      cancelLabel: ref.tr('common.cancel'),
      destructive: true,
    );

    if (!ok || !context.mounted) return;

    try {
      await ref.read(attendanceRepositoryProvider).cancelRegularisation(id);

      if (context.mounted) {
        showFeatureSnack(context, ref.tr('attendanceHistory.withdrawn'));
      }

      onChanged();
    } catch (e) {
      if (context.mounted) showFeatureSnack(context, cleanErrorMessage(e));
    }
  }

  Future<void> _openRequest(BuildContext context, WidgetRef ref) async {
    final sent = await CorrectionSheet.show(context);

    if (sent == true) {
      if (context.mounted) {
        showFeatureSnack(context, ref.tr('attendanceHistory.correctionSent'));
      }

      onChanged();
    }
  }
}

class CorrectionSheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final TimeOfDay? initialEntry;
  final TimeOfDay? initialExit;

  const CorrectionSheet({
    super.key,
    this.initialDate,
    this.initialEntry,
    this.initialExit,
  });

  static Future<bool?> show(
    BuildContext context, {
    DateTime? initialDate,
    TimeOfDay? initialEntry,
    TimeOfDay? initialExit,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CorrectionSheet(
        initialDate: initialDate,
        initialEntry: initialEntry,
        initialExit: initialExit,
      ),
    );
  }

  @override
  ConsumerState<CorrectionSheet> createState() => _CorrectionSheetState();
}

class _CorrectionSheetState extends ConsumerState<CorrectionSheet> {
  final _reason = TextEditingController();
  late DateTime _date;
  TimeOfDay? _entry;
  TimeOfDay? _exit;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate ?? DateTime.now();
    _entry = widget.initialEntry;
    _exit = widget.initialExit;
  }
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? _hhmm(TimeOfDay? t) => t == null
      ? null
      : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _send() async {
    if (_entry == null && _exit == null) {
      setState(() => _error = ref.tr('attendanceHistory.correctionNeedTime'));
      return;
    }

    if (_reason.text.trim().length < 3) {
      setState(() => _error = ref.tr('attendanceHistory.correctionNeedReason'));
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref.read(attendanceRepositoryProvider).requestRegularisation(
            date: apiDateKey(_date),
            requestedEntryTime: _hhmm(_entry),
            requestedExitTime: _hhmm(_exit),
            reason: _reason.text.trim(),
          );

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = cleanErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget picker({
      required String label,
      required String value,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: featureInputDecoration(
            label,
            suffixIcon: Icon(icon, size: 18),
          ),
          child: Text(
            value,
            style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              ref.tr('attendanceHistory.requestCorrection'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              ref.tr('attendanceHistory.correctionDialogHint'),
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
            ),
            const SizedBox(height: 14),
            if (_error != null) ...[
              ErrorBanner(_error!),
              const SizedBox(height: 12),
            ],
            picker(
              label: ref.tr('fieldWork.date'),
              value: formatApiDate(apiDateKey(_date)),
              icon: Icons.calendar_today_outlined,
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(now.year - 1),
                  lastDate: now,
                );

                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: picker(
                    label: ref.tr('attendance.checkIn'),
                    value: _entry?.format(context) ?? '--:--',
                    icon: Icons.login_rounded,
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _entry ?? const TimeOfDay(hour: 9, minute: 0),
                      );

                      if (t != null) setState(() => _entry = t);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: picker(
                    label: ref.tr('attendance.checkOut'),
                    value: _exit?.format(context) ?? '--:--',
                    icon: Icons.logout_rounded,
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _exit ?? const TimeOfDay(hour: 18, minute: 0),
                      );

                      if (t != null) setState(() => _exit = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reason,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              decoration: featureInputDecoration(
                ref.tr('attendanceHistory.reason'),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFillColor,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : Text(
                        ref.tr('attendanceHistory.sendRequest'),
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
