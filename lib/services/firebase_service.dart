import 'package:firebase_database/firebase_database.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  String? _deviceId;

  FirebaseService() {
    _initDeviceId();
  }

  Future<void> _initDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor;
    }
  }

  // Community mesh features removed as per user request to prevent intruders from receiving notifications.
  // This service is now a shell for future non-broadcast Firebase features.
}
