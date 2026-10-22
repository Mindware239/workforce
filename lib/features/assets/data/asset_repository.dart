import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// Company assets issued to the employee — backend/modules/assets.
///
/// `GET /api/assets/mine` answers `{ current: [...], history: [...], issues: [...] }`.
/// Assignment fields: id (the assignment id), assetId, assetTag, assetName,
/// assetCategory, brand, model, serialNumber, photoPath, assetStatus,
/// assignedOn, conditionAtIssue, issueNotes, assignedByName, acknowledgedAt,
/// returnedOn, conditionAtReturn, returnNotes, receivedByName,
/// closedReason (returned|lost), openIssues.
/// Issue fields: id, assetTag, assetName, kind (damaged|lost|other),
/// description, status (open|resolved), resolutionNote, resolvedByName,
/// resolvedAt, createdAt.
class AssetRepository {
  final ApiClient apiClient;

  AssetRepository({required this.apiClient});

  static const List<String> issueKinds = ['damaged', 'lost', 'other'];

  Future<AssetHoldings> getMine() async {
    try {
      final response = await apiClient.get('/assets/mine');

      return AssetHoldings.fromJson(asMap(unwrapData(response.data)));
    } catch (e) {
      throw apiException(e, 'Unable to load your assets.');
    }
  }

  /// POST /api/assets/assignments/:assignmentId/acknowledge
  Future<AssetHoldings> acknowledge(int assignmentId) async {
    try {
      final response =
          await apiClient.post('/assets/assignments/$assignmentId/acknowledge');

      return AssetHoldings.fromJson(asMap(unwrapData(response.data)));
    } catch (e) {
      throw apiException(e, 'Unable to acknowledge the asset.');
    }
  }

  /// POST /api/assets/assignments/:assignmentId/issues
  ///   kind: damaged | lost | other
  ///   description: 3-2000 chars
  Future<AssetHoldings> reportIssue({
    required int assignmentId,
    required String kind,
    required String description,
  }) async {
    try {
      final response = await apiClient.post(
        '/assets/assignments/$assignmentId/issues',
        data: {'kind': kind, 'description': description},
      );

      return AssetHoldings.fromJson(asMap(unwrapData(response.data)));
    } catch (e) {
      throw apiException(e, 'Unable to send the report.');
    }
  }
}

class AssetHoldings {
  final List<Map<String, dynamic>> current;
  final List<Map<String, dynamic>> history;
  final List<Map<String, dynamic>> issues;

  const AssetHoldings({
    this.current = const [],
    this.history = const [],
    this.issues = const [],
  });

  factory AssetHoldings.fromJson(Map<String, dynamic> json) {
    return AssetHoldings(
      current: asMapList(json['current']),
      history: asMapList(json['history']),
      issues: asMapList(json['issues']),
    );
  }
}
