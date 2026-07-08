import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/chat_service.dart';

class BlockedContactsScreen extends StatefulWidget {
  const BlockedContactsScreen({super.key});

  @override
  State<BlockedContactsScreen> createState() => _BlockedContactsScreenState();
}

class _BlockedContactsScreenState extends State<BlockedContactsScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  List<Map<String, dynamic>> _blockedProfiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedProfiles();
  }

  Future<void> _loadBlockedProfiles() async {
    final chatService = context.read<ChatService>();
    await chatService.loadBlockedUsers();
    final blockedIds = chatService.blockedUserIds;

    if (blockedIds.isEmpty) {
      if (mounted) {
        setState(() {
          _blockedProfiles = [];
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final data = await _supabase
          .from('profiles')
          .select('id, name, phone_number, avatar_url')
          .inFilter('id', blockedIds);
      
      if (mounted) {
        setState(() {
          _blockedProfiles = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading blocked profiles: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unblock(String userId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Unblock $name?'),
        content: const Text('They will be able to call you and send you messages.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Unblock')),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        final chatService = context.read<ChatService>();
        await chatService.unblockUser(userId);
        _loadBlockedProfiles(); // reload UI
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name unblocked')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to unblock: $e')));
      }
    }
  }

  Future<void> _addBlockedContact() async {
    // Ideally this opens the contact list. We'll just fetch all non-blocked users for selection.
    final chatService = context.read<ChatService>();
    final allUsers = await chatService.getAllUsers();
    
    // Filter out already blocked users
    final blockableUsers = allUsers.where((u) => !chatService.isBlocked(u['id'])).toList();

    if (!mounted) return;
    final selectedUser = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          color: AppColors.white,
          child: Column(
            children: [
              AppBar(
                title: const Text('Select Contact to Block', style: TextStyle(color: AppColors.dark, fontSize: 16)),
                backgroundColor: AppColors.white,
                elevation: 0,
                leading: IconButton(icon: const Icon(Icons.close, color: AppColors.dark), onPressed: () => Navigator.pop(context)),
              ),
              Expanded(
                child: blockableUsers.isEmpty
                    ? const Center(child: Text('No contacts available to block.'))
                    : ListView.builder(
                        itemCount: blockableUsers.length,
                        itemBuilder: (context, index) {
                          final user = blockableUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                              backgroundColor: AppColors.lightGrey,
                              child: user['avatar_url'] == null ? const Icon(Icons.person, color: AppColors.grey) : null,
                            ),
                            title: Text(user['name'] ?? user['phone_number'] ?? 'Unknown'),
                            onTap: () => Navigator.pop(context, user),
                          );
                        },
                      ),
              )
            ],
          ),
        );
      }
    );

    if (selectedUser != null) {
      try {
        await chatService.blockUser(selectedUser['id']);
        _loadBlockedProfiles();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to block: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Blocked contacts',
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.orange),
            onPressed: _addBlockedContact,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _blockedProfiles.isEmpty 
          ? const Center(child: Text('No blocked contacts', style: TextStyle(color: AppColors.grey, fontSize: 16)))
          : ListView.builder(
              itemCount: _blockedProfiles.length,
              itemBuilder: (context, index) {
                final user = _blockedProfiles[index];
                return Container(
                  color: AppColors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user['avatar_url'] != null ? NetworkImage(user['avatar_url']) : null,
                      backgroundColor: AppColors.lightGrey,
                      child: user['avatar_url'] == null ? const Icon(Icons.person, color: AppColors.grey) : null,
                    ),
                    title: Text(user['name'] ?? user['phone_number'] ?? 'Unknown', style: const TextStyle(fontSize: 16)),
                    onTap: () => _unblock(user['id'], user['name'] ?? user['phone_number'] ?? 'Unknown'),
                  ),
                );
              },
            ),
    );
  }
}

