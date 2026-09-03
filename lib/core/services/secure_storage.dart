import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user';

  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await storage.write(key: _tokenKey, value: token);
  }

  Future<void> saveUser(Map<String, dynamic> user) async {
    await storage.write(key: _userKey, value: jsonEncode(user));
  }

  Future<Map<String, dynamic>?> getUser() async {
    final value = await storage.read(key: _userKey);

    if (value == null || value.isEmpty) {
      return null;
    }

    return Map<String, dynamic>.from(jsonDecode(value));
  }

  Future<String?> getToken() async {
    return storage.read(key: _tokenKey);
  }

  Future<void> deleteToken() async {
    await storage.delete(key: _tokenKey);
  }

  // Logout: remove token and user data
  Future<void> clearAuth() async {
    await storage.delete(key: _tokenKey);
    await storage.delete(key: _userKey);
  }
}
