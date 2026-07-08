import 'package:twibee/widgets/gradient_fab.dart';
import 'package:twibee/widgets/hexagon_avatar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../services/auth_service.dart';
import '../utils/permission_utils.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import 'call_overlay_manager.dart';

class CreateGroupCallScreen extends StatefulWidget {
  const CreateGroupCallScreen({super.key});

  @override
  State<CreateGroupCallScreen> createState() => _CreateGroupCallScreenState();
}

class _CreateGroupCallScreenState extends State<CreateGroupCallScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _registeredUsers = [];
  final Set<String> _selectedUserIds = {};

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _initiateGroupCall(bool isVideo) {
    if (!CallOverlayManager().canStartNewCall(context)) return;

    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.id;
    final currentUserName = authService.currentUser?.userMetadata?['name'] ?? 'Unknown';

    if (currentUserId == null || _selectedUserIds.isEmpty) return;

    final invitees = _registeredUsers
        .where((user) => _selectedUserIds.contains(user['id']))
        .map((user) => ZegoUIKitUser(
              id: user['id'].toString().replaceAll('-', ''),
              name: user['contact_name'] ?? user['name'] ?? 'Unknown',
            ))
        .toList();

    final callId = 'group_call_${DateTime.now().millisecondsSinceEpoch}';
    final data = ZegoCallInvitationData(
      timeoutSeconds: 60,
      callID: callId,
      invitationID: callId,
      type: isVideo ? ZegoCallType.videoCall : ZegoCallType.voiceCall,
      customData: '',
      inviter: ZegoUIKitUser(id: currentUserId.replaceAll('-', ''), name: currentUserName),
      invitees: invitees,
    );

    if (isVideo) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VideoCallScreen(invitationData: data)));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => VoiceCallScreen(invitationData: data)));
    }
  }

  void _showCallTypeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Start Group Call', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.dark)),
              ),
              ListTile(
                leading: const HexagonAvatar(backgroundColor: AppColors.lightGrey, child: Icon(Icons.videocam, color: AppColors.green)),
                title: const Text('Video Call'),
                onTap: () {
                  Navigator.pop(context);
                  _initiateGroupCall(true);
                },
              ),
              ListTile(
                leading: const HexagonAvatar(backgroundColor: AppColors.lightGrey, child: Icon(Icons.call, color: AppColors.green)),
                title: const Text('Voice Call'),
                onTap: () {
                  Navigator.pop(context);
                  _initiateGroupCall(false);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'New Group Call',
        subtitle: _selectedUserIds.isNotEmpty ? '${_selectedUserIds.length} selected' : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.green))
          : _registeredUsers.isEmpty
              ? const Center(child: Text('No Twibee users found', style: TextStyle(color: AppColors.grey)))
              : ListView.builder(
                  itemCount: _registeredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _registeredUsers[index];
                    final userId = user['id'];
                    final name = user['contact_name'] ?? user['name'] ?? 'Unknown';
                    final about = user['about'] ?? 'Available';
                    final avatarUrl = user['avatar_url'];
                    final isSelected = _selectedUserIds.contains(userId);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Stack(
                        children: [
                          HexagonAvatar(
                            radius: 24,
//                             backgroundColor: AppColors.grey2,
                            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                            child: avatarUrl == null ? const Icon(Icons.person, color: AppColors.white) : null,
                          ),
                          if (isSelected)
                            const Positioned(
                              bottom: 0,
                              right: 0,
                              child: HexagonAvatar(
                                radius: 10,
//                                 backgroundColor: AppColors.green,
                                child: Icon(Icons.check, color: AppColors.white, size: 12),
                              ),
                            ),
                        ],
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark)),
                      subtitle: Text(about, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedUserIds.remove(userId);
                          } else {
                            _selectedUserIds.add(userId);
                          }
                        });
                      },
                    );
                  },
                ),
      floatingActionButton: _selectedUserIds.isNotEmpty
          ? GradientFab(
              onPressed: _showCallTypeSheet,
//               backgroundColor: AppColors.green,
              child: const Icon(Icons.check, color: AppColors.white),
            )
          : null,
    );
  }
}

