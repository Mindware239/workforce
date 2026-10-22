import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// The warehouse scanner — backend/modules/inventory and modules/sales.
/// Same calls as the web employee page `/employee/warehouse`.
///
/// A scan resolves (GET /inventory/identifiers/resolve?code=) to
/// `{ type, id, label, sub, status, code, stock?, onHand?, unitCode? }` where
/// type is variant|product|batch|serial|location|warehouse (stock you can
/// move), pick_list, transfer, count (work you can do), or another document
/// that is handled from the console.
class WarehouseRepository {
  final ApiClient apiClient;

  WarehouseRepository({required this.apiClient});

  // GET /api/inventory/identifiers/resolve?code=
  Future<Map<String, dynamic>> resolve(String code) async {
    try {
      final response = await apiClient.get(
        '/inventory/identifiers/resolve',
        queryParameters: {'code': code},
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Nothing matches that code.');
    }
  }

  // ============================================================
  // OPEN WORK
  // ============================================================

  // GET /api/sales/pick-lists?mine=true&limit=20 -> { pickLists, total }
  Future<List<Map<String, dynamic>>> getMyPickLists() async {
    try {
      final response = await apiClient.get(
        '/sales/pick-lists',
        queryParameters: {'mine': true, 'limit': 20},
      );

      return asMapList(asMap(unwrapData(response.data))['pickLists']);
    } catch (e) {
      throw apiException(e, 'Unable to load pick lists.');
    }
  }

  // GET /api/inventory/transfers?status=IN_TRANSIT&limit=20 -> { transfers }
  Future<List<Map<String, dynamic>>> getInTransitTransfers() async {
    try {
      final response = await apiClient.get(
        '/inventory/transfers',
        queryParameters: {'status': 'IN_TRANSIT', 'limit': 20},
      );

      return asMapList(asMap(unwrapData(response.data))['transfers']);
    } catch (e) {
      throw apiException(e, 'Unable to load transfers.');
    }
  }

  // GET /api/inventory/counts?status=IN_PROGRESS&limit=20 -> { counts }
  Future<List<Map<String, dynamic>>> getOpenCounts() async {
    try {
      final response = await apiClient.get(
        '/inventory/counts',
        queryParameters: {'status': 'IN_PROGRESS', 'limit': 20},
      );

      return asMapList(asMap(unwrapData(response.data))['counts']);
    } catch (e) {
      throw apiException(e, 'Unable to load stock counts.');
    }
  }

  // ============================================================
  // MOVE
  // ============================================================

  // GET /api/inventory/warehouses/:id/locations (without stock)
  Future<List<Map<String, dynamic>>> getLocations(int warehouseId) async {
    try {
      final response =
          await apiClient.get('/inventory/warehouses/$warehouseId/locations');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load locations.');
    }
  }

  // POST /api/inventory/stock/relocate
  //   { warehouseId, lines: [{ variantId, quantity, batchId, serialId,
  //     fromLocationId, toLocationId, status }] }
  Future<void> relocate({
    required int warehouseId,
    required Map<String, dynamic> line,
  }) async {
    try {
      await apiClient.post(
        '/inventory/stock/relocate',
        data: {
          'warehouseId': warehouseId,
          'lines': [line],
        },
      );
    } catch (e) {
      throw apiException(e, 'Unable to move the stock.');
    }
  }

  // ============================================================
  // PICK
  // ============================================================

  // GET /api/sales/pick-lists/:id
  Future<Map<String, dynamic>> getPickList(int id) async {
    try {
      final response = await apiClient.get('/sales/pick-lists/$id');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load the pick list.');
    }
  }

  // POST /api/sales/pick-lists/:id/pick { items: [{ itemId, pickedQuantity }] }
  Future<Map<String, dynamic>> recordPick(
    int id,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final response = await apiClient.post(
        '/sales/pick-lists/$id/pick',
        data: {'items': items},
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to record the picks.');
    }
  }

  // ============================================================
  // RECEIVE
  // ============================================================

  // GET /api/inventory/transfers/:id
  Future<Map<String, dynamic>> getTransfer(int id) async {
    try {
      final response = await apiClient.get('/inventory/transfers/$id');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load the transfer.');
    }
  }

  // GET /api/inventory/putaway/suggest?warehouseId&variantId&batchId&quantity
  //   -> { locationId, path, reason, rule: { id, name } | null, ... }
  Future<Map<String, dynamic>> suggestPutaway({
    required int warehouseId,
    required int variantId,
    int? batchId,
    num? quantity,
  }) async {
    try {
      final response = await apiClient.get(
        '/inventory/putaway/suggest',
        queryParameters: {
          'warehouseId': warehouseId,
          'variantId': variantId,
          'batchId': ?batchId,
          'quantity': ?quantity,
        },
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'No put-away suggestion.');
    }
  }

  // POST /api/inventory/transfers/:id/receive
  //   { items: [{ itemId, quantity, damagedQuantity, destLocationId }] }
  Future<Map<String, dynamic>> receiveTransfer(
    int id,
    List<Map<String, dynamic>> items,
  ) async {
    try {
      final response = await apiClient.post(
        '/inventory/transfers/$id/receive',
        data: {'items': items},
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to receive the transfer.');
    }
  }

  // ============================================================
  // COUNT
  // ============================================================

  // GET /api/inventory/counts/:id
  Future<Map<String, dynamic>> getCount(int id) async {
    try {
      final response = await apiClient.get('/inventory/counts/$id');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load the stock count.');
    }
  }

  // POST /api/inventory/counts/:id/record
  //   { items: [{ itemId, countedQuantity }] }
  Future<void> recordCount(int id, List<Map<String, dynamic>> items) async {
    try {
      await apiClient.post(
        '/inventory/counts/$id/record',
        data: {'items': items},
      );
    } catch (e) {
      throw apiException(e, 'Unable to save the counts.');
    }
  }

  // POST /api/inventory/counts/:id/submit -> { status, varianceLines, ... }
  Future<Map<String, dynamic>> submitCount(int id) async {
    try {
      final response = await apiClient.post(
        '/inventory/counts/$id/submit',
        data: <String, dynamic>{},
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to submit the count.');
    }
  }
}
