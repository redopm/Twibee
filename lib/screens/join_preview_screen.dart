import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/chat_service.dart';
import '../../theme.dart';
import 'individual_chat_screen.dart';
import 'channel_chat_screen.dart';

class JoinPreviewScreen extends StatefulWidget {
  final String inviteCode;

  const JoinPreviewScreen({super.key, required this.inviteCode});

  @override
  State<JoinPreviewScreen> createState() => _JoinPreviewScreenState();
}

class _JoinPreviewScreenState extends State<JoinPreviewScreen> {
  bool _isLoading = true;
  bool _isJoining = false;
  Map<String, dynamic>? _groupInfo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchGroupInfo();
  }

  Future<void> _fetchGroupInfo() async {
    final info = await context.read<ChatService>().getGroupInfoByInviteCode(widget.inviteCode);
    if (mounted) {
      setState(() {
        _groupInfo = info;
        _isLoading = false;
        if (info == null) {
          _error = 'Invalid or expired invite link.';
        }
      });
    }
  }

  Future<void> _joinGroup() async {
    if (_groupInfo == null) return;
    setState(() => _isJoining = true);
    
    final success = await context.read<ChatService>().joinViaInviteCode(widget.inviteCode);
    
    if (mounted) {
      setState(() => _isJoining = false);
      if (success) {
        // Navigate to the chat
        Navigator.pop(context); // close preview
        if (_groupInfo!['is_channel'] == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChannelChatScreen(channel: _groupInfo!),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IndividualChatScreen(
                chatId: _groupInfo!['id'],
                chatName: _groupInfo!['name'],
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to join. You might already be a member.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Join'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: AppColors.grey),
                        const SizedBox(height: 16),
                        Text(_error!, style: const TextStyle(fontSize: 16, color: AppColors.dark)),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
                          child: const Text('Go Back', style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Spacer(),
                      CircleAvatar(
                        radius: 64,
                        backgroundColor: AppColors.lightGrey,
                        backgroundImage: _groupInfo!['avatar_url'] != null ? NetworkImage(_groupInfo!['avatar_url']) : null,
                        child: _groupInfo!['avatar_url'] == null
                            ? const Icon(Icons.group, size: 64, color: AppColors.grey)
                            : null,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _groupInfo!['name'] ?? 'Unknown Group',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.dark),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _groupInfo!['is_channel'] == true ? 'Channel' : 'Group',
                        style: const TextStyle(fontSize: 16, color: AppColors.orange),
                      ),
                      if (_groupInfo!['description'] != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          _groupInfo!['description'],
                          style: const TextStyle(color: AppColors.grey),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isJoining ? null : _joinGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _isJoining
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text('Join Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}

