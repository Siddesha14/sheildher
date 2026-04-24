import 'package:flutter/services.dart';

class PowerButtonService {
  static const _channel = MethodChannel('com.example.shieldher/power_button');
  final VoidCallback onTrigger;

  PowerButtonService({required this.onTrigger});

  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerSOS') {
        onTrigger();
      }
    });
  }

  void stop() {
    _channel.setMethodCallHandler(null);
  }
}
