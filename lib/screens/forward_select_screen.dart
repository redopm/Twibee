import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'package:flutter/services.dart';

class ForwardSelectScreen extends StatefulWidget {
  final Map<String, dynamic> message;
  final String currentChannelId;

  const ForwardSelectScreen({
    super.key,
    required this.message,
    required this.currentChannelId,
  });

  @override
  State<ForwardSelectScreen> createState() => _ForwardSelectScreenState();
}

class _ForwardSelectScreenState extends State<ForwardSelectScreen> {
  late final ChatService _chatService;
  List<Map<String, dynamic>> _recentChats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _loadRecents();
  }

  Future<void> _loadRecents() async {
    try {
      final chats = await _chatService.getChatsStream().first;
      if (mounted) {
        setState(() {
          _recentChats = chats.where((c) => c['id'] != widget.currentChannelId).toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading recent chats: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forwardTo(Map<String, dynamic> targetChat) async {
    // Show loading
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    
    try {
      final isGroup = targetChat['is_group'] == true;
      final targetName = isGroup ? (targetChat['group_name'] ?? 'Group Chat') : (targetChat['other_user']?['name'] ?? 'Chat');

      await _chatService.sendMessage(
        chatId: targetChat['id'],
        content: widget.message['content']?.toString(),
        messageType: widget.message['message_type']?.toString() ?? 'text',
        mediaUrl: widget.message['media_url']?.toString(),
        forwardedFromId: widget.message['id']?.toString(),
      );

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context); // close dialog
        Navigator.pop(context); // close screen
        messenger.showSnackBar(SnackBar(content: Text('Forwarded to $targetName')));
      }
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(SnackBar(content: Text('Failed to forward: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String deepLink = 'Twibee://channel/${widget.currentChannelId}/post/${widget.message['id']}';
    final contentText = widget.message['content']?.toString() ?? 'Media message';

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Forward to...'),
      body: Column(
        children: [
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.copy,
                  label: 'Copy Link',
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: deepLink));
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link Copied!')));
                      Navigator.pop(context);
                    }
                  },
                ),
                _buildActionButton(
                  icon: Icons.share,
                  label: 'Share',
                  onTap: () {
                    Share.share(contentText);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Recent Chats', style: TextStyle(color: AppColors.grey2, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _recentChats.isEmpty
                    ? const Center(child: Text('No recent chats found.', style: TextStyle(color: AppColors.grey)))
                    : ListView.builder(
                        itemCount: _recentChats.length,
                        itemBuilder: (context, index) {
                          final chat = _recentChats[index];
                          final isGroup = chat['is_group'] == true;
                          final name = isGroup 
                              ? (chat['group_name'] ?? 'Group Chat') 
                              : (chat['other_user']?['name'] ?? 'Chat');
                          final avatarUrl = isGroup 
                              ? chat['group_avatar_url'] 
                              : chat['other_user']?['avatar_url'];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                              child: avatarUrl == null ? Text(name.isNotEmpty ? name.characters.first.toUpperCase() : '?', style: const TextStyle(color: AppColors.orange)) : null,
                            ),
                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            onTap: () => _forwardTo(chat),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.lightGrey,
              child: Icon(icon, color: AppColors.dark),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppColors.dark, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

