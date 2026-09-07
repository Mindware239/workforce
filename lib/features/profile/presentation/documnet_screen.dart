import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/profile/providers/document_provider.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  String _selectedDocument = 'Identity proof';

  PlatformFile? _selectedFile;

  final List<String> _documentTypes = [
    'Identity proof',
    'Address proof',
    'PAN card',
    'Bank passbook',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(documentProvider.notifier).fetchDocuments();
    });
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
      );

      final file = result.first;

      if (file.path == null || file.path!.isEmpty) {
        _showMessage('Unable to access selected file.');
        return;
      }

      setState(() {
        _selectedFile = file;
      });

      debugPrint('📄 Selected file: ${file.name}');
      debugPrint('📂 Path: ${file.path}');
    } catch (e) {
      debugPrint('❌ File picker error: $e');

      _showMessage('Unable to select file.');
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null) {
      _showMessage('Please choose a document first.');
      return;
    }

    final filePath = _selectedFile!.path;

    if (filePath == null || filePath.isEmpty) {
      _showMessage('Invalid file selected.');
      return;
    }

    final category = _getCategoryValue(_selectedDocument);

    debugPrint('📤 Uploading document...');
    debugPrint('📄 File: ${_selectedFile!.name}');
    debugPrint('📁 Path: $filePath');
    debugPrint('📂 Category: $category');

    final success = await ref
        .read(documentProvider.notifier)
        .uploadDocument(filePath: filePath, category: category);

    if (!mounted) return;

    if (success) {
      // Refresh documents from backend after successful upload.
      await ref.read(documentProvider.notifier).fetchDocuments();

      if (!mounted) return;

      setState(() {
        _selectedFile = null;
      });

      _showMessage('Document uploaded successfully.');
    } else {
      final message = ref.read(documentProvider).errorMessage;

      _showMessage(message ?? 'Unable to upload document.');
    }
  }

  String _getCategoryValue(String document) {
    switch (document) {
      case 'Identity proof':
        return 'identity';

      case 'Address proof':
        return 'address';

      case 'PAN card':
        return 'pan';

      case 'Bank passbook':
        return 'bank_passbook';

      case 'Other':
        return 'other';

      default:
        return 'other';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final documentState = ref.watch(documentProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,

      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.whiteBackgroundColor,
        surfaceTintColor: AppColors.whiteBackgroundColor,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Documents',
                style: GoogleFonts.inter(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Upload your personal documents and signe the organization\'s sNDA.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  height: 1.35,
                  color: const Color(0xFF696269),
                ),
              ),

              const SizedBox(height: 16),

              _buildNdaCard(),

              const SizedBox(height: 16),

              _buildUploadCard(
                isUploading: documentState.status == DocumentStatus.uploading,
              ),

              const SizedBox(height: 24),

              Text(
                'Your documents',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textColor,
                ),
              ),

              const SizedBox(height: 8),

              _buildDocumentsList(documentState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNdaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'NDA Agreement',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor,
                  ),
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF3525CD).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'Not available',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.mutedColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 9),

          Text(
            'Your organization has not uploaded an NDA yet.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadCard({required bool isUploading}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEBDDE0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload a document',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textColor,
            ),
          ),

          const SizedBox(height: 12),

          _buildDocumentDropdown(),

          const SizedBox(height: 12),

          _buildFilePicker(),

          const SizedBox(height: 16),

          AbsorbPointer(
            absorbing: isUploading,
            child: Opacity(
              opacity: isUploading ? 0.6 : 1,
              child: WorkforcePrimaryButton(
                title: isUploading ? 'Uploading...' : 'Upload',
                onPressed: _uploadDocument,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentDropdown() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedDocument,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 20,
            color: Color(0xFF29252A),
          ),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF29252A),
          ),
          items: _documentTypes.map((type) {
            return DropdownMenuItem<String>(value: type, child: Text(type));
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedDocument = value;
            });
          },
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor, width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Choose file',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                _selectedFile?.name ?? 'No file chosen',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF29252A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsList(DocumentState state) {
    if (state.status == DocumentStatus.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.status == DocumentStatus.error && state.documents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          state.errorMessage ?? 'Unable to load documents.',
          style: GoogleFonts.inter(fontSize: 11, color: Colors.red),
        ),
      );
    }

    if (state.documents.isEmpty) {
      return Text(
        'You haven\'t uploaded any documents yet.',
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
      );
    }

    return Column(
      children: state.documents.map((document) {
        return _buildDocumentItem(document);
      }).toList(),
    );
  }

  Widget _buildDocumentItem(Map<String, dynamic> document) {
    final fileName = document['fileName']?.toString() ?? 'Document';

    final category = document['category']?.toString() ?? '';

    final createdAt = document['createdAt']?.toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF3525CD).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _documentIcon(fileName),
              color: AppColors.primaryFillColor,
              size: 21,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textColor,
                  ),
                ),

                if (category.isNotEmpty) const SizedBox(height: 4),

                Row(
                  children: [
                    if (category.isNotEmpty)
                      Text(
                        category,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.mutedColor,
                        ),
                      ),
                    SizedBox(width: 8),
                    if (createdAt != null)
                      Text(
                        _formatDate(createdAt),
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.mutedColor,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap: () async {
              final documentId = document['id'];

              debugPrint('documentId: $documentId');

              if (documentId == null) return;

              final filePath = await ref
                  .read(documentProvider.notifier)
                  .downloadDocument(int.parse(documentId.toString()));

              if (!mounted) return;

              if (filePath != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$fileName saved to Downloads.')),
                );
              } else {
                final error = ref.read(documentProvider).errorMessage;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error ?? 'Unable to download document.'),
                  ),
                );
              }
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.mutedColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.download,
                color: AppColors.mutedColor,
                size: 21,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _documentIcon(String fileName) {
    final name = fileName.toLowerCase();

    if (name.endsWith('.pdf')) {
      return Icons.picture_as_pdf_outlined;
    }

    if (name.endsWith('.doc') || name.endsWith('.docx')) {
      return Icons.description_outlined;
    }

    return Icons.image_outlined;
  }

  String _formatDate(String value) {
    try {
      final date = DateTime.parse(value).toLocal();

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return value;
    }
  }
}
