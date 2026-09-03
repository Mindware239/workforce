import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/attendance_repository.dart';

enum AttendanceStatus {
  initial,
  loading,
  success,
  error,
}

class AttendanceState {
  final AttendanceStatus status;
  final String? message;

  const AttendanceState({
    this.status = AttendanceStatus.initial,
    this.message,
  });

  AttendanceState copyWith({
    AttendanceStatus? status,
    String? message,
  }) {
    return AttendanceState(
      status: status ?? this.status,
      message: message,
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

  Future<bool> checkIn({
    required String photoPath,
    required double lat,
    required double lng,
    double? accuracy,
  }) async {
    state = state.copyWith(
      status: AttendanceStatus.loading,
      message: null,
    );

    try {
      await repository.checkIn(
        photoPath: photoPath,
        lat: lat,
        lng: lng,
        accuracy: accuracy,
      );

      state = state.copyWith(
        status: AttendanceStatus.success,
        message: 'Check-in successful',
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: AttendanceStatus.error,
        message: e.toString().replaceFirst('Exception: ', ''),
      );

      return false;
    }
  }

  void reset() {
    state = const AttendanceState();
  }
}

final attendanceProvider =
    NotifierProvider<AttendanceNotifier, AttendanceState>(
  AttendanceNotifier.new,
);