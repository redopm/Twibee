import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_backup_pin_screen.dart';

class ChatBackupScreen extends StatefulWidget {
  const ChatBackupScreen({super.key});

  @override
  State<ChatBackupScreen> createState() => _ChatBackupScreenState();
}

class _ChatBackupScreenState extends State<ChatBackupScreen> {
  bool _isBackingUp = false;
  double _progress = 0.0;

  Future<void> _performBackup() async {
    setState(() {
      _isBackingUp = true;
      _progress = 0.1;
    });

    try {
      final chatService = context.read<ChatService>();
      final settingsService = context.read<SettingsService>();
      
      // Simulate some progress for UI
      for (int i = 2; i <= 8; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) setState(() => _progress = i / 10.0);
      }

      await chatService.generateAndUploadBackup();

      if (mounted) {
        setState(() => _progress = 1.0);
        settingsService.updateSetting('last_backup_date', DateTime.now().toUtc().toIso8601String());
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup successful! Zip uploaded to Supabase Storage.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBackingUp = false;
          _progress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Chat backup'),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          final lastBackupRaw = settings.getSetting('last_backup_date', defaultValue: '');
          String lastBackupText = 'Never';
          if (lastBackupRaw.isNotEmpty) {
            final dt = DateTime.tryParse(lastBackupRaw)?.toLocal();
            if (dt != null) {
              lastBackupText = '${dt.day}/${dt.month}/${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Icon(Icons.cloud_upload_outlined, size: 64, color: AppColors.orange),
              const SizedBox(height: 16),
              const Text(
                'Back up your messages and media to Supabase Storage. You can restore them when you reinstall Twibee.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Last backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('Local: $lastBackupText', style: const TextStyle(color: AppColors.grey)),
                    Text('Supabase: $lastBackupText', style: const TextStyle(color: AppColors.grey)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isBackingUp ? null : _performBackup,
                        child: _isBackingUp 
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20, 
                                    height: 20, 
                                    child: CircularProgressIndicator(value: _progress > 0 ? _progress : null, color: AppColors.white, strokeWidth: 2)
                                  ),
                                  const SizedBox(width: 12),
                                  const Text('Backing up...'),
                                ],
                              )
                            : const Text('Back up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text('End-to-end encrypted backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 4),
              const Text('Turn on to protect your backup with a password or a 64-digit encryption key.', style: TextStyle(color: AppColors.grey)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('End-to-end encrypted backup'),
                subtitle: const Text('Off'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
                onTap: () {
                  final user = Supabase.instance.client.auth.currentUser;
                  if (user != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatBackupPinScreen(
                          isSettingUp: true,
                          userId: user.id,
                          onSuccess: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('E2EE PIN updated successfully!')),
                            );
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

