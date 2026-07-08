import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:io';
import '../theme.dart';

class VideoViewerScreen extends StatefulWidget {
  final String videoUrl;
  final String senderName;
  final String time;

  const VideoViewerScreen({
    super.key, 
    required this.videoUrl,
    required this.senderName,
    required this.time,
  });

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState extends State<VideoViewerScreen> {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _isError = false;
  final TextEditingController _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      if (widget.videoUrl.startsWith('http')) {
        _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else {
        _videoPlayerController = VideoPlayerController.file(File(widget.videoUrl));
      }
      
      await _videoPlayerController.initialize();
      
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              errorMessage,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      setState(() {
        _isError = true;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.senderName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.star_border, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.forward, color: Colors.white), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'all_media') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All media coming soon')));
              } else if (value == 'show_in_chat') {
                Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all_media', child: Text('All media')),
              const PopupMenuItem(value: 'show_in_chat', child: Text('Show in chat')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _isError
                    ? const Text('Error loading video', style: TextStyle(color: Colors.white))
                    : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                        ? Chewie(controller: _chewieController!)
                        : const CircularProgressIndicator(),
              ),
            ),
            // Bottom Reply Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black.withValues(alpha: 0.8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Reply',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.emoji_emotions_outlined, color: Colors.white70),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (_replyController.text.isNotEmpty) {
                        Navigator.pop(context, _replyController.text);
                      }
                    },
                    child: const CircleAvatar(
                      backgroundColor: AppColors.orange,
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

