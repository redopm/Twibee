import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'new_group_setup_screen.dart';

class SelectGroupMembersScreen extends StatefulWidget {
  const SelectGroupMembersScreen({super.key});

  @override
  State<SelectGroupMembersScreen> createState() => _SelectGroupMembersScreenState();
}

class _SelectGroupMembersScreenState extends State<SelectGroupMembersScreen> {
  List<Map<String, dynamic>> _allUsers = [];
  final List<Map<String, dynamic>> _selectedUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  final int _maxMembers = 1023;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final result = await context.read<ChatService>().syncDeviceContacts();
      final users = result.registeredUsers;
      if (mounted) {
        setState(() {
          _allUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _toggleSelection(Map<String, dynamic> user) {
    setState(() {
      final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
      if (isSelected) {
        _selectedUsers.removeWhere((u) => u['id'] == user['id']);
      } else {
        if (_selectedUsers.length >= _maxMembers) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('You can only select up to $_maxMembers members for a group!')),
          );
        } else {
          _selectedUsers.add(user);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _allUsers.where((user) {
      final name = (user['contact_name'] ?? user['name'] ?? '').toLowerCase();
      final phone = (user['phone_number'] ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: TwibeeAppBar(
        title: 'Add members',
        subtitle: '${_selectedUsers.length}/$_maxMembers',
        onBack: () => Navigator.maybePop(context),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.dark),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          if (_selectedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => NewGroupSetupScreen(selectedUsers: _selectedUsers)));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                  minimumSize: const Size(0, 36),
                ),
                child: const Text('Next', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search name or number',
                  hintStyle: TextStyle(color: AppColors.grey),
                  prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),

          // Selected Members Horizontal List
          if (_selectedUsers.isNotEmpty)
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedUsers.length,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                itemBuilder: (context, index) {
                  final user = _selectedUsers[index];
                  final name = user['contact_name'] ?? user['name'] ?? 'User';
                  final avatar = user['avatar_url'];
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
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
                                onTap: () => _toggleSelection(user),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFF2F2F7), width: 2),
                                  ),
                                  child: const Icon(Icons.close, size: 12, color: AppColors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 60,
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 12, color: AppColors.dark),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          if (_selectedUsers.isNotEmpty)
            const Divider(height: 1, color: AppColors.grey2),

          // Contacts Header
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Frequently contacted',
                style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),

          // Contact List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.green))
                : ListView.builder(
                    itemCount: filteredUsers.length,
                    itemBuilder: (context, index) {
                      final user = filteredUsers[index];
                      final isSelected = _selectedUsers.any((u) => u['id'] == user['id']);
                      final name = user['contact_name'] ?? user['name'] ?? 'User';
                      final about = user['about'] ?? 'Hey there! I am using Twibee.';
                      final avatar = user['avatar_url'];

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.grey2,
                          backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                          child: avatar == null ? const Icon(Icons.person, color: AppColors.white) : null,
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Text(about, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                        trailing: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? AppColors.green : Colors.transparent,
                            border: Border.all(
                              color: isSelected ? AppColors.green : AppColors.grey,
                              width: 1.5,
                            ),
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 16, color: AppColors.white) : null,
                        ),
                        onTap: () => _toggleSelection(user),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

