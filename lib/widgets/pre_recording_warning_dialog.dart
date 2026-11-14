import 'package:flutter/material.dart';
import '../models/system_telemetry.dart';
import '../models/lens_capability.dart';

class PreRecordingWarningDialog extends StatelessWidget {
  final VideoResolution resolution;
  final int fps;
  final SystemTelemetry telemetry;

  const PreRecordingWarningDialog({
    super.key,
    required this.resolution,
    required this.fps,
    required this.telemetry,
  });

  static bool shouldWarn({
    required VideoResolution resolution,
    required int fps,
    required SystemTelemetry telemetry,
  }) {
    final isHighDataRate = (resolution.width >= 3840) || (fps >= 60);
    final isStorageTight = telemetry.isStorageLow;
    final isThermalStressed = telemetry.isThermalModerate || telemetry.isThermalSevere;
    final isBatteryLow = telemetry.batteryPct < 20;

    return isHighDataRate || isStorageTight || isThermalStressed || isBatteryLow;
  }

  static Future<bool> checkAndShow(
    BuildContext context, {
    required VideoResolution resolution,
    required int fps,
    required SystemTelemetry telemetry,
  }) async {
    if (!shouldWarn(resolution: resolution, fps: fps, telemetry: telemetry)) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => PreRecordingWarningDialog(
        resolution: resolution,
        fps: fps,
        telemetry: telemetry,
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final is4K = resolution.width >= 3840;
    final isHighFps = fps >= 60;
    final mbPerMinute = is4K ? (isHighFps ? 600 : 380) : (isHighFps ? 250 : 150);

    return AlertDialog(
      backgroundColor: const Color(0xFF1B1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.amberAccent, width: 1.0),
      ),
      title: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 24),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'High Resource Advisory',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recording in ${resolution.shortLabel} @ ${fps}fps requires sustained hardware throughput:',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _buildWarningItem(
            Icons.sd_storage_outlined,
            'High Storage Consumption',
            '~${mbPerMinute} MB per minute. Remaining runway: ${telemetry.formattedRemainingTime(mbPerMinute * 8.0 / 60.0)}.',
            telemetry.isStorageLow ? Colors.redAccent : Colors.amberAccent,
          ),
          if (telemetry.isThermalModerate || telemetry.isThermalSevere)
            _buildWarningItem(
              Icons.thermostat,
              'Thermal Throttling Risk',
              'Device is currently at ${telemetry.batteryTempC.toStringAsFixed(1)}°C (${telemetry.thermalStatus}). Long takes may drop frames.',
              Colors.redAccent,
            ),
          if (telemetry.batteryPct < 20)
            _buildWarningItem(
              Icons.battery_alert,
              'Low Battery Alert',
              'Battery at ${telemetry.batteryPct}%. Plug into power or power bank to avoid sudden recording cuts.',
              Colors.redAccent,
            ),
          const SizedBox(height: 8),
          const Text(
            'Original footage will be safely written to disk. For cooler operation, 1080p 30fps is recommended.',
            style: TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('ADJUST FORMAT', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amberAccent,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('PROCEED', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildWarningItem(IconData icon, String title, String subtitle, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
