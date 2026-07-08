import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:archive/archive_io.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:archive/archive.dart';
import 'package:share_plus/share_plus.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:crypto/crypto.dart';
import 'encryption_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path/path.dart' as p;
import 'package:dio/dio.dart';
import '../utils/media_compressor.dart';

class ContactSyncResult {
  final List<Map<String, dynamic>> registeredUsers;
  final List<Contact> unregisteredContacts;

  ContactSyncResult({
    required this.registeredUsers,
    required this.unregisteredContacts,
  });
}

class ChatService extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;

  final _secureStorage = const FlutterSecureStorage();
  final _localAuth = LocalAuthentication();
  final StreamController<void> _refreshChatsController = StreamController<void>.broadcast();

  Set<String> _lockedChatIds = {};
  bool _isLockedChatsUnlocked = false;

  // Local state for blocked users
  final List<String> _blockedUserIds = [];

  SupabaseClient get supabaseClient => _supabase;
  bool _blockedUsersLoaded = false;

  // ---------------------------------
  // Current User Profile State
  Map<String, dynamic>? currentUserProfile;

  // ---------------------------------
  // Typing Indicators State
  Map<String, String> typingChats = {};
  final Map<String, RealtimeChannel> _groupTypingChannels = {};
  Map<String, Timer> _typingTimers = {};
  RealtimeChannel? _userEventsChannel;

  List<Map<String, dynamic>> _offlineQueue = [];
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  Database? _offlineDb;

  // Local contact cache for mapping unsaved numbers to contact names in chats
  Map<String, String> localContactsCache = {};

  ChatService() {
    _loadLockedChats();
    _initOfflineQueue();
    initLocalContactsCache();
  }

  Future<void> _initOfflineQueue() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'Twibee_offline.db');
    _offlineDb = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_messages (
            local_id TEXT PRIMARY KEY,
            data TEXT
          )
        ''');
      },
    );

    try {
      final List<Map<String, dynamic>> maps = await _offlineDb!.query('offline_messages');
      _offlineQueue = maps.map((e) {
        return jsonDecode(e['data'] as String) as Map<String, dynamic>;
      }).toList();
    } catch (e) {
      debugPrint('Error loading offline queue from SQLite: $e');
    }
    notifyListeners();

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncOfflineMessages();
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _offlineDb?.close();
    super.dispose();
  }

  List<Map<String, dynamic>> get offlineQueue => _offlineQueue;

  Future<void> syncOfflineMessages() async {
    if (_offlineQueue.isEmpty) return;
    
    // Copy and clear to prevent concurrent modification issues or duplicates
    final messagesToSync = List<Map<String, dynamic>>.from(_offlineQueue);
    _offlineQueue.clear();
    if (_offlineDb != null) {
      await _offlineDb!.delete('offline_messages');
    }
    notifyListeners();

    for (var msgData in messagesToSync) {
      try {
        final payload = Map<String, dynamic>.from(msgData);
        payload.remove('is_pending');
        payload.remove('local_id');
        payload.remove('created_at'); // Let database set timestamp
        
        await _supabase.from('messages').insert(payload);
      } catch (e) {
        debugPrint('Failed to sync offline message: $e');
        if (e is SocketException || e.toString().contains('ClientException') || e.toString().contains('Failed host lookup')) {
           _offlineQueue.add(msgData);
           if (_offlineDb != null) {
             await _offlineDb!.insert('offline_messages', {
               'local_id': msgData['local_id'],
               'data': jsonEncode(msgData),
             }, conflictAlgorithm: ConflictAlgorithm.replace);
           }
           notifyListeners();
        }
      }
    }
  }

  Future<void> _loadLockedChats() async {
    try {
      final lockedStr = await _secureStorage.read(key: 'locked_chats');
      if (lockedStr != null) {
        final List<dynamic> decoded = jsonDecode(lockedStr);
        _lockedChatIds = decoded.map((e) => e.toString()).toSet();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading locked chats: $e');
    }
  }

  Future<void> _saveLockedChats() async {
    await _secureStorage.write(
        key: 'locked_chats', value: jsonEncode(_lockedChatIds.toList()));
  }

  bool isChatLocked(String chatId) => _lockedChatIds.contains(chatId);
  Set<String> get lockedChatIds => _lockedChatIds;
  bool get isLockedChatsUnlocked => _isLockedChatsUnlocked;

  Future<bool> authenticateForLock() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!isAvailable) return true;

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access locked chats',
        options:
            const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );
      if (authenticated) {
        _isLockedChatsUnlocked = true;
        notifyListeners();
      }
      return authenticated;
    } catch (e) {
      debugPrint('Error authenticating: $e');
      return false;
    }
  }

  Future<bool> lockChat(String chatId) async {
    if (_lockedChatIds.contains(chatId)) return true;
    final success = await authenticateForLock();
    if (success) {
      _lockedChatIds.add(chatId);
      await _saveLockedChats();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<bool> unlockChat(String chatId) async {
    if (!_lockedChatIds.contains(chatId)) return true;
    final success = await authenticateForLock();
    if (success) {
      _lockedChatIds.remove(chatId);
      await _saveLockedChats();
      notifyListeners();
      return true;
    }
    return false;
  }

  void lockFolder() {
    _isLockedChatsUnlocked = false;
    notifyListeners();
  }

  String get currentUserId =>
      _supabase.auth.currentUser?.id ?? 'mock-user-preview';

  Future<void> fetchCurrentUserProfile() async {
    if (currentUserId == 'mock-user-preview') return;
    try {
      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUserId)
          .maybeSingle();
      if (profile != null) {
        currentUserProfile = profile;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching current user profile: $e');
    }
  }

  // --- Blocked Users Logic ---

  List<String> get blockedUserIds => _blockedUserIds;

  bool isBlocked(String userId) => _blockedUserIds.contains(userId);

  Future<void> loadBlockedUsers() async {
    if (_blockedUsersLoaded || currentUserId == 'mock-user-preview') return;
    try {
      final data = await _supabase
          .from('blocked_users')
          .select('blocked_id')
          .eq('blocker_id', currentUserId);
      _blockedUserIds.clear();
      for (var row in data) {
        _blockedUserIds.add(row['blocked_id']);
      }
      _blockedUsersLoaded = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading blocked users: $e');
    }
  }

  Future<void> blockUser(String userId) async {
    if (isBlocked(userId)) return;
    try {
      await _supabase.from('blocked_users').insert({
        'blocker_id': currentUserId,
        'blocked_id': userId,
      });
      _blockedUserIds.add(userId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to block user: $e');
    }
  }

  Future<void> unblockUser(String userId) async {
    if (!isBlocked(userId)) return;
    try {
      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', userId);
      _blockedUserIds.remove(userId);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to unblock user: $e');
    }
  }

  // --- Typing Indicator Broadcast ---

  void initUserEventsListener() {
    if (_userEventsChannel != null || currentUserId == null) return;

    _userEventsChannel = _supabase.channel('user_events:$currentUserId');
    _userEventsChannel!.onBroadcast(
        event: 'typing_status',
        callback: (payload) {
          final chatId = payload['chat_id'] as String?;
          final isTyping = payload['is_typing'] == true;
          final senderName = payload['sender_name'] as String? ?? 'Someone';

          if (chatId != null) {
            _setTypingStatus(chatId, isTyping, senderName);
          }
        }).subscribe();
  }

  void _setTypingStatus(String chatId, bool isTyping, [String senderName = '']) {
    if (isTyping) {
      typingChats[chatId] = senderName;
      notifyListeners();

      // Clear existing timer if any
      _typingTimers[chatId]?.cancel();

      // Set debounce timer for ghost typing
      _typingTimers[chatId] = Timer(const Duration(seconds: 4), () {
        if (typingChats.containsKey(chatId)) {
          typingChats.remove(chatId);
          notifyListeners();
        }
      });
    } else {
      _typingTimers[chatId]?.cancel();
      typingChats.remove(chatId);
      notifyListeners();
    }
  }

  void sendTypingEvent(String? targetUserId, String chatId, bool isTyping, [String senderName = '']) {
    if (targetUserId != null) {
      // 1-on-1 chat: send to target user's personal channel
      final targetChannel = _supabase.channel('user_events:$targetUserId');
      targetChannel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          targetChannel.sendBroadcastMessage(
            event: 'typing_status',
            payload: {
              'chat_id': chatId,
              'is_typing': isTyping,
              'sender_name': senderName,
            },
          );
          // Clean up connection immediately after sending
          _supabase.removeChannel(targetChannel);
        }
      });
    } else {
      // Group chat: send to group's shared typing channel
      final channelName = 'chat_events:$chatId';
      final channel = _supabase.channel(channelName);
      channel.subscribe((status, error) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          channel.sendBroadcastMessage(
            event: 'typing_status',
            payload: {
              'chat_id': chatId,
              'is_typing': isTyping,
              'sender_name': senderName,
            },
          );
          // Remove if it's not the currently active subscribed channel
          if (!_groupTypingChannels.containsKey(chatId)) {
            _supabase.removeChannel(channel);
          }
        }
      });
    }
  }

  void subscribeToGroupTyping(String chatId) {
    if (_groupTypingChannels.containsKey(chatId)) return;
    
    final channelName = 'chat_events:$chatId';
    final channel = _supabase.channel(channelName);
    
    channel.onBroadcast(
      event: 'typing_status',
      callback: (payload) {
        final cid = payload['chat_id'] as String?;
        final isTyping = payload['is_typing'] == true;
        final senderName = payload['sender_name'] as String? ?? 'Someone';

        if (cid != null) {
          _setTypingStatus(cid, isTyping, senderName);
        }
      },
    ).subscribe();
    
    _groupTypingChannels[chatId] = channel;
  }

  void unsubscribeFromGroupTyping(String chatId) {
    final channel = _groupTypingChannels[chatId];
    if (channel != null) {
      _supabase.removeChannel(channel);
      _groupTypingChannels.remove(chatId);
    }
    typingChats.remove(chatId);
    Future.microtask(() {
      notifyListeners();
    });
  }

  // Controller to emit chats, combining DB stream and realtime events
  Stream<List<Map<String, dynamic>>> getChatsStream() async* {
    final StreamController<List<Map<String, dynamic>>> controller =
        StreamController();

    Future<void> fetchAndEmit() async {
      await fetchCurrentUserProfile();
      try {
        // Try optimized RPC first (requires get_unified_chats SQL to be deployed)
        final data = await _supabase
            .rpc('get_unified_chats')
            .timeout(const Duration(seconds: 5));

        List<Map<String, dynamic>> enrichedChats = [];

        for (var row in data) {
          String senderName = '';
          if (row['last_message_sender_id'] == currentUserId) {
            senderName = 'You';
          } else if (row['last_message_sender_name'] != null) {
            senderName = row['last_message_sender_name']?.split(' ')[0] ?? '';
          }

          Map<String, dynamic> enrichedChat = {
            'id': row['chat_id'],
            'is_group': row['is_group'],
            'group_name': row['group_name'],
            'group_avatar_url': row['group_avatar_url'],
            'is_pinned': row['is_pinned'],
            'is_archived': row['is_archived'],
            'is_muted': row['is_muted'],
            'unread_count': row['unread_count'],
            'unread_mentions_count': row['unread_mentions_count'],
            'last_message_at': row['last_message_at'],
            'other_last_read_at': row['other_last_read_at'],
          };

          if (row['is_group'] != true) {
            // Filter out broken/ghost chats that don't have a valid second participant
            if (row['other_user_id'] == null) {
              continue;
            }
            String finalName = row['other_user_name'] ?? 'Unknown';
            if (row['other_user_phone'] != null) {
              final phoneStr = row['other_user_phone'].toString();
              if (phoneStr.isNotEmpty) {
                final normalized = _normalizePhone(phoneStr);
                if (localContactsCache.containsKey(normalized)) {
                  finalName = localContactsCache[normalized]!;
                } else {
                  finalName = phoneStr;
                }
              }
            }

            enrichedChat['other_user'] = {
              'id': row['other_user_id'],
              'name': finalName,
              'profile_name': row['other_user_name'],
              'phone': row['other_user_phone'],
              'avatar_url': row['other_user_avatar'],
              'avatar_text': finalName.isNotEmpty ? finalName.characters.first.toUpperCase() : '?',
              'avatar_color': row['other_user_color'],
              'is_online': false,
            };
          }

          if (row['last_message_at'] != null) {
            String previewContent = '';
            if (row['last_message_preview'] != null) {
              previewContent = await decryptAndParsePreview(row['last_message_preview'].toString());
            }
            enrichedChat['last_message'] = {
              'content': previewContent,
              'message_type': row['last_message_type'] ?? 'text',
              'sender_name': senderName,
              'sender_id': row['last_message_sender_id'],
              'is_deleted_for_everyone': row['last_message_is_deleted_for_everyone'] == true,
            };
          }

          enrichedChats.add(enrichedChat);
        }

        if (!controller.isClosed) controller.add(enrichedChats);
      } catch (e) {
        debugPrint('RPC get_unified_chats failed: $e');
        // Fallback: Use direct query if RPC fails for any reason
        try {
          final fallbackData =
              await _supabase.from('chat_participants').select('''
            chat_id, is_pinned, is_archived, is_muted, unread_count,
            chats ( 
              id, is_group, group_name, group_avatar_url, last_message_at, last_message_preview, last_message_sender_id,
              chat_participants ( user_id, profiles (name, phone_number, avatar_url) )
            )
          ''').eq('user_id', currentUserId).timeout(const Duration(seconds: 5));

          List<Map<String, dynamic>> fallbackChats = [];
          for (var row in fallbackData) {
            final chatData = row['chats'] as Map<String, dynamic>?;
            if (chatData == null) continue;
            
            Map<String, dynamic> lastMessageObj = {};
            if (chatData['last_message_preview'] != null) {
              String previewContent = await decryptAndParsePreview(chatData['last_message_preview'].toString());
              lastMessageObj = {
                'content': previewContent,
                'sender_name': '', // We don't have sender name in basic chats table view
                'sender_id': chatData['last_message_sender_id'],
              };
            }

            if (chatData['is_group'] != true) {
              final participantsList = chatData['chat_participants'] as List? ?? [];
              final otherParticipant = participantsList.firstWhere(
                (p) => p['user_id'] != currentUserId, 
                orElse: () => null
              );
              if (otherParticipant != null) {
                final profile = otherParticipant['profiles'] ?? {};
                
                String finalName = profile['name'] ?? 'Unknown';
                final phoneStr = profile['phone_number']?.toString() ?? '';
                if (phoneStr.isNotEmpty) {
                  final normalized = _normalizePhone(phoneStr);
                  if (localContactsCache.containsKey(normalized)) {
                    finalName = localContactsCache[normalized]!;
                  } else {
                    finalName = phoneStr;
                  }
                }

                chatData['other_user'] = {
                  'id': otherParticipant['user_id'],
                  'name': finalName,
                  'profile_name': profile['name'],
                  'phone': profile['phone_number'],
                  'avatar_url': profile['avatar_url'],
                  'avatar_text': finalName.isNotEmpty ? finalName.characters.first.toUpperCase() : '?',
                  'avatar_color': null,
                  'is_online': false,
                };
              }
            }

            fallbackChats.add({
              ...chatData,
              'id': chatData['id'],
              'is_pinned': row['is_pinned'],
              'is_archived': row['is_archived'],
              'is_muted': row['is_muted'],
              'unread_count': row['unread_count'],
              if (lastMessageObj.isNotEmpty) 'last_message': lastMessageObj,
            });
          }
          // Sort pinned first, then by recency
          fallbackChats.sort((a, b) {
            if ((a['is_pinned'] == true) && (b['is_pinned'] != true)) return -1;
            if ((a['is_pinned'] != true) && (b['is_pinned'] == true)) return 1;
            final dateA = a['last_message_at'] != null
                ? DateTime.parse(a['last_message_at'])
                : DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = b['last_message_at'] != null
                ? DateTime.parse(b['last_message_at'])
                : DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          if (!controller.isClosed) controller.add(fallbackChats);
        } catch (fallbackErr) {
          debugPrint('Fallback query also failed: $fallbackErr');
          if (!controller.isClosed) {
            controller.add([]);
          }
        }
      }
    }

    fetchAndEmit();

    final channel = _supabase
        .channel('public:chats_updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (payload) => fetchAndEmit(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_participants',
          callback: (payload) => fetchAndEmit(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'profiles',
          callback: (payload) => fetchAndEmit(),
        )
        .subscribe();

    final refreshSub = _refreshChatsController.stream.listen((_) => fetchAndEmit());

    controller.onCancel = () {
      refreshSub.cancel();
      _supabase.removeChannel(channel);
      controller.close();
    };

    yield* controller.stream;
  }

  // --- Chat Actions ---

  Future<void> pinChat(String chatId, bool isPinned) async {
    await _supabase
        .from('chat_participants')
        .update({'is_pinned': isPinned})
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }

  Future<void> archiveChat(String chatId, bool isArchived) async {
    await _supabase
        .from('chat_participants')
        .update({'is_archived': isArchived})
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }

  Future<void> muteChat(String chatId, bool isMuted) async {
    await _supabase
        .from('chat_participants')
        .update({'is_muted': isMuted})
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }

  // Local Settings for Chats (Tone, Timer, Wallpaper)
  Future<void> saveChatSetting(String chatId, String key, String value) async {
    await _secureStorage.write(key: '${chatId}_$key', value: value);
    notifyListeners();
  }

  Future<String?> getChatSetting(String chatId, String key) async {
    return await _secureStorage.read(key: '${chatId}_$key');
  }

  // Update DB Settings (e.g. for Disappearing Messages)
  Future<void> updateChatDbSetting(String chatId, String key, dynamic value) async {
    try {
      final chatData = await _supabase.from('chats').select('settings').eq('id', chatId).single();
      Map<String, dynamic> settings = chatData['settings'] != null ? Map<String, dynamic>.from(chatData['settings']) : {};
      settings[key] = value;
      await _supabase.from('chats').update({'settings': settings}).eq('id', chatId);
    } catch (e) {
      debugPrint('Error updating DB chat setting: $e');
    }
  }

  Future<void> markChatRead(String chatId) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      // Reset unread counts
      await _supabase
          .from('chat_participants')
          .update({
            'unread_count': 0,
            'unread_mentions_count': 0,
            'last_read_at': DateTime.now().toUtc().toIso8601String()
          })
          .eq('chat_id', chatId)
          .eq('user_id', currentUserId);
    } catch (e) {
      debugPrint('Error marking chat as read: $e');
    }
  }

  Future<void> markChatUnread(String chatId) async {
    await _supabase
        .from('chat_participants')
        .update({'unread_count': 1})
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }

  Future<void> voteOnPoll(
      String messageId, String chatId, int optionIndex) async {
    try {
      await _supabase.from('poll_votes').upsert({
        'message_id': messageId,
        'user_id': currentUserId,
        'option_index': optionIndex,
      }, onConflict: 'message_id, user_id');
    } catch (e) {
      debugPrint('Error voting on poll: $e');
    }
  }

  Future<void> deleteChat(String chatId) async {
    await _supabase
        .from('chat_participants')
        .delete()
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId);
  }

  Stream<List<Map<String, dynamic>>> getArchivedChatsStream() {
    return getChatsStream()
        .map((chats) => chats.where((c) => c['is_archived'] == true).toList());
  }

  Stream<List<Map<String, dynamic>>> getProfileStream(String userId) {
    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .asBroadcastStream();
  }

  Stream<List<Map<String, dynamic>>> getMessagesStream(String chatId,
      {int limit = 50}) async* {
    if (chatId.isEmpty) {
      yield [];
      return;
    }

    final myId = currentUserId;
    DateTime? clearedAt;
    
    if (myId != null) {
      try {
        final cpRes = await _supabase
            .from('chat_participants')
            .select('cleared_at')
            .eq('chat_id', chatId)
            .eq('user_id', myId)
            .maybeSingle();
        if (cpRes != null && cpRes['cleared_at'] != null) {
          clearedAt = DateTime.parse(cpRes['cleared_at']);
        }
      } catch (_) {}
    }

    yield* _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at',
            ascending: false) // Order descending to get newest first
        .limit(limit)
        .map((messages) {
          return messages.reversed.where((m) {
            if (myId == null) return true;
            
            // 1. Filter out individually deleted messages
            final deletedBy = m['deleted_by'] as List<dynamic>? ?? [];
            if (deletedBy.contains(myId)) return false;
            
            // 2. Filter out messages before the chat was cleared
            if (clearedAt != null) {
              final ca = DateTime.parse(m['created_at']);
              if (ca.isBefore(clearedAt) || ca.isAtSameMomentAs(clearedAt)) return false;
            }
            
            return true;
          }).toList();
        })
        .asyncMap((messages) async {
          List<Map<String, dynamic>> decrypted = [];
          for (var msg in messages) {
            var newMsg = Map<String, dynamic>.from(msg);
            if (newMsg['message_type'] == 'text' && newMsg['content'] != null) {
              final contentStr = newMsg['content'] as String;
              if (contentStr.startsWith('{') &&
                  contentStr.contains('encryptedText')) {
                try {
                  newMsg['content'] =
                      await EncryptionService.decryptMessage(contentStr);
                } catch (_) {
                  newMsg['content'] = "🔒 Encrypted Message (Cannot decrypt)";
                }
              }
            }
            // Filter expired disappearing messages
            if (newMsg['expires_at'] != null) {
              final expiresAt = DateTime.tryParse(newMsg['expires_at'].toString());
              if (expiresAt != null && expiresAt.isBefore(DateTime.now())) {
                continue; // Skip expired message
              }
            }
            decrypted.add(newMsg);
          }
          return decrypted;
        }).asBroadcastStream();
  }

  Future<List<Map<String, dynamic>>> searchMessages(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final response = await _supabase.rpc('search_messages', params: {
        'search_query': query,
      });
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error searching messages: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getChatMedia(String chatId, {int limit = 30, int offset = 0}) async {
    final response = await _supabase
        .from('messages')
        .select('id, content, message_type, media_url, created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getCommonGroups(
      String contactUserId) async {
    try {
      final myGroupsResponse = await _supabase
          .from('chat_participants')
          .select('chat_id, chats!inner(is_group, group_name)')
          .eq('user_id', currentUserId)
          .eq('chats.is_group', true);
      final contactGroupsResponse = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', contactUserId);
      final contactGroupIds =
          (contactGroupsResponse as List).map((e) => e['chat_id']).toSet();

      final myGroups = myGroupsResponse as List;
      final common = myGroups
          .where((e) => contactGroupIds.contains(e['chat_id']))
          .toList();
      return common
          .map((e) => {
                'id': e['chat_id'],
                'name': e['chats']['group_name'] ?? 'Group',
              })
          .toList();
    } catch (e) {
      debugPrint('Error fetching common groups: $e');
      return [];
    }
  }

  // Report Contact
  Future<void> reportContact(String reportedUserId, String reason) async {
    try {
      await _supabase.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': reportedUserId,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('Error reporting contact: ');
    }
  }

  Future<void> reportGroup(String reportedChatId, String reason) async {
    try {
      await _supabase.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_chat_id': reportedChatId,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('Error reporting group: ');
    }
  }

  Future<void> reportContact_old(String reportedUserId, String reason) async {
    try {
      await _supabase.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_user_id': reportedUserId,
        'reason': reason,
      });
    } catch (e) {
      debugPrint('Error reporting contact: $e');
    }
  }

  // Block Contact
  Future<void> blockContact(String blockedUserId) async {
    try {
      await _supabase.from('blocked_users').insert({
        'blocker_id': currentUserId,
        'blocked_id': blockedUserId,
      });
      _blockedUserIds.add(blockedUserId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error blocking contact: $e');
    }
  }

  Future<void> unblockContact(String blockedUserId) async {
    try {
      await _supabase
          .from('blocked_users')
          .delete()
          .eq('blocker_id', currentUserId)
          .eq('blocked_id', blockedUserId);
      _blockedUserIds.remove(blockedUserId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error unblocking contact: $e');
    }
  }

  Future<void> updateGroupInfo({
    required String groupId,
    String? name,
    String? description,
    File? imageFile,
  }) async {
    try {
      if (groupId.startsWith('dummy-')) return;

      String? avatarUrl;
      if (imageFile != null) {
        final ext = imageFile.path.split('.').last;
        final fileName =
            'group_${groupId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage
            .from('group_avatars')
            .upload(fileName, imageFile);
        avatarUrl =
            _supabase.storage.from('group_avatars').getPublicUrl(fileName);
      }

      final Map<String, dynamic> updates = {};
      if (name != null) updates['group_name'] = name;
      if (description != null) updates['description'] = description;
      if (avatarUrl != null) updates['group_avatar_url'] = avatarUrl;

      if (updates.isNotEmpty) {
        final res = await _supabase
            .from('chats')
            .update(updates)
            .eq('id', groupId)
            .select();
        if (res.isEmpty) {
          throw Exception('Permission denied or group not found.');
        }
      }
    } catch (e) {
      debugPrint('Error updating group info: $e');
      rethrow;
    }
  }

  Future<String?> getOrCreateDirectChat(String otherUserId) async {
    if (currentUserId == 'mock-user-preview') return null;

    final chatRes = await _supabase
        .from('chats')
        .select('id, chat_participants!inner(user_id)')
        .eq('is_group', false);

    for (var c in chatRes) {
      final participants = c['chat_participants'] as List;
      final ids = participants.map((p) => p['user_id'] as String).toList();
      if (ids.length == 2 &&
          ids.contains(currentUserId) &&
          ids.contains(otherUserId)) {
        return c['id'];
      }
    }

    final newChatRes = await _supabase
        .from('chats')
        .insert({
          'is_group': false,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select()
        .single();
    final chatId = newChatRes['id'];

    if (chatId != null) {
      await _supabase.from('chat_participants').insert([
        {'chat_id': chatId, 'user_id': currentUserId},
        {'chat_id': chatId, 'user_id': otherUserId},
      ]);
    }
    return chatId;
  }

  Future<void> sendMessage({
    required String chatId,
    String? id,
    String? content,
    String messageType = 'text',
    String? mediaUrl,
    List<String>? mentionedUserIds,
    String? replyToId,
    String? forwardedFromId,
    String? mediaGroupId,
    int? orderIndex,
    void Function(double)? onSendProgress,
  }) async {
    // Handle media upload (if local file path provided)
    String? finalMediaUrl = mediaUrl;
    if (mediaUrl != null &&
        forwardedFromId == null &&
        !mediaUrl.startsWith('http') &&
        (messageType == 'image' ||
            messageType == 'audio' ||
            messageType == 'video' ||
            messageType == 'document')) {
      debugPrint('[DEBUG] sendMessage: Uploading local file: $mediaUrl');
      final file = File(mediaUrl);
      if (!file.existsSync()) {
        throw Exception('Media file not found at path: $mediaUrl');
      }
      final fileName = mediaUrl.split('/').last;
      final storagePath = await uploadMedia(chatId, mediaUrl, fileName, onProgress: onSendProgress);
      if (storagePath != null) {
        finalMediaUrl = storagePath;
        debugPrint('[DEBUG] sendMessage: Upload successful: $storagePath');
      } else {
        throw Exception(
            'Failed to upload media file. Check storage bucket permissions.');
      }
    }

    // Fetch chat meta for E2EE, disappearing timer, and broadcast
    Map<String, dynamic>? chatMeta;
    try {
      chatMeta = await _supabase.from('chats').select('is_group, is_broadcast, broadcast_recipients, settings').eq('id', chatId).maybeSingle();
    } catch (_) {}

    // Handle E2EE for text messages in 1-on-1 chats
    String finalContent = content ?? '';
    if (messageType == 'text' && finalContent.isNotEmpty) {
      try {
        bool isGroup = chatMeta?['is_group'] == true;

        if (!isGroup) {
          final otherParticipant = await _supabase
              .from('chat_participants')
              .select('user_id, profiles(public_key)')
              .eq('chat_id', chatId)
              .neq('user_id', currentUserId)
              .limit(1)
              .maybeSingle();

          final otherPubKey = otherParticipant?['profiles']?['public_key'];

          final myProfile = await _supabase
              .from('profiles')
              .select('public_key')
              .eq('id', currentUserId)
              .maybeSingle();
          final myPubKey = myProfile?['public_key'];

          if (otherPubKey != null && otherPubKey.toString().isNotEmpty) {
            finalContent = await EncryptionService.encryptMessage(
                finalContent, otherPubKey.toString(),
                senderPubKeyStr: myPubKey?.toString());
          }
        }
      } catch (e) {
        debugPrint('[DEBUG] E2EE Error: $e');
      }
    }

    // Insert message directly - RLS on messages table handles security
    debugPrint(
        '[DEBUG] sendMessage: Inserting. chatId=$chatId type=$messageType');
    final Map<String, dynamic> messageData = {
      if (id != null) 'id': id,
      'chat_id': chatId,
      'sender_id': currentUserId,
      'content': finalContent.isEmpty ? null : finalContent,
      'message_type': messageType,
      'media_url': finalMediaUrl,
      if (forwardedFromId != null) 'forwarded_from_id': forwardedFromId,
      if (mentionedUserIds != null && mentionedUserIds.isNotEmpty) 'mentioned_user_ids': mentionedUserIds,
    };
    
    // Check for disappearing messages setting
    if (chatMeta != null && chatMeta['settings'] != null) {
      final settings = chatMeta['settings'] as Map<String, dynamic>;
      final timer = settings['disappearing_timer'];
      if (timer != null && timer is int && timer > 0) {
        messageData['expires_at'] = DateTime.now().add(Duration(hours: timer)).toIso8601String();
      }
    }

    if (replyToId != null) {
      messageData['reply_to_id'] = replyToId;
    }
    if (forwardedFromId != null) {
      messageData['forwarded_from_id'] = forwardedFromId;
    }

    if (mentionedUserIds != null && mentionedUserIds.isNotEmpty) {
      messageData['mentioned_user_ids'] = mentionedUserIds;
    }
    if (mediaGroupId != null) {
      messageData['media_group_id'] = mediaGroupId;
    }
    if (orderIndex != null) {
      messageData['order_index'] = orderIndex;
    }

    try {
      await _supabase.from('messages').insert(messageData).select();
      debugPrint('[DEBUG] sendMessage: Insert SUCCESS.');

      // --- Broadcast Distribution Logic ---
      if (chatMeta?['is_broadcast'] == true && messageType != 'event') {
        try {
          await _supabase.functions.invoke('send_broadcast_message', body: {
            'broadcast_chat_id': chatId,
            'sender_id': currentUserId,
            'message_type': messageType,
            'content': finalContent,
            'media_url': finalMediaUrl,
          });
        } catch (e) {
          debugPrint('[DEBUG] Edge Function Broadcast failed: $e');
        }
      }
      
      // Force refresh chat list on home screen
      _refreshChatsController.add(null);
    } catch (e) {
      debugPrint('[DEBUG] sendMessage: Insert FAILED. $e');
      if (e is SocketException || e.toString().contains('ClientException') || e.toString().contains('Failed host lookup')) {
         final localMessage = Map<String, dynamic>.from(messageData);
         localMessage['is_pending'] = true;
         localMessage['local_id'] = 'pending-${DateTime.now().millisecondsSinceEpoch}';
         localMessage['created_at'] = DateTime.now().toIso8601String(); // for UI sorting
         _offlineQueue.add(localMessage);
         
         if (_offlineDb != null) {
           await _offlineDb!.insert('offline_messages', {
             'local_id': localMessage['local_id'],
             'data': jsonEncode(localMessage),
           }, conflictAlgorithm: ConflictAlgorithm.replace);
         }
         notifyListeners();
         return; // Gracefully queued
      }
      rethrow;
    }
  }

  // Method to handle poll votes
  Future<void> votePoll(String messageId, int optionIndex) async {
    try {
      await _supabase.from('poll_votes').upsert({
        'message_id': messageId,
        'user_id': currentUserId,
        'option_index': optionIndex,
      }, onConflict: 'message_id, user_id');
    } catch (e) {
      debugPrint('Error voting on poll: $e');
    }
  }

  // Send a batch of media messages
  Future<void> sendMediaBatch({
    required String chatId,
    required List<Map<String, dynamic>> mediaItems,
    required String mediaGroupId,
    void Function(double)? onSendProgress,
  }) async {
    List<Map<String, dynamic>> batchData = [];

    int totalFiles = mediaItems.length;
    for (int i = 0; i < mediaItems.length; i++) {
      final item = mediaItems[i];
      // mediaUrl here is ALREADY the storagePath returned by uploadMedia in MediaPreviewEditScreen
      final mediaUrl = item['url'] as String;
      final type = item['type'] as String;
      final caption = item['caption'] as String?;

      batchData.add({
        'chat_id': chatId,
        'sender_id': currentUserId,
        'content': caption,
        'message_type': type,
        'media_url': mediaUrl,
        'media_group_id': mediaGroupId,
        'order_index': i,
      });
    }

    if (batchData.isNotEmpty) {
      await _supabase.from('messages').insert(batchData);
    } else {
      notifyListeners();
    }
  }

  // Upload Media to Supabase Storage with Progress
  Future<String?> uploadMedia(
      String chatId, String filePath, String fileName, {void Function(double)? onProgress}) async {
    try {
      final fileExt = fileName.split('.').last.toLowerCase();
      final uniqueFileName =
          '${DateTime.now().millisecondsSinceEpoch}_$currentUserId.$fileExt';
      final storagePath = '$chatId/$uniqueFileName';

      File file = File(filePath);
      if (!file.existsSync()) return null;

      // --- COMPRESSION LOGIC ---
      if (fileExt == 'jpg' || fileExt == 'jpeg' || fileExt == 'png' || fileExt == 'webp') {
        final compressedFile = await MediaCompressor.compressImage(file);
        if (compressedFile != null) file = compressedFile;
      } else if (fileExt == 'mp4' || fileExt == 'mov' || fileExt == 'mkv' || fileExt == 'avi') {
        final compressedFile = await MediaCompressor.compressVideo(file);
        if (compressedFile != null) file = compressedFile;
      }
      // -------------------------

      final session = _supabase.auth.currentSession;
      if (session == null) throw Exception('Not authenticated');

      final storageUrl = _supabase.rest.url.replaceAll('/rest/v1', '/storage/v1');
      final url = '$storageUrl/object/chat_media/$storagePath';
      
      final dio = Dio();
      await dio.post(
        url,
        data: file.readAsBytesSync(),
        options: Options(
          headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/octet-stream',
          },
        ),
        onSendProgress: (count, total) {
          if (onProgress != null && total > 0) {
            onProgress(count / total);
          }
        },
      );

      // Return the public URL so the UI can easily display it
      return _supabase.storage.from('chat_media').getPublicUrl(storagePath);
    } catch (e) {
      debugPrint('Upload Error: $e');
      return null;
    }
  }

  final Map<String, Map<String, dynamic>> _signedUrlCache = {};

  // Get a fresh signed URL for playback/viewing (cached in memory)
  Future<String?> getMediaSignedUrl(String storagePath) async {
    try {
      if (storagePath.startsWith('http://') ||
          storagePath.startsWith('https://')) {
        return storagePath;
      }
      if (storagePath.startsWith('/') ||
          storagePath.startsWith('/Users/') ||
          storagePath.startsWith('C:')) {
        return storagePath; // Local file path
      }
      if (storagePath.contains('storage/emulated')) {
        return storagePath; // Android local path
      }

      // Check cache first to prevent image flickering and 400 Bad Request (expired token)
      if (_signedUrlCache.containsKey(storagePath)) {
        final cacheEntry = _signedUrlCache[storagePath]!;
        final expiresAt = cacheEntry['expires'] as DateTime;
        if (DateTime.now().isBefore(expiresAt)) {
          return cacheEntry['url'] as String;
        }
        _signedUrlCache.remove(storagePath); // Expired, remove it
      }

      final signedUrl = await _supabase.storage
          .from('chat_media')
          .createSignedUrl(storagePath, 60 * 60); // 1 hour expiry
          
      // Cache with a 55-minute expiry to be safe (5 minutes before actual expiry)
      _signedUrlCache[storagePath] = {
        'url': signedUrl,
        'expires': DateTime.now().add(const Duration(minutes: 55)),
      };
      return signedUrl;
    } catch (e) {
      debugPrint('Error generating signed URL: $e');
      return null;
    }
  }

  Future<String> createChat(String otherUserId) async {
    try {
      // Step 1: Check if a 1-on-1 chat already exists between these two users
      final myChats = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', currentUserId);

      final myChatIds =
          (myChats as List).map((e) => e['chat_id'] as String).toList();

      if (myChatIds.isNotEmpty) {
        // Check if the other user is in any of my chats (1-on-1 only)
        final existingChats = await _supabase
            .from('chat_participants')
            .select('chat_id, chats!inner(is_group)')
            .eq('user_id', otherUserId)
            .inFilter('chat_id', myChatIds)
            .eq('chats.is_group', false);

        if (existingChats.isNotEmpty) {
          // Return the existing chat ID
          return existingChats[0]['chat_id'] as String;
        }
      }
    } catch (e) {
      debugPrint(
          '[ChatService] createChat: Error checking existing chat (will create new): $e');
    }

    // Step 2: No existing chat found — create a new one
    final newChat = await _supabase
        .from('chats')
        .insert({'is_group': false})
        .select('id')
        .single();

    final chatId = newChat['id'] as String;

    // Step 3: Add both participants (insert self first for RLS, then the other)
      await _supabase
          .from('chat_participants')
          .insert({'chat_id': chatId, 'user_id': currentUserId, 'role': 'admin'});
      await _supabase
          .from('chat_participants')
          .insert({'chat_id': chatId, 'user_id': otherUserId});

    debugPrint('[ChatService] createChat: New chat created: $chatId');
    return chatId;
  }

  // Create a new group chat
  Future<String> createGroup(String groupName, List<String> memberIds,
      {File? groupAvatar,
      Map<String, bool>? permissions,
      bool isPublic = false,
      int disappearingTimer = 0}) async {
    String? avatarUrl;

    if (groupAvatar != null) {
      try {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${groupAvatar.path.split('/').last}';
        final storagePath = '$currentUserId/$fileName';
        await _supabase.storage
            .from('group_avatars')
            .upload(storagePath, groupAvatar);
        avatarUrl =
            _supabase.storage.from('group_avatars').getPublicUrl(storagePath);
      } catch (e) {
        debugPrint('[ChatService] Error uploading group avatar: $e');
      }
    }

    final newChat = await _supabase
        .from('chats')
        .insert({
          'is_group': true,
          'group_name': groupName,
          'is_public': isPublic,
          'disappearing_timer': disappearingTimer,
          if (avatarUrl != null) 'group_avatar_url': avatarUrl,
          if (permissions != null) 'settings': permissions,
        })
        .select('id')
        .single();

    final chatId = newChat['id'];

    // Insert self as admin FIRST so RLS allows subsequent inserts
    await _supabase
        .from('chat_participants')
        .insert({'chat_id': chatId, 'user_id': currentUserId, 'role': 'admin'});

    List<Map<String, dynamic>> otherParticipants = [];
    for (var id in memberIds) {
      otherParticipants
          .add({'chat_id': chatId, 'user_id': id, 'role': 'member'});
    }

    if (otherParticipants.isNotEmpty) {
      await _supabase.from('chat_participants').insert(otherParticipants);
    }

    // Insert an initial system message so the chat appears in the list immediately
    try {
      await sendMessage(
        chatId: chatId,
        messageType: 'system',
        content: 'Group "$groupName" was created.',
      );
    } catch (e) {
      debugPrint('[ChatService] Failed to insert initial group message: $e');
    }

    return chatId;
  }

  // Create a new broadcast list
  Future<String> createBroadcastList(String listName, List<String> recipientIds) async {
    final newChat = await _supabase
        .from('chats')
        .insert({
          'is_group': true, // Treat as group for the sender's UI
          'group_name': listName,
          'is_broadcast': true,
          'broadcast_recipients': recipientIds,
        })
        .select('id')
        .single();

    final chatId = newChat['id'];

    // Insert only self into chat_participants
    await _supabase
        .from('chat_participants')
        .insert({'chat_id': chatId, 'user_id': currentUserId, 'role': 'admin'});

    try {
      await sendMessage(
        chatId: chatId,
        messageType: 'event',
        content: 'You created a broadcast list with ${recipientIds.length} recipients.',
      );
    } catch (e) {
      debugPrint('[ChatService] Failed to insert initial broadcast message: $e');
    }

    return chatId;
  }

  // --- Scalable Online Presence ---

  /// Updates the last_seen timestamp for the current user in a specific chat/channel.
  /// This should be called periodically (e.g., every 5 mins) while the user is active in the chat.
  Future<void> pingOnlineStatus(String id, {bool isChannel = false}) async {
    try {
      if (isChannel) {
        await _supabase
            .rpc('update_my_last_seen', params: {'p_channel_id': id});
      } else {
        await _supabase.rpc('update_my_last_seen', params: {'p_chat_id': id});
      }
    } catch (e) {
      debugPrint('Error pinging online status: $e');
    }
  }

  /// Gets the count of members who have been active in the last 5 minutes.
  Future<int> getActiveMembersCount(String id, {bool isChannel = false}) async {
    try {
      final fiveMinutesAgo =
          DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String();
      if (isChannel) {
        final count = await _supabase
            .from('channel_subscribers')
            .count(CountOption.exact)
            .eq('channel_id', id)
            .gte('last_seen', fiveMinutesAgo);
        return count;
      } else {
        final count = await _supabase
            .from('chat_participants')
            .count(CountOption.exact)
            .eq('chat_id', id)
            .gte('last_seen', fiveMinutesAgo);
        return count;
      }
    } catch (e) {
      debugPrint('Error getting active members count: $e');
      return 0;
    }
  }

  /// Gets the total count of members in a chat or channel.
  Future<int> getTotalMembersCount(String id, {bool isChannel = false}) async {
    try {
      if (isChannel) {
        final count = await _supabase
            .from('channel_subscribers')
            .count(CountOption.exact)
            .eq('channel_id', id);
        return count;
      } else {
        final count = await _supabase
            .from('chat_participants')
            .count(CountOption.exact)
            .eq('chat_id', id);
        return count;
      }
    } catch (e) {
      debugPrint('Error getting total members count: $e');
      return 0;
    }
  }

  /// PERMANENT FIX: Fetches the true metadata of a chat from the database.
  /// Returns {is_group: bool, other_user_id: String?}
  /// This ensures IndividualChatScreen ALWAYS knows the real chat type,
  /// regardless of which navigation path opened it.
  Future<Map<String, dynamic>> getChatMeta(String chatId) async {
    try {
      final chat = await _supabase
          .from('chats')
          .select('is_group')
          .eq('id', chatId)
          .single();

      final bool isGroup = chat['is_group'] == true;
      String? otherUserId;

      if (!isGroup) {
        // For 1-on-1 chats, fetch the other participant
        final participants = await _supabase
            .from('chat_participants')
            .select('user_id')
            .eq('chat_id', chatId)
            .neq('user_id', currentUserId);

        if (participants.isNotEmpty) {
          otherUserId = participants.first['user_id'] as String?;
        }
      }

      return {'is_group': isGroup, 'other_user_id': otherUserId};
    } catch (e) {
      debugPrint('[ChatService] getChatMeta error: $e');
      return {'is_group': false, 'other_user_id': null};
    }
  }

  // --- Voice Message Methods ---

  // --- Group & Channel Invite Methods ---

  Future<String?> getInviteLink(String id, {bool isChannel = false}) async {
    final table = isChannel ? 'channels' : 'chats';
    final res = await _supabase
        .from(table)
        .select('invite_code')
        .eq('id', id)
        .maybeSingle();
    if (res != null && res['invite_code'] != null) {
      return 'Twibee://join/${res['invite_code']}';
    }
    return null;
  }

  Future<String> generateInviteLink(String id, {bool isChannel = false}) async {
    final table = isChannel ? 'channels' : 'chats';
    // Generate a unique 8-character code
    final code = DateTime.now().millisecondsSinceEpoch.toRadixString(36) +
        (currentUserId.substring(0, 4));
    await _supabase.from(table).update({'invite_code': code}).eq('id', id);
    return 'Twibee://join/$code';
  }

  Future<Map<String, dynamic>?> getGroupInfoByInviteCode(String code) async {
    // Check channels first
    var res = await _supabase
        .from('channels')
        .select('id, name, avatar_url, description')
        .eq('invite_code', code)
        .maybeSingle();
    if (res != null) {
      res['is_channel'] = true;
      return res;
    }
    // Then check groups
    res = await _supabase
        .from('chats')
        .select('id, group_name, group_avatar_url')
        .eq('invite_code', code)
        .maybeSingle();
    if (res != null) {
      res['name'] = res['group_name'];
      res['avatar_url'] = res['group_avatar_url'];
      res['is_channel'] = false;
      return res;
    }
    return null;
  }

  Future<bool> joinViaInviteCode(String code) async {
    final info = await getGroupInfoByInviteCode(code);
    if (info == null) return false;

    final id = info['id'];
    final isChannel = info['is_channel'] == true;

    try {
      if (isChannel) {
        // Add to channel_subscribers
        final existing = await _supabase
            .from('channel_subscribers')
            .select()
            .eq('channel_id', id)
            .eq('user_id', currentUserId)
            .maybeSingle();
        if (existing == null) {
          await _supabase.from('channel_subscribers').insert({
            'channel_id': id,
            'user_id': currentUserId,
            'role': 'subscriber'
          });
        }
      } else {
        // Add to chat_participants
        final existing = await _supabase
            .from('chat_participants')
            .select()
            .eq('chat_id', id)
            .eq('user_id', currentUserId)
            .maybeSingle();
        if (existing == null) {
          await _supabase.from('chat_participants').insert({
            'chat_id': id,
            'user_id': currentUserId,
          });
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error joining via invite code: $e');
      return false;
    }
  }

  // --- Group Management Methods ---

  Future<List<Map<String, dynamic>>> getGroupParticipants(String chatId) async {
    final response = await _supabase.from('chat_participants').select('''
      role,
      profiles:user_id (id, name, avatar_url)
    ''').eq('chat_id', chatId);

    List<Map<String, dynamic>> members = [];
    for (var row in response) {
      final profile = row['profiles'] as Map<String, dynamic>?;
      if (profile != null) {
        members.add({
          'id': profile['id'],
          'name': profile['id'] == currentUserId
              ? 'You'
              : (profile['name'] ?? 'User'),
          'avatar_url': profile['avatar_url'],
          'role': row['role'] ?? 'member',
        });
      }
    }
    // Sort so You are first, then admins, then members
    members.sort((a, b) {
      if (a['id'] == currentUserId) return -1;
      if (b['id'] == currentUserId) return 1;
      if (a['role'] == 'admin' && b['role'] != 'admin') return -1;
      if (a['role'] != 'admin' && b['role'] == 'admin') return 1;
      return (a['name'] as String).compareTo(b['name'] as String);
    });
    return members;
  }

  Future<void> addParticipants(String chatId, List<String> userIds) async {
    List<Map<String, dynamic>> participants = [];
    for (var id in userIds) {
      participants.add({'chat_id': chatId, 'user_id': id, 'role': 'member'});
    }
    await _supabase.from('chat_participants').insert(participants);
  }

  Future<void> updateParticipantRole(
      String chatId, String userId, String newRole) async {
    await _supabase
        .from('chat_participants')
        .update({'role': newRole})
        .eq('chat_id', chatId)
        .eq('user_id', userId);
  }

  Future<void> removeParticipant(String chatId, String userId) async {
    await _supabase
        .from('chat_participants')
        .delete()
        .eq('chat_id', chatId)
        .eq('user_id', userId);
  }

  // Get all users (for creating new chats)
  Future<List<Map<String, dynamic>>> getAllUsers() async {
    return await _supabase
        .from('profiles')
        .select('id, name, phone_number, avatar_url, about')
        .neq('id', currentUserId);
  }

  String getContactName(String phone, String fallbackName) {
    if (phone.isEmpty) return fallbackName;
    final normalized = _normalizePhone(phone);
    return localContactsCache[normalized] ?? fallbackName;
  }

  String _normalizePhone(String phone) {
    String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length > 10) {
      digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
    }
    return digitsOnly;
  }

  Future<void> initLocalContactsCache() async {
    try {
      final status = await Permission.contacts.status;
      if (status.isGranted) {
        final deviceContacts = await FlutterContacts.getContacts(withProperties: true);
        for (var contact in deviceContacts) {
          for (var phone in contact.phones) {
            final normalized = _normalizePhone(phone.number);
            localContactsCache[normalized] = contact.displayName;
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error caching local contacts: $e');
    }
  }

  // Get only users who are in device contacts
  Future<ContactSyncResult> syncDeviceContacts() async {
    if (currentUserId == 'mock-user-preview') {
      return ContactSyncResult(
        registeredUsers: await getAllUsers(),
        unregisteredContacts: [],
      );
    }

    try {
      final registeredProfiles = await getAllUsers();

      var status = await Permission.contacts.status;
      if (!status.isGranted) {
        status = await Permission.contacts.request();
      }

      if (status.isGranted) {
        final deviceContacts =
            await FlutterContacts.getContacts(withProperties: true);

        final registeredPhones = <String, Map<String, dynamic>>{};
        for (var profile in registeredProfiles) {
          final phone = profile['phone_number']?.toString() ?? '';
          if (phone.isNotEmpty) {
            registeredPhones[_normalizePhone(phone)] = profile;
          }
        }

        final List<Map<String, dynamic>> matchedUsers = [];
        final List<Contact> unmatchedContacts = [];
        final Set<String> matchedIds = {};

        for (var contact in deviceContacts) {
          bool matched = false;
          for (var phone in contact.phones) {
            final normalized = _normalizePhone(phone.number);
            if (registeredPhones.containsKey(normalized)) {
              final user = registeredPhones[normalized]!;
              if (!matchedIds.contains(user['id'])) {
                matchedUsers.add({
                  ...user,
                  'contact_name': contact.displayName,
                });
                matchedIds.add(user['id']);
              }
              matched = true;
              break;
            }
          }
          if (!matched && contact.phones.isNotEmpty) {
            unmatchedContacts.add(contact);
          }
        }

        matchedUsers.sort((a, b) {
          final nameA =
              (a['contact_name'] ?? a['name'] ?? '').toString().toLowerCase();
          final nameB =
              (b['contact_name'] ?? b['name'] ?? '').toString().toLowerCase();
          return nameA.compareTo(nameB);
        });

        unmatchedContacts.sort((a, b) {
          final nameA = a.displayName.toLowerCase();
          final nameB = b.displayName.toLowerCase();
          return nameA.compareTo(nameB);
        });

        return ContactSyncResult(
          registeredUsers: matchedUsers,
          unregisteredContacts: unmatchedContacts,
        );
      }
    } catch (e) {
      debugPrint('Error syncing contacts: $e');
    }
    return ContactSyncResult(registeredUsers: [], unregisteredContacts: []);
  }

  // --- Real Chat Backup Logic ---

  Future<void> generateAndUploadBackup({String? encryptionPassword}) async {
    if (currentUserId == 'mock-user-preview') return;

    try {
      // 1. Fetch all chats the user is part of
      final participantsData = await _supabase
          .from('chat_participants')
          .select('chat_id')
          .eq('user_id', currentUserId);
      final List<String> chatIds =
          participantsData.map<String>((p) => p['chat_id'] as String).toList();

      if (chatIds.isEmpty) return; // Nothing to backup

      // 2. Fetch all messages for these chats
      final messagesData = await _supabase
          .from('messages')
          .select()
          .inFilter('chat_id', chatIds);

      // 3. Convert to JSON string
      final Map<String, dynamic> backupPayload = {
        'version': 1,
        'timestamp': DateTime.now().toIso8601String(),
        'messages': messagesData,
      };
      final jsonString = jsonEncode(backupPayload);

      // 4. Create an archive
      final archive = Archive();

      // Add messages.json to archive
      final jsonBytes = utf8.encode(jsonString);
      archive
          .addFile(ArchiveFile('messages.json', jsonBytes.length, jsonBytes));

      // 5. Encode archive to zip
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);

      // 6. Upload to Supabase Storage 'chat_backups' bucket
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${currentUserId}_backup_$timestamp.zip';

      await _supabase.storage.from('chat_backups').uploadBinary(
            fileName,
            Uint8List.fromList(zipBytes),
            fileOptions:
                const FileOptions(upsert: true, contentType: 'application/zip'),
          );
    } catch (e) {
      debugPrint('Backup generation failed: $e');
      throw Exception('Backup failed: $e');
    }
  }

  Future<void> togglePin(String messageId, bool isPinned, String chatId) async {
    try {
      await _supabase.rpc('toggle_message_pin', params: {
        'p_message_id': messageId,
        'p_is_pinned': isPinned,
        'p_chat_id': chatId,
      });
    } catch (e) {
      debugPrint('Error toggling pin: $e');
    }
  }

  Future<void> starMessage(String messageId, bool isStarred) async {
    if (currentUserId == null) return;
    try {
      if (isStarred) {
        await _supabase.from('saved_messages').insert({
          'user_id': currentUserId,
          'message_id': messageId,
        });
      } else {
        await _supabase.from('saved_messages').delete()
            .eq('user_id', currentUserId)
            .eq('message_id', messageId);
      }
    } catch (e) {
      debugPrint('[ChatService] Failed to toggle star: $e');
      rethrow;
    }
  }

  Future<List<String>> getStarredMessageIds() async {
    if (currentUserId == null) return [];
    try {
      final res = await _supabase
          .from('saved_messages')
          .select('message_id')
          .eq('user_id', currentUserId);
      return List<String>.from(res.map((e) => e['message_id'].toString()));
    } catch (e) {
      debugPrint('Error getting starred messages: $e');
      return [];
    }
  }

  Future<void> deleteMessage(String messageId, {bool forEveryone = false}) async {
    if (currentUserId == null) return;
    try {
      if (forEveryone) {
        // Pre-fetch message to check for media
        final msg = await _supabase.from('messages').select('media_url, sender_id').eq('id', messageId).maybeSingle();
        
        if (msg != null && msg['sender_id'] == currentUserId) {
          if (msg['media_url'] != null) {
            final String mediaUrl = msg['media_url'];
            if (mediaUrl.contains('chat_media')) {
              final uri = Uri.parse(mediaUrl);
              final pathSegments = uri.pathSegments;
              final bucketIndex = pathSegments.indexOf('chat_media');
              if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
                final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
                await _supabase.storage.from('chat_media').remove([storagePath]);
                debugPrint('[DEBUG] Deleted media from storage: $storagePath');
              }
            }
          }
          // Soft delete from database (Tombstone)
          await _supabase.from('messages').update({
            'is_deleted_for_everyone': true,
            'content': 'This message was deleted',
            'media_url': null,
          }).eq('id', messageId).eq('sender_id', currentUserId);
        }
      } else {
        // Delete for me
        await _supabase.rpc('delete_message_for_me', params: {'msg_id': messageId});
      }
      _refreshChatsController.add(null);
    } catch (e) {
      debugPrint('Error deleting message: $e');
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    try {
      await _supabase
          .from('messages')
          .update({'content': newContent, 'is_edited': true})
          .eq('id', messageId)
          .eq('sender_id', currentUserId);
    } catch (e) {
      debugPrint('Error editing message: $e');
    }
  }

  Future<void> exportChat(String chatId, String chatName, {bool attachMedia = false}) async {
    try {
      final messagesRes = await _supabase
          .from('messages')
          .select('sender_id, content, created_at, media_url, media_type, profiles(name)')
          .eq('chat_id', chatId)
          .order('created_at', ascending: true);

      final buffer = StringBuffer();
      buffer.writeln('Twibee Chat Export: $chatName');
      buffer.writeln('----------------------------------------');

      final dir = await getTemporaryDirectory();
      final exportDir = Directory('${dir.path}/Twibee_Export_${DateTime.now().millisecondsSinceEpoch}');
      await exportDir.create();
      
      final mediaDir = Directory('${exportDir.path}/media');
      if (attachMedia) {
        await mediaDir.create();
      }

      int mediaCount = 0;
      final dio = Dio();

      for (var msg in messagesRes) {
        final senderName = msg['profiles']?['name'] ?? 'Unknown';
        var content = msg['content'];
        final timestamp = msg['created_at'];
        final mediaUrl = msg['media_url'];

        if (mediaUrl != null && attachMedia && mediaUrl.toString().startsWith('http')) {
           mediaCount++;
           final ext = msg['media_type'] == 'video' ? 'mp4' : (msg['media_type'] == 'audio' ? 'mp3' : 'jpg');
           final fileName = 'media_$mediaCount.$ext';
           try {
             await dio.download(mediaUrl, '${mediaDir.path}/$fileName');
             content = (content == null || content.isEmpty) ? '<Media attached: $fileName>' : '$content <Media attached: $fileName>';
           } catch (e) {
             debugPrint('Failed to download media: $e');
             content = (content == null || content.isEmpty) ? '<Media failed to download>' : '$content <Media failed to download>';
           }
        } else if (mediaUrl != null && !attachMedia) {
           content = (content == null || content.isEmpty) ? '<Media omitted>' : '$content <Media omitted>';
        }

        content ??= '';
        buffer.writeln('[$timestamp] $senderName: $content');
      }

      final textFile = File('${exportDir.path}/Twibee_Chat_$chatName.txt');
      await textFile.writeAsString(buffer.toString());

      if (attachMedia) {
        final zipEncoder = ZipFileEncoder();
        final zipFile = File('${dir.path}/Twibee_Chat_$chatName.zip');
        zipEncoder.create(zipFile.path);
        zipEncoder.addDirectory(exportDir);
        zipEncoder.close();
        
        await Share.shareXFiles([XFile(zipFile.path)], subject: 'Twibee Chat Export: $chatName');
      } else {
        await Share.shareXFiles([XFile(textFile.path)], subject: 'Twibee Chat Export: $chatName');
      }
    } catch (e) {
      debugPrint('Error exporting chat: $e');
    }
  }

  Future<void> clearChat(String chatId) async {
    try {
      // Delete messages sent by current user (RLS allows this)
      await _supabase
          .from('messages')
          .delete()
          .eq('chat_id', chatId)
          .eq('sender_id', currentUserId);
      // Reset unread counts
      await _supabase
          .from('chat_participants')
          .update({'unread_count': 0, 'unread_mentions_count': 0})
          .eq('chat_id', chatId)
          .eq('user_id', currentUserId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing chat: $e');
      rethrow;
    }
  }

  // ─── Context Menu Features ──────────────────────────────────────

  Future<void> addReaction(String messageId, String emoji, String chatId) async {
    try {
      final myId = currentUserId;
      if (myId == null) return;

      // Step 1: Find existing reaction for this user on this message
      final existing = await _supabase
          .from('message_reactions')
          .select('emoji')
          .eq('message_id', messageId)
          .eq('user_id', myId)
          .maybeSingle();

      if (existing != null) {
        if (existing['emoji'] == emoji) {
          // Same emoji → Toggle OFF (delete)
          await _supabase
              .from('message_reactions')
              .delete()
              .eq('message_id', messageId)
              .eq('user_id', myId);
        } else {
          // Different emoji → Change reaction (update)
          await _supabase
              .from('message_reactions')
              .update({'emoji': emoji})
              .eq('message_id', messageId)
              .eq('user_id', myId);
        }
      } else {
        // No existing → Insert new reaction
        await _supabase.from('message_reactions').insert({
          'message_id': messageId,
          'user_id': myId,
          'chat_id': chatId,
          'emoji': emoji,
        });
      }
    } catch (e) {
      debugPrint('Error in addReaction: $e');
    }
  }


  /// Clear all locked chats (removes lock and secret code)
  Future<void> clearAllLockedChats() async {
    final myId = supabaseClient.auth.currentUser?.id;
    if (myId == null) return;
    try {
      await supabaseClient
          .from('chat_participants')
          .update({'is_locked': false})
          .eq('user_id', myId)
          .eq('is_locked', true);
    } catch (e) {
      debugPrint('Error clearing locked chats: $e');
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    try {
      await _supabase
          .from('message_reactions')
          .delete()
          .eq('message_id', messageId)
          .eq('user_id', currentUserId)
          .eq('emoji', emoji);
    } catch (e) {
      debugPrint('Error removing reaction: $e');
    }
  }



  // ─── Call Features Integrations (Favorites, Links, Schedules) ──────────────────

  Stream<List<Map<String, dynamic>>> get favoritesStream {
    try {
      return _supabase
          .from('user_favorites')
          .stream(primaryKey: ['id'])
          .eq('user_id', currentUserId)
          .asyncMap((favorites) async {
            final List<Map<String, dynamic>> enriched = [];
            for (var fav in favorites) {
              final favUserId = fav['favorite_user_id'];
              if (favUserId == null) continue;
              final userResp = await _supabase
                  .from('profiles')
                  .select()
                  .eq('id', favUserId)
                  .maybeSingle();
              if (userResp != null) {
                enriched.add({...fav, 'profile': userResp});
              }
            }
            return enriched;
          }).asBroadcastStream();
    } catch (e) {
      debugPrint('Error in favoritesStream: $e');
      return Stream.value([]);
    }
  }

  Future<void> addFavorite(String favoriteUserId) async {
    try {
      await _supabase.from('user_favorites').insert({
        'user_id': currentUserId,
        'favorite_user_id': favoriteUserId,
      });
    } catch (e) {
      debugPrint('Error adding favorite: $e');
    }
  }

  Future<void> removeFavorite(String favoriteUserId) async {
    try {
      await _supabase
          .from('user_favorites')
          .delete()
          .eq('user_id', currentUserId)
          .eq('favorite_user_id', favoriteUserId);
    } catch (e) {
      debugPrint('Error removing favorite: $e');
    }
  }

  Future<String> createCallLink(String callType) async {
    try {
      // Generate unique token
      final token =
          'mme-${DateTime.now().millisecondsSinceEpoch}-${(List.generate(4, (_) => (DateTime.now().microsecondsSinceEpoch % 10).toString()).join())}';

      await _supabase.from('call_links').insert({
        'creator_id': currentUserId,
        'link_token': token,
        'call_type': callType,
      });
      return 'https://Twibee.app/call/$token';
    } catch (e) {
      debugPrint('Error creating call link: $e');
      return 'https://Twibee.app/call/fallback-link';
    }
  }

  Future<String> createScheduledCall(String title, DateTime scheduledAt,
      String callType, List<String> participantIds) async {
    try {
      final resp = await _supabase
          .from('scheduled_calls')
          .insert({
            'creator_id': currentUserId,
            'title': title,
            'scheduled_at': scheduledAt.toUtc().toIso8601String(),
            'call_type': callType,
          })
          .select()
          .single();

      final scheduledCallId = resp['id'];

      final participantInserts = participantIds
          .map((pid) => {
                'scheduled_call_id': scheduledCallId,
                'user_id': pid,
                'status': 'pending',
              })
          .toList();

      await _supabase
          .from('scheduled_call_participants')
          .insert(participantInserts);
      return scheduledCallId;
    } catch (e) {
      debugPrint('Error creating scheduled call: $e');
      rethrow;
    }
  }

  // --- Group Approvals ---

  Future<void> joinViaLink(String token) async {
    if (currentUserId == 'mock-user-preview') return;
    
    // 1. Find the invite via invite_code
    final invite = await _supabase
        .from('chats')
        .select('id')
        .eq('invite_code', token)
        .maybeSingle();
        
    if (invite == null) throw Exception('Invalid or expired invite link');
    
    final chatId = invite['id'];
    
    // 2. Check if already a member
    final memberCheck = await _supabase
        .from('chat_participants')
        .select('id')
        .eq('chat_id', chatId)
        .eq('user_id', currentUserId)
        .maybeSingle();
        
    if (memberCheck != null) return; // Already a member
    
    // 3. Check group settings for 'approve_members'
    final chatData = await _supabase
        .from('chats')
        .select('settings')
        .eq('id', chatId)
        .single();
        
    final settings = chatData['settings'] as Map<String, dynamic>? ?? {};
    final requiresApproval = settings['approve_members'] == true;
    
    if (requiresApproval) {
      // Add to join_requests
      await _supabase.from('group_join_requests').upsert({
        'chat_id': chatId,
        'user_id': currentUserId,
        'status': 'pending',
      }, onConflict: 'chat_id,user_id');
      throw Exception('Join request sent. Waiting for admin approval.');
    } else {
      // Join instantly
      await _supabase.from('chat_participants').insert({
        'chat_id': chatId,
        'user_id': currentUserId,
        'role': 'member'
      });
      // Optionally add a system message
      await sendGroupSystemMessage(chatId, 'joined via invite link');
    }
  }

  Future<void> sendGroupSystemMessage(String chatId, String content) async {
    final currentUserId = _supabase.auth.currentUser!.id;
    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'content': content,
      'message_type': 'system'
    });
  }
  
  Future<List<Map<String, dynamic>>> getPendingJoinRequests(String chatId) async {
    final res = await _supabase
        .from('group_join_requests')
        .select('id, chat_id, status, created_at, profiles(id, name, avatar_url, phone_number)')
        .eq('chat_id', chatId)
        .eq('status', 'pending');
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> approveJoinRequest(String requestId, String chatId, String userId) async {
    if (currentUserId == 'mock-user-preview') return;
    
    // Update request
    await _supabase
        .from('group_join_requests')
        .update({'status': 'approved'})
        .eq('id', requestId);
        
    // Add to participants
    await _supabase.from('chat_participants').insert({
      'chat_id': chatId,
      'user_id': userId,
      'role': 'member'
    });
    
    // Optionally add a system message
    await sendGroupSystemMessage(chatId, 'was approved to join the group');
  }

  Future<void> rejectJoinRequest(String requestId) async {
    if (currentUserId == 'mock-user-preview') return;
    await _supabase
        .from('group_join_requests')
        .update({'status': 'rejected'})
        .eq('id', requestId);
  }

  static Future<String> decryptAndParsePreview(String rawContent) async {
    String parsed = rawContent;
    if (parsed.startsWith('{')) {
      if (parsed.contains('encryptedText')) {
        try {
          parsed = await EncryptionService.decryptMessage(parsed);
        } catch (_) {
          return "🔒 Encrypted Message";
        }
      }
      if (parsed.startsWith('{') && parsed.contains('"is_status_reply"')) {
        try {
          final data = jsonDecode(parsed);
          if (data['is_status_reply'] == true) {
            parsed = 'Reply: ${data['text'] ?? ''}';
          }
        } catch (_) {}
      }
    }
    return parsed;
  }

  // ---------------------------------
  // Saved Messages Logic
  // ---------------------------------
  Future<void> toggleSaveMessage(String messageId, bool currentlySaved) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      if (currentlySaved) {
        await _supabase.from('saved_messages')
            .delete()
            .eq('user_id', userId)
            .eq('message_id', messageId);
      } else {
        await _supabase.from('saved_messages').insert({
          'user_id': userId,
          'message_id': messageId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling saved message: $e');
    }
  }

  Future<bool> isMessageSaved(String messageId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;
    try {
      final res = await _supabase.from('saved_messages')
          .select('id')
          .eq('user_id', userId)
          .eq('message_id', messageId)
          .maybeSingle();
      return res != null;
    } catch (e) {
      return false;
    }
  }
}

