import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';

/// LocationService manages high-accuracy location fetching with robust permission checks.
class LocationService {
  
  /// Fetches the current position with fallback and error handling.
  Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location: Service is disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location: Permission denied.');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location: Permission permanently denied.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      debugPrint('Location Error (Fetch): ${e.toString()}');
      return null;
    }
  }

  /// Provides a stream of location updates with distance filtering for efficiency.
  Stream<Position> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    return Geolocator.getPositionStream(locationSettings: locationSettings).handleError((error) {
      debugPrint('Location Stream Error: ${error.toString()}');
    });
  }
}
