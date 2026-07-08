import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'package:intl/intl.dart';
import 'individual_chat_screen.dart';
import 'group_info_screen.dart';
import 'lists_screen.dart';

import 'package:flutter_slidable/flutter_slidable.dart';

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  final Set<String> _locallyUnarchivedIds = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Archived'),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: context.read<ChatService>().getArchivedChatsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.orange));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final chats = List<Map<String, dynamic>>.from(snapshot.data ?? []);
          chats.removeWhere((c) => _locallyUnarchivedIds.contains(c['id']));

          if (chats.isEmpty) {
            return const Center(
              child: Text('No archived chats',
                  style: TextStyle(color: AppColors.grey)),
            );
          }

          return ListView.builder(
            itemCount: chats.length,
            itemBuilder: (context, index) {
              final chat = chats[index];
              final isGroup = chat['is_group'] ?? false;

              String name = 'Unknown';
              String avatarText = '?';
              String? otherUserId;

              if (isGroup) {
                name = chat['group_name'] ?? 'Group Chat';
                avatarText = name[0].toUpperCase();
              } else {
                final otherUser = chat['other_user'];
                if (otherUser != null) {
                  name = otherUser['name'] ?? 'Unknown';
                  avatarText = name[0].toUpperCase();
                  otherUserId = otherUser['id'] as String?;
                }
                // Fallback: use other_user_id from unified chats RPC
                otherUserId ??= chat['other_user_id'] as String?;
              }

              final lastMessage = chat['last_message'];
              String messageText = 'Say hi! 👋';

              if (lastMessage != null) {
                messageText = lastMessage['content'] ?? '...';
                if (isGroup &&
                    lastMessage['sender_name'] != null &&
                    lastMessage['sender_name'].isNotEmpty) {
                  messageText = '${lastMessage['sender_name']}: $messageText';
                }
              }

              String timeText = '';
              if (chat['last_message_at'] != null) {
                final time = DateTime.parse(chat['last_message_at']).toLocal();
                timeText = DateFormat('hh:mm a').format(time);
              }

              int unreadCount = chat['unread_count'] ?? 0;
              bool isMuted = chat['is_muted'] ?? false;

              return Slidable(
                key: Key(chat['id']),
                endActionPane: ActionPane(
                  motion: const ScrollMotion(),
                  extentRatio: 0.5,
                  children: [
                    SlidableAction(
                      onPressed: (context) {
                        _showArchivedContextMenu(
                          context: context,
                          chatId: chat['id'],
                          name: name,
                          isMuted: isMuted,
                          unreadCount: unreadCount,
                        );
                      },
                      backgroundColor: AppColors.dark,
                      foregroundColor: Colors.white,
                      icon: Icons.more_horiz,
                      label: 'More',
                    ),
                    SlidableAction(
                      onPressed: (context) {
                        setState(() => _locallyUnarchivedIds.add(chat['id']));
                        context
                            .read<ChatService>()
                            .archiveChat(chat['id'], false);
                      },
                      backgroundColor: AppColors.blue,
                      foregroundColor: Colors.white,
                      icon: Icons.unarchive,
                      label: 'Unarchive',
                    ),
                  ],
                ),
                child: ListTile(
                  onTap: () {
                    if (isGroup) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GroupInfoScreen(
                            chatId: chat['id'],
                            groupName: name,
                            groupAvatarUrl: chat['group_avatar_url'],
                          ),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IndividualChatScreen(
                            chatId: chat['id'],
                            chatName: name,
                            otherUserId: otherUserId, // PERMANENT FIX: pass otherUserId
                          ),
                        ),
                      );
                    }
                  },
                  onLongPress: () {
                    _showArchivedContextMenu(
                      context: context,
                      chatId: chat['id'],
                      name: name,
                      isMuted: isMuted,
                      unreadCount: unreadCount,
                    );
                  },
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.grey,
                    child: Text(
                      avatarText,
                      style: const TextStyle(
                          color: AppColors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(name, style: AppTextStyles.title),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      messageText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.subtitle,
                    ),
                  ),
                  trailing: Text(timeText,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.grey2)),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showArchivedContextMenu({
    required BuildContext context,
    required String chatId,
    required String name,
    required bool isMuted,
    required int unreadCount,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                ListTile(
                  leading: Icon(
                      unreadCount > 0
                          ? Icons.mark_chat_read
                          : Icons.mark_chat_unread,
                      color: AppColors.dark),
                  title: Text(
                      unreadCount > 0 ? 'Mark as read' : 'Mark as unread',
                      style: const TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.read<ChatService>().markChatRead(chatId);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(unreadCount > 0
                            ? 'Marked as read'
                            : 'Marked as unread')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.unarchive, color: AppColors.dark),
                  title: const Text('Unarchive',
                      style: TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    setState(() => _locallyUnarchivedIds.add(chatId));
                    context.read<ChatService>().archiveChat(chatId, false);
                  },
                ),
                ListTile(
                  leading: Icon(isMuted ? Icons.volume_up : Icons.volume_off,
                      color: AppColors.dark),
                  title: Text(isMuted ? 'Unmute' : 'Mute',
                      style: const TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content:
                            Text(isMuted ? 'Chat unmuted' : 'Chat muted')));
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.lock_outline, color: AppColors.dark),
                  title: const Text('Lock chat',
                      style: TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    final success =
                        await context.read<ChatService>().lockChat(chatId);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat locked.')));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Authentication failed. Please set up a screen lock.')));
                    }
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.favorite_border, color: AppColors.dark),
                  title: const Text('Add to Favorites',
                      style: TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Added to Favorites')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.list_alt, color: AppColors.dark),
                  title: const Text('Add to list',
                      style: TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ListsScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.block, color: AppColors.dark),
                  title: Text('Block $name',
                      style: const TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Blocked $name')));
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.cancel_outlined, color: AppColors.dark),
                  title: const Text('Clear chat',
                      style: TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.read<ChatService>().clearChat(chatId);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.delete_outline, color: AppColors.red),
                  title: const Text('Delete chat',
                      style: TextStyle(
                          color: AppColors.red, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    context.read<ChatService>().deleteChat(chatId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

