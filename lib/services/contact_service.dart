import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ContactService {
  static const String _contactsKey = 'emergency_contacts';

  Future<bool> requestPermission() async {
    return await FlutterContacts.requestPermission(readonly: true);
  }

  Future<List<Contact>> getDeviceContacts() async {
    if (await requestPermission()) {
      return await FlutterContacts.getContacts(withProperties: true);
    }
    return [];
  }

  Future<void> saveEmergencyContacts(List<Map<String, String>> contacts) async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(contacts);
    await prefs.setString(_contactsKey, encodedData);
  }

  Future<List<Map<String, String>>> getEmergencyContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_contactsKey);
    if (data != null) {
      final List<dynamic> decodedData = jsonDecode(data);
      return decodedData.map((e) => Map<String, String>.from(e)).toList();
    }
    return [];
  }
}
