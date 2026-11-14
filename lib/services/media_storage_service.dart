import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/media_item.dart';

class MediaStorageService {
  static const String _folderName = 'opticpro_media';
  static const String _catalogFileName = 'catalog.json';

  static Directory? _mediaDir;

  static Future<Directory> getMediaDirectory() async {
    if (_mediaDir != null && await _mediaDir!.exists()) {
      return _mediaDir!;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/$_folderName');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    _mediaDir = mediaDir;
    return mediaDir;
  }

  static Future<List<MediaItem>> loadMediaCatalog() async {
    try {
      final dir = await getMediaDirectory();
      final catalogFile = File('${dir.path}/$_catalogFileName');
      if (await catalogFile.exists()) {
        final content = await catalogFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;
        final items = <MediaItem>[];
        for (final item in jsonList) {
          final mi = MediaItem.fromMap(item as Map<String, dynamic>);
          // Verify file still exists on disk
          if (File(mi.filePath).existsSync()) {
            items.add(mi);
          }
        }
        // Sort newest first
        items.sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
        return items;
      }
    } catch (_) {
      // Return empty list on failure
    }
    return [];
  }

  static Future<void> _saveCatalog(List<MediaItem> items) async {
    try {
      final dir = await getMediaDirectory();
      final catalogFile = File('${dir.path}/$_catalogFileName');
      final jsonList = items.map((e) => e.toMap()).toList();
      await catalogFile.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Ignore
    }
  }

  static Future<MediaItem> saveCapturedMedia({
    required String sourcePath,
    required bool isVideo,
    required bool isRaw,
    required int width,
    required int height,
    required int durationSeconds,
    required String lensId,
    int? iso,
    double? shutterSeconds,
    String? lutName,
  }) async {
    final dir = await getMediaDirectory();
    final now = DateTime.now();
    final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';

    final ext = isVideo ? 'mp4' : (isRaw ? 'dng' : 'jpg');
    final prefix = isVideo ? 'VID' : (isRaw ? 'RAW' : 'IMG');
    final newFileName = '${prefix}_${timestamp}.$ext';
    final destinationPath = '${dir.path}/$newFileName';

    final sourceFile = File(sourcePath);
    if (await sourceFile.exists()) {
      await sourceFile.copy(destinationPath);
    } else {
      // If mock or direct write
      await File(destinationPath).writeAsBytes(await sourceFile.readAsBytes().catchError((_) => <int>[]));
    }

    final savedFile = File(destinationPath);
    final sizeBytes = await savedFile.exists() ? await savedFile.length() : 0;

    final mediaItem = MediaItem(
      id: 'media_${now.millisecondsSinceEpoch}',
      filePath: destinationPath,
      fileName: newFileName,
      recordedAt: now,
      durationSeconds: durationSeconds,
      fileSizeBytes: sizeBytes,
      width: width,
      height: height,
      isVideo: isVideo,
      isRaw: isRaw,
      lensId: lensId,
      iso: iso,
      shutterSeconds: shutterSeconds,
      lutName: lutName,
    );

    final existing = await loadMediaCatalog();
    existing.insert(0, mediaItem);
    await _saveCatalog(existing);

    return mediaItem;
  }

  static Future<bool> deleteMedia(MediaItem item) async {
    try {
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      final items = await loadMediaCatalog();
      items.removeWhere((e) => e.id == item.id);
      await _saveCatalog(items);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> shareMedia(MediaItem item) async {
    final file = File(item.filePath);
    if (await file.exists()) {
      await Share.shareXFiles(
        [XFile(item.filePath, name: item.fileName)],
        text: 'Optic Pro capture: ${item.fileName}',
      );
    }
  }
}
