import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import '../theme.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import 'package:provider/provider.dart';
import 'call_overlay_manager.dart';

class CallInfoScreen extends StatelessWidget {
  final String displayName;
  final String avatarUrl;
  final String displayStatus;
  final IconData statusIcon;
  final Color statusColor;
  final String timeText;
  final String durationText;
  final String callTargetId;
  final bool isVideo;

  const CallInfoScreen({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.displayStatus,
    required this.statusIcon,
    required this.statusColor,
    required this.timeText,
    required this.durationText,
    required this.callTargetId,
    required this.isVideo,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Call Info'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Avatar
            CircleAvatar(
              radius: 64,
              backgroundColor: avatarUrl.isEmpty
                  ? AppColors.orange.withValues(alpha: 0.2)
                  : Colors.transparent,
              backgroundImage:
                  avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl.isEmpty
                  ? Text(
                      displayName.isNotEmpty
                          ? displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: AppColors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 48),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            // Name
            Text(
              displayName,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // Quick Actions
            if (callTargetId.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionBtn(
                    icon: Icons.call,
                    label: 'Voice',
                    color: AppColors.orange,
                    onTap: () {},
                    child: IconButton(
                      icon: const Icon(Icons.call,
                          color: AppColors.orange, size: 32),
                      onPressed: () {
                        final callId =
                            'call_${DateTime.now().millisecondsSinceEpoch}';
                        final data = ZegoCallInvitationData(
                          timeoutSeconds: 60,
                          callID: callId,
                          invitationID: callId,
                          type: ZegoCallType.voiceCall,
                          customData: '',
                          inviter: ZegoUIKitUser(id: 'you', name: 'You'),
                          invitees: [
                            ZegoUIKitUser(id: callTargetId.replaceAll('-', ''), name: displayName)
                          ],
                        );
                        if (!CallOverlayManager().canStartNewCall(context)) return;
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    VoiceCallScreen(invitationData: data)));
                      },
                    ),
                  ),
                  const SizedBox(width: 32),
                  _buildActionBtn(
                    icon: Icons.videocam,
                    label: 'Video',
                    color: AppColors.orange,
                    onTap: () {},
                    child: IconButton(
                      icon: const Icon(Icons.videocam,
                          color: AppColors.orange, size: 32),
                      onPressed: () {
                        final callId =
                            'call_${DateTime.now().millisecondsSinceEpoch}';
                        final data = ZegoCallInvitationData(
                          timeoutSeconds: 60,
                          callID: callId,
                          invitationID: callId,
                          type: ZegoCallType.videoCall,
                          customData: '',
                          inviter: ZegoUIKitUser(id: 'you', name: 'You'),
                          invitees: [
                            ZegoUIKitUser(id: callTargetId.replaceAll('-', ''), name: displayName)
                          ],
                        );
                        if (!CallOverlayManager().canStartNewCall(context)) return;
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    VideoCallScreen(invitationData: data)));
                      },
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 32),
            const Divider(color: AppColors.lightGrey, thickness: 8),

            // Call Details
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Call Details',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.dark)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(statusIcon, color: statusColor, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayStatus,
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: statusColor),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(isVideo ? Icons.videocam : Icons.call,
                                    size: 14, color: AppColors.grey),
                                const SizedBox(width: 6),
                                Text(timeText,
                                    style: const TextStyle(
                                        color: AppColors.grey, fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (durationText.isNotEmpty)
                        Text(
                          durationText,
                          style: const TextStyle(
                              color: AppColors.dark,
                              fontWeight: FontWeight.w600,
                              fontSize: 14),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBtn(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap,
      Widget? child}) {
    return Column(
      children: [
        if (child != null)
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(child: child),
          )
        else
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                color: AppColors.dark,
                fontSize: 12,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

