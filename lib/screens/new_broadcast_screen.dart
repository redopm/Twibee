import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'individual_chat_screen.dart';

class NewBroadcastScreen extends StatefulWidget {
  const NewBroadcastScreen({super.key});

  @override
  State<NewBroadcastScreen> createState() => _NewBroadcastScreenState();
}

class _NewBroadcastScreenState extends State<NewBroadcastScreen> {
  List<Map<String, dynamic>> _registeredUsers = [];
  final List<String> _selectedUserIds = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final chatService = context.read<ChatService>();
      final syncResult = await chatService.syncDeviceContacts();
      if (mounted) {
        setState(() {
          _registeredUsers = syncResult.registeredUsers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createBroadcast() async {
    if (_selectedUserIds.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      final chatService = context.read<ChatService>();
      final listName = '\ recipients';
      final chatId = await chatService.createBroadcastList(listName, _selectedUserIds);
      
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => IndividualChatScreen(
              chatId: chatId,
              chatName: listName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error creating broadcast: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: 'New broadcast',
        subtitle: '${_selectedUserIds.length} of 30 selected',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _registeredUsers.isEmpty
              ? const Center(child: Text('No contacts found', style: TextStyle(color: AppColors.grey)))
              : Column(
                  children: [
                    if (_selectedUserIds.isNotEmpty)
                      Container(
                        height: 80,
                        color: AppColors.lightGrey,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _selectedUserIds.length,
                          itemBuilder: (context, index) {
                            final userId = _selectedUserIds[index];
                            final user = _registeredUsers.firstWhere((u) => u['id'] == userId);
                            final name = user['name']?.toString() ?? 'User';
                            final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                            
                            return Padding(
                              padding: const EdgeInsets.only(right: 12.0, top: 12, bottom: 8),
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: AppColors.green,
                                        backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                                        child: user['avatar_url'] == null ? Text(initial, style: const TextStyle(color: AppColors.white)) : null,
                                      ),
                                      Positioned(
                                        bottom: 0,
                                        right: 0,
                                        child: GestureDetector(
                                          onTap: () {
                                            setState(() => _selectedUserIds.remove(userId));
                                          },
                                          child: Container(
                                            decoration: const BoxDecoration(color: AppColors.grey, shape: BoxShape.circle),
                                            child: const Icon(Icons.close, size: 14, color: AppColors.white),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(name.split(' ')[0], style: const TextStyle(fontSize: 10, color: AppColors.dark)),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _registeredUsers.length,
                        itemBuilder: (context, index) {
                          final user = _registeredUsers[index];
                          final userId = user['id'] as String;
                          final isSelected = _selectedUserIds.contains(userId);
                          final name = user['name']?.toString() ?? 'User';
                          final initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

                          return ListTile(
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.green,
                                  backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                                  child: user['avatar_url'] == null ? Text(initial, style: const TextStyle(color: AppColors.white)) : null,
                                ),
                                if (isSelected)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: AppColors.white, width: 1.5),
                                      ),
                                      child: const Icon(Icons.check, size: 12, color: AppColors.white),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(user['phone_number'] ?? '', style: const TextStyle(color: AppColors.grey2)),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUserIds.remove(userId);
                                } else {
                                  if (_selectedUserIds.length < 30) {
                                    _selectedUserIds.add(userId);
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only select up to 30 contacts')));
                                  }
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createBroadcast,
              backgroundColor: AppColors.green,
              child: const Icon(Icons.check, color: AppColors.white),
            )
          : null,
    );
  }
}

