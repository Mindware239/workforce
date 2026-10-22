import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/features/profile/data/document_repository.dart';

enum DocumentStatus {
  initial,
  loading,
  loaded,
  uploading,
  downloading,
  error,
}

class DocumentState {
  final DocumentStatus status;
  final List<Map<String, dynamic>> documents;
  final String? errorMessage;
  final bool isDownloading;
  final String? downloadedFilePath;

  /// The organization's NDA: `template` (or null when none is uploaded) and
  /// `signedAt` (null until this account signs it).
  final Map<String, dynamic>? nda;
  final bool isLoadingNda;
  final String? ndaError;
  final bool isSigning;

  /// The document a download or delete is running for.
  final int? busyId;

  const DocumentState({
    this.status = DocumentStatus.initial,
    this.documents = const [],
    this.errorMessage,
    this.isDownloading = false,
    this.downloadedFilePath,
    this.nda,
    this.isLoadingNda = false,
    this.ndaError,
    this.isSigning = false,
    this.busyId,
  });

  Map<String, dynamic>? get ndaTemplate {
    final template = nda?['template'];

    return template is Map ? Map<String, dynamic>.from(template) : null;
  }

  String? get ndaSignedAt => nda?['signedAt']?.toString();

  DocumentState copyWith({
    DocumentStatus? status,
    List<Map<String, dynamic>>? documents,
    String? errorMessage,
    bool? isDownloading,
    String? downloadedFilePath,
    Map<String, dynamic>? nda,
    bool? isLoadingNda,
    String? ndaError,
    bool? isSigning,
    int? busyId,
    bool clearBusy = false,
    bool clearNdaError = false,
    bool clearError = false,
    bool clearDownloadedFilePath = false,
  }) {
    return DocumentState(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : downloadedFilePath ?? this.downloadedFilePath,
      nda: nda ?? this.nda,
      isLoadingNda: isLoadingNda ?? this.isLoadingNda,
      ndaError: clearNdaError ? null : ndaError ?? this.ndaError,
      isSigning: isSigning ?? this.isSigning,
      busyId: clearBusy ? null : busyId ?? this.busyId,
    );
  }
}

class DocumentNotifier extends StateNotifier<DocumentState> {
  final DocumentRepository repository;

  DocumentNotifier({required this.repository}) : super(const DocumentState());

  Future<void> loadAll() async {
    await Future.wait([fetchDocuments(), loadNda()]);
  }

  Future<void> fetchDocuments() async {
    state = state.copyWith(status: DocumentStatus.loading, clearError: true);

    try {
      final documents = await repository.getMyDocuments();

      state = state.copyWith(
        status: DocumentStatus.loaded,
        documents: documents,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: DocumentStatus.error,
        errorMessage: cleanErrorMessage(e),
      );
    }
  }

  Future<void> loadNda() async {
    state = state.copyWith(isLoadingNda: true, clearNdaError: true);

    try {
      final nda = await repository.getNdaTemplate();

      state = state.copyWith(isLoadingNda: false, nda: nda);
    } catch (e) {
      state = state.copyWith(
        isLoadingNda: false,
        ndaError: cleanErrorMessage(e),
      );
    }
  }

  /// Null on success, otherwise the reason.
  Future<String?> signNda(String signedName) async {
    state = state.copyWith(isSigning: true);

    try {
      final nda = await repository.signNda(signedName);

      state = state.copyWith(
        isSigning: false,
        nda: nda.isEmpty ? null : nda,
      );

      if (nda.isEmpty) await loadNda();

      return null;
    } catch (e) {
      state = state.copyWith(isSigning: false);

      return cleanErrorMessage(e);
    }
  }

  Future<bool> uploadDocument({
    required String filePath,
    required String category,
  }) async {
    state = state.copyWith(status: DocumentStatus.uploading, clearError: true);

    try {
      await repository.uploadDocument(filePath: filePath, category: category);

      final documents = await repository.getMyDocuments();

      state = state.copyWith(
        status: DocumentStatus.loaded,
        documents: documents,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: DocumentStatus.error,
        errorMessage: cleanErrorMessage(e),
      );

      return false;
    }
  }

  /// Null on success, otherwise the reason.
  Future<String?> deleteDocument(int documentId) async {
    state = state.copyWith(busyId: documentId);

    try {
      await repository.deleteDocument(documentId);

      state = state.copyWith(
        clearBusy: true,
        documents: state.documents
            .where((doc) => doc['id']?.toString() != documentId.toString())
            .toList(),
      );

      return null;
    } catch (e) {
      state = state.copyWith(clearBusy: true);

      return cleanErrorMessage(e);
    }
  }

  Future<String?> downloadDocument(int documentId, {String? fileName}) async {
    state = state.copyWith(
      isDownloading: true,
      busyId: documentId,
      clearError: true,
      clearDownloadedFilePath: true,
    );

    try {
      final filePath = await repository.downloadDocument(
        documentId: documentId,
        fileName: fileName,
      );

      state = state.copyWith(
        isDownloading: false,
        clearBusy: true,
        downloadedFilePath: filePath,
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        isDownloading: false,
        clearBusy: true,
        errorMessage: cleanErrorMessage(e),
      );

      return null;
    }
  }
}

final documentProvider =
    StateNotifierProvider<DocumentNotifier, DocumentState>((ref) {
  return DocumentNotifier(repository: ref.read(documentRepositoryProvider));
});
