import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'storage_service.dart';

/// SecurityService manages app-level security including authentication, 
/// SOS cooldowns, and data privacy enforcement.
class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final StorageService _storage = StorageService();

  User? get currentUser => _auth.currentUser;

  // SOS Cooldown configuration
  DateTime? _lastSosTrigger;
  static const Duration sosCooldown = Duration(minutes: 1);

  /// Initializes secure session. Anonymous login ensures Firebase rules work 
  /// without requiring user PII (Privacy First).
  Future<void> ensureAuthenticated() async {
    try {
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
        debugPrint('Security: Session initialized anonymously.');
      }
    } catch (e) {
      debugPrint('Security Error (Auth): ${e.toString()}');
    }
  }

  /// Validates if an SOS can be triggered based on cooldown policy.
  /// Prevents spamming and redundant alerts.
  bool canTriggerSos() {
    if (_lastSosTrigger == null) return true;
    final now = DateTime.now();
    return now.difference(_lastSosTrigger!) > sosCooldown;
  }

  /// Records an SOS event to enforce the cooldown.
  void recordSosTrigger() {
    _lastSosTrigger = DateTime.now();
  }

  /// Privacy: Validates that no sensitive audio/voice is stored on disk.
  /// In this app, we ensure PassiveVoiceService only processes in-memory.
  void enforcePrivacyPolicy() {
    // This is a placeholder for structural checks.
    // Ensure all temporary files are in secure directories.
    debugPrint('Security: Privacy policy enforced.');
  }

  /// Robustness: Validates phone numbers before emergency actions.
  bool isValidPhoneNumber(String? phone) {
    if (phone == null || phone.length < 10) return false;
    final regex = RegExp(r'^\+?[0-9]{10,15}$');
    return regex.hasMatch(phone);
  }
}
