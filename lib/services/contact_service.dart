import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// ContactService manages emergency contacts with encrypted storage.
class ContactService {
  static const String _contactsKey = 'emergency_contacts';
  final StorageService _storage = StorageService();

  /// Robust permission handling with logging.
  Future<bool> requestPermission() async {
    try {
      return await FlutterContacts.requestPermission(readonly: true);
    } catch (e) {
      debugPrint('Contacts Error (Permission): ${e.toString()}');
      return false;
    }
  }

  /// Fetches contacts with try-catch to prevent crashes on restricted devices.
  Future<List<Contact>> getDeviceContacts() async {
    try {
      if (await requestPermission()) {
        return await FlutterContacts.getContacts(withProperties: true);
      }
    } catch (e) {
      debugPrint('Contacts Error (Fetch): ${e.toString()}');
    }
    return [];
  }

  /// Saves contacts using the encrypted StorageService.
  Future<void> saveEmergencyContacts(List<Map<String, String>> contacts) async {
    try {
      await _storage.saveData(_contactsKey, contacts);
    } catch (e) {
      debugPrint('Contacts Error (Save): ${e.toString()}');
    }
  }

  /// Retrieves contacts from encrypted storage.
  Future<List<Map<String, String>>> getEmergencyContacts() async {
    try {
      final data = await _storage.getData(_contactsKey);
      if (data != null && data is List) {
        return data.map((e) => Map<String, String>.from(e)).toList();
      }
    } catch (e) {
      debugPrint('Contacts Error (Retrieve): ${e.toString()}');
    }
    return [];
  }
}
