import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/features/profile/data/document_repository.dart';

enum DocumentStatus {
  initial,
  loading,
  loaded,
  uploading,
  error,
}

class DocumentState {
  final DocumentStatus status;
  final List<Map<String, dynamic>> documents;
  final String? errorMessage;

  const DocumentState({
    this.status = DocumentStatus.initial,
    this.documents = const [],
    this.errorMessage,
  });

  DocumentState copyWith({
    DocumentStatus? status,
    List<Map<String, dynamic>>? documents,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DocumentState(
      status: status ?? this.status,
      documents: documents ?? this.documents,
      errorMessage:
          clearError ? null : errorMessage ?? this.errorMessage,
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
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
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
        errorMessage: e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );

      return false;
    }
  }
}

final documentProvider = StateNotifierProvider<
    DocumentNotifier,
    DocumentState>((ref) {
  return DocumentNotifier(
    repository: ref.read(
      documentRepositoryProvider,
    ),
  );
});