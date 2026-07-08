import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';
import 'privacy_strict_mode_screen.dart';

class PrivacyAdvancedScreen extends StatelessWidget {
  const PrivacyAdvancedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final blockUnknownMsgs = settings.getSetting('block_unknown_account_msgs', defaultValue: false);
    final protectIpInCalls = settings.getSetting('protect_ip_in_calls', defaultValue: false);
    final disableLinkPreviews = settings.getSetting('disable_link_previews', defaultValue: false);
    final isStrictMode = settings.isStrictModeEnabled;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: const Text('Advanced', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.dark),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: AppColors.green,
                      title: const Text('Block unknown account messages', style: TextStyle(fontSize: 16, color: AppColors.dark)),
                      subtitle: const Text('Automatically block high-volume messages from unknown accounts.', style: TextStyle(fontSize: 13, color: AppColors.grey)),
                      value: blockUnknownMsgs,
                      onChanged: (val) => context.read<SettingsService>().updateSetting('block_unknown_account_msgs', val),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                    const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                    SwitchListTile(
                      activeThumbColor: AppColors.green,
                      title: const Text('Protect IP address in calls', style: TextStyle(fontSize: 16, color: AppColors.dark)),
                      subtitle: const Text('Relay calls through Twibee servers to protect your IP. This will reduce call quality.', style: TextStyle(fontSize: 13, color: AppColors.grey)),
                      value: protectIpInCalls,
                      onChanged: (val) => context.read<SettingsService>().updateSetting('protect_ip_in_calls', val),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                    const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                    SwitchListTile(
                      activeThumbColor: AppColors.green,
                      title: const Text('Disable link previews', style: TextStyle(fontSize: 16, color: AppColors.dark)),
                      subtitle: const Text('Stop generating link preview cards to avoid IP leakage to third-party sites.', style: TextStyle(fontSize: 13, color: AppColors.grey)),
                      value: disableLinkPreviews,
                      onChanged: (val) => context.read<SettingsService>().updateSetting('disable_link_previews', val),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  title: const Text('Strict account settings', style: TextStyle(fontSize: 16, color: AppColors.dark)),
                  subtitle: Text(isStrictMode ? 'On' : 'Off', style: TextStyle(fontSize: 13, color: isStrictMode ? AppColors.orange : AppColors.grey)),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.grey2),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyStrictModeScreen())),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Text(
                  'Strict account settings are extreme protections. Only enable if you believe you\'re at risk of a cyber attack.',
                  style: TextStyle(color: AppColors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

