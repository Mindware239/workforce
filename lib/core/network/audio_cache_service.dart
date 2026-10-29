import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:workforce/core/network/api_client.dart';
import 'package:workforce/core/network/stored_file.dart';

/// Prepares and caches audio files locally for reliable in-app playback with AudioPlayer.
///
/// On the web, audio works because bytes are fetched via authenticated AJAX/blob
/// requests and turned into in-memory blob URLs. On mobile, AudioPlayer (ExoPlayer/AVPlayer)
/// streaming directly from an authenticated endpoint often fails with 401 Unauthorized
/// or 404 because HTTP headers aren't sent or endpoints don't support Range requests.
///
/// This service fetches the audio bytes with the authenticated [ApiClient], saves them
/// in the app's cache directory with the proper extension (.m4a, .webm, .mp3, etc.),
/// and returns the local file path for 100% reliable local playback.
class AudioCacheService {
  static Future<String> prepareAudio(ApiClient apiClient, String rawPath) async {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      throw Exception('Audio path is empty');
    }

    // 1. If it is already a valid local file on the device
    if (trimmed.startsWith('/') || trimmed.startsWith('file://')) {
      final localPath = trimmed.replaceFirst('file://', '');
      if (await File(localPath).exists()) {
        return localPath;
      }
    }

    final tempDir = await getTemporaryDirectory();
    final hash = trimmed.hashCode.toRadixString(16).replaceAll('-', 'm');

    // Determine extension from filename or default to .m4a
    String ext = '.m4a';
    final lower = trimmed.toLowerCase();
    if (lower.contains('.webm')) {
      ext = '.webm';
    } else if (lower.contains('.mp3')) {
      ext = '.mp3';
    } else if (lower.contains('.wav')) {
      ext = '.wav';
    } else if (lower.contains('.aac')) {
      ext = '.aac';
    } else if (lower.contains('.ogg')) {
      ext = '.ogg';
    }

    final cachedFile = File('${tempDir.path}/audio_cache_$hash$ext');

    // Reuse existing cache if available and non-empty
    if (await cachedFile.exists() && (await cachedFile.length()) > 0) {
      return cachedFile.path;
    }

    Uint8List bytes;

    // 2. Full HTTP / HTTPS URL
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final response = await apiClient.dio.get<List<int>>(
        trimmed,
        options: Options(responseType: ResponseType.bytes),
      );
      bytes = Uint8List.fromList(response.data ?? const []);
    } else {
      // 3. Stored relative path (e.g., "tasks/1/note.webm", "uploads/...", or just a filename)
      final cleanPath = trimmed
          .replaceFirst(RegExp(r'^/+'), '')
          .replaceFirst(RegExp(r'^uploads/'), '');

      bytes = await fetchStoredFile(apiClient, cleanPath);
    }

    if (bytes.isEmpty) {
      throw Exception('Downloaded audio file is empty');
    }

    await cachedFile.writeAsBytes(bytes, flush: true);
    return cachedFile.path;
  }
}
