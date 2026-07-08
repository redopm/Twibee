import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../utils/permission_utils.dart';
import '../services/call_log_service.dart' as import_call_log_service;
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import 'call_overlay_manager.dart';
import '../services/auth_service.dart';
class SelectCallContactScreen extends StatefulWidget {
  final bool isAddParticipantMode;
  final bool isFavoriteMode;
  final String? activeCallId;

  const SelectCallContactScreen({
    super.key,
    this.isAddParticipantMode = false,
    this.isFavoriteMode = false,
    this.activeCallId,
  });

  @override
  State<SelectCallContactScreen> createState() => _SelectCallContactScreenState();
}

class _SelectCallContactScreenState extends State<SelectCallContactScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _registeredUsers = [];
  List<Contact> _unregisteredContacts = [];

  void _initiateCall(Map<String, dynamic> targetUser, bool isVideo) {
    if (!widget.isAddParticipantMode && !CallOverlayManager().canStartNewCall(context)) return;

    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.id;
    final currentUserName = authService.currentUser?.userMetadata?['name'] ?? 'Unknown';

    if (currentUserId == null) return;

    final targetUserId = targetUser['id'];
    final targetUserName = targetUser['contact_name'] ?? targetUser['name'] ?? 'Unknown';

    final callId = 'call_${DateTime.now().millisecondsSinceEpoch}';
    final data = ZegoCallInvitationData(
      timeoutSeconds: 60,
      callID: callId,
      invitationID: callId,
      type: isVideo ? ZegoCallType.videoCall : ZegoCallType.voiceCall,
      customData: '',
      inviter: ZegoUIKitUser(id: currentUserId.replaceAll('-', ''), name: currentUserName),
      invitees: [ZegoUIKitUser(id: targetUserId.replaceAll('-', ''), name: targetUserName)],
    );

    if (isVideo) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoCallScreen(invitationData: data)));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(invitationData: data)));
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _fetchContacts() async {
    try {
      var status = await Permission.contacts.status;
      if (status.isDenied) status = await Permission.contacts.request();

      if (status.isGranted) {
        final chatService = context.read<ChatService>();
        final result = await chatService.syncDeviceContacts();

        if (mounted) {
          setState(() {
            _registeredUsers = result.registeredUsers;
            _unregisteredContacts = result.unregisteredContacts;
            _isLoading = false;
          });
        }
      } else if (status.isPermanentlyDenied) {
        if (mounted) {
          setState(() => _isLoading = false);
          PermissionUtils.showPermissionDialog(context, 'Contacts');
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error fetching contacts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _inviteContact(Contact contact) async {
    if (contact.phones.isEmpty) return;
    final phone = contact.phones.first.number;
    final uri = Uri.parse('sms:$phone?body=Hey! Join me on Twibee app for secure messaging and calls. Download here: https://Twibee.app/dl');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    const bgColor = Color(0xFFF2F2F7);
    return Scaffold(
      backgroundColor: bgColor,
      appBar: TwibeeAppBar(
        title: widget.isAddParticipantMode ? 'Add participant' : widget.isFavoriteMode ? 'Select favorite' : 'Select contact',
        subtitle: _isLoading ? null : '${_registeredUsers.length} contacts',
        actions: [
          IconButton(icon: const Icon(Icons.search, color: AppColors.dark), onPressed: () {}),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      if (!widget.isAddParticipantMode && !widget.isFavoriteMode) ...[
                        _buildActionTile(Icons.link, 'New call link'),
                        _buildActionTile(Icons.person_add, 'New contact'),
                        _buildActionTile(Icons.group_add, 'New group call'),
                      ],
                      const Padding(
                        padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('Contacts on Twibee', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Registered Users
                if (_registeredUsers.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final user = _registeredUsers[index];
                        final name = user['contact_name'] ?? user['name'] ?? 'Unknown';
                        final about = user['about'] ?? 'Available';
                        final avatarUrl = user['avatar_url'];
                        
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.grey2,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.white) : null,
                          ),
                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                          subtitle: Text(about, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                          trailing: widget.isAddParticipantMode
                              ? TextButton(
                                  onPressed: () {
                                    if (widget.activeCallId != null) {
                                      import_call_log_service.CallLogService().addParticipant(
                                        callId: widget.activeCallId!,
                                        userId: user['id'],
                                      );
                                      // TODO: Call Zego API to actually invite the user to the current room
                                    }
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invited $name to the call')));
                                  },
                                  child: const Text('Add', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                                )
                              : widget.isFavoriteMode ? TextButton(
                                  onPressed: () async {
                                    await context.read<ChatService>().addFavorite(user['id']);
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name added to favorites')));
                                  },
                                  child: const Text('Favorite', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                                ) : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.call, color: AppColors.green),
                                      onPressed: () => _initiateCall(user, false),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.videocam, color: AppColors.green),
                                      onPressed: () => _initiateCall(user, true),
                                    ),
                                  ],
                                ),
                        );
                      },
                      childCount: _registeredUsers.length,
                    ),
                  )
                else
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(child: Text('No Twibee users found', style: TextStyle(color: AppColors.grey))),
                    ),
                  ),

                // Invite to Twibee Section
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(left: 16, top: 24, bottom: 8),
                    child: Text('Invite to Twibee', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),

                if (_unregisteredContacts.isNotEmpty)
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final contact = _unregisteredContacts[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: const CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.grey2,
                            child: Icon(Icons.person, color: AppColors.white),
                          ),
                          title: Text(contact.displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                          trailing: TextButton(
                            onPressed: () => _inviteContact(contact),
                            child: const Text('Invite', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                          ),
                        );
                      },
                      childCount: _unregisteredContacts.length,
                    ),
                  ),
                
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
    );
  }

  Widget _buildActionTile(IconData icon, String title) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.green,
        child: Icon(icon, color: AppColors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title - coming soon')));
      },
    );
  }
}

