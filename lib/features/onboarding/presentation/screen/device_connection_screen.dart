import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:workforce/app/routes/app_routes.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/location/precise_location.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/attendence/data/attendance_repository.dart';
import 'package:workforce/features/attendence/providers/attendance_provider.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

/// Device check, as the web's employee/device page: confirms this device can
/// mark attendance from where it is. Shows a local device id (generated once
/// and kept on the device), runs the same geofence check the check-in uses
/// (`POST /attendance/geofence-check`), and says where attendance would be
/// recorded — a workplace location or today's field work — or how far away
/// the nearest place is. Passing leads on to the face capture; failing
/// offers a retry.
class DeviceConnectionScreen extends ConsumerStatefulWidget {
  const DeviceConnectionScreen({super.key});

  @override
  ConsumerState<DeviceConnectionScreen> createState() =>
      _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState
    extends ConsumerState<DeviceConnectionScreen> {
  static const _deviceKey = 'attendance_device_id';

  String _deviceId = '';
  bool _checking = true;
  String? _error;
  Map<String, dynamic>? _fence;
  Position? _position;
  DateTime? _checkedAt;

  @override
  void initState() {
    super.initState();

    Future.microtask(() async {
      await _loadDeviceId();
      await _check();
    });
  }

  /// A short, stable id for this device — the same `WS-XXXX` form and
  /// storage key the web uses.
  Future<void> _loadDeviceId() async {
    final storage = ref.read(secureStorageProvider);

    var id = await storage.read(key: _deviceKey);

    if (id == null || id.isEmpty) {
      const chars = '0123456789ABCDEF';
      final random = Random.secure();
      final suffix =
          List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();

      id = 'WS-$suffix';
      await storage.write(key: _deviceKey, value: id);
    }

    if (mounted) setState(() => _deviceId = id!);
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception(ref.tr('deviceCheck.servicesOff'));
      }

      var permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception(ref.tr('deviceCheck.permissionDenied'));
      }

      final position = await getPrecisePosition(
        timeout: const Duration(seconds: 20),
      );

      final response = await ref
          .read(attendanceRepositoryProvider)
          .checkGeofence(
            lat: position.latitude,
            lng: position.longitude,
            accuracy: position.accuracy,
          );

      final data = response['data'];

      if (!mounted) return;

      setState(() {
        _position = position;
        _fence = data is Map ? Map<String, dynamic>.from(data) : null;
        _checkedAt = DateTime.now();
        _checking = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _checking = false;
      });
    }
  }

  bool get _verified => _fence?['isWithinFence'] == true;

  void _continue() {
    if (!_verified) {
      _check();
      return;
    }

    final today = ref.read(attendanceProvider).today;
    final checkedIn = today?['entryTime'] != null;
    final checkedOut = today?['exitTime'] != null;

    if (checkedIn && checkedOut) {
      showFeatureSnack(context, ref.tr('deviceCheck.shiftDone'));
      return;
    }

    final position = _position;

    context.push(
      AppRoutes.attendanceMethod,
      extra: {
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'accuracy': position?.accuracy,
        'isStart': !checkedIn,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(title: ref.tr('deviceCheck.title')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _check,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 8),
              Center(child: _buildDeviceIcon()),
              const SizedBox(height: 12),
              Text(
                _checking
                    ? ref.tr('deviceCheck.checking')
                    : ref.tr(
                        _verified
                            ? 'deviceCheck.connected'
                            : 'deviceCheck.notVerified',
                      ),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _message(),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColors.mutedColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildDeviceDetails(),
              const SizedBox(height: 24),
              WorkforcePrimaryButton(
                title: ref.tr(_verified ? 'common.continue' : 'common.retry'),
                onPressed: _checking ? () {} : _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _message() {
    if (_checking) return ref.tr('deviceCheck.checkingHint');
    if (_error != null) return _error!;

    final place = _fence?['place'];

    if (_verified) {
      if (place is Map && place['label'] != null) {
        return fill(ref.tr('deviceCheck.atPlace'), {'place': place['label']});
      }

      return ref.tr('deviceCheck.authenticated');
    }

    final nearest = _fence?['nearest'];

    if (nearest is Map) {
      return fill(ref.tr('deviceCheck.nearestPlace'), {
        'place': nearest['label'] ?? '-',
        'distance': toNum(nearest['distanceMeters'])?.round() ?? '?',
        'radius': toNum(nearest['radiusMeters'])?.round() ?? '?',
      });
    }

    return fill(ref.tr('deviceCheck.outsideArea'), {
      'distance': toNum(_fence?['distanceMeters'])?.round() ?? '?',
    });
  }

  Widget _buildDeviceIcon() {
    final color = _verified ? AppColors.successColor : const Color(0xFFB3261E);

    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(
            Icons.devices_outlined,
            size: 36,
            color: AppColors.primaryFillColor,
          ),
          Positioned(
            right: 9,
            bottom: 8,
            child: _checking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                    child: Icon(
                      _verified ? Icons.check : Icons.close,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceDetails() {
    final place = _fence?['place'];
    final placeLabel = place is Map ? place['label']?.toString() : null;
    final accuracy = _position?.accuracy;
    final maxAccuracy = toNum(_fence?['maxGpsAccuracyMeters']);

    final rows = <_RowData>[
      (
        icon: Icons.tag_outlined,
        label: ref.tr('deviceCheck.deviceId'),
        value: _deviceId.isEmpty ? '-' : _deviceId,
        dot: null,
      ),
      (
        icon: Icons.dns_outlined,
        label: ref.tr('deviceCheck.workstation'),
        value: _checking
            ? '-'
            : ref.tr(
                _verified ? 'deviceCheck.connected' : 'deviceCheck.notConnected',
              ),
        dot: _checking
            ? null
            : _verified
            ? AppColors.successColor
            : const Color(0xFFB3261E),
      ),
      (
        icon: Icons.location_on_outlined,
        label: ref.tr('deviceCheck.networkStatus'),
        value: _checking
            ? '-'
            : _verified
            ? (placeLabel ?? ref.tr('deviceCheck.workspaceNetwork'))
            : ref.tr('deviceCheck.outsideWorkspace'),
        dot: null,
      ),
      if (accuracy != null)
        (
          icon: Icons.gps_fixed,
          label: ref.tr('deviceCheck.gpsAccuracy'),
          value: maxAccuracy == null
              ? '${accuracy.round()} m'
              : fill(ref.tr('deviceCheck.accuracyOf'), {
                  'meters': accuracy.round(),
                  'max': maxAccuracy.round(),
                }),
          dot: maxAccuracy != null && accuracy > maxAccuracy
              ? AppColors.saffronDeep
              : null,
        ),
      (
        icon: Icons.access_time_outlined,
        label: ref.tr('deviceCheck.connectionTime'),
        value: DateFormat('hh:mm a').format(_checkedAt ?? DateTime.now()),
        dot: null,
      ),
    ];

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _DeviceRow(
              icon: rows[i].icon,
              label: rows[i].label,
              value: rows[i].value,
              dotColor: rows[i].dot,
              isLast: i == rows.length - 1,
            ),
        ],
      ),
    );
  }
}

typedef _RowData = ({IconData icon, String label, String value, Color? dot});

class _DeviceRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? dotColor;
  final bool isLast;

  const _DeviceRow({
    required this.icon,
    required this.label,
    required this.value,
    this.dotColor,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Icon(icon, size: 16, color: AppColors.mutedColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.mutedColor,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (dotColor != null)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dotColor,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        value,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
