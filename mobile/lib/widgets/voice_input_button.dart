import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/speech_to_text_service.dart';
import '../services/theme_service.dart';

/// 🎤 Voice Input Button Widget
///
/// Long-press to start voice input
/// Release to stop
class VoiceInputButton extends StatefulWidget {
  final Function(String text) onTextRecognized;

  const VoiceInputButton({
    super.key,
    required this.onTextRecognized,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  final SpeechToTextService _speechService = SpeechToTextService.instance;
  
  bool _isListening = false;
  bool _isInitialized = false;
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speechService.initialize();
    setState(() => _isInitialized = available);
  }

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    final colors = themeService.gradientColors;

    if (!_isInitialized) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return GestureDetector(
      onLongPress: _startListening,
      onLongPressUp: _stopListening,
      onTapUp: (_) => _stopListening(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: _isListening
              ? LinearGradient(colors: colors)
              : null,
          color: _isListening ? null : Colors.white.withOpacity(0.1),
          border: Border.all(
            color: _isListening ? colors[0] : Colors.white.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: _isListening
              ? [
                  BoxShadow(
                    color: colors[0].withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ]
              : [],
        ),
        child: Icon(
          _isListening ? Icons.mic : Icons.mic_none,
          color: _isListening
              ? Colors.white
              : Colors.white.withOpacity(0.7),
          size: 20,
        ),
      ),
    );
  }

  Future<void> _startListening() async {
    setState(() => _isListening = true);
    
    // Show listening indicator
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.mic, color: Colors.white),
              const SizedBox(width: 12),
              Text(
                'Listening... Speak now',
                style: GoogleFonts.firaCode(color: Colors.white),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 30),
        ),
      );
    }

    await _speechService.startListening(
      localeId: 'en_US', // TODO: Get from settings
      onResult: (text) {
        setState(() => _recognizedText = text);
      },
      onListeningChange: (isListening) {
        setState(() => _isListening = isListening);
      },
    );
  }

  Future<void> _stopListening() async {
    await _speechService.stopListening();
    setState(() => _isListening = false);

    if (_recognizedText.isNotEmpty) {
      widget.onTextRecognized(_recognizedText);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Recognized: $_recognizedText'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }

    setState(() => _recognizedText = '');
  }
}
