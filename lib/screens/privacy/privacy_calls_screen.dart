import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';

class PrivacyCallsScreen extends StatelessWidget {
  const PrivacyCallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isSilenced = settings.getSetting('silence_unknown_callers', defaultValue: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: const Text('Calls', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
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
                  title: const Text('Silence unknown callers', style: TextStyle(fontSize: 16, color: AppColors.dark)),
                  value: isSilenced,
                  onChanged: (val) => context.read<SettingsService>().updateSetting('silence_unknown_callers', val),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Text(
                  'Calls from unknown numbers will be silenced. They will still be shown in the Calls tab and in your notifications.',
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

