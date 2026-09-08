import 'dart:convert';

import 'package:workforce/core/services/secure_storage.dart';

class LocationQueue {
  static const String _key = 'workforce_location_queue';

  final SecureStorage storage;

  LocationQueue({
    required this.storage,
  });

  Future<List<Map<String, dynamic>>> getAll() async {
    final raw = await storage.read(
      key: _key,
    );

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! List) {
        return [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => Map<String, dynamic>.from(item),
          )
          .toList();
    } catch (e) {
      print(
        '❌ Failed to read location queue: $e',
      );

      return [];
    }
  }

  Future<void> add(
    Map<String, dynamic> location,
  ) async {
    final locations = await getAll();

    locations.add(location);

    await storage.write(
      key: _key,
      value: jsonEncode(locations),
    );
  }

  Future<void> replace(
    List<Map<String, dynamic>> locations,
  ) async {
    await storage.write(
      key: _key,
      value: jsonEncode(locations),
    );
  }

  Future<void> clear() async {
    await storage.delete(
      key: _key,
    );

    print(
      '🗑️ Location queue cleared.',
    );
  }
}