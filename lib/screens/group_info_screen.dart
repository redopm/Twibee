import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';
import '../theme.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import 'edit_group_info_screen.dart';
import 'invite_share_screen.dart';
import 'add_participants_screen.dart';
import 'group_join_requests_screen.dart';
import 'media_links_docs_screen.dart';
import 'contact_info_sub_screens.dart';
import 'saved_messages_screen.dart';
import 'chat_theme_screen.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'video_call_screen.dart';
import 'voice_call_screen.dart';
import 'lists_screen.dart';
import 'group_activity_screen.dart';
import 'select_group_members_screen.dart';
import 'call_overlay_manager.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  final String groupName;
  final String? groupAvatarUrl;

  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.groupName,
    this.groupAvatarUrl,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  List<Map<String, dynamic>> _members = [];
  bool _isLoading = true;
  bool _isAdmin = false;
  int _mediaCount = 0;
  String? _currentAvatarUrl;
  String _currentGroupName = '';
  String _groupCreatedAt = '';

  @override
  void initState() {
    super.initState();
    _currentAvatarUrl = widget.groupAvatarUrl;
    _currentGroupName = widget.groupName;
    _fetchMembers();
    _fetchMediaStats();
    _refreshGroupData();
  }

  Future<void> _refreshGroupData() async {
    try {
      final data = await Supabase.instance.client
          .from('chats')
          .select('group_avatar_url, group_name, created_at')
          .eq('id', widget.chatId)
          .maybeSingle();
      if (mounted && data != null) {
        String formattedDate = '';
        if (data['created_at'] != null) {
          final dt = DateTime.tryParse(data['created_at'].toString())?.toLocal();
          if (dt != null) {
            final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
            formattedDate = 'Created ${months[dt.month - 1]} ${dt.day}, ${dt.year}';
          }
        }
        setState(() {
          _currentAvatarUrl = data['group_avatar_url'] as String?;
          if (data['group_name'] != null) {
            _currentGroupName = data['group_name'] as String;
          }
          if (formattedDate.isNotEmpty) {
            _groupCreatedAt = formattedDate;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMediaStats() async {
    try {
      final media = await context.read<ChatService>().getChatMedia(widget.chatId);
      if (mounted) {
        setState(() {
          _mediaCount = media.length;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMembers() async {
    setState(() => _isLoading = true);
    try {
      final chatService = context.read<ChatService>();
      final members = await chatService.getGroupParticipants(widget.chatId);
      final currentUserId = chatService.currentUserId;
      
      bool isAdmin = false;
      for (var m in members) {
        if (m['id'] == currentUserId && m['role'] == 'admin') {
          isAdmin = true;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _members = members;
          _isAdmin = isAdmin;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildDefaultAvatar() {
    final name = _currentGroupName.trim();
    final letter = name.isNotEmpty ? name.characters.first.toUpperCase() : 'G';
    return Container(
      width: 100,
      height: 100,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF9A00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Future<void> _exportChat(bool attachMedia) async {
    final name = widget.groupName.isNotEmpty ? widget.groupName : 'Group';
    await context.read<ChatService>().exportChat(widget.chatId, name, attachMedia: attachMedia);
  }

  void _showParticipantOptions(Map<String, dynamic> member) {
    if (!_isAdmin) return;
    final currentUserId = context.read<ChatService>().currentUserId;
    if (member['id'] == currentUserId) return; 

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.grey2, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person, color: AppColors.dark),
              title: Text('View ${member['name']}'),
              onTap: () => Navigator.pop(context), 
            ),
            ListTile(
              leading: Icon(member['role'] == 'admin' ? Icons.remove_moderator : Icons.admin_panel_settings, color: AppColors.orange),
              title: Text(member['role'] == 'admin' ? 'Dismiss as Admin' : 'Make Group Admin'),
              onTap: () async {
                Navigator.pop(context);
                final newRole = member['role'] == 'admin' ? 'member' : 'admin';
                await context.read<ChatService>().updateParticipantRole(widget.chatId, member['id'], newRole);
                _fetchMembers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppColors.red),
              title: const Text('Remove from Group', style: TextStyle(color: AppColors.red)),
              onTap: () async {
                Navigator.pop(context);
                await context.read<ChatService>().removeParticipant(widget.chatId, member['id']);
                _fetchMembers();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(String title, String content, String actionText, {bool isDestructive = false, dynamic Function()? onConfirm}) {
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
              if (onConfirm != null) await onConfirm();
            },
            child: Text(actionText),
          ),
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
              ListTile(leading: const Icon(Icons.check, color: AppColors.orange), title: const Text('Default (Off)'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const SizedBox(width: 24), title: const Text('Always'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const SizedBox(width: 24), title: const Text('Never'), onTap: () => Navigator.pop(context)),
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
                onTap: () {
                  Navigator.pop(context);
                  _exportChat(false);
                },
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text('Attach Media', textAlign: TextAlign.center, style: TextStyle(color: AppColors.blue, fontSize: 18)),
                onTap: () {
                  Navigator.pop(context);
                  _exportChat(true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF2F2F7);
    final chatService = context.watch<ChatService>();

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 64,
        titleSpacing: 0,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12.0, top: 8.0, bottom: 8.0),
          child: GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.orange, size: 18),
            ),
          ),
        ),
        actions: [
          if (_isAdmin)
            Padding(
              padding: const EdgeInsets.only(right: 16.0, top: 8.0, bottom: 8.0),
              child: TextButton(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditGroupInfoScreen(
                        groupId: widget.chatId,
                        currentName: _currentGroupName,
                        currentDescription: 'Group description...',
                        currentAvatarUrl: _currentAvatarUrl,
                      ),
                    ),
                  );
                  if (result == true) {
                    _fetchMembers();
                    _refreshGroupData(); // Refresh avatar & name from DB
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(60, 40),
                ),
                child: const Text('Edit', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: () async {
                if (_isAdmin) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditGroupInfoScreen(
                        groupId: widget.chatId,
                        currentName: _currentGroupName,
                        currentDescription: 'Group description...',
                        currentAvatarUrl: _currentAvatarUrl,
                      ),
                    ),
                  );
                  if (result == true) {
                    _fetchMembers();
                    _refreshGroupData(); // Refresh avatar from DB after save
                  }
                }
              },
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(shape: BoxShape.circle),
                    child: _currentAvatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              _currentAvatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildDefaultAvatar(),
                            ),
                          )
                        : _buildDefaultAvatar(),
                  ),
                  if (_isAdmin)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.green,
                        shape: BoxShape.circle,
                        border: Border.fromBorderSide(BorderSide(color: AppColors.white, width: 2)),
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _currentGroupName,
              style: const TextStyle(color: AppColors.dark, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Group • ', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                Text('${_members.length} members', style: const TextStyle(color: AppColors.orange, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add group description')));
              },
              child: const Text('Add group description', style: TextStyle(color: AppColors.orange, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 24),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildTopAction(Icons.call_outlined, 'Audio', () {
                if (!CallOverlayManager().canStartNewCall(context)) return;
                
                final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
                final actualMembers = _members
                    .where((m) => m['id'] != context.read<ChatService>().currentUserId)
                    .map((m) => ZegoUIKitUser(id: m['id'].toString().replaceAll('-', ''), name: m['name'] ?? 'User'))
                    .toList();
                
                final data = ZegoCallInvitationData(
                  timeoutSeconds: 60,
                  callID: callId,
                  invitationID: callId,
                  type: ZegoCallType.voiceCall,
                  customData: '{"groupName": "${widget.groupName}"}',
                  inviter: ZegoUIKitUser(id: context.read<ChatService>().currentUserId.replaceAll('-', ''), name: 'You'),
                  invitees: actualMembers,
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(invitationData: data)));
              }),
              _buildTopAction(Icons.videocam_outlined, 'Video', () {
                if (!CallOverlayManager().canStartNewCall(context)) return;

                final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
                final actualMembers = _members
                    .where((m) => m['id'] != context.read<ChatService>().currentUserId)
                    .map((m) => ZegoUIKitUser(id: m['id'].toString().replaceAll('-', ''), name: m['name'] ?? 'User'))
                    .toList();
                
                final data = ZegoCallInvitationData(
                  timeoutSeconds: 60,
                  callID: callId,
                  invitationID: callId,
                  type: ZegoCallType.videoCall,
                  customData: '{"groupName": "${widget.groupName}"}',
                  inviter: ZegoUIKitUser(id: context.read<ChatService>().currentUserId.replaceAll('-', ''), name: 'You'),
                  invitees: actualMembers,
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => VideoCallScreen(invitationData: data)));
              }),
              _buildTopAction(Icons.person_add_outlined, 'Add', () async {
                if (!_isAdmin) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Only admins can add participants.')));
                  return;
                }
                final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => AddParticipantsScreen(chatId: widget.chatId)));
                if (result == true) {
                  _fetchMembers();
                }
              }, isGrayedOut: !_isAdmin),
              _buildTopAction(Icons.search, 'Search', () {
                Navigator.pop(context, true);
              }),
            ],
          ),
          const SizedBox(height: 24),

          _buildGroupContainer([
            _buildListTile(Icons.image_outlined, 'Media, links and docs', trailingText: '$_mediaCount', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => MediaLinksDocsScreen(chatId: widget.chatId)));
            }),
            _buildListTile(Icons.storage_outlined, 'Storage', trailingText: _mediaCount > 0 ? '$_mediaCount' : 'None', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ManageStorageScreen(contactName: widget.groupName, chatId: widget.chatId)));
            }),
            _buildListTile(Icons.star_outline, 'Starred', trailingText: 'None', showBorder: false, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedMessagesScreen()));
            }),
          ]),
          
          const SizedBox(height: 20),
          _buildGroupContainer([
            _buildListTile(Icons.notifications_none, 'Notifications', trailingText: 'All', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen(contactName: widget.groupName)));
            }),
            _buildListTile(Icons.color_lens_outlined, 'Chat theme', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatThemeScreen(chatId: widget.chatId)));
            }),
            _buildListTile(Icons.download_outlined, 'Save to Photos', trailingText: 'Default', showBorder: false, onTap: () {
              _showSaveToPhotosSheet();
            }),
          ]),

          const SizedBox(height: 20),
          _buildGroupContainer([
            _buildListTile(Icons.timer_outlined, 'Disappearing messages', trailingText: 'Off', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => DisappearingMessagesScreen(chatId: widget.chatId, contactName: widget.groupName)));
            }),
            _buildSwitchTile(Icons.lock_outline, 'Lock chat', 'Lock and hide this chat on this device.', chatService.isChatLocked(widget.chatId), (val) async {
              if (val) {
                await chatService.lockChat(widget.chatId);
              } else {
                await chatService.unlockChat(widget.chatId);
              }
              setState(() {});
            }),
            _buildListTile(Icons.shield_outlined, 'Advanced chat privacy', trailingText: 'Off', onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AdvancedChatPrivacyScreen()));
            }),
            _buildListTile(Icons.lock_outline, 'Encryption', subtitle: 'Messages and calls are end-to-end encrypted. Tap to learn more.', showBorder: false, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => EncryptionScreen(contactName: widget.groupName)));
            }),
          ]),

          const SizedBox(height: 20),
          _buildGroupContainer([
            _buildListTile(Icons.groups_outlined, 'Create a similar group', subtitle: 'Start with the same members that you can add or remove.', showBorder: false, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectGroupMembersScreen()));
            }),
          ]),

          const SizedBox(height: 20),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppColors.orange))
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8, right: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_members.length} members', style: const TextStyle(color: AppColors.dark, fontSize: 17, fontWeight: FontWeight.bold)),
                      const Icon(Icons.search, color: AppColors.dark, size: 22),
                    ],
                  ),
                ),
                _buildGroupContainer([
                  _buildListTile(
                    Icons.link, 
                    'Invite via Link', 
                    showBorder: true,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InviteShareScreen(
                            id: widget.chatId,
                            isChannel: false,
                            isAdmin: _isAdmin,
                            name: widget.groupName,
                          ),
                        ),
                      );
                    },
                  ),
                  if (_isAdmin)
                    _buildListTile(
                      Icons.person_add_alt_1,
                      'Review Join Requests',
                      showBorder: true,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GroupJoinRequestsScreen(
                              chatId: widget.chatId,
                            ),
                          ),
                        );
                      },
                    ),
                  ..._members.asMap().entries.map((entry) {
                    final index = entry.key;
                    final m = entry.value;
                    final bool isLast = index == _members.length - 1;
                    return _buildMemberTile(m, showBorder: !isLast);
                  }),
                ]),
              ],
            ),

          const SizedBox(height: 20),
          _buildGroupContainer([
            _buildTextActionTile('View member changes', AppColors.dark, trailingIcon: Icons.chevron_right, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => GroupActivityScreen(
                chatId: widget.chatId,
                groupName: widget.groupName,
              )));
            }),
            _buildTextActionTile('Add to Favorites', AppColors.orange, onTap: () {
              final settings = context.read<SettingsService>();
              final key = 'fav_${widget.chatId}';
              final isFav = settings.getSetting(key, defaultValue: false) as bool;
              settings.updateSetting(key, !isFav);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(!isFav ? 'Added to Favorites' : 'Removed from Favorites'))
              );
            }),
            _buildTextActionTile('Add to list', AppColors.orange, onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ListsScreen()));
            }),
            _buildTextActionTile('Export chat', AppColors.orange, onTap: () {
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
          // Group 6: Exit/Report
          _buildGroupContainer([
            _buildTextActionTile('Exit group', AppColors.red, onTap: () {
              _showConfirmDialog('Exit ${widget.groupName}?', 'You will leave this group.', 'Exit', isDestructive: true, onConfirm: () async {
                final chatService = context.read<ChatService>();
                final nav = Navigator.of(context);
                await chatService.removeParticipant(widget.chatId, chatService.currentUserId);
                nav.pop();
              });
            }),
            _buildTextActionTile('Report group', AppColors.red, showBorder: false, onTap: () {
              _showConfirmDialog('Report ${widget.groupName} to Twibee?', 'The last 5 messages from this group will be forwarded to Twibee.', 'Report', isDestructive: true, onConfirm: () async {
                await context.read<ChatService>().reportGroup(widget.chatId, 'Spam or inappropriate content');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report sent.')));
              });
            }),
          ]),

          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Text(
              _groupCreatedAt.isNotEmpty ? '$_groupCreatedAt.' : '',
              style: const TextStyle(color: AppColors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- Helper UI Methods --- //

  Widget _buildTopAction(IconData icon, String label, VoidCallback onTap, {bool isGrayedOut = false}) {
    final color = isGrayedOut ? AppColors.grey : AppColors.orange;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        height: 75,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: isGrayedOut ? AppColors.grey : AppColors.dark)),
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

  Widget _buildListTile(IconData icon, String title, {String? subtitle, String? trailingText, bool showBorder = true, bool isIconTile = false, Color? color, VoidCallback? onTap}) {
    final c = color ?? AppColors.dark;
    return Column(
      children: [
        ListTile(
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
        ),
        if (showBorder) const Divider(height: 1, indent: 56, color: AppColors.lightGrey),
      ],
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Icon(icon, color: AppColors.dark, size: 24),
          title: Text(title, style: const TextStyle(color: AppColors.dark, fontSize: 16)),
          subtitle: Text(subtitle, style: const TextStyle(color: AppColors.grey, fontSize: 12)),
          trailing: CupertinoSwitch(
            value: value,
            activeTrackColor: AppColors.orange,
            onChanged: onChanged,
          ),
        ),
        const Divider(height: 1, indent: 56, color: AppColors.lightGrey),
      ],
    );
  }

  Widget _buildTextActionTile(String title, Color color, {bool showBorder = true, IconData? trailingIcon, VoidCallback? onTap}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(title, style: TextStyle(color: color, fontSize: 16)),
          trailing: trailingIcon != null ? Icon(trailingIcon, color: AppColors.grey, size: 20) : null,
          onTap: onTap,
        ),
        if (showBorder) const Divider(height: 1, indent: 16, color: AppColors.lightGrey),
      ],
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> m, {bool showBorder = true}) {
    String name = m['name'] ?? 'Unknown';
    String initial = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
    bool isAdmin = m['role'] == 'admin';
    final chatService = context.read<ChatService>();
    final currentUserId = chatService.currentUserId;
    bool isCurrentUser = m['id'] == currentUserId;
    String? avatarUrl = m['avatar_url'];
    
    if (isCurrentUser) {
      name = 'You';
      if (chatService.currentUserProfile?['avatar_url'] != null) {
        avatarUrl = chatService.currentUserProfile?['avatar_url'];
      }
    }

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.blue,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null ? Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)) : null,
            ),
            title: Text(name, style: const TextStyle(fontSize: 16, color: AppColors.dark)),
            subtitle: isCurrentUser
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Add member tag', style: TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('Life has no Ctrl + Z.', style: TextStyle(color: AppColors.grey, fontSize: 13)),
                    ],
                  )
                : const Text('Hey there! I am using Twibee.', style: TextStyle(color: AppColors.grey, fontSize: 13)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isAdmin)
                  const Text('Admin', style: TextStyle(color: AppColors.grey, fontSize: 14)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
              ],
            ),
            onTap: () => _showParticipantOptions(m),
          ),
        ),
        if (showBorder) const Divider(height: 1, indent: 64, color: AppColors.lightGrey),
      ],
    );
  }
}


