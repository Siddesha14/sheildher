import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/shake_service.dart';
import '../services/sms_service.dart';
import '../services/contact_service.dart';
import '../services/call_service.dart';
import '../services/passive_voice_service.dart';
import 'contacts_screen.dart';
import 'safe_route_screen.dart';
import '../services/power_button_service.dart';
import '../services/fake_call_service.dart';
import 'fake_call_screen.dart';
import '../services/search_service.dart';
import '../services/voice_guidance_service.dart';
import '../services/route_service.dart';
import '../services/security_service.dart';
import 'dart:math' show cos, sqrt, asin;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LocationService _locationService = LocationService();
  final SmsService _smsService = SmsService();
  final RouteService _routeService = RouteService();
  final SecurityService _securityService = SecurityService();
  final ContactService _contactService = ContactService();
  final CallService _callService = CallService();
  final SearchService _searchService = SearchService();
  final VoiceGuidanceService _voiceGuidanceService = VoiceGuidanceService();
  late ShakeService _shakeService;
  late PassiveVoiceService _passiveVoiceService;
  bool _passiveListening = false;
  bool _isSendingSos = false;
  int _tabIndex = 0;
  String _voiceState = 'Idle';
  String _latestTranscript = 'No speech detected yet.';
  String _latestConfidence = '-';
  String _lastDistressTranscript = 'No distress intent detected yet.';
  final List<String> _voiceHistory = [];
  late PowerButtonService _powerButtonService;
  late FakeCallService _fakeCallService;

  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  List<RouteStep> _navigationSteps = [];
  int _currentStepIndex = -1;
  LatLng? _lastAnnouncedStepLocation;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(12.9716, 77.5946),
    zoom: 12,
  );

  @override
  void initState() {
    super.initState();
    _securityService.ensureAuthenticated();
    _initLocation();
    _shakeService = ShakeService(onShake: _handleShakeEmergency);
    _shakeService.start();
    _passiveVoiceService = PassiveVoiceService(
      onThreatDetected: _handlePassiveThreatDetected,
      onTranscript: _handleTranscriptUpdate,
      onDetectionStateChanged: _handleVoiceStateChanged,
      onGuidanceRequested: (text) => _handleEmergencyGuidance(),
    );
    _powerButtonService = PowerButtonService(onTrigger: () => _sendSOS());
    _powerButtonService.start();
    _fakeCallService = FakeCallService(onTrigger: _showFakeCall);
    _fakeCallService.start();

    _enablePassiveVoice();
    _initLocationMonitoring();
  }

  void _showFakeCall() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FakeCallScreen()),
    );
  }

  @override
  void dispose() {
    _shakeService.stop();
    _passiveVoiceService.stop();
    _powerButtonService.stop();
    _fakeCallService.stop();
    _voiceGuidanceService.stop();
    super.dispose();
  }

  void _initLocationMonitoring() {
    _locationService.getLocationStream().listen((position) {
      if (_currentStepIndex >= 0 && _navigationSteps.isNotEmpty) {
        _updateNavigation(position);
      }
    });
  }

  void _updateNavigation(Position position) {
    if (_currentStepIndex >= _navigationSteps.length) return;

    final currentStep = _navigationSteps[_currentStepIndex];
    final distanceToStep = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      currentStep.location.latitude, currentStep.location.longitude
    );

    // If within 20 meters of the step location, announce next step
    if (distanceToStep < 20) {
      _currentStepIndex++;
      if (_currentStepIndex < _navigationSteps.length) {
        _voiceGuidanceService.speak(_navigationSteps[_currentStepIndex].instruction);
      } else {
        _voiceGuidanceService.speak("You have arrived at the safe zone.");
        _currentStepIndex = -1; // Reset navigation
      }
    }
  }

  Future<void> _initLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null) {
      if (mounted) {
        setState(() {
          _updateLocationMarker(position);
        });
        _mapController?.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 15,
          ),
        ));
      }
    }
  }

  void _updateLocationMarker(Position position) {
    setState(() {
      _markers.removeWhere((m) => m.markerId.value == "current_location");
      _markers.add(
        Marker(
          markerId: const MarkerId("current_location"),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(title: "You are here"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  void _handleShakeEmergency() {
    _sendSOS(fromShake: true);
  }

  void _handlePassiveThreatDetected(String detectedText) {
    if (mounted) {
      setState(() {
        _lastDistressTranscript = detectedText;
        _voiceHistory.insert(0, '[DISTRESS] $detectedText');
        if (_voiceHistory.length > 40) _voiceHistory.removeLast();
      });
    }
    _sendSOS(fromVoice: true, detectedText: detectedText);
  }

  void _handleTranscriptUpdate(String transcript, double confidence) {
    if (!mounted) return;
    setState(() {
      _latestTranscript = transcript;
      _latestConfidence =
          confidence < 0 ? 'N/A' : '${(confidence * 100).toStringAsFixed(1)}%';
      _voiceHistory.insert(0, '[VOICE] $transcript');
      if (_voiceHistory.length > 40) _voiceHistory.removeLast();
    });
  }

  void _handleVoiceStateChanged(String state) {
    if (!mounted) return;
    setState(() {
      _voiceState = state;
    });
  }

  Future<void> _enablePassiveVoice() async {
    final enabled = await _passiveVoiceService.start();
    if (!mounted) return;
    setState(() {
      _passiveListening = enabled;
    });
  }

  Future<void> _togglePassiveVoice() async {
    if (_passiveListening) {
      await _passiveVoiceService.stop();
      if (!mounted) return;
      setState(() {
        _passiveListening = false;
        _voiceState = 'Paused';
      });
      return;
    }
    await _enablePassiveVoice();
    if (mounted && !_passiveListening) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission is needed for passive detection.')),
      );
    }
  }

  Future<void> _sendSOS({
    bool fromShake = false,
    bool fromVoice = false,
    String? detectedText,
  }) async {
    if (_isSendingSos) return;
    _isSendingSos = true;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fromShake
                ? 'Shake detected! Sending SOS...'
                : fromVoice
                    ? 'Threat phrase detected. Sending SOS...'
                    : 'Sending SOS...',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }

    try {
      final smsResult = await _smsService.sendEmergencySms();
      final contacts = await _contactService.getEmergencyContacts();
      final callAttempts = await _callService.callEmergencyContacts(contacts);

      if (mounted) {
        final triggerInfo =
            fromVoice && detectedText != null ? ' Trigger: "$detectedText".' : '';
        final message = smsResult.errorMessage ??
            'SOS sent to ${smsResult.sentCount}/${smsResult.contactsCount} contacts. Calls attempted: $callAttempts.$triggerInfo';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: smsResult.errorMessage == null ? Colors.green : Colors.red,
          ),
        );
      }

      // Find nearby police stations and provide guidance
      print('Triggering emergency guidance...');
      await _handleEmergencyGuidance();

    } finally {
      _isSendingSos = false;
    }
  }

  Future<void> _handleEmergencyGuidance() async {
    final position = await _locationService.getCurrentLocation();
    if (position == null) return;

    final userLatLng = LatLng(position.latitude, position.longitude);
    final stations = await _searchService.findNearbySafeZones(userLatLng);

    if (stations.isNotEmpty) {
      // Find the closest one
      var closest = stations[0];
      double minDistance = Geolocator.distanceBetween(
        userLatLng.latitude, userLatLng.longitude,
        closest.location.latitude, closest.location.longitude
      );

      for (var station in stations) {
        double d = Geolocator.distanceBetween(
          userLatLng.latitude, userLatLng.longitude,
          station.location.latitude, station.location.longitude
        );
        if (d < minDistance) {
          minDistance = d;
          closest = station;
        }
      }

      setState(() {
        _markers.add(
          Marker(
            markerId: const MarkerId("nearest_safe_zone"),
            position: closest.location,
            infoWindow: InfoWindow(title: closest.name, snippet: "Nearest Safe Zone"),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ),
        );
      });

      // Provide initial voice guidance and route info
      String guidanceMsg = await _voiceGuidanceService.getEmergencyGuidanceMessage(closest.name, minDistance);
      
      // Fetch and display route
      final routeData = await _routeService.getRoute(userLatLng, closest.location);
      if (routeData != null) {
        setState(() {
          _polylines.add(Polyline(
            polylineId: const PolylineId("emergency_route"),
            points: routeData.polyline,
            color: Colors.red,
            width: 5,
          ));
          _navigationSteps = routeData.steps;
          _currentStepIndex = 0;
        });
        
        if (_navigationSteps.isNotEmpty) {
          guidanceMsg += " Starting navigation. ${_navigationSteps[0].instruction}";
        }
      }

      await _voiceGuidanceService.speak(guidanceMsg);

      // Zoom map to show both
      _fitMapToPoints(userLatLng, closest.location);
    } else {
      debugPrint('No safe zones found within range.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No 24h safe zones found nearby. Please stay in a well-lit area.')),
        );
      }
    }
  }

  void _fitMapToPoints(LatLng p1, LatLng p2) {
    double minLat = p1.latitude < p2.latitude ? p1.latitude : p2.latitude;
    double maxLat = p1.latitude > p2.latitude ? p1.latitude : p2.latitude;
    double minLng = p1.longitude < p2.longitude ? p1.longitude : p2.longitude;
    double maxLng = p1.longitude > p2.longitude ? p1.longitude : p2.longitude;

    _mapController?.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100, // padding
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F3F3), // Microsoft Light Theme background
      appBar: AppBar(
        title: const Text('ShieldHer', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts, color: Color(0xFF0078D4)),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ContactsScreen()));
            },
          )
        ],
      ),
      body: IndexedStack(
        index: _tabIndex,
        children: [
          _buildSafetyTab(),
          _buildVoiceMonitorTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Safety'),
          NavigationDestination(icon: Icon(Icons.graphic_eq), label: 'Voice Monitor'),
        ],
      ),
    );
  }

  Widget _buildSafetyTab() {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: GoogleMap(
              initialCameraPosition: _initialPosition,
              onMapCreated: (controller) => _mapController = controller,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text(
                  "Safety Tools",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[800]),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionCard(
                      title: "SOS",
                      icon: Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      onTap: _sendSOS,
                    ),
                    _buildActionCard(
                      title: "Safe Route",
                      icon: Icons.route,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SafeRouteScreen()));
                      },
                    ),
                    _buildActionCard(
                      title: "Fake Call",
                      icon: Icons.call_outlined,
                      color: Colors.blue,
                      onTap: _showFakeCall,
                    ),
                  ],
                ),
                _buildActionCard(
                  title: _passiveListening ? "Passive ON" : "Passive OFF",
                  icon: _passiveListening ? Icons.mic : Icons.mic_off,
                  color: _passiveListening ? Colors.deepPurple : Colors.grey,
                  onTap: _togglePassiveVoice,
                ),
                Text(
                  "Shake or threat voice detection can silently trigger SOS",
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                )
              ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildVoiceMonitorTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice state: $_voiceState', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Passive mode: ${_passiveListening ? "ON" : "OFF"}'),
                  Text('ASR confidence: $_latestConfidence'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Latest speech', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(_latestTranscript),
                  const SizedBox(height: 10),
                  const Text('Last distress trigger', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(_lastDistressTranscript),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Detected history', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                itemCount: _voiceHistory.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    dense: true,
                    title: Text(_voiceHistory[index]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
