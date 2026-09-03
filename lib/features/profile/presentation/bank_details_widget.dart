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
  ConsumerState<BankDetailsWidget> createState() => _BankDetailsWidgetState();
}

class _BankDetailsWidgetState extends ConsumerState<BankDetailsWidget> {
  final _formKey = GlobalKey<FormState>();

  final _accountHolderController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _ifscController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _branchNameController = TextEditingController();

  File? _passbookFile;
  String? _passbookFileName;

  bool _isSaving = false;
  bool _isLoading = true;

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

  Future<void> _loadBankDetails() async {
    try {
      debugPrint('🏦 Loading bank details...');

      final response = await ref
          .read(bankDetailsRepositoryProvider)
          .getBankDetails();

      debugPrint('🏦 FULL BANK RESPONSE: $response');

      if (!mounted) return;

      final Map<String, dynamic>? bankDetails = response?['data'] != null
          ? Map<String, dynamic>.from(response!['data'])
          : null;

      debugPrint('🏦 INNER BANK DATA: $bankDetails');

      setState(() {
        if (bankDetails != null) {
          _accountHolderController.text =
              bankDetails['accountHolderName']?.toString() ?? '';

          _accountNumberController.text =
              bankDetails['accountNumber']?.toString() ?? '';

          _ifscController.text = bankDetails['ifscCode']?.toString() ?? '';

          _bankNameController.text = bankDetails['bankName']?.toString() ?? '';

          _branchNameController.text =
              bankDetails['branchName']?.toString() ?? '';

          debugPrint('✅ Account Holder: ${_accountHolderController.text}');
          debugPrint('✅ Account Number: ${_accountNumberController.text}');
          debugPrint('✅ IFSC: ${_ifscController.text}');
          debugPrint('✅ Bank: ${_bankNameController.text}');
          debugPrint('✅ Branch: ${_branchNameController.text}');
        } else {
          debugPrint('ℹ️ No bank details saved yet');
        }

        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Get bank details error: $e');
      debugPrint('$stackTrace');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickPassbook() async {
    try {
      final PlatformFile? result = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      );

      if (result == null) {
        debugPrint('📄 No file selected');
        return;
      }

      debugPrint('📄 Selected file: ${result.name}');
      debugPrint('📂 File path: ${result.path}');

      if (result.path == null || result.path!.isEmpty) {
        debugPrint('❌ Selected file has no local path');
        return;
      }

      final file = File(result.path!);

      if (!await file.exists()) {
        debugPrint('❌ Selected file does not exist');
        return;
      }

      setState(() {
        _passbookFile = file;
        _passbookFileName = result.name;
      });

      debugPrint('✅ Passbook ready for upload');
      debugPrint('📄 Name: $_passbookFileName');
      debugPrint('📂 Path: ${_passbookFile!.path}');
    } catch (e, stackTrace) {
      debugPrint('❌ File picker error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  Future<void> _saveBankDetails() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Bank details validation failed');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final accountHolderName = _accountHolderController.text.trim();

    final accountNumber = _accountNumberController.text.trim();

    final ifscCode = _ifscController.text.trim().toUpperCase();

    final bankName = _bankNameController.text.trim();

    final branchName = _branchNameController.text.trim();

    debugPrint('========== SAVING BANK DETAILS ==========');
    debugPrint('Account Holder: $accountHolderName');
    debugPrint('Account Number: $accountNumber');
    debugPrint('IFSC Code: $ifscCode');
    debugPrint('Bank Name: $bankName');
    debugPrint('Branch Name: $branchName');
    debugPrint('Passbook selected: ${_passbookFile != null}');
    debugPrint('==========================================');

    try {
      final response = await ref
          .read(bankDetailsRepositoryProvider)
          .saveBankDetails(
            accountHolderName: accountHolderName,
            accountNumber: accountNumber,
            ifscCode: ifscCode,
            bankName: bankName,
            branchName: branchName.isEmpty ? null : branchName,
          );

      debugPrint('✅ Bank details saved successfully');
      debugPrint('📥 Save response: $response');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank details saved successfully')),
      );

      // Reload from backend so the UI reflects
      // exactly what the server saved.
      await _loadBankDetails();
    } catch (e, stackTrace) {
      debugPrint('❌ Save bank details error: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      if (e is DioException) {
        debugPrint('❌ STATUS CODE: ${e.response?.statusCode}');
        debugPrint('❌ RESPONSE DATA: ${e.response?.data}');
      }

      if (!mounted) return;

      String errorMessage = 'Unable to save bank details.';

      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final data = e.response?.data;

        if (statusCode == 400) {
          if (data is Map<String, dynamic>) {
            // Try backend message
            if (data['message'] != null) {
              errorMessage = data['message'].toString();
            }

            // If backend returns validation details
            if (data['details'] != null) {
              final details = data['details'];

              if (details is Map) {
                errorMessage = details.entries
                    .map((entry) => '${entry.key}: ${entry.value}')
                    .join('\n');
              } else {
                errorMessage = details.toString();
              }
            }
          }
        } else if (statusCode == 401) {
          errorMessage = 'Your session has expired. Please login again.';
        } else if (data is Map<String, dynamic> && data['message'] != null) {
          errorMessage = data['message'].toString();
        }
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.whiteBackgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteBackgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Icon(
                  Icons.credit_card_outlined,
                  size: 20,
                  color: AppColors.primaryFillColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bank Details',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildLabel('Account Holder Name'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _accountHolderController,
              hintText: 'As per bank records',
            ),

            const SizedBox(height: 12),

            _buildLabel('Account Number'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _accountNumberController,
              hintText: 'Account number',
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 12),

            _buildLabel('IFSC Code'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _ifscController,
              hintText: 'E.G. HDFC0001234',
              textCapitalization: TextCapitalization.characters,
            ),

            const SizedBox(height: 12),

            _buildLabel('Bank Name'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _bankNameController,
              hintText: 'Bank name',
            ),

            const SizedBox(height: 12),

            _buildLabel('Branch Name (optional)'),
            const SizedBox(height: 6),
            _buildTextField(
              controller: _branchNameController,
              hintText: 'Branch name',
              requiredField: false,
            ),

            const SizedBox(height: 12),

            _buildLabel('Passbook (first page) — image or PDF'),
            const SizedBox(height: 8),

            _buildFilePicker(),

            const SizedBox(height: 16),

            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveBankDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryFillColor,
                  // disabledBackgroundColor: const Color(0xFFF7A0AD),
                  elevation: 2,
                  shadowColor: const Color(0x33000000),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save Bank Details',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool requiredField = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(fontSize: 16, color: AppColors.textColor),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: const Color(0xFF8A8588),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderColor, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.primaryFillColor,
            width: 1,
          ),
        ),
      ),
      validator: requiredField
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickPassbook,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        // height: 48,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Choose file',
                style: GoogleFonts.inter(fontSize: 14, color: Colors.black),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _passbookFileName ?? 'No file chosen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _passbookFileName == null
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
