import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';
import '../contact_selection_screen.dart';

class PrivacyLastSeenScreen extends StatefulWidget {
  const PrivacyLastSeenScreen({super.key});

  @override
  State<PrivacyLastSeenScreen> createState() => _PrivacyLastSeenScreenState();
}

class _PrivacyLastSeenScreenState extends State<PrivacyLastSeenScreen> {
  late String _lastSeenValue;
  late String _onlineValue;
  late List<String> _excludedContacts;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _lastSeenValue = settings.getSetting('privacy_last_seen', defaultValue: 'Everyone');
    _onlineValue = settings.getSetting('privacy_online', defaultValue: 'Everyone');
    _excludedContacts = List<String>.from(settings.getSetting('privacy_last_seen_excluded', defaultValue: []));
  }

  Future<void> _handleLastSeenTap(String value, {bool isExcept = false}) async {
    final settings = context.read<SettingsService>();
    
    if (isExcept) {
      final selectedIds = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => ContactSelectionScreen(
            title: 'Hide from',
            subtitle: 'excluded',
            initialSelectedIds: _excludedContacts,
          ),
        ),
      );

      if (selectedIds != null) {
        setState(() {
          _lastSeenValue = value;
          _excludedContacts = selectedIds;
        });
        settings.updateSetting('privacy_last_seen', value);
        settings.updateSetting('privacy_last_seen_excluded', selectedIds);
      }
    } else {
      setState(() => _lastSeenValue = value);
      settings.updateSetting('privacy_last_seen', value);
    }
  }

  void _handleOnlineTap(String value) {
    final settings = context.read<SettingsService>();
    setState(() => _onlineValue = value);
    settings.updateSetting('privacy_online', value);
  }

  Widget _buildOptionRow({
    required String label, 
    required String value, 
    required String groupValue, 
    required VoidCallback onTap,
    bool isExcept = false,
  }) {
    final isSelected = groupValue == value;
    Widget? subtitleWidget;
    if (isExcept && isSelected) {
      subtitleWidget = Text('${_excludedContacts.length} contacts excluded', style: const TextStyle(color: AppColors.grey, fontSize: 13));
    }

    Widget? trailingWidget;
    if (isSelected) {
      trailingWidget = const Icon(Icons.check, color: AppColors.green);
    } else if (isExcept) {
      trailingWidget = const Icon(Icons.chevron_right, color: AppColors.grey2);
    }

    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 16, color: AppColors.dark)),
      subtitle: subtitleWidget,
      trailing: trailingWidget,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: const Text('Last seen & online', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
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
              const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text('Who can see my Last Seen', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _buildOptionRow(label: 'Everyone', value: 'Everyone', groupValue: _lastSeenValue, onTap: () => _handleLastSeenTap('Everyone')),
                    const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                    _buildOptionRow(label: 'My contacts', value: 'My contacts', groupValue: _lastSeenValue, onTap: () => _handleLastSeenTap('My contacts')),
                    const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                    _buildOptionRow(label: 'My contacts except...', value: 'My contacts except...', groupValue: _lastSeenValue, isExcept: true, onTap: () => _handleLastSeenTap('My contacts except...', isExcept: true)),
                    const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                    _buildOptionRow(label: 'Nobody', value: 'Nobody', groupValue: _lastSeenValue, onTap: () => _handleLastSeenTap('Nobody')),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              const Padding(
                padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text('Who can see when I\'m online', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    _buildOptionRow(label: 'Everyone', value: 'Everyone', groupValue: _onlineValue, onTap: () => _handleOnlineTap('Everyone')),
                    const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                    _buildOptionRow(label: 'Same as last seen', value: 'Same as last seen', groupValue: _onlineValue, onTap: () => _handleOnlineTap('Same as last seen')),
                  ],
                ),
              ),
              
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                child: Text(
                  'If you don\'t share when you were last seen or online, you won\'t be able to see when other people were last seen or online.',
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

