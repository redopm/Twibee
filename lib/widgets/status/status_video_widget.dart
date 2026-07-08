import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

class StatusVideoWidget extends StatefulWidget {
  final String videoUrl;
  
  const StatusVideoWidget({super.key, required this.videoUrl});

  @override
  State<StatusVideoWidget> createState() => _StatusVideoWidgetState();
}

class _StatusVideoWidgetState extends State<StatusVideoWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
    } else {
      _controller = VideoPlayerController.file(File(widget.videoUrl));
    }
    
    _controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(1.0);
        _controller.play();
      }
    });
  }

  @override
  void dispose() {
    _controller.pause();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

