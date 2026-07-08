import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';
import 'privacy_last_seen_screen.dart';
import 'privacy_basic_screens.dart';
import 'privacy_calls_screen.dart';
import 'privacy_app_lock_screen.dart';
import '../blocked_contacts_screen.dart';
import '../status_privacy_screen.dart';

class PrivacyCheckupScreen extends StatefulWidget {
  const PrivacyCheckupScreen({super.key});

  @override
  State<PrivacyCheckupScreen> createState() => _PrivacyCheckupScreenState();
}

class _PrivacyCheckupScreenState extends State<PrivacyCheckupScreen> {
  int _expandedSection = 0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();

    final sections = [
      _CheckupSection(
        icon: Icons.person_off_outlined,
        title: 'Choose who can contact you',
        color: const Color(0xFF5C6BC0),
        items: [
          _CheckupItem(
            label: 'Groups',
            valueText: settings.getSetting('privacy_groups', defaultValue: 'Everyone'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyGroupsScreen())),
          ),
          _CheckupItem(
            label: 'Silence unknown callers',
            valueText: settings.getSetting('silence_unknown_callers', defaultValue: false) ? 'On' : 'Off',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyCallsScreen())),
          ),
          _CheckupItem(
            label: 'Blocked contacts',
            valueText: 'View',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedContactsScreen())),
          ),
        ],
      ),
      _CheckupSection(
        icon: Icons.person_outline,
        title: 'Control your personal info',
        color: const Color(0xFF26A69A),
        items: [
          _CheckupItem(
            label: 'Profile picture',
            valueText: settings.getSetting('privacy_profile_photo', defaultValue: 'Everyone'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyProfilePictureScreen())),
          ),
          _CheckupItem(
            label: 'Last seen & online',
            valueText: settings.getSetting('privacy_last_seen', defaultValue: 'Everyone'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyLastSeenScreen())),
          ),
          _CheckupItem(
            label: 'Status',
            valueText: settings.getSetting('privacy_status', defaultValue: 'My contacts'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatusPrivacyScreen())),
          ),
        ],
      ),
      _CheckupSection(
        icon: Icons.chat_bubble_outline,
        title: 'Add more privacy to your chats',
        color: AppColors.green,
        items: [
          _CheckupItem(
            label: 'App lock',
            valueText: settings.getSetting('app_lock', defaultValue: false) ? 'On' : 'Off',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyAppLockScreen())),
          ),
          _CheckupItem(
            label: 'Read receipts',
            valueText: settings.getSetting('read_receipts', defaultValue: true) ? 'On' : 'Off',
            onTap: () => Navigator.pop(context), // Goes back to privacy screen
          ),
        ],
      ),
      _CheckupSection(
        icon: Icons.security_outlined,
        title: 'Add more protection to your account',
        color: AppColors.orange,
        items: [
          _CheckupItem(
            label: 'Two-step verification',
            valueText: settings.getSetting('two_step_verification', defaultValue: false) ? 'On' : 'Off',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon'))),
          ),
          _CheckupItem(
            label: 'Strict account settings',
            valueText: settings.isStrictModeEnabled ? 'On' : 'Off',
            onTap: () => Navigator.pop(context), // Goes back to privacy -> Advanced
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: const Text('Privacy checkup', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.dark),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: const Row(
              children: [
                Icon(Icons.verified_user, color: AppColors.green, size: 40),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your privacy matters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark)),
                      Text('Review the settings below to make sure everything is set up the way you want it.', style: TextStyle(fontSize: 13, color: AppColors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final isExpanded = _expandedSection == index;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: section.color.withValues(alpha: 0.15),
                          child: Icon(section.icon, color: section.color),
                        ),
                        title: Text(section.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.dark)),
                        trailing: Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: AppColors.grey),
                        onTap: () => setState(() => _expandedSection = isExpanded ? -1 : index),
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                        ...section.items.map((item) => Column(
                          children: [
                            ListTile(
                              title: Text(item.label, style: const TextStyle(fontSize: 15, color: AppColors.dark)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(item.valueText, style: const TextStyle(color: AppColors.orange, fontSize: 14, fontWeight: FontWeight.w500)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.chevron_right, color: AppColors.grey2, size: 20),
                                ],
                              ),
                              onTap: item.onTap,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                            ),
                            if (section.items.last != item)
                              const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                          ],
                        )),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckupSection {
  final IconData icon;
  final String title;
  final Color color;
  final List<_CheckupItem> items;
  _CheckupSection({required this.icon, required this.title, required this.color, required this.items});
}

class _CheckupItem {
  final String label;
  final String valueText;
  final VoidCallback onTap;
  _CheckupItem({required this.label, required this.valueText, required this.onTap});
}

