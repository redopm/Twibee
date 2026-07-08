import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'package:intl/intl.dart';
import 'individual_chat_screen.dart';
import 'contacts_screen.dart';
import 'select_group_members_screen.dart';
import 'locked_chats_screen.dart';
import 'archived_chats_screen.dart';
import 'qr_scanner_screen.dart';
import 'create_list_screen.dart';
import 'contact_info_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'lists_screen.dart';
import 'new_broadcast_screen.dart';
import 'package:twibee/widgets/hexagon_avatar.dart';

class ChatsHomeScreen extends StatefulWidget {
  const ChatsHomeScreen({super.key});

  @override
  State<ChatsHomeScreen> createState() => _ChatsHomeScreenState();
}

class _ChatsHomeScreenState extends State<ChatsHomeScreen> with WidgetsBindingObserver {
  String _selectedFilter = 'All';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  Timer? _debounce;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];
  bool _isMultiSelectMode = false;

  final Set<String> _selectedChatIds = {};

  // Set of chat IDs that are in the user's 'Favorites' list
  Set<String> _favoriteChatIds = {};

  late Stream<List<Map<String, dynamic>>> _chatsStream;
  bool _isNotificationDenied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkNotificationPermission();
    _chatsStream = context.read<ChatService>().getChatsStream().asBroadcastStream();
    // In a real app, load locked chats from local storage/secure storage here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatService>().loadBlockedUsers();
      _loadFavorites();
    });
  }

  Future<void> _loadFavorites() async {
    final supabase = context.read<ChatService>().supabaseClient;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      // Find the 'Favorites' list ID
      final listData = await supabase
          .from('chat_lists')
          .select('id')
          .eq('user_id', userId)
          .eq('name', 'Favorites')
          .maybeSingle();

      if (listData != null) {
        final listId = listData['id'];
        final membersData = await supabase
            .from('chat_list_members')
            .select('chat_id')
            .eq('list_id', listId);

        setState(() {
          _favoriteChatIds =
              membersData.map((m) => m['chat_id'] as String).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

  Future<void> _toggleFavorite(String chatId) async {
    final supabase = context.read<ChatService>().supabaseClient;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;
    try {
      var listData = await supabase
          .from('chat_lists')
          .select('id')
          .eq('user_id', userId)
          .eq('name', 'Favorites')
          .maybeSingle();
      String listId;
      if (listData == null) {
        final created = await supabase
            .from('chat_lists')
            .insert({'user_id': userId, 'name': 'Favorites'})
            .select('id')
            .single();
        listId = created['id'];
      } else {
        listId = listData['id'];
      }
      final isCurrentlyFav = _favoriteChatIds.contains(chatId);
      if (isCurrentlyFav) {
        await supabase
            .from('chat_list_members')
            .delete()
            .eq('list_id', listId)
            .eq('chat_id', chatId);
        setState(() => _favoriteChatIds.remove(chatId));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Removed from Favorites')));
      } else {
        await supabase.from('chat_list_members').upsert(
            {'list_id': listId, 'chat_id': chatId},
            onConflict: 'list_id,chat_id');
        setState(() => _favoriteChatIds.add(chatId));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Added to Favorites ⭐')));
      }
    } catch (e) {
      debugPrint('Error toggling favorite: $e');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkNotificationPermission();
      context.read<ChatService>().initLocalContactsCache();
    }
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _isNotificationDenied = status.isDenied || status.isPermanentlyDenied;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black12,
        centerTitle: false,
        title: _isMultiSelectMode
            ? Row(
                children: [
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded, color: AppColors.orange, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${_selectedChatIds.length} selected',
                    style: const TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.orange, Color(0xFFFF8C42)],
                  ).createShader(bounds),
                  child: const Text(
                    'Chats',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
        actions: _isMultiSelectMode
            ? [
                IconButton(
                  icon: const Icon(Icons.push_pin_outlined,
                      color: AppColors.dark),
                  onPressed: () {
                    for (var id in _selectedChatIds) {
                      context.read<ChatService>().pinChat(id, true);
                    }
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedChatIds.clear();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.volume_off_outlined,
                      color: AppColors.dark),
                  onPressed: () {
                    for (var id in _selectedChatIds) {
                      context.read<ChatService>().muteChat(id, true);
                    }
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedChatIds.clear();
                    });
                  },
                ),
                IconButton(
                  icon:
                      const Icon(Icons.archive_outlined, color: AppColors.dark),
                  onPressed: () {
                    for (var id in _selectedChatIds) {
                      context.read<ChatService>().archiveChat(id, true);
                    }
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedChatIds.clear();
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.red),
                  onPressed: () {
                    for (var id in _selectedChatIds) {
                      context.read<ChatService>().deleteChat(id);
                    }
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedChatIds.clear();
                    });
                  },
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.dark),
                  color: Colors.white,
                  onSelected: (value) async {
                    if (value == 'lock') {
                      for (var id in _selectedChatIds) {
                        await context.read<ChatService>().lockChat(id);
                      }
                    } else if (value == 'mark_read') {
                      for (var id in _selectedChatIds) {
                        context.read<ChatService>().markChatRead(id);
                      }
                    } else if (value == 'mark_unread') {
                      for (var id in _selectedChatIds) {
                        context.read<ChatService>().markChatUnread(id);
                      }
                    }
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedChatIds.clear();
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                        value: 'lock', child: Text('Lock chat')),
                    const PopupMenuItem(
                        value: 'mark_read', child: Text('Mark as read')),
                    const PopupMenuItem(
                        value: 'mark_unread', child: Text('Mark as unread')),
                    const PopupMenuItem(
                        value: 'add_list', child: Text('Add to list')),
                    const PopupMenuItem(
                        value: 'select_more', child: Text('Select more chats')),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.dark),
                  onPressed: () {
                    setState(() {
                      _isMultiSelectMode = false;
                      _selectedChatIds.clear();
                    });
                  },
                ),
              ]
            : [
                IconButton(
                  icon: const Icon(Icons.camera_alt_outlined,
                      color: AppColors.dark),
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const QRScannerScreen()));
                  },
                ),
                // New Chat Button (+) in Theme Color
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: PopupMenuButton<String>(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add, color: AppColors.white, size: 22),
                    ),
                    onSelected: (value) {
                      if (value == 'new_chat') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const ContactsScreen()));
                      } else if (value == 'new_group') {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const SelectGroupMembersScreen()));
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return [
                        const PopupMenuItem(
                            value: 'new_chat', child: Text('New Chat')),
                        const PopupMenuItem(
                            value: 'new_group', child: Text('New Group')),
                      ];
                    },
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.dark),
                  color: AppColors.white,
                  onSelected: (value) {
                    if (value == 'select_chats') {
                      setState(() {
                        _isMultiSelectMode = true;
                      });
                    } else if (value == 'read_all') {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('All chats marked as read!')));
                    } else if (value == 'new_broadcast') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NewBroadcastScreen()));
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    return [
                      const PopupMenuItem(
                          value: 'new_broadcast', child: Text('New broadcast')),
                      const PopupMenuItem(
                          value: 'starred_messages',
                          child: Text('Starred messages')),
                      const PopupMenuItem(
                          value: 'select_chats', child: Text('Select chats')),
                      const PopupMenuItem(
                          value: 'read_all', child: Text('Read all')),
                    ];
                  },
                ),
                const SizedBox(width: 8),
              ],
      ),
      body: _buildChatsTab(),
    );
  }

  Widget _buildChatsTab() {
    return Column(
      children: [
        if (_isNotificationDenied)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.red.shade50,
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Notifications Disabled',
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'You won\'t receive call or message alerts.',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('Enable Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        // ── Search Bar ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                if (_debounce?.isActive ?? false) _debounce?.cancel();
                if (val.trim().isEmpty) {
                  setState(() {
                    _searchQuery = '';
                    _isSearching = false;
                    _searchResults = [];
                  });
                  return;
                }
                _debounce = Timer(const Duration(milliseconds: 300), () async {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                    _isSearching = true;
                  });
                  final results = await context
                      .read<ChatService>()
                      .searchMessages(_searchQuery);
                  if (mounted) {
                    setState(() {
                      _searchResults = results;
                      _isSearching = false;
                    });
                  }
                });
              },
              style: const TextStyle(fontSize: 15, color: AppColors.dark),
              decoration: InputDecoration(
                hintText: 'Search messages or contacts...',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ),
        // ── Filter Chips ─────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4, top: 4),
          child: SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildFilterChip('All', isSelected: _selectedFilter == 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Unread', isSelected: _selectedFilter == 'Unread'),
                const SizedBox(width: 8),
                _buildFilterChip('Favorites', isSelected: _selectedFilter == 'Favorites'),
                const SizedBox(width: 8),
                _buildFilterChip('Groups', isSelected: _selectedFilter == 'Groups'),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateListScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(Icons.add_rounded, color: AppColors.grey, size: 20),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 24),
          leading: const Icon(Icons.archive_outlined, color: AppColors.dark),
          title: const Text('Archived',
              style: TextStyle(
                  color: AppColors.dark, fontWeight: FontWeight.bold)),
          onTap: () {
            Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()));
          },
        ),
        // Chats List or Search Results
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildSearchResults()
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _chatsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.orange));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final List<Map<String, dynamic>> chats =
                        List.from(snapshot.data ?? []);

                    final chatService = context.watch<ChatService>();
                    final lockedChats = chatService.lockedChatIds;

                    // Filter chats based on selected chip (search is handled separately now)
                    List<Map<String, dynamic>> visibleChats = chats.where((c) {
                      if (lockedChats.contains(c['id'])) return false;
                      if (c['is_archived'] == true) return false;

                      if (_selectedFilter == 'Unread') {
                        return (c['unread_count'] ?? 0) > 0;
                      } else if (_selectedFilter == 'Groups') {
                        return c['is_group'] == true;
                      } else if (_selectedFilter == 'Favorites') {
                        return _favoriteChatIds.contains(c['id']);
                      }
                      return true;
                    }).toList();

                    // Sort pinned first, then by recency
                    visibleChats.sort((a, b) {
                      bool aPinned = a['is_pinned'] == true;
                      bool bPinned = b['is_pinned'] == true;
                      if (aPinned && !bPinned) return -1;
                      if (!aPinned && bPinned) return 1;

                      DateTime timeA = a['last_message_at'] != null
                          ? DateTime.parse(a['last_message_at'])
                          : DateTime.fromMillisecondsSinceEpoch(0);
                      DateTime timeB = b['last_message_at'] != null
                          ? DateTime.parse(b['last_message_at'])
                          : DateTime.fromMillisecondsSinceEpoch(0);
                      return timeB.compareTo(timeA);
                    });

                    if (visibleChats.isEmpty &&
                        _searchQuery.isEmpty &&
                        _selectedFilter == 'All') {
                      return const Center(
                        child: Text('Start a conversation!',
                            style: TextStyle(color: AppColors.grey)),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100, top: 4),
                      itemCount: visibleChats.length +
                          (lockedChats.isNotEmpty ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (lockedChats.isNotEmpty && index == 0) {
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            leading: const Icon(Icons.lock_outline,
                                color: AppColors.orange),
                            title: const Text('Locked chats',
                                style: TextStyle(
                                    color: AppColors.dark,
                                    fontWeight: FontWeight.bold)),
                            trailing: const Icon(Icons.chevron_right,
                                color: AppColors.grey),
                            onTap: () async {
                              final authenticated = await context
                                  .read<ChatService>()
                                  .authenticateForLock();
                              if (authenticated && context.mounted) {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const LockedChatsScreen()));
                              }
                            },
                          );
                        }

                        final actualIndex =
                            lockedChats.isNotEmpty ? index - 1 : index;
                        final chat = visibleChats[actualIndex];
                        final isGroup = chat['is_group'] ?? false;

                        String name = 'Unknown';
                        String avatarText = '?';
                        String? avatarUrl;
                        bool isOnline = false;
                        String? otherUserId;

                        if (isGroup) {
                          name = chat['group_name'] ?? 'Group Chat';
                          avatarText = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                          avatarUrl = chat['group_avatar_url'];
                        } else {
                          final otherUser = chat['other_user'];
                          if (otherUser != null) {
                            final phone = otherUser['phone']?.toString() ?? '';
                            name = chatService.getContactName(phone, otherUser['name'] ?? 'Unknown');
                            avatarText = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                            avatarUrl = otherUser['avatar_url'];
                            isOnline = otherUser['is_online'] ?? false;
                            otherUserId = otherUser['id'];
                          }
                        }

                        final lastMessage = chat['last_message'];
                        String messageText = 'Say hi! 👋';
                        bool isRead = true; // Default
                        int unreadCount = chat['unread_count'] ?? 0;
                        bool isPinned = chat['is_pinned'] == true;
                        bool isMuted = chat['is_muted'] == true;
                        bool isDeleted = false;
                        if (lastMessage != null) {
                          final deletedBy = lastMessage['deleted_by'] as List<dynamic>? ?? [];
                          bool isDeletedForMe = deletedBy.contains(chatService.currentUserId);
                          bool isDeletedForEveryone = lastMessage['is_deleted_for_everyone'] == true;
                          isDeleted = isDeletedForMe || isDeletedForEveryone;
                          String msgType = lastMessage['message_type'] ?? 'text';
                          String rawContent = lastMessage['content']?.toString().trim() ?? '';
                          
                          // Remove legacy emoji prefixes from forwarded messages
                          if (rawContent == '📷 Photo') rawContent = 'Photo';
                          if (rawContent == '🎥 Video') rawContent = 'Video';
                          if (rawContent == '🎤 Audio') rawContent = 'Audio';
                          if (rawContent == '📄 Document') rawContent = 'Document';

                          if (rawContent.isEmpty) {
                            if (msgType == 'image') rawContent = 'Photo';
                            else if (msgType == 'video') rawContent = 'Video';
                            else if (msgType == 'audio') rawContent = 'Audio';
                            else if (msgType == 'document') rawContent = 'Document';
                            else rawContent = 'Media message';
                          }
                          
                          final content = isDeleted ? 'This message was deleted' : rawContent;
                          
                          if (isDeleted) {
                            messageText = content;
                          } else if (isGroup &&
                              lastMessage['sender_name'] != null &&
                              lastMessage['sender_name'].isNotEmpty &&
                              lastMessage['sender_name'] != 'You') {
                            messageText =
                                '${lastMessage['sender_name']}: $content';
                          } else if (isGroup &&
                              lastMessage['sender_name'] == 'You') {
                            messageText = 'You: $content';
                          } else {
                            messageText = content;
                          }

                          bool isMe = lastMessage['sender_id'] ==
                              chatService.currentUserId;
                          if (isMe) {
                            // Determine read receipt using other_last_read_at
                            DateTime? otherLastRead;
                            if (chat['other_last_read_at'] != null) {
                              otherLastRead =
                                  DateTime.parse(chat['other_last_read_at']);
                            }
                            DateTime msgTime = chat['last_message_at'] != null
                                ? DateTime.parse(chat['last_message_at'])
                                : DateTime.now();
                            isRead = otherLastRead != null &&
                                (otherLastRead.isAfter(msgTime) ||
                                    otherLastRead.isAtSameMomentAs(msgTime));
                          } else {
                            isRead = unreadCount == 0;
                          }
                        }

                        String timeText = '';
                        if (chat['last_message_at'] != null) {
                          final time =
                              DateTime.parse(chat['last_message_at']).toLocal();
                          timeText = DateFormat('hh:mm a').format(time);
                        }

                        int unreadMentions = chat['unread_mentions_count'] ?? 0;

                        return _buildChatTile(
                          name: name,
                          message: messageText,
                          messageType: lastMessage?['message_type'] ?? 'text',
                          time: timeText,
                          isRead: isRead,
                          isSentByMe: lastMessage?['sender_id'] ==
                              chatService.currentUserId,
                          unreadCount: unreadCount,
                          unreadMentionsCount: unreadMentions,
                          isPinned: isPinned,
                          isMuted: isMuted,
                          avatarText: avatarText,
                          avatarUrl: avatarUrl,
                          avatarColor:
                              AppColors.orange, // Can randomize or hash
                          isOnline: isOnline,
                          chatId: chat['id'],
                          otherUserId: otherUserId,
                          isSelected: _selectedChatIds.contains(chat['id']),
                          isDeletedForEveryone: isDeleted,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.orange : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(17),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: isSelected ? 0.2 : 0,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_isSearching) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.orange));
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child:
            Text('No messages found', style: TextStyle(color: AppColors.grey)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final msg = _searchResults[index];
        final chatName = msg['chat_name'] ?? 'Unknown Chat';
        final senderName = msg['sender_name'] ?? 'Someone';
        final content = msg['content'] ?? '';
        final isGroup = msg['is_group'] ?? false;

        String timeText = '';
        if (msg['created_at'] != null) {
          final time = DateTime.parse(msg['created_at']).toLocal();
          timeText = DateFormat('hh:mm a').format(time);
        }

        return ListTile(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IndividualChatScreen(
                  chatId: msg['chat_id'],
                  chatName: chatName,
                  otherUserId: isGroup ? null : msg['other_user_id'] as String?,
                  avatarUrl: msg['other_user_avatar'] as String?,
                  unreadCount: msg['unread_count'] as int? ?? 0,
                ),
              ),
            );
          },
          leading: CircleAvatar(
            backgroundColor: AppColors.orange,
            child: Text(
              chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.white, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(chatName, style: AppTextStyles.title),
          subtitle: Text(
            isGroup ? '$senderName: $content' : content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.subtitle.copyWith(color: AppColors.grey),
          ),
          trailing: Text(timeText,
              style: const TextStyle(fontSize: 12, color: AppColors.grey2)),
        );
      },
    );
  }

  void _handleMuteChat(String chatId, bool isMuted) {
    context.read<ChatService>().muteChat(chatId, !isMuted);
  }

  void _handlePinChat(String chatId, bool isPinned) {
    context.read<ChatService>().pinChat(chatId, !isPinned);
  }

  void _handleArchiveChat(String chatId, bool isArchived) {
    context.read<ChatService>().archiveChat(chatId, !isArchived);
  }

  void _handleDeleteChat(String chatId) {
    context.read<ChatService>().deleteChat(chatId);
  }

  void _handleMarkRead(String chatId, {int unreadCount = 0}) {
    if (unreadCount > 0) {
      context.read<ChatService>().markChatRead(chatId);
    } else {
      context.read<ChatService>().markChatUnread(chatId);
    }
  }

  void _showMoreOptionsBottomSheet({
    required BuildContext context,
    required String chatId,
    required bool isMuted,
    required bool isPinned,
    required String name,
    required int unreadCount,
    String? otherUserId,
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
                    _handleMarkRead(chatId);
                  },
                ),
                ListTile(
                  leading:
                      const Icon(Icons.archive_outlined, color: AppColors.dark),
                  title: const Text('Archive',
                      style: TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _handleArchiveChat(chatId, false);
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
                    _handleMuteChat(chatId, isMuted);
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
                  leading: Icon(
                      _favoriteChatIds.contains(chatId)
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: AppColors.dark),
                  title: Text(
                      _favoriteChatIds.contains(chatId)
                          ? 'Remove from Favorites'
                          : 'Add to Favorites',
                      style: const TextStyle(
                          color: AppColors.dark, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _toggleFavorite(chatId);
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
                  leading: const Icon(Icons.block, color: AppColors.red),
                  title: Text('Block $name',
                      style: const TextStyle(
                          color: AppColors.red, fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    if (otherUserId != null) {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Block $name?'),
                          content: Text('$name will not be able to message or call you.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Block', style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await context.read<ChatService>().blockContact(otherUserId);
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$name has been blocked')));
                      }
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: AppColors.red),
                  title: const Text('Clear chat',
                      style: TextStyle(color: AppColors.red, fontWeight: FontWeight.w500)),
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear chat?'),
                        content: const Text('All your sent messages will be permanently deleted.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear', style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      await context.read<ChatService>().clearChat(chatId);
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat cleared ✓')));
                    }
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
                    _handleDeleteChat(chatId);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPeekAndPopContextMenu({
    required BuildContext context,
    required String chatId,
    required String name,
    required String avatarText,
    required Color avatarColor,
    required String? otherUserId,
    required bool isMuted,
    required bool isPinned,
    required int unreadCount,
    required Rect childRect,
  }) {
    // Navigate to a custom opaque overlay
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black54, // Dim background
        pageBuilder: (context, animation, secondaryAnimation) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                // Dismiss gesture
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(color: Colors.transparent),
                  ),
                ),

                // Content Layout
                Center(
                  child: Material(
                    color: AppColors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: 250,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildContextMenuItem(
                            context,
                            icon: unreadCount > 0
                                ? Icons.mark_chat_read
                                : Icons.mark_chat_unread,
                            title: unreadCount > 0
                                ? 'Mark as read'
                                : 'Mark as unread',
                            onTap: () => _handleMarkRead(chatId),
                          ),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(
                            context,
                            icon: Icons.archive_outlined,
                            title: 'Archive',
                            onTap: () => _handleArchiveChat(chatId, false),
                          ),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(
                            context,
                            icon: isMuted
                                ? Icons.volume_up_outlined
                                : Icons.volume_off_outlined,
                            title: isMuted ? 'Unmute' : 'Mute',
                            onTap: () => _handleMuteChat(chatId, isMuted),
                          ),
                          const Divider(height: 1, color: AppColors.border),
                          _buildContextMenuItem(
                            context,
                            icon: isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin_rounded,
                            title: isPinned ? 'Unpin' : 'Pin chat',
                            onTap: () => _handlePinChat(chatId, isPinned),
                          ),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(context,
                              icon: Icons.lock_outline,
                              title: 'Lock chat', onTap: () async {
                            final success = await context
                                .read<ChatService>()
                                .lockChat(chatId);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Chat locked.')));
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Authentication failed. Please set up a screen lock.')));
                            }
                          }),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(
                            context,
                            icon: _favoriteChatIds.contains(chatId)
                                ? Icons.favorite
                                : Icons.favorite_border,
                            title: _favoriteChatIds.contains(chatId)
                                ? 'Remove from Favorites'
                                : 'Add to Favorites',
                            onTap: () => _toggleFavorite(chatId),
                          ),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(
                            context,
                            icon: Icons.list_alt,
                            title: 'Add to list',
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ListsScreen())),
                          ),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(
                            context,
                            icon: Icons.block,
                            title: otherUserId != null ? 'Block $name' : 'Exit group',
                            isDestructive: true,
                            onTap: () async {
                              if (otherUserId != null) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Block $name?'),
                                    content: Text('$name will not be able to message or call you.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.pop(ctx, true),
                                          child: const Text('Block', style: TextStyle(color: Colors.red))),
                                    ],
                                  ),
                                );
                                if (confirm == true && mounted) {
                                  await context.read<ChatService>().blockContact(otherUserId);
                                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('$name has been blocked')));
                                }
                              }
                            },
                          ),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(
                            context,
                            icon: Icons.cancel_outlined,
                            title: 'Clear chat',
                            isDestructive: true,
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Clear chat?'),
                                  content: const Text('All your sent messages will be permanently deleted.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Clear', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true && mounted) {
                                await context.read<ChatService>().clearChat(chatId);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Chat cleared ✓')));
                              }
                            },
                          ),
                          const Divider(height: 1, color: AppColors.grey2),
                          _buildContextMenuItem(
                            context,
                            icon: Icons.delete_outline,
                            title: 'Delete chat',
                            isDestructive: true,
                            onTap: () => _handleDeleteChat(chatId),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContextMenuItem(BuildContext context,
      {required IconData icon,
      required String title,
      required VoidCallback onTap,
      bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon,
                  color: isDestructive ? AppColors.red : AppColors.dark,
                  size: 24),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: isDestructive ? AppColors.red : AppColors.dark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatTile({
    required String name,
    required String message,
    required String time,
    String messageType = 'text',
    int unreadCount = 0,
    int unreadMentionsCount = 0,
    bool isRead = false,
    bool isSentByMe = false,
    bool isPinned = false,
    bool isMuted = false,
    required String avatarText,
    String? avatarUrl,
    required Color avatarColor,
    bool isOnline = false,
    String? chatId,
    String? otherUserId,
    bool isSelected = false,
    bool isDeletedForEveryone = false,
  }) {
    IconData? mediaIcon;
    if (messageType == 'image') mediaIcon = Icons.photo_camera;
    else if (messageType == 'video') mediaIcon = Icons.videocam_outlined;
    else if (messageType == 'audio') mediaIcon = Icons.mic_none_outlined;
    else if (messageType == 'document') mediaIcon = Icons.insert_drive_file_outlined;

    return Slidable(
      key: Key(chatId ?? name),
      startActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (context) {
              if (chatId != null) {
                _handleMarkRead(chatId);
              }
            },
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            icon: Icons.mark_chat_read,
            label: 'Read',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (context) {
              if (chatId != null) {
                _showMoreOptionsBottomSheet(
                  context: context,
                  chatId: chatId,
                  isMuted: isMuted,
                  isPinned: isPinned,
                  name: name,
                  unreadCount: unreadCount,
                );
              }
            },
            backgroundColor: AppColors.dark,
            foregroundColor: Colors.white,
            icon: Icons.more_horiz,
            label: 'More',
          ),
          SlidableAction(
            onPressed: (context) {
              if (chatId != null) {
                _handleArchiveChat(chatId, false);
              }
            },
            backgroundColor: AppColors.orange,
            foregroundColor: Colors.white,
            icon: Icons.archive,
            label: 'Archive',
          ),
        ],
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        color: isSelected ? AppColors.orange.withValues(alpha: 0.08) : Colors.transparent,
        child: Builder(
          builder: (builderContext) {
            // Generate a consistent color from the name
            final avatarGradient = _nameToGradient(name);
            return GestureDetector(
              onLongPressStart: (details) {
                if (chatId != null) {
                  final renderBox =
                      builderContext.findRenderObject() as RenderBox;
                  final offset = renderBox.localToGlobal(Offset.zero);
                  final rect = offset & renderBox.size;

                  _showPeekAndPopContextMenu(
                    context: context,
                    chatId: chatId,
                    name: name,
                    avatarText: avatarText,
                    avatarColor: avatarColor,
                    otherUserId: otherUserId,
                    isMuted: isMuted,
                    isPinned: isPinned,
                    unreadCount: unreadCount,
                    childRect: rect,
                  );
                }
              },
              child: ListTile(
                onTap: () {
                  if (_isMultiSelectMode && chatId != null) {
                    setState(() {
                      if (_selectedChatIds.contains(chatId)) {
                        _selectedChatIds.remove(chatId);
                        if (_selectedChatIds.isEmpty) _isMultiSelectMode = false;
                      } else {
                        _selectedChatIds.add(chatId);
                      }
                    });
                    return;
                  }
                  if (chatId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => IndividualChatScreen(
                          chatId: chatId,
                          chatName: name,
                          otherUserId: otherUserId,
                          avatarUrl: avatarUrl,
                          unreadCount: unreadCount,
                        ),
                      ),
                    );
                  }
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: Stack(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContactInfoScreen(
                              name: name,
                              avatarUrl: avatarUrl,
                              avatarText: avatarText,
                              avatarColor: avatarColor,
                              chatId: chatId ?? '',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 52, height: 52,
                        decoration: BoxDecoration(
                          gradient: avatarUrl == null ? LinearGradient(
                            colors: avatarGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ) : null,
                          shape: BoxShape.circle,
                          image: avatarUrl != null ? DecorationImage(
                            image: CachedNetworkImageProvider(avatarUrl),
                            fit: BoxFit.cover,
                          ) : null,
                          boxShadow: [
                            BoxShadow(
                              color: avatarGradient.first.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: avatarUrl == null ? Center(
                          child: Text(
                            avatarText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ) : null,
                      ),
                    ),
                    if (isOnline)
                      Positioned(
                        bottom: 1,
                        right: 1,
                        child: Container(
                          width: 13,
                          height: 13,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                          color: AppColors.dark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPinned)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.push_pin_rounded, size: 13, color: AppColors.grey2),
                      ),
                    if (isMuted)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.volume_off_rounded, size: 13, color: AppColors.grey2),
                      ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      if (isSentByMe && !isDeletedForEveryone)
                        Padding(
                          padding: const EdgeInsets.only(right: 3.0),
                          child: Icon(
                            isRead ? Icons.done_all_rounded : Icons.check_rounded,
                            color: isRead
                                ? const Color(0xFF3399FF)   // blue = read
                                : Colors.grey.shade400,      // grey = not read yet
                            size: 15,
                          ),
                        ),
                      if (mediaIcon != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Icon(mediaIcon, size: 14, color: Colors.grey.shade500),
                        ),
                      Expanded(
                        child: Text(
                          message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontStyle: isDeletedForEveryone ? FontStyle.italic : FontStyle.normal,
                            fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            color: unreadCount > 0 ? const Color(0xFF333333) : Colors.grey.shade500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: unreadCount > 0 ? AppColors.orange : Colors.grey.shade400,
                        fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (unreadMentionsCount > 0)
                          Container(
                            margin: const EdgeInsets.only(right: 4),
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text('@',
                                style: TextStyle(color: AppColors.dark, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        if (unreadCount > 0)
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: isMuted ? Colors.grey.shade300 : AppColors.orange,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              unreadCount > 99 ? '99+' : unreadCount.toString(),
                              style: TextStyle(
                                color: isMuted ? Colors.grey.shade600 : Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          const SizedBox(width: 20),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Returns a consistent gradient pair based on the contact name
  List<Color> _nameToGradient(String name) {
    const gradients = [
      [Color(0xFFFF6B00), Color(0xFFFF8C42)], // orange
      [Color(0xFF6C63FF), Color(0xFF9C8FFF)], // purple
      [Color(0xFF00B4D8), Color(0xFF48CAE4)], // teal
      [Color(0xFF2DC653), Color(0xFF51CF66)], // green
      [Color(0xFFE63946), Color(0xFFFF6B6B)], // red
      [Color(0xFFFFB703), Color(0xFFFFD166)], // yellow
      [Color(0xFF3A86FF), Color(0xFF74B3FF)], // blue
      [Color(0xFFE040FB), Color(0xFFEA80FC)], // pink
    ];
    final hash = name.isEmpty ? 0 : name.codeUnits.fold(0, (a, b) => a + b);
    final pair = gradients[hash % gradients.length];
    return [pair[0], pair[1]];
  }
}

