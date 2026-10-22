import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/expenses/data/expense_repository.dart';
import 'package:workforce/features/expenses/presentation/expense_ui.dart';
import 'package:workforce/features/expenses/providers/expense_provider.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';

/// File a claim: date, category, amount, description and an optional receipt
/// (camera, gallery or PDF). The organization's "receipt required above ₹X"
/// rule is shown as the amount is typed, so the API refusing it is not the
/// first the employee hears of it.
class NewExpenseScreen extends ConsumerStatefulWidget {
  const NewExpenseScreen({super.key});

  @override
  ConsumerState<NewExpenseScreen> createState() => _NewExpenseScreenState();
}

class _NewExpenseScreenState extends ConsumerState<NewExpenseScreen> {
  static const int _maxReceiptMb = 10;

  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();

  DateTime _expenseDate = DateTime.now();
  String _category = ExpenseRepository.categories.first;

  String? _receiptPath;
  String? _receiptName;
  String? _error;

  @override
  void initState() {
    super.initState();

    _dateController.text = formatApiDate(apiDateKey(_expenseDate));

    _amountController.addListener(() => setState(() {}));

    Future.microtask(() {
      final state = ref.read(expenseProvider);

      if (!state.settingsLoaded) {
        ref.read(expenseProvider.notifier).loadSettings();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  num? get _amount => num.tryParse(_amountController.text.trim());

  bool _receiptRequired(num? threshold) {
    final amount = _amount;

    return threshold != null && amount != null && amount > threshold;
  }

  // ============================================================
  // DATE
  // ============================================================

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _expenseDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );

    if (picked == null || !mounted) return;

    setState(() {
      _expenseDate = DateTime(picked.year, picked.month, picked.day);
      _dateController.text = formatApiDate(apiDateKey(_expenseDate));
    });
  }

  // ============================================================
  // RECEIPT
  // ============================================================

  Future<void> _chooseReceipt() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_camera_outlined,
                color: AppColors.saffronDeep,
              ),
              title: Text(ref.tr('expense.takePhoto')),
              onTap: () => Navigator.of(context).pop('camera'),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.saffronDeep,
              ),
              title: Text(ref.tr('expense.chooseFromGallery')),
              onTap: () => Navigator.of(context).pop('gallery'),
            ),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf_outlined,
                color: AppColors.saffronDeep,
              ),
              title: Text(ref.tr('expense.choosePdf')),
              onTap: () => Navigator.of(context).pop('pdf'),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    try {
      if (choice == 'pdf') {
        final file = await FilePicker.pickFile(
          type: FileType.custom,
          allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        );

        if (file == null) return;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage(ref.tr('documents.unableAccessFile'));
          return;
        }

        await _setReceipt(file.path!, file.name);
        return;
      }

      // imageQuality makes image_picker re-encode as JPEG (HEIC on iOS
      // would be refused by the server).
      final image = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 2000,
        maxHeight: 2000,
      );

      if (image == null) return;

      await _setReceipt(image.path, image.name);
    } catch (e) {
      debugPrint('❌ Receipt picker error: $e');
      _showMessage(ref.tr('documents.unableSelectFile'));
    }
  }

  Future<void> _setReceipt(String path, String name) async {
    final size = await File(path).length();

    if (!mounted) return;

    if (size > _maxReceiptMb * 1024 * 1024) {
      setState(() {
        _error = fill(ref.tr('expense.errReceiptSize'), {'mb': _maxReceiptMb});
      });
      return;
    }

    setState(() {
      _receiptPath = path;
      _receiptName = name;
      _error = null;
    });
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    final state = ref.read(expenseProvider);

    if (state.isSubmitting) return;

    final amount = _amount;
    final description = _descriptionController.text.trim();
    final threshold = state.receiptRequiredAbove;

    String? error;

    if (amount == null || amount <= 0) {
      error = ref.tr('expense.errAmount');
    } else if (amount > 10000000) {
      error = ref.tr('expense.errAmountMax');
    } else if (description.length < 3) {
      error = ref.tr('expense.errDescription');
    } else if (_receiptRequired(threshold) && _receiptPath == null) {
      error = fill(ref.tr('expense.errReceiptRequired'), {
        'amount': formatInr(threshold),
      });
    }

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() => _error = null);

    final failure = await ref.read(expenseProvider.notifier).submitClaim(
          expenseDate: apiDateKey(_expenseDate),
          category: _category,
          amount: amount!,
          description: description,
          receiptPath: _receiptPath,
          receiptName: _receiptName,
        );

    if (!mounted) return;

    if (failure == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = failure);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    showFeatureSnack(context, message);
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(expenseProvider);
    final threshold = state.receiptRequiredAbove;
    final receiptRequired = _receiptRequired(threshold);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,
      appBar: featureAppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FeatureHeading(
                title: ref.tr('expense.newClaim'),
                subtitle: ref.tr('expense.newClaimSubtitle'),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                ErrorBanner(_error!),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: featureInputDecoration(
                  ref.tr('expense.date'),
                  suffixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _category,
                isExpanded: true,
                decoration: featureInputDecoration(ref.tr('expense.category')),
                borderRadius: BorderRadius.circular(12),
                items: ExpenseRepository.categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(
                              expenseCategoryIcon(c),
                              size: 18,
                              color: AppColors.saffronDeep,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              expenseCategoryLabel(ref, c),
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                ],
                decoration: featureInputDecoration(
                  ref.tr('expense.amountInr'),
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descriptionController,
                minLines: 3,
                maxLines: 5,
                maxLength: 1000,
                decoration: featureInputDecoration(
                  ref.tr('expense.description'),
                  hint: ref.tr('expense.descriptionPlaceholder'),
                ),
              ),
              const SizedBox(height: 6),
              _buildReceiptPicker(receiptRequired),
              if (threshold != null) ...[
                const SizedBox(height: 8),
                Text(
                  fill(ref.tr('expense.receiptRule'), {
                    'amount': formatInr(threshold),
                  }),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: receiptRequired
                        ? AppColors.saffronText
                        : AppColors.mutedColor,
                    fontWeight:
                        receiptRequired ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              AbsorbPointer(
                absorbing: state.isSubmitting,
                child: Opacity(
                  opacity: state.isSubmitting ? 0.6 : 1,
                  child: WorkforcePrimaryButton(
                    title: state.isSubmitting
                        ? ref.tr('common.saving')
                        : ref.tr('expense.submit'),
                    icon: Icons.send_outlined,
                    onPressed: _submit,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptPicker(bool required) {
    final label = required
        ? ref.tr('expense.receiptRequired')
        : ref.tr('expense.receiptOptional');

    final isPdf = (_receiptName ?? '').toLowerCase().endsWith('.pdf');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.attach_file,
              size: 16,
              color: AppColors.mutedColor,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: required ? AppColors.saffronText : AppColors.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_receiptPath == null)
          OutlinedButton.icon(
            onPressed: _chooseReceipt,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(ref.tr('expense.addReceipt')),
          )
        else
          FeatureCard(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: isPdf
                        ? Container(
                            color: AppColors.primarySurfaceTintColor,
                            child: const Icon(
                              Icons.picture_as_pdf_outlined,
                              color: AppColors.saffronDeep,
                            ),
                          )
                        : Image.file(File(_receiptPath!), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _receiptName ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textColor,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: ref.tr('expense.changeReceipt'),
                  onPressed: _chooseReceipt,
                  icon: const Icon(Icons.swap_horiz, color: AppColors.navy),
                ),
                IconButton(
                  tooltip: ref.tr('expense.removeReceipt'),
                  onPressed: () => setState(() {
                    _receiptPath = null;
                    _receiptName = null;
                  }),
                  icon: const Icon(
                    Icons.close,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
