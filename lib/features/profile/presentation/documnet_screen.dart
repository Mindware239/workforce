import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:workforce/core/styles/app_colors.dart';
import 'package:workforce/core/styles/tricolour_strip.dart';
import 'package:workforce/core/localization/app_localization.dart';
import 'package:workforce/core/widgets/feature_widgets.dart';
import 'package:workforce/features/onboarding/presentation/widget/primary_button.dart';
import 'package:workforce/features/profile/providers/document_provider.dart';

/// Documents, as on the web: the organization's NDA first (view it, type your
/// full name, tick the box and sign, or see when you signed it), then your own
/// uploads in the six categories the API accepts, with download and delete.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  /// The categories documents.validator.js accepts (less the NDA template).
  static const List<String> _categories = [
    'identity',
    'address',
    'education',
    'experience',
    'bank_passbook',
    'other',
  ];

  String _selectedCategory = 'identity';

  PlatformFile? _selectedFile;

  final TextEditingController _signedNameController = TextEditingController();
  bool _agreed = false;
  String? _ndaFormError;

  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      ref.read(documentProvider.notifier).loadAll();
    });
  }

  @override
  void dispose() {
    _signedNameController.dispose();
    super.dispose();
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'jpeg', 'png', 'webp'],
      );

      if (result.isEmpty) return;

      final file = result.first;

      if (file.path == null || file.path!.isEmpty) {
        _showMessage(ref.tr('documents.unableAccessFile'));
        return;
      }

      setState(() {
        _selectedFile = file;
      });
    } catch (e) {
      _showMessage(ref.tr('documents.unableSelectFile'));
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedFile == null) {
      _showMessage(ref.tr('documents.chooseDocumentFirst'));
      return;
    }

    final filePath = _selectedFile!.path;

    if (filePath == null || filePath.isEmpty) {
      _showMessage(ref.tr('documents.invalidFileSelected'));
      return;
    }

    final success = await ref
        .read(documentProvider.notifier)
        .uploadDocument(filePath: filePath, category: _selectedCategory);

    if (!mounted) return;

    if (success) {
      setState(() {
        _selectedFile = null;
      });

      _showMessage(ref.tr('documents.uploadSuccess'));
    } else {
      final message = ref.read(documentProvider).errorMessage;

      _showMessage(message ?? ref.tr('documents.unableUpload'));
    }
  }

  Future<void> _download(int id, String fileName) async {
    final filePath = await ref
        .read(documentProvider.notifier)
        .downloadDocument(id, fileName: fileName);

    if (!mounted) return;

    if (filePath != null) {
      _showMessage(
        fill(ref.tr('docx.savedTo'), {'path': filePath}),
      );
    } else {
      final error = ref.read(documentProvider).errorMessage;

      _showMessage(error ?? ref.tr('documents.unableDownload'));
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await confirmAction(
      context,
      title: ref.tr('docx.deleteTitle'),
      message: ref.tr('docx.deleteMessage'),
      confirmLabel: ref.tr('common.delete'),
      cancelLabel: ref.tr('common.cancel'),
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    final error = await ref.read(documentProvider.notifier).deleteDocument(id);

    if (!mounted) return;

    _showMessage(error ?? ref.tr('docx.deleted'));
  }

  Future<void> _signNda() async {
    final name = _signedNameController.text.trim();

    if (name.length < 2) {
      setState(() => _ndaFormError = ref.tr('docx.typeFullName'));
      return;
    }

    if (!_agreed) {
      setState(() => _ndaFormError = ref.tr('docx.mustAgree'));
      return;
    }

    setState(() => _ndaFormError = null);

    final error = await ref.read(documentProvider.notifier).signNda(name);

    if (!mounted) return;

    if (error != null) {
      setState(() => _ndaFormError = error);
      return;
    }

    _signedNameController.clear();
    setState(() => _agreed = false);
    _showMessage(ref.tr('docx.ndaSigned'));
  }

  String _categoryLabel(String category) {
    switch (category) {
      case 'identity':
        return ref.tr('documents.identityProof');
      case 'address':
        return ref.tr('documents.addressProof');
      case 'education':
        return ref.tr('docx.education');
      case 'experience':
        return ref.tr('docx.experience');
      case 'bank_passbook':
        return ref.tr('documents.bankPassbook');
      case 'nda_template':
        return ref.tr('documents.ndaAgreement');
      default:
        return ref.tr('documents.other');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final documentState = ref.watch(documentProvider);

    return Scaffold(
      backgroundColor: AppColors.whiteBackgroundColor,

      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.appBarColor,
        surfaceTintColor: AppColors.appBarColor,
        foregroundColor: AppColors.onAppBarColor,
        bottom: const TricolourStrip(),
      ),

      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(documentProvider.notifier).loadAll(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ref.tr('documents.title'),
                  style: GoogleFonts.inter(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  ref.tr('documents.documentsSubtitle'),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    height: 1.35,
                    color: const Color(0xFF696269),
                  ),
                ),

                const SizedBox(height: 16),

                _buildNdaCard(documentState),

                const SizedBox(height: 16),

                _buildUploadCard(
                  isUploading:
                      documentState.status == DocumentStatus.uploading,
                ),

                const SizedBox(height: 24),

                Text(
                  ref.tr('documents.yourDocuments'),
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
      ),
    );
  }

  // ============================================================
  // NDA
  // ============================================================

  Widget _buildNdaCard(DocumentState state) {
    final template = state.ndaTemplate;
    final signedAt = state.ndaSignedAt;

    final (String badge, ChipTone tone) = template == null
        ? (ref.tr('documents.notAvailable'), ChipTone.neutral)
        : signedAt != null
        ? (ref.tr('docx.signed'), ChipTone.success)
        : (ref.tr('docx.actionNeeded'), ChipTone.warning);

    Widget body;

    if (state.isLoadingNda && state.nda == null) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (state.ndaError != null && state.nda == null) {
      body = ErrorBanner(state.ndaError!);
    } else if (template == null) {
      body = Text(
        ref.tr('documents.ndaNotUploaded'),
        style: GoogleFonts.inter(fontSize: 12, color: AppColors.mutedColor),
      );
    } else {
      final templateId = toInt(template['id']);
      final templateName =
          template['fileName']?.toString() ?? ref.tr('documents.ndaAgreement');
      final downloading =
          templateId != null && state.busyId == templateId;

      final viewButton = OutlinedButton.icon(
        onPressed: templateId == null || downloading
            ? null
            : () => _download(templateId, templateName),
        icon: downloading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded, size: 18),
        label: Text(ref.tr('docx.viewDocument')),
      );

      if (signedAt != null) {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fill(ref.tr('docx.signedOn'), {
                'date': formatApiDate(signedAt),
              }),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 8),
            viewButton,
          ],
        );
      } else {
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ref.tr('docx.readThenSign'),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.mutedColor,
              ),
            ),
            const SizedBox(height: 8),
            viewButton,
            const SizedBox(height: 12),
            if (_ndaFormError != null) ...[
              ErrorBanner(_ndaFormError!),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _signedNameController,
              textCapitalization: TextCapitalization.words,
              decoration: featureInputDecoration(ref.tr('docx.typeFullName')),
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              value: _agreed,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              onChanged: (value) => setState(() => _agreed = value ?? false),
              title: Text(
                ref.tr('docx.agreeToNda'),
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: AppColors.textColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            AbsorbPointer(
              absorbing: state.isSigning,
              child: Opacity(
                opacity: state.isSigning ? 0.6 : 1,
                child: WorkforcePrimaryButton(
                  title: state.isSigning
                      ? ref.tr('docx.signing')
                      : ref.tr('docx.signNda'),
                  onPressed: _signNda,
                ),
              ),
            ),
          ],
        );
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  ref.tr('documents.ndaAgreement'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textColor,
                  ),
                ),
              ),
              if (!(state.isLoadingNda && state.nda == null))
                StatusChip(label: badge, tone: tone),
            ],
          ),

          const SizedBox(height: 9),

          body,
        ],
      ),
    );
  }

  // ============================================================
  // UPLOAD
  // ============================================================

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
            ref.tr('documents.uploadDocument'),
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
                title: isUploading
                    ? ref.tr('documents.uploading')
                    : ref.tr('documents.upload'),
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
          value: _selectedCategory,
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
          items: _categories.map((category) {
            return DropdownMenuItem<String>(
              value: category,
              child: Text(_categoryLabel(category)),
            );
          }).toList(),
          onChanged: (value) {
            if (value == null) return;

            setState(() {
              _selectedCategory = value;
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
                ref.tr('documents.chooseFile'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: AppColors.mutedColor,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                _selectedFile?.name ?? ref.tr('documents.noFileChosen'),
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

  // ============================================================
  // LIST
  // ============================================================

  Widget _buildDocumentsList(DocumentState state) {
    if (state.status == DocumentStatus.loading && state.documents.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.status == DocumentStatus.error && state.documents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          state.errorMessage ?? ref.tr('documents.unableLoad'),
          style: GoogleFonts.inter(fontSize: 11, color: Colors.red),
        ),
      );
    }

    if (state.documents.isEmpty) {
      return Text(
        ref.tr('documents.noDocuments'),
        style: GoogleFonts.inter(fontSize: 11, color: AppColors.mutedColor),
      );
    }

    return Column(
      children: state.documents.map((document) {
        return _buildDocumentItem(document, state.busyId);
      }).toList(),
    );
  }

  Widget _buildDocumentItem(Map<String, dynamic> document, int? busyId) {
    final fileName =
        document['fileName']?.toString() ?? ref.tr('documents.document');

    final category = document['category']?.toString() ?? '';

    final createdAt = document['createdAt'];

    final id = toInt(document['id']);

    final busy = id != null && busyId == id;

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
              color: AppColors.primaryFillColor.withValues(alpha: 0.1),
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

                const SizedBox(height: 4),

                Text(
                  [
                    _categoryLabel(category),
                    if (createdAt != null) formatApiDate(createdAt),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: AppColors.mutedColor,
                  ),
                ),
              ],
            ),
          ),

          if (busy)
            const Padding(
              padding: EdgeInsets.all(8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else ...[
            _iconButton(
              icon: Icons.download,
              color: AppColors.mutedColor,
              tooltip: ref.tr('docx.download'),
              onTap: id == null ? null : () => _download(id, fileName),
            ),
            const SizedBox(width: 6),
            _iconButton(
              icon: Icons.delete_outline_rounded,
              color: const Color(0xFFB3261E),
              tooltip: ref.tr('common.delete'),
              onTap: id == null ? null : () => _delete(id),
            ),
          ],
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
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
}
