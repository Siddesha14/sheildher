import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class LocationSearchResult {
  final String name;
  final LatLng location;

  LocationSearchResult({required this.name, required this.location});
}

class SearchService {
  Future<List<LocationSearchResult>> searchLocations(String query) async {
    if (query.isEmpty) return [];
    
    // Restricting search to Bangalore area for better relevance
    String searchQuery = query;
    if (!query.toLowerCase().contains('bangalore')) {
      searchQuery = '$query, Bangalore';
    }

    const String bangaloreViewbox = '77.34,13.17,77.85,12.73'; // lon1,lat1,lon2,lat2
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(searchQuery)}&format=json&limit=15&addressdetails=1&viewbox=$bangaloreViewbox&bounded=1&namedetails=1',
    );

    try {
      print('Searching for: $query');
      final response = await http.get(url, headers: {
        'User-Agent': 'ShieldHerSafetyApp_v1_Development', 
      });

      print('Search response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        print('Found ${data.length} results');
        return data.map((item) {
          return LocationSearchResult(
            name: item['display_name'],
            location: LatLng(
              double.parse(item['lat']),
              double.parse(item['lon']),
            ),
          );
        }).toList();
      } else {
        print('Search failed with status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error searching locations: $e');
    }
    return [];
  }
}
