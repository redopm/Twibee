import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../theme.dart';

class AddParticipantsScreen extends StatefulWidget {
  final String chatId;
  const AddParticipantsScreen({super.key, required this.chatId});

  @override
  State<AddParticipantsScreen> createState() => _AddParticipantsScreenState();
}

class _AddParticipantsScreenState extends State<AddParticipantsScreen> {
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _existingMembers = [];
  final List<String> _selectedUserIds = [];
  bool _isLoading = true;
  final String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final chatService = context.read<ChatService>();
      final contactsResult = await chatService.syncDeviceContacts();
      final users = contactsResult.registeredUsers;
      final members = await chatService.getGroupParticipants(widget.chatId);
      
      if (mounted) {
        setState(() {
          _allUsers = users;
          _existingMembers = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load contacts. Please allow contact permissions.')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addSelectedUsers() async {
    if (_selectedUserIds.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await context.read<ChatService>().addParticipants(widget.chatId, _selectedUserIds);
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding participants: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Filter out users who are already in the group
    final existingIds = _existingMembers.map((m) => m['id']).toSet();
    final availableUsers = _allUsers.where((u) => !existingIds.contains(u['id']) && u['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Add Participants'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : availableUsers.isEmpty
              ? const Center(child: Text('No more users to add', style: TextStyle(color: AppColors.grey)))
              : ListView.builder(
                  itemCount: availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = availableUsers[index];
                    final userId = user['id'] as String;
                    final isSelected = _selectedUserIds.contains(userId);
                    
                    String initial = user['name'] != null && user['name'].toString().isNotEmpty 
                        ? user['name'].toString()[0].toUpperCase() : '?';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.blue,
                        child: Text(initial, style: const TextStyle(color: AppColors.white)),
                      ),
                      title: Text(user['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(user['phone_number'] ?? '', style: const TextStyle(color: AppColors.grey2)),
                      trailing: Checkbox(
                        value: isSelected,
                        activeColor: AppColors.orange,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedUserIds.add(userId);
                            } else {
                              _selectedUserIds.remove(userId);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(userId);
                          } else {
                            _selectedUserIds.add(userId);
                          }
                        });
                      },
                    );
                  },
                ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _addSelectedUsers,
              backgroundColor: AppColors.orange,
              icon: const Icon(Icons.check, color: AppColors.white),
              label: Text('Add (${_selectedUserIds.length})', style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }
}

