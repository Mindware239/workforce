import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// Field work — backend/modules/location (routes/location.routes.js).
///
/// A session row is `field_work_sessions.*` (snake_case) plus the joined
/// `assignedByName`: id, requested_date (YYYY-MM-DD), purpose,
/// location_label, status (pending|approved|active|rejected|completed|
/// cancelled), origin (requested|assigned), admin_remarks, started_at,
/// ended_at, created_at.
class FieldWorkRepository {
  final ApiClient apiClient;

  FieldWorkRepository({required this.apiClient});

  // GET /api/location/field-sessions/mine
  Future<List<Map<String, dynamic>>> mySessions() async {
    try {
      final response = await apiClient.get('/location/field-sessions/mine');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load your field-work requests.');
    }
  }

  // POST /api/location/field-sessions { purpose (3-500), requestedDate }
  Future<Map<String, dynamic>> createSession({
    required String purpose,
    required String requestedDate,
  }) async {
    try {
      final response = await apiClient.post(
        '/location/field-sessions',
        data: {'purpose': purpose, 'requestedDate': requestedDate},
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not submit the request.');
    }
  }

  // POST /api/location/field-sessions/:id/start (approved, for today)
  Future<Map<String, dynamic>> startSession(int id) async {
    try {
      final response =
          await apiClient.post('/location/field-sessions/$id/start');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not start tracking.');
    }
  }

  // POST /api/location/field-sessions/:id/end (active)
  Future<Map<String, dynamic>> endSession(int id) async {
    try {
      final response = await apiClient.post('/location/field-sessions/$id/end');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not end tracking.');
    }
  }

  // GET /api/location/field-sessions/:id/history -> [{lat,lng,accuracy,recordedAt}]
  Future<List<Map<String, dynamic>>> sessionHistory(int id) async {
    try {
      final response =
          await apiClient.get('/location/field-sessions/$id/history');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load the movement history.');
    }
  }

  // GET /api/location/office -> { lat, lng, radiusMeters, places: [...] }
  Future<Map<String, dynamic>> office() async {
    try {
      final response = await apiClient.get('/location/office');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load the workplace location.');
    }
  }

  // GET /api/visits (list assigned customer visits for field employee)
  Future<List<Map<String, dynamic>>> myVisits({String? status, String? date}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null) queryParams['status'] = status;
      if (date != null) queryParams['date'] = date;

      final response = await apiClient.get('/visits', queryParameters: queryParams);
      final data = unwrapData(response.data);
      if (data is Map && data['items'] is List) {
        return asMapList(data['items']);
      }
      return asMapList(data);
    } catch (e) {
      throw apiException(e, 'Unable to load customer visits.');
    }
  }

  // POST /api/visits/:id/check-in (with geofence validation and coordinates)
  Future<Map<String, dynamic>> checkInVisit(
    int id, {
    required double lat,
    required double lng,
    double? accuracy,
    String? notes,
    String? photoUrl,
  }) async {
    try {
      final response = await apiClient.post(
        '/visits/$id/check-in',
        data: {
          'lat': lat,
          'lng': lng,
          'accuracy': ?accuracy,
          'notes': ?notes,
          'photoUrl': ?photoUrl,
        },
      );
      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not complete customer visit check-in.');
    }
  }

  // POST /api/visits/:id/check-out (with outcome notes and order collection)
  Future<Map<String, dynamic>> checkOutVisit(
    int id, {
    double? lat,
    double? lng,
    String? outcomeNotes,
    double? orderAmount,
    String? orderReference,
    double? paymentCollected,
    String? paymentMethod,
  }) async {
    try {
      final response = await apiClient.post(
        '/visits/$id/check-out',
        data: {
          'lat': ?lat,
          'lng': ?lng,
          'outcomeNotes': ?outcomeNotes,
          'orderAmount': ?orderAmount,
          'orderReference': ?orderReference,
          'paymentCollected': ?paymentCollected,
          'paymentMethod': ?paymentMethod,
        },
      );
      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not complete customer visit check-out.');
    }
  }
}
