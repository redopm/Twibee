import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../theme.dart';
import '../../services/chat_service.dart';
import '../../services/channel_service.dart';

class PinnedMessagesBanner extends StatefulWidget {
  final List<Map<String, dynamic>> pinnedMessages;
  final String chatId;
  final bool isChannel;
  final ScrollController scrollController;
  final List<dynamic>? allMessages; // Only needed to calculate index for scrolling
  final void Function(String messageId)? onUnpin;

  const PinnedMessagesBanner({
    super.key,
    required this.pinnedMessages,
    required this.chatId,
    this.isChannel = false,
    required this.scrollController,
    this.allMessages,
    this.onUnpin,
  });

  @override
  State<PinnedMessagesBanner> createState() => _PinnedMessagesBannerState();
}

class _PinnedMessagesBannerState extends State<PinnedMessagesBanner> {
  int _currentIndex = 0;

  void _scrollToMessage(Map<String, dynamic> message) {
    if (widget.allMessages == null) return;
    final index = widget.allMessages!.indexWhere((m) {
      if (m is List) return m.any((i) => i['id'] == message['id']);
      return m['id'] == message['id'];
    });

    if (index != -1) {
      widget.scrollController.animateTo(
        index * 60.0, // rough estimate, but ensures we scroll up
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _unpinMessage(String messageId) async {
    if (widget.isChannel) {
      await ChannelService().togglePin(messageId, false, widget.chatId);
    } else {
      await context.read<ChatService>().togglePin(messageId, false, widget.chatId);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message unpinned')));
      widget.onUnpin?.call(messageId);
      if (_currentIndex >= widget.pinnedMessages.length - 1) {
        setState(() {
          _currentIndex = 0;
        });
      }
    }
  }

  Widget _buildMediaThumbnail(Map<String, dynamic> message) {
    final type = message['message_type'];
    final content = message['content']?.toString() ?? '';

    if (type == 'image' || type == 'video') {
      if (content.startsWith('http')) {
        return Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: AppColors.grey2,
            borderRadius: BorderRadius.circular(6),
            image: DecorationImage(
              image: CachedNetworkImageProvider(content),
              fit: BoxFit.cover,
            ),
          ),
          child: type == 'video'
              ? const Icon(Icons.play_circle_fill, color: Colors.white, size: 20)
              : null,
        );
      }
      return Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.grey2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(type == 'video' ? Icons.videocam : Icons.image, color: AppColors.grey, size: 20),
      );
    } else if (type == 'document' || type == 'audio' || type == 'voice') {
      return Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          type == 'document' ? Icons.insert_drive_file : (type == 'audio' ? Icons.audiotrack : Icons.mic),
          color: AppColors.blue,
          size: 20,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  void _showAllPinnedMessages() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey2,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pinned Messages',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark)),
                    Text('${widget.pinnedMessages.length}',
                        style: const TextStyle(fontSize: 14, color: AppColors.grey)),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.pinnedMessages.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (context, index) {
                    final msg = widget.pinnedMessages[index];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        _scrollToMessage(msg);
                      },
                      leading: _buildMediaThumbnail(msg),
                      title: Text(
                        msg['content']?.toString().trim().isNotEmpty == true
                            ? msg['content'].toString()
                            : (msg['message_type'] != 'text'
                                ? msg['message_type'].toString().toUpperCase()
                                : 'Message'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, color: AppColors.dark),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close, color: AppColors.grey, size: 20),
                        onPressed: () {
                          Navigator.pop(context);
                          _unpinMessage(msg['id']);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pinnedMessages.isEmpty) {
      return const SizedBox.shrink();
    }

    // Ensure index is valid (messages might have been unpinned)
    if (_currentIndex >= widget.pinnedMessages.length) {
      _currentIndex = 0;
    }

    final currentMessage = widget.pinnedMessages[_currentIndex];

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () {
          _scrollToMessage(currentMessage);
          // Cycle to next pin
          if (widget.pinnedMessages.length > 1) {
            setState(() {
              _currentIndex = (_currentIndex + 1) % widget.pinnedMessages.length;
            });
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: const Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Row(
            children: [
              Container(width: 3, height: 36, color: AppColors.orange),
              const SizedBox(width: 8),
              _buildMediaThumbnail(currentMessage),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.pinnedMessages.length > 1 ? 'Pinned Message #${_currentIndex + 1}' : 'Pinned Message',
                      style: const TextStyle(color: AppColors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      currentMessage['content']?.toString().trim().isNotEmpty == true
                          ? currentMessage['content'].toString()
                          : (currentMessage['message_type'] != 'text'
                              ? currentMessage['message_type'].toString().toUpperCase()
                              : 'Message'),
                      style: const TextStyle(color: AppColors.dark, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (widget.pinnedMessages.length > 1)
                IconButton(
                  icon: const Icon(Icons.list, color: AppColors.grey),
                  onPressed: _showAllPinnedMessages,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              else
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.grey, size: 20),
                  onPressed: () => _unpinMessage(currentMessage['id']),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
