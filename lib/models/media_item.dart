class MediaItem {
  final String id;
  final String filePath;
  final String fileName;
  final DateTime recordedAt;
  final int durationSeconds;
  final int fileSizeBytes;
  final int width;
  final int height;
  final bool isVideo;
  final bool isRaw;
  final String lensId;
  final int? iso;
  final double? shutterSeconds;
  final String? lutName;

  const MediaItem({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.recordedAt,
    required this.durationSeconds,
    required this.fileSizeBytes,
    required this.width,
    required this.height,
    required this.isVideo,
    required this.isRaw,
    required this.lensId,
    this.iso,
    this.shutterSeconds,
    this.lutName,
  });

  String get formattedSize {
    if (fileSizeBytes >= 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (fileSizeBytes >= 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
  }

  String get formattedDuration {
    if (!isVideo) return 'PHOTO';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get formattedDate {
    return '${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')} '
        '${recordedAt.hour.toString().padLeft(2, '0')}:${recordedAt.minute.toString().padLeft(2, '0')}';
  }

  String get resolutionLabel {
    if (width >= 3840 && height >= 2160) return '4K UHD';
    if (width >= 1920 && height >= 1080) return '1080p FHD';
    if (width >= 1280 && height >= 720) return '720p HD';
    return '${width}×$height';
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'filePath': filePath,
    'fileName': fileName,
    'recordedAt': recordedAt.toIso8601String(),
    'durationSeconds': durationSeconds,
    'fileSizeBytes': fileSizeBytes,
    'width': width,
    'height': height,
    'isVideo': isVideo,
    'isRaw': isRaw,
    'lensId': lensId,
    'iso': iso,
    'shutterSeconds': shutterSeconds,
    'lutName': lutName,
  };

  factory MediaItem.fromMap(Map<String, dynamic> map) {
    return MediaItem(
      id: map['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      filePath: map['filePath'] as String? ?? '',
      fileName: map['fileName'] as String? ?? 'clip.mp4',
      recordedAt: DateTime.tryParse(map['recordedAt'] as String? ?? '') ?? DateTime.now(),
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (map['fileSizeBytes'] as num?)?.toInt() ?? 0,
      width: (map['width'] as num?)?.toInt() ?? 1920,
      height: (map['height'] as num?)?.toInt() ?? 1080,
      isVideo: map['isVideo'] == true,
      isRaw: map['isRaw'] == true,
      lensId: map['lensId'] as String? ?? '0',
      iso: (map['iso'] as num?)?.toInt(),
      shutterSeconds: (map['shutterSeconds'] as num?)?.toDouble(),
      lutName: map['lutName'] as String?,
    );
  }
}
