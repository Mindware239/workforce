import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class AttendancePdfService {
  AttendancePdfService._();

  static Future<String> generate({
    required int year,
    required int month,
    required List<Map<String, dynamic>> records,
  }) async {
    if (records.isEmpty) {
      throw Exception('No attendance records available.');
    }

    final pdf = pw.Document();

    final monthName = _monthName(month);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        build: (context) {
          return [
            pw.Text(
              'ATTENDANCE REPORT',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 4),

            pw.Text(
              '$monthName $year',
              style: const pw.TextStyle(fontSize: 12),
            ),

            pw.SizedBox(height: 20),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(1.2),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.3),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(1.0),
                6: pw.FlexColumnWidth(1.2),
                7: pw.FlexColumnWidth(1.0),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _header('Date'),
                    _header('Entry'),
                    _header('Exit'),
                    _header('Working Hours'),
                    _header('Overtime'),
                    _header('Late'),
                    _header('Early Exit'),
                    _header('Status'),
                  ],
                ),

                ...records.map(
                  (record) => pw.TableRow(
                    children: [
                      _cell(record['date']),
                      _cell(record['entryTime']),
                      _cell(record['exitTime']),
                      _cell(_formatMinutes(record['totalWorkingMinutes'])),
                      _cell(_formatMinutes(record['overtimeMinutes'])),
                      _cell('${record['lateMinutes'] ?? 0} min'),
                      _cell('${record['earlyExitMinutes'] ?? 0} min'),
                      _cell(record['status']),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              'Total Records: ${records.length}',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),

            pw.SizedBox(height: 5),

            pw.Text(
              'Generated from Workforce attendance records',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ];
        },
      ),
    );

    final directory = Directory('/storage/emulated/0/Download');

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final fileName =
        'attendance_${year}_${month.toString().padLeft(2, '0')}.pdf';

    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(await pdf.save(), flush: true);

    return file.path;
  }

  static pw.Widget _header(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  static pw.Widget _cell(dynamic value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        value?.toString() ?? '-',
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  static String _formatMinutes(dynamic value) {
    final minutes = int.tryParse(value?.toString() ?? '') ?? 0;

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    return '${hours}h ${remainingMinutes}m';
  }

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

    return months[month - 1];
  }
}
