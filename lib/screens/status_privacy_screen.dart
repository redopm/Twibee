import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/status_service.dart';
import 'contact_selection_screen.dart';

class StatusPrivacyScreen extends StatefulWidget {
  const StatusPrivacyScreen({super.key});

  @override
  State<StatusPrivacyScreen> createState() => _StatusPrivacyScreenState();
}

class _StatusPrivacyScreenState extends State<StatusPrivacyScreen> {
  String _selectedOption = 'everyone';
  List<String> _included = [];
  List<String> _excluded = [];
  bool _isLoading = true;
  bool _allowSharing = true;

  @override
  void initState() {
    super.initState();
    _loadPrivacySettings();
  }

  Future<void> _loadPrivacySettings() async {
    final service = context.read<StatusService>();
    final privacy = await service.getStatusPrivacy();
    if (privacy != null && mounted) {
      setState(() {
        _selectedOption = privacy['type'] ?? 'everyone';
        _included = List<String>.from(privacy['included'] ?? []);
        _excluded = List<String>.from(privacy['excluded'] ?? []);
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _savePrivacy() async {
    await context.read<StatusService>().updateStatusPrivacy(_selectedOption, _included, _excluded);
  }

  void _onOptionTap(String option) {
    setState(() {
      _selectedOption = option;
    });
    _savePrivacy();
  }

  void _openContactPicker(String option) async {
    final title = option == 'except' ? 'Hide status from' : 'Share status with';
    final subtitle = option == 'except' ? 'excluded' : 'included';
    final initialList = option == 'except' ? _excluded : _included;

    final selectedIds = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => ContactSelectionScreen(
          title: title,
          subtitle: subtitle,
          initialSelectedIds: initialList,
        ),
      ),
    );

    if (selectedIds != null) {
      setState(() {
        _selectedOption = option;
        if (option == 'except') {
          _excluded = selectedIds;
        } else {
          _included = selectedIds;
        }
      });
      _savePrivacy();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2), // Light gray background matching WhatsApp settings
      appBar: const TwibeeAppBar(title: 'Status privacy'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.green))
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8.0, bottom: 8.0),
                    child: Text('Audience who can see my status', 
                      style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                  
                  // Main Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _buildPrivacyTile(
                          icon: Icons.person_outline,
                          title: 'My contacts',
                          value: 'everyone',
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildPrivacyTile(
                          icon: Icons.person_off_outlined,
                          title: 'My contacts except',
                          subtitle: '${_excluded.length} excluded • Edit >',
                          value: 'except',
                          onEditTap: () => _openContactPicker('except'),
                        ),
                        const Divider(height: 1, indent: 56),
                        _buildPrivacyTile(
                          icon: Icons.person_add_alt_1_outlined,
                          title: 'Only share with',
                          subtitle: '${_included.length} included • Edit >',
                          value: 'only_share_with',
                          onEditTap: () => _openContactPicker('only_share_with'),
                        ),
                      ],
                    ),
                  ),
                  
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    child: Text(
                      'Changes to your privacy settings won\'t affect status updates that you\'ve shared already.',
                      style: TextStyle(color: AppColors.grey, fontSize: 13),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sharing Card
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SwitchListTile(
                      activeThumbColor: AppColors.green,
                      title: const Row(
                        children: [
                          Icon(Icons.sync_alt, color: AppColors.dark),
                          SizedBox(width: 16),
                          Text('Allow sharing', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
                        ],
                      ),
                      value: _allowSharing,
                      onChanged: (val) {
                        setState(() {
                          _allowSharing = val;
                        });
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
                    child: Text(
                      'Let people who can see your status reshare and forward it.',
                      style: TextStyle(color: AppColors.grey, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ),
    );
  }

  Widget _buildPrivacyTile({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
    VoidCallback? onEditTap,
  }) {
    final isSelected = _selectedOption == value;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(icon, color: AppColors.dark, size: 28),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
      subtitle: subtitle != null 
        ? GestureDetector(
            onTap: onEditTap,
            child: Text(subtitle, style: const TextStyle(color: AppColors.green, fontWeight: FontWeight.bold, fontSize: 13)),
          )
        : null,
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.green) : null,
      onTap: () => _onOptionTap(value),
    );
  }
}

