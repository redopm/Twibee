import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme.dart';
import 'account_settings_screen.dart';
import 'chats_settings_screen.dart';
import 'notifications_settings_screen.dart';
import 'privacy_settings_screen.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';
import 'storage_data_screen.dart';
import 'linked_devices_screen.dart';
import 'help_screen.dart';
import 'saved_messages_screen.dart';
import 'my_bots_screen.dart';
import '../widgets/settings_group.dart';

class MyProfileScreen extends StatefulWidget {
  final SupabaseClient? supabaseClient;
  const MyProfileScreen({super.key, this.supabaseClient});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  late final SupabaseClient _supabase;

  String _name = 'Loading...';
  String _about = '';
  String _phoneNumber = '';
  String? _username;
  String? _avatarUrl;
  String? _userId;

  final _scrollController = ScrollController();
  bool _isCollapsed = false;

  @override
  void initState() {
    super.initState();
    _supabase = widget.supabaseClient ?? Supabase.instance.client;
    _loadProfile();
    _scrollController.addListener(() {
      final collapsed =
          _scrollController.hasClients && _scrollController.offset > 150;
      if (collapsed != _isCollapsed) {
        setState(() => _isCollapsed = collapsed);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data != null && mounted) {
        setState(() {
          _name = data['name'] ?? 'Unknown';
          _about = data['about'] ?? 'Hey there! Using Twibee';
          String formatPhone(String phone) {
            if (phone.isEmpty) return phone;
            String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
            if (!clean.startsWith('+')) clean = '+$clean';
            if (clean.length == 13 && clean.startsWith('+91')) {
              return '+91 ${clean.substring(3, 8)} ${clean.substring(8)}';
            }
            return clean;
          }

          _phoneNumber = formatPhone(data['phone_number'] ?? user.phone ?? '');
          _username = data['username'];
          _avatarUrl = data['avatar_url'];
          _userId = user.id;
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _updateAvatar() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final file = File(image.path);
      final fileExt = image.path.split('.').last;
      final fileName =
          '${_supabase.auth.currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await _supabase.storage.from('avatars').upload(fileName, file);
      final publicUrl =
          _supabase.storage.from('avatars').getPublicUrl(fileName);
      await _supabase.from('profiles').update({'avatar_url': publicUrl}).eq(
          'id', _supabase.auth.currentUser!.id);

      setState(() {
        _avatarUrl = publicUrl;
      });
    } catch (e) {
      debugPrint('Error updating avatar: $e');

      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update avatar')));
    }
  }

  Future<void> _editField(
      String title, String currentValue, String fieldName) async {
    final controller = TextEditingController(text: currentValue);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Enter $title'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Save')),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && result != currentValue) {
      try {
        await _supabase.from('profiles').update({fieldName: result.trim()}).eq(
            'id', _supabase.auth.currentUser!.id);
        setState(() {
          if (fieldName == 'name') _name = result.trim();
          if (fieldName == 'about') _about = result.trim();
          if (fieldName == 'username') _username = result.trim().toLowerCase();
        });
      } catch (e) {
        debugPrint('Error updating $fieldName: $e');
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await PushNotificationService().unregisterDeviceToken();
      await _supabase.auth.signOut();
      // The auth state listener in main should automatically kick the user back to the welcome screen
    }
  }

  /// Show the QR code bottom sheet with actual user ID encoded
  void _showQrCode() {
    if (_userId == null) return;
    // QR data: a deep link style string with user info
    final qrData =
        'Twibee://user/$_userId?name=${Uri.encodeComponent(_name)}&phone=${Uri.encodeComponent(_phoneNumber)}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              const Text('My QR Code',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark)),
              const SizedBox(height: 4),
              Text('Scan to add me on Twibee',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(height: 24),
              // QR Code
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 220,
                  backgroundColor: AppColors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.circle, color: AppColors.orange),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.circle,
                      color: AppColors.dark),
                ),
              ),
              const SizedBox(height: 20),
              // User info below QR
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.orange,
                    backgroundImage:
                        _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? Text(_name.isNotEmpty ? _name.characters.first.toUpperCase() : '?',
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_name,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppColors.dark)),
                      Text(_phoneNumber,
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey[500])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrData));
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Profile link copied!')));
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.orange,
                        side: const BorderSide(color: AppColors.orange),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.share, size: 18),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          _isCollapsed ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // ── Collapsible Orange Header ──
            SliverAppBar(
              expandedHeight: 260,
              collapsedHeight: kToolbarHeight,
              pinned: true,
              stretch: true,
              automaticallyImplyLeading: false, // Hide back button for root tab
              backgroundColor: AppColors.orange,
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: const Icon(Icons.qr_code, color: AppColors.white),
                    onPressed: _showQrCode,
                  ),
                ),
              ],
              // Collapsed state: avatar + name in compact row
              title: AnimatedOpacity(
                opacity: _isCollapsed ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: AppColors.orangePale,
                        backgroundImage: _avatarUrl != null
                            ? NetworkImage(_avatarUrl!)
                            : null,
                        child: _avatarUrl == null
                            ? Text(
                                _name.isNotEmpty ? _name.characters.first.toUpperCase() : '?',
                                style: const TextStyle(
                                    color: AppColors.orange,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(_name,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.parallax,
                background: Stack(
                  children: [
                    // Decorative blobs
                    Positioned(
                      top: -50,
                      left: -40,
                      child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.07),
                              shape: BoxShape.circle)),
                    ),
                    Positioned(
                      bottom: 10,
                      right: -50,
                      child: Container(
                          width: 200,
                          height: 200,
                          decoration: BoxDecoration(
                              color: AppColors.dark.withValues(alpha: 0.08),
                              shape: BoxShape.circle)),
                    ),
                    // Main content
                    Positioned.fill(
                      child: SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Avatar
                            GestureDetector(
                              onTap: _updateAvatar,
                              child: Stack(
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: AppColors.orangePale,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: AppColors.white, width: 3),
                                      image: _avatarUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(_avatarUrl!),
                                              fit: BoxFit.cover)
                                          : null,
                                    ),
                                    child: _avatarUrl == null
                                        ? Center(
                                            child: Text(
                                              _name.isNotEmpty
                                                  ? _name.characters.first.toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                  color: AppColors.orange,
                                                  fontSize: 38,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                          color: AppColors.white,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.camera_alt,
                                          color: AppColors.orange, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Name
                            GestureDetector(
                              onTap: () => _editField('Name', _name, 'name'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_name,
                                      style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 21,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit,
                                      color: AppColors.white, size: 15),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Phone + About
                            GestureDetector(
                              onTap: () => _editField('About', _about, 'about'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _phoneNumber.isNotEmpty
                                        ? '$_phoneNumber • $_about'
                                        : _about,
                                    style: const TextStyle(
                                        color: AppColors.white, fontSize: 12),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit,
                                      color: AppColors.white, size: 12),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Username
                            GestureDetector(
                              onTap: () => _editField(
                                  'Username', _username ?? '', 'username'),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _username != null && _username!.isNotEmpty
                                        ? '@$_username'
                                        : 'Set Username',
                                    style: const TextStyle(
                                        color: AppColors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.edit,
                                      color: AppColors.white, size: 12),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Divider ──
            SliverToBoxAdapter(
              child: Container(
                height: 20,
                decoration: const BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
              ),
            ),

            // ── Settings Options ──
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.lightGrey,
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  children: [
                    SettingsGroup(
                      header: 'Account & Privacy',
                      children: [
                        SettingsItem(
                          title: 'Account',
                          subtitle: 'Security, change number',
                          icon: Icons.person_outline,
                          iconBackgroundColor: AppColors.orange,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const AccountSettingsScreen())),
                        ),
                        SettingsItem(
                          title: 'Privacy',
                          subtitle: 'Block contacts, last seen',
                          icon: Icons.lock_outline,
                          iconBackgroundColor: AppColors.orange,
                          showDivider: false,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PrivacySettingsScreen())),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      header: 'Chat & Media',
                      children: [
                        SettingsItem(
                          title: 'Chats',
                          subtitle: 'Theme, wallpaper, backup',
                          icon: Icons.chat_bubble_outline,
                          iconBackgroundColor: AppColors.orange,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ChatsSettingsScreen())),
                        ),
                        SettingsItem(
                          title: 'Notifications',
                          subtitle: 'Message, group & call tones',
                          icon: Icons.notifications_none,
                          iconBackgroundColor: AppColors.red,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const NotificationsSettingsScreen())),
                        ),
                        SettingsItem(
                          title: 'Storage and Data',
                          subtitle: 'Network usage, auto-download',
                          icon: Icons.data_usage_outlined,
                          iconBackgroundColor: AppColors.orange,
                          showDivider: false,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const StorageDataScreen())),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      header: 'Features',
                      children: [
                        SettingsItem(
                          title: 'Saved Messages',
                          subtitle: 'Your saved photos & files',
                          icon: Icons.bookmark_outline,
                          iconBackgroundColor: AppColors.orange,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SavedMessagesScreen())),
                        ),
                        SettingsItem(
                          title: 'Linked Devices',
                          subtitle: 'Manage your active devices',
                          icon: Icons.laptop_chromebook_outlined,
                          iconBackgroundColor: AppColors.orange,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LinkedDevicesScreen())),
                        ),
                        SettingsItem(
                          title: 'My Bots',
                          subtitle: 'Manage connected bots',
                          icon: Icons.smart_toy_outlined,
                          iconBackgroundColor: AppColors.orange,
                          showDivider: false,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MyBotsScreen())),
                        ),
                      ],
                    ),
                    SettingsGroup(
                      header: 'Support & Actions',
                      children: [
                        SettingsItem(
                          title: 'Help',
                          subtitle: 'Help center, privacy policy',
                          icon: Icons.help_outline,
                          iconBackgroundColor: AppColors.red,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const HelpScreen())),
                        ),
                        SettingsItem(
                          title: 'Logout',
                          subtitle: 'Sign out of your account',
                          icon: Icons.logout,
                          iconBackgroundColor: AppColors.red,
                          isDestructive: true,
                          showDivider: false,
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
