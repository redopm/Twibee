import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/channel_service.dart';

class ChannelBannedUsersScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const ChannelBannedUsersScreen({super.key, required this.channel});

  @override
  State<ChannelBannedUsersScreen> createState() => _ChannelBannedUsersScreenState();
}

class _ChannelBannedUsersScreenState extends State<ChannelBannedUsersScreen> {
  final ChannelService _channelService = ChannelService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _bannedUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchBannedUsers();
  }

  Future<void> _fetchBannedUsers() async {
    setState(() => _isLoading = true);
    try {
      final banned = await _channelService.getBannedUsers(widget.channel['id']);
      if (mounted) {
        setState(() {
          _bannedUsers = banned;
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

  Future<void> _unbanUser(String userId, String name) async {
    try {
      await _channelService.unbanUser(widget.channel['id'], userId);
      setState(() {
        _bannedUsers.removeWhere((u) => u['user_id'] == userId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name unbanned successfully')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Removed Users'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _bannedUsers.isEmpty
              ? const Center(child: Text('No removed users found.', style: TextStyle(color: AppColors.grey2)))
              : ListView.separated(
                  itemCount: _bannedUsers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final banned = _bannedUsers[i];
                    final profile = banned['profiles'] ?? {};
                    final name = profile['name'] ?? 'Unknown';
                    final avatarUrl = profile['avatar_url'];
                    final userId = banned['user_id'];

                    return ListTile(
                      tileColor: AppColors.white,
                      leading: CircleAvatar(
                        backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(name[0].toUpperCase(), style: const TextStyle(color: AppColors.orange)) : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark)),
                      subtitle: const Text('Banned', style: TextStyle(color: Colors.red, fontSize: 12)),
                      trailing: TextButton(
                        onPressed: () => _unbanUser(userId, name),
                        child: const Text('Unban', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
    );
  }
}

