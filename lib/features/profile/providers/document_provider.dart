import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  const DocumentState({
    this.status = DocumentStatus.initial,
    this.documents = const [],
    this.errorMessage,
    this.isDownloading = false,
    this.downloadedFilePath,
  });

  DocumentState copyWith({
    DocumentStatus? status,
    List<Map<String, dynamic>>? documents,
    String? errorMessage,
    bool? isDownloading,
    String? downloadedFilePath,
    bool clearError = false,
    bool clearDownloadedFilePath = false,
  }) {
    return DocumentState(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      errorMessage:
          clearError ? null : errorMessage ?? this.errorMessage,
      isDownloading:
          isDownloading ?? this.isDownloading,
      downloadedFilePath: clearDownloadedFilePath
          ? null
          : downloadedFilePath ?? this.downloadedFilePath,
    );
  }
}

class DocumentNotifier
    extends StateNotifier<DocumentState> {
  final DocumentRepository repository;

  DocumentNotifier({
    required this.repository,
  }) : super(const DocumentState());

  Future<void> fetchDocuments() async {
    state = state.copyWith(
      status: DocumentStatus.loading,
      clearError: true,
    );

    try {
      final documents =
          await repository.getMyDocuments();

      state = state.copyWith(
        status: DocumentStatus.loaded,
        documents: documents,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: DocumentStatus.error,
        errorMessage: _cleanError(e),
      );
    }
  }

  Future<bool> uploadDocument({
    required String filePath,
    required String category,
  }) async {
    state = state.copyWith(
      status: DocumentStatus.uploading,
      clearError: true,
    );

    try {
      await repository.uploadDocument(
        filePath: filePath,
        category: category,
      );

      // Refresh list after successful upload.
      final documents =
          await repository.getMyDocuments();

      state = state.copyWith(
        status: DocumentStatus.loaded,
        documents: documents,
        clearError: true,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        status: DocumentStatus.error,
        errorMessage: _cleanError(e),
      );

      return false;
    }
  }

  Future<String?> downloadDocument(
    int documentId,
  ) async {
    state = state.copyWith(
      status: DocumentStatus.downloading,
      isDownloading: true,
      clearError: true,
      clearDownloadedFilePath: true,
    );

    try {
      final filePath =
          await repository.downloadDocument(
        documentId: documentId,
      );

      state = state.copyWith(
        status: DocumentStatus.loaded,
        isDownloading: false,
        downloadedFilePath: filePath,
        clearError: true,
      );

      return filePath;
    } catch (e) {
      state = state.copyWith(
        status: DocumentStatus.error,
        isDownloading: false,
        errorMessage: _cleanError(e),
      );

      return null;
    }
  }

  String _cleanError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .trim();
  }
}

final documentProvider =
    StateNotifierProvider<DocumentNotifier, DocumentState>(
  (ref) {
    return DocumentNotifier(
      repository: ref.read(
        documentRepositoryProvider,
      ),
    );
  },
);