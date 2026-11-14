import 'package:flutter/services.dart';

/// Service pour maintenir l'écran allumé pendant la lecture vidéo ou les sessions d'écoute,
/// empêchant le verrouillage automatique du système après 30s/1min d'inactivité tactile.
class ScreenWakeService {
  static const MethodChannel _channel = MethodChannel('com.example.sonoritiz/audio_output');
  static bool _isKeptOn = false;

  static bool get isKeptOn => _isKeptOn;

  /// Active ou désactive le maintien de l'écran allumé
  static Future<void> setKeepScreenOn(bool keepOn) async {
    if (_isKeptOn == keepOn) return;
    _isKeptOn = keepOn;
    try {
      await _channel.invokeMethod('setKeepScreenOn', {'enabled': keepOn});
    } catch (_) {}
  }
}
