import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opticpro/models/capture_preset.dart';
import 'package:opticpro/models/lens_capability.dart';
import 'package:opticpro/models/media_item.dart';
import 'package:opticpro/models/system_telemetry.dart';
import 'package:opticpro/widgets/audio_meter_widget.dart';
import 'package:opticpro/widgets/monitoring_overlays.dart';
import 'package:opticpro/widgets/pre_recording_warning_dialog.dart';
import 'package:opticpro/widgets/telemetry_bar.dart';

void main() {
  group('LensCapability & Hardware Interpretation Tests', () {
    test('Correctly identifies RAW Still vs RAW Video constraints', () {
      final lensMap = {
        'cameraId': '0',
        'facing': 'BACK',
        'hardwareLevel': 'FULL',
        'focalLengths': [4.5],
        'apertures': [1.8],
        'minFocusDistance': 10.0,
        'canManualFocus': true,
        'hasManualSensor': true,
        'hasManualPostProcessing': true,
        'isoMin': 50,
        'isoMax': 6400,
        'exposureMinNs': 50000,
        'exposureMaxNs': 1000000000,
        'supportsRawStill': true,
        'rawFormats': ['RAW_SENSOR (DNG)', 'RAW10'],
        'supportsRawVideo': false,
        'rawVideoExplanation': 'Direct continuous RAW video stream dumping is not supported.',
        'supportsTenBitHdr': false,
        'supportsLogProfile': false,
        'logExplanation': 'Log profile requires 10-bit HDR hardware.',
        'videoResolutions': [
          {'width': 3840, 'height': 2160, 'maxFps': 30},
          {'width': 1920, 'height': 1080, 'maxFps': 60},
        ],
      };

      final lens = LensCapability.fromMap(lensMap);

      expect(lens.cameraId, '0');
      expect(lens.hardwareLevel, 'FULL');
      expect(lens.supportsRawStill, isTrue);
      expect(lens.rawFormats.contains('RAW_SENSOR (DNG)'), isTrue);
      // RAW video must NOT be falsely advertised
      expect(lens.supportsRawVideo, isFalse);
      expect(lens.rawVideoExplanation.contains('not supported'), isTrue);
      // 4K support check
      expect(lens.supports4K, isTrue);
      expect(lens.supports60Fps, isTrue);
      // Shutter speed formatting
      expect(lens.formatShutterSpeed(1.0 / 60.0), '1/60 s');
      expect(lens.formatShutterSpeed(2.0), '2.0 s');
    });

    test('Gracefully falls back for legacy or limited cameras', () {
      final fallbackLens = LensCapability.fallback(cameraId: '1', facing: 'FRONT');
      expect(fallbackLens.facing, 'FRONT');
      expect(fallbackLens.hardwareLevel, 'LIMITED');
      expect(fallbackLens.supportsRawStill, isFalse);
      expect(fallbackLens.supportsRawVideo, isFalse);
    });
  });

  group('SystemTelemetry & Time Remaining Estimation Tests', () {
    test('Calculates remaining recording time accurately for given bitrates', () {
      const telemetry = SystemTelemetry(
        freeStorageBytes: 10 * 1024 * 1024 * 1024, // 10 GB free
        totalStorageBytes: 128 * 1024 * 1024 * 1024,
        batteryPct: 75,
        isCharging: false,
        batteryTempC: 34.0,
        thermalStatus: 'NORMAL',
        thermalInt: 0,
        audioDevices: [],
      );

      expect(telemetry.freeStorageGB.toStringAsFixed(1), '10.0');
      expect(telemetry.formattedFreeStorage, '10.0 GB free');

      // 40 Mbps bitrate = (40 * 60) / 8 = 300 MB per minute.
      // Usable MB = (10240 - 500 reserve) = 9740 MB.
      // 9740 / 300 = 32.46 minutes.
      final mins = telemetry.calculateRemainingRecordMinutes(40.0);
      expect(mins, closeTo(32.46, 0.5));
      expect(telemetry.formattedRemainingTime(40.0), '32m remaining');
    });

    test('Correctly identifies thermal and storage risk conditions', () {
      const normalTelemetry = SystemTelemetry(
        freeStorageBytes: 20 * 1024 * 1024 * 1024,
        totalStorageBytes: 64 * 1024 * 1024 * 1024,
        batteryPct: 80,
        isCharging: false,
        batteryTempC: 31.0,
        thermalStatus: 'NORMAL',
        thermalInt: 0,
        audioDevices: [],
      );
      expect(normalTelemetry.isThermalSevere, isFalse);
      expect(normalTelemetry.isStorageLow, isFalse);

      const hotTelemetry = SystemTelemetry(
        freeStorageBytes: 1024 * 1024 * 1024, // 1 GB free (< 2GB is low)
        totalStorageBytes: 64 * 1024 * 1024 * 1024,
        batteryPct: 15, // < 20%
        isCharging: false,
        batteryTempC: 46.5, // >= 45°C
        thermalStatus: 'SEVERE',
        thermalInt: 3,
        audioDevices: [],
      );
      expect(hotTelemetry.isThermalSevere, isTrue);
      expect(hotTelemetry.isStorageLow, isTrue);
      expect(hotTelemetry.thermalWarning != null, isTrue);
    });
  });

  group('CapturePreset Adaptation Tests', () {
    test('Adapts 4K 60fps preset down to 1080p 30fps if lens does not support 4K or 60fps', () {
      const limitedLens = LensCapability(
        cameraId: '0',
        facing: 'BACK',
        hardwareLevel: 'LIMITED',
        focalLengths: [3.8],
        apertures: [2.0],
        minFocusDistance: 0.0,
        canManualFocus: false,
        hasManualSensor: false,
        hasManualPostProcessing: false,
        isoMin: 100,
        isoMax: 800,
        exposureMinNs: 100000,
        exposureMaxNs: 500000000,
        expMin: -2,
        expMax: 2,
        expStep: 0.5,
        hasOis: false,
        hasEis: false,
        supportsRawStill: false,
        rawFormats: [],
        supportsRawVideo: false,
        rawVideoExplanation: 'Not supported',
        supportsTenBitHdr: false,
        supportsLogProfile: false,
        logExplanation: 'Not supported',
        videoResolutions: [
          VideoResolution(width: 1920, height: 1080, maxFps: 30),
          VideoResolution(width: 1280, height: 720, maxFps: 30),
        ],
        physicalCameraIds: [],
      );

      const cinematicPreset = CapturePreset(
        type: PresetType.cinematic24,
        title: 'Cinematic 24p',
        description: '4K 24p target',
        targetFps: 24,
        targetWidth: 3840,
        targetHeight: 2160,
        targetBitrateMbps: 50.0,
        framingGuide: 'anamorphic',
        lutPreviewName: 'film_warm',
        notes: '',
      );

      final adapted = cinematicPreset.adaptToLens(limitedLens);

      // Should automatically adapt resolution to 1080p without failing
      expect(adapted.targetWidth, 1920);
      expect(adapted.targetHeight, 1080);
      expect(adapted.notes.contains('adapted'), isTrue);
    });
  });

  group('PreRecordingWarningDialog Trigger Logic Tests', () {
    test('Triggers warning for 4K video or severe heat', () {
      const normalTelem = SystemTelemetry(
        freeStorageBytes: 30 * 1024 * 1024 * 1024,
        totalStorageBytes: 128 * 1024 * 1024 * 1024,
        batteryPct: 90,
        isCharging: false,
        batteryTempC: 30.0,
        thermalStatus: 'NORMAL',
        thermalInt: 0,
        audioDevices: [],
      );

      // 1080p 30fps with normal telemetry should NOT trigger warning
      final noWarn = PreRecordingWarningDialog.shouldWarn(
        resolution: const VideoResolution(width: 1920, height: 1080, maxFps: 30),
        fps: 30,
        telemetry: normalTelem,
      );
      expect(noWarn, isFalse);

      // 4K UHD should trigger warning
      final warn4K = PreRecordingWarningDialog.shouldWarn(
        resolution: const VideoResolution(width: 3840, height: 2160, maxFps: 30),
        fps: 30,
        telemetry: normalTelem,
      );
      expect(warn4K, isTrue);

      // 60fps should trigger warning
      final warn60 = PreRecordingWarningDialog.shouldWarn(
        resolution: const VideoResolution(width: 1920, height: 1080, maxFps: 60),
        fps: 60,
        telemetry: normalTelem,
      );
      expect(warn60, isTrue);
    });
  });

  group('MediaItem Metadata Serialization Tests', () {
    test('Serializes and deserializes cleanly with correct labels', () {
      final item = MediaItem(
        id: 'test_123',
        filePath: '/data/user/0/opticpro/VID_20261112.mp4',
        fileName: 'VID_20261112.mp4',
        recordedAt: DateTime(2026, 11, 12, 14, 30),
        durationSeconds: 125,
        fileSizeBytes: 250 * 1024 * 1024, // 250 MB
        width: 3840,
        height: 2160,
        isVideo: true,
        isRaw: false,
        lensId: '0',
        iso: 400,
        shutterSeconds: 1.0 / 48.0,
        lutName: 'Rec.709 Natural',
      );

      expect(item.resolutionLabel, '4K UHD');
      expect(item.formattedDuration, '02:05');
      expect(item.formattedSize, '250.0 MB');

      final map = item.toMap();
      final roundtrip = MediaItem.fromMap(map);

      expect(roundtrip.id, item.id);
      expect(roundtrip.fileName, item.fileName);
      expect(roundtrip.width, 3840);
      expect(roundtrip.durationSeconds, 125);
      expect(roundtrip.iso, 400);
      expect(roundtrip.lutName, 'Rec.709 Natural');
    });
  });

  group('UI Widgets Smoke Tests', () {
    testWidgets('AudioMeterWidget renders decibels and clipping badge', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AudioMeterWidget(
              rmsDb: -14.0,
              peakDb: -0.5,
              isClipping: true,
              micName: 'Built-in Mic',
            ),
          ),
        ),
      );

      expect(find.text('CLIP'), findsOneWidget);
      expect(find.text('-1dB'), findsOneWidget);
      expect(find.byType(AudioMeterWidget), findsOneWidget);
    });

    testWidgets('TelemetryBar renders remaining storage and battery status', (WidgetTester tester) async {
      const telemetry = SystemTelemetry(
        freeStorageBytes: 15 * 1024 * 1024 * 1024,
        totalStorageBytes: 128 * 1024 * 1024 * 1024,
        batteryPct: 88,
        isCharging: false,
        batteryTempC: 33.0,
        thermalStatus: 'NORMAL',
        thermalInt: 0,
        audioDevices: [],
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TelemetryBar(
              telemetry: telemetry,
              isRecording: true,
              recordingElapsedSeconds: 65,
            ),
          ),
        ),
      );

      expect(find.text('REC 01:05'), findsOneWidget);
      expect(find.text('88%'), findsOneWidget);
      expect(find.text('33°C'), findsOneWidget);
    });

    test('LutHelper returns valid 20-element color matrices', () {
      final rec709 = LutHelper.getMatrixForLut('rec709');
      expect(rec709.length, 20);

      final flat = LutHelper.getMatrixForLut('flat');
      expect(flat.length, 20);

      final warm = LutHelper.getMatrixForLut('film_warm');
      expect(warm.length, 20);

      final bAndW = LutHelper.getMatrixForLut('monochrome');
      expect(bAndW.length, 20);
    });
  });
}
