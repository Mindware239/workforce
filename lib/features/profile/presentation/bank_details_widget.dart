import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/profile/data/bank_details_repository.dart';

class BankDetailsWidget extends ConsumerStatefulWidget {
  const BankDetailsWidget({super.key});

  @override
  ConsumerState<BankDetailsWidget> createState() =>
      _BankDetailsWidgetState();
}

class _BankDetailsWidgetState
    extends ConsumerState<BankDetailsWidget> {
  final _formKey = GlobalKey<FormState>();

  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchNameController = TextEditingController();

  File? _passbookFile;
  String? _passbookFileName;

  String? _savedPassbookFileName;

  bool _isSaving = false;
  bool _isLoading = true;
  bool _isEditing = false;

  // ============================================================
  // INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      _loadBankDetails();
    });
  }

  @override
  void dispose() {
    _accountHolderController.dispose();
    _accountNumberController.dispose();
    _ifscController.dispose();
    _bankNameController.dispose();
    _branchNameController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD BANK DETAILS
  // ============================================================

  Future<void> _loadBankDetails() async {
    try {
      final response = await ref
          .read(bankDetailsRepositoryProvider)
          .getBankDetails();

      if (!mounted) return;

      Map<String, dynamic>? bankDetails;

      if (response != null && response['data'] != null) {
        bankDetails = Map<String, dynamic>.from(
          response['data'] as Map,
        );
      }

      if (bankDetails != null) {
        _accountHolderController.text =
            bankDetails['accountHolderName']?.toString() ?? '';

        _accountNumberController.text =
            bankDetails['accountNumber']?.toString() ?? '';

        _ifscController.text =
            bankDetails['ifscCode']?.toString() ?? '';

        _bankNameController.text =
            bankDetails['bankName']?.toString() ?? '';

        _branchNameController.text =
            bankDetails['branchName']?.toString() ?? '';

        _savedPassbookFileName =
            bankDetails['passbookFileName']?.toString() ??
                bankDetails['passbookName']?.toString();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Load bank details error: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.tr('bankDetails.loadError'),
            style: GoogleFonts.inter(),
          ),
        ),
      );
    }
  }

  // ============================================================
  // ENTER EDIT MODE
  // ============================================================

  void _startEditing() {
    if (_isSaving) return;

    setState(() {
      _isEditing = true;
    });
  }

  // ============================================================
  // CANCEL EDIT
  // ============================================================

  void _cancelEditing() {
    if (_isSaving) return;

    _loadBankDetails().then((_) {
      if (!mounted) return;

      setState(() {
        _isEditing = false;
        _passbookFile = null;
        _passbookFileName = null;
      });
    });
  }

  // ============================================================
  // PICK PASSBOOK
  // ============================================================

  Future<void> _pickPassbook() async {
    if (_isSaving) return;

    try {
      final PlatformFile? result =
          await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'pdf',
        ],
      );

      if (result == null) {
        debugPrint('📄 No file selected');
        return;
      }

      debugPrint('📄 Selected file: ${result.name}');
      debugPrint('📂 File path: ${result.path}');

      if (result.path == null || result.path!.isEmpty) {
        debugPrint('❌ Selected file has no local path');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.tr('bankDetails.fileAccessError'),
            ),
          ),
        );

        return;
      }

      final file = File(result.path!);

      if (!await file.exists()) {
        debugPrint('❌ Selected file does not exist');

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.tr('bankDetails.fileNotFound'),
            ),
          ),
        );

        return;
      }

      setState(() {
        _passbookFile = file;
        _passbookFileName = result.name;
      });

      debugPrint(
        '✅ Passbook selected: $_passbookFileName',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ File picker error: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.tr('bankDetails.fileSelectError'),
          ),
        ),
      );
    }
  }

  // ============================================================
  // SAVE BANK DETAILS
  // ============================================================

  Future<void> _saveBankDetails() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Bank details validation failed');
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final accountHolderName =
        _accountHolderController.text.trim();

    final accountNumber =
        _accountNumberController.text.trim();

    final ifscCode =
        _ifscController.text.trim().toUpperCase();

    final bankName =
        _bankNameController.text.trim();

    final branchName =
        _branchNameController.text.trim();

    debugPrint(
      '========== SAVING BANK DETAILS ==========',
    );

    debugPrint('Account Holder: $accountHolderName');
    debugPrint('Account Number: $accountNumber');
    debugPrint('IFSC Code: $ifscCode');
    debugPrint('Bank Name: $bankName');
    debugPrint('Branch Name: $branchName');
    debugPrint(
      'Passbook selected: ${_passbookFile != null}',
    );

    debugPrint(
      '==========================================',
    );

    try {
      final response = await ref
          .read(bankDetailsRepositoryProvider)
          .saveBankDetails(
            accountHolderName: accountHolderName,
            accountNumber: accountNumber,
            ifscCode: ifscCode,
            bankName: bankName,
            branchName: branchName.isEmpty
                ? null
                : branchName,
          );

      debugPrint('✅ Bank details saved successfully');
      debugPrint('📥 Save response: $response');

      if (!mounted) return;

      if (_passbookFileName != null) {
        _savedPassbookFileName =
            _passbookFileName;
      }

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ref.tr('bankDetails.saveSuccess'),
            style: GoogleFonts.inter(),
          ),
        ),
      );

      await _loadBankDetails();

      if (!mounted) return;

      setState(() {
        _isEditing = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        '❌ Save bank details error: $e',
      );

      debugPrint(
        '❌ Stack trace: $stackTrace',
      );

      if (e is DioException) {
        debugPrint(
          '❌ STATUS CODE: '
          '${e.response?.statusCode}',
        );

        debugPrint(
          '❌ RESPONSE DATA: '
          '${e.response?.data}',
        );
      }

      if (!mounted) return;

      String errorMessage =
          ref.tr('bankDetails.saveError');

      if (e is DioException) {
        final statusCode =
            e.response?.statusCode;

        final data =
            e.response?.data;

        if (statusCode == 401) {
          errorMessage =
              ref.tr('bankDetails.sessionExpired');
        } else if (data is Map) {
          if (data['message'] != null) {
            errorMessage =
                data['message'].toString();
          }

          if (data['details'] is List) {
            final details =
                data['details'] as List;

            final messages = details
                .whereType<Map>()
                .map((item) {
                  final field =
                      item['field']?.toString();

                  final message =
                      item['message']?.toString();

                  if (field != null &&
                      message != null) {
                    return '$field: $message';
                  }

                  return message ?? '';
                })
                .where(
                  (message) =>
                      message.isNotEmpty,
                )
                .toList();

            if (messages.isNotEmpty) {
              errorMessage =
                  messages.join('\n');
            }
          } else if (data['details'] is Map) {
            final details =
                data['details'] as Map;

            final messages =
                details.entries
                    .map(
                      (entry) =>
                          '${entry.key}: ${entry.value}',
                    )
                    .join('\n');

            if (messages.isNotEmpty) {
              errorMessage = messages;
            }
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage,
            style: GoogleFonts.inter(),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.whiteBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: _isEditing
          ? _buildEditMode()
          : _buildViewMode(),
    );
  }

  // ============================================================
  // VIEW MODE
  // ============================================================

  Widget _buildViewMode() {
    final accountHolder =
        _accountHolderController.text.trim();

    final accountNumber =
        _accountNumberController.text.trim();

    final ifscCode =
        _ifscController.text.trim();

    final bankName =
        _bankNameController.text.trim();

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.credit_card_outlined,
              size: 20,
              color: AppColors.primaryFillColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ref.tr('bankDetails.bankDetails'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
            ),
            InkWell(
              onTap: _startEditing,
              borderRadius:
                  BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(
                    color: AppColors.borderColor,
                  ),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppColors.primaryFillColor,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        const Divider(
          height: 1,
          color: AppColors.borderColor,
        ),

        const SizedBox(height: 10),

        _buildViewItem(
          label: ref.tr('bankDetails.accountHolder')
              .toUpperCase(),
          value: accountHolder.isEmpty
              ? ref.tr('bankDetails.notProvided')
              : accountHolder,
        ),

        _buildViewItem(
          label: ref.tr('bankDetails.accountNumber')
              .toUpperCase(),
          value: accountNumber.isEmpty
              ? ref.tr('bankDetails.notProvided')
              : accountNumber,
        ),

        _buildViewItem(
          label: ref.tr('bankDetails.ifscCode')
              .toUpperCase(),
          value: ifscCode.isEmpty
              ? ref.tr('bankDetails.notProvided')
              : ifscCode,
        ),

        _buildViewItem(
          label: ref.tr('bankDetails.bankName')
              .toUpperCase(),
          value: bankName.isEmpty
              ? ref.tr('bankDetails.notProvided')
              : bankName,
        ),

        _buildViewItem(
          label: ref.tr('bankDetails.passbook')
              .toUpperCase(),
          value:
              _savedPassbookFileName ??
                  _passbookFileName ??
                  ref.tr('bankDetails.notUploaded'),
          isLast: true,
        ),
      ],
    );
  }

  // ============================================================
  // VIEW ITEM
  // ============================================================

  Widget _buildViewItem({
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(
                  color: AppColors.borderColor,
                  width: 1,
                ),
              ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
              color: AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textColor,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EDIT MODE
  // ============================================================

  Widget _buildEditMode() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.credit_card_outlined,
                size: 20,
                color: AppColors.primaryFillColor,
              ),
              const SizedBox(width: 8),
              Text(
                ref.tr('bankDetails.bankDetails'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildLabel(
            ref.tr('bankDetails.accountHolderName'),
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _accountHolderController,
            hintText: ref.tr(
              'bankDetails.accountHolderNameHint',
            ),
          ),

          const SizedBox(height: 12),

          _buildLabel(
            ref.tr('bankDetails.accountNumber'),
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _accountNumberController,
            hintText: ref.tr(
              'bankDetails.accountNumberHint',
            ),
            keyboardType: TextInputType.number,
          ),

          const SizedBox(height: 12),

          _buildLabel(
            ref.tr('bankDetails.ifscCode'),
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _ifscController,
            hintText: ref.tr(
              'bankDetails.ifscCodeHint',
            ),
            textCapitalization:
                TextCapitalization.characters,
          ),

          const SizedBox(height: 12),

          _buildLabel(
            ref.tr('bankDetails.bankName'),
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _bankNameController,
            hintText: ref.tr(
              'bankDetails.bankNameHint',
            ),
          ),

          const SizedBox(height: 12),

          _buildLabel(
            ref.tr('bankDetails.branchNameOptional'),
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _branchNameController,
            hintText: ref.tr(
              'bankDetails.branchNameHint',
            ),
            requiredField: false,
          ),

          const SizedBox(height: 12),

          _buildLabel(
            ref.tr('bankDetails.passbookUploadLabel'),
          ),

          const SizedBox(height: 8),

          _buildFilePicker(),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : _saveBankDetails,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors.primaryFillColor,
                      elevation: 2,
                      shadowColor:
                          const Color(0x33000000),
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            ref.tr(
                              'bankDetails.saveDetails',
                            ),
                            style:
                                GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              SizedBox(
                height: 48,
                child: OutlinedButton(
                  onPressed: _isSaving
                      ? null
                      : _cancelEditing,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        AppColors.primaryFillColor,
                    side: const BorderSide(
                      color: AppColors.borderColor,
                      width: 1,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal: 20,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    ref.tr('common.cancel'),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color:
                          AppColors.primaryFillColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.mutedColor,
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization =
        TextCapitalization.none,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.textColor,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFF8A8588),
        ),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderColor,
            width: 1,
          ),
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderColor,
            width: 1,
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryFillColor,
            width: 1,
          ),
        ),
        errorBorder:
            OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
      ),
      validator: requiredField
          ? (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return ref.tr(
                  'bankDetails.required',
                );
              }

              return null;
            }
          : null,
      onChanged: (value) {
        if (controller == _ifscController) {
          final upper = value.toUpperCase();

          if (upper != value) {
            controller.value =
                controller.value.copyWith(
              text: upper,
              selection:
                  TextSelection.collapsed(
                offset: upper.length,
              ),
            );
          }
        }
      },
    );
  }

  // ============================================================
  // FILE PICKER
  // ============================================================

  Widget _buildFilePicker() {
    final fileName =
        _passbookFileName ??
            _savedPassbookFileName;

    return InkWell(
      onTap: _isSaving
          ? null
          : _pickPassbook,
      borderRadius:
          BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius:
                    BorderRadius.circular(4),
              ),
              child: Text(
                ref.tr('bankDetails.chooseFile'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                fileName ??
                    ref.tr(
                      'bankDetails.noFileChosen',
                    ),
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: fileName == null
                      ? const Color(0xFF555155)
                      : AppColors.textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

