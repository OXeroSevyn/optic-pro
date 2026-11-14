import 'package:flutter/material.dart';

import '../models/system_telemetry.dart';

class TelemetryBar extends StatelessWidget {
  final SystemTelemetry telemetry;
  final bool isRecording;
  final int recordingElapsedSeconds;
  final double currentBitrateMbps;
  final VoidCallback? onStorageTap;
  final VoidCallback? onThermalTap;

  const TelemetryBar({
    super.key,
    required this.telemetry,
    required this.isRecording,
    required this.recordingElapsedSeconds,
    this.currentBitrateMbps = 35.0,
    this.onStorageTap,
    this.onThermalTap,
  });

  String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final remainingTime = telemetry.formattedRemainingTime(currentBitrateMbps);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xE6181A20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.12), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recording Status Pill (Material 3 Expressive)
          if (isRecording) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF453A),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF453A).withOpacity(0.4),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'REC ${_formatElapsed(recordingElapsedSeconds)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(width: 1, height: 14, color: Colors.white12),
            const SizedBox(width: 10),
          ],

          // Storage Info
          InkWell(
            onTap: onStorageTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.sd_storage_outlined,
                    size: 14,
                    color: telemetry.isStorageCritical
                        ? const Color(0xFFFF453A)
                        : (telemetry.isStorageLow
                              ? const Color(0xFFFFB74D)
                              : const Color(0xFF74E0D0)),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${telemetry.formattedFreeStorage} ($remainingTime)',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: telemetry.isStorageCritical
                          ? const Color(0xFFFF453A)
                          : (telemetry.isStorageLow
                                ? const Color(0xFFFFB74D)
                                : Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),
          Container(width: 1, height: 14, color: Colors.white12),
          const SizedBox(width: 10),

          // Thermal Status
          InkWell(
            onTap: onThermalTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                children: [
                  Icon(
                    Icons.thermostat_outlined,
                    size: 14,
                    color: telemetry.isThermalSevere
                        ? const Color(0xFFFF453A)
                        : (telemetry.isThermalModerate
                              ? const Color(0xFFFFB74D)
                              : Colors.white70),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '${telemetry.batteryTempC.toStringAsFixed(0)}°C',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: telemetry.isThermalSevere
                          ? const Color(0xFFFF453A)
                          : (telemetry.isThermalModerate
                                ? const Color(0xFFFFB74D)
                                : Colors.white),
                    ),
                  ),
                  if (telemetry.isThermalSevere) ...[
                    const SizedBox(width: 3),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF453A),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),
          Container(width: 1, height: 14, color: Colors.white12),
          const SizedBox(width: 10),

          // Battery Status
          Row(
            children: [
              Icon(
                telemetry.isCharging
                    ? Icons.battery_charging_full_rounded
                    : (telemetry.batteryPct < 20
                          ? Icons.battery_alert_rounded
                          : Icons.battery_full_rounded),
                size: 15,
                color: telemetry.batteryPct < 20
                    ? const Color(0xFFFF453A)
                    : (telemetry.isCharging
                          ? const Color(0xFF74E0D0)
                          : Colors.white70),
              ),
              const SizedBox(width: 3),
              Text(
                '${telemetry.batteryPct}%',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: telemetry.batteryPct < 20
                      ? const Color(0xFFFF453A)
                      : Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
