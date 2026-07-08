import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../services/settings_service.dart';

class SignedImageWidget extends StatefulWidget {
  final String mediaUrl;
  final ChatService chatService;
  final BoxFit fit;
  final double? width;
  final double? height;

  const SignedImageWidget({
    super.key,
    required this.mediaUrl,
    required this.chatService,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  State<SignedImageWidget> createState() => _SignedImageWidgetState();
}

class _SignedImageWidgetState extends State<SignedImageWidget> {
  String? _signedUrl;
  bool _isLoading = false;
  bool _hasError = false;
  bool _needsDownload = false;

  @override
  void initState() {
    super.initState();
    _checkAutoDownload();
  }

  void _checkAutoDownload() {
    // If it's a local file or already an http URL, no need to download
    if (widget.mediaUrl.startsWith('http') || widget.mediaUrl.startsWith('/')) {
      _fetchSignedUrl();
      return;
    }

    // Default to 'On' if not found (though MVP UI says 'Off' is default, let's respect the settings service)
    final settings = Provider.of<SettingsService>(context, listen: false);
    final autoPhoto = settings.getSetting('media_auto_photo', defaultValue: 'Off');
    
    if (autoPhoto == 'Off') {
      setState(() => _needsDownload = true);
    } else {
      _fetchSignedUrl();
    }
  }

  @override
  void didUpdateWidget(SignedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _needsDownload = false;
      _checkAutoDownload();
    }
  }

  Future<void> _fetchSignedUrl() async {
    setState(() {
      _isLoading = true;
      _needsDownload = false;
    });
    try {
      final url = await widget.chatService.getMediaSignedUrl(widget.mediaUrl);
      if (mounted) {
        setState(() {
          _signedUrl = url;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_needsDownload) {
      return GestureDetector(
        onTap: _fetchSignedUrl,
        child: Container(
          width: widget.width ?? 150,
          height: widget.height ?? 150,
          color: const Color(0xFF2A2A2A), // Dark Grey Box
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
    if (_isLoading) {
      return SizedBox(
        width: widget.width ?? 150,
        height: widget.height ?? 150,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasError || _signedUrl == null) {
      return SizedBox(
        width: widget.width ?? 150,
        height: widget.height ?? 150,
        child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
      );
    }
    return _signedUrl!.startsWith('http')
        ? Image.network(_signedUrl!, width: widget.width, height: widget.height, fit: widget.fit)
        : Image.file(File(_signedUrl!), width: widget.width, height: widget.height, fit: widget.fit);
  }
}

