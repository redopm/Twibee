import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';

class PrivacyStrictModeScreen extends StatefulWidget {
  const PrivacyStrictModeScreen({super.key});

  @override
  State<PrivacyStrictModeScreen> createState() => _PrivacyStrictModeScreenState();
}

class _PrivacyStrictModeScreenState extends State<PrivacyStrictModeScreen> {
  Future<void> _enableStrictMode() async {
    final settings = context.read<SettingsService>();
    // Apply strict settings automatically when enabling
    await settings.updateSettings({
      'privacy_strict_mode': true,
      'privacy_groups': 'My contacts',
      'silence_unknown_callers': true,
      'block_unknown_account_msgs': true,
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Strict account settings enabled. Some settings are now locked.')),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _disableStrictMode() async {
    final settings = context.read<SettingsService>();
    await settings.updateSetting('privacy_strict_mode', false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Strict account settings disabled.')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.watch<SettingsService>().isStrictModeEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: const Text('Strict account settings', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.dark),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.shield_outlined, size: 60, color: AppColors.orange),
            const SizedBox(height: 16),
            const Text(
              'This is a set of extreme protections and should only be used if you believe you are at risk of a cyber attack.',
              style: TextStyle(fontSize: 16, color: AppColors.dark),
            ),
            const SizedBox(height: 24),
            const Text('When enabled, these protections are applied:', style: TextStyle(fontSize: 14, color: AppColors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildBullet('Media and attachments from unknown senders are blocked'),
            _buildBullet('Privacy settings are auto-updated to limit who can call you and add you to groups'),
            _buildBullet('Certain settings are locked while Strict Mode is on and cannot be changed until you disable it'),
            _buildBullet('This will reduce call quality'),
            const Spacer(),
            if (isEnabled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _disableStrictMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Disable Strict Mode', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _enableStrictMode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Next', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.dark))),
        ],
      ),
    );
  }
}

