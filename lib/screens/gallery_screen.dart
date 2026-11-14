import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/media_item.dart';
import '../services/media_storage_service.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<MediaItem> _mediaItems = [];
  bool _isLoading = true;
  String _activeFilter = 'ALL'; // 'ALL', 'VIDEOS', 'PHOTOS', 'RAW'

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    final items = await MediaStorageService.loadMediaCatalog();
    setState(() {
      _mediaItems = items;
      _isLoading = false;
    });
  }

  List<MediaItem> get _filteredItems {
    if (_activeFilter == 'VIDEOS')
      return _mediaItems.where((m) => m.isVideo).toList();
    if (_activeFilter == 'PHOTOS')
      return _mediaItems.where((m) => !m.isVideo && !m.isRaw).toList();
    if (_activeFilter == 'RAW')
      return _mediaItems.where((m) => m.isRaw).toList();
    return _mediaItems;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredItems;

    return Scaffold(
      backgroundColor: const Color(0xFF0B1012),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1012),
        toolbarHeight: 64,
        elevation: 0,
        title: const Text(
          'Your captures',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadMedia,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: SizedBox(
            height: 52,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All (${_mediaItems.length})'),
                  _buildFilterChip(
                    'VIDEOS',
                    'Videos (${_mediaItems.where((m) => m.isVideo).length})',
                  ),
                  _buildFilterChip(
                    'PHOTOS',
                    'Photos (${_mediaItems.where((m) => !m.isVideo && !m.isRaw).length})',
                  ),
                  _buildFilterChip(
                    'RAW',
                    'RAW (${_mediaItems.where((m) => m.isRaw).length})',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF74E0D0)),
            )
          : filtered.isEmpty
          ? _buildEmptyState()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.92,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _buildMediaTile(item);
              },
            ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _activeFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFF74E0D0).withOpacity(0.18),
        backgroundColor: const Color(0xFF171F21),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF74E0D0) : Colors.white70,
        ),
        side: BorderSide(
          color: isSelected ? const Color(0xFF74E0D0) : Colors.transparent,
        ),
        onSelected: (val) {
          if (val) setState(() => _activeFilter = key);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 54,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          const Text(
            'No media captured yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Recordings and photos will appear here with technical metadata.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMediaTile(MediaItem item) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MediaDetailScreen(item: item)),
        );
        _loadMedia();
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF151D1F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Preview image or video placeholder
            if (!item.isVideo && File(item.filePath).existsSync())
              Image.file(File(item.filePath), fit: BoxFit.cover)
            else
              Container(
                color: const Color(0xFF151D1F),
                child: Center(
                  child: Icon(
                    item.isVideo ? Icons.play_circle_fill : Icons.image,
                    size: 36,
                    color: item.isVideo
                        ? const Color(0xFF74E0D0).withOpacity(0.8)
                        : Colors.white38,
                  ),
                ),
              ),

            // Top Badges (RAW / Resolution)
            Positioned(
              top: 6,
              left: 6,
              child: Row(
                children: [
                  if (item.isRaw)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.purpleAccent.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: const Text(
                        'RAW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (item.isVideo)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        item.width >= 3840 ? '4K' : 'FHD',
                        style: const TextStyle(
                          color: Color(0xFF74E0D0),
                          fontSize: 8.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom info gradient bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.formattedSize,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      item.formattedDuration,
                      style: TextStyle(
                        color: item.isVideo
                            ? const Color(0xFF74E0D0)
                            : Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MediaDetailScreen extends StatefulWidget {
  final MediaItem item;

  const MediaDetailScreen({super.key, required this.item});

  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    if (widget.item.isVideo && File(widget.item.filePath).existsSync()) {
      _videoController = VideoPlayerController.file(File(widget.item.filePath))
        ..initialize().then((_) {
          setState(() {});
        });
      _videoController?.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _videoController?.value.isPlaying ?? false;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1012),
        title: Text(
          item.fileName,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontFamily: 'monospace',
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.white),
            tooltip: 'Share',
            onPressed: () => MediaStorageService.shareMedia(item),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Delete',
            onPressed: _confirmDelete,
          ),
        ],
      ),
      body: Column(
        children: [
          // Media Player / Viewer Viewport
          Expanded(
            child: Center(
              child: item.isVideo
                  ? (_videoController != null &&
                            _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                VideoPlayer(_videoController!),
                                GestureDetector(
                                  onTap: () {
                                    if (_isPlaying) {
                                      _videoController?.pause();
                                    } else {
                                      _videoController?.play();
                                    }
                                  },
                                  child: Container(
                                    color: Colors.transparent,
                                    child: Center(
                                      child: AnimatedOpacity(
                                        opacity: _isPlaying ? 0.0 : 1.0,
                                        duration: const Duration(
                                          milliseconds: 200,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            size: 48,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const CircularProgressIndicator(
                            color: Color(0xFF74E0D0),
                          ))
                  : (File(item.filePath).existsSync()
                        ? InteractiveViewer(
                            child: Image.file(
                              File(item.filePath),
                              fit: BoxFit.contain,
                            ),
                          )
                        : const Text(
                            'File not found on device',
                            style: TextStyle(color: Colors.white54),
                          )),
            ),
          ),

          // Technical Metadata Sheet
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF11191B),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Color(0xFF74E0D0),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Technical Camera Metadata',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.resolutionLabel,
                      style: const TextStyle(
                        color: Color(0xFF74E0D0),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMetadataRow('Recorded Date', item.formattedDate),
                _buildMetadataRow(
                  'Resolution',
                  '${item.width} × ${item.height} pixels',
                ),
                _buildMetadataRow('File Size', item.formattedSize),
                _buildMetadataRow('Camera Lens', 'Lens ${item.lensId}'),
                if (item.iso != null)
                  _buildMetadataRow('ISO Gain', 'ISO ${item.iso}'),
                if (item.shutterSeconds != null)
                  _buildMetadataRow(
                    'Shutter Speed',
                    '1/${(1.0 / item.shutterSeconds!).round()} s',
                  ),
                if (item.lutName != null)
                  _buildMetadataRow(
                    'Monitoring LUT',
                    '${item.lutName} (Non-destructive preview)',
                  ),
                _buildMetadataRow(
                  'Storage Path',
                  item.filePath,
                  monospace: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(
    String label,
    String value, {
    bool monospace = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontFamily: monospace ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2127),
        title: const Text(
          'Delete Capture?',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          'Permanently delete ${widget.item.fileName} from device storage?',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await MediaStorageService.deleteMedia(widget.item);
      if (mounted) Navigator.pop(context);
    }
  }
}
