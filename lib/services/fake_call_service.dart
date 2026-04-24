import 'package:flutter/services.dart';

class FakeCallService {
  static const _channel = MethodChannel('com.example.shieldher/hardware_buttons');
  final void Function() onTrigger;

  FakeCallService({required this.onTrigger});

  void start() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'triggerFakeCall') {
        onTrigger();
      }
    });
  }

  void stop() {
    _channel.setMethodCallHandler(null);
  }
}
