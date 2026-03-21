import 'package:flutter/material.dart';

/// 🔐 7-Tap Gesture Helper for Invisible Sovereign Portal
class SevenTapGesture {
  int _tapCount = 0;
  DateTime? _lastTapTime;

  /// Handle tap gesture
  /// Returns true when 7 taps detected within 3 seconds
  bool handleTap() {
    final now = DateTime.now();
    
    // Reset if more than 3 seconds passed
    if (_lastTapTime == null || 
        now.difference(_lastTapTime!) > const Duration(seconds: 3)) {
      _tapCount = 0;
    }
    
    _tapCount++;
    _lastTapTime = now;
    
    debugPrint('👆 Secret tap: $_tapCount/7');
    
    // 7 taps → OPEN PORTAL
    if (_tapCount >= 7) {
      _tapCount = 0;
      debugPrint('🔐 INVISIBLE SOVEREIGN PORTAL DETECTED');
      return true;
    }
    
    return false;
  }

  /// Reset gesture state
  void reset() {
    _tapCount = 0;
    _lastTapTime = null;
  }
}
