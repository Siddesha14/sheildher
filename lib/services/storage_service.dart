import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// StorageService provides an encrypted local storage layer using device keystore.
/// This is essential for protecting sensitive user data like contacts and settings.
class StorageService {
  // Singleton pattern for centralized access
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  /// Saves any data as an encrypted string. Sensitive data is JSON encoded first.
  Future<void> saveData(String key, dynamic value) async {
    try {
      String valueToStore;
      if (value is String) {
        valueToStore = value;
      } else {
        valueToStore = jsonEncode(value);
      }
      await _storage.write(key: key, value: valueToStore);
    } catch (e) {
      debugPrint('Storage Error (Save): ${e.toString()}');
      rethrow;
    }
  }

  /// Retrieves and decodes encrypted data.
  Future<dynamic> getData(String key) async {
    try {
      final value = await _storage.read(key: key);
      if (value == null) return null;
      
      try {
        return jsonDecode(value);
      } catch (_) {
        return value; // Return as raw string if not JSON
      }
    } catch (e) {
      debugPrint('Storage Error (Read): ${e.toString()}');
      return null;
    }
  }

  /// Permanently removes a specific key.
  Future<void> deleteData(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      debugPrint('Storage Error (Delete): ${e.toString()}');
    }
  }

  /// Wipes all local encrypted data (useful for logout/reset).
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      debugPrint('Storage Error (Clear): ${e.toString()}');
    }
  }
}
