import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';

/// The employee's documents (`/api/documents`), as the web Documents page
/// uses them: the organization's NDA (read, type your name, sign), the
/// employee's own uploads, download and delete.
class DocumentRepository {
  final ApiClient apiClient;

  DocumentRepository({required this.apiClient});

  /// GET /api/documents/mine
  Future<List<Map<String, dynamic>>> getMyDocuments() async {
    try {
      final response = await apiClient.get('/documents/mine');

      return asMapList(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to load documents.');
    }
  }

  /// POST /api/documents (multipart: file, category)
  ///
  /// category: identity | address | education | experience | bank_passbook | other
  Future<Map<String, dynamic>> uploadDocument({
    required String filePath,
    required String category,
  }) async {
    try {
      final fileName = filePath.split(RegExp(r'[\\/]')).last;

      final formData = FormData.fromMap({
        'category': category,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await apiClient.dio.post('/documents', data: formData);

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Unable to upload document.');
    }
  }

  /// DELETE /api/documents/:id
  Future<void> deleteDocument(int documentId) async {
    try {
      await apiClient.delete('/documents/$documentId');
    } catch (e) {
      throw apiException(e, 'Could not delete that document.');
    }
  }

  /// GET /api/documents/nda-template
  ///
  /// `{ template: {id, fileName, ...} | null, signedAt: string | null }`.
  Future<Map<String, dynamic>> getNdaTemplate() async {
    try {
      final response = await apiClient.get('/documents/nda-template');

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not load the NDA.');
    }
  }

  /// POST /api/documents/nda-template/sign  `{ signedName }`
  Future<Map<String, dynamic>> signNda(String signedName) async {
    try {
      final response = await apiClient.post(
        '/documents/nda-template/sign',
        data: {'signedName': signedName},
      );

      return asMap(unwrapData(response.data));
    } catch (e) {
      throw apiException(e, 'Could not sign the NDA.');
    }
  }

  /// GET /api/documents/:id/download — saved to the Download folder
  /// (Android), falling back to the app documents folder. Returns the path.
  Future<String> downloadDocument({
    required int documentId,
    String? fileName,
  }) async {
    try {
      final response = await apiClient.dio.get<List<int>>(
        '/documents/$documentId/download',
        options: Options(responseType: ResponseType.bytes),
      );

      var name = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : 'document_$documentId';

      final contentDisposition = response.headers.value('content-disposition');

      if ((fileName == null || fileName.trim().isEmpty) &&
          contentDisposition != null) {
        final match = RegExp(
          r'filename="?([^"]+)"?',
          caseSensitive: false,
        ).firstMatch(contentDisposition);

        if (match != null && match.group(1) != null) {
          name = match.group(1)!;
        }
      }

      Directory directory = Directory('/storage/emulated/0/Download');

      if (!Platform.isAndroid || !await directory.exists()) {
        directory = await getApplicationDocumentsDirectory();
      }

      final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${directory.path}/$safeName');

      await file.writeAsBytes(response.data ?? const [], flush: true);

      return file.path;
    } catch (e) {
      throw apiException(e, 'Unable to download document.');
    }
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(apiClient: ref.read(apiClientProvider));
});
