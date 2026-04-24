import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationUtils {
  static double calculateDistance(LatLng p1, LatLng p2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 - c((p2.latitude - p1.latitude) * p) / 2 +
        c(p1.latitude * p) * c(p2.latitude * p) *
            (1 - c((p2.longitude - p1.longitude) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000; // Distance in meters
  }

  static double getDistanceFromPolyline(LatLng point, List<LatLng> polyline) {
    if (polyline.isEmpty) return double.infinity;
    
    double minDistance = double.infinity;
    for (int i = 0; i < polyline.length - 1; i++) {
      double dist = _distToSegment(point, polyline[i], polyline[i + 1]);
      if (dist < minDistance) {
        minDistance = dist;
      }
    }
    return minDistance;
  }

  static double _distToSegment(LatLng p, LatLng v, LatLng w) {
    double l2 = _dist2(v, w);
    if (l2 == 0) return calculateDistance(p, v);
    double t = ((p.latitude - v.latitude) * (w.latitude - v.latitude) +
            (p.longitude - v.longitude) * (w.longitude - v.longitude)) /
        l2;
    t = max(0, min(1, t));
    return calculateDistance(
        p,
        LatLng(v.latitude + t * (w.latitude - v.latitude),
            v.longitude + t * (w.longitude - v.longitude)));
  }

  static double _dist2(LatLng v, LatLng w) {
    return pow(v.latitude - w.latitude, 2).toDouble() + pow(v.longitude - w.longitude, 2).toDouble();
  }
}
