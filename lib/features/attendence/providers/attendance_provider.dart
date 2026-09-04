import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/attendance_repository.dart';

enum AttendanceStatus { initial, loading, success, error }

class AttendanceState {
  final AttendanceStatus status;
  final String? message;

  // ============================================================
  // TODAY ATTENDANCE
  // ============================================================

  final bool isLoadingToday;
  final Map<String, dynamic>? today;
  final Map<String, dynamic>? schedule;
  final List<Map<String, dynamic>> breaks;
  final int breakMinutes;
  final Map<String, dynamic>? activeBreak;
  final List<Map<String, dynamic>> timeline;

  // ============================================================
  // MONTHLY HISTORY
  // ============================================================

  final bool isLoadingHistory;
  final int? historyYear;
  final int? historyMonth;
  final int standardWorkingHoursMinutes;
  final List<Map<String, dynamic>> historyRecords;
  final Map<String, dynamic>? historySummary;

  final bool isLoadingMonthlyReport;
  final Map<String, dynamic>? monthlyReport;

  final bool isLoadingSalary;
  final Map<String, dynamic>? salarySnapshot;

  final bool isLoadingDashboard;
  final Map<String, dynamic>? dashboard;

  const AttendanceState({
    this.status = AttendanceStatus.initial,
    this.message,

    // Today
    this.isLoadingToday = false,
    this.today,
    this.schedule,
    this.breaks = const [],
    this.breakMinutes = 0,
    this.activeBreak,
    this.timeline = const [],

    // History
    this.isLoadingHistory = false,
    this.historyYear,
    this.historyMonth,
    this.standardWorkingHoursMinutes = 0,
    this.historyRecords = const [],
    this.historySummary,

    this.isLoadingMonthlyReport = false,
    this.monthlyReport,

    this.isLoadingSalary = false,
    this.salarySnapshot,

    this.isLoadingDashboard = false,
    this.dashboard,
  });

  AttendanceState copyWith({
    AttendanceStatus? status,
    String? message,
    bool clearMessage = false,

    // Today
    bool? isLoadingToday,
    Map<String, dynamic>? today,
    bool clearToday = false,
    Map<String, dynamic>? schedule,
    bool clearSchedule = false,
    List<Map<String, dynamic>>? breaks,
    int? breakMinutes,
    Map<String, dynamic>? activeBreak,
    bool clearActiveBreak = false,
    List<Map<String, dynamic>>? timeline,

    // History
    bool? isLoadingHistory,
    int? historyYear,
    int? historyMonth,
    int? standardWorkingHoursMinutes,
    List<Map<String, dynamic>>? historyRecords,
    Map<String, dynamic>? historySummary,
    bool clearHistory = false,

    bool? isLoadingMonthlyReport,
    Map<String, dynamic>? monthlyReport,
    bool clearMonthlyReport = false,

    bool? isLoadingSalary,
    Map<String, dynamic>? salarySnapshot,

    bool? isLoadingDashboard,
    Map<String, dynamic>? dashboard,
  }) {
    return AttendanceState(
      status: status ?? this.status,

      message: clearMessage ? null : message ?? this.message,

      // Today
      isLoadingToday: isLoadingToday ?? this.isLoadingToday,

      today: clearToday ? null : today ?? this.today,

      schedule: clearSchedule ? null : schedule ?? this.schedule,

      breaks: breaks ?? this.breaks,

      breakMinutes: breakMinutes ?? this.breakMinutes,

      activeBreak: clearActiveBreak ? null : activeBreak ?? this.activeBreak,

      timeline: timeline ?? this.timeline,

      // History
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,

      historyYear: clearHistory ? null : historyYear ?? this.historyYear,

      historyMonth: clearHistory ? null : historyMonth ?? this.historyMonth,

      standardWorkingHoursMinutes: clearHistory
          ? 0
          : standardWorkingHoursMinutes ?? this.standardWorkingHoursMinutes,

      historyRecords: clearHistory
          ? const []
          : historyRecords ?? this.historyRecords,

      historySummary: clearHistory
          ? null
          : historySummary ?? this.historySummary,

      isLoadingMonthlyReport:
          isLoadingMonthlyReport ?? this.isLoadingMonthlyReport,

      monthlyReport: clearMonthlyReport
          ? null
          : monthlyReport ?? this.monthlyReport,

      isLoadingSalary: isLoadingSalary ?? this.isLoadingSalary,
      salarySnapshot: salarySnapshot ?? this.salarySnapshot,

      isLoadingDashboard: isLoadingDashboard ?? this.isLoadingDashboard,

      dashboard: dashboard ?? this.dashboard,
    );
  }
}

class AttendanceNotifier extends Notifier<AttendanceState> {
  late final AttendanceRepository repository;

  @override
  AttendanceState build() {
    repository = ref.read(attendanceRepositoryProvider);

    return const AttendanceState();
  }

  // ============================================================
  // CHECK IN
  // ============================================================

  Future<bool> checkIn({
    required String attendanceType,
    String? photoPath,
    String? signature,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    state = state.copyWith(
      status: AttendanceStatus.loading,
      clearMessage: true,
    );

    try {
      await repository.checkIn(
        attendanceType: attendanceType,
        photoPath: photoPath,
        signature: signature,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
      );

      state = state.copyWith(
        status: AttendanceStatus.success,
        message: 'Check-in successful',
      );

      await getTodayAttendance();

      return true;
    } catch (e) {
      state = state.copyWith(
        status: AttendanceStatus.error,
        message: e.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    }
  }

  // ============================================================
  // TODAY ATTENDANCE
  // GET /attendance/me/today
  // ============================================================

  Future<void> getTodayAttendance() async {
    state = state.copyWith(isLoadingToday: true, clearMessage: true);

    try {
      final response = await repository.getTodayAttendance();

      final data = response['data'];

      if (data is! Map) {
        throw Exception('Invalid today attendance response.');
      }

      final todayData = data['today'];
      final scheduleData = data['schedule'];
      final breaksData = data['breaks'];
      final activeBreakData = data['activeBreak'];
      final timelineData = data['timeline'];

      final parsedBreaks = <Map<String, dynamic>>[];

      if (breaksData is List) {
        for (final item in breaksData) {
          if (item is Map) {
            parsedBreaks.add(Map<String, dynamic>.from(item));
          }
        }
      }

      final parsedTimeline = <Map<String, dynamic>>[];

      if (timelineData is List) {
        for (final item in timelineData) {
          if (item is Map) {
            parsedTimeline.add(Map<String, dynamic>.from(item));
          }
        }
      }

      state = state.copyWith(
        isLoadingToday: false,

        today: todayData is Map ? Map<String, dynamic>.from(todayData) : null,

        schedule: scheduleData is Map
            ? Map<String, dynamic>.from(scheduleData)
            : null,

        breaks: parsedBreaks,

        breakMinutes: data['breakMinutes'] is num
            ? (data['breakMinutes'] as num).toInt()
            : 0,

        activeBreak: activeBreakData is Map
            ? Map<String, dynamic>.from(activeBreakData)
            : null,

        timeline: parsedTimeline,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingToday: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // MONTHLY ATTENDANCE HISTORY
  // GET /attendance/me/history
  // ============================================================

  Future<void> getAttendanceHistory({
    required int year,
    required int month,
  }) async {
    state = state.copyWith(isLoadingHistory: true, clearMessage: true);

    try {
      final response = await repository.getAttendanceHistory(
        year: year,
        month: month,
      );

      final data = response['data'];

      if (data is! Map) {
        throw Exception('Invalid attendance history response.');
      }

      final recordsData = data['records'];
      final summaryData = data['summary'];

      final records = <Map<String, dynamic>>[];

      if (recordsData is List) {
        for (final item in recordsData) {
          if (item is Map) {
            records.add(Map<String, dynamic>.from(item));
          }
        }
      }

      Map<String, dynamic>? summary;

      if (summaryData is Map) {
        summary = Map<String, dynamic>.from(summaryData);
      }

      state = state.copyWith(
        isLoadingHistory: false,

        historyYear: data['year'] is num ? (data['year'] as num).toInt() : year,

        historyMonth: data['month'] is num
            ? (data['month'] as num).toInt()
            : month,

        standardWorkingHoursMinutes: data['standardWorkingHoursMinutes'] is num
            ? (data['standardWorkingHoursMinutes'] as num).toInt()
            : 0,

        historyRecords: records,

        historySummary: summary,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingHistory: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> getMonthlyReport({required int year, required int month}) async {
    state = state.copyWith(isLoadingMonthlyReport: true, clearMessage: true);

    try {
      final response = await repository.getMonthlyReport(
        year: year,
        month: month,
      );

      final data = response['data'];

      if (data is! Map) {
        throw Exception('Invalid monthly report response.');
      }

      state = state.copyWith(
        isLoadingMonthlyReport: false,
        monthlyReport: Map<String, dynamic>.from(data),
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMonthlyReport: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> getMySalary({required int year, required int month}) async {
    state = state.copyWith(isLoadingSalary: true, clearMessage: true);

    try {
      final response = await repository.getMySalary(year: year, month: month);

      final data = response['data'];

      if (data is! Map) {
        throw Exception('Invalid salary response.');
      }

      state = state.copyWith(
        isLoadingSalary: false,
        salarySnapshot: Map<String, dynamic>.from(data),
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingSalary: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> getDashboard() async {
    state = state.copyWith(isLoadingDashboard: true, clearMessage: true);

    try {
      final response = await repository.getDashboard();

      final data = response['data'];

      if (data is! Map) {
        throw Exception('Invalid dashboard response.');
      }

      state = state.copyWith(
        isLoadingDashboard: false,
        dashboard: Map<String, dynamic>.from(data),
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingDashboard: false,
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  // ============================================================
  // RESET
  // ============================================================

  void reset() {
    state = const AttendanceState();
  }
}

final attendanceProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
      AttendanceNotifier.new,
    );
