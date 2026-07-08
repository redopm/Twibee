import 'package:flutter/material.dart';
import '../../services/chat_service.dart';
import 'audio_message_widget.dart'; // Ensure we import the correct audio widget

class SignedAudioWidget extends StatefulWidget {
  final String mediaUrl;
  final ChatService chatService;

  const SignedAudioWidget({
    super.key,
    required this.mediaUrl,
    required this.chatService,
  });

  @override
  State<SignedAudioWidget> createState() => _SignedAudioWidgetState();
}

class _SignedAudioWidgetState extends State<SignedAudioWidget> {
  String? _signedUrl;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchSignedUrl();
  }

  @override
  void didUpdateWidget(SignedAudioWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaUrl != widget.mediaUrl) {
      _fetchSignedUrl();
    }
  }

  Future<void> _fetchSignedUrl() async {
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
    if (_isLoading) {
      return const SizedBox(
        width: 200,
        height: 50,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_hasError || _signedUrl == null) {
      return const Text('Error loading audio', style: TextStyle(color: Colors.red));
    }
    return AudioMessageWidget(url: _signedUrl!);
  }
}

