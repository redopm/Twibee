import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';
import '../services/settings_service.dart';
import 'my_profile_screen.dart';
import 'privacy_settings_screen.dart';
import 'account_settings_screen.dart';
import 'chats_settings_screen.dart';
import 'notifications_settings_screen.dart';
import 'storage_data_screen.dart';
import 'linked_devices_screen.dart';
import 'help_screen.dart';
import 'invite_friend_screen.dart';
import 'lists_screen.dart';

class SettingsScreen extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  const SettingsScreen({super.key, this.supabaseClient});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SupabaseClient _supabase;
  String _name = 'Loading...';
  String _about = 'Hey there! Using Twibee 👋';
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;
      final data = await _supabase.from('profiles').select('name, about, avatar_url').eq('id', user.id).maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _name = data['name'] ?? 'Unknown';
          _about = data['about'] ?? 'Hey there! Using Twibee 👋';
          _avatarUrl = data['avatar_url'];
        });
      }
    } catch (e) {
      debugPrint('SettingsScreen profile fetch error: $e');
    }
  }

  Future<void> _showLanguagePicker(BuildContext context, SettingsService settings) async {
    final languages = ['English (device\'s language)', 'Hindi', 'Spanish', 'French', 'Arabic', 'German'];
    final currentLang = settings.getSetting('app_language', defaultValue: 'English (device\'s language)');

    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('App language', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark)),
              ),
              ...languages.map((lang) => ListTile(
                title: Text(lang),
                trailing: lang == currentLang ? const Icon(Icons.check, color: AppColors.orange) : null,
                onTap: () => Navigator.pop(context, lang),
              )),
            ],
          ),
        );
      },
    );

    if (selected != null && selected != currentLang) {
      settings.updateSetting('app_language', selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Settings',
        showBackButton: false,
        centerTitle: true,
      ),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          return ListView(
            children: [
              // Search Box
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: 'Search',
                      hintStyle: TextStyle(color: AppColors.grey),
                      prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
              ),
              
              SettingsGroup(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.orange,
                        backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                        child: _avatarUrl == null
                            ? Text(_name.isNotEmpty ? _name.characters.first.toUpperCase() : 'U', style: const TextStyle(color: AppColors.white, fontSize: 28, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      title: Text(_name, style: const TextStyle(color: AppColors.dark, fontSize: 20, fontWeight: FontWeight.bold)),
                      subtitle: Text(_about, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code, color: Colors.blue),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.lightGrey,
                            ),
                            child: const Icon(Icons.keyboard_arrow_down, color: AppColors.grey, size: 20),
                          ),
                        ],
                      ),
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => MyProfileScreen(supabaseClient: widget.supabaseClient)));
                          // Refresh data when returning from MyProfileScreen
                         _fetchProfile();
                      },
                    ),
                  ),
                ],
              ),
              
              SettingsGroup(
                children: [
                  SettingsItem(
                    title: 'Lists',
                    trailing: const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ListsScreen())),
                  ),
                  SettingsItem(
                    title: 'Linked Devices',
                    trailing: const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
                    showDivider: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LinkedDevicesScreen())),
                  ),
                ],
              ),
              
              SettingsGroup(
                children: [
                  SettingsItem(
                    title: 'Account',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSettingsScreen()))
                  ),
                  SettingsItem(
                    title: 'Privacy',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()))
                  ),
                  SettingsItem(
                    title: 'Chats',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsSettingsScreen()))
                  ),
                  SettingsItem(
                    title: 'Notifications',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()))
                  ),
                  SettingsItem(
                    title: 'Storage and Data',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StorageDataScreen()))
                  ),
                  SettingsItem(
                    title: 'App language',
                    subtitle: settings.getSetting('app_language', defaultValue: 'English (device\'s language)'),
                    showDivider: false,
                    onTap: () => _showLanguagePicker(context, settings),
                  ),
                ],
              ),
              
              SettingsGroup(
                children: [
                  SettingsItem(
                    title: 'Help',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()))
                  ),
                  SettingsItem(
                    title: 'Tell a Friend',
                    showDivider: false,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InviteFriendScreen()))
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

