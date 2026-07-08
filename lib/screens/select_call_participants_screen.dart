import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'individual_chat_screen.dart';

class SelectCallParticipantsScreen extends StatefulWidget {
  final Map<String, dynamic> callDetails;
  
  const SelectCallParticipantsScreen({super.key, required this.callDetails});

  @override
  State<SelectCallParticipantsScreen> createState() => _SelectCallParticipantsScreenState();
}

class _SelectCallParticipantsScreenState extends State<SelectCallParticipantsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allUsers = [];
  final List<Map<String, dynamic>> _selectedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final users = await context.read<ChatService>().getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching users for call: $e');
      setState(() => _isLoading = false);
    }
  }

  void _toggleUser(Map<String, dynamic> user) {
    setState(() {
      if (_selectedUsers.any((u) => u['id'] == user['id'])) {
        _selectedUsers.removeWhere((u) => u['id'] == user['id']);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _createScheduledCall() async {
    if (_selectedUsers.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final chatService = context.read<ChatService>();
      final title = widget.callDetails['title'];
      final date = widget.callDetails['startDate'] as DateTime;
      final time = widget.callDetails['startTime'] as TimeOfDay;
      final dateString = '${date.day}/${date.month}/${date.year} at ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      final isVideo = widget.callDetails['isVideoCall'] as bool;
      final msg = 'Scheduled ${isVideo ? 'Video' : 'Audio'} Call: "$title"\nWhen: $dateString\n${widget.callDetails['description']}';

      String chatId;
      final selectedIds = _selectedUsers.map((u) => u['id'] as String).toList();
      
      // Save to backend DB
      final scheduledCallId = await chatService.createScheduledCall(
        title, 
        date, 
        isVideo ? 'video' : 'audio', 
        selectedIds
      );

      if (_selectedUsers.length == 1) {
        final currentUserId = chatService.currentUserId;
        final targetUserId = _selectedUsers.first['id'];
        final users = [currentUserId, targetUserId];
        users.sort();
        chatId = users.join('_');

        await chatService.sendMessage(
          chatId: chatId,
          messageType: 'event',
          content: msg,
        );
      } else {
        // If multiple people, create a group
        chatId = await chatService.createGroup(title, selectedIds);
        
        await chatService.sendMessage(
          chatId: chatId,
          messageType: 'event',
          content: msg,
        );
      }

      if (mounted) {
        // Pop the participant screen and the schedule screen
        Navigator.pop(context);
        Navigator.pop(context);
        
        // Navigate to the chat where the schedule was posted
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => IndividualChatScreen(
            chatId: chatId,
            chatName: _selectedUsers.length == 1 ? _selectedUsers.first['name'] : title,
          ),
        ));
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call Scheduled Successfully!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error scheduling call: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: 'Add participants',
        subtitle: '${_selectedUsers.length} selected',
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.dark), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : Column(
              children: [
                // Selected users chip list
                if (_selectedUsers.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.lightGrey)),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _selectedUsers.map((user) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                            child: Text(user['name'][0].toUpperCase(), style: const TextStyle(color: AppColors.orange, fontSize: 12)),
                          ),
                          label: Text(user['name']),
                          deleteIcon: const Icon(Icons.cancel, size: 18, color: AppColors.grey),
                          onDeleted: () => _toggleUser(user),
                          backgroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: AppColors.lightGrey)),
                        );
                      }).toList(),
                    ),
                  ),

                // All contacts list
                Expanded(
                  child: ListView.builder(
                    itemCount: _allUsers.length,
                    itemBuilder: (context, index) {
                      final user = _allUsers[index];
                      final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
                      
                      return ListTile(
                        onTap: () => _toggleUser(user),
                        leading: Stack(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                              child: Text(user['name'][0].toUpperCase(), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 20)),
                            ),
                            if (isSelected)
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                                  child: const Icon(Icons.check, color: AppColors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                        title: Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(user['about'] ?? 'Available', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey)),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: _selectedUsers.isNotEmpty
          ? FloatingActionButton(
              onPressed: _createScheduledCall,
              backgroundColor: AppColors.orange,
              child: const Icon(Icons.check, color: AppColors.white),
            )
          : null,
    );
  }
}

