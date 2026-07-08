import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/chat_service.dart';

class ContactSelectionScreen extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<String> initialSelectedIds;

  const ContactSelectionScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.initialSelectedIds,
  });

  @override
  State<ContactSelectionScreen> createState() => _ContactSelectionScreenState();
}

class _ContactSelectionScreenState extends State<ContactSelectionScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _contacts = [];
  Set<String> _selectedIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedIds = Set.from(widget.initialSelectedIds);
    // Delay slightly to ensure context is ready for provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContacts();
    });
  }

  Future<void> _loadContacts() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final chatService = context.read<ChatService>();
      final result = await chatService.syncDeviceContacts();
      
      // registeredUsers contains the profiles of users in their contacts
      if (mounted) {
        setState(() {
          _contacts = result.registeredUsers.where((u) => u['id'] != currentUserId).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading contacts: $e')));
      }
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: widget.title,
        subtitle: '${_selectedIds.length} ${widget.subtitle}',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _contacts.isEmpty
              ? const Center(child: Text('No contacts found.', style: TextStyle(color: AppColors.grey)))
              : ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) {
                    final contact = _contacts[index];
                    final isSelected = _selectedIds.contains(contact['id']);
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.lightGrey,
                        backgroundImage: contact['avatar_url'] != null ? NetworkImage(contact['avatar_url']) : null,
                        child: contact['avatar_url'] == null ? const Icon(Icons.person, color: AppColors.grey) : null,
                      ),
                      title: Text(contact['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(contact['phone_number'] ?? '', style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: AppColors.green)
                          : const Icon(Icons.radio_button_unchecked, color: AppColors.grey),
                      onTap: () => _toggleSelection(contact['id']),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.green,
        onPressed: () {
          Navigator.pop(context, _selectedIds.toList());
        },
        child: const Icon(Icons.check, color: AppColors.white),
      ),
    );
  }
}

