import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/channel_service.dart';
import 'channel_admin_permissions_screen.dart';

class AddChannelAdminScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const AddChannelAdminScreen({super.key, required this.channel});

  @override
  State<AddChannelAdminScreen> createState() => _AddChannelAdminScreenState();
}

class _AddChannelAdminScreenState extends State<AddChannelAdminScreen> {
  final ChannelService _channelService = ChannelService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _subscribers = [];
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
      final admins = await _channelService.getAdmins(widget.channel['id']);
      
      final adminIds = admins.map((a) => a['admin_id']).toSet();
      
      // Filter out existing admins
      final eligibleSubs = subs.where((s) => !adminIds.contains(s['user_id'])).toList();

      if (mounted) {
        setState(() {
          _subscribers = eligibleSubs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _promoteToAdmin(Map<String, dynamic> subscriber) async {
    final userId = subscriber['user_id'];
    
    // Default new admin permissions
    final newAdminData = {
      'admin_id': userId,
      'role': 'admin',
      'permissions': {
        'change_info': false,
        'delete_messages': false,
        'ban_users': false,
        'invite_via_link': false,
        'pin_messages': false,
        'post_messages': true, // default to true so they can at least post
        'add_new_admins': false,
        'remain_anonymous': false,
      },
      'profiles': subscriber['profiles'],
    };

    // Before actually adding, we open the permissions screen so the owner can configure it!
    // But since it's a NEW admin, ChannelAdminPermissionsScreen needs a way to KNOW it's new,
    // OR we just add them with defaults and immediately open the permissions screen.
    // Telegram adds them immediately with defaults, then opens the screen. Let's do that.
    
    setState(() => _isLoading = true);
    try {
      await _channelService.addAdmin(
        widget.channel['id'],
        userId,
        newAdminData['permissions'] as Map<String, dynamic>,
      );

      if (mounted) {
        // Now open the permissions screen
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ChannelAdminPermissionsScreen(
              channel: widget.channel,
              adminUser: newAdminData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _subscribers.where((s) {
      final profile = s['profiles'] ?? {};
      final name = (profile['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Add Admin'),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search subscribers...',
                prefixIcon: const Icon(Icons.search, color: AppColors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: AppColors.lightGrey,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                : filtered.isEmpty
                    ? const Center(child: Text('No eligible subscribers found.', style: TextStyle(color: AppColors.grey2)))
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final sub = filtered[i];
                          final profile = sub['profiles'] ?? {};
                          final name = profile['name'] ?? 'Unknown';
                          final avatarUrl = profile['avatar_url'];

                          return ListTile(
                            tileColor: AppColors.white,
                            leading: CircleAvatar(
                              backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.orange)) : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark)),
                            subtitle: const Text('Subscriber', style: TextStyle(color: AppColors.grey2, fontSize: 12)),
                            onTap: () => _promoteToAdmin(sub),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

