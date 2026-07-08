import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../theme.dart';
import '../../services/settings_service.dart';
import '../contact_selection_screen.dart';

class PrivacyOption {
  final String label;
  final String value;
  final bool isExceptOption;

  PrivacyOption({
    required this.label,
    required this.value,
    this.isExceptOption = false,
  });
}

class PrivacyRadioScreen extends StatefulWidget {
  final String title;
  final String sectionHeader;
  final String settingKey;
  final List<PrivacyOption> options;
  final String? footerText;
  final String excludedListKey;

  const PrivacyRadioScreen({
    super.key,
    required this.title,
    required this.sectionHeader,
    required this.settingKey,
    required this.options,
    required this.excludedListKey,
    this.footerText,
  });

  @override
  State<PrivacyRadioScreen> createState() => _PrivacyRadioScreenState();
}

class _PrivacyRadioScreenState extends State<PrivacyRadioScreen> {
  late String _selectedValue;
  late List<String> _excludedContacts;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsService>();
    _selectedValue = settings.getSetting(widget.settingKey, defaultValue: 'Everyone');
    _excludedContacts = List<String>.from(settings.getSetting(widget.excludedListKey, defaultValue: []));
  }

  Future<void> _handleOptionTap(PrivacyOption option) async {
    final settings = context.read<SettingsService>();
    
    if (option.isExceptOption) {
      // If it's already selected and tapped again, or if it's being selected for the first time
      // Open the contact picker
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
          _selectedValue = option.value;
          _excludedContacts = selectedIds;
        });
        settings.updateSetting(widget.settingKey, option.value);
        settings.updateSetting(widget.excludedListKey, selectedIds);
      }
    } else {
      setState(() {
        _selectedValue = option.value;
      });
      settings.updateSetting(widget.settingKey, option.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: Text(widget.title, style: const TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
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
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Text(widget.sectionHeader, style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: List.generate(widget.options.length, (index) {
                    final option = widget.options[index];
                    final isSelected = _selectedValue == option.value;
                    
                    Widget? subtitleWidget;
                    if (option.isExceptOption && isSelected) {
                      subtitleWidget = Text('${_excludedContacts.length} contacts excluded', style: const TextStyle(color: AppColors.grey, fontSize: 13));
                    }
                    
                    Widget? trailingWidget;
                    if (isSelected) {
                      trailingWidget = const Icon(Icons.check, color: AppColors.green);
                    } else if (option.isExceptOption) {
                      trailingWidget = const Icon(Icons.chevron_right, color: AppColors.grey2);
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(option.label, style: const TextStyle(fontSize: 16, color: AppColors.dark)),
                          subtitle: subtitleWidget,
                          trailing: trailingWidget,
                          onTap: () => _handleOptionTap(option),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        ),
                        if (index < widget.options.length - 1)
                          const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
                      ],
                    );
                  }),
                ),
              ),
              if (widget.footerText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                  child: Text(
                    widget.footerText!,
                    style: const TextStyle(color: AppColors.grey, fontSize: 13),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

