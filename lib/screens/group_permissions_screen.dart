import 'package:flutter/material.dart';
import '../theme.dart';

class GroupPermissionsScreen extends StatefulWidget {
  final Map<String, bool> currentPermissions;
  
  const GroupPermissionsScreen({super.key, required this.currentPermissions});

  @override
  State<GroupPermissionsScreen> createState() => _GroupPermissionsScreenState();
}

class _GroupPermissionsScreenState extends State<GroupPermissionsScreen> {
  late Map<String, bool> _permissions;

  @override
  void initState() {
    super.initState();
    _permissions = Map.from(widget.currentPermissions);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context, _permissions);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: TwibeeAppBar(
          title: 'Group permissions',
          onBack: () => Navigator.pop(context, _permissions),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Text('Members can', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    'Edit group settings',
                    'edit_group_settings',
                    Icons.edit,
                    subtitle: 'This includes the group name, icon, description, disappearing message timer, advanced chat privacy, and the ability to pin, keep or unkeep messages.',
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSwitchTile(
                    'Send new messages',
                    'send_messages',
                    Icons.campaign,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSwitchTile(
                    'Add other members',
                    'add_members',
                    Icons.person_add,
                  ),
                  const Divider(height: 1, indent: 56),
                  _buildSwitchTile(
                    'Invite via link or QR code',
                    'invite_via_link',
                    Icons.link,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12.0, bottom: 24.0, left: 4.0, right: 4.0),
              child: Text(
                'Turning off these settings means that only group admins can perform this action.',
                style: TextStyle(color: AppColors.grey, fontSize: 13),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0, left: 4.0),
              child: Text('Admins can', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildSwitchTile(
                'Approve new members',
                'approve_members',
                Icons.person_add_alt_1,
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 12.0, bottom: 24.0, left: 4.0, right: 4.0),
              child: Text(
                'When turned on, admins must approve anyone who wants to join this group.',
                style: TextStyle(color: AppColors.grey, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String key, IconData icon, {String? subtitle, bool enabled = true}) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.normal)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 13)) : null,
      secondary: Icon(icon, color: AppColors.dark, size: 24),
      value: _permissions[key] ?? false,
      activeThumbColor: AppColors.white,
      activeTrackColor: AppColors.orange,
      inactiveThumbColor: AppColors.white,
      inactiveTrackColor: AppColors.grey2,
      onChanged: enabled
          ? (value) {
              setState(() {
                _permissions[key] = value;
              });
            }
          : null,
    );
  }
}

