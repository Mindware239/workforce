import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/attendence/services/employee_location_service.dart';
import 'package:workforce/features/field_work/providers/field_work_provider.dart';
import 'package:workforce/features/field_work/services/field_work_tracker.dart';
import 'customer_visits_view.dart';

/// Field work, as the web's employee/field-work page: request a day out of
/// the workplace, see each request's status, and — once a session is approved
/// for today, or already running — start and stop tracking. Assigned work
/// arrives already approved, so its brief is shown here.
///
/// Tracking reuses the app's background location service (see
/// [FieldWorkTracker]); while this screen is open it also feeds its own
/// foreground fixes so the status line is live.
class FieldWorkScreen extends ConsumerStatefulWidget {
  const FieldWorkScreen({super.key});

  @override
  ConsumerState<FieldWorkScreen> createState() => _FieldWorkScreenState();
}

enum _Tone { ok, warn, bad, idle }

class _FieldWorkScreenState extends ConsumerState<FieldWorkScreen> {
  final _purposeController = TextEditingController();
  late DateTime _date;
  String? _formError;

  StreamSubscription<Position>? _positionSub;
  Timer? _refreshTimer;
  FieldTrackerSnapshot? _snapshot;
  Position? _position;

  /// null = fine; otherwise why no fix can be had.
  String? _locationProblem;
  int _activeTab = 0;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);

    Future.microtask(() async {
      await ref.read(fieldWorkProvider.notifier).load();
      _syncWatch();
    });

    // The background isolate updates the stored snapshot; re-read it, and
    // re-evaluate "gone quiet", every 15 seconds.
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _readSnapshot();
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _refreshTimer?.cancel();
    _purposeController.dispose();
    super.dispose();
  }

  Future<void> _readSnapshot() async {
    final snapshot = await FieldWorkTracker.snapshot();

    if (!mounted) return;

    // A new ping landed: refresh the "N updates recorded" count.
    if (snapshot?.lastSentAt != null &&
        snapshot?.lastSentAt != _snapshot?.lastSentAt) {
      final id = toInt(ref.read(fieldWorkProvider).current?['id']);

      if (id != null) ref.invalidate(fieldSessionHistoryProvider(id));
    }

    setState(() => _snapshot = snapshot);
  }

  bool get _isTracking =>
      ref.read(fieldWorkProvider).current?['status'] == 'active';

  /// Runs the foreground watch only while a session is active.
  Future<void> _syncWatch() async {
    if (!mounted) return;

    if (!_isTracking) {
      await _positionSub?.cancel();
      _positionSub = null;
      await _readSnapshot();
      return;
    }

    if (_positionSub != null) return;

    final problem = await _ensurePermission();

    if (!mounted) return;

    setState(() => _locationProblem = problem);

    if (problem != null) return;

    final apiClient = ref.read(apiClientProvider);

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (position) async {
        if (mounted) setState(() => _position = position);

        await FieldWorkTracker.pingIfActive(
          apiClient: apiClient,
          lat: position.latitude,
          lng: position.longitude,
          accuracy: position.accuracy,
          recordedAt: position.timestamp.toUtc().toIso8601String(),
        );

        await _readSnapshot();

        // A 403 clears the stored session: it was ended elsewhere.
        if (await FieldWorkTracker.activeSessionId() == null && mounted) {
          await ref.read(fieldWorkProvider.notifier).loadSessions();
          _syncWatch();
        }
      },
      onError: (Object error) {
        if (mounted) {
          setState(() => _locationProblem = ref.tr('fieldWork.couldNotRead'));
        }
      },
    );

    await _readSnapshot();
  }

  /// Null when a fix can be had, else the reason it cannot.
  Future<String?> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return ref.tr('fieldWork.servicesOff');
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return ref.tr('fieldWork.permissionDenied');
    }

    return null;
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );

    if (picked == null || !mounted) return;

    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _submit() async {
    final purpose = _purposeController.text.trim();

    if (purpose.length < 3) {
      setState(() => _formError = ref.tr('fieldWork.describePurpose'));
      return;
    }

    setState(() => _formError = null);

    final error = await ref.read(fieldWorkProvider.notifier).submitRequest(
          requestedDate: apiDateKey(_date),
          purpose: purpose,
        );

    if (!mounted) return;

    if (error != null) {
      setState(() => _formError = error);
      return;
    }

    _purposeController.clear();
    showFeatureSnack(context, ref.tr('fieldWork.requestSubmitted'));
  }

  Future<void> _start(Map<String, dynamic> session) async {
    final id = toInt(session['id']);

    if (id == null) return;

    final problem = await _ensurePermission();

    if (!mounted) return;

    if (problem != null) {
      setState(() => _locationProblem = problem);
      showFeatureSnack(context, problem);
      return;
    }

    // Field work is mostly spent away from the app, so ask for background
    // location (with the Play-required disclosure) and make sure the shared
    // tracking service is running.
    try {
      await LocationTrackingService.requestAlwaysPermission(context, ref.tr);
      await LocationTrackingService.start();
    } catch (_) {
      // No native tracker on this platform; the foreground watch still runs.
    }

    final error = await ref.read(fieldWorkProvider.notifier).start(id);

    if (!mounted) return;

    if (error != null) {
      showFeatureSnack(context, error);
      return;
    }

    setState(() => _locationProblem = null);
    await _syncWatch();
  }

  Future<void> _stop(Map<String, dynamic> session) async {
    final id = toInt(session['id']);

    if (id == null) return;

    final confirmed = await confirmAction(
      context,
      title: ref.tr('fieldWork.stopTracking'),
      message: ref.tr('fieldWork.stopConfirm'),
      confirmLabel: ref.tr('fieldWork.stopTracking'),
      cancelLabel: ref.tr('common.cancel'),
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    await _positionSub?.cancel();
    _positionSub = null;

    final error = await ref.read(fieldWorkProvider.notifier).end(id);

    if (!mounted) return;

    showFeatureSnack(context, error ?? ref.tr('fieldWork.trackingEnded'));

    await _syncWatch();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(fieldWorkProvider);
    final current = state.current;

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('fieldWork.title')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 0 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _activeTab == 0
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Sessions & GPS',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: _activeTab == 0 ? FontWeight.w600 : FontWeight.w500,
                            color: _activeTab == 0 ? AppColors.saffronDeep : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _activeTab = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _activeTab == 1 ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _activeTab == 1
                              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.navigation, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'Customer Visits',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: _activeTab == 1 ? FontWeight.w600 : FontWeight.w500,
                                color: _activeTab == 1 ? AppColors.saffronDeep : Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _activeTab == 1
                  ? const CustomerVisitsView()
                  : RefreshIndicator(
                      onRefresh: () async {
                        await ref.read(fieldWorkProvider.notifier).load();
                        await _syncWatch();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          FeatureHeading(
                            title: ref.tr('fieldWork.title'),
                            subtitle: ref.tr('fieldWork.subtitle'),
                          ),
                          if (current != null) ...[
                            const SizedBox(height: 20),
                            SectionTitle(ref.tr('fieldWork.locationTracking')),
                            const SizedBox(height: 10),
                            _buildCurrent(state, current),
                          ],
                          const SizedBox(height: 22),
                          SectionTitle(ref.tr('fieldWork.submitRequest')),
                          const SizedBox(height: 10),
                          _buildForm(state),
                          const SizedBox(height: 22),
                          SectionTitle(ref.tr('fieldWork.myFieldWork')),
                          const SizedBox(height: 10),
                          ..._buildList(state),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------

  // Current session
  // ------------------------------------------------------------

  Widget _buildCurrent(FieldWorkState state, Map<String, dynamic> session) {
    final tracking = session['status'] == 'active';
    final (tone, title, sub) = _describe(tracking);
    final label = session['location_label']?.toString();
    final assignedBy = session['assignedByName']?.toString();
    final id = toInt(session['id']);

    final dotColor = switch (tone) {
      _Tone.ok => AppColors.indiaGreen,
      _Tone.warn => AppColors.saffronDeep,
      _Tone.bad => const Color(0xFFB3261E),
      _Tone.idle => AppColors.mutedColor,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (session['origin'] == 'assigned' &&
            assignedBy != null &&
            assignedBy.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySurfaceTintColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              fill(ref.tr('fieldWork.assignedBy'), {'name': assignedBy}),
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.textColor),
            ),
          ),
          const SizedBox(height: 10),
        ],
        FeatureCard(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: tone == _Tone.idle
                      ? null
                      : [
                          BoxShadow(
                            color: dotColor.withValues(alpha: 0.25),
                            spreadRadius: 4,
                          ),
                        ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textColor,
                      ),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              if (label != null && label.isNotEmpty)
                TextSpan(
                  text: '$label — ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              TextSpan(text: session['purpose']?.toString() ?? ''),
            ],
          ),
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
        ),
        ..._buildWhereabouts(state),
        if (tracking && id != null) _PointsLine(sessionId: id),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: state.isBusy
                ? null
                : () => tracking ? _stop(session) : _start(session),
            style: ElevatedButton.styleFrom(
              backgroundColor: tracking
                  ? const Color(0xFFB3261E)
                  : AppColors.primaryFillColor,
              foregroundColor: AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: state.isBusy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.white,
                    ),
                  )
                : Icon(tracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
            label: Text(
              ref.tr(
                tracking ? 'fieldWork.stopTracking' : 'fieldWork.startTracking',
              ),
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// What the tracker says, as the web's `describe()` switch.
  (_Tone, String, String) _describe(bool tracking) {
    if (!tracking) {
      return (_Tone.idle, ref.tr('fieldWork.readyToStart'), '');
    }

    if (_locationProblem != null) {
      return (
        _Tone.bad,
        ref.tr('fieldWork.locationUnavailable'),
        _locationProblem!,
      );
    }

    final snapshot = _snapshot;

    if (snapshot == null) {
      return (
        _Tone.warn,
        ref.tr('fieldWork.locationAvailable'),
        ref.tr('fieldWork.sendingUpdates'),
      );
    }

    if (DateTime.now().difference(snapshot.at) > FieldWorkTracker.staleAfter) {
      return (
        _Tone.warn,
        ref.tr('fieldWork.mayHavePaused'),
        ref.tr('fieldWork.noRecentUpdate'),
      );
    }

    switch (snapshot.result) {
      case 'poor':
        return (
          _Tone.warn,
          ref.tr('fieldWork.locationAvailable'),
          fill(ref.tr('fieldWork.lowAccuracy'), {
            'meters': (snapshot.accuracy ?? 0).round(),
          }),
        );
      case 'failed':
        return (
          _Tone.warn,
          ref.tr('fieldWork.trackingActive'),
          snapshot.message?.isNotEmpty == true
              ? snapshot.message!
              : ref.tr('fieldWork.networkIssue'),
        );
      default:
        final at = snapshot.lastSentAt ?? snapshot.at;

        return (
          _Tone.ok,
          ref.tr('fieldWork.trackingActive'),
          fill(ref.tr('fieldWork.lastUpdate'), {
            'time': DateFormat('hh:mm:ss a').format(at),
          }),
        );
    }
  }

  /// In place of the web's map: how far the person is from the nearest
  /// workplace fence.
  List<Widget> _buildWhereabouts(FieldWorkState state) {
    final lat = _position?.latitude ?? _snapshot?.lat;
    final lng = _position?.longitude ?? _snapshot?.lng;
    final office = state.office;

    if (lat == null || lng == null || office == null) return const [];

    final fences = <({String label, double lat, double lng, double radius})>[];
    final places = office['places'];

    if (places is List) {
      for (final p in places.whereType<Map>()) {
        final pLat = toNum(p['lat'])?.toDouble();
        final pLng = toNum(p['lng'])?.toDouble();

        if (pLat == null || pLng == null) continue;

        fences.add((
          label: p['label']?.toString() ?? ref.tr('fieldWork.office'),
          lat: pLat,
          lng: pLng,
          radius: toNum(p['radiusMeters'])?.toDouble() ?? 100,
        ));
      }
    }

    if (fences.isEmpty) {
      final oLat = toNum(office['lat'])?.toDouble();
      final oLng = toNum(office['lng'])?.toDouble();

      if (oLat != null && oLng != null) {
        fences.add((
          label: ref.tr('fieldWork.office'),
          lat: oLat,
          lng: oLng,
          radius: toNum(office['radiusMeters'])?.toDouble() ?? 100,
        ));
      }
    }

    if (fences.isEmpty) return const [];

    ({String label, double lat, double lng, double radius})? nearest;
    double nearestDistance = double.infinity;

    for (final f in fences) {
      final d = Geolocator.distanceBetween(lat, lng, f.lat, f.lng);

      if (d < nearestDistance) {
        nearestDistance = d;
        nearest = f;
      }
    }

    final inside = nearestDistance <= nearest!.radius;
    final text = inside
        ? fill(ref.tr('fieldWork.insidePlace'), {'place': nearest.label})
        : fill(ref.tr('fieldWork.awayFromPlace'), {
            'place': nearest.label,
            'distance': nearestDistance >= 1000
                ? '${(nearestDistance / 1000).toStringAsFixed(1)} km'
                : '${nearestDistance.round()} m',
          });

    return [
      const SizedBox(height: 8),
      Row(
        children: [
          Icon(
            inside ? Icons.apartment_rounded : Icons.near_me_outlined,
            size: 16,
            color: AppColors.mutedColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
            ),
          ),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------
  // Request form
  // ------------------------------------------------------------

  Widget _buildForm(FieldWorkState state) {
    return FeatureCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_formError != null) ...[
            ErrorBanner(_formError!),
            const SizedBox(height: 12),
          ],
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: featureInputDecoration(
                ref.tr('fieldWork.date'),
                suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(
                formatApiDate(apiDateKey(_date)),
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.textColor),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _purposeController,
            minLines: 3,
            maxLines: 5,
            maxLength: 500,
            decoration: featureInputDecoration(
              ref.tr('fieldWork.purpose'),
              hint: ref.tr('fieldWork.purposePlaceholder'),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 46,
            child: ElevatedButton(
              onPressed: state.isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryFillColor,
                foregroundColor: AppColors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      ref.tr('fieldWork.submitRequest'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // My requests
  // ------------------------------------------------------------

  List<Widget> _buildList(FieldWorkState state) {
    if (state.isLoading && state.sessions.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }

    if (state.error != null && state.sessions.isEmpty) {
      return [
        LoadErrorView(
          message: state.error!,
          retryLabel: ref.tr('common.retry'),
          onRetry: () => ref.read(fieldWorkProvider.notifier).load(),
        ),
      ];
    }

    if (state.sessions.isEmpty) {
      return [
        EmptyNote(
          ref.tr('fieldWork.noRequestsYet'),
          icon: Icons.directions_walk_rounded,
        ),
      ];
    }

    return state.sessions.map(_buildSessionCard).toList();
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final status = session['status']?.toString() ?? '';
    final label = session['location_label']?.toString();
    final assignedBy = session['assignedByName']?.toString();
    final remarks = session['admin_remarks']?.toString();
    final started = parseApiDate(session['started_at']);
    final ended = parseApiDate(session['ended_at']);
    final time = DateFormat('hh:mm a');

    final tone = switch (status) {
      'pending' => ChipTone.warning,
      'approved' || 'active' => ChipTone.success,
      'rejected' => ChipTone.danger,
      _ => ChipTone.neutral,
    };

    final small = GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor);

    return FeatureCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_longDate(FieldWorkState.sessionDateKey(session))}'
                  '${label != null && label.isNotEmpty ? ' · $label' : ''}',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(session['purpose']?.toString() ?? '', style: small),
                if (session['origin'] == 'assigned' &&
                    assignedBy != null &&
                    assignedBy.isNotEmpty)
                  Text(
                    fill(ref.tr('fieldWork.assignedBy'), {'name': assignedBy}),
                    style: small,
                  ),
                if (started != null)
                  Text(
                    ended != null
                        ? '${time.format(started)} – ${time.format(ended)}'
                        : fill(ref.tr('fieldWork.startedAt'), {
                            'time': time.format(started),
                          }),
                    style: small,
                  ),
                if (status == 'rejected' &&
                    remarks != null &&
                    remarks.isNotEmpty)
                  Text(
                    fill(ref.tr('fieldWork.remarks'), {'text': remarks}),
                    style: small.copyWith(color: const Color(0xFFB3261E)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusChip(label: _statusLabel(status), tone: tone),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    final key = 'fieldWork.status_$status';
    final text = ref.tr(key);

    if (text != key) return text;

    return status.isEmpty
        ? '-'
        : '${status[0].toUpperCase()}${status.substring(1)}';
  }

  String _longDate(String key) {
    final date = DateTime.tryParse(key);

    if (date == null) return key;

    return DateFormat('EEE, d MMM yyyy').format(date);
  }
}

/// "N location updates recorded" for the running session.
class _PointsLine extends ConsumerWidget {
  final int sessionId;

  const _PointsLine({required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(fieldSessionHistoryProvider(sessionId));

    final count = history.valueOrNull?.length;

    if (count == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          const Icon(Icons.route_outlined, size: 16, color: AppColors.mutedColor),
          const SizedBox(width: 6),
          Text(
            fill(ref.tr('fieldWork.pointsRecorded'), {'count': count}),
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
          const Spacer(),
          InkWell(
            onTap: () => ref.invalidate(fieldSessionHistoryProvider(sessionId)),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.refresh, size: 16, color: AppColors.mutedColor),
            ),
          ),
        ],
      ),
    );
  }
}
