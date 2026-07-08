import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/settings_service.dart';
import '../../theme.dart';

class VideoThumbnailWidget extends StatefulWidget {
  final String mediaUrl;
  final ChatService chatService;
  final bool showPlayIcon;

  const VideoThumbnailWidget({
    super.key, 
    required this.mediaUrl, 
    required this.chatService,
    this.showPlayIcon = true,
  });

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  Uint8List? _thumbnailData;
  bool _loading = false;
  bool _needsDownload = false;

  @override
  void initState() {
    super.initState();
    _checkAutoDownload();
  }

  void _checkAutoDownload() {
    if (widget.mediaUrl.startsWith('http') || widget.mediaUrl.startsWith('/')) {
      _generateThumbnail();
      return;
    }

    final settings = Provider.of<SettingsService>(context, listen: false);
    final autoVideo = settings.getSetting('media_auto_video', defaultValue: 'Off');
    
    if (autoVideo == 'Off') {
      setState(() => _needsDownload = true);
    } else {
      _generateThumbnail();
    }
  }

  Future<void> _generateThumbnail() async {
    setState(() {
      _loading = true;
      _needsDownload = false;
    });
    try {
      final signedUrl = await widget.chatService.getMediaSignedUrl(widget.mediaUrl);
      if (signedUrl != null) {
        final uint8list = await VideoThumbnail.thumbnailData(
          video: signedUrl,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 250,
          quality: 25,
        );
        if (mounted) {
          setState(() {
            _thumbnailData = uint8list;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsDownload) {
      return GestureDetector(
        onTap: _generateThumbnail,
        child: Container(
          color: const Color(0xFF2A2A2A),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.download, color: Colors.white70, size: 32),
                SizedBox(height: 8),
                Text('Download', style: TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }
    
    return Stack(
      alignment: Alignment.center,
      fit: StackFit.expand,
      children: [
        if (_thumbnailData != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              _thumbnailData!, 
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: AppColors.lightGrey,
                  child: const Icon(Icons.broken_image, color: AppColors.grey, size: 40),
                );
              },
            ),
          )
        else
          const Icon(Icons.videocam, color: Colors.white24, size: 80),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: Colors.white))
        else if (widget.showPlayIcon)
          const Icon(Icons.play_circle_fill, color: Colors.white70, size: 60),
      ],
    );
  }
}

