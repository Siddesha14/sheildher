import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'security_service.dart';

/// Model representing a sensitive SOS alert.
/// Designed for ephemeral storage (Privacy-First).
class SosAlert {
  final String id;
  final double lat;
  final double lng;
  final int timestamp;
  final String status; // "active" or "resolved"

  SosAlert({
    required this.id,
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.status = "active",
  });

  Map<String, dynamic> toJson() => {
    "lat": lat,
    "lng": lng,
    "timestamp": timestamp,
    "status": status,
  };

  factory SosAlert.fromJson(String id, Map<dynamic, dynamic> json) {
    return SosAlert(
      id: id,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      timestamp: json['timestamp'] as int,
      status: json['status'] as String? ?? "active",
    );
  }
}

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  final SecurityService _securityService = SecurityService();

  /// Saves an SOS alert with a timestamp for automatic cleanup.
  Future<void> sendSosAlert(double lat, double lng) async {
    try {
      await _securityService.ensureAuthenticated();
      final user = _securityService.currentUser;
      if (user == null) return;

      final alertRef = _dbRef.child("alerts").child(user.uid).push();
      final alert = SosAlert(
        id: alertRef.key!,
        lat: lat,
        lng: lng,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await alertRef.set(alert.toJson());
      debugPrint('Firebase: SOS Alert stored (Ephemeral)');
    } catch (e) {
      debugPrint('Firebase Error (Send SOS): ${e.toString()}');
    }
  }

  /// Client-side Fallback: Cleans up expired alerts (older than 5 mins) locally.
  /// This ensures privacy even if Cloud Functions have high latency.
  Future<void> runClientSideCleanup() async {
    try {
      final user = _securityService.currentUser;
      if (user == null) return;

      final snapshot = await _dbRef.child("alerts").child(user.uid).get();
      if (!snapshot.exists) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      const fiveMinutes = 5 * 60 * 1000;

      final Map<dynamic, dynamic> alerts = snapshot.value as Map<dynamic, dynamic>;
      
      for (var entry in alerts.entries) {
        final alertId = entry.key;
        final data = entry.value as Map<dynamic, dynamic>;
        final timestamp = data['timestamp'] as int;
        final status = data['status'] as String? ?? "active";

        // Deletion Criteria: Older than 5 mins OR already resolved
        if (now - timestamp > fiveMinutes || status == "resolved") {
          await _dbRef.child("alerts").child(user.uid).child(alertId).remove();
          debugPrint('Firebase Cleanup: Removed expired alert $alertId');
        }
      }
    } catch (e) {
      debugPrint('Firebase Error (Cleanup): ${e.toString()}');
    }
  }
}
