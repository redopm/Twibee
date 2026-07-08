import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/channel_service.dart';

class ChannelAdminPermissionsScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  final Map<String, dynamic> adminUser; // the profile + admin data

  const ChannelAdminPermissionsScreen({
    super.key,
    required this.channel,
    required this.adminUser,
  });

  @override
  State<ChannelAdminPermissionsScreen> createState() => _ChannelAdminPermissionsScreenState();
}

class _ChannelAdminPermissionsScreenState extends State<ChannelAdminPermissionsScreen> {
  final ChannelService _channelService = ChannelService();
  bool _isLoading = false;

  late Map<String, dynamic> _permissions;
  late String _adminId;
  late String _adminName;

  @override
  void initState() {
    super.initState();
    _adminId = widget.adminUser['user_id'] ?? widget.adminUser['admin_id'];
    
    final profile = widget.adminUser['profiles'] ?? widget.adminUser;
    _adminName = profile['name'] ?? 'Admin';

    final dynamic rawPerms = widget.adminUser['permissions'];
    if (rawPerms is Map) {
      _permissions = Map<String, dynamic>.from(rawPerms);
    } else {
      _permissions = {
        'change_info': false,
        'delete_messages': false,
        'ban_users': false,
        'invite_via_link': false,
        'pin_messages': false,
        'post_messages': false,
        'add_new_admins': false,
        'remain_anonymous': false,
      };
    }
  }

  Future<void> _savePermissions() async {
    setState(() => _isLoading = true);
    try {
      await _channelService.updateAdminPermissions(
        widget.channel['id'],
        _adminId,
        _permissions,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permissions updated'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _dismissAdmin() async {
    setState(() => _isLoading = true);
    try {
      await _channelService.removeAdmin(widget.channel['id'], _adminId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Admin dismissed'), backgroundColor: Colors.red));
        Navigator.pop(context, 'dismissed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSwitch(String key, String title, String subtitle) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.grey2)),
      value: _permissions[key] == true,
      activeThumbColor: AppColors.orange,
      onChanged: (val) {
        setState(() {
          _permissions[key] = val;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: _adminName,
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2))))
              : IconButton(
                  icon: const Icon(Icons.check, color: AppColors.orange),
                  onPressed: _savePermissions,
                ),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text('WHAT CAN THIS ADMIN DO?', style: TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          Container(
            color: AppColors.white,
            child: Column(
              children: [
                _buildSwitch('change_info', 'Change Channel Info', 'Edit name, photo or description'),
                const Divider(height: 1),
                _buildSwitch('post_messages', 'Post Messages', 'Send new messages to the channel'),
                const Divider(height: 1),
                _buildSwitch('delete_messages', 'Delete Messages', 'Delete messages from others'),
                const Divider(height: 1),
                _buildSwitch('ban_users', 'Ban Users', 'Remove or ban subscribers'),
                const Divider(height: 1),
                _buildSwitch('invite_via_link', 'Invite Users via Link', 'Create and manage invite links'),
                const Divider(height: 1),
                _buildSwitch('pin_messages', 'Pin Messages', 'Pin important messages at the top'),
                const Divider(height: 1),
                _buildSwitch('add_new_admins', 'Add New Admins', 'Promote subscribers to admins'),
                const Divider(height: 1),
                _buildSwitch('remain_anonymous', 'Remain Anonymous', 'Hide presence in admin list for subscribers'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            color: AppColors.white,
            child: ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.red),
              title: const Text('Dismiss Admin', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () {
                // Confirm dialog
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Dismiss Admin'),
                    content: const Text('Are you sure you want to remove all admin rights from this user?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      TextButton(onPressed: () { Navigator.pop(ctx); _dismissAdmin(); }, child: const Text('Dismiss', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

