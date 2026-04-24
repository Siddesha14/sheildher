import 'package:background_sms/background_sms.dart';
import 'package:geolocator/geolocator.dart';
import 'contact_service.dart';
import 'location_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class SosDispatchResult {
  const SosDispatchResult({
    required this.contactsCount,
    required this.sentCount,
    this.errorMessage,
  });

  final int contactsCount;
  final int sentCount;
  final String? errorMessage;
}

class SmsService {
  final ContactService _contactService = ContactService();
  final LocationService _locationService = LocationService();

  Future<SosDispatchResult> sendEmergencySms() async {
    try {
      final contacts = await _contactService.getEmergencyContacts();
      if (contacts.isEmpty) {
        return const SosDispatchResult(contactsCount: 0, sentCount: 0);
      }

      final smsPermission = await Permission.sms.request();
      if (!smsPermission.isGranted) {
        return const SosDispatchResult(
          contactsCount: 0,
          sentCount: 0,
          errorMessage: 'SMS permission denied.',
        );
      }

      final Position? position = await _locationService.getCurrentLocation();
      String message = "EMERGENCY: I need help!";
      if (position != null) {
        message += " My location: https://maps.google.com/?q=${position.latitude},${position.longitude}";
      }

      var sentCount = 0;
      for (var contact in contacts) {
        String? phone = contact['phone'];
        if (phone != null && phone.trim().isNotEmpty) {
          final normalizedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
          SmsStatus result = await BackgroundSms.sendMessage(
            phoneNumber: normalizedPhone,
            message: message,
          );
          if (result == SmsStatus.sent) {
            sentCount += 1;
            debugPrint("Sent SMS to $normalizedPhone");
          } else {
            debugPrint("Failed to send SMS to $normalizedPhone");
          }
        }
      }

      return SosDispatchResult(contactsCount: contacts.length, sentCount: sentCount);
    } catch (e) {
      debugPrint("Error sending SMS: $e");
      return SosDispatchResult(
        contactsCount: 0,
        sentCount: 0,
        errorMessage: 'Failed to send emergency SMS.',
      );
    }
  }
}
