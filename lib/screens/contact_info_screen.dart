import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../theme.dart';
import 'edit_contact_screen.dart';
import 'media_links_docs_screen.dart';
import 'contact_info_sub_screens.dart';
import 'saved_messages_screen.dart';
import 'chat_theme_screen.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import '../services/call_log_service.dart' as import_call_log_service;
import 'select_group_members_screen.dart';
import 'lists_screen.dart';
import 'contacts_screen.dart';
import 'individual_chat_screen.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';
import 'media_viewer_screen.dart';
import 'call_overlay_manager.dart';

class ContactInfoScreen extends StatefulWidget {
  final String name;
  final String avatarText;
  final String? avatarUrl;
  final Color avatarColor;
  final String chatId;
  final String? initialPhone;

  const ContactInfoScreen({
    super.key,
    required this.name,
    required this.avatarText,
    this.avatarUrl,
    required this.avatarColor,
    required this.chatId,
    this.initialPhone,
  });

  @override
  State<ContactInfoScreen> createState() => _ContactInfoScreenState();
}

class _ContactInfoScreenState extends State<ContactInfoScreen> {
  String? _otherUserId;
  String? _currentPhone;
  String? _currentName;
  String? _currentBio;
  String? _currentAvatarUrl;
  List<Map<String, dynamic>> _commonGroups = [];
  bool _isLoadingGroups = true;

  @override
  void initState() {
    super.initState();
    _currentName = widget.name;
    _currentAvatarUrl = widget.avatarUrl;
    _currentPhone = widget.initialPhone;
    _fetchUserInfo();
    _fetchCommonGroups();
  }

  Future<void> _fetchUserInfo() async {
    try {
      final res = await ChatService().getChatMeta(widget.chatId);
      final isGroup = res['is_group'] as bool;
      final otherUserId = res['other_user_id'] as String?;
      
      if (!isGroup && otherUserId != null) {
        _otherUserId = otherUserId;
        
        // Fetch phone and about
        final userRes = await Supabase.instance.client
            .from('profiles')
            .select('phone_number, about, avatar_url')
            .eq('id', otherUserId)
            .maybeSingle();
            
        if (userRes != null && mounted) {
          setState(() {
            if (userRes['phone_number'] != null) _currentPhone = userRes['phone_number'].toString();
            if (userRes['about'] != null) _currentBio = userRes['about'];
            if (userRes['avatar_url'] != null) _currentAvatarUrl = userRes['avatar_url'];
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching contact info: $e');
    }
  }

  Future<void> _fetchCommonGroups() async {
    // In a real app we'd fetch the participant user_id. Here we just pass chatId as a mock.
    final groups = await context.read<ChatService>().getCommonGroups(widget.chatId);
    if (mounted) {
      setState(() {
        _commonGroups = groups;
        _isLoadingGroups = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF2F2F7);
    final displayName = _currentName ?? widget.name;
    final displayAvatar = _currentAvatarUrl ?? widget.avatarUrl;
    String formatPhone(String phone) {
      if (phone.isEmpty) return phone;
      String clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
      if (!clean.startsWith('+')) clean = '+$clean';
      if (clean.length == 13 && clean.startsWith('+91')) {
        return '+91 ${clean.substring(3, 8)} ${clean.substring(8)}';
      }
      return clean;
    }
    
    final displayPhone = formatPhone(_currentPhone ?? '');
    final displayBio = _currentBio ?? 'Hey there! I am using Twibee.';
    final chatService = context.watch<ChatService>();
    final settings = context.watch<SettingsService>();
    final isLocked = chatService.isChatLocked(widget.chatId);
    
    final currentThemeId = settings.getSetting('chat_theme_id', defaultValue: 'default');
    final currentTheme = ChatTheme.getTheme(currentThemeId);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: TwibeeAppBar(
        title: 'Contact info',
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EditContactScreen(
                      initialName: displayName,
                      initialPhone: displayPhone,
                    ),
                  ),
                );
                if (result != null && result is Map<String, String>) {
                  setState(() {
                    if (result['phone']?.isNotEmpty ?? false) {
                      _currentPhone = result['phone'];
                    }
                    if (result['name']?.isNotEmpty ?? false) {
                      _currentName = result['name'];
                    }
                  });
                }
              },
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                minimumSize: Size.zero,
              ),
              child: const Text('Edit', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 20),
          // Avatar
          Center(
            child: GestureDetector(
              onTap: () {
                if (displayAvatar != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MediaViewerScreen(
                        initialMediaUrl: displayAvatar,
                        initialMessageType: 'image',
                        senderName: displayName,
                        time: '',
                        chatId: widget.chatId,
                        messageId: 'profile',
                      ),
                    ),
                  );
                }
              },
              child: CircleAvatar(
                radius: 60,
                backgroundColor: displayAvatar == null ? widget.avatarColor : Colors.transparent,
                backgroundImage: displayAvatar != null ? CachedNetworkImageProvider(displayAvatar) : null,
                child: displayAvatar == null ? Text(
                  widget.avatarText,
                  style: const TextStyle(color: AppColors.white, fontSize: 50, fontWeight: FontWeight.bold),
                ) : null,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Name
          Center(
            child: Text(
              displayName,
              style: const TextStyle(color: AppColors.dark, fontSize: 28, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          // Phone
          Center(
            child: Text(
              displayPhone,
              style: const TextStyle(color: AppColors.grey, fontSize: 16),
            ),
          ),
          const SizedBox(height: 8),
          // Bio
          Center(
            child: Text(
              displayBio,
              style: const TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          ),
          const SizedBox(height: 24),
          
          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTopAction(Icons.call_outlined, 'Audio', () {
                if (!CallOverlayManager().canStartNewCall(context)) return;
                final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
                final data = ZegoCallInvitationData(
                  timeoutSeconds: 60,
                  callID: callId,
                  invitationID: callId,
                  type: ZegoCallType.voiceCall,
                  customData: '',
                  inviter: ZegoUIKitUser(id: context.read<ChatService>().currentUserId.replaceAll('-', ''), name: 'You'),
                  invitees: [ZegoUIKitUser(id: widget.chatId.replaceAll('-', ''), name: widget.name)],
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(invitationData: data)));
              }),
              _buildTopAction(Icons.videocam_outlined, 'Video', () {
                if (!CallOverlayManager().canStartNewCall(context)) return;
                final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
                final data = ZegoCallInvitationData(
                  timeoutSeconds: 60,
                  callID: callId,
                  invitationID: callId,
                  type: ZegoCallType.videoCall,
                  customData: '',
                  inviter: ZegoUIKitUser(id: context.read<ChatService>().currentUserId.replaceAll('-', ''), name: 'You'),
                  invitees: [ZegoUIKitUser(id: widget.chatId.replaceAll('-', ''), name: widget.name)],
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => VideoCallScreen(invitationData: data)));
              }),
              _buildTopAction(Icons.search, 'Search', () {
                Navigator.pop(context, true); // Return to chat screen with search flag
              }),
            ],
          ),
          const SizedBox(height: 24),
          
          // Call History
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: import_call_log_service.CallLogService().callLogsStream,
            builder: (context, snapshot) {
              final allLogs = snapshot.data ?? [];
              final currentUserId = context.read<ChatService>().currentUserId;
              final contactLogs = allLogs.where((log) {
                final inviterId = log['inviter']?['id'];
                final participants = log['participants'] as List? ?? [];
                return inviterId == widget.chatId || participants.any((p) => p['user_id'] == widget.chatId);
              }).take(3).toList();

              if (contactLogs.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 16, bottom: 8),
                      child: Text('Recent Calls', style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                    _buildGroupContainer(
                      contactLogs.map((log) {
                        final isInviter = log['inviter']['id'] == currentUserId;
                        final isVideo = log['is_video'] == true;
                        final startedAt = log['started_at'] != null ? DateTime.parse(log['started_at']).toLocal() : DateTime.now();
                        
                        String displayStatus = 'Incoming';
                        IconData statusIcon = Icons.call_received;
                        Color statusColor = AppColors.grey;

                        if (isInviter) {
                          statusIcon = Icons.call_made;
                          if (log['status'] == 'completed') {
                            displayStatus = 'Outgoing';
                          } else if (log['status'] == 'ongoing') { displayStatus = 'Ongoing'; statusColor = Colors.green; }
                          else displayStatus = 'Cancelled';
                        } else {
                          final participants = log['participants'] as List? ?? [];
                          final myParticipantMap = participants.firstWhere((p) => p['user_id'] == currentUserId, orElse: () => null);
                          final myStatus = myParticipantMap?['status'] ?? 'missed';
                          if (myStatus == 'missed' || myStatus == 'declined') {
                            statusIcon = Icons.call_missed;
                            displayStatus = myStatus == 'missed' ? 'Missed' : 'Declined';
                            statusColor = Colors.red;
                          } else if (log['status'] == 'ongoing') {
                            statusIcon = Icons.call_received;
                            displayStatus = 'Ongoing';
                            statusColor = Colors.green;
                          }
                        }
                        
                        final dateStr = "${startedAt.day}/${startedAt.month} ${startedAt.hour}:${startedAt.minute.toString().padLeft(2, '0')}";
                        return _buildListTile(
                          statusIcon,
                          '$displayStatus ($dateStr)',
                          subtitle: isVideo ? 'Video Call' : 'Audio Call',
                          trailingText: '',
                          onTap: () {},
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            },
          ),

          // Group 1
          _buildGroupContainer([
            _buildListTile(Icons.image_outlined, 'Media, links and docs', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MediaLinksDocsScreen(chatId: widget.chatId)));
            }),
            _buildListTile(Icons.storage_outlined, 'Manage storage', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ManageStorageScreen(contactName: displayName, chatId: widget.chatId)));
            }),
            _buildListTile(Icons.star_outline, 'Saved', trailingText: 'None', showBorder: false, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedMessagesScreen()));
            }),
          ]),
          
          const SizedBox(height: 20),
          // Group 2
          _buildGroupContainer([
            _buildListTile(Icons.notifications_none, 'Notifications', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(contactName: displayName)));
            }),
            _buildListTile(Icons.color_lens_outlined, 'Chat theme', trailingText: currentTheme.name, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThemeScreen(chatId: widget.chatId)));
            }),
            _buildListTile(Icons.download_outlined, 'Save to Photos', trailingText: 'Default', showBorder: false, onTap: () {
              _showSaveToPhotosSheet();
            }),
          ]),

          const SizedBox(height: 20),
          // Group 3
          _buildGroupContainer([
            _buildListTile(Icons.timer_outlined, 'Disappearing messages', trailingText: 'Off', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DisappearingMessagesScreen(chatId: widget.chatId, contactName: displayName)));
            }),
            _buildSwitchTile(Icons.lock_outline, 'Lock chat', 'Lock and hide this chat on this device.', isLocked, (val) async {
              if (val) {
                await chatService.lockChat(widget.chatId);
              } else {
                await chatService.unlockChat(widget.chatId);
              }
            }),
            _buildListTile(Icons.shield_outlined, 'Advanced chat privacy', trailingText: 'Off', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedChatPrivacyScreen()));
            }),
            _buildListTile(Icons.lock_outline, 'Encryption', subtitle: 'Messages and calls are end-to-end encrypted. Tap to verify.', showBorder: false, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => EncryptionScreen(contactName: displayName)));
            }),
          ]),

          const SizedBox(height: 20),
          // Group 4
          _buildGroupContainer([
            _buildListTile(Icons.person_outline, 'Contact details', showBorder: false, onTap: () {
              _showContactDetailsSheet(displayName, displayPhone);
            }),
          ]),

          const SizedBox(height: 20),
          // Group 5 - Common groups
          if (_isLoadingGroups)
            const Center(child: CircularProgressIndicator())
          else if (_commonGroups.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 8),
                  child: Text('No groups in common', style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _buildGroupContainer([
                  _buildListTile(Icons.add, 'Create group with $displayName', isIconTile: true, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectGroupMembersScreen()));
                  }),
                  _buildListTile(Icons.group_add_outlined, 'Add to group', isIconTile: true, showBorder: false, onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Add $displayName to an existing group...')));
                  }),
                ]),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Text('${_commonGroups.length} group${_commonGroups.length > 1 ? 's' : ''} in common', style: const TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                _buildGroupContainer([
                  _buildListTile(Icons.add, 'Create group with $displayName', isIconTile: true, onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectGroupMembersScreen()));
                  }),
                  ..._commonGroups.map((group) => _buildListTile(Icons.group, group['name'], onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => IndividualChatScreen(chatId: group['id'], chatName: group['name'])));
                  })),
                ]),
              ],
            ),

          const SizedBox(height: 20),
          // Group 6 - Text actions
          _buildGroupContainer([
            _buildTextActionTile('Share contact', AppColors.green, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ContactsScreen()));
            }),
            _buildTextActionTile('Add to Favorites', AppColors.green, onTap: () async {
              if (_otherUserId != null) await context.read<ChatService>().addFavorite(_otherUserId!);
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$displayName added to favorites!')));
            }),
            _buildTextActionTile('Add to list', AppColors.green, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ListsScreen()));
            }),
            _buildTextActionTile('Export chat', AppColors.green, onTap: () {
              _showExportChatSheet();
            }),
            _buildTextActionTile('Clear chat', AppColors.red, showBorder: false, onTap: () {
              _showConfirmDialog('Clear this chat?', 'Messages will be removed from this device.', 'Clear chat', isDestructive: true, onConfirm: () async {
                await context.read<ChatService>().clearChat(widget.chatId);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared.')));
              });
            }),
          ]),

          const SizedBox(height: 20),
          // Group 7 - Block/Report
          _buildGroupContainer([
            _buildTextActionTile('Block $displayName', AppColors.red, onTap: () {
              _showConfirmDialog('Block $displayName?', 'Blocked contacts will no longer be able to call you or send you messages.', 'Block', isDestructive: true, onConfirm: () async {
                if (_otherUserId != null) await context.read<ChatService>().blockContact(_otherUserId!);
              });
            }),
            _buildTextActionTile('Report $displayName', AppColors.red, showBorder: false, onTap: () {
              _showConfirmDialog('Report $displayName to Twibee?', 'The last 5 messages from this contact will be forwarded to Twibee.', 'Report', isDestructive: true, onConfirm: () async {
                if (_otherUserId != null) await context.read<ChatService>().reportContact(_otherUserId!, 'Spam or inappropriate content');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent.')));
              });
            }),
          ]),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showSaveToPhotosSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    const Text('Save to Photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Automatically save photos and videos you receive to Photos.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey)),
              ),
              ListTile(leading: const Icon(Icons.check, color: AppColors.green), title: const Text('Default (Off)'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const SizedBox(width: 24), title: const Text('Always'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const SizedBox(width: 24), title: const Text('Never'), onTap: () => Navigator.pop(context)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.orange, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.dark, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupContainer(List<Widget> children) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, {String? subtitle, String? trailingText, bool showBorder = true, bool isIconTile = false, VoidCallback? onTap}) {
    Color c = AppColors.dark;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: isIconTile
          ? CircleAvatar(backgroundColor: AppColors.lightGrey, radius: 18, child: Icon(icon, color: c, size: 20))
          : Icon(icon, color: c, size: 24),
      title: Text(title, style: TextStyle(color: c, fontSize: 16)),
      subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 12)) : null,
      trailing: trailingText != null
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(trailingText, style: const TextStyle(color: AppColors.grey, fontSize: 16)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
              ],
            )
          : (onTap != null ? const Icon(Icons.chevron_right, color: AppColors.grey, size: 20) : null),
      onTap: onTap,
      shape: showBorder ? const Border(bottom: BorderSide(color: AppColors.lightGrey, width: 0.5)) : null,
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Icon(icon, color: AppColors.dark, size: 24),
      title: Text(title, style: const TextStyle(color: AppColors.dark, fontSize: 16)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
      trailing: CupertinoSwitch(
        value: value,
        activeTrackColor: AppColors.orange,
        onChanged: onChanged,
      ),
      shape: const Border(bottom: BorderSide(color: AppColors.lightGrey, width: 0.5)),
    );
  }

  Widget _buildTextActionTile(String title, Color color, {bool showBorder = true, VoidCallback? onTap}) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      onTap: onTap,
      shape: showBorder ? const Border(bottom: BorderSide(color: AppColors.lightGrey, width: 0.5)) : null,
    );
  }

  void _showContactDetailsSheet(String name, String phone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
                child: Text('Contact details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(name),
                subtitle: const Text('Name'),
              ),
              ListTile(
                leading: const Icon(Icons.phone_outlined),
                title: Text(phone),
                subtitle: const Text('Mobile'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExportChatSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Export chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text('Attaching media will increase the size of the chat export.', style: TextStyle(color: AppColors.grey)),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Without Media', textAlign: TextAlign.center, style: TextStyle(color: AppColors.blue, fontSize: 18)),
                onTap: () async {
                  Navigator.pop(context);
                  final name = widget.name.isNotEmpty ? widget.name : 'Unknown';
                  await context.read<ChatService>().exportChat(widget.chatId, name, attachMedia: false);
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Attach Media', textAlign: TextAlign.center, style: TextStyle(color: AppColors.blue, fontSize: 18)),
                onTap: () async {
                  Navigator.pop(context);
                  final name = widget.name.isNotEmpty ? widget.name : 'Unknown';
                  await context.read<ChatService>().exportChat(widget.chatId, name, attachMedia: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showConfirmDialog(String title, String content, String actionText,
      {bool isDestructive = false, dynamic Function()? onConfirm}) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () async {
              Navigator.pop(context);
              if (onConfirm != null) {
                await onConfirm();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$actionText executed.')));
              }
            },
            child: Text(actionText),
          ),
        ],
      ),
    );
  }
}

