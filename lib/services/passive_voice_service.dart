import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'distress_intent_detector.dart';

class PassiveVoiceService {
  PassiveVoiceService({
    required this.onThreatDetected,
    this.onTranscript,
    this.onDetectionStateChanged,
  });

  final void Function(String triggerText) onThreatDetected;
  final void Function(String transcript, double confidence)? onTranscript;
  final void Function(String state)? onDetectionStateChanged;
  final SpeechToText _speech = SpeechToText();
  final DistressIntentDetector _intentDetector = DistressIntentDetector();

  bool _isEnabled = false;
  bool _isListening = false;
  DateTime? _lastThreatAt;
  Timer? _restartTimer;

  Future<bool> start() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) return false;

    await _intentDetector.initialize();

    _isEnabled = await _speech.initialize(
      onStatus: _handleStatus,
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        _scheduleRestart();
      },
      debugLogging: false,
    );

    if (_isEnabled) {
      _startListening();
    }
    return _isEnabled;
  }

  Future<void> stop() async {
    _isEnabled = false;
    _restartTimer?.cancel();
    if (_speech.isListening) {
      await _speech.stop();
    }
    _isListening = false;
  }

  void _startListening() {
    if (!_isEnabled || _isListening) return;
    _isListening = true;
    onDetectionStateChanged?.call('Listening');

    _speech.listen(
      onResult: _handleResult,
      listenFor: const Duration(minutes: 10),
      pauseFor: const Duration(minutes: 2),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: ListenMode.dictation,
      ),
    );
  }

  void _handleStatus(String status) {
    if (!_isEnabled) return;
    if (status == 'listening') {
      onDetectionStateChanged?.call('Listening');
    }
    if (status == 'done' || status == 'notListening') {
      _isListening = false;
      onDetectionStateChanged?.call('Reconnecting...');
      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_isEnabled) return;
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(seconds: 2), _startListening);
  }

  void _handleResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim().toLowerCase();
    if (transcript.isEmpty) return;
    onTranscript?.call(transcript, result.confidence);

    final intent = _intentDetector.detect(
      transcript: transcript,
      speechConfidence: result.confidence,
    );
    if (!intent.isDistressIntent || _isInCooldown()) return;

    _lastThreatAt = DateTime.now();
    debugPrint(
      'Distress intent detected. score=${intent.score.toStringAsFixed(2)} '
      'signals=${intent.matchedSignals.join(',')}',
    );
    onDetectionStateChanged?.call('Distress detected');
    onThreatDetected(transcript);
  }

  bool _isInCooldown() {
    if (_lastThreatAt == null) return false;
    return DateTime.now().difference(_lastThreatAt!) < const Duration(seconds: 30);
  }
}
