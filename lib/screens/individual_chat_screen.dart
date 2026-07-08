import 'package:visibility_detector/visibility_detector.dart';
import '../widgets/chat/message_bubble_widget.dart';
import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:audio_waveforms/audio_waveforms.dart' hide PlayerState;
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../services/settings_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'forward_select_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../widgets/chat/pinned_messages_banner.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'video_call_screen.dart';
import 'voice_call_screen.dart';
import 'contact_info_screen.dart';
import 'group_info_screen.dart';
import 'media_viewer_screen.dart';
import 'media_preview_edit_screen.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart' hide LatLng;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'map_viewer_screen.dart';
import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:zego_uikit/zego_uikit.dart';
import '../widgets/chat/message_context_menu.dart';
// import 'voice_call_screen.dart';
// import 'video_call_screen.dart';
import 'create_event_screen.dart';
import 'create_poll_screen.dart';
import 'share_contacts_screen.dart';
import 'location_picker_screen.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'pdf_viewer_screen.dart';
import 'video_viewer_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:swipe_to/swipe_to.dart';
import '../services/bot_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../widgets/chat/video_thumbnail_widget.dart';
import '../widgets/chat/signed_image_widget.dart';
import '../widgets/chat/audio_message_widget.dart';
import '../widgets/chat/tail_painter.dart';
import '../widgets/chat/voice_recorder_bar.dart';
import '../widgets/chat/attachment_menu.dart';
import '../screens/call_overlay_manager.dart';

class IndividualChatScreen extends StatefulWidget {
  final String? chatId;
  final String chatName;
  final String? otherUserId;
  final String? avatarUrl;
  final int unreadCount;

  const IndividualChatScreen({
    super.key,
    this.chatId,
    required this.chatName,
    this.otherUserId,
    this.avatarUrl,
    this.unreadCount = 0,
  });

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final Map<String, String?> _optimisticReactions = {};
  final Set<String> _optimisticallyDeletedMessages = {};
  final Set<String> _optimisticallyTombstonedMessages = {};
  final Set<String> _starredMessageIds = {};
  bool _isSearching = false;
  bool _isCurrentUserAdmin = false;
  String _searchQuery = '';
  final FocusNode _focusNode = FocusNode();
  bool _isTyping = false;
  bool _showEmoji = false;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  String _replyMessageId = '';
  final List<Map<String, dynamic>> _pendingMessages = [];
  Timer? _recordingTimer;
  Timer? _presenceTimer;
  Timer? _readReceiptDebouncer;
  int _onlineCount = 0;
  int _totalMembers = 0;
  final Map<String, String> _groupMemberNames = {};
  int _messageLimit = 50;
  Timer? _typingDebounceTimer;
  Map<String, dynamic>? _editingMessage;
  bool _isLoadingOlder = false;
  
  // Mentions State
  bool _isMentioning = false;
  String _mentionQuery = '';
  List<MapEntry<String, String>> _filteredMentionUsers = [];
  final Map<String, String> _currentMentions = {}; // '@Username' -> 'UUID'
  SupabaseClient get _supabase => Supabase.instance.client;
  RealtimeChannel? _presenceChannel;

  // Bot logic
  bool _isBot = false;
  List<Map<String, dynamic>> _botCommands = [];
  final BotService _botService = BotService();

  Map<String, dynamic>? _replyingToMessage;

  String? _currentChatId;
  String? _groupAvatarUrl;
  Stream<List<Map<String, dynamic>>>? _messagesStream;
  Stream<List<Map<String, dynamic>>>? _reactionsStream;
  DateTime? _otherLastReadAt;
  RealtimeChannel? _readReceiptsChannel;
  late final ChatService _chatService;

  @override
  void initState() {
    super.initState();
    _chatService = context.read<ChatService>();
    _loadStarredMessages();
    _messageController.addListener(() {
      final isNotEmpty = _messageController.text.isNotEmpty;
      if (_isTyping != isNotEmpty) {
        setState(() => _isTyping = isNotEmpty);
        if (widget.otherUserId != null && _currentChatId != null) {
          final myName = _chatService.currentUserProfile?['name'] ?? 'Someone';
          _chatService.sendTypingEvent(widget.otherUserId, _currentChatId!, isNotEmpty, myName);
        } else if (_currentChatId != null) {
          final myName = _chatService.currentUserProfile?['name'] ?? 'Someone';
          _chatService.sendTypingEvent(null, _currentChatId!, isNotEmpty, myName);
        }
      }
      
      // Mention Logic
      if (widget.otherUserId == null) {
        final text = _messageController.text;
        final selection = _messageController.selection;
        if (selection.isValid && selection.baseOffset > 0) {
          final textBeforeCursor = text.substring(0, selection.baseOffset);
          final lastAtWordMatch = RegExp(r'@([a-zA-Z0-9_]*)$').firstMatch(textBeforeCursor);
          if (lastAtWordMatch != null) {
            final query = lastAtWordMatch.group(1) ?? '';
            final filtered = _groupMemberNames.entries.where((e) {
              return e.value.toLowerCase().contains(query.toLowerCase());
            }).toList();
            
            setState(() {
              _isMentioning = true;
              _mentionQuery = query;
              _filteredMentionUsers = filtered;
            });
          } else {
            if (_isMentioning) setState(() => _isMentioning = false);
          }
        } else {
          if (_isMentioning) setState(() => _isMentioning = false);
        }
      }
      
      _typingDebounceTimer?.cancel();
      if (isNotEmpty) {
        _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
          if (mounted && _isTyping) {
            setState(() => _isTyping = false);
            if (widget.otherUserId != null && _currentChatId != null) {
              final myName = _chatService.currentUserProfile?['name'] ?? 'Someone';
              _chatService.sendTypingEvent(widget.otherUserId, _currentChatId!, false, myName);
            } else if (_currentChatId != null) {
              final myName = _chatService.currentUserProfile?['name'] ?? 'Someone';
              _chatService.sendTypingEvent(null, _currentChatId!, false, myName);
            }
          }
        });
      }
    });

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    _currentChatId = widget.chatId;
    if (_currentChatId == null && widget.otherUserId != null) {
      _initChat();
    } else if (_currentChatId != null) {
      _chatService.markChatRead(_currentChatId!);
      _messagesStream = context
          .read<ChatService>()
          .getMessagesStream(_currentChatId!, limit: _messageLimit);
      _reactionsStream = Supabase.instance.client
          .from('message_reactions')
          .stream(primaryKey: ['message_id', 'user_id'])
          .eq('chat_id', _currentChatId!)
          .order('created_at', ascending: true);
      _setupGroupPresence();
      _setupReadReceipts();
      if (widget.otherUserId == null) {
        _chatService.subscribeToGroupTyping(_currentChatId!);
      }
    }

    _scrollController.addListener(_onScroll);
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        setState(() {
          _showEmoji = false;
        });
      }
    });

    _checkIfBot();
  }

  Future<void> _initChat() async {
    try {
      final newChatId =
          await _chatService.createChat(widget.otherUserId!);
      if (mounted) {
        setState(() {
          _currentChatId = newChatId;
          _chatService.markChatRead(_currentChatId!);
          _messagesStream =
              _chatService.getMessagesStream(_currentChatId!);
          _reactionsStream = Supabase.instance.client
              .from('message_reactions')
              .stream(primaryKey: ['message_id', 'user_id'])
              .eq('chat_id', _currentChatId!)
              .order('created_at', ascending: true);
          _setupReadReceipts();
        });
      }
    } catch (e) {
      debugPrint('[DEBUG] Failed to create chat in init: $e');
    }
  }

  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingOlder) {
      setState(() {
        _isLoadingOlder = true;
        _messageLimit += 50;
        _messagesStream = context
            .read<ChatService>()
            .getMessagesStream(_currentChatId!, limit: _messageLimit);
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) setState(() => _isLoadingOlder = false);
      });
    }
  }

  void _setupGroupPresence() {
    if (widget.otherUserId == null && _currentChatId != null) {
      _presenceChannel = _supabase.channel('presence:group_${_currentChatId}');

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

      _fetchTotalMembersCount();
      _fetchGroupAvatar(widget.chatId!);
    }
  }

  void _setupReadReceipts() async {
    if (_currentChatId == null || widget.otherUserId == null) return;
    
    try {
      final data = await _supabase
          .from('chat_participants')
          .select('last_read_at')
          .eq('chat_id', _currentChatId!)
          .eq('user_id', widget.otherUserId!)
          .maybeSingle();
      if (data != null && data['last_read_at'] != null) {
        if (mounted) {
          setState(() {
            _otherLastReadAt = DateTime.parse(data['last_read_at']);
          });
        }
      }
    } catch (_) {}

    _readReceiptsChannel = _supabase.channel('public:chat_participants:${_currentChatId}_${widget.otherUserId}');
    _readReceiptsChannel!.onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'chat_participants',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'chat_id',
          value: _currentChatId!,
        ),
        callback: (payload) {
          final row = payload.newRecord;
          if (row['user_id'] == widget.otherUserId && row['last_read_at'] != null) {
            if (mounted) {
              setState(() {
                _otherLastReadAt = DateTime.parse(row['last_read_at']);
              });
            }
          }
        }).subscribe();
  }

  Future<void> _fetchGroupAvatar(String chatId) async {
    try {
      final data = await _supabase
          .from('chats')
          .select('group_avatar_url')
          .eq('id', chatId)
          .maybeSingle();
      if (mounted && data != null) {
        setState(() {
          _groupAvatarUrl = data['group_avatar_url'] as String?;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTotalMembersCount() async {
    if (_currentChatId == null) return;
    final totalCount = await _chatService.getTotalMembersCount(_currentChatId!);
    if (mounted) {
      setState(() {
        _totalMembers = totalCount;
      });
    }

    if (widget.otherUserId == null) {
      try {
        final res = await _supabase
            .from('chat_participants')
            .select('user_id, role, profiles(name)')
            .eq('chat_id', _currentChatId!);
        if (mounted) {
          setState(() {
            for (var row in res) {
              final uid = row['user_id'] as String;
              final role = row['role'] as String?;
              final prof = row['profiles'];
              if (prof != null && prof is Map && prof['name'] != null) {
                _groupMemberNames[uid] = prof['name'] as String;
              }
              if (uid == _chatService.currentUserId && role == 'admin') {
                _isCurrentUserAdmin = true;
              }
            }
          });
        }
      } catch (e) {
        debugPrint('[DEBUG] _fetchTotalMembersCount error: $e');
      }
    }
  }

  Future<void> _checkIfBot() async {
    if (widget.otherUserId != null) {
      final isBot = await _botService.checkIfBot(widget.otherUserId!);
      if (mounted) setState(() => _isBot = isBot);

      if (isBot) {
        final cmds = await _botService.getBotCommands(widget.otherUserId!);
        if (mounted) setState(() => _botCommands = cmds);
      }
    }
  }

  Future<void> _loadStarredMessages() async {
    final ids = await _chatService.getStarredMessageIds();
    if (mounted) {
      setState(() {
        _starredMessageIds.addAll(ids);
      });
    }
  }

  @override
  void dispose() {
    if (_currentChatId != null) {
      _chatService.markChatRead(_currentChatId!);
    }
    if (_readReceiptsChannel != null) {
      _supabase.removeChannel(_readReceiptsChannel!);
    }
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }
    if (_currentChatId != null && widget.otherUserId == null) {
      _chatService.unsubscribeFromGroupTyping(_currentChatId!);
    }
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _recordingTimer?.cancel();
    _presenceTimer?.cancel();
    _readReceiptDebouncer?.cancel();
    super.dispose();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentChatId == null) {
      return;
    }

    // Extract mentions for group chats
    List<String> mentionedUserIds = [];
    if (widget.otherUserId == null) {
      _currentMentions.forEach((mentionTag, uuid) {
        if (text.contains(mentionTag)) {
          mentionedUserIds.add(uuid);
        }
      });
      _currentMentions.clear();
    }

    if (_editingMessage != null) {
      final msgId = _editingMessage!['id'].toString();
      _messageController.clear();
      setState(() {
        _isTyping = false;
        _editingMessage = null;
      });
      _typingDebounceTimer?.cancel();
      if (widget.otherUserId != null && _currentChatId != null) {
        _chatService.sendTypingEvent(widget.otherUserId!, _currentChatId!, false);
      }
      await _chatService.editMessage(msgId, text);
      return;
    }

    _messageController.clear();
    setState(() => _isTyping = false);
    _typingDebounceTimer?.cancel();
    if (_currentChatId != null) {
      final myName = _chatService.currentUserProfile?['name'] ?? 'Someone';
      _chatService.sendTypingEvent(widget.otherUserId, _currentChatId!, false, myName);
    }

    try {
      debugPrint('[DEBUG] Calling ChatService.sendMessage...');
      final replyId = _replyingToMessage?['id']?.toString();
      final messageId = Uuid().v4();
      
      setState(() {
        _replyingToMessage = null;
        _pendingMessages.add({
          'id': messageId,
          'sender_id': _chatService.currentUserId,
          'content': text,
          'message_type': 'text',
          'is_pending': true,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      _scrollToBottom();

      await _chatService.sendMessage(
            chatId: _currentChatId!,
            id: messageId,
            content: text,
            replyToId: replyId,
            mentionedUserIds: mentionedUserIds.isNotEmpty ? mentionedUserIds : null,
          );
      debugPrint('[DEBUG] ChatService.sendMessage completed successfully.');
      
      if (mounted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _pendingMessages.removeWhere((m) => m['id'] == messageId);
            });
          }
        });
      }
    } catch (e) {
      debugPrint('[DEBUG] ChatService.sendMessage threw error: $e');
      // If error occurs, we should also remove it from pending (ChatService handles offline queue fallback if needed)
      if (mounted) {
        setState(() {
          _pendingMessages.removeWhere((m) => m['content'] == text);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<Map<String, dynamic>> _getMergedReactions(List<Map<String, dynamic>> streamReactions, String? msgId) {
    if (msgId == null) return streamReactions;
    if (!_optimisticReactions.containsKey(msgId)) return streamReactions;
    
    final optEmoji = _optimisticReactions[msgId];
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (myId == null) return streamReactions;
    
    final merged = List<Map<String, dynamic>>.from(streamReactions);
    merged.removeWhere((r) => r['user_id'] == myId);
    
    if (optEmoji != null) {
      merged.add({
        'message_id': msgId,
        'user_id': myId,
        'emoji': optEmoji,
      });
    }
    return merged;
  }

  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();
    final settings = context.watch<SettingsService>();
    final globalThemeId = settings.getSetting('chat_theme_id', defaultValue: 'default');
    final currentThemeId = settings.getSetting('chat_theme_${widget.chatId}', defaultValue: globalThemeId);
    final currentTheme = ChatTheme.getTheme(currentThemeId);
    
    int parseInt(dynamic val, int def) {
      if (val == null) return def;
      if (val is int) return val;
      if (val is double) return val.toInt();
      if (val is String) return int.tryParse(val) ?? def;
      return def;
    }
    
    final bgColor = Color(parseInt(settings.getSetting('chat_bg_color_${widget.chatId}', defaultValue: settings.getSetting('chat_bg_color')), currentTheme.bgColor.value));
    final bubbleColor = Color(parseInt(settings.getSetting('chat_bubble_color_${widget.chatId}', defaultValue: settings.getSetting('chat_bubble_color')), currentTheme.bubbleColor.value));
    final receiverBubbleColor = currentTheme.receiverBubbleColor;
    final senderTextColor = currentTheme.senderTextColor;
    final receiverTextColor = currentTheme.receiverTextColor;
    final timeColor = currentTheme.timeColor;
    final currentFont = widget.chatId != null 
        ? settings.getSetting('chat_font_${widget.chatId}', defaultValue: settings.getSetting('chat_font', defaultValue: 'Inter'))
        : settings.getSetting('chat_font', defaultValue: 'Inter');
    final String? wallpaperPath = settings.getSetting('chat_wallpaper_path_${widget.chatId}', defaultValue: settings.getSetting('chat_wallpaper_path'));

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
        color: bgColor,
        image: DecorationImage(
          image: CachedNetworkImageProvider(currentTheme.bgImageUrl!),
          fit: BoxFit.cover,
        ),
      );
    } else if (currentTheme.bgGradient != null) {
      bgDecoration = BoxDecoration(gradient: currentTheme.bgGradient);
    }

    final avatarLetter =
        widget.chatName.isNotEmpty ? widget.chatName.characters.first.toUpperCase() : '?';

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      appBar: _isSearching
          ? AppBar(
              backgroundColor: AppColors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              titleSpacing: 0,
              leading: IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.orange, size: 18),
                ),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchController.clear();
                    _searchQuery = '';
                  });
                },
              ),
              title: TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search...',
                  border: InputBorder.none,
                ),
                style: const TextStyle(color: AppColors.dark),
              ),
              actions: [
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.dark),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
              ],
            )
          : AppBar(
              backgroundColor: AppColors.white.withValues(alpha: 0.95),
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              leadingWidth: 52,
              titleSpacing: 0,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.orange, size: 18),
                  ),
                  onPressed: () => Navigator.maybePop(context),
                ),
              ),
              title: Builder(
                builder: (context) {
                  if (widget.otherUserId == null) {
                    // Group chat uses _groupAvatarUrl and widget.chatName
                    final avatarLetter = widget.chatName.isNotEmpty ? widget.chatName.characters.first.toUpperCase() : '?';
                    return GestureDetector(
                      onTap: () async {
                        if (widget.chatId != null) {
                          String? avatarUrl;
                          try {
                            final data = await _supabase.from('chats').select('group_avatar_url').eq('id', widget.chatId!).maybeSingle();
                            avatarUrl = data?['group_avatar_url'] as String?;
                          } catch (_) {}
                          if (mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupInfoScreen(
                                  chatId: widget.chatId!,
                                  groupName: widget.chatName,
                                  groupAvatarUrl: avatarUrl,
                                ),
                              ),
                            );
                          }
                        }
                      },
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.orange,
                            backgroundImage: _groupAvatarUrl != null ? NetworkImage(_groupAvatarUrl!) : null,
                            child: _groupAvatarUrl == null ? Text(avatarLetter, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)) : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.chatName,
                                  style: const TextStyle(color: AppColors.dark, fontSize: 17, fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                  if (context.watch<ChatService>().typingChats.containsKey(_currentChatId))
                                    Text('${context.watch<ChatService>().typingChats[_currentChatId]} is typing...', style: const TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.w500))
                                  else
                                    Row(
                                      children: [
                                        Text('$_totalMembers members, ', style: const TextStyle(fontSize: 12, color: AppColors.grey)),
                                        if (_onlineCount > 0) ...[
                                          const Icon(Icons.circle, color: Color(0xFF22C55E), size: 8),
                                          const SizedBox(width: 4),
                                          Text('$_onlineCount online', style: const TextStyle(color: Color(0xFF22C55E), fontSize: 13, fontWeight: FontWeight.w600)),
                                        ] else
                                          const Text('0 online', style: TextStyle(fontSize: 13, color: AppColors.grey)),
                                      ],
                                    ),
                                ],
                              ),
                          ),
                        ],
                      ),
                    );
                  } else {
                    // Individual Chat
                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _chatService.getProfileStream(widget.otherUserId!),
                      builder: (context, snapshot) {
                        String name = widget.chatName;
                        String? avatarUrl = widget.avatarUrl;
                        Map<String, dynamic>? profile;
                        if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          profile = snapshot.data!.first;
                          // Keep the passed chatName (which respects local contacts)
                          avatarUrl = profile['avatar_url'] ?? avatarUrl;
                        }
                        final avatarLetter = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                        
                        return GestureDetector(
                          onTap: () async {
                            final startSearch = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => ContactInfoScreen(
                                          name: name,
                                          avatarUrl: avatarUrl,
                                          avatarText: avatarLetter,
                                          avatarColor: AppColors.orange,
                                          chatId: _currentChatId ?? '',
                                          initialPhone: profile?['phone_number']?.toString(),
                                        )));
                            if (startSearch == true && mounted) {
                              setState(() {
                                _isSearching = true;
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            }
                          },
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.orange,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? Text(avatarLetter, style: const TextStyle(color: AppColors.white, fontSize: 18, fontWeight: FontWeight.bold)) : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(color: AppColors.dark, fontSize: 17, fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (!_isBot && profile != null)
                                      FutureBuilder<List<bool>>(
                                        future: Future.wait([
                                          context.read<SettingsService>().canSeeOnline(widget.otherUserId!),
                                          context.read<SettingsService>().canSeeLastSeen(widget.otherUserId!),
                                        ]),
                                        builder: (context, privacySnapshot) {
                                          if (!privacySnapshot.hasData) return const SizedBox.shrink();
                                          final canSeeOnline = privacySnapshot.data![0];
                                          final canSeeLastSeen = privacySnapshot.data![1];

                                          final isOnline = profile!['is_online'] == true;
                                          final lastSeenStr = profile!['last_seen'];

                                          final isTyping = context.watch<ChatService>().typingChats.containsKey(_currentChatId);

                                          if (isTyping) {
                                            return const Text('typing...', style: TextStyle(color: AppColors.orange, fontSize: 13, fontWeight: FontWeight.w500));
                                          } else if (isOnline && canSeeOnline) {
                                            return const Text('online', style: TextStyle(color: AppColors.grey, fontSize: 13));
                                          } else if (lastSeenStr != null && canSeeLastSeen) {
                                            try {
                                              final lastSeenDate = DateTime.parse(lastSeenStr).toLocal();
                                              final now = DateTime.now();
                                              final isToday = lastSeenDate.year == now.year && lastSeenDate.month == now.month && lastSeenDate.day == now.day;
                                              final isYesterday = lastSeenDate.year == now.year && lastSeenDate.month == now.month && lastSeenDate.day == now.day - 1;

                                              String timeFormat = DateFormat('hh:mm a').format(lastSeenDate);
                                              String dayText = isToday ? 'today' : (isYesterday ? 'yesterday' : DateFormat('MMM d').format(lastSeenDate));

                                              return SizedBox(
                                                height: 16,
                                                child: Marquee(
                                                  text: 'last seen $dayText at $timeFormat',
                                                  style: const TextStyle(color: AppColors.grey, fontSize: 13),
                                                  scrollAxis: Axis.horizontal,
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  blankSpace: 20.0,
                                                  velocity: 20.0,
                                                  startPadding: 0.0,
                                                  pauseAfterRound: const Duration(seconds: 2),
                                                  accelerationDuration: const Duration(seconds: 1),
                                                  accelerationCurve: Curves.linear,
                                                  decelerationDuration: const Duration(milliseconds: 500),
                                                  decelerationCurve: Curves.easeOut,
                                                ),
                                              );
                                            } catch (_) {}
                                          }
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }
                },
              ),
              actions: [
                if (widget.otherUserId != null && !_isBot) ...[
                  ZegoSendCallInvitationButton(
                    isVideoCall: false,
                    invitees: [
                      ZegoUIKitUser(
                        id: widget.otherUserId!.replaceAll('-', ''),
                        name: widget.chatName,
                      ),
                    ],
                    resourceID: 'twibee_call', // Add this if you configure it in Zego console
                    iconSize: const Size(24, 24),
                    buttonSize: const Size(40, 40),
                    icon: ButtonIcon(icon: const Icon(Icons.call_outlined, color: AppColors.dark)),
                  ),
                  const SizedBox(width: 8),
                  ZegoSendCallInvitationButton(
                    isVideoCall: true,
                    invitees: [
                      ZegoUIKitUser(
                        id: widget.otherUserId!.replaceAll('-', ''),
                        name: widget.chatName,
                      ),
                    ],
                    resourceID: 'twibee_call', // Add this if you configure it in Zego console
                    iconSize: const Size(24, 24),
                    buttonSize: const Size(40, 40),
                    icon: ButtonIcon(icon: const Icon(Icons.videocam_outlined, color: AppColors.dark)),
                  ),
                ],
                IconButton(
                  icon: const Icon(Icons.search, color: AppColors.dark),
                  onPressed: () {
                    setState(() {
                      _isSearching = true;
                    });
                  },
                ),
                const SizedBox(width: 8),
              ],
            ),
      body: Container(
        decoration: bgDecoration,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: _currentChatId == null
              ? Column(
                  children: [
                    const Expanded(child: Center(child: Text("Preview Mode"))),
                    if (_isBot)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: () {
                            _messageController.text = '/start';
                            _sendMessage();
                          },
                          child: const Text('START',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ),
                      )
                    else ...[
                      _buildReplyPreviewBar(),
                      _buildMentionOverlay(),
                      _buildInputBar(currentTheme, currentFont),
                    ],
                  ],
                )
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.orange));
                    }

                    return StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _reactionsStream,
                      builder: (context, reactionsSnapshot) {
                        final rawReactions = reactionsSnapshot.data ?? [];
                        final Map<String, List<Map<String, dynamic>>> reactionsByMessage = {};
                        for (var r in rawReactions) {
                          final mId = r['message_id'].toString();
                          final uId = r['user_id'].toString();
                          final list = reactionsByMessage.putIfAbsent(mId, () => []);
                          // Ensure unique reaction per user in UI
                          list.removeWhere((element) => element['user_id'].toString() == uId);
                          list.add(r);
                        }

                        List<Map<String, dynamic>> messages = (snapshot.data ?? [])
                            .where((m) => !_optimisticallyDeletedMessages.contains(m['id'].toString()))
                            .map((m) {
                              if (_optimisticallyTombstonedMessages.contains(m['id'].toString())) {
                                return {
                                  ...m,
                                  'is_deleted_for_everyone': true,
                                  'content': 'This message was deleted',
                                  'media_url': null,
                                };
                              }
                              return m;
                            })
                            .toList();
                    final hasMessages = messages.isNotEmpty;
                    List<Map<String, dynamic>> reversedMessages =
                        messages.reversed.toList();

                    // Add global text/media offline messages from ChatService
                    final offlineMessages = chatService.offlineQueue
                        .where((m) => m['chat_id'] == _currentChatId)
                        .toList();
                    if (offlineMessages.isNotEmpty) {
                      reversedMessages.insertAll(0, offlineMessages.reversed);
                    }

                    if (_pendingMessages.isNotEmpty) {
                      final streamIds = reversedMessages.map((m) => m['id']?.toString()).where((id) => id != null).toSet();
                      final pendingToShow = _pendingMessages.where((p) => !streamIds.contains(p['id'])).toList();
                      reversedMessages.insertAll(0, pendingToShow.reversed);
                    }

                    if (_isSearching && _searchQuery.isNotEmpty) {
                      reversedMessages = reversedMessages.where((msg) {
                        final content =
                            msg['content']?.toString().toLowerCase() ?? '';
                        return content.contains(_searchQuery);
                      }).toList();
                    }

                    List<dynamic> clusteredMessages = [];
                    String? currentGroupId;
                    List<Map<String, dynamic>> currentGroup = [];
                    int processedCount = 0;
                    bool unreadDividerInserted = false;

                    for (var msg in reversedMessages) {
                      if (widget.unreadCount > 0 && processedCount == widget.unreadCount && !unreadDividerInserted) {
                        if (currentGroup.isNotEmpty) {
                          clusteredMessages.add(currentGroup);
                          currentGroup = [];
                          currentGroupId = null;
                        }
                        clusteredMessages.add('UNREAD_DIVIDER');
                        unreadDividerInserted = true;
                      }

                      processedCount++;

                      final groupId = msg['media_group_id'];
                      if (groupId != null) {
                        if (groupId == currentGroupId) {
                          currentGroup.add(msg);
                        } else {
                          if (currentGroup.isNotEmpty)
                            clusteredMessages.add(currentGroup);
                          currentGroupId = groupId;
                          currentGroup = [msg];
                        }
                      } else {
                        if (currentGroup.isNotEmpty) {
                          clusteredMessages.add(currentGroup);
                          currentGroup = [];
                          currentGroupId = null;
                        }
                        clusteredMessages.add(msg);
                      }
                    }
                    if (currentGroup.isNotEmpty)
                      clusteredMessages.add(currentGroup);

                    final pinnedMessages = reversedMessages.where((m) => m['is_pinned'] == true).toList();

                    return Column(
                      children: [
                        PinnedMessagesBanner(
                          pinnedMessages: pinnedMessages,
                          chatId: _currentChatId ?? '',
                          isChannel: false,
                          scrollController: _scrollController,
                          allMessages: clusteredMessages,
                        ),
                        Expanded(
                          child: snapshot.hasError && clusteredMessages.isEmpty
                              ? Center(child: Text('Error: ${snapshot.error}'))
                              : ListView.builder(
                                  controller: _scrollController,
                                  reverse: true,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 0, vertical: 16),
                                  itemCount: clusteredMessages.length + (_isLoadingOlder || (snapshot.hasError && clusteredMessages.isNotEmpty) ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == clusteredMessages.length) {
                                       if (snapshot.hasError) {
                                          return Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Column(
                                              children: [
                                                const Text('Failed to load older messages.', style: TextStyle(color: Colors.red)),
                                                TextButton(
                                                  onPressed: () {
                                                    setState(() {
                                                      _isLoadingOlder = false;
                                                      _onScroll();
                                                    });
                                                  },
                                                  child: const Text('Retry'),
                                                ),
                                              ],
                                            ),
                                          );
                                       }
                                       return const Padding(
                                          padding: EdgeInsets.all(16.0),
                                          child: Center(
                                              child: CircularProgressIndicator(
                                                  color: AppColors.orange)),
                                        );
                                    }

                                    final item = clusteredMessages[index];

                                    if (item == 'UNREAD_DIVIDER') {
                                      return Container(
                                        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                                        child: Row(
                                          children: [
                                            Expanded(child: Divider(color: AppColors.orange.withValues(alpha: 0.3), thickness: 1)),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppColors.orange.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${widget.unreadCount} Unread Messages',
                                                style: const TextStyle(
                                                  color: AppColors.orange,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            Expanded(child: Divider(color: AppColors.orange.withValues(alpha: 0.3), thickness: 1)),
                                          ],
                                        ),
                                      );
                                    }

                                    bool isSameSenderAsPrevious = false;
                                    if (index < clusteredMessages.length - 1) {
                                      final prevItem =
                                          clusteredMessages[index + 1];
                                      if (prevItem != 'UNREAD_DIVIDER') {
                                        final currentSender = item is List
                                            ? item.first['sender_id']
                                            : (item as Map)['sender_id'];
                                        final prevSender = prevItem is List
                                            ? prevItem.first['sender_id']
                                            : (prevItem as Map)['sender_id'];
                                        isSameSenderAsPrevious =
                                            currentSender == prevSender;
                                      }
                                    }
                                    final topMargin =
                                        isSameSenderAsPrevious ? 0.0 : 12.0;

                                    Widget messageWidget;
                                    if (item is List<Map<String, dynamic>>) {
                                      final firstMsg = item.first;
                                      final isMe = firstMsg['sender_id'] ==
                                          context
                                              .read<ChatService>()
                                              .currentUserId;
                                      String timeText = '';
                                      bool isRead = false;
                                      if (firstMsg['created_at'] != null) {
                                        final msgTime = DateTime.parse(firstMsg['created_at']);
                                        timeText = DateFormat('hh:mm a').format(msgTime.toLocal());
                                        if (isMe && _otherLastReadAt != null) {
                                          isRead = msgTime.isBefore(_otherLastReadAt!) || msgTime.isAtSameMomentAs(_otherLastReadAt!);
                                        }
                                      }
                                      messageWidget = _buildMediaGroupGrid(
                                          item.reversed.toList(),
                                          isMe,
                                          timeText,
                                          bubbleColor,
                                          isPending: firstMsg['is_pending'] == true,
                                          isRead: isRead,
                                      );
                                    } else {
                                      final msg = item as Map<String, dynamic>;
                                      final isMe = msg['sender_id'] ==
                                          context
                                              .read<ChatService>()
                                              .currentUserId;

                                      Map<String, dynamic>? replyToMsg;
                                      if (msg['reply_to_id'] != null) {
                                        final parentId =
                                            msg['reply_to_id'].toString();
                                        try {
                                          replyToMsg =
                                              reversedMessages.firstWhere((p) =>
                                                  p['id']?.toString() ==
                                                  parentId);
                                        } catch (_) {}
                                      }

                                      String timeText = '';
                                      if (msg['created_at'] != null) {
                                        final time =
                                            DateTime.parse(msg['created_at'])
                                                .toLocal();
                                        timeText =
                                            DateFormat('hh:mm a').format(time);
                                      }
                                      bool isRead = false;
                                      if (isMe && _otherLastReadAt != null && msg['created_at'] != null) {
                                        final msgTime = DateTime.tryParse(msg['created_at']);
                                        if (msgTime != null) {
                                          isRead = msgTime.isBefore(_otherLastReadAt!) || msgTime.isAtSameMomentAs(_otherLastReadAt!);
                                        }
                                      }

                                      messageWidget = MessageBubbleWidget(
                                        text: msg['content'] ?? '',
                                        time: timeText,
                                        isMe: isMe,
                                        isRead: isRead,
                                        messageType: msg['message_type'] ?? 'text',
                                        mediaUrl: msg['media_url'],
                                        isForwarded: msg['forwarded_from_id'] != null,
                                        isEdited: msg['is_edited'] == true,
                                        isStarred: _starredMessageIds.contains(msg['id']?.toString()),
                                        messageId: msg['id']?.toString(),
                                        senderName: widget.otherUserId == null ? _groupMemberNames[msg['sender_id']] : null,
                                        replyMarkup: msg['reply_markup'],
                                        reactions: _getMergedReactions(
                                          reactionsByMessage[msg['id']?.toString()] ?? [],
                                          msg['id']?.toString(),
                                        ),
                                        rawMsg: msg,
                                        replyToMsg: replyToMsg,
                                        bubbleColor: bubbleColor,
                                        receiverBubbleColor: receiverBubbleColor,
                                        senderTextColor: senderTextColor,
                                        receiverTextColor: receiverTextColor,
                                        timeColor: timeColor,
                                        fontFamily: currentFont,
                                        isPending: msg['is_pending'] == true,
                                        chatName: widget.chatName,
                                        chatId: widget.chatId,
                                        otherUserId: widget.otherUserId,
                                        onReply: (rawMsg) => setState(() => _replyingToMessage = rawMsg),
                                        onForward: (rawMsg) => _handleForward(rawMsg),
                                        onScrollToMessage: (id) => _scrollToMessage(id),
                                        onBotCommand: (cmd) {
                                          _messageController.text = cmd;
                                          _sendMessage();
                                        },
                                      );
                                    }
                                    final msgId = (item is List
                                            ? item.first['id']
                                            : (item as Map)['id'])
                                        ?.toString();
                                    if (msgId != null &&
                                        !_messageKeys.containsKey(msgId)) {
                                      _messageKeys[msgId] =
                                          GlobalKey(debugLabel: msgId);
                                    }

                                    return VisibilityDetector(
                                      key: Key(msgId ?? 'unknown_msg_${DateTime.now().microsecondsSinceEpoch}'),
                                      onVisibilityChanged: (info) {
                                        if (info.visibleFraction > 0.5) {
                                          final rawMsg = item is List ? item.first : item;
                                          final isMe = rawMsg['sender_id'] == context.read<ChatService>().currentUserId;
                                          if (!isMe && _currentChatId != null) {
                                            _readReceiptDebouncer?.cancel();
                                            _readReceiptDebouncer = Timer(const Duration(milliseconds: 1500), () {
                                              if (mounted) {
                                                context.read<ChatService>().markChatRead(_currentChatId!);
                                              }
                                            });
                                          }
                                        }
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.only(top: topMargin),
                                        child: Builder(
                                          builder: (builderContext) {
                                            return Container(
                                              key: msgId != null
                                                  ? _messageKeys[msgId]
                                                  : null,
                                              color:
                                                  _highlightedMessageId == msgId
                                                      ? AppColors.orange
                                                          .withOpacity(0.2)
                                                      : Colors.transparent,
                                              child: GestureDetector(
                                                onLongPressStart: (details) {
                                                  final renderBox = builderContext
                                                          .findRenderObject()
                                                      as RenderBox;
                                                  final offset = renderBox
                                                      .localToGlobal(Offset.zero);
                                                  final rect =
                                                      offset & renderBox.size;
                                                  final rawMsg = item is List
                                                      ? item.first
                                                      : item;
                                                  final isMe =
                                                      rawMsg['sender_id'] ==
                                                          context
                                                              .read<ChatService>()
                                                              .currentUserId;
                                                  _showCustomMessageOptions(
                                                      rawMsg,
                                                      messageWidget,
                                                      rect,
                                                      isMe,
                                                      _getMergedReactions(
                                                        reactionsByMessage[rawMsg['id']?.toString()] ?? [],
                                                        rawMsg['id']?.toString(),
                                                      ));
                                                },
                                                child: messageWidget,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (_isBot && !hasMessages)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.orange,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16)),
                              onPressed: () {
                                _messageController.text = '/start';
                                _sendMessage();
                              },
                              child: const Text('START',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                            ),
                          )
                        else ...[
                          _buildReplyPreviewBar(),
                          _buildMentionOverlay(),
                          _buildInputBar(currentTheme, currentFont),
                        ],
                        if (_showEmoji)
                          SizedBox(
                            height: 250,
                            child: EmojiPicker(
                              textEditingController: _messageController,
                              config: const Config(
                                height: 250,
                                checkPlatformCompatibility: true,
                                emojiViewConfig: EmojiViewConfig(
                                  backgroundColor: AppColors.lightGrey,
                                ),
                                bottomActionBarConfig: BottomActionBarConfig(
                                  backgroundColor: AppColors.white,
                                  buttonColor: AppColors.white,
                                  buttonIconColor: AppColors.grey,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ); // End Column
                      }, // End reactionsSnapshot builder
                    ); // End reactions StreamBuilder
                  }, // End messagesSnapshot builder
                ), // End messages StreamBuilder
        ),
      ),
    );
  }

  Widget _buildReplyPreviewBar() {
    if (_replyingToMessage == null && _editingMessage == null) return const SizedBox.shrink();

    final isEdit = _editingMessage != null;
    final messageData = isEdit ? _editingMessage! : _replyingToMessage!;
    
    final isMe = messageData['sender_id'] ==
        _chatService.currentUserId;
    final senderName = isMe ? 'You' : widget.chatName;

    return Container(
      padding: const EdgeInsets.only(right: 12, top: 4, bottom: 4, left: 12),
      decoration: const BoxDecoration(
        color: AppColors.lightGrey,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(isEdit ? Icons.edit : Icons.reply, size: 20, color: AppColors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: isEdit 
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Message', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(messageData['content'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey, fontSize: 13)),
                    ],
                  )
                : buildReplySnippet(context, messageData, senderName,
                isPreview: true),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
               _replyingToMessage = null;
               _editingMessage = null;
               if (isEdit) _messageController.clear();
            }),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.dark, width: 1.5),
              ),
              child: const Icon(Icons.close, size: 14, color: AppColors.dark),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.5,
      );
      setState(() => _highlightedMessageId = messageId);
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && _highlightedMessageId == messageId) {
          setState(() => _highlightedMessageId = null);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message is too far up in history.')));
    }
  }

  void _handleForward(Map<String, dynamic> msg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ForwardSelectScreen(
          message: msg,
          currentChannelId: widget.chatId ?? '',
        ),
      ),
    );
  }

  Future<void> _showCustomMessageOptions(Map<String, dynamic> msg, Widget messageWidget,
      Rect childRect, bool isMe, List<Map<String, dynamic>> reactions) async {
    final messageType = msg['message_type'] ?? 'text';
    final hasTextContent = msg['content']?.toString().isNotEmpty ?? false;

    final canCopy = messageType == 'text' ||
        messageType == 'location' ||
        messageType == 'image' ||
        messageType == 'document';
    final canPin = widget.otherUserId != null || _isCurrentUserAdmin;

    final isSaved = await context.read<ChatService>().isMessageSaved(msg['id']);

    if (!mounted) return;

    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MessageContextMenu(
            messageWidget: messageWidget,
            childRect: childRect,
            isMe: isMe,
            onReply: () => setState(() { 
               _editingMessage = null;
               _replyingToMessage = msg; 
            }),
            onEdit: (msg['message_type'] == 'text' && isMe) ? () {
              final createdAt = DateTime.tryParse(msg['created_at'].toString())?.toLocal() ?? DateTime.now();
              if (DateTime.now().difference(createdAt).inMinutes >= 5) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot edit messages older than 5 minutes.')));
              } else {
                setState(() {
                  _editingMessage = msg;
                  _replyingToMessage = null;
                  _messageController.text = msg['content']?.toString() ?? '';
                });
                _focusNode.requestFocus();
              }
            } : null,
            onForward: () => _handleForward(msg),
            onSave: () async {
              await context.read<ChatService>().toggleSaveMessage(msg['id'], isSaved);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isSaved ? 'Message removed from Saved Messages' : 'Message Saved')),
                );
              }
            },
            isSaved: isSaved,
            onCopy: canCopy
                ? () {
                    final textToCopy = msg['content']?.toString() ?? '';
                    if (textToCopy.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')));
                    }
                  }
                : null,

            onInfo: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.white,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(16))),
                builder: (context) {
                  final time = msg['created_at'] != null
                      ? DateFormat('MMM d, hh:mm a')
                          .format(DateTime.parse(msg['created_at']).toLocal())
                      : 'Unknown';
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Message Info',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.dark)),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.done_all, color: Colors.blue),
                          title: const Text('Read',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          trailing: const Text('---'),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Icon(Icons.done, color: AppColors.grey),
                          title: const Text('Delivered',
                              style: TextStyle(fontWeight: FontWeight.w500)),
                          trailing: Text(time),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            onStar: () async {
              final msgId = msg['id']?.toString();
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
                  await _chatService.starMessage(msgId, !isCurrentlyStarred);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(isCurrentlyStarred ? 'Message unstarred' : 'Message starred')));
                } catch (e) {
                  if (mounted) {
                    setState(() {
                      if (isCurrentlyStarred) {
                        _starredMessageIds.add(msgId);
                      } else {
                        _starredMessageIds.remove(msgId);
                      }
                    });
                  }
                }
              }
            },
            onPin: canPin
                ? () {
                    final msgId = msg['id'];
                    if (msgId != null) {
                      final isCurrentlyPinned = msg['is_pinned'] == true;
                      if (_currentChatId != null) {
                        context
                            .read<ChatService>()
                            .togglePin(msgId.toString(), !isCurrentlyPinned, _currentChatId!);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(isCurrentlyPinned
                              ? 'Message unpinned'
                              : 'Message pinned')));
                    }
                  }
                : null,
            onDelete: () {
              final createdAt = DateTime.tryParse(msg['created_at'].toString())?.toLocal() ?? DateTime.now();
              final difference = DateTime.now().difference(createdAt);
              final canDeleteForEveryone = isMe && difference.inMinutes <= 10;

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Message'),
                  content: Text(isMe ? 'Delete this message?' : 'Delete this message for yourself?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        final msgId = msg['id'];
                        if (msgId != null) {
                          setState(() => _optimisticallyDeletedMessages.add(msgId.toString()));
                          _chatService.deleteMessage(msgId.toString(), forEveryone: false);
                        }
                      },
                      child: const Text('Delete for me', style: TextStyle(color: Colors.red)),
                    ),
                    if (canDeleteForEveryone)
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          final msgId = msg['id'];
                          if (msgId != null) {
                            setState(() => _optimisticallyTombstonedMessages.add(msgId.toString()));
                            _chatService.deleteMessage(msgId.toString(), forEveryone: true);
                          }
                        },
                        child: const Text('Delete for Everyone', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              );
            },
            onReact: (emoji) {
              final msgId = msg['id'];
              if (msgId != null && _currentChatId != null) {
                final mId = msgId.toString();
                final chatService = _chatService;
                final myId = chatService.currentUserId;
                
                // Find current reaction from merged UI state
                String? currentEmoji;
                if (_optimisticReactions.containsKey(mId)) {
                  currentEmoji = _optimisticReactions[mId];
                } else {
                  final myReaction = (msg['reactions'] as List? ?? []).where((r) => r['user_id'] == myId).toList();
                  if (myReaction.isNotEmpty) currentEmoji = myReaction.first['emoji'];
                }

                setState(() {
                  if (currentEmoji == emoji) {
                    _optimisticReactions[mId] = null; // Toggle off
                  } else {
                    _optimisticReactions[mId] = emoji; // Update/Insert
                  }
                });

                context
                    .read<ChatService>()
                    .addReaction(mId, emoji, _currentChatId!);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildMediaGroupGrid(List<Map<String, dynamic>> displayMsgs, bool isMe,
      String timeText, Color bubbleColor, {bool isPending = false, bool isRead = false}) {
    if (displayMsgs.isEmpty) return const SizedBox.shrink();
    final mainMsg = displayMsgs.first;
    Map<String, dynamic> rawMsg = Map.from(mainMsg);

    Widget buildMediaItem(Map<String, dynamic> msg, {bool isLast = false}) {
      final url = msg['media_url'] as String;
      final msgId = msg['id']?.toString();
      final isLocal = !url.startsWith('http') &&
          (url.startsWith('/') ||
              url.startsWith('C:') ||
              url.startsWith('file://') ||
              url.contains('\\\\'));
      final int remainingCount = displayMsgs.length - 4;
      final isVideo = msg['message_type'] == 'video';

      return Expanded(
        child: GestureDetector(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => MediaViewerScreen(
                  initialMediaUrl: url,
                  initialMessageType: isVideo ? 'video' : 'image',
                  senderName: isMe ? 'You' : widget.chatName,
                  time: timeText,
                  chatId: widget.chatId ?? '',
                  messageId: msgId ?? '',
                ),
              ),
            );
            if (result == 'reply' && mounted) {
              setState(() => _replyingToMessage = rawMsg);
            }
          },
          child: Container(
            margin: const EdgeInsets.all(1.5),
            color: Colors.grey[300],
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (isVideo)
                  VideoThumbnailWidget(
                      mediaUrl: url, chatService: _chatService)
                else
                  FutureBuilder<String?>(
                    future: (url.startsWith('http') || isLocal)
                        ? Future.value(url)
                        : _chatService.getMediaSignedUrl(url),
                    builder: (context, snapshot) {
                      final resolvedUrl = snapshot.data ?? '';
                      final isResolvedNetwork = resolvedUrl.startsWith('http');

                      if (resolvedUrl.isEmpty) return const SizedBox.shrink();
                      return Image(
                        image: (isResolvedNetwork
                            ? NetworkImage(resolvedUrl)
                            : FileImage(File(resolvedUrl))) as ImageProvider,
                        fit: BoxFit.cover,
                      );
                    },
                  ),
                if (isVideo)
                  const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 36),
                  ),
                if (isLast && remainingCount > 0)
                  Container(
                    color: Colors.black45,
                    alignment: Alignment.center,
                    child: Text(
                      '+$remainingCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w400),
                    ),
                  )
              ],
            ),
          ),
        ),
      );
    }

    final msgs = displayMsgs.take(4).toList();

    Widget gridWidget;
    if (msgs.length == 1) {
      gridWidget = Row(children: [buildMediaItem(msgs[0])]);
    } else if (msgs.length == 2) {
      gridWidget =
          Row(children: [buildMediaItem(msgs[0]), buildMediaItem(msgs[1])]);
    } else if (msgs.length == 3) {
      gridWidget = Column(
        children: [
          Expanded(child: Row(children: [buildMediaItem(msgs[0])])),
          Expanded(
              child: Row(children: [
            buildMediaItem(msgs[1]),
            buildMediaItem(msgs[2])
          ])),
        ],
      );
    } else {
      gridWidget = Column(
        children: [
          Expanded(
              child: Row(children: [
            buildMediaItem(msgs[0]),
            buildMediaItem(msgs[1])
          ])),
          Expanded(
              child: Row(children: [
            buildMediaItem(msgs[2]),
            buildMediaItem(msgs[3], isLast: displayMsgs.length > 4)
          ])),
        ],
      );
    }

    return SwipeTo(
      key: ValueKey(rawMsg['id']),
      iconOnRightSwipe: Icons.reply,
      onRightSwipe: (details) {
        setState(() => _replyingToMessage = rawMsg);
      },
      iconOnLeftSwipe: Icons.shortcut,
      onLeftSwipe: (details) {
        _handleForward(rawMsg);
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
              bottom: 2, top: 2, left: isMe ? 60 : 16, right: isMe ? 0 : 60),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(4),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                  decoration: BoxDecoration(
                    color: isMe ? bubbleColor : AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isMe ? 16 : 0),
                      bottomRight: Radius.circular(isMe ? 0 : 16),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      )
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: msgs.length == 1
                              ? 220
                              : (msgs.length == 2 ? 140 : 280),
                          width: double.infinity,
                          child: gridWidget,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.black54, Colors.transparent],
                              begin: Alignment.bottomRight,
                              end: Alignment.topLeft,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isPending ? Icons.access_time : (isRead ? Icons.done_all : Icons.check),
                                  size: 14, 
                                  color: isRead ? Colors.blue : Colors.white,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }

  void _showBotCommands() {
    // empty for now
  }

  Widget _buildPollOption(String text,
      {bool isSelected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? AppColors.orange : AppColors.border,
              width: isSelected ? 1.5 : 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: AppColors.dark,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal))),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.orange : AppColors.border,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineKeyboard(List<dynamic> inlineKeyboard) {
    if (inlineKeyboard.isEmpty) return const SizedBox.shrink();
    return Column(
      children: inlineKeyboard.map((row) {
        if (row is! List) return const SizedBox.shrink();
        return Row(
          children: row.map((btn) {
            final text = btn['text']?.toString() ?? '';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange),
                  ),
                  onPressed: () {
                    if (btn['callback_data'] != null) {
                      _messageController.text = btn['callback_data'];
                      _sendMessage();
                    }
                  },
                  child: Text(text),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
  Widget _buildMentionOverlay() {
    if (!_isMentioning || _filteredMentionUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      margin: const EdgeInsets.symmetric(horizontal: 48, vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.8),
              border: Border.all(color: AppColors.lightGrey.withValues(alpha: 0.5), width: 1),
            ),
            child: ListView.builder(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemCount: _filteredMentionUsers.length,
        itemBuilder: (context, index) {
          final user = _filteredMentionUsers[index];
          return InkWell(
            onTap: () {
              final text = _messageController.text;
              final selection = _messageController.selection;
              final textBeforeCursor = text.substring(0, selection.baseOffset);
              final textAfterCursor = text.substring(selection.baseOffset);
              
              final lastAtIndex = textBeforeCursor.lastIndexOf('@');
              if (lastAtIndex != -1) {
                final newTextBeforeCursor = textBeforeCursor.substring(0, lastAtIndex) + '@${user.value} ';
                
                _currentMentions['@${user.value}'] = user.key; // Track the UUID
                
                _messageController.value = TextEditingValue(
                  text: newTextBeforeCursor + textAfterCursor,
                  selection: TextSelection.collapsed(offset: newTextBeforeCursor.length),
                );
                
                setState(() {
                  _isMentioning = false;
                  _mentionQuery = '';
                });
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.orange.withOpacity(0.1),
                    child: Text(
                      user.value.isNotEmpty ? user.value[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    user.value,
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      ),
      ),
      ),
    );
  }

  Widget _buildInputBar(ChatTheme currentTheme, String currentFont) {
    if (_isRecording) {
      return VoiceRecorderBar(
          onCancel: () => setState(() => _isRecording = false),
          onSend: (path) {
            setState(() {
              _isRecording = false;
              _pendingMessages.add({
                'id': 'pending-${DateTime.now().millisecondsSinceEpoch}',
                'sender_id': _chatService.currentUserId,
                'content': 'Voice Message',
                'message_type': 'audio',
                'media_url': path,
                'created_at': DateTime.now().toIso8601String(),
                'is_pending': true,
                if (_replyingToMessage != null)
                  'reply_to_id': _replyingToMessage!['id']?.toString(),
              });
            });
            context
                .read<ChatService>()
                .sendMessage(
                    chatId: _currentChatId!,
                    messageType: 'audio',
                    mediaUrl: path,
                    content: 'Voice Message',
                    replyToId: _replyingToMessage?['id']?.toString())
                .then((_) {
              if (mounted) {
                setState(() {
                  _pendingMessages.removeWhere((m) => m['media_url'] == path);
                  if (_replyingToMessage != null) _replyingToMessage = null;
                });
              }
            }).catchError((e) {
              if (mounted) {
                setState(() => _pendingMessages
                    .removeWhere((m) => m['media_url'] == path));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Failed to send voice message: $e')));
              }
            });
          });
    }
    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle, color: AppColors.orange, size: 30),
              splashRadius: 24,
              onPressed: () {
                AttachmentMenuBottomSheet.show(context, _currentChatId!,
                    _replyingToMessage?['id']?.toString(), () {
                  if (mounted) setState(() => _replyingToMessage = null);
                });
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
                  controller: _messageController,
                  focusNode: _focusNode,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: GoogleFonts.getFont(currentFont, color: currentTheme.receiverTextColor),
                  onChanged: (text) {
                    // Handled by _messageController listener
                  },
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: GoogleFonts.getFont(currentFont, color: currentTheme.receiverTextColor.withOpacity(0.5), fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    prefixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(width: 4),
                        IconButton(
                          splashRadius: 20,
                          icon: Icon(
                              _showEmoji
                                  ? Icons.keyboard
                                  : Icons.emoji_emotions_outlined,
                              color: AppColors.grey),
                          onPressed: () {
                            if (_showEmoji) {
                              _focusNode.requestFocus();
                            } else {
                              _focusNode.unfocus();
                              setState(() {
                                _showEmoji = true;
                              });
                            }
                          },
                        ),
                        if (_isBot && _botCommands.isNotEmpty)
                          IconButton(
                            splashRadius: 20,
                            icon: const Icon(Icons.data_object,
                                color: AppColors.orange),
                            tooltip: 'Commands',
                            onPressed: _showBotCommands,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_isTyping)
              IconButton(
                icon: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.grey),
                onPressed: () async {
                  final file =
                      await ImagePicker().pickImage(source: ImageSource.camera);
                  if (file != null && mounted) {
                    setState(() {
                      _pendingMessages.add({
                        'id':
                            'pending-${DateTime.now().millisecondsSinceEpoch}',
                        'sender_id': _chatService.currentUserId,
                        'content': '',
                        'message_type': 'image',
                        'media_url': file.path,
                        'created_at': DateTime.now().toIso8601String(),
                        'is_pending': true,
                      });
                    });
                    context
                        .read<ChatService>()
                        .sendMessage(
                            chatId: _currentChatId!,
                            messageType: 'image',
                            mediaUrl: file.path,
                            content: '')
                        .then((_) {
                      if (mounted)
                        setState(() => _pendingMessages
                            .removeWhere((m) => m['media_url'] == file.path));
                    }).catchError((e) {
                      if (mounted)
                        setState(() => _pendingMessages
                            .removeWhere((m) => m['media_url'] == file.path));
                    });
                  }
                },
              ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _isTyping
                  ? _sendMessage
                  : () async {
                      try {
                        if (await Permission.microphone.request().isGranted) {
                          setState(() => _isRecording = true);
                        }
                      } catch (e) {
                        debugPrint('Microphone permission error: $e');
                      }
                    },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.orange,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isTyping ? Icons.send : Icons.mic,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

