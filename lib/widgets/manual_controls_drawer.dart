import 'package:flutter/material.dart';

import '../models/lens_capability.dart';

class ManualSettingsState {
  final bool isAutoExposure;
  final double evBias;
  final bool isAutoIso;
  final int iso;
  final bool isAutoShutter;
  final double shutterSeconds;
  final bool isAutoFocus;
  final double focusDistance; // 0.0 (infinity) to 1.0 (macro)
  final String
  whiteBalanceMode; // "auto", "daylight", "cloudy", "tungsten", "fluorescent"
  final double zoomRatio;

  const ManualSettingsState({
    this.isAutoExposure = true,
    this.evBias = 0.0,
    this.isAutoIso = true,
    this.iso = 200,
    this.isAutoShutter = true,
    this.shutterSeconds = 1.0 / 60.0,
    this.isAutoFocus = true,
    this.focusDistance = 0.5,
    this.whiteBalanceMode = 'auto',
    this.zoomRatio = 1.0,
  });

  ManualSettingsState copyWith({
    bool? isAutoExposure,
    double? evBias,
    bool? isAutoIso,
    int? iso,
    bool? isAutoShutter,
    double? shutterSeconds,
    bool? isAutoFocus,
    double? focusDistance,
    String? whiteBalanceMode,
    double? zoomRatio,
  }) {
    return ManualSettingsState(
      isAutoExposure: isAutoExposure ?? this.isAutoExposure,
      evBias: evBias ?? this.evBias,
      isAutoIso: isAutoIso ?? this.isAutoIso,
      iso: iso ?? this.iso,
      isAutoShutter: isAutoShutter ?? this.isAutoShutter,
      shutterSeconds: shutterSeconds ?? this.shutterSeconds,
      isAutoFocus: isAutoFocus ?? this.isAutoFocus,
      focusDistance: focusDistance ?? this.focusDistance,
      whiteBalanceMode: whiteBalanceMode ?? this.whiteBalanceMode,
      zoomRatio: zoomRatio ?? this.zoomRatio,
    );
  }

  static ManualSettingsState allAuto() {
    return const ManualSettingsState();
  }
}

class ManualControlsDrawer extends StatefulWidget {
  final LensCapability lens;
  final ManualSettingsState settings;
  final ValueChanged<ManualSettingsState> onSettingsChanged;

  const ManualControlsDrawer({
    super.key,
    required this.lens,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<ManualControlsDrawer> createState() => _ManualControlsDrawerState();
}

class _ManualControlsDrawerState extends State<ManualControlsDrawer> {
  String _activeTab = 'EV'; // 'EV', 'ISO', 'SHUTTER', 'FOCUS', 'WB', 'ZOOM'

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF216181D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.12), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top pill handle
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 8),

          // Expressive Tab Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                _buildTabButton(
                  'EV',
                  'EV ${widget.settings.evBias > 0 ? "+" : ""}${widget.settings.evBias.toStringAsFixed(1)}',
                ),
                _buildTabButton(
                  'ISO',
                  widget.settings.isAutoIso
                      ? 'ISO Auto'
                      : 'ISO ${widget.settings.iso}',
                ),
                _buildTabButton(
                  'SHUTTER',
                  widget.settings.isAutoShutter
                      ? 'SEC Auto'
                      : widget.lens.formatShutterSpeed(
                          widget.settings.shutterSeconds,
                        ),
                ),
                _buildTabButton(
                  'FOCUS',
                  widget.settings.isAutoFocus ? 'AF-C' : 'MF',
                ),
                _buildTabButton(
                  'WB',
                  widget.settings.whiteBalanceMode.toUpperCase(),
                ),
                _buildTabButton(
                  'ZOOM',
                  '${widget.settings.zoomRatio.toStringAsFixed(1)}x',
                ),
                const SizedBox(width: 8),
                // One-tap Reset to AUTO button (M3 Expressive pill)
                GestureDetector(
                  onTap: () {
                    widget.onSettingsChanged(ManualSettingsState.allAuto());
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF74E0D0).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFF74E0D0).withOpacity(0.3),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          size: 13,
                          color: Color(0xFF74E0D0),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'RESET AUTO',
                          style: TextStyle(
                            color: Color(0xFF74E0D0),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Active Control Panel
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _buildActiveControlContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String tabKey, String label) {
    final isSelected = _activeTab == tabKey;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = tabKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF74E0D0) : Colors.white10,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF74E0D0).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? const Color(0xFF07201D) : Colors.white70,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  Widget _buildActiveControlContent() {
    switch (_activeTab) {
      case 'EV':
        return _buildEvControl();
      case 'ISO':
        return _buildIsoControl();
      case 'SHUTTER':
        return _buildShutterControl();
      case 'FOCUS':
        return _buildFocusControl();
      case 'WB':
        return _buildWbControl();
      case 'ZOOM':
        return _buildZoomControl();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildEvControl() {
    final evMin = (widget.lens.expMin * widget.lens.expStep).clamp(-4.0, 0.0);
    final evMax = (widget.lens.expMax * widget.lens.expStep).clamp(0.0, 4.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Exposure Compensation',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF74E0D0).withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.settings.evBias > 0 ? "+" : ""}${widget.settings.evBias.toStringAsFixed(1)} EV',
                style: const TextStyle(
                  color: Color(0xFF74E0D0),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFF74E0D0),
            inactiveTrackColor: Colors.white12,
            thumbColor: const Color(0xFF74E0D0),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: widget.settings.evBias.clamp(evMin, evMax),
            min: evMin,
            max: evMax,
            divisions: ((evMax - evMin) / widget.lens.expStep).round(),
            onChanged: (val) {
              widget.onSettingsChanged(widget.settings.copyWith(evBias: val));
            },
          ),
        ),
      ],
    );
  }

  Widget _buildIsoControl() {
    final isoPresets = [100, 200, 400, 800, 1600, 3200, 6400];
    final validPresets = isoPresets
        .where((i) => i >= widget.lens.isoMin && i <= widget.lens.isoMax)
        .toList();
    if (validPresets.isEmpty) validPresets.addAll([100, 200, 400, 800]);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.lens.hasManualSensor
                  ? 'Sensor Gain (ISO ${widget.lens.isoMin} – ${widget.lens.isoMax})'
                  : 'ISO Control',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                widget.onSettingsChanged(
                  widget.settings.copyWith(isAutoIso: true),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.settings.isAutoIso
                      ? const Color(0xFF74E0D0)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'AUTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: widget.settings.isAutoIso
                        ? const Color(0xFF07201D)
                        : Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: validPresets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final val = validPresets[idx];
              final isSel =
                  !widget.settings.isAutoIso && widget.settings.iso == val;
              return GestureDetector(
                onTap: () {
                  widget.onSettingsChanged(
                    widget.settings.copyWith(isAutoIso: false, iso: val),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF74E0D0) : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      '$val',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        color: isSel ? const Color(0xFF07201D) : Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildShutterControl() {
    final speeds = [
      1.0 / 24.0,
      1.0 / 30.0,
      1.0 / 48.0,
      1.0 / 50.0,
      1.0 / 60.0,
      1.0 / 120.0,
      1.0 / 250.0,
      1.0 / 500.0,
      1.0 / 1000.0,
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Shutter Speed / Angle',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                widget.onSettingsChanged(
                  widget.settings.copyWith(isAutoShutter: true),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: widget.settings.isAutoShutter
                      ? const Color(0xFF74E0D0)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'AUTO',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: widget.settings.isAutoShutter
                        ? const Color(0xFF07201D)
                        : Colors.white70,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: speeds.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final spd = speeds[idx];
              final isSel =
                  !widget.settings.isAutoShutter &&
                  (widget.settings.shutterSeconds - spd).abs() < 0.001;
              return GestureDetector(
                onTap: () {
                  widget.onSettingsChanged(
                    widget.settings.copyWith(
                      isAutoShutter: false,
                      shutterSeconds: spd,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF74E0D0) : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      widget.lens.formatShutterSpeed(spd),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        color: isSel ? const Color(0xFF07201D) : Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFocusControl() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Focus Control',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () => widget.onSettingsChanged(
                    widget.settings.copyWith(isAutoFocus: true),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.settings.isAutoFocus
                          ? const Color(0xFF74E0D0)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'AF-C',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: widget.settings.isAutoFocus
                            ? const Color(0xFF07201D)
                            : Colors.white70,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => widget.onSettingsChanged(
                    widget.settings.copyWith(isAutoFocus: false),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: !widget.settings.isAutoFocus
                          ? const Color(0xFF74E0D0)
                          : Colors.white10,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'MANUAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: !widget.settings.isAutoFocus
                            ? const Color(0xFF07201D)
                            : Colors.white70,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        if (!widget.settings.isAutoFocus) ...[
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: const Color(0xFF74E0D0),
              inactiveTrackColor: Colors.white12,
              thumbColor: const Color(0xFF74E0D0),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: widget.settings.focusDistance,
              min: 0.0,
              max: 1.0,
              onChanged: (val) {
                widget.onSettingsChanged(
                  widget.settings.copyWith(focusDistance: val),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWbControl() {
    final modes = [
      {'key': 'auto', 'label': 'Auto AWB', 'icon': Icons.auto_awesome_rounded},
      {
        'key': 'daylight',
        'label': '5600K Daylight',
        'icon': Icons.wb_sunny_rounded,
      },
      {'key': 'cloudy', 'label': '6500K Cloudy', 'icon': Icons.cloud_rounded},
      {
        'key': 'tungsten',
        'label': '3200K Tungsten',
        'icon': Icons.lightbulb_rounded,
      },
      {
        'key': 'fluorescent',
        'label': '4000K Fluorescent',
        'icon': Icons.fluorescent_rounded,
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'White Balance / Color Temperature',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: modes.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, idx) {
              final item = modes[idx];
              final isSel = widget.settings.whiteBalanceMode == item['key'];
              return GestureDetector(
                onTap: () {
                  widget.onSettingsChanged(
                    widget.settings.copyWith(
                      whiteBalanceMode: item['key'] as String,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? const Color(0xFF74E0D0) : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        size: 14,
                        color: isSel ? const Color(0xFF07201D) : Colors.white70,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                          color: isSel ? const Color(0xFF07201D) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildZoomControl() {
    final presets = [0.5, 1.0, 2.0, 3.0, 5.0];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Focal Zoom',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF74E0D0).withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.settings.zoomRatio.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Color(0xFF74E0D0),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ...presets.map((p) {
              final isSel = (widget.settings.zoomRatio - p).abs() < 0.1;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () {
                    widget.onSettingsChanged(
                      widget.settings.copyWith(zoomRatio: p),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFF74E0D0) : Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${p}x',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.w900 : FontWeight.w600,
                        color: isSel ? const Color(0xFF07201D) : Colors.white,
                      ),
                    ),
                  ),
                ),
              );
            }),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: const Color(0xFF74E0D0),
                  inactiveTrackColor: Colors.white12,
                  thumbColor: const Color(0xFF74E0D0),
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  value: widget.settings.zoomRatio.clamp(1.0, 8.0),
                  min: 1.0,
                  max: 8.0,
                  onChanged: (val) {
                    widget.onSettingsChanged(
                      widget.settings.copyWith(zoomRatio: val),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
