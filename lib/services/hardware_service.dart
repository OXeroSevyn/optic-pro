import 'dart:async';
import 'package:flutter/services.dart';
import '../models/lens_capability.dart';
import '../models/system_telemetry.dart';

class HardwareService {
  static const MethodChannel _channel = MethodChannel('com.opticpro/hardware');

  /// Fetches deep Camera2 hardware capabilities for all detected cameras
  static Future<List<LensCapability>> getCameraCapabilities() async {
    try {
      final List<dynamic>? rawList = await _channel.invokeMethod('getCameraCapabilities');
      if (rawList != null && rawList.isNotEmpty) {
        return rawList
            .map((item) => LensCapability.fromMap(item as Map<dynamic, dynamic>))
            .toList();
      }
    } on PlatformException catch (_) {
      // Fallback for non-Android platforms or restricted hardware
    } catch (_) {
      // General error fallback
    }

    return [
      LensCapability.fallback(cameraId: '0', facing: 'BACK'),
      LensCapability.fallback(cameraId: '1', facing: 'FRONT'),
    ];
  }

  /// Fetches system telemetry (storage, battery, thermals, audio input devices)
  static Future<SystemTelemetry> getSystemTelemetry() async {
    try {
      final dynamic raw = await _channel.invokeMethod('getSystemTelemetry');
      if (raw is Map) {
        return SystemTelemetry.fromMap(raw);
      }
    } on PlatformException catch (_) {
      // Return fallback telemetry
    } catch (_) {
      // Fallback
    }

    return SystemTelemetry.fallback();
  }

  /// Starts real-time native AudioRecord background level monitoring
  static Future<bool> startAudioMeter() async {
    try {
      final bool? success = await _channel.invokeMethod('startAudioMeter');
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Stops native AudioRecord measurement
  static Future<void> stopAudioMeter() async {
    try {
      await _channel.invokeMethod('stopAudioMeter');
    } catch (_) {
      // Ignore cleanup error
    }
  }

  /// Polls the latest measured audio levels (RMS dBFS and Peak dBFS)
  static Future<AudioLevelData> getAudioLevel() async {
    try {
      final dynamic raw = await _channel.invokeMethod('getAudioLevel');
      if (raw is Map) {
        return AudioLevelData(
          rmsDb: (raw['rmsDb'] as num?)?.toDouble() ?? -60.0,
          peakDb: (raw['peakDb'] as num?)?.toDouble() ?? -60.0,
          isClipping: raw['isClipping'] == true,
        );
      }
    } catch (_) {
      // Ignore
    }

    return const AudioLevelData(rmsDb: -60.0, peakDb: -60.0, isClipping: false);
  }
}

class AudioLevelData {
  final double rmsDb;
  final double peakDb;
  final bool isClipping;

  const AudioLevelData({
    required this.rmsDb,
    required this.peakDb,
    required this.isClipping,
  });
}
