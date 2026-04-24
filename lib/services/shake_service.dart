import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';

class ShakeService {
  static const double shakeThresholdGravity = 4;
  static const int shakeSlopTimeMs = 500;
  static const int shakeCountResetTimeMs = 3000;
  static const int shakeCooldownMs = 10000;

  int _shakeCount = 0;
  int _lastShakeTime = 0;
  int _lastTriggerTime = 0;
  StreamSubscription? _accelerometerSubscription;
  final VoidCallback onShake;

  ShakeService({required this.onShake});

  void start() {
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      double x = event.x / 9.80665;
      double y = event.y / 9.80665;
      double z = event.z / 9.80665;

      double gX = x;
      double gY = y;
      double gZ = z;

      double gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

      if (gForce > shakeThresholdGravity) {
        final now = DateTime.now().millisecondsSinceEpoch;
        
        if (_lastShakeTime + shakeSlopTimeMs > now) {
          return;
        }
        
        if (_lastShakeTime + shakeCountResetTimeMs < now) {
          _shakeCount = 0;
        }

        _lastShakeTime = now;
        _shakeCount++;
        print('Shake detected! Count: $_shakeCount');

        if (_shakeCount >= 5) {
          if (now - _lastTriggerTime > shakeCooldownMs) {
            _lastTriggerTime = now;
            onShake();
            _shakeCount = 0;
          }
        }
      }
    });
  }

  void stop() {
    _accelerometerSubscription?.cancel();
  }
}
