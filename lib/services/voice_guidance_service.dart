import 'package:flutter_tts/flutter_tts.dart';

class VoiceGuidanceService {
  final FlutterTts _tts = FlutterTts();

  bool _isInitialized = false;
  Future<void>? _initFuture;

  VoiceGuidanceService() {
    _initFuture = _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _isInitialized = true;
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (!_isInitialized) await _initFuture;
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<String> getEmergencyGuidanceMessage(String stationName, double distanceInMeters) async {
    String distanceStr;
    if (distanceInMeters < 1000) {
      distanceStr = "${distanceInMeters.round()} meters";
    } else {
      distanceStr = "${(distanceInMeters / 1000).toStringAsFixed(1)} kilometers";
    }
    return "Emergency detected. The nearest safe zone is $stationName, located approximately $distanceStr away. Please head there immediately.";
  }

  Future<void> provideEmergencyGuidance(String stationName, double distanceInMeters) async {
    final msg = await getEmergencyGuidanceMessage(stationName, distanceInMeters);
    await speak(msg);
  }
}
