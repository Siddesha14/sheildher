import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_tts/flutter_tts.dart';

class FakeCallScreen extends StatefulWidget {
  const FakeCallScreen({super.key});

  @override
  State<FakeCallScreen> createState() => _FakeCallScreenState();
}

class _FakeCallScreenState extends State<FakeCallScreen> {
  bool _hasAccepted = false;
  int _seconds = 0;
  Timer? _callDurationTimer;
  Timer? _scriptTimer;
  
  final String _callerName = "Mom ❤️";
  final String _callerNumber = "+91 98765 43210";
  final FlutterTts _flutterTts = FlutterTts();
  
  int _scriptIndex = 0;
  bool _isMomSpeaking = false;

  final List<Map<String, dynamic>> _conversationScript = [
    {"text": "Hey honey, where are you? I've been waiting for you.", "delay": 2},
    {"text": "Oh okay, are you near the main road? It's getting dark out there.", "delay": 6},
    {"text": "Great. I'm just about to serve dinner. How much longer will you be, roughly?", "delay": 6},
    {"text": "Alright, just stay on the line with me until you get to the front door, okay?", "delay": 6},
    {"text": "I'm looking out the window for you now. I think I see you! Is that you in the distance?", "delay": 7},
    {"text": "Okay, I'm coming down to the gate now. See you in a second!", "delay": 6},
  ];

  @override
  void initState() {
    super.initState();
    _initTts();
    _startRinging();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.45); // Slightly slower for realism
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
    
    _startScriptedConversation();

    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _seconds++;
        });
      }
    });
  }

  void _declineCall() {
    _stopRinging();
    _flutterTts.stop();
    _callDurationTimer?.cancel();
    _scriptTimer?.cancel();
    Navigator.pop(context);
  }

  void _startScriptedConversation() {
    _scriptIndex = 0;
    _playNextLine();
  }

  void _playNextLine() {
    if (!mounted || !_hasAccepted || _scriptIndex >= _conversationScript.length) return;

    final currentLine = _conversationScript[_scriptIndex];
    
    _scriptTimer = Timer(Duration(seconds: currentLine['delay'] as int), () async {
      if (!mounted) return;
      
      setState(() => _isMomSpeaking = true);
      await _flutterTts.speak(currentLine['text'] as String);
      
      // Wait for speech to finish before marking as done
      // (Approximate duration based on text length)
      final speechDuration = (currentLine['text'] as String).length * 80;
      await Future.delayed(Duration(milliseconds: speechDuration));
      
      if (mounted) {
        setState(() => _isMomSpeaking = false);
        _scriptIndex++;
        _playNextLine(); // Schedule next line
      }
    });
  }

  String _formatDuration(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _stopRinging();
    _flutterTts.stop();
    _callDurationTimer?.cancel();
    _scriptTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1B1F),
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
          padding: const EdgeInsets.only(top: 100),
          child: Column(
            children: [
              Text(
                _callerName,
                style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 12),
              Text(
                "Phone $_callerNumber",
                style: const TextStyle(color: Color(0xFFE2E2E6), fontSize: 18),
              ),
            ],
          ),
        ),
        Column(
          children: [
            const Icon(Icons.call, color: Colors.green, size: 50),
            const SizedBox(height: 100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2E32),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _declineCall,
                        child: const Center(
                          child: Text("Decline", style: TextStyle(color: Colors.white, fontSize: 16)),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _acceptCall,
                      child: Container(
                        width: 75,
                        height: 75,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.call, color: Color(0xFF34A853), size: 35),
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text("Answer", style: TextStyle(color: Colors.white, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveCall() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 40),
          child: Column(
            children: [
              Text(
                _formatDuration(_seconds),
                style: const TextStyle(color: Color(0xFFE2E2E6), fontSize: 18),
              ),
              const SizedBox(height: 16),
              Text(
                _callerName,
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 8),
              Text(
                "Phone $_callerNumber",
                style: const TextStyle(color: Color(0xFFE2E2E6), fontSize: 16),
              ),
            ],
          ),
        ),
        
        Container(
          width: 140,
          height: 140,
          decoration: const BoxDecoration(
            color: Color(0xFFA50B0B),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text(
            "M",
            style: TextStyle(color: Colors.white, fontSize: 60, fontWeight: FontWeight.w300),
          ),
        ),

        Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                _isMomSpeaking ? "Mom is speaking..." : "Waiting for your reply...",
                style: TextStyle(
                  color: _isMomSpeaking ? const Color(0xFF8AB4F8) : Colors.green, 
                  fontSize: 14, 
                  fontStyle: FontStyle.italic
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2E2E32),
                borderRadius: BorderRadius.circular(40),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildOptionIcon(Icons.dialpad, "Keypad"),
                      _buildOptionIcon(Icons.mic_off, "Mute"),
                      _buildOptionIcon(Icons.bluetooth, "Airdopes ...", isSelected: true),
                      _buildOptionIcon(Icons.more_horiz, "More"),
                    ],
                  ),
                  const SizedBox(height: 24),
                  GestureDetector(
                    onTap: _declineCall,
                    child: Container(
                      width: double.infinity,
                      height: 70,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252),
                        borderRadius: BorderRadius.circular(35),
                      ),
                      child: const Icon(Icons.call_end, color: Colors.white, size: 35),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionIcon(IconData icon, String label, {bool isSelected = false}) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFD3E3FD) : const Color(0xFF1B1B1F),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isSelected ? const Color(0xFF041E49) : Colors.white, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          label, 
          style: const TextStyle(color: Colors.white, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
