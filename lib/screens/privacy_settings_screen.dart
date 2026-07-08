import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';
import '../services/settings_service.dart';
import 'blocked_contacts_screen.dart';
import 'status_privacy_screen.dart';
import 'privacy/privacy_last_seen_screen.dart';
import 'privacy/privacy_basic_screens.dart';
import 'privacy/privacy_calls_screen.dart';
import 'privacy/privacy_app_lock_screen.dart';
import 'privacy/privacy_chat_lock_screen.dart';
import 'privacy/privacy_advanced_screen.dart';
import 'privacy/privacy_checkup_screen.dart';

class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Privacy'),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          final strict = settings.isStrictModeEnabled;

          return ListView(
            children: [
              // -- Privacy Checkup Banner --
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyCheckupScreen())),
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user_outlined, color: AppColors.orange),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Privacy checkup', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 15)),
                            Text('Review your important privacy settings', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: AppColors.orange),
                    ],
                  ),
                ),
              ),

              // -- Group 1: Visibility settings --
              SettingsGroup(
                children: [
                  _privacyNavItem(context,
                    title: 'Last seen & online',
                    trailing: settings.getSetting('privacy_last_seen', defaultValue: 'Everyone'),
                    lockedByStrict: strict,
                    destination: const PrivacyLastSeenScreen(),
                    icon: Icons.access_time_filled,
                    iconBackgroundColor: AppColors.orange,
                  ),
                  _privacyNavItem(context,
                    title: 'Profile picture',
                    trailing: settings.getSetting('privacy_profile_photo', defaultValue: 'Everyone'),
                    lockedByStrict: false,
                    destination: const PrivacyProfilePictureScreen(),
                    icon: Icons.photo_camera,
                    iconBackgroundColor: AppColors.orange,
                  ),
                  _privacyNavItem(context,
                    title: 'About',
                    trailing: settings.getSetting('privacy_about', defaultValue: 'Everyone'),
                    lockedByStrict: false,
                    destination: const PrivacyAboutScreen(),
                    icon: Icons.info_outline,
                    iconBackgroundColor: AppColors.orange,
                  ),
                  _privacyNavItem(context,
                    title: 'Links',
                    trailing: settings.getSetting('privacy_links', defaultValue: 'Everyone'),
                    lockedByStrict: false,
                    destination: const PrivacyLinksScreen(),
                    icon: Icons.link,
                    iconBackgroundColor: AppColors.orange,
                  ),
                  _privacyNavItem(context,
                    title: 'Groups',
                    trailing: settings.getSetting('privacy_groups', defaultValue: 'Everyone'),
                    lockedByStrict: strict,
                    destination: const PrivacyGroupsScreen(),
                    icon: Icons.group,
                    iconBackgroundColor: AppColors.orange,
                  ),
                  _privacyNavItem(context,
                    title: 'Status',
                    trailing: '',
                    lockedByStrict: false,
                    destination: const StatusPrivacyScreen(),
                    icon: Icons.history,
                    iconBackgroundColor: AppColors.red,
                    showDivider: false,
                  ),
                ],
              ),

              // -- Group 2: Live location --
              SettingsGroup(
                footer: 'You are not sharing live location in any chats.',
                children: [
                  SettingsItem(
                    title: 'Live location',
                    icon: Icons.location_on_outlined,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _trailingText('None'),
                    showDivider: false,
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No active live location shares'))),
                  ),
                ],
              ),

              // -- Group 3: Calls, Blocked, Contacts --
              SettingsGroup(
                children: [
                  _privacyNavItem(context,
                    title: 'Calls',
                    trailing: settings.getSetting('silence_unknown_callers', defaultValue: false) ? 'Silencing unknown' : '',
                    lockedByStrict: strict,
                    destination: const PrivacyCallsScreen(),
                    icon: Icons.call,
                    iconBackgroundColor: AppColors.orange,
                  ),
                  SettingsItem(
                    title: 'Blocked Contacts',
                    icon: Icons.block,
                    iconBackgroundColor: AppColors.red,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BlockedContactsScreen())),
                  ),
                  SettingsItem(
                    title: 'Contacts',
                    icon: Icons.contacts,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _trailingText(settings.getSetting('privacy_contacts', defaultValue: 'Everyone')),
                    showDivider: false,
                    onTap: () {
                      _showBottomSelector(
                        context: context,
                        title: 'Sync contacts',
                        settingKey: 'privacy_contacts',
                        options: ['Everyone', 'My contacts', 'Nobody'],
                        settings: settings,
                      );
                    },
                  ),
                ],
              ),

              // -- Group 4: Disappearing messages --
              SettingsGroup(
                header: 'Disappearing messages',
                footer: 'Start new chats with disappearing messages set to your timer.',
                children: [
                  SettingsItem(
                    title: 'Default message timer',
                    icon: Icons.timer,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _trailingText(settings.getSetting('default_message_timer', defaultValue: 'Off')),
                    showDivider: false,
                    onTap: () {
                      _showBottomSelector(
                        context: context,
                        title: 'Message timer',
                        settingKey: 'default_message_timer',
                        options: ['Off', '24 hours', '7 days', '90 days'],
                        settings: settings,
                      );
                    },
                  ),
                ],
              ),

              // -- Group 5: Read receipts --
              SettingsGroup(
                footer: 'If you turn off read receipts, you won\'t be able to see read receipts from other people. Read receipts are always sent for group chats.',
                children: [
                  SettingsItem(
                    title: 'Read receipts',
                    icon: Icons.done_all,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('read_receipts', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('read_receipts', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),

              // -- Group 6: App lock --
              SettingsGroup(
                footer: 'Require Face ID / Fingerprint to unlock Twibee.',
                children: [
                  _privacyNavItem(context,
                    title: 'App lock',
                    trailing: settings.getSetting('app_lock', defaultValue: false) ? 'On' : 'Off',
                    lockedByStrict: false,
                    destination: const PrivacyAppLockScreen(),
                    icon: Icons.lock,
                    iconBackgroundColor: AppColors.orange,
                    showDivider: false,
                  ),
                ],
              ),

              // -- Group 7: Chat lock --
              SettingsGroup(
                footer: 'Lock and hide individual chats behind Face ID.',
                children: [
                  _privacyNavItem(context,
                    title: 'Chat lock',
                    trailing: '',
                    lockedByStrict: false,
                    destination: const PrivacyChatLockScreen(),
                    icon: Icons.lock_outline,
                    iconBackgroundColor: AppColors.orange,
                    showDivider: false,
                  ),
                ],
              ),

              // -- Group 8: Camera effects --
              SettingsGroup(
                footer: 'Use effects in the camera and video calls.',
                children: [
                  SettingsItem(
                    title: 'Allow camera effects',
                    icon: Icons.auto_awesome,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('allow_camera_effects', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('allow_camera_effects', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),

              // -- Group 9: Advanced --
              SettingsGroup(
                footer: 'Manage IP address, unknown messages, and strict mode.',
                children: [
                  _privacyNavItem(context,
                    title: 'Advanced',
                    trailing: '',
                    lockedByStrict: false,
                    destination: const PrivacyAdvancedScreen(),
                    icon: Icons.shield,
                    iconBackgroundColor: AppColors.orange,
                    showDivider: false,
                  ),
                ],
              ),

              if (strict)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Icon(Icons.lock, color: AppColors.orange, size: 14),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Some settings are locked by Strict Mode. Go to Advanced → Strict account settings to disable.',
                          style: TextStyle(color: AppColors.orange, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _trailingText(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (text.isNotEmpty)
          Text(text, style: const TextStyle(color: AppColors.grey, fontSize: 16)),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios, color: AppColors.grey, size: 16),
      ],
    );
  }

  Widget _privacyNavItem(
    BuildContext context, {
    required String title,
    required String trailing,
    required bool lockedByStrict,
    required Widget destination,
    required IconData icon,
    required Color iconBackgroundColor,
    bool showDivider = true,
  }) {
    if (lockedByStrict) {
      return SettingsItem(
        title: title,
        icon: icon,
        iconBackgroundColor: iconBackgroundColor,
        showDivider: showDivider,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing.isNotEmpty)
              Text(trailing, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
            const SizedBox(width: 6),
            const Icon(Icons.lock, size: 16, color: AppColors.orange),
          ],
        ),
        onTap: null, // unclickable when locked
      );
    }

    return SettingsItem(
      title: title,
      icon: icon,
      iconBackgroundColor: iconBackgroundColor,
      showDivider: showDivider,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing.isNotEmpty)
            Text(trailing, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_forward_ios, color: AppColors.grey, size: 16),
        ],
      ),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
    );
  }

  Future<void> _showBottomSelector({
    required BuildContext context,
    required String title,
    required String settingKey,
    required List<String> options,
    required SettingsService settings,
  }) async {
    final currentValue = settings.getSetting(settingKey, defaultValue: options.first);
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark)),
            ),
            ...options.map((option) => ListTile(
              title: Text(option),
              trailing: option == currentValue ? const Icon(Icons.check, color: AppColors.orange) : null,
              onTap: () => Navigator.pop(ctx, option),
            )),
          ],
        ),
      ),
    );
    if (selected != null && selected != currentValue) {
      settings.updateSetting(settingKey, selected);
    }
  }
}

