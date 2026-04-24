# Firebase Ephemeral Storage Cleanup

This document contains the implementation for the automated data cleanup (Cloud Functions) and explains the privacy architecture.

## 1. Firebase Cloud Function (Node.js)
Deploy this function to your Firebase project to handle automatic deletion of sensitive data every 5 minutes.

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

/**
 * Scheduled Cleanup: Runs every 5 minutes.
 * Deletes SOS alerts that are older than 5 minutes or marked as 'resolved'.
 */
exports.autoCleanupExpiredAlerts = functions.pubsub.schedule('every 5 minutes').onRun(async (context) => {
    const db = admin.database();
    const alertsRef = db.ref('alerts');
    const now = Date.now();
    const CUTOFF_MS = 5 * 60 * 1000; // 5 Minutes

    try {
        const snapshot = await alertsRef.once('value');
        if (!snapshot.exists()) return null;

        const updates = {};
        let count = 0;

        snapshot.forEach((userSnapshot) => {
            userSnapshot.forEach((alertSnapshot) => {
                const alert = alertSnapshot.val();
                const timestamp = alert.timestamp;
                const status = alert.status || 'active';

                // Privacy Logic: Delete if expired OR resolved
                if ((now - timestamp > CUTOFF_MS) || status === 'resolved') {
                    // Path to delete: alerts/{userId}/{alertId}
                    updates[`${userSnapshot.key}/${alertSnapshot.key}`] = null;
                    count++;
                }
            });
        });

        if (count > 0) {
            await alertsRef.update(updates);
            console.log(`Successfully deleted ${count} expired alerts.`);
        }
        return null;
    } catch (error) {
        console.error('Cleanup Error:', error);
        return null;
    }
});
```

## 2. Privacy & Security Benefits
* **Data Minimization**: Sensitive location data is only stored for as long as it is critically needed for the emergency (max 5 minutes).
* **Reduced Attack Surface**: Even if the database were compromised, an attacker would find almost zero historical location data.
* **Ephemeral Tracking**: Live tracking data is treated as "in-transit" only, preventing long-term profiling of user movements.

## 3. Client-Side Fallback usage
The Flutter app includes a fallback in `FirebaseService.runClientSideCleanup()`. It is recommended to call this:
1. On App Start.
2. Every time the SOS state is refreshed.

```dart
// Example usage in main.dart or HomeScreen
@override
void initState() {
  super.initState();
  FirebaseService().runClientSideCleanup();
}
```
