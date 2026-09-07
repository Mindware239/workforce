import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';

class DocumentRepository {
  final ApiClient apiClient;

  DocumentRepository({required this.apiClient});

  /// GET /api/documents/mine
  Future<List<Map<String, dynamic>>> getMyDocuments() async {
    try {
      final response = await apiClient.get('/documents/mine');

      debugPrint('========== MY DOCUMENTS RESPONSE ==========');
      debugPrint('${response.data}');
      debugPrint('===========================================');

      final responseData = response.data;

      // API response:
      // {
      //   success: true,
      //   statusCode: 200,
      //   message: "Your documents",
      //   data: [...]
      // }

      if (responseData is Map) {
        final documents = responseData['data'];

        if (documents is List) {
          return documents
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }

      return [];
    } on DioException catch (e) {
      debugPrint('❌ Get documents error: ${e.message}');
      debugPrint('❌ Status: ${e.response?.statusCode}');
      debugPrint('❌ Response: ${e.response?.data}');

      final responseData = e.response?.data;

      if (responseData is Map) {
        final message = responseData['message'];

        if (message != null && message.toString().trim().isNotEmpty) {
          throw Exception(message.toString());
        }
      }

      throw Exception(e.message ?? 'Unable to load documents.');
    }
  }

  /// POST /api/documents
  ///
  /// multipart/form-data:
  /// file     -> binary
  /// category -> string
  Future<Map<String, dynamic>> uploadDocument({
    required String filePath,
    required String category,
  }) async {
    try {
      final fileName = filePath.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
        'category': category,
      });

      debugPrint('========== DOCUMENT UPLOAD ==========');
      debugPrint('File: $fileName');
      debugPrint('Path: $filePath');
      debugPrint('Category: $category');
      debugPrint('=====================================');

      final response = await apiClient.dio.post('/documents', data: formData);

      debugPrint('========== UPLOAD RESPONSE ==========');
      debugPrint('${response.data}');
      debugPrint('====================================');

      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      debugPrint('❌ Upload document error: ${e.message}');
      debugPrint('❌ Status: ${e.response?.statusCode}');
      debugPrint('❌ Response: ${e.response?.data}');

      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic>) {
        final message = responseData['message'];

        if (message != null) {
          throw Exception(message.toString());
        }
      }

      throw Exception(e.message ?? 'Unable to upload document.');
    }
  }

  Future<String> downloadDocument({required int documentId}) async {
    try {
      final response = await apiClient.dio.get(
        '/documents/$documentId/download',
        options: Options(responseType: ResponseType.bytes),
      );

      final contentDisposition = response.headers.value('content-disposition');

      String fileName = 'document_$documentId';

      if (contentDisposition != null) {
        final match = RegExp(
          r'filename="?([^"]+)"?',
          caseSensitive: false,
        ).firstMatch(contentDisposition);

        if (match != null && match.group(1) != null) {
          fileName = match.group(1)!;
        }
      }

      final directory = Directory('/storage/emulated/0/Download');

      final filePath = '${directory.path}/$fileName';

      final file = File(filePath);

      await file.writeAsBytes(response.data as List<int>, flush: true);

      return filePath;
    } on DioException catch (e) {
      debugPrint('========== DOCUMENT DOWNLOAD ERROR ==========');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      debugPrint('=============================================');

      final data = e.response?.data;

      if (data is Map && data['message'] != null) {
        throw Exception(data['message'].toString());
      }

      throw Exception(e.message ?? 'Unable to download document.');
    }
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>((ref) {
  return DocumentRepository(apiClient: ref.read(apiClientProvider));
});
