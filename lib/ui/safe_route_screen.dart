import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../services/sms_service.dart';
import '../services/search_service.dart';
import '../utils/location_utils.dart';

class SafeRouteScreen extends StatefulWidget {
  const SafeRouteScreen({super.key});

  @override
  State<SafeRouteScreen> createState() => _SafeRouteScreenState();
}

class _SafeRouteScreenState extends State<SafeRouteScreen> {
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final SmsService _smsService = SmsService();
  final SearchService _searchService = SearchService();
  
  final TextEditingController _searchController = TextEditingController();
  List<LocationSearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  bool _isMonitoring = false;
  StreamSubscription<Position>? _locationSubscription;
  double _deviationThreshold = 300.0; // 300 meters
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _initCurrentLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initCurrentLocation() async {
    final pos = await _locationService.getCurrentLocation();
    if (pos != null) {
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _updateMarkers();
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentLocation!, 15));
    }
  }

  void _updateMarkers() {
    _markers.clear();
    if (_currentLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('current'),
        position: _currentLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        infoWindow: const InfoWindow(title: 'Your Location'),
      ));
    }
    if (_destination != null) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destination!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }
    setState(() {});
  }

  Future<void> _performSearch(String query) async {
    _searchDebounce?.cancel();
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _isSearching = true);
      final results = await _searchService.searchLocations(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectSearchResult(LocationSearchResult result) {
    setState(() {
      _destination = result.location;
      _searchResults = [];
      _searchController.text = result.name;
      _updateMarkers();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(result.location, 15));
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;
    
    final points = await _routeService.getRoute(_currentLocation!, _destination!);
    if (points != null) {
      setState(() {
        _routePoints = points;
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: _routePoints,
            color: Colors.blue,
            width: 5,
          ),
        };
      });
      
      _fitRoute();
    }
  }

  void _fitRoute() {
    if (_routePoints.isEmpty) return;
    
    double minLat = _routePoints.first.latitude;
    double minLng = _routePoints.first.longitude;
    double maxLat = _routePoints.first.latitude;
    double maxLng = _routePoints.first.longitude;

    for (var point in _routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }

  void _startMonitoring() {
    if (_routePoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination and fetch route first.')),
      );
      return;
    }

    setState(() {
      _isMonitoring = true;
    });

    _locationSubscription = _locationService.getLocationStream().listen((Position position) {
      final currentPos = LatLng(position.latitude, position.longitude);
      setState(() {
        _currentLocation = currentPos;
        _updateMarkers();
      });

      double deviation = LocationUtils.getDistanceFromPolyline(currentPos, _routePoints);
      
      if (deviation > _deviationThreshold) {
        _triggerDeviationAlert(deviation);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Safe Route monitoring started.'), backgroundColor: Colors.green),
    );
  }

  void _stopMonitoring() {
    _locationSubscription?.cancel();
    setState(() {
      _isMonitoring = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Monitoring stopped.')),
    );
  }

  void _triggerDeviationAlert(double deviation) {
    _stopMonitoring(); 
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Route Deviation Detected!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text('You have deviated ${deviation.toStringAsFixed(0)} meters from your safe path. Sending SOS to emergency contacts...'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('OK'),
          )
        ],
      ),
    );

    _smsService.sendEmergencySms();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Route Deviation', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(12.9716, 77.5946),
              zoom: 12,
            ),
            onMapCreated: (controller) => _mapController = controller,
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            onLongPress: (latLng) {
              if (!_isMonitoring) {
                setState(() {
                  _destination = latLng;
                  _searchController.text = "Selected Point: ${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
                  _updateMarkers();
                });
              }
            },
          ),
          // Search Bar
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _performSearch,
                    decoration: InputDecoration(
                      hintText: 'Search destination...',
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF0078D4)),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchResults = []);
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Searching locations...', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                else if (_searchResults.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          title: Text(result.name, style: const TextStyle(fontSize: 14)),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  )
                else if (_searchController.text.length >= 3 && !_isSearching)
                   Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('No locations found.', style: TextStyle(color: Colors.grey)),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_destination == null)
                    const Text('Long press on map to set destination', style: TextStyle(color: Colors.grey))
                  else if (_routePoints.isEmpty)
                    ElevatedButton.icon(
                      onPressed: _fetchRoute,
                      icon: const Icon(Icons.route),
                      label: const Text('Calculate Safe Route'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0078D4),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isMonitoring ? _stopMonitoring : _startMonitoring,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                            ),
                            child: Text(_isMonitoring ? 'Stop Trip' : 'Start Safe Trip'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (!_isMonitoring)
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _destination = null;
                                _routePoints = [];
                                _polylines = {};
                                _updateMarkers();
                              });
                            },
                            icon: const Icon(Icons.clear, color: Colors.red),
                          )
                      ],
                    ),
                  const SizedBox(height: 10),
                  Text(
                    'SOS will be sent if you deviate more than ${_deviationThreshold.toStringAsFixed(0)}m',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
