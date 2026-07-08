import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'forward_select_screen.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import '../theme.dart';
import '../services/channel_service.dart';
import '../services/channel_preferences.dart';
import 'channel_info_screen.dart';
import '../services/chat_service.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/chat/voice_recorder_bar.dart';
import '../widgets/chat/pinned_messages_banner.dart';
import '../widgets/chat/message_bubble_widget.dart';
import '../widgets/chat/attachment_menu.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:file_picker/file_picker.dart';
import 'location_picker_screen.dart';
import 'share_contacts_screen.dart';
import 'create_poll_screen.dart';
import 'image_viewer_screen.dart';
import 'map_viewer_screen.dart';
import 'pdf_viewer_screen.dart';
import 'video_viewer_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'individual_chat_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

class ChannelChatScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const ChannelChatScreen({super.key, required this.channel});

  @override
  State<ChannelChatScreen> createState() => _ChannelChatScreenState();
}

class _ChannelChatScreenState extends State<ChannelChatScreen> {
  final ChannelService _channelService = ChannelService();
  final TextEditingController _postController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSearching = false;
  String _searchQuery = '';
  
  late Map<String, dynamic> _channel;
  List<Map<String, dynamic>> _posts = [];
  
  bool _isLoadingPosts = true;
  bool _isAdminOrOwner = false;
  bool _isPosting = false;
  bool _isMuted = false;
  bool _isTyping = false;
  
  // Voice Recording State
  bool _isRecording = false;
  
  final Set<String> _viewedMessageIds = {};
  final Set<String> _starredMessageIds = {};
  
  Map<String, dynamic>? _replyingToMessage;
  
  Timer? _presenceTimer;
  int _messageLimit = 50;
  bool _isLoadingOlder = false;
  
  RealtimeChannel? _realtimeChannel;

  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _presenceChannel;
  int _onlineCount = 0;

  RealtimeChannel? _typingChannel;
  String _typingUserName = '';
  Timer? _typingTimer;
  DateTime _lastTypingTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _channel = Map<String, dynamic>.from(widget.channel);
    _loadStarredMessages();
    _postController.addListener(() {
      final text = _postController.text;
      setState(() {
        _isTyping = text.isNotEmpty;
      });

      if (text.isNotEmpty && DateTime.now().difference(_lastTypingTime).inSeconds > 2) {
        _lastTypingTime = DateTime.now();
        final currentUserName = _channelService.currentUserName ?? 'Someone';
        _typingChannel?.sendBroadcastMessage(
          event: 'is_typing',
          payload: {
            'user_id': _supabase.auth.currentUser!.id,
            'user_name': currentUserName,
          },
        );
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 300 && !_showScrollToBottom) {
        if (mounted) setState(() => _showScrollToBottom = true);
      } else if (_scrollController.position.pixels <= 300 && _showScrollToBottom) {
        if (mounted) setState(() => _showScrollToBottom = false);
      }
    });

    _init();
    _setupPresence();
    _setupTypingIndicator();
  }

  void _setupTypingIndicator() {
    _typingChannel = _supabase.channel('typing:channel_${widget.channel['id']}');

    _typingChannel!.onBroadcast(
      event: 'is_typing',
      callback: (payload) {
        if (payload['user_id'] != _supabase.auth.currentUser!.id) {
          if (mounted) {
            setState(() {
              _typingUserName = payload['user_name'];
            });
          }
          
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _typingUserName = '');
          });
        }
      },
    ).subscribe();
  }

  void _setupPresence() {
    _presenceChannel = _supabase.channel('presence:channel_${widget.channel['id']}');

    _presenceChannel!.onPresenceSync((payload) {
      final onlineUsers = _presenceChannel!.presenceState();
      if (mounted) {
        setState(() {
          _onlineCount = onlineUsers.length;
        });
      }
    });

    _presenceChannel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({
          'user_id': _supabase.auth.currentUser!.id,
        });
      }
    });
  }

  Future<void> _loadStarredMessages() async {
    final ids = await context.read<ChatService>().getStarredMessageIds();
    if (mounted) {
      setState(() {
        _starredMessageIds.addAll(ids);
      });
    }
  }

  @override
  void dispose() {
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }
    if (_typingChannel != null) {
      _supabase.removeChannel(_typingChannel!);
    }
    _typingTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    _presenceTimer?.cancel();
    _postController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && !_isLoadingOlder) {
      setState(() {
        _isLoadingOlder = true;
        _messageLimit += 50;
        _fetchPosts();
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isLoadingOlder = false);
      });
    }
  }

  void _startPresencePinger() {
    context.read<ChatService>().pingOnlineStatus(_channel['id'], isChannel: true);
    _presenceTimer = Timer.periodic(const Duration(minutes: 4), (_) {
      context.read<ChatService>().pingOnlineStatus(_channel['id'], isChannel: true);
    });
  }
  Future<void> _fetchPosts() async {
    final channelId = _channel['id'] as String;
    final currentUserId = _channelService.currentUserId;

    try {
      final isBanned = await _channelService.isBanned(channelId);
      if (isBanned && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Banned'),
            content: const Text('You have been banned from this channel.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      final results = await Future.wait([
        _channelService.getPosts(channelId, limit: _messageLimit),
        _channelService.isAdmin(channelId),
        _channelService.getSubscribers(channelId),
      ]);

      final posts = results[0] as List<Map<String, dynamic>>;
      final isAdmin = results[1] as bool;
      final subscribers = results[2] as List<Map<String, dynamic>>;
      final isOwner = _channel['owner_id'] == currentUserId;

      if (mounted) {
        setState(() {
          _posts = posts;
          _isAdminOrOwner = isAdmin || isOwner;
          _isLoadingPosts = false;
          _channel['subscriber_count'] = subscribers.length;
        });
      }
    } catch (e) {
      debugPrint('Channel init error: $e');
      if (mounted) {
        setState(() => _isLoadingPosts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load messages: $e'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () {
                setState(() => _isLoadingPosts = true);
                _fetchPosts();
              },
            ),
          ),
        );
      }
    }
  }

  Future<void> _init() async {
    await _fetchPosts();
    final channelId = _channel['id'] as String;
    _realtimeChannel = _channelService.subscribeToChannelPosts(
      channelId,
      (newPost) {
        if (!mounted) return;
        final existingIndex = _posts.indexWhere((p) => p['id'] == newPost['id']);

        setState(() {
          if (existingIndex != -1) {
            final existing = _posts[existingIndex];
            final merged = Map<String, dynamic>.from(newPost);
            
            if (existing['reply_to'] != null) {
              merged['reply_to'] = existing['reply_to'];
            }
            _posts[existingIndex] = merged;
          } else {
            _posts.insert(0, newPost);
          }
        });
      },
    );
  }

  Future<void> _createPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isPosting = true);
    
    final replyId = _replyingToMessage?['id'];
    final replySnapshot = _replyingToMessage != null 
        ? Map<String, dynamic>.from(_replyingToMessage!) 
        : null;
    
    try {
      final newPost = await _channelService.createPost(
        channelId: _channel['id'],
        text: text,
        replyToId: replyId,
      );
      
      _postController.clear();
      setState(() {
        _isTyping = false;
        _replyingToMessage = null;
      });

      _insertOptimisticPost(newPost, replySnapshot);
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _insertOptimisticPost(Map<String, dynamic> newPost, Map<String, dynamic>? replySnapshot) {
    if (!mounted || newPost['id'] == null) return;
    
    final existingIndex = _posts.indexWhere((p) => p['id'] == newPost['id']);
    final enrichedPost = Map<String, dynamic>.from(newPost);
    
    if (replySnapshot != null) {
      enrichedPost['reply_to'] = [replySnapshot]; 
    }
    
    if (existingIndex != -1) {
      setState(() => _posts[existingIndex] = enrichedPost);
    } else {
      setState(() => _posts.insert(0, enrichedPost));
    }
  }

  Future<void> _deletePost(String postId) async {
    try {
      await _channelService.deletePost(postId);
      setState(() => _posts.removeWhere((p) => p['id'] == postId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  void _showDeletePostDialog(String postId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deletePost(postId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }


  void _showMessageOptions(Map<String, dynamic> post) {
    final type = post['message_type'] ?? 'text';
    final mediaUrl = post['media_url'];
    final postId = post['id'];
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: ['👍', '❤️', '😂', '😮', '😢', '👏'].map((emoji) {
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await _channelService.addReaction(postId, emoji);
                          if (mounted) {
                            setState(() {
                              final reactions = List<Map<String, dynamic>>.from(post['message_reactions'] ?? []);
                              final currentUserId = _channelService.currentUserId;
                              
                              final exactMatch = reactions.any((r) => r['user_id'] == currentUserId && r['emoji'] == emoji);
                              
                              reactions.removeWhere((r) => r['user_id'] == currentUserId);
                              
                              if (!exactMatch) {
                                reactions.add({'user_id': currentUserId, 'emoji': emoji});
                              }
                              
                              post['message_reactions'] = reactions;
                            });
                          }
                        } catch (e) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add reaction')));
                        }
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAdminOrOwner)
                          _buildOptionItem(Icons.reply, 'Reply', () {
                            Navigator.pop(context);
                            setState(() {
                              _replyingToMessage = post;
                            });
                          }),
                        if (_isAdminOrOwner)
                          _buildOptionItem(post['is_pinned'] == true ? Icons.push_pin : Icons.push_pin_outlined, post['is_pinned'] == true ? 'Unpin' : 'Pin', () async {
                            Navigator.pop(context);
                            final isPinned = post['is_pinned'] == true;
                            await _channelService.togglePin(post['id'], !isPinned, widget.channel['id']);
                            if (mounted) {
                              setState(() {
                                post['is_pinned'] = !isPinned;
                              });
                            }
                          }),
                        _buildOptionItem(
                          _starredMessageIds.contains(post['id']?.toString()) ? Icons.star : Icons.star_border,
                          _starredMessageIds.contains(post['id']?.toString()) ? 'Unstar' : 'Star', 
                          () async {
                            Navigator.pop(context);
                            final msgId = post['id']?.toString();
                            if (msgId != null) {
                              final isCurrentlyStarred = _starredMessageIds.contains(msgId);
                              setState(() {
                                if (isCurrentlyStarred) {
                                  _starredMessageIds.remove(msgId);
                                } else {
                                  _starredMessageIds.add(msgId);
                                }
                              });
                              try {
                                await context.read<ChatService>().starMessage(msgId, !isCurrentlyStarred);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isCurrentlyStarred ? 'Message unstarred' : 'Message starred')));
                              } catch (e) {
                                if (mounted) {
                                  setState(() {
                                    if (isCurrentlyStarred) _starredMessageIds.add(msgId);
                                    else _starredMessageIds.remove(msgId);
                                  });
                                }
                              }
                            }
                          }
                        ),
                        _buildOptionItem(Icons.shortcut, 'Forward', () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => ForwardSelectScreen(
                              message: post,
                              currentChannelId: _channel['id'],
                            ),
                          ));
                        }),
                        _buildOptionItem(Icons.copy, 'Copy Link', () async {
                          Navigator.pop(context);
                          final link = 'Twibee://channel/${_channel['id']}/post/${post['id']}';
                          await Clipboard.setData(ClipboardData(text: link));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                          }
                        }),
                        if (type == 'poll' && _isAdminOrOwner && post['is_closed'] != true)
                          _buildOptionItem(Icons.stop_circle_outlined, 'Stop Quiz', () {
                            Navigator.pop(context);
                            setState(() {
                              post['is_closed'] = true;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Quiz stopped. No more votes allowed.')),
                            );
                          }, color: Colors.red),
                        if (type == 'image' && mediaUrl != null)
                          _buildOptionItem(Icons.save_alt, 'Save Image', () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved')));
                          }),
                        if (type == 'video' && mediaUrl != null)
                          _buildOptionItem(Icons.save_alt, 'Save Video', () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video saved')));
                          }),
                        if (type == 'document' && mediaUrl != null)
                          _buildOptionItem(Icons.save_alt, 'Save Document', () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document saved')));
                          }),
                        _buildOptionItem(Icons.select_all, 'Select', () {
                          Navigator.pop(context);
                        }),
                        if (type == 'text' && _isAdminOrOwner)
                          _buildOptionItem(Icons.edit, 'Edit', () {
                            Navigator.pop(context);
                          }),
                        if (!_isAdminOrOwner)
                          _buildOptionItem(Icons.report_problem_outlined, 'Report', () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message reported')));
                          }, color: Colors.orange),
                        if (_isAdminOrOwner)
                          _buildOptionItem(Icons.delete_outline, 'Delete', () {
                            Navigator.pop(context);
                            _showDeletePostDialog(post['id']);
                          }, color: Colors.red),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildOptionItem(IconData icon, String title, VoidCallback onTap, {Color color = AppColors.dark}) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      onTap: onTap,
      dense: true,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAppBar() {
    if (_isSearching) {
      return AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.dark),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search channel...',
            border: InputBorder.none,
          ),
          onChanged: (val) {
            setState(() {
              _searchQuery = val.toLowerCase();
            });
          },
        ),
      );
    }

    final name = _channel['name'] ?? 'Channel';
    final avatarUrl = _channel['avatar_url'];

    return AppBar(
      backgroundColor: AppColors.white.withValues(alpha: 0.95),
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.black.withValues(alpha: 0.05),
      iconTheme: const IconThemeData(color: AppColors.dark),
      titleSpacing: 0,
      title: GestureDetector(
        onTap: () async {
          final updatedChannel = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChannelInfoScreen(channel: _channel),
            ),
          );
          if (mounted) {
            if (updatedChannel == 'search') {
               setState(() => _isSearching = true);
            } else if (updatedChannel != null) {
              setState(() {
                _channel = updatedChannel;
              });
            }
          }
        },
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.orange.withValues(alpha: 0.15),
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'C',
                      style: const TextStyle(
                          color: AppColors.orange, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _channel['name'] ?? 'Channel',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.dark),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      FutureBuilder<String?>(
                        future: ChannelPreferences.getAutoDelete(_channel['id']),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            return const Padding(
                              padding: EdgeInsets.only(left: 4.0),
                              child: Icon(Icons.access_time, size: 14, color: AppColors.grey),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (_typingUserName.isNotEmpty) ...[
                        Text(
                          '$_typingUserName is typing',
                          style: const TextStyle(fontSize: 12, color: AppColors.orange, fontStyle: FontStyle.italic),
                        ),
                        // Small bounce animation dots can be added here, for now use standard text
                        const Text('...', style: TextStyle(fontSize: 12, color: AppColors.orange, fontStyle: FontStyle.italic)),
                      ] else ...[
                        Text(
                          '${_channel['subscriber_count'] ?? 0} ${_channel['is_group'] == true ? 'members' : 'subscribers'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.grey),
                        ),
                        if (_onlineCount > 0) ...[
                          const Text(' • ', style: TextStyle(color: AppColors.grey, fontSize: 12)),
                          const Icon(Icons.circle, color: Colors.green, size: 8),
                          const SizedBox(width: 4),
                          Text('$_onlineCount online', style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ],
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

  final Map<String, double> _swipeOffsets = {};
  
  Widget _buildPostBubble(Map<String, dynamic> post) {
    final settings = context.watch<SettingsService>();
    final globalThemeId = settings.getSetting('chat_theme_id', defaultValue: 'default');
    final currentThemeId = settings.getSetting('chat_theme_${widget.channel['id']}', defaultValue: globalThemeId);
    final currentTheme = ChatTheme.getTheme(currentThemeId);
    final bubbleColor = Color(settings.getSetting('chat_bubble_color_${widget.channel['id']}', defaultValue: settings.getSetting('chat_bubble_color', defaultValue: currentTheme.bubbleColor.value)));
    final receiverBubbleColor = currentTheme.receiverBubbleColor;
    final senderTextColor = currentTheme.senderTextColor;
    final receiverTextColor = currentTheme.receiverTextColor;

    final currentUserId = context.read<ChatService>().currentUserId;
    final isMe = post['sender_id']?.toString() == currentUserId;
    final currentFont = settings.getSetting('chat_font_${widget.channel['id']}', defaultValue: settings.getSetting('chat_font', defaultValue: 'Inter'));

    String timeText = '';
    if (post['created_at'] != null) {
      final time = DateTime.parse(post['created_at']).toLocal();
      timeText = DateFormat('hh:mm a').format(time);
    }

    Map<String, dynamic>? replyToMsg;
    if (post['reply_to_id'] != null) {
      final parentId = post['reply_to_id'].toString();
      try {
        replyToMsg = _posts.firstWhere((p) => p['id']?.toString() == parentId);
      } catch (_) {}
    }

    Widget messageWidget = MessageBubbleWidget(
      text: post['content'] ?? '',
      time: timeText,
      isMe: isMe,
      viewCount: post['view_count'],
      messageType: post['message_type'] ?? 'text',
      mediaUrl: post['media_url'],
      isForwarded: post['forwarded_from_id'] != null,
      isEdited: post['is_edited'] == true,
      isStarred: _starredMessageIds.contains(post['id']?.toString()),
      messageId: post['id']?.toString(),
      replyMarkup: null,
      rawMsg: post,
      replyToMsg: replyToMsg,
      isGroupedBottom: false,
      bubbleColor: bubbleColor,
      receiverBubbleColor: receiverBubbleColor,
      senderTextColor: senderTextColor,
      receiverTextColor: receiverTextColor,
      timeColor: AppColors.grey,
      isPending: false,
      isRead: false,
      chatName: widget.channel['name'] ?? 'Channel',
      chatId: widget.channel['id'],
      fontFamily: currentFont,
      reactions: List<Map<String, dynamic>>.from(post['message_reactions'] ?? []),
      onReply: (msg) {
        if (_isAdminOrOwner) {
          setState(() => _replyingToMessage = msg);
        }
      },
      onScrollToMessage: (msgId) {
        final index = _posts.indexWhere((p) => p['id']?.toString() == msgId);
        if (index != -1) {
          _scrollController.animateTo(
            index * 60.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      onForward: (msg) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ForwardSelectScreen(
            message: msg,
            currentChannelId: widget.channel['id'],
          ),
        ));
      },
    );

    return Builder(
      builder: (builderContext) {
        return GestureDetector(
          onLongPressStart: (details) {
            _showMessageOptions(post);
          },
          child: messageWidget,
        );
      }
    );
  }
  Widget _buildComposerOrMute() {
    final settings = context.watch<SettingsService>();
    final globalThemeId = settings.getSetting('chat_theme_id', defaultValue: 'default');
    final currentThemeId = settings.getSetting('chat_theme_${widget.channel['id']}', defaultValue: globalThemeId);
    final currentTheme = ChatTheme.getTheme(currentThemeId);
    final currentFont = settings.getSetting('chat_font_${widget.channel['id']}', defaultValue: settings.getSetting('chat_font', defaultValue: 'Inter'));

    if (_isAdminOrOwner) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        color: Colors.transparent,
        child: SafeArea(
          child: _isRecording
              ? VoiceRecorderBar(
                  onCancel: () => setState(() => _isRecording = false),
                  onSend: (path) async {
                    setState(() => _isRecording = false);
                    final file = File(path);
                    if (await file.exists()) {
                      await _channelService.createPost(
                        channelId: _channel['id'],
                        mediaFile: file,
                        mediaType: 'audio',
                        replyToId: _replyingToMessage?['id'],
                      );
                      if (mounted) {
                        setState(() {
                          _replyingToMessage = null;
                        });
                      }
                    }
                  },
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
                IconButton(
                  icon: const Icon(Icons.add_circle, color: AppColors.orange, size: 30),
                  splashRadius: 24,
                  onPressed: () {
                    AttachmentMenuBottomSheet.show(
                      context, 
                      widget.channel['id'],
                      _replyingToMessage?['id']?.toString(), 
                      () {
                        if (mounted) setState(() => _replyingToMessage = null);
                      }, 
                      isChannel: true,
                    );
                  },
                ),
                const SizedBox(width: 4),
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 140),
                  decoration: BoxDecoration(
                    color: currentTheme.receiverBubbleColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _postController,
                    maxLines: 5,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: GoogleFonts.getFont(currentFont, color: currentTheme.receiverTextColor),
                    onChanged: (text) {
                      setState(() {
                        _isTyping = text.trim().isNotEmpty;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Broadcast a message...',
                      hintStyle: GoogleFonts.getFont(currentFont, color: currentTheme.receiverTextColor.withOpacity(0.5), fontSize: 16),
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _isTyping ? (_isPosting ? null : _createPost) : () => setState(() => _isRecording = true),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: _isPosting
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          _isTyping ? Icons.send : Icons.mic,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      final hasDiscussion = _channel['discussion_group_id'] != null;
      final canDM = _channel['direct_messages_enabled'] == true;

      return Container(
        color: AppColors.white,
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    setState(() => _isMuted = !_isMuted);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isMuted ? 'Channel muted' : 'Channel unmuted')),
                    );
                  },
                  child: Container(
                    height: 50,
                    alignment: Alignment.center,
                    child: Text(
                      _isMuted ? 'UNMUTE' : 'MUTE',
                      style: const TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ),
              if (hasDiscussion) ...[
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => IndividualChatScreen(
                          chatId: _channel['discussion_group_id'],
                          chatName: '${_channel['name']} Discussion',
                        ),
                      ));
                    },
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: const Text('DISCUSS', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
              if (canDM) ...[
                Container(width: 1, height: 30, color: AppColors.border),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      try {
                        final chatService = context.read<ChatService>();
                        final ownerId = _channel['owner_id'];
                        final chatId = await chatService.createChat(ownerId);
                        if (mounted) {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => IndividualChatScreen(
                              chatId: chatId,
                              chatName: '${_channel['name']} Admin',
                            ),
                          ));
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
                        }
                      }
                    },
                    child: Container(
                      height: 50,
                      alignment: Alignment.center,
                      child: const Text('MESSAGE', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final globalThemeId = settings.getSetting('chat_theme_id', defaultValue: 'default');
    final currentThemeId = settings.getSetting('chat_theme_${widget.channel['id']}', defaultValue: globalThemeId);
    final currentTheme = ChatTheme.getTheme(currentThemeId);
    final bgColor = Color(settings.getSetting('chat_bg_color_${widget.channel['id']}', defaultValue: settings.getSetting('chat_bg_color', defaultValue: currentTheme.bgColor.value)));
    final String? wallpaperPath = settings.getSetting('chat_wallpaper_path_${widget.channel['id']}', defaultValue: settings.getSetting('chat_wallpaper_path'));

    Decoration? bgDecoration;
    if (wallpaperPath != null && File(wallpaperPath).existsSync()) {
      bgDecoration = BoxDecoration(
        image: DecorationImage(
          image: FileImage(File(wallpaperPath)),
          fit: BoxFit.cover,
        ),
      );
    } else if (currentTheme.bgImageUrl != null) {
      bgDecoration = BoxDecoration(
        color: currentTheme.bgColor,
        image: DecorationImage(
          image: CachedNetworkImageProvider(currentTheme.bgImageUrl!),
          fit: BoxFit.cover,
        ),
      );
    } else if (currentTheme.bgGradient != null) {
      bgDecoration = BoxDecoration(gradient: currentTheme.bgGradient);
    }

    return Scaffold(
      backgroundColor: currentTheme.bgColor,
      resizeToAvoidBottomInset: true,
      floatingActionButton: _showScrollToBottom
          ? Padding(
              padding: const EdgeInsets.only(bottom: 60.0),
              child: FloatingActionButton(
                mini: true,
                backgroundColor: AppColors.white,
                child: const Icon(Icons.keyboard_double_arrow_down, color: AppColors.grey),
                onPressed: () {
                  _scrollController.animateTo(
                    0.0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                },
              ),
            )
          : null,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: _buildAppBar(),
      ),
      body: Container(
        decoration: bgDecoration,
        child: Column(
        children: [
          _buildPinnedMessagesBar(),
          Expanded(
            child: _isLoadingPosts
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.orange))
                : _posts.isEmpty
                    ? Center(
                        child: Text(
                          _isAdminOrOwner
                              ? 'Broadcast something to your channel!'
                              : 'No messages yet.',
                          style: const TextStyle(color: AppColors.grey2),
                        ),
                      )
                    : Builder(
                        builder: (ctx) {
                          var displayedPosts = _posts;
                          if (_isSearching && _searchQuery.isNotEmpty) {
                            displayedPosts = _posts.where((p) {
                              final text = (p['content'] ?? '').toString().toLowerCase();
                              final sender = (p['profiles']?['name'] ?? '').toString().toLowerCase();
                              final fileName = (p['media_url'] != null && p['message_type'] == 'document') ? text : '';
                              return text.contains(_searchQuery) || sender.contains(_searchQuery) || fileName.contains(_searchQuery);
                            }).toList();
                          }
                          
                          if (displayedPosts.isEmpty) {
                            return const Center(child: Text('No results found.', style: TextStyle(color: AppColors.grey)));
                          }
                          
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            itemCount: displayedPosts.length,
                            itemBuilder: (ctx, i) => _buildPostBubble(displayedPosts[i]),
                          );
                        },
                      ),
          ),
          _buildReplyPreviewBar(),
          _buildComposerOrMute(),
        ],
      ),
      ),
    );
  }

  Widget _buildPinnedMessagesBar() {
    final pinnedPosts = _posts.where((p) => p['is_pinned'] == true).toList();
    
    return PinnedMessagesBanner(
      pinnedMessages: pinnedPosts,
      chatId: widget.channel['id'],
      isChannel: true,
      scrollController: _scrollController,
      allMessages: _posts,
      onUnpin: (messageId) {
        setState(() {
          final idx = _posts.indexWhere((p) => p['id'] == messageId);
          if (idx != -1) {
            _posts[idx]['is_pinned'] = false;
          }
        });
      },
    );
  }

  Widget _buildReplyPreviewBar() {
    if (_replyingToMessage == null) return const SizedBox.shrink();
    
    final type = _replyingToMessage!['message_type'] ?? 'text';
    final content = _replyingToMessage!['content'] ?? '';
    final mediaUrl = _replyingToMessage!['media_url'];
    final senderName = _replyingToMessage!['profiles']?['name'] ?? 'Channel';
    
    Widget previewContent;
    if (type == 'image' && mediaUrl != null) {
      previewContent = Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              mediaUrl,
              width: 48, height: 48, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 48, height: 48,
                color: AppColors.lightGrey,
                child: const Icon(Icons.broken_image, color: AppColors.grey, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('📷 Photo', style: TextStyle(color: AppColors.dark, fontSize: 13)),
        ],
      );
    } else if (type == 'video') {
      previewContent = const Row(children: [
        Icon(Icons.videocam, color: AppColors.grey, size: 18),
        SizedBox(width: 6),
        Text('Video', style: TextStyle(color: AppColors.dark, fontSize: 13)),
      ]);
    } else if (type == 'voice') {
      previewContent = const Row(children: [
        Icon(Icons.mic, color: AppColors.grey, size: 18),
        SizedBox(width: 6),
        Text('Voice message', style: TextStyle(color: AppColors.dark, fontSize: 13)),
      ]);
    } else if (type == 'document') {
      previewContent = Row(children: [
        const Icon(Icons.insert_drive_file, color: AppColors.grey, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(content.isNotEmpty ? content : 'Document',
            style: const TextStyle(color: AppColors.dark, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]);
    } else if (type == 'poll') {
      String question = 'Poll';
      try { question = (jsonDecode(content) as Map)['question']?.toString() ?? 'Poll'; } catch (_) {}
      previewContent = Row(children: [
        const Icon(Icons.poll, color: AppColors.grey, size: 18),
        const SizedBox(width: 6),
        Expanded(child: Text(question,
            style: const TextStyle(color: AppColors.dark, fontSize: 13),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]);
    } else if (type == 'location') {
      previewContent = const Row(children: [
        Icon(Icons.location_on, color: AppColors.orange, size: 18),
        SizedBox(width: 6),
        Text('Location', style: TextStyle(color: AppColors.dark, fontSize: 13)),
      ]);
    } else {
      previewContent = Text(
        content.isNotEmpty ? content : 'Message',
        style: const TextStyle(color: AppColors.dark, fontSize: 13),
        maxLines: 1, overflow: TextOverflow.ellipsis,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, color: AppColors.orange, size: 20),
          const SizedBox(width: 8),
          Container(width: 3, height: 40, color: AppColors.orange),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(senderName,
                    style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 2),
                previewContent,
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.grey),
            onPressed: () => setState(() => _replyingToMessage = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
