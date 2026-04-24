import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/foundation.dart';
import 'api_config.dart';

class LocationSearchResult {
  final String name;
  final LatLng location;
  final String? phoneNumber;
  final String? address;

  LocationSearchResult({
    required this.name, 
    required this.location,
    this.phoneNumber,
    this.address,
  });
}

class SearchService {
  /// Robust search for locations with multi-tier fallback and timeout handling.
  Future<List<LocationSearchResult>> searchLocations(String query) async {
    if (query.isEmpty) return [];
    
    final String bangaloreQuery = "$query, Bangalore";

    // Attempt 1: Google Places (Legacy)
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json?query=${Uri.encodeComponent(bangaloreQuery)}&location=12.9716,77.5946&radius=20000&key=${ApiConfig.googleMapsKey}',
    );

    try {
      final response = await http.get(url).timeout(ApiConfig.requestTimeout);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['results'] ?? [];
        if (results.isNotEmpty) {
          return results.map((item) {
            final loc = item['geometry']['location'];
            return LocationSearchResult(
              name: item['name'],
              location: LatLng(loc['lat'], loc['lng']),
              address: item['formatted_address'],
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Search Error (Google): ${e.toString()}');
    }

    // Attempt 2: OpenStreetMap Fallback
    final osmUrl = Uri.parse(
      '${ApiConfig.osmSearchUrl}?q=${Uri.encodeComponent(bangaloreQuery)}&format=json&limit=10&viewbox=77.3,13.2,77.8,12.7&bounded=1'
    );
    
    try {
      final response = await http.get(osmUrl, headers: {
        'User-Agent': 'ShieldHer-Production-App'
      }).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((item) {
          return LocationSearchResult(
            name: item['display_name'].split(',')[0],
            location: LatLng(double.parse(item['lat']), double.parse(item['lon'])),
            address: item['display_name'],
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Search Error (OSM): ${e.toString()}');
    }

    return [];
  }

  /// Securely fetches nearby safe zones using production API keys.
  Future<List<LocationSearchResult>> findNearbySafeZones(LatLng position) async {
    try {
      final results = await _tryPlacesApiNew(position, ApiConfig.googleMapsKey);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('SafeZone Error (Google): ${e.toString()}');
    }

    return await _findSafeZonesOSM(position);
  }

  Future<List<LocationSearchResult>> _tryPlacesApiNew(LatLng position, String key) async {
    final url = Uri.parse('https://places.googleapis.com/v1/places:searchNearby');
    final body = json.encode({
      "includedTypes": ["police", "hospital", "convenience_store", "gas_station"],
      "maxResultCount": 10,
      "locationRestriction": {
        "circle": {
          "center": {"latitude": position.latitude, "longitude": position.longitude},
          "radius": 5000.0
        }
      }
    });

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': key,
          'X-Goog-FieldMask': 'places.displayName,places.location,places.shortAddress'
        },
        body: body,
      ).timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List results = data['places'] ?? [];
        return results.map((item) {
          final loc = item['location'];
          return LocationSearchResult(
            name: item['displayName']['text'],
            location: LatLng(loc['latitude'], loc['longitude']),
            address: item['shortAddress'],
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('Search Error (Places New): ${e.toString()}');
    }
    return [];
  }

  Future<List<LocationSearchResult>> _findSafeZonesOSM(LatLng position) async {
    final double lat = position.latitude;
    final double lon = position.longitude;
    final String viewbox = '${lon - 0.1},${lat + 0.1},${lon + 0.1},${lat - 0.1}';
    
    final url = Uri.parse(
      '${ApiConfig.osmSearchUrl}?q=police+station&format=json&limit=5&viewbox=$viewbox&bounded=1'
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'ShieldHer-Production-App'
      }).timeout(ApiConfig.requestTimeout);
      
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          return data.map((item) {
            return LocationSearchResult(
              name: item['display_name'].split(',')[0],
              location: LatLng(double.parse(item['lat']), double.parse(item['lon'])),
              address: item['display_name'],
            );
          }).toList();
        }
      }
    } catch (e) {
      debugPrint('Search Error (OSM Backup): ${e.toString()}');
    }

    // Hardcoded safety net for Bangalore (BMS College area)
    if (lat > 12.9 && lat < 13.0 && lon > 77.5 && lon < 77.6) {
      return [
        LocationSearchResult(
          name: "Basavanagudi Police Station",
          location: const LatLng(12.9422, 77.5743),
          address: "Basavanagudi, Bengaluru, Karnataka",
        ),
      ];
    }

    return [];
  }
}
