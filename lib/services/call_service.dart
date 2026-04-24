import 'package:flutter/foundation.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:permission_handler/permission_handler.dart';

class CallService {
  Future<int> callEmergencyContacts(List<Map<String, String>> contacts) async {
    if (contacts.isEmpty) return 0;

    final phonePermission = await Permission.phone.request();
    if (!phonePermission.isGranted) {
      debugPrint('Phone permission denied.');
      return 0;
    }

    var callAttemptCount = 0;
    for (final contact in contacts) {
      final phone = contact['phone'];
      if (phone == null || phone.trim().isEmpty) continue;

      final normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (normalizedPhone.isEmpty) continue;

      final didCall = await FlutterPhoneDirectCaller.callNumber(normalizedPhone) ?? false;
      if (didCall) {
        callAttemptCount += 1;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    return callAttemptCount;
  }
}
