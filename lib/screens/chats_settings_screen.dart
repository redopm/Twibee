import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';
import '../services/settings_service.dart';
import 'chat_backup_screen.dart';
import 'chat_theme_screen.dart';

class ChatsSettingsScreen extends StatefulWidget {
  const ChatsSettingsScreen({super.key});

  @override
  State<ChatsSettingsScreen> createState() => _ChatsSettingsScreenState();
}

class _ChatsSettingsScreenState extends State<ChatsSettingsScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  bool _isBusy = false;

  Future<void> _confirmAction(
      BuildContext context, String title, String body, Future<void> Function() onConfirm,
      {Color confirmColor = Colors.red}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(title,
                style: TextStyle(color: confirmColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (result == true) await onConfirm();
  }

  // ── Archive All Chats ──
  Future<void> _archiveAllChats() async {
    setState(() => _isBusy = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Archive all chats where user is a participant
      final chatIds = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', userId);

      if (chatIds.isNotEmpty) {
        final ids = (chatIds as List).map((e) => e['chat_id'] as String).toList();
        await _supabase
            .from('chat_participants')
            .update({'is_archived': true})
            .eq('user_id', userId)
            .inFilter('chat_id', ids);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All chats archived'),
              backgroundColor: Colors.green,
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── Clear All Messages ──
  Future<void> _clearAllChats() async {
    setState(() => _isBusy = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Get all chat IDs where user participates
      final chatIds = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', userId);

      if (chatIds.isNotEmpty) {
        final ids = (chatIds as List).map((e) => e['chat_id'] as String).toList();
        // Update cleared_at to hide messages locally instead of deleting them globally
        await _supabase
            .from('chat_participants')
            .update({'cleared_at': DateTime.now().toUtc().toIso8601String()})
            .eq('user_id', userId)
            .inFilter('chat_id', ids);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All chat messages cleared'),
              backgroundColor: Colors.green,
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── Delete All Chats ──
  Future<void> _deleteAllChats() async {
    setState(() => _isBusy = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Remove user from all chats (cascades messages via RLS)
      await _supabase
          .from('chat_participants')
          .delete()
          .eq('user_id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('All chats deleted'),
              backgroundColor: Colors.green,
            ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  // ── Transfer via QR ──
  void _showTransferQR() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final qrData = 'Twibee://transfer?uid=$userId&ts=$ts';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            const Text('Transfer Chat History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Scan this QR code on your new device\nto begin the transfer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 20)
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: AppColors.white,
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.circle, color: AppColors.orange),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.circle,
                    color: AppColors.dark),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This QR code expires in 5 minutes.',
              style: TextStyle(color: AppColors.grey, fontSize: 12),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.lightGrey,
          appBar: const TwibeeAppBar(title: 'Chats'),
          body: Consumer<SettingsService>(
            builder: (context, settings, _) {
              return ListView(
                children: [
                  // ── Theme ──
                  SettingsGroup(
                    footer: 'Changes the appearance of the entire app.',
                    children: [
                      SettingsItem(
                        title: 'Default chat theme',
                        icon: Icons.color_lens,
                        iconBackgroundColor: AppColors.orange,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                settings.getSetting('chat_theme',
                                    defaultValue: 'Default'),
                                style: const TextStyle(
                                    color: AppColors.grey, fontSize: 14)),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_forward_ios,
                                color: AppColors.grey, size: 16),
                          ],
                        ),
                        showDivider: false,
                        onTap: () => Navigator.push(context,
                            MaterialPageRoute(
                                builder: (_) => const ChatThemeScreen())),
                      ),
                    ],
                  ),

                  // ── Animations ──
                  SettingsGroup(
                    footer:
                        'Choose whether emoji, stickers and GIFs move automatically.',
                    children: [
                      SettingsItem(
                        title: 'Animations',
                        icon: Icons.animation,
                        iconBackgroundColor: AppColors.orange,
                        trailing: CupertinoSwitch(
                          value: settings.getSetting('chat_animations',
                              defaultValue: true),
                          activeTrackColor: AppColors.orange,
                          onChanged: (v) =>
                              settings.updateSetting('chat_animations', v),
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),

                  // ── Save to Photos ──
                  SettingsGroup(
                    footer:
                        'Automatically save photos and videos you receive to Photos.',
                    children: [
                      SettingsItem(
                        title: 'Save to Photos',
                        icon: Icons.save_alt,
                        iconBackgroundColor: AppColors.orange,
                        trailing: CupertinoSwitch(
                          value: settings.getSetting('save_to_photos',
                              defaultValue: false),
                          activeTrackColor: AppColors.orange,
                          onChanged: (v) =>
                              settings.updateSetting('save_to_photos', v),
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),

                  // ── Backup & Export ──
                  SettingsGroup(
                    children: [
                      SettingsItem(
                        title: 'Chat backup',
                        icon: Icons.cloud_upload,
                        iconBackgroundColor: AppColors.orange,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ChatBackupScreen())),
                      ),
                      SettingsItem(
                        title: 'Export chat',
                        icon: Icons.import_export,
                        iconBackgroundColor: AppColors.orange,
                        showDivider: false,
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Open a chat and tap ··· → Export chat'))),
                      ),
                    ],
                  ),

                  // ── Voice Transcripts ──
                  SettingsGroup(
                    footer: 'Automatically transcribe your voice messages.',
                    children: [
                      SettingsItem(
                        title: 'Voice message transcripts',
                        icon: Icons.mic,
                        iconBackgroundColor: AppColors.orange,
                        trailing: CupertinoSwitch(
                          value: settings.getSetting('voice_transcripts',
                              defaultValue: false),
                          activeTrackColor: AppColors.orange,
                          onChanged: (v) =>
                              settings.updateSetting('voice_transcripts', v),
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),

                  // ── Keep Archived ──
                  SettingsGroup(
                    footer:
                        'Archived chats will remain archived when you receive a new message.',
                    children: [
                      SettingsItem(
                        title: 'Keep chats archived',
                        icon: Icons.archive,
                        iconBackgroundColor: AppColors.orange,
                        trailing: CupertinoSwitch(
                          value: settings.getSetting('keep_chats_archived',
                              defaultValue: true),
                          activeTrackColor: AppColors.orange,
                          onChanged: (v) =>
                              settings.updateSetting('keep_chats_archived', v),
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),

                  // ── Transfer ──
                  SettingsGroup(
                    header: 'Transfer chat history',
                    footer: 'Transfer your chats to another phone.',
                    children: [
                      SettingsItem(
                        title: 'Transfer chat history',
                        icon: Icons.phonelink_setup,
                        iconBackgroundColor: AppColors.orange,
                        titleColor: AppColors.dark,
                        showDivider: false,
                        onTap: _showTransferQR,
                      ),
                    ],
                  ),

                  // ── Destructive Actions (REAL DB OPERATIONS) ──
                  SettingsGroup(
                    children: [
                      SettingsItem(
                        title: 'Archive all chats',
                        icon: Icons.archive_outlined,
                        iconBackgroundColor: AppColors.orange,
                        titleColor: AppColors.dark,
                        onTap: () => _confirmAction(
                          context,
                          'Archive all chats',
                          'This will archive all your chats. You can unarchive them anytime from the chats list.',
                          _archiveAllChats,
                          confirmColor: AppColors.orange,
                        ),
                      ),
                      SettingsItem(
                        title: 'Clear all chats',
                        icon: Icons.clear_all,
                        isDestructive: true,
                        onTap: () => _confirmAction(
                          context,
                          'Clear all chats',
                          'This will permanently delete all messages in all your chats. This action CANNOT be undone.',
                          _clearAllChats,
                        ),
                      ),
                      SettingsItem(
                        title: 'Delete all chats',
                        icon: Icons.delete_forever,
                        isDestructive: true,
                        showDivider: false,
                        onTap: () => _confirmAction(
                          context,
                          'Delete all chats',
                          'This will permanently remove you from all chats and delete all messages. This CANNOT be undone.',
                          _deleteAllChats,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          ),
        ),
        // Loading overlay
        if (_isBusy)
          Container(
            color: Colors.black38,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.orange),
            ),
          ),
      ],
    );
  }
}

