import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PayslipPdfService {
  PayslipPdfService._();

  static Future<PayslipDownloadResult> generate({
    required int year,
    required int month,
    required Map<String, dynamic> summary,
  }) async {
    if (!Platform.isAndroid) {
      throw Exception(
        'Payslip download is currently supported on Android.',
      );
    }

    final pdf = pw.Document();

    final monthName = _monthName(month);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --------------------------------------------------
              // HEADER
              // --------------------------------------------------
              pw.Container(
                padding: const pw.EdgeInsets.all(18),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey900,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'WORKFORCE',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'Employee Management System',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment:
                          pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'PAYSLIP',
                          style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          '$monthName $year',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey300,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 22),

              // --------------------------------------------------
              // PAY PERIOD
              // --------------------------------------------------
              pw.Text(
                'PAY PERIOD',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700,
                ),
              ),

              pw.SizedBox(height: 8),

              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                  borderRadius: pw.BorderRadius.circular(7),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    _infoItem(
                      'Month',
                      '$monthName $year',
                    ),
                    _infoItem(
                      'Working Days',
                      _value(summary['totalWorkingDays']),
                    ),
                    _infoItem(
                      'Present Days',
                      _value(summary['presentDays']),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 22),

              // --------------------------------------------------
              // ATTENDANCE SUMMARY
              // --------------------------------------------------
              _sectionHeader('ATTENDANCE SUMMARY'),

              pw.SizedBox(height: 9),

              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _statBox(
                            'Working Days',
                            _value(
                              summary['totalWorkingDays'],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: _statBox(
                            'Present Days',
                            _value(
                              summary['presentDays'],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: _statBox(
                            'Absent Days',
                            _value(
                              summary['absentDays'],
                            ),
                          ),
                        ),
                      ],
                    ),

                    pw.Container(
                      height: 0.5,
                      color: PdfColors.grey300,
                    ),

                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _statBox(
                            'Half Days',
                            _value(
                              summary['halfDays'],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: _statBox(
                            'Late Days',
                            _value(
                              summary['lateDays'],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: _statBox(
                            'Late Minutes',
                            _value(
                              summary['totalLateMinutes'],
                            ),
                          ),
                        ),
                      ],
                    ),

                    pw.Container(
                      height: 0.5,
                      color: PdfColors.grey300,
                    ),

                    pw.Row(
                      children: [
                        pw.Expanded(
                          child: _statBox(
                            'Early Exit',
                            '${_value(summary['totalEarlyExitMinutes'])} min',
                          ),
                        ),
                        pw.Expanded(
                          child: _statBox(
                            'Working Hours',
                            _value(
                              summary['totalWorkingHours'],
                            ),
                          ),
                        ),
                        pw.Expanded(
                          child: _statBox(
                            'Overtime',
                            _value(
                              summary['overtimeHours'],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 22),

              // --------------------------------------------------
              // SALARY DETAILS
              // --------------------------------------------------
              _sectionHeader('SALARY DETAILS'),

              pw.SizedBox(height: 9),

              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _salaryRow(
                      'Gross Salary',
                      _currency(
                        summary['grossSalary'],
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    _salaryRow(
                      'Salary Deduction',
                      '- ${_currency(
                        summary['salaryDeduction'],
                      )}',
                    ),

                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      child: pw.Divider(
                        color: PdfColors.grey300,
                      ),
                    ),

                    // FINAL SALARY
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey100,
                        borderRadius:
                            pw.BorderRadius.circular(7),
                      ),
                      child: pw.Row(
                        mainAxisAlignment:
                            pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            'NET SALARY',
                            style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight:
                                  pw.FontWeight.bold,
                            ),
                          ),
                          pw.Text(
                            _currency(
                              summary['finalSalary'],
                            ),
                            style: pw.TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  pw.FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // --------------------------------------------------
              // ATTENDANCE NOTE
              // --------------------------------------------------
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: PdfColors.grey300,
                  ),
                  borderRadius: pw.BorderRadius.circular(7),
                ),
                child: pw.Row(
                  crossAxisAlignment:
                      pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'NOTE',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Text(
                        'This payslip is generated from the '
                        'Workforce attendance and salary report '
                        'for the selected pay period.',
                        style: const pw.TextStyle(
                          fontSize: 8,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // --------------------------------------------------
              // FOOTER
              // --------------------------------------------------
              pw.Container(
                padding: const pw.EdgeInsets.only(
                  top: 10,
                ),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(
                      color: PdfColors.grey300,
                      width: 0.5,
                    ),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Workforce',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Generated from Workforce attendance report',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // ------------------------------------------------------------
    // DOWNLOADS FOLDER
    // ------------------------------------------------------------

    final downloadsDirectory = Directory(
      '/storage/emulated/0/Download',
    );

    if (!await downloadsDirectory.exists()) {
      await downloadsDirectory.create(
        recursive: true,
      );
    }

    final fileName =
        'payslip_${year}_${month.toString().padLeft(2, '0')}.pdf';

    final file = File(
      '${downloadsDirectory.path}/$fileName',
    );

    await file.writeAsBytes(
      await pdf.save(),
      flush: true,
    );

    return PayslipDownloadResult(
      fileName: fileName,
      filePath: file.path,
    );
  }

  // --------------------------------------------------------------
  // SECTION HEADER
  // --------------------------------------------------------------

  static pw.Widget _sectionHeader(String title) {
    return pw.Row(
      children: [
        pw.Container(
          width: 4,
          height: 14,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey900,
            borderRadius: pw.BorderRadius.circular(2),
          ),
        ),
        pw.SizedBox(width: 7),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------
  // INFO ITEM
  // --------------------------------------------------------------

  static pw.Widget _infoItem(
    String label,
    String value,
  ) {
    return pw.Column(
      crossAxisAlignment:
          pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey600,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------
  // STAT BOX
  // --------------------------------------------------------------

  static pw.Widget _statBox(
    String label,
    String value,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 11,
      ),
      child: pw.Column(
        crossAxisAlignment:
            pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------
  // SALARY ROW
  // --------------------------------------------------------------

  static pw.Widget _salaryRow(
    String label,
    String value,
  ) {
    return pw.Row(
      mainAxisAlignment:
          pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------
  // VALUE
  // --------------------------------------------------------------

  static String _value(dynamic value) {
    if (value == null) return '0';

    if (value is num) {
      if (value == value.roundToDouble()) {
        return value.toInt().toString();
      }

      return value.toString();
    }

    return value.toString();
  }

  // --------------------------------------------------------------
  // CURRENCY
  // --------------------------------------------------------------

  static String _currency(dynamic value) {
    if (value == null) return 'Rs. 0';

    if (value is num) {
      final number = value.toDouble();

      if (number == number.roundToDouble()) {
        return 'Rs. ${number.toInt()}';
      }

      return 'Rs. ${number.toStringAsFixed(2)}';
    }

    return 'Rs. $value';
  }

  // --------------------------------------------------------------
  // MONTH
  // --------------------------------------------------------------

  static String _monthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    if (month < 1 || month > 12) {
      return 'Unknown Month';
    }

    return months[month - 1];
  }
}

class PayslipDownloadResult {
  final String fileName;
  final String filePath;

  const PayslipDownloadResult({
    required this.fileName,
    required this.filePath,
  });
}