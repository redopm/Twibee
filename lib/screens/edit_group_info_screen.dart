import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/chat_service.dart';

class EditGroupInfoScreen extends StatefulWidget {
  final String groupId;
  final String currentName;
  final String currentDescription;
  final String? currentAvatarUrl;

  const EditGroupInfoScreen({
    super.key,
    required this.groupId,
    required this.currentName,
    required this.currentDescription,
    this.currentAvatarUrl,
  });

  @override
  State<EditGroupInfoScreen> createState() => _EditGroupInfoScreenState();
}

class _EditGroupInfoScreenState extends State<EditGroupInfoScreen> {
  late TextEditingController _nameController;
  late TextEditingController _descController;
  File? _selectedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descController = TextEditingController(text: widget.currentDescription);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image.')));
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group name cannot be empty.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<ChatService>().updateGroupInfo(
        groupId: widget.groupId,
        name: name != widget.currentName ? name : null,
        description: _descController.text.trim() != widget.currentDescription ? _descController.text.trim() : null,
        imageFile: _selectedImage,
      );

      if (mounted) {
        Navigator.pop(context, true); // true indicates changes were saved
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating group: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: 'Edit Group Info',
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange))))
              : TextButton(
                  onPressed: _saveChanges,
                  child: const Text('Save', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.lightGrey,
                    backgroundImage: _selectedImage != null
                        ? FileImage(_selectedImage!) as ImageProvider
                        : (widget.currentAvatarUrl != null && widget.currentAvatarUrl!.isNotEmpty)
                            ? NetworkImage(widget.currentAvatarUrl!)
                            : null,
                    child: (_selectedImage == null && (widget.currentAvatarUrl == null || widget.currentAvatarUrl!.isEmpty))
                        ? const Icon(Icons.group, size: 50, color: AppColors.grey)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: AppColors.white, size: 20),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Group Name',
                labelStyle: const TextStyle(color: AppColors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange)),
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _descController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Group Description',
                labelStyle: const TextStyle(color: AppColors.grey),
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.grey2)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.orange)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

