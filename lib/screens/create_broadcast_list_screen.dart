import 'package:twibee/widgets/gradient_fab.dart';
import 'package:twibee/widgets/hexagon_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../utils/permission_utils.dart';
import 'individual_chat_screen.dart';

class CreateBroadcastListScreen extends StatefulWidget {
  const CreateBroadcastListScreen({super.key});

  @override
  State<CreateBroadcastListScreen> createState() => _CreateBroadcastListScreenState();
}

class _CreateBroadcastListScreenState extends State<CreateBroadcastListScreen> {
  bool _isLoading = true;
  bool _isCreating = false;
  List<Map<String, dynamic>> _registeredUsers = [];
  final Set<String> _selectedUserIds = {};
  final int _maxMembers = 256;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      var status = await Permission.contacts.status;
      if (status.isDenied) status = await Permission.contacts.request();

      if (status.isGranted) {
        final chatService = context.read<ChatService>();
        final result = await chatService.syncDeviceContacts();

        if (mounted) {
          setState(() {
            _registeredUsers = result.registeredUsers;
            _isLoading = false;
          });
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() => _isLoading = false);
          PermissionUtils.showPermissionDialog(context, 'Contacts');
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createBroadcastList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a list name.')));
      return;
    }
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least 2 contacts.')));
      return;
    }

    setState(() => _isCreating = true);

    try {
      final chatService = context.read<ChatService>();
      final broadcastId = await chatService.createBroadcastList(name, _selectedUserIds.toList());

      if (mounted) {
        setState(() => _isCreating = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => IndividualChatScreen(chatId: broadcastId, chatName: name)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCreating = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showNameInputDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Broadcast List Name', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold)),
          content: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'e.g. Family, Office Updates...',
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
            ),
            maxLength: 50,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _createBroadcastList();
              },
              child: const Text('Create', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'New Broadcast',
        subtitle: '${_selectedUserIds.length} of $_maxMembers selected',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _registeredUsers.isEmpty
              ? const Center(child: Text('No Twibee users found', style: TextStyle(color: AppColors.grey)))
              : ListView.builder(
                  itemCount: _registeredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _registeredUsers[index];
                    final userId = user['id'];
                    final name = user['contact_name'] ?? user['name'] ?? 'Unknown';
                    final about = user['about'] ?? 'Available';
                    final avatarUrl = user['avatar_url'];
                    final isSelected = _selectedUserIds.contains(userId);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          HexagonAvatar(
                            radius: 24,
//                             backgroundColor: AppColors.grey2,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.white) : null,
                          ),
                          if (isSelected)
                            const Positioned(
                              bottom: 0,
                              right: 0,
                              child: HexagonAvatar(
                                radius: 10,
//                                 backgroundColor: AppColors.green,
                                child: Icon(Icons.check, color: AppColors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                      subtitle: Text(about, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(userId);
                          } else {
                            if (_selectedUserIds.length < _maxMembers) {
                              _selectedUserIds.add(userId);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('You can only select up to $_maxMembers contacts.')));
                            }
                          }
                        });
                      },
                    );
                  },
                ),
      floatingActionButton: _selectedUserIds.length >= 2
          ? GradientFab(
              onPressed: _isCreating ? null : _showNameInputDialog,
//               backgroundColor: AppColors.green,
              child: _isCreating
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                  : const Icon(Icons.check, color: AppColors.white),
            )
          : null,
    );
  }
}

