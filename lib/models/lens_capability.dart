class VideoResolution {
  final int width;
  final int height;
  final int maxFps;

  const VideoResolution({
    required this.width,
    required this.height,
    required this.maxFps,
  });

  String get label {
    if (width >= 3840 && height >= 2160) return '4K UHD (3840×2160)';
    if (width >= 1920 && height >= 1080) return '1080p FHD (1920×1080)';
    if (width >= 1280 && height >= 720) return '720p HD (1280×720)';
    return '$width×$height';
  }

  String get shortLabel {
    if (width >= 3840 && height >= 2160) return '4K';
    if (width >= 1920 && height >= 1080) return '1080p';
    if (width >= 1280 && height >= 720) return '720p';
    return '$height p';
  }

  double get aspectRatio => width / height;

  factory VideoResolution.fromMap(Map<dynamic, dynamic> map) {
    return VideoResolution(
      width: (map['width'] as num?)?.toInt() ?? 1920,
      height: (map['height'] as num?)?.toInt() ?? 1080,
      maxFps: (map['maxFps'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toMap() => {
    'width': width,
    'height': height,
    'maxFps': maxFps,
  };
}

class LensCapability {
  final String cameraId;
  final String facing; // "BACK", "FRONT", "EXTERNAL"
  final String hardwareLevel; // "LEGACY", "LIMITED", "FULL", "LEVEL_3"
  final List<double> focalLengths;
  final List<double> apertures;
  final double minFocusDistance;
  final bool canManualFocus;
  final bool hasManualSensor;
  final bool hasManualPostProcessing;
  final int isoMin;
  final int isoMax;
  final int exposureMinNs;
  final int exposureMaxNs;
  final int expMin;
  final int expMax;
  final double expStep;
  final bool hasOis;
  final bool hasEis;
  final bool supportsRawStill;
  final List<String> rawFormats;
  final bool supportsRawVideo;
  final String rawVideoExplanation;
  final bool supportsTenBitHdr;
  final bool supportsLogProfile;
  final String logExplanation;
  final List<VideoResolution> videoResolutions;
  final List<String> physicalCameraIds;

  const LensCapability({
    required this.cameraId,
    required this.facing,
    required this.hardwareLevel,
    required this.focalLengths,
    required this.apertures,
    required this.minFocusDistance,
    required this.canManualFocus,
    required this.hasManualSensor,
    required this.hasManualPostProcessing,
    required this.isoMin,
    required this.isoMax,
    required this.exposureMinNs,
    required this.exposureMaxNs,
    required this.expMin,
    required this.expMax,
    required this.expStep,
    required this.hasOis,
    required this.hasEis,
    required this.supportsRawStill,
    required this.rawFormats,
    required this.supportsRawVideo,
    required this.rawVideoExplanation,
    required this.supportsTenBitHdr,
    required this.supportsLogProfile,
    required this.logExplanation,
    required this.videoResolutions,
    required this.physicalCameraIds,
  });

  String get lensTypeDisplayName {
    if (facing == 'FRONT') return 'Front Selfie ($cameraId)';
    if (focalLengths.isNotEmpty) {
      final fl = focalLengths.first;
      if (fl < 2.5) return 'Ultra-Wide ($cameraId)';
      if (fl > 5.5) return 'Telephoto ($cameraId)';
    }
    return 'Main Wide ($cameraId)';
  }

  bool get supports4K => videoResolutions.any((r) => r.width >= 3840 && r.height >= 2160);
  bool get supports60Fps => videoResolutions.any((r) => r.maxFps >= 60);

  double get minShutterSeconds => exposureMinNs / 1000000000.0;
  double get maxShutterSeconds => exposureMaxNs / 1000000000.0;

  String formatShutterSpeed(double seconds) {
    if (seconds <= 0) return 'Auto';
    if (seconds < 1.0) {
      final denominator = (1.0 / seconds).round();
      return '1/$denominator s';
    }
    return '${seconds.toStringAsFixed(1)} s';
  }

  factory LensCapability.fromMap(Map<dynamic, dynamic> map) {
    final resList = (map['videoResolutions'] as List<dynamic>?)
            ?.map((e) => VideoResolution.fromMap(e as Map<dynamic, dynamic>))
            .toList() ??
        [];

    // Sort resolutions descending by pixel count
    resList.sort((a, b) => (b.width * b.height).compareTo(a.width * a.height));

    return LensCapability(
      cameraId: (map['cameraId'] ?? '0').toString(),
      facing: (map['facing'] ?? 'BACK').toString(),
      hardwareLevel: (map['hardwareLevel'] ?? 'LIMITED').toString(),
      focalLengths: ((map['focalLengths'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      apertures: ((map['apertures'] as List<dynamic>?) ?? [])
          .map((e) => (e as num).toDouble())
          .toList(),
      minFocusDistance: (map['minFocusDistance'] as num?)?.toDouble() ?? 0.0,
      canManualFocus: map['canManualFocus'] == true,
      hasManualSensor: map['hasManualSensor'] == true,
      hasManualPostProcessing: map['hasManualPostProcessing'] == true,
      isoMin: (map['isoMin'] as num?)?.toInt() ?? 100,
      isoMax: (map['isoMax'] as num?)?.toInt() ?? 800,
      exposureMinNs: (map['exposureMinNs'] as num?)?.toInt() ?? 100000,
      exposureMaxNs: (map['exposureMaxNs'] as num?)?.toInt() ?? 1000000000,
      expMin: (map['expMin'] as num?)?.toInt() ?? -4,
      expMax: (map['expMax'] as num?)?.toInt() ?? 4,
      expStep: (map['expStep'] as num?)?.toDouble() ?? 0.5,
      hasOis: map['hasOis'] == true,
      hasEis: map['hasEis'] == true,
      supportsRawStill: map['supportsRawStill'] == true,
      rawFormats: ((map['rawFormats'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
      supportsRawVideo: map['supportsRawVideo'] == true,
      rawVideoExplanation: (map['rawVideoExplanation'] ??
              'RAW video is not exposed by standard Android media pipeline.')
          .toString(),
      supportsTenBitHdr: map['supportsTenBitHdr'] == true,
      supportsLogProfile: map['supportsLogProfile'] == true,
      logExplanation: (map['logExplanation'] ??
              'Log profiles require dedicated 10-bit HDR/Log hardware support.')
          .toString(),
      videoResolutions: resList,
      physicalCameraIds: ((map['physicalCameraIds'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  /// Default fallback lens capability for devices or emulators where camera2 is limited
  factory LensCapability.fallback({String cameraId = '0', String facing = 'BACK'}) {
    return LensCapability(
      cameraId: cameraId,
      facing: facing,
      hardwareLevel: 'LIMITED',
      focalLengths: [4.2],
      apertures: [1.8],
      minFocusDistance: 10.0,
      canManualFocus: true,
      hasManualSensor: true,
      hasManualPostProcessing: true,
      isoMin: 100,
      isoMax: 3200,
      exposureMinNs: 100000, // 1/10000s
      exposureMaxNs: 500000000, // 0.5s
      expMin: -4,
      expMax: 4,
      expStep: 0.5,
      hasOis: false,
      hasEis: true,
      supportsRawStill: false,
      rawFormats: [],
      supportsRawVideo: false,
      rawVideoExplanation:
          'Android standard camera pipeline compresses video to H.264/HEVC or YUV. Direct uncompressed RAW video recording is not exposed by this device.',
      supportsTenBitHdr: false,
      supportsLogProfile: false,
      logExplanation:
          'True 10-bit Log requires dedicated manufacturer Log SDK or 10-bit HDR HAL support. Real-time Rec.709 monitoring LUT is available.',
      videoResolutions: const [
        VideoResolution(width: 3840, height: 2160, maxFps: 30),
        VideoResolution(width: 1920, height: 1080, maxFps: 60),
        VideoResolution(width: 1280, height: 720, maxFps: 60),
      ],
      physicalCameraIds: [],
    );
  }
}
