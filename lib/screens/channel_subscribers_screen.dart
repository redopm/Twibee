import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/channel_service.dart';
import 'contact_selection_screen.dart';
import 'individual_chat_screen.dart';

class ChannelSubscribersScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  final bool isAdminOrOwner;

  const ChannelSubscribersScreen({
    super.key,
    required this.channel,
    required this.isAdminOrOwner,
  });

  @override
  State<ChannelSubscribersScreen> createState() => _ChannelSubscribersScreenState();
}

class _ChannelSubscribersScreenState extends State<ChannelSubscribersScreen> {
  final ChannelService _channelService = ChannelService();
  List<Map<String, dynamic>> _subscribers = [];
  List<Map<String, dynamic>> _filteredSubscribers = [];
  bool _isLoading = true;
  bool _isEditMode = false;
  final Set<String> _selectedUserIdsForRemoval = {};
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchSubscribers();
  }

  Future<void> _fetchSubscribers() async {
    setState(() => _isLoading = true);
    try {
      final subs = await _channelService.getSubscribers(widget.channel['id']);
      setState(() {
        _subscribers = subs;
        _filteredSubscribers = subs;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading subscribers: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredSubscribers = _subscribers.where((sub) {
        final profile = sub['profiles'] ?? {};
        final name = (profile['name'] ?? '').toLowerCase();
        final username = (profile['username'] ?? '').toLowerCase();
        return name.contains(_searchQuery) || username.contains(_searchQuery);
      }).toList();
    });
  }

  void _showUserOptions(Map<String, dynamic> subscriber) {
    if (!widget.isAdminOrOwner) return;
    
    final profile = subscriber['profiles'] ?? {};
    final userId = subscriber['user_id'];
    
    // Cannot ban yourself or the owner
    if (userId == _channelService.currentUserId || userId == widget.channel['owner_id']) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(profile['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Manage user'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline, color: AppColors.orange),
              title: const Text('Message User', style: TextStyle(color: AppColors.dark)),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => IndividualChatScreen(
                  otherUserId: userId,
                  chatName: profile['name'] ?? 'User',
                )));
              },
            ),
            // ONLY THE OWNER CAN PROMOTE TO ADMIN (Prevent Admin Breeding Rule)
            if (widget.channel['owner_id'] == _channelService.currentUserId)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: AppColors.orange),
                title: const Text('Promote to Admin', style: TextStyle(color: AppColors.orange)),
                onTap: () {
                  Navigator.pop(ctx);
                  _promoteToAdmin(userId, profile['name'] ?? 'User');
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('Remove from channel', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _removeUser(userId, profile['name'] ?? 'User');
              },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Ban User', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _banUser(userId, profile['name'] ?? 'User');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _promoteToAdmin(String userId, String name) async {
    try {
      // Use default full permissions for a new admin.
      final defaultPermissions = {
        'can_edit_info': true,
        'can_post_messages': true,
        'can_edit_messages': true,
        'can_delete_messages': true,
        'can_manage_subscribers': true,
        'can_manage_admins': false, // Usually only owner manages admins
      };
      await _channelService.addAdmin(widget.channel['id'], userId, defaultPermissions);
      // Once promoted, we can either leave them in the subscribers list (as they are technically still subscribers)
      // or just refresh to show any new status.
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name is now an Admin!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error promoting user: $e')));
    }
  }

  Future<void> _removeUser(String userId, String name) async {
    try {
      await _channelService.removeMultipleSubscribers(widget.channel['id'], [userId]);
      setState(() {
        _subscribers.removeWhere((s) => s['user_id'] == userId);
        _onSearchChanged(_searchQuery);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name removed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _removeSelectedUsers() async {
    final idsToRemove = _selectedUserIdsForRemoval.toList();
    try {
      await _channelService.removeMultipleSubscribers(widget.channel['id'], idsToRemove);
      setState(() {
        _subscribers.removeWhere((s) => idsToRemove.contains(s['user_id']));
        _selectedUserIdsForRemoval.clear();
        _isEditMode = false;
        _onSearchChanged(_searchQuery);
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selected subscribers removed')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _banUser(String userId, String name) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ban $name?'),
        content: const Text('This user will be removed and cannot rejoin the channel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _channelService.banUser(widget.channel['id'], userId, reason: 'Banned by admin');
                setState(() {
                  _subscribers.removeWhere((s) => s['user_id'] == userId);
                  _onSearchChanged(_searchQuery);
                });
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name banned')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Ban', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // standard light grey background
      appBar: TwibeeAppBar(
        title: '${_subscribers.length} Members',
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.orange),
            onPressed: () {},
          ),
          if (widget.isAdminOrOwner)
            TextButton(
              onPressed: () {
                setState(() {
                  _isEditMode = !_isEditMode;
                  _selectedUserIdsForRemoval.clear();
                });
              },
              child: Text(_isEditMode ? 'Done' : 'Edit', style: const TextStyle(color: AppColors.orange, fontSize: 16)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (widget.isAdminOrOwner) ...[
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: ListTile(
                      leading: const Icon(Icons.person_add_alt_1, color: AppColors.orange),
                      title: const Text('Add Subscribers', style: TextStyle(color: AppColors.orange, fontSize: 16)),
                      onTap: () async {
                        final selectedIds = await Navigator.push<List<String>>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ContactSelectionScreen(
                              title: 'Add Subscribers',
                              subtitle: 'selected',
                              initialSelectedIds: [],
                            ),
                          ),
                        );

                        if (selectedIds != null && selectedIds.isNotEmpty) {
                          await _channelService.addMultipleSubscribers(widget.channel['id'], selectedIds);
                          _fetchSubscribers();
                        }
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 8, bottom: 24),
                    child: Text(
                      'Only channel admins can see this list.',
                      style: TextStyle(color: AppColors.grey2, fontSize: 13),
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(
                    'OTHER SUBSCRIBERS',
                    style: TextStyle(color: AppColors.grey2, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                if (_filteredSubscribers.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No subscribers found', style: TextStyle(color: AppColors.grey2)),
                  ))
                else
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: _filteredSubscribers.asMap().entries.map((entry) {
                        final i = entry.key;
                        final sub = entry.value;
                        final profile = sub['profiles'] ?? {};
                        final name = profile['name'] ?? 'Unknown';
                        final avatarUrl = profile['avatar_url'];
                        final isLast = i == _filteredSubscribers.length - 1;

                        return Column(
                          children: [
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null
                                    ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U', style: const TextStyle(color: AppColors.orange))
                                    : null,
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.dark, fontSize: 16)),
                              subtitle: const Text('last seen recently', style: TextStyle(color: AppColors.grey2, fontSize: 14)), // dummy
                              trailing: _isEditMode && sub['user_id'] != _channelService.currentUserId && sub['user_id'] != widget.channel['owner_id']
                                  ? Checkbox(
                                      value: _selectedUserIdsForRemoval.contains(sub['user_id']),
                                      activeColor: AppColors.orange,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedUserIdsForRemoval.add(sub['user_id']);
                                          } else {
                                            _selectedUserIdsForRemoval.remove(sub['user_id']);
                                          }
                                        });
                                      },
                                    )
                                  : null,
                              onTap: _isEditMode
                                  ? () {
                                      if (sub['user_id'] != _channelService.currentUserId && sub['user_id'] != widget.channel['owner_id']) {
                                        setState(() {
                                          if (_selectedUserIdsForRemoval.contains(sub['user_id'])) {
                                            _selectedUserIdsForRemoval.remove(sub['user_id']);
                                          } else {
                                            _selectedUserIdsForRemoval.add(sub['user_id']);
                                          }
                                        });
                                      }
                                    }
                                  : () => _showUserOptions(sub),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 72),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
      floatingActionButton: _isEditMode && _selectedUserIdsForRemoval.isNotEmpty
          ? FloatingActionButton.extended(
              backgroundColor: Colors.red,
              onPressed: _removeSelectedUsers,
              icon: const Icon(Icons.delete, color: Colors.white),
              label: Text('Remove ${_selectedUserIdsForRemoval.length}', style: const TextStyle(color: Colors.white)),
            )
          : null,
    );
  }
}

