import 'package:flutter/material.dart';
import '../models/capture_preset.dart';
import '../models/lens_capability.dart';

class PresetSelectorSheet extends StatelessWidget {
  final LensCapability lens;
  final CapturePreset? currentPreset;
  final ValueChanged<CapturePreset> onSelectPreset;

  const PresetSelectorSheet({
    super.key,
    required this.lens,
    required this.currentPreset,
    required this.onSelectPreset,
  });

  static Future<void> show(
    BuildContext context, {
    required LensCapability lens,
    required CapturePreset? currentPreset,
    required ValueChanged<CapturePreset> onSelectPreset,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF16181C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => PresetSelectorSheet(
        lens: lens,
        currentPreset: currentPreset,
        onSelectPreset: onSelectPreset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allPresets = CapturePreset.getAllPresets().map((p) => p.adaptToLens(lens)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.movie_filter_outlined, color: Colors.amberAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Creator Capture Presets',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Presets automatically adapt targets to this lens (${lens.lensTypeDisplayName}) without promising unsupported rates.',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 14),
          ...allPresets.map((preset) {
            final isSelected = currentPreset?.type == preset.type;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? Colors.amberAccent.withOpacity(0.12) : const Color(0xFF20232A),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.amberAccent : Colors.white12,
                  width: isSelected ? 1.2 : 0.8,
                ),
              ),
              child: ListTile(
                title: Row(
                  children: [
                    Text(
                      preset.title,
                      style: TextStyle(
                        color: isSelected ? Colors.amberAccent : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white10,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${preset.targetWidth >= 3840 ? "4K" : "1080p"} • ${preset.targetFps}fps',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      preset.description,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    if (preset.notes.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        preset.notes,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: isSelected
                    ? const Icon(Icons.check_circle, color: Colors.amberAccent, size: 20)
                    : null,
                onTap: () {
                  onSelectPreset(preset);
                  Navigator.pop(context);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
