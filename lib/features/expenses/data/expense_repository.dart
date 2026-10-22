import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// Expense claims — backend/modules/expenses.
///
/// Claim fields are the API's own (camelCase): id, expenseDate (YYYY-MM-DD),
/// category, amount (number), currency, description, receiptPath,
/// receiptName, receiptMime, status (pending|approved|rejected|cancelled|paid),
/// approvalLevel, approvalTotalLevels, decidedByName, decidedAt,
/// decisionComment, paidOn, paidReference, payrollYear, payrollMonth,
/// createdAt. The detail adds `history` (approval steps).
class ExpenseRepository {
  final ApiClient apiClient;

  ExpenseRepository({required this.apiClient});

  static const List<String> categories = [
    'travel',
    'food',
    'fuel',
    'accommodation',
    'office_supplies',
    'phone_internet',
    'other',
  ];

  // ============================================================
  // SETTINGS
  // GET /api/expenses/settings -> { receiptRequiredAbove: number | null }
  // ============================================================

  Future<num?> getReceiptThreshold() async {
    try {
      final response = await apiClient.get('/expenses/settings');

      final data = asMap(unwrapData(response.data));
      final value = data['receiptRequiredAbove'];

      if (value == null) return null;

      return value is num ? value : num.tryParse(value.toString());
    } catch (e) {
      throw apiException(e, 'Unable to load expense settings.');
    }
  }

  // ============================================================
  // MY CLAIMS
  // GET /api/expenses/mine
  // ============================================================

  Future<List<Map<String, dynamic>>> getMyClaims() async {
    try {
      final response = await apiClient.get('/expenses/mine');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load your expense claims.');
    }
  }

  // ============================================================
  // ONE CLAIM
  // GET /api/expenses/:id
  // ============================================================

  Future<Map<String, dynamic>> getClaim(int id) async {
    try {
      final response = await apiClient.get('/expenses/$id');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load the expense claim.');
    }
  }

  // ============================================================
  // NEW CLAIM
  // POST /api/expenses  (multipart/form-data)
  //   expenseDate  YYYY-MM-DD
  //   category     one of [categories]
  //   amount       > 0
  //   description  3-1000 chars
  //   receipt      optional file: JPEG / PNG / WebP / PDF
  // ============================================================

  Future<Map<String, dynamic>> createClaim({
    required String expenseDate,
    required String category,
    required num amount,
    required String description,
    String? receiptPath,
    String? receiptName,
  }) async {
    try {
      final formData = FormData.fromMap({
        'expenseDate': expenseDate,
        'category': category,
        'amount': amount.toString(),
        'description': description,
        if (receiptPath != null && receiptPath.isNotEmpty)
          'receipt': await MultipartFile.fromFile(
            receiptPath,
            filename: receiptName ?? receiptPath.split(RegExp(r'[\\/]')).last,
            contentType: _mediaTypeFor(receiptName ?? receiptPath),
          ),
      });

      final response = await apiClient.dio.post('/expenses', data: formData);

      debugPrint('========== EXPENSE CLAIM CREATED ==========');
      debugPrint('${response.data}');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to submit the expense claim.');
    }
  }

  // ============================================================
  // CANCEL (pending only)
  // PUT /api/expenses/:id/cancel
  // ============================================================

  Future<void> cancelClaim(int id) async {
    try {
      await apiClient.put('/expenses/$id/cancel');
    } catch (e) {
      throw apiException(e, 'Unable to cancel the claim.');
    }
  }

  /// multer checks the declared type, so send the right one.
  static DioMediaType? _mediaTypeFor(String name) {
    final lower = name.toLowerCase();

    if (lower.endsWith('.pdf')) return DioMediaType('application', 'pdf');
    if (lower.endsWith('.png')) return DioMediaType('image', 'png');
    if (lower.endsWith('.webp')) return DioMediaType('image', 'webp');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return DioMediaType('image', 'jpeg');
    }

    return null;
  }
}
