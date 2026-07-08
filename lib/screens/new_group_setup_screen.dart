import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme.dart';
import '../services/chat_service.dart';
import 'group_permissions_screen.dart';
import 'individual_chat_screen.dart';

class NewGroupSetupScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedUsers;

  const NewGroupSetupScreen({super.key, required this.selectedUsers});

  @override
  State<NewGroupSetupScreen> createState() => _NewGroupSetupScreenState();
}

class _NewGroupSetupScreenState extends State<NewGroupSetupScreen> {
  final TextEditingController _groupNameController = TextEditingController();
  bool _isLoading = false;
  bool _isPublic = false;
  File? _groupImage;
  Map<String, bool> _permissions = {
    'edit_group_settings': true,
    'send_messages': true,
    'add_members': true,
    'invite_via_link': false,
    'approve_members': false,
  };

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Profile photo', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.green),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() => _groupImage = File(image.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo, color: AppColors.green),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() => _groupImage = File(image.path));
                  }
                },
              ),
            ],
          ),
        );
      }
    );
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a group name.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatService = context.read<ChatService>();
      final memberIds = widget.selectedUsers.map((u) => u['id'] as String).toList();
      
      final chatId = await chatService.createGroup(
        groupName, 
        memberIds,
        groupAvatar: _groupImage,
        permissions: _permissions,
        isPublic: _isPublic,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        // Pop all the way back to the home screen, then push the new chat
        Navigator.popUntil(context, (route) => route.isFirst);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => IndividualChatScreen(
              chatId: chatId,
              chatName: groupName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create group: $e')));
      }
    }
  }

  void _removeUser(Map<String, dynamic> user) {
    if (widget.selectedUsers.length == 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group must have at least one member.')));
      return;
    }
    setState(() {
      widget.selectedUsers.removeWhere((u) => u['id'] == user['id']);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: TwibeeAppBar(
        title: 'New group',
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createGroup,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                minimumSize: const Size(0, 36),
              ),
              child: _isLoading 
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                : const Text('Create', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Setup (Camera + Text Field)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: AppColors.white,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.grey2.withValues(alpha: 0.5),
                      backgroundImage: _groupImage != null ? FileImage(_groupImage!) : null,
                      child: _groupImage == null ? const Icon(Icons.camera_alt, color: AppColors.green, size: 28) : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _groupNameController,
                      decoration: const InputDecoration(
                        hintText: 'Group name (optional)',
                        hintStyle: TextStyle(color: AppColors.grey),
                        border: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green, width: 2)),
                      ),
                      maxLength: 100,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Settings Tiles
            Container(
              color: AppColors.white,
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Public Group', style: TextStyle(color: AppColors.dark, fontSize: 16)),
                    subtitle: const Text('Anyone can find and join your public group.', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                    value: _isPublic,
                    activeThumbColor: AppColors.green,
                    onChanged: (val) {
                      setState(() => _isPublic = val);
                    },
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    title: const Text('Disappearing messages', style: TextStyle(color: AppColors.dark, fontSize: 16)),
                    trailing: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Off', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                        SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: AppColors.grey),
                      ],
                    ),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disappearing messages coming soon!')));
                    },
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    title: const Text('Group permissions', style: TextStyle(color: AppColors.dark, fontSize: 16)),
                    trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
                    onTap: () async {
                      final updatedPermissions = await Navigator.push<Map<String, bool>>(
                        context, 
                        MaterialPageRoute(builder: (_) => GroupPermissionsScreen(currentPermissions: _permissions))
                      );
                      if (updatedPermissions != null) {
                        setState(() {
                          _permissions = updatedPermissions;
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            
            // Members count text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                'MEMBERS: ${widget.selectedUsers.length} OF 1,023',
                style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),

            // Members Grid/List
            Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Wrap(
                spacing: 16.0,
                runSpacing: 16.0,
                children: widget.selectedUsers.map((user) {
                  final name = user['contact_name'] ?? user['name'] ?? 'User';
                  final avatar = user['avatar_url'];
                  return SizedBox(
                    width: 72,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: AppColors.grey2,
                              backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                              child: avatar == null ? const Icon(Icons.person, color: AppColors.white) : null,
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: GestureDetector(
                                onTap: () => _removeUser(user),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: AppColors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: const TextStyle(fontSize: 12, color: AppColors.dark),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

