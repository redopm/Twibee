import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../services/channel_service.dart';

class ChannelAppearanceScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  const ChannelAppearanceScreen({super.key, required this.channel});

  @override
  State<ChannelAppearanceScreen> createState() => _ChannelAppearanceScreenState();
}

class _ChannelAppearanceScreenState extends State<ChannelAppearanceScreen> {
  final ChannelService _channelService = ChannelService();
  bool _isLoading = false;
  String? _currentWallpaper;

  @override
  void initState() {
    super.initState();
    _currentWallpaper = widget.channel['wallpaper_url'];
  }

  Future<void> _pickWallpaper() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await _channelService.updateChannelWallpaper(widget.channel['id'], File(picked.path));
        // Refresh channel data to get new wallpaper url
        final freshChannel = await _channelService.getChannel(widget.channel['id']);
        if (mounted) {
          setState(() {
            _currentWallpaper = freshChannel['wallpaper_url'];
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallpaper updated successfully'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeWallpaper() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      await _channelService.updateChannelFields(widget.channel['id'], {'wallpaper_url': null});
      if (mounted) {
        setState(() => _currentWallpaper = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallpaper removed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Appearance'),
      body: Center(
        child: _isLoading 
        ? const CircularProgressIndicator(color: AppColors.orange)
        : Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_currentWallpaper != null)
              Container(
                width: 200,
                height: 300,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  image: DecorationImage(image: NetworkImage(_currentWallpaper!), fit: BoxFit.cover),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10)],
                ),
              )
            else
              const Icon(Icons.wallpaper, size: 80, color: AppColors.grey),
            const SizedBox(height: 16),
            const Text('Channel Wallpaper', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Set a custom background for this channel.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey2)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickWallpaper,
              icon: const Icon(Icons.image, color: Colors.white),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
              label: Text(_currentWallpaper != null ? 'Change Wallpaper' : 'Choose Wallpaper', style: const TextStyle(color: Colors.white)),
            ),
            if (_currentWallpaper != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _removeWallpaper,
                child: const Text('Remove Wallpaper', style: TextStyle(color: Colors.red)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

