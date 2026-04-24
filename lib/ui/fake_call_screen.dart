import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool _hasAccepted = false;
  int _seconds = 0;
  Timer? _timer;
  final String _callerName = "Mom ❤️";
  final String _callerNumber = "+91 98765 43210";

  @override
  void initState() {
    super.initState();
    _startRinging();
  }

  void _startRinging() {
    FlutterRingtonePlayer().playRingtone(
      looping: true,
      volume: 1.0,
      asAlarm: false,
    );
    Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 1);
  }

  void _stopRinging() {
    FlutterRingtonePlayer().stop();
    Vibration.cancel();
  }

  void _acceptCall() {
    _stopRinging();
    setState(() {
      _hasAccepted = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  void _declineCall() {
    _stopRinging();
    _timer?.cancel();
    Navigator.pop(context);
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopRinging();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: _hasAccepted ? _buildActiveCall() : _buildIncomingCall(),
      ),
    );
  }

  Widget _buildIncomingCall() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 80),
          child: Column(
            children: [
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 60, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                _callerName,
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 8),
              Text(
                "ShieldHer Safety Call",
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 80, left: 40, right: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCallButton(
                icon: Icons.call_end,
                color: Colors.red,
                label: "Decline",
                onTap: _declineCall,
              ),
              _buildCallButton(
                icon: Icons.call,
                color: Colors.green,
                label: "Accept",
                onTap: _acceptCall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveCall() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 60),
          child: Column(
            children: [
              Text(
                _callerName,
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 8),
              Text(
                _formatDuration(_seconds),
                style: const TextStyle(color: Colors.white70, fontSize: 18),
              ),
            ],
          ),
        ),
        // Grid of call options
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Wrap(
            spacing: 40,
            runSpacing: 40,
            alignment: WrapAlignment.center,
            children: [
              _buildOptionIcon(Icons.mic_off, "mute"),
              _buildOptionIcon(Icons.dialpad, "keypad"),
              _buildOptionIcon(Icons.volume_up, "speaker"),
              _buildOptionIcon(Icons.add, "add call"),
              _buildOptionIcon(Icons.videocam_off, "FaceTime"),
              _buildOptionIcon(Icons.contacts, "contacts"),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: _buildCallButton(
            icon: Icons.call_end,
            color: Colors.red,
            label: "End",
            onTap: _declineCall,
            large: true,
          ),
        ),
      ],
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
    bool large = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: large ? 75 : 65,
            height: large ? 75 : 65,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: large ? 40 : 30),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildOptionIcon(IconData icon, String label) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
