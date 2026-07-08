import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';

class PrivacyAppLockScreen extends StatefulWidget {
  const PrivacyAppLockScreen({super.key});

  @override
  State<PrivacyAppLockScreen> createState() => _PrivacyAppLockScreenState();
}

class _PrivacyAppLockScreenState extends State<PrivacyAppLockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isToggling = false;

  Future<void> _toggleAppLock(BuildContext context, bool currentValue) async {
    if (_isToggling) return;
    setState(() => _isToggling = true);
    final settings = context.read<SettingsService>();
    try {
      if (!currentValue) {
        final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
        if (!canCheck) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrics not available on this device.')));
          return;
        }

        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to enable App Lock',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );

        if (didAuthenticate && mounted) {
          settings.updateSetting('app_lock', true);
        }
      } else {
        final didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to disable App Lock',
          options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
        );
        if (didAuthenticate && mounted) {
          settings.updateSetting('app_lock', false);
        }
      }
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  Widget _buildTimingOption(String label, String value, String currentValue, SettingsService settings) {
    final isSelected = currentValue == value;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          title: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.dark)),
          trailing: isSelected ? const Icon(Icons.check, color: AppColors.green) : null,
          onTap: () => settings.updateSetting('app_lock_timing', value),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
        ),
        const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isLocked = settings.getSetting('app_lock', defaultValue: false);
    final timing = settings.getSetting('app_lock_timing', defaultValue: 'Immediately');

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: const Text('App lock', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
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
                child: SwitchListTile(
                activeThumbColor: AppColors.green,
                  title: const Text('Require Face ID', style: TextStyle(fontSize: 16, color: AppColors.dark)),
                  value: isLocked,
                  onChanged: (val) => _toggleAppLock(context, isLocked),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Text(
                  'When enabled, you\'ll need to use Face ID to unlock Twibee. You can still reply to messages from notifications and answer calls if Twibee is locked.',
                  style: TextStyle(color: AppColors.grey, fontSize: 13),
                ),
              ),
              if (isLocked) ...[
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _buildTimingOption('Immediately', 'Immediately', timing, settings),
                      _buildTimingOption('After 1 minute', 'After 1 minute', timing, settings),
                      _buildTimingOption('After 15 minutes', 'After 15 minutes', timing, settings),
                      _buildTimingOption('After 1 hour', 'After 1 hour', timing, settings),
                    ],
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

