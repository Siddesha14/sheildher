import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RouteService {
  Future<List<LatLng>?> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List<dynamic> coordinates = data['routes'][0]['geometry']['coordinates'];
          return coordinates.map((coord) => LatLng(coord[1], coord[0])).toList();
        }
      }
    } catch (e) {
      print('Error fetching route: $e');
    }
    return null;
  }
}
