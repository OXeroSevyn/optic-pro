import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/capture_preset.dart';
import '../models/lens_capability.dart';
import '../models/system_telemetry.dart';
import '../services/hardware_service.dart';
import '../services/media_storage_service.dart';
import '../widgets/audio_meter_widget.dart';
import '../widgets/capability_sheet.dart';
import '../widgets/manual_controls_drawer.dart';
import '../widgets/monitoring_overlays.dart';
import '../widgets/pre_recording_warning_dialog.dart';
import '../widgets/preset_selector.dart';
import '../widgets/telemetry_bar.dart';
import 'gallery_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  List<CameraDescription> _availableCameras = [];
  CameraController? _controller;
  int _selectedCameraIndex = 0;
  double _minimumZoom = 1.0;
  double _maximumZoom = 1.0;
  double _pinchStartZoom = 1.0;

  List<LensCapability> _lensCapabilities = [];
  LensCapability? _currentLensCapability;

  SystemTelemetry _telemetry = SystemTelemetry.fallback();
  Timer? _telemetryTimer;

  // Audio meter state
  Timer? _audioTimer;
  double _rmsDb = -60.0;
  double _peakDb = -60.0;
  bool _isClipping = false;

  // Capture mode
  bool _isVideoMode = false;
  bool _isRecording = false;
  int _recordingElapsedSeconds = 0;
  Timer? _recordTimer;

  // Creator Manual Settings
  ManualSettingsState _manualSettings = const ManualSettingsState();
  bool _showManualDrawer = false;

  // On-Set Monitoring Overlays state
  GridMode _framingGrid = GridMode.thirds;
  bool _showHistogram = false;
  bool _histogramRgb = false;
  bool _focusPeaking = false;
  PeakingColor _peakingColor = PeakingColor.green;
  bool _zebraStripes = false;
  bool _falseColor = false;
  String _activeLut = 'none'; // 'none', 'rec709', 'flat', 'film_warm', 'clean_cool', 'monochrome'
  bool _captureRawStill = false;
  FlashMode _flashMode = FlashMode.off;
  String? _latestMediaPath;
  bool _latestMediaIsVideo = false;

  // Active capture preset
  CapturePreset? _activePreset;

  // Viewfinder Tap to focus
  Offset? _focusPoint;
  bool _showFocusReticle = false;
  Timer? _focusReticleTimer;

  bool _isInitializing = true;
  String? _initError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _telemetryTimer?.cancel();
    _audioTimer?.cancel();
    _recordTimer?.cancel();
    _focusReticleTimer?.cancel();
    HardwareService.stopAudioMeter();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      if (_isRecording) {
        _stopVideoRecording(saveSafely: true);
      }
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCameraController();
    }
  }

  Future<void> _initApp() async {
    setState(() => _isInitializing = true);

    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
      Permission.photos,
    ].request();

    try {
      final savedMedia = await MediaStorageService.loadMediaCatalog();
      if (savedMedia.isNotEmpty && mounted) {
        setState(() {
          _latestMediaPath = savedMedia.first.filePath;
          _latestMediaIsVideo = savedMedia.first.isVideo;
        });
      }

      final caps = await HardwareService.getCameraCapabilities();
      _lensCapabilities = caps;

      final cameras = await availableCameras();
      _availableCameras = cameras;

      if (_availableCameras.isNotEmpty) {
        await _initCameraController();
      } else {
        setState(() {
          _initError = 'No camera sensors detected on this device.';
          _isInitializing = false;
        });
      }

      await _refreshTelemetry();
      _telemetryTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _refreshTelemetry(),
      );

      final micStarted = await HardwareService.startAudioMeter();
      if (micStarted) {
        _audioTimer = Timer.periodic(const Duration(milliseconds: 60), (
          _,
        ) async {
          final level = await HardwareService.getAudioLevel();
          if (mounted) {
            setState(() {
              _rmsDb = level.rmsDb;
              _peakDb = level.peakDb;
              _isClipping = level.isClipping;
            });
          }
        });
      }
    } catch (e) {
      setState(() {
        _initError = 'Camera initialization failed: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _refreshTelemetry() async {
    final t = await HardwareService.getSystemTelemetry();
    if (mounted) {
      setState(() => _telemetry = t);

      if (_isRecording &&
          (t.thermalStatus == 'CRITICAL' || t.thermalStatus == 'EMERGENCY')) {
        _stopVideoRecording(saveSafely: true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFFF453A),
            content: Text(
              'Recording stopped: Device thermal emergency threshold reached.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _initCameraController() async {
    if (_availableCameras.isEmpty) return;

    final camDesc = _availableCameras[_selectedCameraIndex];
    final cap = _lensCapabilities.firstWhere(
      (c) =>
          c.cameraId == camDesc.name ||
          c.facing ==
              (camDesc.lensDirection == CameraLensDirection.front
                  ? 'FRONT'
                  : 'BACK'),
      orElse: () => _lensCapabilities.isNotEmpty
          ? _lensCapabilities.first
          : LensCapability.fallback(),
    );

    _currentLensCapability = cap;

    await _controller?.dispose();

    final newController = CameraController(
      camDesc,
      ResolutionPreset.max,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await newController.initialize();
      final minimumZoom = await newController.getMinZoomLevel();
      final maximumZoom = await newController.getMaxZoomLevel();
      if (mounted) {
        setState(() {
          _controller = newController;
          _minimumZoom = minimumZoom;
          _maximumZoom = maximumZoom;
          _manualSettings = _manualSettings.copyWith(
            zoomRatio: _manualSettings.zoomRatio
                .clamp(minimumZoom, maximumZoom)
                .toDouble(),
          );
          _isInitializing = false;
          _initError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _initError = 'Failed to open lens: $e';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _switchCamera(int newIndex) async {
    if (_isRecording ||
        newIndex == _selectedCameraIndex ||
        newIndex >= _availableCameras.length)
      return;
    setState(() {
      _selectedCameraIndex = newIndex;
      _isInitializing = true;
    });
    await _initCameraController();
    if (_activePreset != null && _currentLensCapability != null) {
      setState(() {
        _activePreset = _activePreset!.adaptToLens(_currentLensCapability!);
      });
    }
  }

  void _onViewfinderTap(TapUpDetails details, BoxConstraints constraints) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    final offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );

    setState(() {
      _focusPoint = details.localPosition;
      _showFocusReticle = true;
    });

    _focusReticleTimer?.cancel();
    _focusReticleTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _showFocusReticle = false);
    });

    try {
      _controller?.setFocusPoint(offset);
      _controller?.setExposurePoint(offset);
    } catch (_) {}
  }

  Future<void> _onShutterPressed() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (_isVideoMode) {
      if (_isRecording) {
        await _stopVideoRecording(saveSafely: true);
      } else {
        await _startVideoRecording();
      }
    } else {
      await _takePhoto();
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || _isRecording) return;

    final targetRes =
        _currentLensCapability?.videoResolutions.isNotEmpty == true
        ? _currentLensCapability!.videoResolutions.first
        : const VideoResolution(width: 1920, height: 1080, maxFps: 30);

    final proceed = await PreRecordingWarningDialog.checkAndShow(
      context,
      resolution: targetRes,
      fps: _activePreset?.targetFps ?? 30,
      telemetry: _telemetry,
    );

    if (!proceed) return;

    try {
      await _controller?.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingElapsedSeconds = 0;
      });

      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingElapsedSeconds++);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text('Recording failed to start: $e'),
          ),
        );
      }
    }
  }

  Future<void> _stopVideoRecording({bool saveSafely = true}) async {
    if (_controller == null || !_isRecording) return;

    _recordTimer?.cancel();
    try {
      final XFile videoFile = await _controller!.stopVideoRecording();
      setState(() => _isRecording = false);

      if (saveSafely) {
        final res = _currentLensCapability?.videoResolutions.isNotEmpty == true
            ? _currentLensCapability!.videoResolutions.first
            : const VideoResolution(width: 1920, height: 1080, maxFps: 30);

        final savedItem = await MediaStorageService.saveCapturedMedia(
          sourcePath: videoFile.path,
          isVideo: true,
          isRaw: false,
          width: res.width,
          height: res.height,
          durationSeconds: _recordingElapsedSeconds,
          lensId: _currentLensCapability?.cameraId ?? '0',
          iso: _manualSettings.isAutoIso ? null : _manualSettings.iso,
          shutterSeconds: _manualSettings.isAutoShutter
              ? null
              : _manualSettings.shutterSeconds,
          lutName: _activeLut != 'none'
              ? LutHelper.getDisplayName(_activeLut)
              : null,
        );

        if (mounted) {
          setState(() {
            _latestMediaPath = savedItem.filePath;
            _latestMediaIsVideo = true;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF1E2128),
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xFF34C759),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Saved: ${savedItem.fileName} (${savedItem.formattedSize})',
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isRecording = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text('Error saving recording: $e'),
          ),
        );
      }
    }
  }

  Future<void> _takePhoto() async {
    if (_controller == null) return;

    try {
      final XFile photo = await _controller!.takePicture();
      final isRaw =
          _captureRawStill &&
          (_currentLensCapability?.supportsRawStill == true);

      final savedItem = await MediaStorageService.saveCapturedMedia(
        sourcePath: photo.path,
        isVideo: false,
        isRaw: isRaw,
        width: 4000,
        height: 3000,
        durationSeconds: 0,
        lensId: _currentLensCapability?.cameraId ?? '0',
        iso: _manualSettings.isAutoIso ? null : _manualSettings.iso,
        shutterSeconds: _manualSettings.isAutoShutter
            ? null
            : _manualSettings.shutterSeconds,
        lutName: _activeLut != 'none'
            ? LutHelper.getDisplayName(_activeLut)
            : null,
      );

      if (mounted) {
        setState(() {
          _latestMediaPath = savedItem.filePath;
          _latestMediaIsVideo = false;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF1E2128),
            duration: const Duration(seconds: 2),
            content: Row(
              children: [
                const Icon(
                  Icons.photo_camera,
                  color: Color(0xFF74E0D0),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Captured ${isRaw ? "RAW DNG" : "photo"}: ${savedItem.fileName}',
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFFF453A),
            content: Text('Capture failed: $e'),
          ),
        );
      }
    }
  }

  void _onManualSettingsChanged(ManualSettingsState newSettings) {
    setState(() => _manualSettings = newSettings);

    try {
      _controller?.setExposureOffset(newSettings.evBias);
    } catch (_) {}

    _applyZoom(newSettings.zoomRatio);
  }

  Future<void> _applyZoom(double requestedZoom) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    try {
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      final zoom = requestedZoom.clamp(minZoom, maxZoom).toDouble();
      if (mounted && (zoom - _manualSettings.zoomRatio).abs() > 0.001) {
        setState(
          () => _manualSettings = _manualSettings.copyWith(zoomRatio: zoom),
        );
      }
      await controller.setZoomLevel(zoom);
    } catch (_) {}
  }

  Future<void> _cycleFlashMode() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    const modes = [
      FlashMode.off,
      FlashMode.auto,
      FlashMode.always,
      FlashMode.torch,
    ];
    final next = modes[(modes.indexOf(_flashMode) + 1) % modes.length];
    try {
      await _controller!.setFlashMode(next);
      if (mounted) setState(() => _flashMode = next);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Flash control is unavailable on this camera.'),
          ),
        );
      }
    }
  }

  IconData get _flashIcon => switch (_flashMode) {
    FlashMode.off => Icons.flash_off_rounded,
    FlashMode.auto => Icons.flash_auto_rounded,
    FlashMode.always => Icons.flash_on_rounded,
    FlashMode.torch => Icons.highlight_rounded,
  };

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF74E0D0)),
              SizedBox(height: 16),
              Text(
                'Inspecting Camera2 Hardware...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_initError != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: Color(0xFFFF453A),
                ),
                const SizedBox(height: 16),
                Text(
                  _initError!,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _initApp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF74E0D0),
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('RETRY'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeLens = _currentLensCapability ?? LensCapability.fallback();

    return Scaffold(
      backgroundColor: const Color(0xFF080A0B),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTapUp: (details) => _onViewfinderTap(details, constraints),
                  onScaleStart: (_) =>
                      _pinchStartZoom = _manualSettings.zoomRatio,
                  onScaleUpdate: (details) {
                    if (details.scale != 1.0) {
                      _applyZoom(
                        (_pinchStartZoom * details.scale).clamp(
                          _minimumZoom,
                          _maximumZoom,
                        ),
                      );
                    }
                  },
                  child: ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      LutHelper.getMatrixForLut(_activeLut),
                    ),
                    child:
                        _controller != null && _controller!.value.isInitialized
                        ? CameraPreview(_controller!)
                        : const ColoredBox(color: Color(0xFF101719)),
                  ),
                ),
              ),
              Positioned.fill(child: FramingGridOverlay(mode: _framingGrid)),
              Positioned.fill(child: ZebraOverlay(enabled: _zebraStripes)),
              Positioned.fill(
                child: FocusPeakingOverlay(
                  enabled: _focusPeaking,
                  color: _peakingColor,
                ),
              ),
              Positioned.fill(child: FalseColorOverlay(enabled: _falseColor)),
              if (_showFocusReticle && _focusPoint != null)
                Positioned(
                  left: _focusPoint!.dx - 28,
                  top: _focusPoint!.dy - 28,
                  child: IgnorePointer(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFFFD75E),
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFD75E).withOpacity(0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.add,
                          size: 16,
                          color: Color(0xFFFFD75E),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 4,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    _roundControl(
                      icon: _flashIcon,
                      tooltip: 'Flash: ${_flashMode.name}',
                      onTap: _cycleFlashMode,
                    ),
                    const SizedBox(width: 8),
                    _roundControl(
                      icon: Icons.grid_3x3_rounded,
                      tooltip: 'Framing grid',
                      active: _framingGrid != GridMode.none,
                      onTap: _cycleFramingGrid,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.44),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isRecording) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFF453A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatRecordingTime(_recordingElapsedSeconds),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              Icons.circle,
                              color: Color(0xFFFFD75E),
                              size: 8,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isVideoMode ? 'VIDEO' : 'PHOTO',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    _roundControl(
                      icon: Icons.graphic_eq_rounded,
                      tooltip: 'Exposure monitor',
                      active: _showHistogram,
                      onTap: () =>
                          setState(() => _showHistogram = !_showHistogram),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<String>(
                      tooltip: 'Camera settings',
                      onSelected: (action) =>
                          _handleCameraMenu(action, activeLens),
                      color: const Color(0xFF172022),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'manual',
                          child: Text('Manual controls'),
                        ),
                        PopupMenuItem(
                          value: 'presets',
                          child: Text('Capture presets'),
                        ),
                        PopupMenuItem(
                          value: 'caps',
                          child: Text('Camera capabilities'),
                        ),
                        PopupMenuItem(
                          value: 'peaking',
                          child: Text('Toggle focus peaking'),
                        ),
                        PopupMenuItem(
                          value: 'zebra',
                          child: Text('Toggle zebra stripes'),
                        ),
                        PopupMenuItem(
                          value: 'false_color',
                          child: Text('Toggle false color'),
                        ),
                        PopupMenuItem(
                          value: 'lut',
                          child: Text('Change preview look'),
                        ),
                      ],
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          color: Color(0x7A000000),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 54,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: TelemetryBar(
                          telemetry: _telemetry,
                          isRecording: _isRecording,
                          recordingElapsedSeconds: _recordingElapsedSeconds,
                          currentBitrateMbps:
                              _activePreset?.targetBitrateMbps ?? 35.0,
                          onStorageTap: () => ScaffoldMessenger.of(context)
                              .showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Free storage: ${_telemetry.formattedFreeStorage}',
                                  ),
                                ),
                              ),
                          onThermalTap: () =>
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Device temperature: ${_telemetry.batteryTempC.toStringAsFixed(1)}°C',
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                    if (_isVideoMode) ...[
                      const SizedBox(width: 8),
                      AudioMeterWidget(
                        rmsDb: _rmsDb,
                        peakDb: _peakDb,
                        isClipping: _isClipping,
                        micName: _telemetry.audioDevices.isNotEmpty
                            ? _telemetry.audioDevices.first.name
                            : 'Built-in Mic',
                        isExternalMic: _telemetry.audioDevices.any(
                          (device) => device.isExternal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (_showHistogram)
                Positioned(
                  top: 106,
                  left: 12,
                  child: HistogramView(
                    showRgb: _histogramRgb,
                    onToggle: () =>
                        setState(() => _histogramRgb = !_histogramRgb),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildCaptureDock(activeLens, constraints),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRecordingTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return minutes + ':' + remaining;
  }

  Widget _roundControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? const Color(0xFFFFD75E)
            : Colors.black.withOpacity(0.48),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              color: active ? const Color(0xFF17130A) : Colors.white,
              size: 21,
            ),
          ),
        ),
      ),
    );
  }

  void _handleCameraMenu(String action, LensCapability lens) {
    switch (action) {
      case 'manual':
        setState(() => _showManualDrawer = !_showManualDrawer);
      case 'presets':
        PresetSelectorSheet.show(
          context,
          lens: lens,
          currentPreset: _activePreset,
          onSelectPreset: (preset) => setState(() => _activePreset = preset),
        );
      case 'caps':
        CapabilitySheet.show(
          context,
          capabilities: _lensCapabilities,
          activeCameraId: lens.cameraId,
          onSelectCamera: (cameraId) {
            final index = _availableCameras.indexWhere(
              (camera) => camera.name == cameraId,
            );
            if (index >= 0) _switchCamera(index);
          },
        );
      case 'peaking':
        setState(() => _focusPeaking = !_focusPeaking);
      case 'zebra':
        setState(() => _zebraStripes = !_zebraStripes);
      case 'false_color':
        setState(() => _falseColor = !_falseColor);
      case 'lut':
        _cycleMonitoringLut();
    }
  }

  Widget _buildCaptureDock(LensCapability lens, BoxConstraints constraints) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF20B1012),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.14))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showManualDrawer)
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.36,
              ),
              child: ManualControlsDrawer(
                lens: lens,
                settings: _manualSettings,
                onSettingsChanged: _onManualSettingsChanged,
              ),
            ),
          const SizedBox(height: 12),
          _buildZoomSelector(),
          const SizedBox(height: 8),
          _buildModeSelector(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _buildGalleryThumbnail(),
                  ),
                ),
                _buildShutterButton(),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _roundControl(
                      icon: Icons.cameraswitch_rounded,
                      tooltip: 'Switch camera',
                      onTap: _availableCameras.length > 1 && !_isRecording
                          ? () => _switchCamera(
                              (_selectedCameraIndex + 1) %
                                  _availableCameras.length,
                            )
                          : () {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildZoomSelector() {
    final stops =
        <double>[
              if (_minimumZoom < 0.95) 0.5,
              1,
              2,
              3,
              5,
              if (_maximumZoom > 1 && _maximumZoom < 2) _maximumZoom,
            ]
            .where((zoom) => zoom >= _minimumZoom && zoom <= _maximumZoom)
            .toSet()
            .toList()
          ..sort();
    if (stops.isEmpty) stops.add(_minimumZoom);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.38),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: stops.map((zoom) {
          final selected = (_manualSettings.zoomRatio - zoom).abs() < 0.08;
          final label =
              (zoom == zoom.roundToDouble()
                  ? zoom.toStringAsFixed(0)
                  : zoom.toStringAsFixed(1)) +
              'x';
          return GestureDetector(
            onTap: _isRecording ? null : () => _applyZoom(zoom),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: const BoxConstraints(minWidth: 44, minHeight: 38),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFFD75E).withOpacity(0.18)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? const Color(0xFFFFD75E) : Colors.white,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildModeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _modeButton('VIDEO', _isVideoMode, () {
          if (!_isRecording) setState(() => _isVideoMode = true);
        }),
        const SizedBox(width: 30),
        _modeButton('PHOTO', !_isVideoMode, () {
          if (!_isRecording) setState(() => _isVideoMode = false);
        }),
      ],
    );
  }

  Widget _modeButton(String title, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: selected ? const Color(0xFFFFD75E) : Colors.white70,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: selected ? 6 : 0,
            height: 6,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD75E),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShutterButton() {
    return Semantics(
      button: true,
      label: _isVideoMode
          ? (_isRecording ? 'Stop recording' : 'Start recording')
          : 'Take photo',
      child: GestureDetector(
        onTap: _onShutterPressed,
        child: Container(
          width: 84,
          height: 84,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 14),
            ],
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: _isRecording ? const EdgeInsets.all(16) : EdgeInsets.zero,
            decoration: BoxDecoration(
              shape: _isRecording ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: _isRecording ? BorderRadius.circular(10) : null,
              color: _isVideoMode ? const Color(0xFFFF453A) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGalleryThumbnail() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GalleryScreen()),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 58,
          height: 58,
          color: const Color(0xFF273033),
          child:
              _latestMediaPath != null && File(_latestMediaPath!).existsSync()
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    if (!_latestMediaIsVideo)
                      Image.file(File(_latestMediaPath!), fit: BoxFit.cover)
                    else
                      const Center(
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    if (_latestMediaIsVideo)
                      const Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.videocam_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                  ],
                )
              : const Icon(
                  Icons.photo_library_outlined,
                  color: Colors.white,
                  size: 24,
                ),
        ),
      ),
    );
  }

  void _cycleFramingGrid() {
    setState(() {
      switch (_framingGrid) {
        case GridMode.none:
          _framingGrid = GridMode.thirds;
        case GridMode.thirds:
          _framingGrid = GridMode.crosshair;
        case GridMode.crosshair:
          _framingGrid = GridMode.goldenRatio;
        case GridMode.goldenRatio:
          _framingGrid = GridMode.anamorphic239;
        case GridMode.anamorphic239:
          _framingGrid = GridMode.safeArea;
        case GridMode.safeArea:
          _framingGrid = GridMode.none;
      }
    });
  }

  void _cycleMonitoringLut() {
    const luts = [
      'none',
      'rec709',
      'flat',
      'film_warm',
      'clean_cool',
      'monochrome',
    ];
    final nextIndex = (luts.indexOf(_activeLut) + 1) % luts.length;
    setState(() => _activeLut = luts[nextIndex]);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1100),
        content: Text('Preview look: ' + LutHelper.getDisplayName(_activeLut)),
      ),
    );
  }
}
