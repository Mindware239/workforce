import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:workforce/core/network/api_error.dart';
import '../data/field_work_repository.dart';
import 'field_work_provider.dart';

final customerVisitsProvider =
    StateNotifierProvider<CustomerVisitsNotifier, CustomerVisitsState>((ref) {
  return CustomerVisitsNotifier(ref.read(fieldWorkRepositoryProvider));
});

class CustomerVisitsState {
  final bool isLoading;
  final bool isActionBusy;
  final String? error;
  final List<Map<String, dynamic>> visits;

  const CustomerVisitsState({
    this.isLoading = false,
    this.isActionBusy = false,
    this.error,
    this.visits = const [],
  });

  CustomerVisitsState copyWith({
    bool? isLoading,
    bool? isActionBusy,
    String? error,
    bool clearError = false,
    List<Map<String, dynamic>>? visits,
  }) {
    return CustomerVisitsState(
      isLoading: isLoading ?? this.isLoading,
      isActionBusy: isActionBusy ?? this.isActionBusy,
      error: clearError ? null : error ?? this.error,
      visits: visits ?? this.visits,
    );
  }
}

class CustomerVisitsNotifier extends StateNotifier<CustomerVisitsState> {
  final FieldWorkRepository repository;

  CustomerVisitsNotifier(this.repository) : super(const CustomerVisitsState());

  Future<void> loadVisits({String? status, String? date}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final list = await repository.myVisits(status: status, date: date);
      state = state.copyWith(isLoading: false, visits: list);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: cleanErrorMessage(e));
    }
  }

  /// Performs geofenced check-in using live device GPS fix
  Future<String?> checkInVisit(
    int visitId, {
    String? notes,
    String? photoUrl,
  }) async {
    state = state.copyWith(isActionBusy: true);
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      await repository.checkInVisit(
        visitId,
        lat: position.latitude,
        lng: position.longitude,
        accuracy: position.accuracy,
        notes: notes,
        photoUrl: photoUrl,
      );

      state = state.copyWith(isActionBusy: false);
      await loadVisits();
      return null;
    } catch (e) {
      state = state.copyWith(isActionBusy: false);
      return cleanErrorMessage(e);
    }
  }

  /// Performs check-out with outcome notes and collected orders
  Future<String?> checkOutVisit(
    int visitId, {
    String? outcomeNotes,
    double? orderAmount,
    String? orderReference,
  }) async {
    state = state.copyWith(isActionBusy: true);
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
        );
      } catch (_) {
        // Position optional for checkout
      }

      await repository.checkOutVisit(
        visitId,
        lat: position?.latitude,
        lng: position?.longitude,
        outcomeNotes: outcomeNotes,
        orderAmount: orderAmount,
        orderReference: orderReference,
      );

      state = state.copyWith(isActionBusy: false);
      await loadVisits();
      return null;
    } catch (e) {
      state = state.copyWith(isActionBusy: false);
      return cleanErrorMessage(e);
    }
  }
}
