import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';

class RouteData {
  final List<LatLng> polyline;
  final List<RouteStep> steps;

  RouteData({required this.polyline, required this.steps});
}

class RouteStep {
  final String instruction;
  final double distance;
  final LatLng location;

  RouteStep({required this.instruction, required this.distance, required this.location});
}

class RouteService {
  /// Fetches routing data with timeout and secure endpoint management.
  Future<RouteData?> getRoute(LatLng start, LatLng end) async {
    final url = Uri.parse(
      '${ApiConfig.osrmBaseUrl}/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full&steps=true',
    );

    try {
      final response = await http.get(url).timeout(ApiConfig.requestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          
          final List<dynamic> coords = route['geometry']['coordinates'];
          final polyline = coords.map((coord) => LatLng(coord[1], coord[0])).toList();

          final List<RouteStep> steps = [];
          for (var leg in route['legs']) {
            for (var step in leg['steps']) {
              final loc = step['maneuver']['location'];
              steps.add(RouteStep(
                instruction: step['maneuver']['instruction'] ?? 'Continue',
                distance: (step['distance'] as num).toDouble(),
                location: LatLng(loc[1], loc[0]),
              ));
            }
          }

          return RouteData(polyline: polyline, steps: steps);
        }
      }
    } catch (e) {
      debugPrint('Route Error: ${e.toString()}');
    }
    return null;
  }
}
