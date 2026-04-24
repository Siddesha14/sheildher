# ShieldHer Production Security & Privacy

This document outlines the security architecture and release requirements for the ShieldHer application.

## 1. Build Security (Obfuscation)
To prevent reverse-engineering of the application logic and API key extraction, always use obfuscation for release builds:

```bash
flutter build apk --release --obfuscate --split-debug-info=build/symbols
```

## 2. API Key Management
* **Current State**: Keys are stored in `ApiConfig.dart`.
* **Production Recommendation**: Keys should be moved to a backend proxy (Firebase Functions or a Node.js server). The app should never make direct calls to third-party APIs with a master key.

## 3. Firebase Security Rules
Ensure your Firebase Realtime Database and Firestore have the following rules applied:

```json
{
  "rules": {
    "users": {
      "$uid": {
        ".read": "auth != null && auth.uid == $uid",
        ".write": "auth != null && auth.uid == $uid"
      }
    }
  }
}
```

## 4. Local Data Security
* All sensitive data (contacts, settings) is stored using `flutter_secure_storage`.
* On Android, this uses **EncryptedSharedPreferences** with the Android KeyStore.
* On iOS, this uses the **Keychain**.

## 5. Privacy Policy
* **Zero Storage Policy**: No audio or voice recordings are stored locally or sent to any server. All AI processing (Voice Recognition) happens in real-time in memory.
* **Minimal Data**: Only necessary metadata is sent during an SOS event to trusted contacts.
* **Encryption**: All network traffic is enforced to use **HTTPS**.

## 6. SOS Safety Controls
* **Cooldown**: A 1-minute cooldown prevents duplicate SOS alerts.
* **Validation**: All phone numbers are validated before SMS or Call triggers are executed.
