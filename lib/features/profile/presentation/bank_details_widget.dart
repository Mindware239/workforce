import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // File already associated with the loaded/saved data.
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

      // debugPrint('🏦 INNER BANK DATA: $bankDetails');

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

        /*
         * If your backend later returns a passbook file name,
         * this will automatically support it.
         */
        _savedPassbookFileName =
            bankDetails['passbookFileName']?.toString() ??
                bankDetails['passbookName']?.toString();

      } else {
        // debugPrint('ℹ️ No bank details saved yet');
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
     

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to load bank details.',
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

    /*
     * Restore the last values loaded from the backend.
     * This prevents unsaved changes from remaining in the form.
     */
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

      debugPrint(
        '📄 Selected file: ${result.name}',
      );

      debugPrint(
        '📂 File path: ${result.path}',
      );

      if (result.path == null ||
          result.path!.isEmpty) {
        debugPrint(
          '❌ Selected file has no local path',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to access the selected file.',
            ),
          ),
        );

        return;
      }

      final file = File(result.path!);

      if (!await file.exists()) {
        debugPrint(
          '❌ Selected file does not exist',
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Selected file could not be found.',
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
      debugPrint(
        '❌ File picker error: $e',
      );

      debugPrint(
        'Stack trace: $stackTrace',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to select passbook file.',
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
      debugPrint(
        '❌ Bank details validation failed',
      );
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

    debugPrint(
      'Account Holder: $accountHolderName',
    );

    debugPrint(
      'Account Number: $accountNumber',
    );

    debugPrint(
      'IFSC Code: $ifscCode',
    );

    debugPrint(
      'Bank Name: $bankName',
    );

    debugPrint(
      'Branch Name: $branchName',
    );

    debugPrint(
      'Passbook selected: ${_passbookFile != null}',
    );

    debugPrint(
      '==========================================',
    );

    try {
      /*
       * Current backend PUT API does not have a passbook
       * upload field, so the selected passbook is kept
       * locally for now.
       */

      final response = await ref
          .read(bankDetailsRepositoryProvider)
          .saveBankDetails(
            accountHolderName: accountHolderName,
            accountNumber: accountNumber,
            ifscCode: ifscCode,
            bankName: bankName,
            branchName:
                branchName.isEmpty
                    ? null
                    : branchName,
          );

      debugPrint(
        '✅ Bank details saved successfully',
      );

      debugPrint(
        '📥 Save response: $response',
      );

      if (!mounted) return;

      /*
       * If a new passbook was selected, keep its name
       * visible in read-only mode.
       */
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
            'Bank details saved successfully',
            style: GoogleFonts.inter(),
          ),
        ),
      );

      /*
       * Reload backend values.
       *
       * Keep the locally selected passbook name because
       * current API does not return/upload it.
       */
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
          'Unable to save bank details.';

      if (e is DioException) {
        final statusCode =
            e.response?.statusCode;

        final data =
            e.response?.data;

        if (statusCode == 401) {
          errorMessage =
              'Your session has expired. Please login again.';
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
              errorMessage =
                  messages;
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
          color:
              AppColors.whiteBackgroundColor,
          borderRadius:
              BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.borderColor,
          ),
        ),
        child: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            AppColors.whiteBackgroundColor,
        borderRadius:
            BorderRadius.circular(12),
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
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Icon(
              Icons.credit_card_outlined,
              size: 20,
              color:
                  AppColors.primaryFillColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Bank Details',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      AppColors.textColor,
                ),
              ),
            ),

            // EDIT BUTTON
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
                    color:
                        AppColors.borderColor,
                  ),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color:
                      AppColors.primaryFillColor,
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
          label: 'ACCOUNT HOLDER',
          value:
              _accountHolderController
                  .text
                  .trim()
                  .isEmpty
                  ? 'Not provided'
                  : _accountHolderController
                      .text
                      .trim(),
        ),

        _buildViewItem(
          label: 'ACCOUNT NUMBER',
          value:
              _accountNumberController
                  .text
                  .trim()
                  .isEmpty
                  ? 'Not provided'
                  : _accountNumberController
                      .text
                      .trim(),
        ),

        _buildViewItem(
          label: 'IFSC CODE',
          value:
              _ifscController.text
                      .trim()
                      .isEmpty
                  ? 'Not provided'
                  : _ifscController
                      .text
                      .trim(),
        ),

        _buildViewItem(
          label: 'BANK NAME',
          value:
              _bankNameController.text
                      .trim()
                      .isEmpty
                  ? 'Not provided'
                  : _bankNameController
                      .text
                      .trim(),
        ),

        _buildViewItem(
          label: 'PASSBOOK',
          value:
              _savedPassbookFileName ??
                  _passbookFileName ??
                  'Not uploaded',
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
                  color:
                      AppColors.borderColor,
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
              fontWeight:
                  FontWeight.w600,
              letterSpacing: 1.1,
              color:
                  AppColors.mutedColor,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight:
                  FontWeight.w500,
              color:
                  AppColors.textColor,
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
          // Header
          Row(
            children: [
              const Icon(
                Icons.credit_card_outlined,
                size: 20,
                color:
                    AppColors.primaryFillColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Bank Details',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w600,
                  color:
                      AppColors.textColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _buildLabel(
            'Account Holder Name',
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller:
                _accountHolderController,
            hintText:
                'As per bank records',
          ),

          const SizedBox(height: 12),

          _buildLabel(
            'Account Number',
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller:
                _accountNumberController,
            hintText:
                'Account number',
            keyboardType:
                TextInputType.number,
          ),

          const SizedBox(height: 12),

          _buildLabel(
            'IFSC Code',
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller:
                _ifscController,
            hintText:
                'E.G. HDFC0001234',
            textCapitalization:
                TextCapitalization.characters,
          ),

          const SizedBox(height: 12),

          _buildLabel(
            'Bank Name',
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller:
                _bankNameController,
            hintText:
                'Bank name',
          ),

          const SizedBox(height: 12),

          _buildLabel(
            'Branch Name (optional)',
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller:
                _branchNameController,
            hintText:
                'Branch name',
            requiredField: false,
          ),

          const SizedBox(height: 12),

          _buildLabel(
            'Passbook (first page) — image or PDF',
          ),

          const SizedBox(height: 8),

          _buildFilePicker(),

          const SizedBox(height: 16),

          // SAVE + CANCEL
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child:
                      ElevatedButton(
                    onPressed:
                        _isSaving
                            ? null
                            : _saveBankDetails,
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          AppColors
                              .primaryFillColor,
                      elevation: 2,
                      shadowColor:
                          const Color(
                        0x33000000,
                      ),
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          12,
                        ),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            'Save Bank Details',
                            style:
                                GoogleFonts.inter(
                              fontSize:
                                  14,
                              fontWeight:
                                  FontWeight
                                      .w700,
                              color:
                                  Colors.white,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(width: 10),

              SizedBox(
                height: 48,
                child:
                    OutlinedButton(
                  onPressed:
                      _isSaving
                          ? null
                          : _cancelEditing,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        AppColors
                            .primaryFillColor,
                    side:
                        const BorderSide(
                      color:
                          AppColors
                              .borderColor,
                      width: 1,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 20,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        12,
                      ),
                    ),
                  ),
                  child: Text(
                    'Cancel',
                    style:
                        GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w600,
                      color:
                          AppColors
                              .primaryFillColor,
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
        fontWeight:
            FontWeight.w500,
        color:
            AppColors.mutedColor,
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String hintText,
    TextInputType? keyboardType,
    TextCapitalization
        textCapitalization =
        TextCapitalization.none,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization:
          textCapitalization,

      style: GoogleFonts.inter(
        fontSize: 16,
        color: AppColors.textColor,
      ),

      decoration: InputDecoration(
        hintText: hintText,

        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color:
              const Color(0xFF8A8588),
        ),

        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 4,
        ),

        filled: true,
        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              const BorderSide(
            color:
                AppColors.borderColor,
            width: 1,
          ),
        ),

        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              const BorderSide(
            color:
                AppColors.borderColor,
            width: 1,
          ),
        ),

        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              const BorderSide(
            color: AppColors
                .primaryFillColor,
            width: 1,
          ),
        ),

        errorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),

        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            12,
          ),
          borderSide:
              const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
      ),

      validator: requiredField
          ? (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Required';
              }

              return null;
            }
          : null,

      onChanged: (value) {
        if (controller ==
            _ifscController) {
          final upper =
              value.toUpperCase();

          if (upper != value) {
            controller.value =
                controller.value.copyWith(
              text: upper,
              selection:
                  TextSelection.collapsed(
                offset:
                    upper.length,
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
              BorderRadius.circular(
            12,
          ),
          border: Border.all(
            color:
                AppColors.borderColor,
          ),
        ),

        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 6,
                vertical: 4,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF1F1F1,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  4,
                ),
              ),

              child: Text(
                'Choose file',
                style:
                    GoogleFonts.inter(
                  fontSize: 14,
                  color:
                      Colors.black,
                ),
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child: Text(
                fileName ??
                    'No file chosen',

                maxLines: 1,

                overflow:
                    TextOverflow
                        .ellipsis,

                style:
                    GoogleFonts.inter(
                  fontSize: 14,
                  color: fileName == null
                      ? const Color(
                          0xFF555155,
                        )
                      : AppColors
                          .textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}