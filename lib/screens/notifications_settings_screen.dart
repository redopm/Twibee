import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';
import '../services/settings_service.dart';

class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});

  Widget _buildTrailingText(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(color: AppColors.grey, fontSize: 16)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
      ],
    );
  }

  Future<void> _showSoundPicker(BuildContext context, SettingsService settings, String title, String settingKey) async {
    final sounds = ['Note', 'Default', 'Chord', 'Circles', 'Complete', 'None'];
    final currentValue = settings.getSetting(settingKey, defaultValue: 'Note');

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark)),
              ),
              ...sounds.map((sound) => ListTile(
                title: Text(sound),
                trailing: sound == currentValue ? const Icon(Icons.check, color: AppColors.orange) : null,
                onTap: () => Navigator.pop(context, sound),
              )),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentValue) {
      settings.updateSetting(settingKey, selected);
      // NOTE for FCM Implementation:
      // When Firebase Cloud Messaging (FCM) receives a background notification, 
      // the native Android/iOS handler should query this SharedPreferences key
      // and pass the selected sound file name to the NotificationChannel (Android)
      // or UNNotificationSound (iOS).
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Notifications'),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return ListView(
            children: [
              SettingsGroup(
                header: 'Message notifications',
                children: [
                  SettingsItem(
                    title: 'Show notifications',
                    icon: Icons.notifications,
                    iconBackgroundColor: AppColors.red,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('msg_notif_enabled', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('msg_notif_enabled', v),
                    ),
                  ),
                  SettingsItem(
                    title: 'Sound',
                    icon: Icons.audiotrack,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(settings.getSetting('msg_notif_sound', defaultValue: 'Note')),
                    onTap: () => _showSoundPicker(context, settings, 'Message Sound', 'msg_notif_sound'),
                  ),
                  SettingsItem(
                    title: 'Reaction notifications',
                    icon: Icons.emoji_emotions,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('msg_notif_reactions', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('msg_notif_reactions', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              
              SettingsGroup(
                header: 'Group notifications',
                children: [
                  SettingsItem(
                    title: 'Show notifications',
                    icon: Icons.notifications,
                    iconBackgroundColor: AppColors.red,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('group_notif_enabled', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('group_notif_enabled', v),
                    ),
                  ),
                  SettingsItem(
                    title: 'Sound',
                    icon: Icons.audiotrack,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(settings.getSetting('group_notif_sound', defaultValue: 'Note')),
                    onTap: () => _showSoundPicker(context, settings, 'Group Sound', 'group_notif_sound'),
                  ),
                  SettingsItem(
                    title: 'Reaction notifications',
                    icon: Icons.emoji_emotions,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('group_notif_reactions', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('group_notif_reactions', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              
              SettingsGroup(
                header: 'Status notifications',
                children: [
                  SettingsItem(
                    title: 'Show notifications',
                    icon: Icons.notifications,
                    iconBackgroundColor: AppColors.red,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('status_notif_enabled', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('status_notif_enabled', v),
                    ),
                  ),
                  SettingsItem(
                    title: 'Sound',
                    icon: Icons.audiotrack,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(settings.getSetting('status_notif_sound', defaultValue: 'Note')),
                    onTap: () => _showSoundPicker(context, settings, 'Status Sound', 'status_notif_sound'),
                  ),
                  SettingsItem(
                    title: 'Reaction notifications',
                    icon: Icons.emoji_emotions,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('status_notif_reactions', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('status_notif_reactions', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              
              SettingsGroup(
                footer: 'Get occasional reminders about messages, calls or status updates you haven\'t seen.',
                children: [
                  SettingsItem(
                    title: 'Reminders',
                    icon: Icons.calendar_today,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('notif_reminders', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('notif_reminders', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              
              SettingsGroup(
                header: 'Home screen notifications',
                children: [
                  SettingsItem(
                    title: 'App icon badge',
                    subtitle: 'Clears when you view all messages and calls',
                    icon: Icons.mark_chat_unread,
                    iconBackgroundColor: AppColors.red,
                    showDivider: false,
                    onTap: () {
                      // Handled by device OS + flutter_app_badger in a real app
                    },
                  ),
                ],
              ),
              
              SettingsGroup(
                children: [
                  SettingsItem(
                    title: 'In-app notifications',
                    subtitle: 'Banners, Sounds, Vibrate',
                    icon: Icons.smartphone,
                    iconBackgroundColor: AppColors.orange,
                    showDivider: false,
                    onTap: () {
                      // Would open sub-settings
                    },
                  ),
                ],
              ),
              
              SettingsGroup(
                footer: 'Preview message text inside new message notifications.',
                children: [
                  SettingsItem(
                    title: 'Show preview',
                    icon: Icons.visibility,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('notif_show_preview', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('notif_show_preview', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              
              SettingsGroup(
                header: 'Calls',
                children: [
                  SettingsItem(
                    title: 'Ringtone',
                    icon: Icons.library_music,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(settings.getSetting('call_ringtone', defaultValue: 'Default')),
                    onTap: () => _showSoundPicker(context, settings, 'Call Ringtone', 'call_ringtone'),
                  ),
                  SettingsItem(
                    title: 'Vibrate',
                    icon: Icons.vibration,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('call_vibrate', defaultValue: true),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('call_vibrate', v),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              
              SettingsGroup(
                footer: 'Reset all notification settings, including custom notification settings for your chats.',
                children: [
                  SettingsItem(
                    title: 'Reset notification settings',
                    icon: Icons.restore,
                    isDestructive: true,
                    showDivider: false,
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reset settings?'),
                          content: const Text('Are you sure you want to reset all notification settings?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                            TextButton(
                              onPressed: () {
                                settings.updateSetting('msg_notif_enabled', true);
                                settings.updateSetting('msg_notif_sound', 'Note');
                                settings.updateSetting('msg_notif_reactions', true);
                                settings.updateSetting('group_notif_enabled', true);
                                settings.updateSetting('group_notif_sound', 'Note');
                                settings.updateSetting('group_notif_reactions', true);
                                settings.updateSetting('status_notif_enabled', true);
                                settings.updateSetting('status_notif_sound', 'Note');
                                settings.updateSetting('status_notif_reactions', true);
                                settings.updateSetting('notif_reminders', true);
                                settings.updateSetting('notif_show_preview', true);
                                Navigator.pop(ctx);
                              },
                              child: const Text('Reset', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

