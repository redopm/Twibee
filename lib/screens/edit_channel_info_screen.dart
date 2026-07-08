import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../services/channel_service.dart';

class EditChannelInfoScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const EditChannelInfoScreen({super.key, required this.channel});

  @override
  State<EditChannelInfoScreen> createState() => _EditChannelInfoScreenState();
}

class _EditChannelInfoScreenState extends State<EditChannelInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descController;
  final ChannelService _channelService = ChannelService();

  bool _isLoading = false;
  bool _isAvatarLoading = false;
  File? _avatarFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.channel['name'] ?? '');
    _descController = TextEditingController(text: widget.channel['description'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      if (mounted) setState(() => _isAvatarLoading = true);
      try {
        await _channelService.updateChannel(
          channelId: widget.channel['id'],
          avatarFile: File(picked.path),
        );
        if (mounted) {
          setState(() {
            _avatarFile = File(picked.path);
            widget.channel['avatar_url'] = null; // Forces local file display
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated successfully'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating photo: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _isAvatarLoading = false);
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _channelService.updateChannel(
        channelId: widget.channel['id'],
        name: _nameController.text.trim(),
        description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        // avatarFile is now uploaded instantly via _pickAvatar
        // isPublic and restrictSaving are updated in a different screen
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel info updated!'), backgroundColor: Colors.green));
        Navigator.pop(context, true); // return true to signal update
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existingAvatarUrl = widget.channel['avatar_url'];

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: 'Edit Info',
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2))))
              : IconButton(icon: const Icon(Icons.check, color: AppColors.orange), onPressed: _saveChanges),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: GestureDetector(
                onTap: _isAvatarLoading ? null : _pickAvatar,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                      backgroundImage: _avatarFile != null
                          ? FileImage(_avatarFile!)
                          : (existingAvatarUrl != null ? NetworkImage(existingAvatarUrl) : null) as ImageProvider?,
                      child: _avatarFile == null && existingAvatarUrl == null
                          ? const Icon(Icons.camera_alt, size: 40, color: AppColors.orange)
                          : null,
                    ),
                    if (_isAvatarLoading)
                      const Positioned.fill(
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3),
                        ),
                      ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(child: Text('Set New Photo', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold))),
            const SizedBox(height: 32),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Channel Name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Channel name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              maxLines: 3,
              maxLength: 255,
              decoration: InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

