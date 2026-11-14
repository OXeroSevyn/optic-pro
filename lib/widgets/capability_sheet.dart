import 'package:flutter/material.dart';
import '../models/lens_capability.dart';

class CapabilitySheet extends StatefulWidget {
  final List<LensCapability> capabilities;
  final String activeCameraId;
  final ValueChanged<String>? onSelectCamera;

  const CapabilitySheet({
    super.key,
    required this.capabilities,
    required this.activeCameraId,
    this.onSelectCamera,
  });

  static Future<void> show(
    BuildContext context, {
    required List<LensCapability> capabilities,
    required String activeCameraId,
    ValueChanged<String>? onSelectCamera,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => CapabilitySheet(
        capabilities: capabilities,
        activeCameraId: activeCameraId,
        onSelectCamera: onSelectCamera,
      ),
    );
  }

  @override
  State<CapabilitySheet> createState() => _CapabilitySheetState();
}

class _CapabilitySheetState extends State<CapabilitySheet> {
  late String _selectedCameraId;

  @override
  void initState() {
    super.initState();
    _selectedCameraId = widget.activeCameraId;
  }

  LensCapability get _activeLens {
    return widget.capabilities.firstWhere(
      (c) => c.cameraId == _selectedCameraId,
      orElse: () => widget.capabilities.isNotEmpty
          ? widget.capabilities.first
          : LensCapability.fallback(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lens = _activeLens;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined, color: Colors.amberAccent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Hardware Capability Report',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Lens Switcher Tabs
            if (widget.capabilities.length > 1)
              Container(
                height: 38,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: widget.capabilities.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final cap = widget.capabilities[index];
                    final isSelected = cap.cameraId == _selectedCameraId;
                    return ChoiceChip(
                      label: Text(cap.lensTypeDisplayName),
                      selected: isSelected,
                      selectedColor: Colors.amberAccent.withOpacity(0.2),
                      backgroundColor: Colors.white10,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Colors.amberAccent : Colors.white70,
                      ),
                      side: BorderSide(
                        color: isSelected ? Colors.amberAccent : Colors.transparent,
                        width: 1,
                      ),
                      onSelected: (val) {
                        if (val) {
                          setState(() => _selectedCameraId = cap.cameraId);
                          widget.onSelectCamera?.call(cap.cameraId);
                        }
                      },
                    );
                  },
                ),
              ),

            const Divider(color: Colors.white12, height: 1),

            // Capability Cards List
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHardwareOverview(lens),
                  const SizedBox(height: 16),
                  _buildStillRawSection(lens),
                  const SizedBox(height: 16),
                  _buildVideoSection(lens),
                  const SizedBox(height: 16),
                  _buildManualControlsSection(lens),
                  const SizedBox(height: 16),
                  _buildLogAndColorSection(lens),
                  const SizedBox(height: 16),
                  _buildPracticalLimitsSection(lens),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHardwareOverview(LensCapability lens) {
    Color badgeColor = Colors.green;
    String badgeDesc = 'Full Camera2 manual exposure & sensor access';
    if (lens.hardwareLevel == 'LIMITED') {
      badgeColor = Colors.orangeAccent;
      badgeDesc = 'Limited Camera2 level: some manual features may be restricted by manufacturer HAL';
    } else if (lens.hardwareLevel == 'LEGACY') {
      badgeColor = Colors.redAccent;
      badgeDesc = 'Legacy camera driver emulation: manual controls unavailable';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF20232A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Camera ID: ${lens.cameraId} (${lens.facing})',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: badgeColor, width: 0.8),
                ),
                child: Text(
                  'HAL: ${lens.hardwareLevel}',
                  style: TextStyle(color: badgeColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            badgeDesc,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (lens.focalLengths.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Focal Length: ${lens.focalLengths.map((f) => "${f.toStringAsFixed(1)}mm").join(", ")} | '
              'Aperture: ${lens.apertures.map((a) => "f/${a.toStringAsFixed(1)}").join(", ")}',
              style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStillRawSection(LensCapability lens) {
    return _buildSectionContainer(
      title: 'Still Photo & RAW Support',
      icon: Icons.camera_alt_outlined,
      children: [
        _buildStatusRow(
          'DNG / RAW Still Capture',
          lens.supportsRawStill,
          lens.supportsRawStill
              ? 'Available (${lens.rawFormats.join(", ")})'
              : 'Unavailable: Sensor RAW output not exposed by camera HAL',
        ),
        if (lens.rawFormats.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            'Supported RAW Bayer formats: ${lens.rawFormats.join(" • ")}',
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
        ],
      ],
    );
  }

  Widget _buildVideoSection(LensCapability lens) {
    return _buildSectionContainer(
      title: 'Video Stream & Resolutions',
      icon: Icons.videocam_outlined,
      children: [
        _buildStatusRow(
          'Optical Image Stabilization (OIS)',
          lens.hasOis,
          lens.hasOis ? 'Hardware optical floating element active' : 'No hardware OIS gyro on this lens module',
        ),
        _buildStatusRow(
          'Electronic Video Stabilization (EIS)',
          lens.hasEis,
          lens.hasEis ? 'Software electronic frame stabilization available' : 'EIS not supported by driver',
        ),
        const SizedBox(height: 8),
        const Text(
          'Verified Recording Resolutions & Max Stream Rates:',
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        ...lens.videoResolutions.map((res) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                const Icon(Icons.check_circle, size: 12, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Text(
                  res.label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const Spacer(),
                Text(
                  'up to ${res.maxFps} fps',
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontFamily: 'monospace'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildManualControlsSection(LensCapability lens) {
    return _buildSectionContainer(
      title: 'Manual Sensor Controls',
      icon: Icons.tune,
      children: [
        _buildStatusRow(
          'Manual ISO Sensitivity',
          lens.hasManualSensor,
          lens.hasManualSensor
              ? 'ISO ${lens.isoMin} – ${lens.isoMax}'
              : 'Auto only (HAL lacks MANUAL_SENSOR capability)',
        ),
        _buildStatusRow(
          'Manual Shutter Speed',
          lens.hasManualSensor,
          lens.hasManualSensor
              ? '${lens.formatShutterSpeed(lens.minShutterSeconds)} – ${lens.formatShutterSpeed(lens.maxShutterSeconds)}'
              : 'Auto exposure only',
        ),
        _buildStatusRow(
          'Manual Focus Distance',
          lens.canManualFocus,
          lens.canManualFocus
              ? 'Supported (Min focus distance: ${lens.minFocusDistance.toStringAsFixed(1)} diopters)'
              : 'Fixed-focus lens module',
        ),
        _buildStatusRow(
          'Exposure Compensation (EV)',
          true,
          'EV ${(lens.expMin * lens.expStep).toStringAsFixed(1)} to +${(lens.expMax * lens.expStep).toStringAsFixed(1)} in ${lens.expStep} EV increments',
        ),
      ],
    );
  }

  Widget _buildLogAndColorSection(LensCapability lens) {
    return _buildSectionContainer(
      title: 'Log, Bit Depth & RAW Video',
      icon: Icons.color_lens_outlined,
      children: [
        // RAW Video Truth Card
        _buildStatusRow(
          'Continuous RAW Video Stream',
          lens.supportsRawVideo,
          lens.rawVideoExplanation,
          caution: true,
        ),
        const SizedBox(height: 8),
        // 10-bit HDR / Log profile Truth Card
        _buildStatusRow(
          '10-bit HDR / Hardware Log Profiles',
          lens.supportsLogProfile,
          lens.logExplanation,
          caution: !lens.supportsLogProfile,
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 14, color: Colors.lightBlueAccent),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Optic Pro provides real-time non-destructive Rec.709 & Film monitoring LUTs on the preview feed without burning into the original recorded video file.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPracticalLimitsSection(LensCapability lens) {
    return _buildSectionContainer(
      title: 'Practical Limits & Advisory',
      icon: Icons.warning_amber_rounded,
      children: [
        _buildBulletPoint('4K 60fps requires significant write bandwidth (~60-100 Mbps) and may cause thermal throttling after prolonged recording.'),
        _buildBulletPoint('Simultaneous high frame rate and software electronic stabilization may crop the sensor field of view slightly.'),
        _buildBulletPoint('When battery is under 15% or device temperature exceeds 42°C, high bitrates may result in dropped frames.'),
      ],
    );
  }

  Widget _buildSectionContainer({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2127),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.amberAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatusRow(String title, bool isSupported, String detail, {bool caution = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isSupported ? Icons.check_circle : (caution ? Icons.warning_amber : Icons.cancel),
            size: 14,
            color: isSupported
                ? Colors.greenAccent
                : (caution ? Colors.amberAccent : Colors.white38),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isSupported ? Colors.white : Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  detail,
                  style: TextStyle(
                    color: caution ? Colors.amberAccent.shade100 : Colors.white60,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.amberAccent, fontSize: 13)),
          Expanded(
            child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}
