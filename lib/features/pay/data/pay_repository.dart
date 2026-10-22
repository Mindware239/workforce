import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';

/// The employee's own finalized payroll — backend/modules/payroll, the
/// `/payroll/me...` half. The subject is always the token; nothing is fetched
/// by user id.
///
/// GET /api/payroll/me?year=&month=
///   -> { year, month, available: false, reason: not_run|not_finalized, runStatus? }
///   or the record with available: true: grossEarnings, totalDeductions,
///      netPay, workingDays, payableDays, presentDays, halfDays, absentDays,
///      paidLeaveDays, unpaidLeaveDays, wfhDays, lateOccurrences,
///      overtimeMinutes, runStatus, finalizedAt, paidAt, payGroupName,
///      payslip {id, number} | null,
///      payment {status, method, reference, paidOn},
///      earnings[], deductions[], employerContributions[], pendingEarnings[]
///      (items: id, kind, code, label, amount, calculation {formula?},
///       approvalStatus approved|pending|rejected), days[], exceptions[].
/// GET /api/payroll/me/history?limit=24 -> finalized months, newest first:
///   id, year, month, runStatus, grossEarnings, totalDeductions, netPay,
///   payslipId, payslipNumber, paymentStatus.
/// GET /api/payroll/payslips/:id/download -> the PDF.
class PayRepository {
  final ApiClient apiClient;

  PayRepository({required this.apiClient});

  Future<Map<String, dynamic>> getMyPayroll(int year, int month) async {
    try {
      final response = await apiClient.get(
        '/payroll/me',
        queryParameters: {'year': year, 'month': month},
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load your pay.');
    }
  }

  Future<List<Map<String, dynamic>>> getHistory({int limit = 24}) async {
    try {
      final response = await apiClient.get(
        '/payroll/me/history',
        queryParameters: {'limit': limit},
      );

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load your pay history.');
    }
  }

  /// Downloads the payslip PDF the server rendered and saves it to the
  /// Download folder (Android), falling back to the app documents folder.
  /// Returns where it was saved.
  Future<String> downloadPayslip({
    required int payslipId,
    required String fileName,
  }) async {
    try {
      final response = await apiClient.dio.get<List<int>>(
        '/payroll/payslips/$payslipId/download',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data ?? const <int>[];

      if (bytes.isEmpty) throw Exception('The payslip came back empty.');

      Directory directory = Directory('/storage/emulated/0/Download');

      if (!Platform.isAndroid || !await directory.exists()) {
        directory = await getApplicationDocumentsDirectory();
      }

      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File(
        '${directory.path}/${safeName.toLowerCase().endsWith('.pdf') ? safeName : '$safeName.pdf'}',
      );

      await file.writeAsBytes(bytes, flush: true);

      return file.path;
    } catch (e) {
      throw apiException(e, 'Unable to download the payslip.');
    }
  }
}
