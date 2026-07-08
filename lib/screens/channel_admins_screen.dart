import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/channel_service.dart';
import 'channel_admin_permissions_screen.dart';
import 'add_channel_admin_screen.dart';
import 'individual_chat_screen.dart';

class ChannelAdminsScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  final bool isOwner;

  const ChannelAdminsScreen({
    super.key,
    required this.channel,
    required this.isOwner,
  });

  @override
  State<ChannelAdminsScreen> createState() => _ChannelAdminsScreenState();
}

class _ChannelAdminsScreenState extends State<ChannelAdminsScreen> {
  final ChannelService _channelService = ChannelService();
  List<Map<String, dynamic>> _admins = [];
  bool _isLoading = true;
  bool _signMessages = false;

  @override
  void initState() {
    super.initState();
    _signMessages = widget.channel['sign_messages'] ?? false;
    _fetchAdmins();
  }

  Future<void> _fetchAdmins() async {
    setState(() => _isLoading = true);
    try {
      final admins = await _channelService.getAdmins(widget.channel['id']);
      setState(() {
        _admins = admins;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading admins: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAdminOptions(Map<String, dynamic> admin) async {
    final role = admin['role'];
    final userId = admin['user_id'];
    final profile = admin['profiles'] ?? {};

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(profile['name'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(role.toString().toUpperCase()),
            ),
            const Divider(height: 1),
            // Everyone can message another admin
            if (userId != _channelService.currentUserId)
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
            // Only owners can edit permissions (and not of themselves)
            if (widget.isOwner && role != 'owner')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings, color: AppColors.orange),
                title: const Text('Edit Permissions', style: TextStyle(color: AppColors.dark)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChannelAdminPermissionsScreen(
                        channel: widget.channel,
                        adminUser: admin,
                      ),
                    ),
                  );
                  if (result != null) _fetchAdmins();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7), // standard light grey background
      appBar: TwibeeAppBar(
        title: 'Admins',
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.orange),
            onPressed: () {},
          ),
          TextButton(
            onPressed: () {},
            child: const Text('Edit', style: TextStyle(color: AppColors.orange, fontSize: 16)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 12, bottom: 8),
                  child: Text(
                    'CHANNEL ADMINS',
                    style: TextStyle(color: AppColors.grey2, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (widget.isOwner) ...[
                        ListTile(
                          leading: const Icon(Icons.person_add_alt_1, color: AppColors.orange),
                          title: const Text('Add Admin', style: TextStyle(color: AppColors.orange, fontSize: 16)),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => AddChannelAdminScreen(channel: widget.channel)),
                            );
                            if (result != null) {
                              _fetchAdmins();
                            }
                          },
                        ),
                        if (_admins.isNotEmpty) const Divider(height: 1, indent: 56),
                      ],
                      ..._admins.asMap().entries.map((entry) {
                        final i = entry.key;
                        final admin = entry.value;
                        final profile = admin['profiles'] ?? {};
                        final name = profile['name'] ?? 'Unknown';
                        final avatarUrl = profile['avatar_url'];
                        final role = admin['role'];
                        final isLast = i == _admins.length - 1;

                        String subtitleText = role == 'owner' ? 'owner' : 'promoted by Admin';

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
                              subtitle: Text(subtitleText, style: const TextStyle(color: AppColors.grey2, fontSize: 14)),
                              onTap: () => _showAdminOptions(admin),
                            ),
                            if (!isLast) const Divider(height: 1, indent: 72),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 8, bottom: 24),
                  child: Text(
                    'You can add admins to help you manage your channel.',
                    style: TextStyle(color: AppColors.grey2, fontSize: 13),
                  ),
                ),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    title: const Text('Sign Messages', style: TextStyle(fontSize: 16, color: AppColors.dark)),
                    trailing: Switch(
                      value: _signMessages,
                      onChanged: (val) async {
                        setState(() => _signMessages = val);
                        try {
                          await _channelService.updateChannelFields(widget.channel['id'], {'sign_messages': val});
                        } catch (e) {
                          if (mounted) {
                            setState(() => _signMessages = !val);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update sign messages. Verify SQL schema.')));
                          }
                        }
                      },
                      activeColor: AppColors.orange,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

