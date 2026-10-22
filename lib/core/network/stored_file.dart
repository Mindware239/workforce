import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/api_error.dart';
import 'package:workforce/core/network/network_providers.dart';
import 'package:workforce/core/styles/app_colors.dart';

/// Uploaded files (receipts, asset photos, ...) served by the signed-in
/// `GET /api/files/<relative path>` endpoint, which checks who may see each
/// one. `Image.network` cannot send the Authorization header, so the bytes are
/// fetched through [ApiClient] (whose interceptor adds the bearer token) and
/// shown with `Image.memory`.
///
/// `path` is the stored path relative to the upload root, as the API returns
/// it (e.g. `expenses/12/1700000000-receipt.jpg`).
String storedFileEndpoint(String path) {
  final segments = path
      .split('/')
      .where((part) => part.isNotEmpty)
      .map(Uri.encodeComponent)
      .join('/');

  return '/files/$segments';
}

Future<Uint8List> fetchStoredFile(ApiClient apiClient, String path) async {
  try {
    final response = await apiClient.dio.get<List<int>>(
      storedFileEndpoint(path),
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data ?? const []);
  } catch (e) {
    throw apiException(e, 'Unable to load the file.');
  }
}

/// Saves a stored file to the device's Download folder (Android), falling
/// back to the app documents folder, and returns where it went.
Future<String> saveStoredFile(
  ApiClient apiClient, {
  required String path,
  required String fileName,
}) async {
  final bytes = await fetchStoredFile(apiClient, path);

  Directory directory = Directory('/storage/emulated/0/Download');

  if (!Platform.isAndroid || !await directory.exists()) {
    directory = await getApplicationDocumentsDirectory();
  }

  final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  final file = File('${directory.path}/$safeName');

  await file.writeAsBytes(bytes, flush: true);

  return file.path;
}

/// Bytes of one stored file, cached for the session by path.
final storedFileBytesProvider =
    FutureProvider.autoDispose.family<Uint8List, String>((ref, path) {
  return fetchStoredFile(ref.read(apiClientProvider), path);
});

/// An image from `/api/files`, loaded with the auth header.
class StoredFileImage extends ConsumerWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? fallback;

  const StoredFileImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.fallback,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(storedFileBytesProvider(path));

    return bytes.when(
      data: (data) => Image.memory(
        data,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _fallback(),
      ),
      loading: () => SizedBox(
        width: width,
        height: height,
        child: const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      error: (_, _) => _fallback(),
    );
  }

  Widget _fallback() {
    return fallback ??
        SizedBox(
          width: width,
          height: height,
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: AppColors.mutedColor,
            ),
          ),
        );
  }
}
