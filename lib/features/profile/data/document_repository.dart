import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/network_providers.dart';

class DocumentRepository {
  final ApiClient apiClient;

  DocumentRepository({
    required this.apiClient,
  });

  /// GET /api/documents/mine
  Future<List<Map<String, dynamic>>> getMyDocuments() async {
    try {
      final response = await apiClient.get(
        '/documents/mine',
      );

      debugPrint('========== MY DOCUMENTS RESPONSE ==========');
      debugPrint('${response.data}');
      debugPrint('===========================================');

      final data = response.data;

      if (data is List) {
        return data
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      }

      return [];
    } on DioException catch (e) {
      debugPrint('❌ Get documents error: ${e.message}');
      debugPrint('❌ Status: ${e.response?.statusCode}');
      debugPrint('❌ Response: ${e.response?.data}');

      final responseData = e.response?.data;

      if (responseData is Map<String, dynamic>) {
        if (responseData['message'] != null) {
          throw Exception(
            responseData['message'].toString(),
          );
        }
      }

      throw Exception(
        e.message ?? 'Unable to load documents.',
      );
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
        'file': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
        'category': category,
      });

      debugPrint('========== DOCUMENT UPLOAD ==========');
      debugPrint('File: $fileName');
      debugPrint('Path: $filePath');
      debugPrint('Category: $category');
      debugPrint('=====================================');

      final response = await apiClient.dio.post(
        '/documents',
        data: formData,
      );

      debugPrint('========== UPLOAD RESPONSE ==========');
      debugPrint('${response.data}');
      debugPrint('====================================');

      return Map<String, dynamic>.from(
        response.data,
      );
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

      throw Exception(
        e.message ?? 'Unable to upload document.',
      );
    }
  }
}

final documentRepositoryProvider =
    Provider<DocumentRepository>((ref) {
  return DocumentRepository(
    apiClient: ref.read(apiClientProvider),
  );
});