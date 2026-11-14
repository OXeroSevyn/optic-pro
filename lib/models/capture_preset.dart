import 'lens_capability.dart';

enum PresetType {
  interview,
  cinematic24,
  actionSlowMo,
  lowLight,
  documentaryRunAndGun,
}

class CapturePreset {
  final PresetType type;
  final String title;
  final String description;
  final int targetFps;
  final int targetWidth;
  final int targetHeight;
  final double targetBitrateMbps;
  final String framingGuide; // "thirds", "crosshair", "anamorphic", "none"
  final String lutPreviewName; // "rec709", "flat", "film_warm", "none"
  final String notes;

  const CapturePreset({
    required this.type,
    required this.title,
    required this.description,
    required this.targetFps,
    required this.targetWidth,
    required this.targetHeight,
    required this.targetBitrateMbps,
    required this.framingGuide,
    required this.lutPreviewName,
    required this.notes,
  });

  /// Adapts the preset to the active lens's true capabilities
  CapturePreset adaptToLens(LensCapability lens) {
    int adaptedWidth = targetWidth;
    int adaptedHeight = targetHeight;
    int adaptedFps = targetFps;
    final List<String> adaptationNotes = [];

    // Check if target resolution is supported
    final hasTargetRes = lens.videoResolutions.any(
      (r) => r.width == targetWidth && r.height == targetHeight,
    );

    if (!hasTargetRes && lens.videoResolutions.isNotEmpty) {
      // Find closest supported resolution (prefer 1080p if 4K unavailable)
      final fallbackRes = lens.videoResolutions.firstWhere(
        (r) => r.width <= targetWidth,
        orElse: () => lens.videoResolutions.first,
      );
      adaptedWidth = fallbackRes.width;
      adaptedHeight = fallbackRes.height;
      adaptationNotes.add('Resolution adapted to ${fallbackRes.shortLabel} based on lens stream support.');
    }

    // Check frame rate capability for this resolution
    final matchingRes = lens.videoResolutions.firstWhere(
      (r) => r.width == adaptedWidth && r.height == adaptedHeight,
      orElse: () => lens.videoResolutions.isNotEmpty
          ? lens.videoResolutions.first
          : const VideoResolution(width: 1920, height: 1080, maxFps: 30),
    );

    if (targetFps > matchingRes.maxFps) {
      adaptedFps = matchingRes.maxFps;
      adaptationNotes.add('Lens max stream rate is ${matchingRes.maxFps} fps (requested $targetFps fps).');
    }

    return CapturePreset(
      type: type,
      title: title,
      description: description,
      targetFps: adaptedFps,
      targetWidth: adaptedWidth,
      targetHeight: adaptedHeight,
      targetBitrateMbps: targetBitrateMbps,
      framingGuide: framingGuide,
      lutPreviewName: lutPreviewName,
      notes: adaptationNotes.isEmpty ? notes : adaptationNotes.join(' '),
    );
  }

  static List<CapturePreset> getAllPresets() {
    return const [
      CapturePreset(
        type: PresetType.interview,
        title: 'Interview / Dialogue',
        description: 'Optimized for speech clarity, stable autofocus, and rule-of-thirds framing.',
        targetFps: 30,
        targetWidth: 1920,
        targetHeight: 1080,
        targetBitrateMbps: 25.0,
        framingGuide: 'thirds',
        lutPreviewName: 'rec709',
        notes: 'Monitors audio levels closely to prevent speech clipping.',
      ),
      CapturePreset(
        type: PresetType.cinematic24,
        title: 'Cinematic 24p',
        description: 'Traditional motion cadence with 2.39:1 widescreen guides and filmic preview.',
        targetFps: 24,
        targetWidth: 3840,
        targetHeight: 2160,
        targetBitrateMbps: 50.0,
        framingGuide: 'anamorphic',
        lutPreviewName: 'film_warm',
        notes: 'Simulates 180° shutter angle (1/48s) when manual controls are available.',
      ),
      CapturePreset(
        type: PresetType.actionSlowMo,
        title: 'Action / High Speed',
        description: 'Crisp fast motion or slow-motion playback with enhanced stabilization.',
        targetFps: 60,
        targetWidth: 1920,
        targetHeight: 1080,
        targetBitrateMbps: 45.0,
        framingGuide: 'crosshair',
        lutPreviewName: 'rec709',
        notes: 'Requires active EIS/OIS and adequate lighting for higher shutter speeds.',
      ),
      CapturePreset(
        type: PresetType.lowLight,
        title: 'Low Light / Night',
        description: 'Maximized light gathering with wider exposure window and noise control.',
        targetFps: 30,
        targetWidth: 1920,
        targetHeight: 1080,
        targetBitrateMbps: 30.0,
        framingGuide: 'none',
        lutPreviewName: 'rec709',
        notes: 'Caps ISO gain to preserve shadow detail and avoid severe sensor chroma noise.',
      ),
      CapturePreset(
        type: PresetType.documentaryRunAndGun,
        title: 'Run & Gun / Doc',
        description: 'Fast responsive capture with safe margin framing and continuous stabilization.',
        targetFps: 30,
        targetWidth: 1920,
        targetHeight: 1080,
        targetBitrateMbps: 35.0,
        framingGuide: 'thirds',
        lutPreviewName: 'rec709',
        notes: 'Reliable handheld capture with automatic exposure compensation.',
      ),
    ];
  }
}
