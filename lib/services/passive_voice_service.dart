import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sound_mode/sound_mode.dart';
import 'package:sound_mode/utils/ringer_mode_statuses.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'distress_intent_detector.dart';

class PassiveVoiceService {
  PassiveVoiceService({
    required this.onThreatDetected,
    this.onTranscript,
    this.onDetectionStateChanged,
    this.onGuidanceRequested,
  });

  final void Function(String triggerText) onThreatDetected;
  final void Function(String transcript)? onGuidanceRequested;
  final void Function(String transcript, double confidence)? onTranscript;
  final void Function(String state)? onDetectionStateChanged;
  final SpeechToText _speech = SpeechToText();
  final DistressIntentDetector _intentDetector = DistressIntentDetector();

  bool _isEnabled = false;
  bool _isListening = false;
  DateTime? _lastThreatAt;
  DateTime? _lastListeningStartedAt;
  Timer? _restartTimer;
  int _restartBackoffSeconds = 2;
  RingerModeStatus? _originalRingerMode;
  bool _ringerModeManagedByService = false;

  Future<bool> start() async {
    final micPermission = await Permission.microphone.request();
    if (!micPermission.isGranted) return false;

    await _intentDetector.initialize();
    await _setPhoneSilentForPassiveListening();

    _isEnabled = await _speech.initialize(
      onStatus: _handleStatus,
      onError: (error) {
        debugPrint('Speech error: ${error.errorMsg}');
        final errorText = error.errorMsg.toLowerCase();
        final benignNoSpeechError =
            errorText.contains('no_match') ||
            errorText.contains('no match') ||
            errorText.contains('speech timeout');
        if (!benignNoSpeechError) {
          _scheduleRestart();
        }
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
    await _restorePhoneRingerMode();
  }

  void _startListening() {
    if (!_isEnabled || _isListening) return;
    _isListening = true;
    _lastListeningStartedAt = DateTime.now();
    _restartBackoffSeconds = 2;
    onDetectionStateChanged?.call('Listening');

    _speech.listen(
      onResult: _handleResult,
      onSoundLevelChange: _handleSoundLevel,
      listenFor: const Duration(hours: 1),
      pauseFor: const Duration(seconds: 4),
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
      final startedAt = _lastListeningStartedAt;
      final sessionSeconds = startedAt == null
          ? 0
          : DateTime.now().difference(startedAt).inSeconds;

      // Short sessions usually create repeated mic beeps on some Android devices.
      // Use an aggressive cooldown before reconnecting to avoid rapid toggling.
      if (sessionSeconds < 20) {
        _restartBackoffSeconds = 2;
      } else if (sessionSeconds < 90) {
        _restartBackoffSeconds = 1;
      } else {
        _restartBackoffSeconds = 1;
      }

      _scheduleRestart();
    }
  }

  void _scheduleRestart() {
    if (!_isEnabled) return;
    _restartTimer?.cancel();
    final delay = Duration(seconds: _restartBackoffSeconds);
    onDetectionStateChanged?.call('Reconnecting in ${delay.inSeconds}s...');
    _restartTimer = Timer(delay, _startListening);
    _restartBackoffSeconds = (_restartBackoffSeconds + 1).clamp(1, 5);
  }

  void _handleResult(SpeechRecognitionResult result) {
    final transcript = result.recognizedWords.trim().toLowerCase();
    if (transcript.isEmpty) return;
    onTranscript?.call(transcript, result.confidence);

    final intent = _intentDetector.detect(
      transcript: transcript,
      speechConfidence: result.confidence,
    );

    if (intent.isDistressIntent && !_isInCooldown()) {
      _lastThreatAt = DateTime.now();
      debugPrint(
        'Distress intent detected. score=${intent.score.toStringAsFixed(2)} '
        'signals=${intent.matchedSignals.join(',')}',
      );
      onDetectionStateChanged?.call('Distress detected');
      onThreatDetected(transcript);
      
      // If it's ALSO a guidance request, handle it too
      if (intent.isGuidanceRequest) {
        onGuidanceRequested?.call(transcript);
      }
    } else if (intent.isGuidanceRequest && !_isInCooldown()) {
      onGuidanceRequested?.call(transcript);
      _lastThreatAt = DateTime.now(); // guidance also has a small cooldown
    }
  }

  void _handleSoundLevel(double level) {
    if (!_isEnabled || _isInCooldown()) return;

    // Screams typically produce very high sound levels.
    // Threshold calibration may be needed per device, but 9.5-11.0 is often 'loud'.
    // We use a high threshold to avoid triggering on normal speech.
    if (level > 11.5) {
      debugPrint('Scream/Loud noise detected: level=$level');
      _lastThreatAt = DateTime.now();
      onDetectionStateChanged?.call('Scream detected!');
      onThreatDetected('Scream/Loud Noise Detected');
    }
  }

  bool _isInCooldown() {
    if (_lastThreatAt == null) return false;
    return DateTime.now().difference(_lastThreatAt!) < const Duration(seconds: 30);
  }

  Future<void> _setPhoneSilentForPassiveListening() async {
    try {
      if (!_ringerModeManagedByService) {
        _originalRingerMode = await SoundMode.ringerModeStatus;
      }
      await SoundMode.setSoundMode(RingerModeStatus.vibrate);
      _ringerModeManagedByService = true;
      onDetectionStateChanged?.call('Listening (silent mode)');
    } catch (e) {
      debugPrint('Unable to set silent/vibrate mode: $e');
    }
  }

  Future<void> _restorePhoneRingerMode() async {
    try {
      if (_ringerModeManagedByService && _originalRingerMode != null) {
        await SoundMode.setSoundMode(_originalRingerMode!);
      }
    } catch (e) {
      debugPrint('Unable to restore ringer mode: $e');
    } finally {
      _ringerModeManagedByService = false;
      _originalRingerMode = null;
    }
  }
}
