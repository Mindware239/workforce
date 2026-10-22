import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/network/stored_file.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';

/// Pieces the expense list and detail screens share.

const List<String> expenseStatuses = [
  'pending',
  'approved',
  'rejected',
  'paid',
  'cancelled',
];

ChipTone expenseStatusTone(String? status) {
  switch (status) {
    case 'pending':
      return ChipTone.warning;
    case 'approved':
      return ChipTone.info;
    case 'rejected':
      return ChipTone.danger;
    case 'paid':
      return ChipTone.success;
    default:
      return ChipTone.neutral;
  }
}

IconData expenseCategoryIcon(String? category) {
  switch (category) {
    case 'travel':
      return Icons.directions_bus_outlined;
    case 'food':
      return Icons.restaurant_outlined;
    case 'fuel':
      return Icons.local_gas_station_outlined;
    case 'accommodation':
      return Icons.hotel_outlined;
    case 'office_supplies':
      return Icons.inventory_2_outlined;
    case 'phone_internet':
      return Icons.wifi_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

String expenseCategoryLabel(WidgetRef ref, String? category) =>
    ref.tr('expense.cat_${category ?? 'other'}');

String expenseStatusLabel(WidgetRef ref, String? status) =>
    ref.tr('expense.status_${status ?? 'pending'}');

class ExpenseStatusChips extends ConsumerWidget {
  final Map<String, dynamic> claim;

  const ExpenseStatusChips({super.key, required this.claim});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = claim['status']?.toString();
    final payrollMonth = toInt(claim['payrollMonth']);
    final payrollYear = toInt(claim['payrollYear']);
    final inPayroll = claim['payrollInputId'] != null &&
        payrollMonth != null &&
        payrollYear != null;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        StatusChip(
          label: expenseStatusLabel(ref, status),
          tone: expenseStatusTone(status),
        ),
        if (inPayroll)
          StatusChip(
            label: fill(ref.tr('expense.inPayroll'), {
              'period': '${payrollMonth.toString().padLeft(2, '0')}/$payrollYear',
            }),
            tone: ChipTone.primary,
          ),
      ],
    );
  }
}

/// The attached receipt: an inline preview for photos, a save button for both.
class ExpenseReceiptView extends ConsumerStatefulWidget {
  final Map<String, dynamic> claim;

  const ExpenseReceiptView({super.key, required this.claim});

  @override
  ConsumerState<ExpenseReceiptView> createState() => _ExpenseReceiptViewState();
}

class _ExpenseReceiptViewState extends ConsumerState<ExpenseReceiptView> {
  bool _saving = false;

  Future<void> _save(String path, String name) async {
    setState(() => _saving = true);

    try {
      final saved = await saveStoredFile(
        ref.read(apiClientProvider),
        path: path,
        fileName: name,
      );

      if (!mounted) return;

      showFeatureSnack(
        context,
        fill(ref.tr('expense.receiptSaved'), {'path': saved}),
      );
    } catch (_) {
      if (!mounted) return;

      showFeatureSnack(context, ref.tr('expense.receiptFailed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openFullScreen(String path) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: featureAppBar(title: ref.tr('expense.receipt')),
          body: Center(
            child: InteractiveViewer(
              maxScale: 5,
              child: StoredFileImage(path: path, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.claim['receiptPath']?.toString();

    if (path == null || path.isEmpty) {
      return Text(
        ref.tr('expense.noReceipt'),
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
      );
    }

    final mime = widget.claim['receiptMime']?.toString() ?? '';
    final name = widget.claim['receiptName']?.toString() ??
        'receipt-${widget.claim['id']}';
    final isImage = mime.startsWith('image/') ||
        RegExp(r'\.(jpe?g|png|webp)$', caseSensitive: false).hasMatch(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isImage)
          GestureDetector(
            onTap: () => _openFullScreen(path),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                color: AppColors.primarySurfaceTintColor,
                width: double.infinity,
                height: 200,
                child: StoredFileImage(path: path, fit: BoxFit.cover),
              ),
            ),
          )
        else
          Row(
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.saffronDeep,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.textColor,
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _saving ? null : () => _save(path, name),
          icon: _saving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 18),
          label: Text(ref.tr('expense.saveReceipt')),
        ),
      ],
    );
  }
}
