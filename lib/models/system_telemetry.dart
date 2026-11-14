class AudioInputDevice {
  final int id;
  final String name;
  final String typeName;
  final bool isExternal;

  const AudioInputDevice({
    required this.id,
    required this.name,
    required this.typeName,
    required this.isExternal,
  });

  factory AudioInputDevice.fromMap(Map<dynamic, dynamic> map) {
    return AudioInputDevice(
      id: (map['id'] as num?)?.toInt() ?? 0,
      name: (map['name'] ?? 'Microphone').toString(),
      typeName: (map['typeName'] ?? 'Built-in Mic').toString(),
      isExternal: map['isExternal'] == true,
    );
  }
}

class SystemTelemetry {
  final int freeStorageBytes;
  final int totalStorageBytes;
  final int batteryPct;
  final bool isCharging;
  final double batteryTempC;
  final String thermalStatus;
  final int thermalInt;
  final List<AudioInputDevice> audioDevices;

  const SystemTelemetry({
    required this.freeStorageBytes,
    required this.totalStorageBytes,
    required this.batteryPct,
    required this.isCharging,
    required this.batteryTempC,
    required this.thermalStatus,
    required this.thermalInt,
    required this.audioDevices,
  });

  double get freeStorageGB => freeStorageBytes / (1024 * 1024 * 1024);
  double get totalStorageGB => totalStorageBytes / (1024 * 1024 * 1024);

  String get formattedFreeStorage {
    if (freeStorageGB >= 1.0) {
      return '${freeStorageGB.toStringAsFixed(1)} GB free';
    } else {
      final mb = freeStorageBytes / (1024 * 1024);
      return '${mb.toStringAsFixed(0)} MB free';
    }
  }

  /// Calculates estimated remaining recording time in minutes given bitrate in Mbps
  double calculateRemainingRecordMinutes(double bitrateMbps) {
    if (bitrateMbps <= 0) return 0;
    // Megabytes per minute = (bitrateMbps * 60) / 8
    final mbPerMinute = (bitrateMbps * 60.0) / 8.0;
    final freeMB = freeStorageBytes / (1024.0 * 1024.0);
    // Reserve 500 MB safe threshold
    final usableMB = (freeMB - 500.0).clamp(0.0, double.infinity);
    return usableMB / mbPerMinute;
  }

  String formattedRemainingTime(double bitrateMbps) {
    final mins = calculateRemainingRecordMinutes(bitrateMbps);
    if (mins <= 0) return 'Storage full';
    final hours = (mins / 60).floor();
    final remainingMins = (mins % 60).round();
    if (hours > 0) {
      return '${hours}h ${remainingMins}m';
    }
    return '${remainingMins}m remaining';
  }

  bool get isStorageCritical => freeStorageBytes < 500 * 1024 * 1024; // < 500MB
  bool get isStorageLow => freeStorageBytes < 2 * 1024 * 1024 * 1024; // < 2GB

  bool get isThermalSevere =>
      thermalStatus == 'SEVERE' ||
      thermalStatus == 'CRITICAL' ||
      thermalStatus == 'EMERGENCY' ||
      batteryTempC >= 45.0;

  bool get isThermalModerate =>
      thermalStatus == 'MODERATE' || batteryTempC >= 40.0;

  String? get thermalWarning {
    if (thermalStatus == 'CRITICAL' || thermalStatus == 'EMERGENCY') {
      return 'Critical thermal level! Device may stop recording to prevent shutdown.';
    }
    if (thermalStatus == 'SEVERE' || batteryTempC >= 45.0) {
      return 'Device is running hot (${batteryTempC.toStringAsFixed(1)}°C). Frame drops or thermal throttling possible.';
    }
    if (thermalStatus == 'MODERATE' || batteryTempC >= 40.0) {
      return 'Warm device temperature (${batteryTempC.toStringAsFixed(1)}°C). High frame rate may increase heat.';
    }
    return null;
  }

  factory SystemTelemetry.fromMap(Map<dynamic, dynamic> map) {
    final devList = (map['audioDevices'] as List<dynamic>?)
            ?.map((e) => AudioInputDevice.fromMap(e as Map<dynamic, dynamic>))
            .toList() ??
        [];

    return SystemTelemetry(
      freeStorageBytes: (map['freeStorageBytes'] as num?)?.toInt() ?? (16 * 1024 * 1024 * 1024),
      totalStorageBytes: (map['totalStorageBytes'] as num?)?.toInt() ?? (64 * 1024 * 1024 * 1024),
      batteryPct: (map['batteryPct'] as num?)?.toInt() ?? 85,
      isCharging: map['isCharging'] == true,
      batteryTempC: (map['batteryTempC'] as num?)?.toDouble() ?? 32.5,
      thermalStatus: (map['thermalStatus'] ?? 'NORMAL').toString(),
      thermalInt: (map['thermalInt'] as num?)?.toInt() ?? 0,
      audioDevices: devList,
    );
  }

  factory SystemTelemetry.fallback() {
    return const SystemTelemetry(
      freeStorageBytes: 32 * 1024 * 1024 * 1024,
      totalStorageBytes: 128 * 1024 * 1024 * 1024,
      batteryPct: 90,
      isCharging: false,
      batteryTempC: 32.0,
      thermalStatus: 'NORMAL',
      thermalInt: 0,
      audioDevices: [
        AudioInputDevice(
          id: 1,
          name: 'Built-in Microphone',
          typeName: 'Built-in Mic',
          isExternal: false,
        )
      ],
    );
  }
}
