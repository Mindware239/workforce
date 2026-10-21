import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final FlutterSecureStorage storage =
      const FlutterSecureStorage();

  // =========================================================
  // Generic secure storage
  // =========================================================

  Future<void> write({
    required String key,
    required String value,
  }) async {
    await storage.write(
      key: key,
      value: value,
    );
  }

  Future<String?> read({
    required String key,
  }) async {
    return storage.read(key: key);
  }

  Future<void> delete({
    required String key,
  }) async {
    await storage.delete(key: key);
  }

  // =========================================================
  // Auth token
  // =========================================================

  Future<void> saveToken(String token) async {
    await storage.write(
      key: _tokenKey,
      value: token,
    );
  }

  Future<String?> getToken() async {
    return storage.read(key: _tokenKey);
  }

  // =========================================================
  // User
  // =========================================================

  Future<void> saveUser(
    Map<String, dynamic> user,
  ) async {
    await storage.write(
      key: _userKey,
      value: jsonEncode(user),
    );
  }

  Future<Map<String, dynamic>?> getUser() async {
    final value = await storage.read(
      key: _userKey,
    );

    if (value == null || value.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(
      jsonDecode(value),
    );
  }

  // =========================================================
  // Clear authentication
  // =========================================================

  Future<void> deleteToken() async {
    await storage.delete(key: _tokenKey);
  }

  Future<void> clearAuth() async {
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _userKey);
  }
}