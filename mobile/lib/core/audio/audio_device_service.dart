import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AudioOutputType { speaker, bluetooth, headphones, usb, unknown }

class AudioOutputDevice {
  final String name;
  final AudioOutputType type;
  final bool isExternal;

  const AudioOutputDevice({
    required this.name,
    required this.type,
    required this.isExternal,
  });

  factory AudioOutputDevice.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) {
      return const AudioOutputDevice(
        name: "Haut-parleur du téléphone",
        type: AudioOutputType.speaker,
        isExternal: false,
      );
    }

    final name = map['name'] as String? ?? "Haut-parleur du téléphone";
    final typeStr = map['type'] as String? ?? "speaker";
    final isExternal = map['isExternal'] as bool? ?? false;

    AudioOutputType type = AudioOutputType.speaker;
    switch (typeStr) {
      case 'bluetooth':
        type = AudioOutputType.bluetooth;
        break;
      case 'headphones':
        type = AudioOutputType.headphones;
        break;
      case 'usb':
        type = AudioOutputType.usb;
        break;
      default:
        type = isExternal ? AudioOutputType.unknown : AudioOutputType.speaker;
    }

    return AudioOutputDevice(
      name: name,
      type: type,
      isExternal: isExternal,
    );
  }

  IconData get icon {
    switch (type) {
      case AudioOutputType.bluetooth:
        return Icons.bluetooth_audio_rounded;
      case AudioOutputType.headphones:
        return Icons.headphones_rounded;
      case AudioOutputType.usb:
        return Icons.usb_rounded;
      case AudioOutputType.speaker:
      default:
        return Icons.phone_android_rounded;
    }
  }
}

class AudioDeviceService {
  static final AudioDeviceService _instance = AudioDeviceService._internal();
  factory AudioDeviceService() => _instance;
  AudioDeviceService._internal() {
    _init();
  }

  static const MethodChannel _methodChannel = MethodChannel('com.example.sonoritiz/audio_output');
  static const EventChannel _eventChannel = EventChannel('com.example.sonoritiz/audio_output_events');

  final _deviceController = StreamController<AudioOutputDevice>.broadcast();
  AudioOutputDevice _currentDevice = const AudioOutputDevice(
    name: "Haut-parleur du téléphone",
    type: AudioOutputType.speaker,
    isExternal: false,
  );

  AudioOutputDevice get currentDevice => _currentDevice;
  Stream<AudioOutputDevice> get deviceStream => _deviceController.stream;

  void _init() {
    try {
      _eventChannel.receiveBroadcastStream().listen((event) {
        if (event is Map) {
          _currentDevice = AudioOutputDevice.fromMap(event);
          _deviceController.add(_currentDevice);
        }
      }, onError: (_) {});

      _fetchCurrentDevice();
    } catch (_) {}
  }

  Future<void> _fetchCurrentDevice() async {
    try {
      final res = await _methodChannel.invokeMethod('getCurrentDevice');
      if (res is Map) {
        _currentDevice = AudioOutputDevice.fromMap(res);
        _deviceController.add(_currentDevice);
      }
    } catch (_) {}
  }

  Future<void> openOutputSwitcher() async {
    try {
      await _methodChannel.invokeMethod('openOutputSwitcher');
    } catch (e) {
      debugPrint("Erreur ouverture sélecteur audio: $e");
    }
  }
}
