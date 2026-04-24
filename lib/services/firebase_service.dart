import 'package:firebase_database/firebase_database.dart';

class FirebaseService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  Future<void> sendSosAlert({required double lat, required double lng}) async {
    final alertData = {
      "lat": lat,
      "lng": lng,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "status": "active"
    };

    final newAlertRef = _dbRef.child("alerts").push();
    await newAlertRef.set(alertData);
  }
}
