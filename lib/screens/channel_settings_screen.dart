import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme.dart';
import '../services/channel_service.dart';
import 'channel_admins_screen.dart';
import 'edit_channel_info_screen.dart';
import 'edit_channel_type_screen.dart';
import 'channel_banned_users_screen.dart';
import 'package:twibee/screens/channel_subscribers_screen.dart';
import 'package:twibee/screens/channel_discussion_screen.dart';
import 'package:twibee/screens/channel_reactions_screen.dart';
import 'package:twibee/screens/channel_appearance_screen.dart';
import 'package:twibee/screens/channel_admin_logs_screen.dart';
import 'channel_invite_links_screen.dart';
// We'll import other screens (subscribers, admins, invite links) later as we build them.

class ChannelSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const ChannelSettingsScreen({super.key, required this.channel});

  @override
  State<ChannelSettingsScreen> createState() => _ChannelSettingsScreenState();
}

class _ChannelSettingsScreenState extends State<ChannelSettingsScreen> {
  final ChannelService _channelService = ChannelService();
  late Map<String, dynamic> _channel;
  bool _directMessagesEnabled = false;
  bool _wasUpdated = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _channel = Map.from(widget.channel);
    _directMessagesEnabled = _channel['direct_messages_enabled'] ?? false;
  }

  Future<void> _updateAvatar() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      if (mounted) setState(() => _isLoading = true);
      try {
        await _channelService.updateChannel(
          channelId: _channel['id'],
          avatarFile: File(picked.path),
        );
        // Fetch fresh channel data to update UI
        final freshData = await _channelService.getChannel(_channel['id']);
        if (freshData.isNotEmpty && mounted) {
          setState(() {
            _channel = freshData;
            _wasUpdated = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated successfully'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating photo: $e'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _leaveChannel() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Channel'),
        content: const Text('Are you sure you want to leave this channel?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _channelService.leaveChannel(widget.channel['id']);
              if (mounted) {
                // Pop back to home screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteChannel() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Channel'),
        content: const Text('Are you sure you want to delete this channel? This action cannot be undone and will remove all messages for everyone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _channelService.deleteChannel(widget.channel['id']);
              if (mounted) {
                // Pop back to home screen
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // A helper method for building section headers
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: AppColors.orange,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    Color iconColor = AppColors.dark,
    Color textColor = AppColors.dark,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
      title: Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppColors.grey2, fontSize: 13)) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _channel['avatar_url'];
    final name = _channel['name'] ?? 'Channel';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _wasUpdated);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.lightGrey,
        appBar: TwibeeAppBar(
          title: 'Channel Settings',
          onBack: () => Navigator.pop(context, _wasUpdated),
        ),
      body: ListView(
        children: [
          // ─── INFO SECTION ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              clipBehavior: Clip.antiAlias,
              child: Column(
              children: [
                const SizedBox(height: 16),
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _updateAvatar,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: const TextStyle(color: AppColors.orange, fontSize: 36, fontWeight: FontWeight.bold))
                              : null,
                        ),
                        if (_isLoading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 3),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppColors.orange, shape: BoxShape.circle),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildTile(
                  icon: Icons.edit,
                  title: 'Name & Description',
                  subtitle: name,
                  onTap: () async {
                    final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditChannelInfoScreen(channel: _channel)));
                    if (updated == true) {
                      setState(() {
                        _wasUpdated = true;
                        // Fetch latest data to update local UI
                      });
                      final freshData = await _channelService.getChannel(_channel['id']);
                      if (freshData.isNotEmpty && mounted) {
                        setState(() => _channel = freshData);
                      }
                    }
                  },
                ),
                const Divider(height: 1),
                _buildTile(
                  icon: Icons.lock_outline,
                  title: 'Channel Type',
                  subtitle: _channel['is_public'] == true ? 'Public Channel' : 'Private Channel',
                  onTap: () async {
                    final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditChannelTypeScreen(channel: _channel)));
                    if (updated == true) {
                      // refresh screen if needed
                    }
                  },
                ),
                const Divider(height: 1),
                _buildTile(
                  icon: Icons.link,
                  title: 'Invite Links',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelInviteLinksScreen(channel: _channel)));
                  },
                ),
              ],
            ),
            ),
          ),

          // ─── ENGAGEMENT SECTION ───────────────────────────────────────────
          _buildSectionHeader('Engagement'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              clipBehavior: Clip.antiAlias,
              child: Column(
              children: [
                _buildTile(
                  icon: Icons.forum,
                  title: 'Discussion',
                  subtitle: _channel['discussion_group_id'] != null ? 'Linked' : 'Add a group chat for comments',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelDiscussionScreen(channel: _channel)));
                  },
                ),
                const Divider(height: 1),
                _buildTile(
                  icon: Icons.add_reaction,
                  title: 'Reactions',
                  subtitle: 'All Reactions',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelReactionsScreen(channel: _channel)));
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.dark.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mail_outline, color: AppColors.dark, size: 22),
                  ),
                  title: const Text('Direct Messages', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600, fontSize: 16)),
                  subtitle: const Text('Allow non-subscribers to send messages to the channel admins', style: TextStyle(color: AppColors.grey2, fontSize: 13)),
                  value: _directMessagesEnabled,
                  activeThumbColor: AppColors.orange,
                  onChanged: (val) async {
                    setState(() => _directMessagesEnabled = val);
                    try {
                      await _channelService.updateChannelFields(_channel['id'], {'direct_messages_enabled': val});
                    } catch (e) {
                      if (mounted) {
                        setState(() => _directMessagesEnabled = !val);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
                      }
                    }
                  },
                ),
              ],
            ),
            ),
          ),

          // ─── APPEARANCE SECTION ───────────────────────────────────────────
          _buildSectionHeader('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              clipBehavior: Clip.antiAlias,
              child: Column(
              children: [
                _buildTile(
                  icon: Icons.wallpaper,
                  title: 'Appearance',
                  subtitle: 'Channel-specific wallpaper',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelAppearanceScreen(channel: _channel)));
                  },
                ),
              ],
            ),
            ),
          ),

          // ─── MEMBERS SECTION ──────────────────────────────────────────────
          _buildSectionHeader('Management'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              clipBehavior: Clip.antiAlias,
              child: Column(
              children: [
                _buildTile(
                  icon: Icons.admin_panel_settings,
                  title: 'Administrators',
                  subtitle: 'Manage admins and bots',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelAdminsScreen(channel: _channel, isOwner: true)));
                  },
                ),
                const Divider(height: 1),
                _buildTile(
                  icon: Icons.people,
                  title: 'Subscribers',
                  subtitle: 'View and manage subscribers',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelSubscribersScreen(channel: _channel, isAdminOrOwner: true)));
                  },
                ),
                const Divider(height: 1),
                _buildTile(
                  icon: Icons.block,
                  title: 'Removed Users',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelBannedUsersScreen(channel: _channel)));
                  },
                ),
                const Divider(height: 1),
                _buildTile(
                  icon: Icons.history,
                  title: 'Recent Actions',
                  subtitle: 'Admin log',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelAdminLogsScreen(channel: _channel)));
                  },
                ),
              ],
            ),
            ),
          ),

          // ─── DANGER ZONE ──────────────────────────────────────────────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              elevation: 2,
              shadowColor: Colors.black.withValues(alpha: 0.1),
              clipBehavior: Clip.antiAlias,
              child: _buildTile(
              icon: Icons.delete_forever,
              title: _channel['owner_id'] == _channelService.currentUserId ? 'Delete Channel' : 'Leave Channel',
              iconColor: Colors.red,
              textColor: Colors.red,
              trailing: const SizedBox.shrink(),
              onTap: () {
                if (_channel['owner_id'] == _channelService.currentUserId) {
                  _deleteChannel();
                } else {
                  _leaveChannel();
                }
              },
            ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    ));
  }
}

