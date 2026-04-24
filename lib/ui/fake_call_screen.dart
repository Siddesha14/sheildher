import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

class FakeCallScreen extends StatefulWidget {
  final String callerName;
  final String callerNumber;
  const FakeCallScreen({
    super.key,
    this.callerName = "Dad",
    this.callerNumber = "Private number",
  });

  static Future<void> show(BuildContext context, {String callerName = "Dad"}) {
    return _showConfigAndCall(context, defaultCallerName: callerName);
  }

  static Future<void> _showConfigAndCall(
    BuildContext context, {
    required String defaultCallerName,
  }) async {
    final config = await showModalBottomSheet<_FakeCallConfig>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _FakeCallConfigSheet(defaultCallerName: defaultCallerName),
    );

    if (config == null || !context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Fake call in ${config.delaySeconds}s')),
    );

    await Future.delayed(Duration(seconds: config.delaySeconds));
    if (!context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Incoming call',
      barrierDismissible: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return FakeCallScreen(
          callerName: config.callerName,
          callerNumber: config.callerNumber,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) =>
          FadeTransition(opacity: animation, child: child),
    );
  }

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool _isRinging = true;
  Timer? _callTimer;
  int _callSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  void _startRinging() async {
    FlutterRingtonePlayer().play(
      android: AndroidSounds.ringtone,
      ios: IosSounds.glass,
      looping: true,
      asAlarm: false,
      volume: 1.0,
    );
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 1000, 1000], repeat: 0);
    }
  }

  void _stopRinging() {
    Vibration.cancel();
    FlutterRingtonePlayer().stop();
  }

  void _answerCall() {
    setState(() {
      _isRinging = false;
      _stopRinging();
    });
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _callSeconds += 1);
    });
  }

  String _formattedDuration() {
    final minutes = (_callSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_callSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _stopRinging();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF101010), Color(0xFF000000)],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                _isRinging ? "Incoming call" : _formattedDuration(),
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
              const SizedBox(height: 16),
              const CircleAvatar(
                radius: 48,
                backgroundColor: Color(0xFF2A2A2A),
                child: Icon(Icons.person, color: Colors.white70, size: 52),
              ),
              const SizedBox(height: 16),
              Text(
                widget.callerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.callerNumber,
                style: const TextStyle(color: Colors.white60, fontSize: 17),
              ),
              const Spacer(),
              if (_isRinging)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildCallButton(Colors.red, Icons.call_end, () {
                      Navigator.pop(context);
                    }, "Decline"),
                    _buildCallButton(Colors.green, Icons.call, _answerCall, "Answer"),
                  ],
                )
              else
                _buildCallButton(Colors.red, Icons.call_end, () {
                  Navigator.pop(context);
                }, "End"),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallButton(Color color, IconData icon, VoidCallback onTap, String label) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 34),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70)),
      ],
    );
  }
}

class _FakeCallConfig {
  const _FakeCallConfig({
    required this.callerName,
    required this.callerNumber,
    required this.delaySeconds,
  });

  final String callerName;
  final String callerNumber;
  final int delaySeconds;
}

class _FakeCallConfigSheet extends StatefulWidget {
  const _FakeCallConfigSheet({required this.defaultCallerName});

  final String defaultCallerName;

  @override
  State<_FakeCallConfigSheet> createState() => _FakeCallConfigSheetState();
}

class _FakeCallConfigSheetState extends State<_FakeCallConfigSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _numberController;
  int _delaySeconds = 3;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultCallerName);
    _numberController = TextEditingController(text: "Private number");
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Fake Call Setup",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Caller name",
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _numberController,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: "Caller number",
              labelStyle: TextStyle(color: Colors.white70),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "Call after $_delaySeconds seconds",
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            min: 1,
            max: 15,
            divisions: 14,
            value: _delaySeconds.toDouble(),
            onChanged: (value) => setState(() => _delaySeconds = value.round()),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final name = _nameController.text.trim().isEmpty
                    ? widget.defaultCallerName
                    : _nameController.text.trim();
                final number = _numberController.text.trim().isEmpty
                    ? "Private number"
                    : _numberController.text.trim();
                Navigator.pop(
                  context,
                  _FakeCallConfig(
                    callerName: name,
                    callerNumber: number,
                    delaySeconds: _delaySeconds,
                  ),
                );
              },
              child: const Text("Start fake call"),
            ),
          ),
        ],
      ),
    );
  }
}
