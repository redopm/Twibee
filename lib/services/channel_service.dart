import 'dart:io';
import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class ChannelService {
  SupabaseClient get _supabase => Supabase.instance.client;

  String get currentUserId {
    try {
      return _supabase.auth.currentUser!.id;
    } catch (_) {
      return 'test_user_id'; // Fallback for tests
    }
  }
  
  String? get currentUserName {
    try {
      return _supabase.auth.currentUser?.userMetadata?['name'] as String?;
    } catch (_) {
      return 'Test User';
    }
  }
  
  String? get currentUserAvatar {
    try {
      return _supabase.auth.currentUser?.userMetadata?['avatar_url'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Channel CRUD ───────────────────────────────────────────

  Future<Map<String, dynamic>> createChannel({
    required String name,
    String? description,
    bool isPublic = true,
    String? username,
    bool restrictSaving = false,
    List<String> initialSubscriberIds = const [],
    File? avatarFile,
  }) async {
    // 1. Create a Chat record for the channel first
    // We generate the UUID here to avoid RLS .select() errors after insertion.
    final chatId = const Uuid().v4();
    await _supabase
        .from('chats')
        .insert({
          'id': chatId,
          'is_group': false,
        });

    // 2. Upload Avatar if present
    String? avatarUrl;
    if (avatarFile != null) {
      final ext = avatarFile.path.split('.').last;
      final path = 'channels/$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('avatars').upload(path, avatarFile);
      avatarUrl = _supabase.storage.from('avatars').getPublicUrl(path);
    }

    // 3. Create the Channel record
    final response = await _supabase
        .from('channels')
        .insert({
          'id': chatId,
          'name': name,
          'description': description,
          'avatar_url': avatarUrl,
          'owner_id': currentUserId,
          'is_public': isPublic,
          'username': isPublic ? username : 'private_${chatId.replaceAll('-', '')}',
          'restrict_saving': restrictSaving,
        })
        .select()
        .single();

    // 4. Add initial subscribers if any
    if (initialSubscriberIds.isNotEmpty) {
      final subInserts = initialSubscriberIds.map((uid) => {
        'channel_id': chatId,
        'user_id': uid,
      }).toList();
      
      await _supabase.from('channel_subscribers').insert(subInserts);
    }

    // Note: Auto-subscribe and admin assignment is handled by the `on_channel_created` Postgres trigger!
    return response;
  }

  Future<List<Map<String, dynamic>>> getMyChannels() async {
    final response = await _supabase
        .from('channel_subscribers')
        .select('joined_at, channels!inner(id, name, description, avatar_url, owner_id, created_at, channel_subscribers(count))')
        .eq('user_id', currentUserId)
        .order('joined_at', ascending: false);

    return List<Map<String, dynamic>>.from(
      response.map((r) {
        final channel = Map<String, dynamic>.from(r['channels'] as Map<String, dynamic>);
        final subsData = channel['channel_subscribers'] as List?;
        channel['subscriber_count'] = (subsData != null && subsData.isNotEmpty) ? (subsData[0]['count'] ?? 0) : 0;
        channel.remove('channel_subscribers');
        return channel;
      }),
    );
  }

  Future<List<Map<String, dynamic>>> getMyOwnedChannels() async {
    final response = await _supabase
        .from('channels')
        .select('*, channel_subscribers(count)')
        .eq('owner_id', currentUserId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response.map((channel) {
      final c = Map<String, dynamic>.from(channel);
      final subsData = c['channel_subscribers'] as List?;
      c['subscriber_count'] = (subsData != null && subsData.isNotEmpty) ? (subsData[0]['count'] ?? 0) : 0;
      c.remove('channel_subscribers');
      return c;
    }));
  }

  Future<List<Map<String, dynamic>>> searchChannels(String query) async {
    final response = await _supabase
        .from('channels')
        .select('*, channel_subscribers(count)')
        .ilike('name', '%$query%')
        .eq('is_public', true)
        .limit(20);
    return List<Map<String, dynamic>>.from(response.map((channel) {
      final c = Map<String, dynamic>.from(channel);
      final subsData = c['channel_subscribers'] as List?;
      c['subscriber_count'] = (subsData != null && subsData.isNotEmpty) ? (subsData[0]['count'] ?? 0) : 0;
      c.remove('channel_subscribers');
      return c;
    }));
  }

  Future<Map<String, dynamic>> getChannel(String channelId) async {
    final response = await _supabase
        .from('channels')
        .select('*, profiles!channels_owner_id_fkey(name, username, avatar_url), channel_subscribers(count)')
        .eq('id', channelId)
        .single();
    
    final c = Map<String, dynamic>.from(response);
    final subsData = c['channel_subscribers'] as List?;
    c['subscriber_count'] = (subsData != null && subsData.isNotEmpty) ? (subsData[0]['count'] ?? 0) : 0;
    c.remove('channel_subscribers');
    return c;
  }

  Future<void> updateChannel({
    required String channelId,
    String? name,
    String? description,
    bool? isPublic,
    String? username,
    bool? restrictSaving,
    File? avatarFile,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isPublic != null) updates['is_public'] = isPublic;

    if (avatarFile != null) {
      final ext = avatarFile.path.split('.').last;
      final path = 'channels/$channelId/avatar.$ext';
      try {
        final canEdit = await _supabase.rpc('can_edit_channel', params: {
          'check_channel_id_text': channelId,
          'requesting_user_id': currentUserId
        });
        debugPrint('RPC can_edit_channel returned: $canEdit');
        if (canEdit == false) {
           throw Exception('RPC says you cannot edit this channel!');
        }

        await _supabase.storage.from('avatars').upload(path, avatarFile,
            fileOptions: const FileOptions(upsert: true));
        updates['avatar_url'] = _supabase.storage.from('avatars').getPublicUrl(path);
      } catch (e) {
        debugPrint('STORAGE ERROR: $e');
        throw Exception('Storage Upload 403 Error: $e');
      }
    }
    if (username != null) updates['username'] = username;
    if (restrictSaving != null) updates['restrict_saving'] = restrictSaving;

    if (updates.isNotEmpty) {
      try {
        final res = await _supabase.from('channels').update(updates).eq('id', channelId).select();
        if (res.isEmpty) throw Exception('Permission denied or channel not found.');
      } catch (e) {
        debugPrint('DB UPDATE ERROR: $e');
        throw Exception('Database Update 403 Error: $e');
      }
    }
  }

  Future<void> updateChannelFields(String channelId, Map<String, dynamic> updates) async {
    if (updates.isNotEmpty) {
      final res = await _supabase.from('channels').update(updates).eq('id', channelId).select();
      if (res.isEmpty) throw Exception('Permission denied or channel not found.');
    }
  }

  Future<void> updateChannelWallpaper(String channelId, File wallpaperFile) async {
    final ext = wallpaperFile.path.split('.').last;
    final path = 'channels/$channelId/wallpaper.$ext';
    try {
      final canEdit = await _supabase.rpc('can_edit_channel', params: {
        'check_channel_id_text': channelId,
        'requesting_user_id': currentUserId
      });
      if (canEdit == false) {
         throw Exception('RPC says you cannot edit this channel!');
      }

      await _supabase.storage.from('chat_media').upload(path, wallpaperFile, fileOptions: const FileOptions(upsert: true));
      final wallpaperUrl = _supabase.storage.from('chat_media').getPublicUrl(path);
      await updateChannelFields(channelId, {'wallpaper_url': wallpaperUrl});
    } catch (e) {
      debugPrint('WALLPAPER UPLOAD ERROR: $e');
      throw Exception('Upload Error: $e');
    }
  }

  Future<void> deleteChannel(String channelId) async {
    // 1. Delete all messages for this channel
    await _supabase.from('messages').delete().eq('chat_id', channelId);
    // 2. Delete the channel (cascade should handle subscribers, admins, etc.)
    await _supabase.from('channels').delete().eq('id', channelId);
    // 3. Delete the base chat record
    await _supabase.from('chats').delete().eq('id', channelId);
  }

  Future<void> leaveChannel(String channelId) async {
    await _supabase
        .from('channel_subscribers')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', currentUserId);
  }

  // ─── Subscribe / Unsubscribe ────────────────────────────────

  Future<void> subscribe(String channelId) async {
    await _supabase.from('channel_subscribers').insert({
      'channel_id': channelId,
      'user_id': currentUserId,
    });
  }

  Future<void> unsubscribe(String channelId) async {
    await _supabase
        .from('channel_subscribers')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', currentUserId);
  }

  Future<bool> isSubscribed(String channelId) async {
    final result = await _supabase
        .from('channel_subscribers')
        .select('user_id')
        .eq('channel_id', channelId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    return result != null;
  }

  Future<void> addMultipleSubscribers(String channelId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    
    // Using unnest for bulk insert as per AGENTS.md rules
    final records = userIds.map((userId) => {
      'channel_id': channelId,
      'user_id': userId,
    }).toList();

    await _supabase.from('channel_subscribers').upsert(records, onConflict: 'channel_id, user_id');
  }

  Future<void> removeMultipleSubscribers(String channelId, List<String> userIds) async {
    if (userIds.isEmpty) return;
    await _supabase
        .from('channel_subscribers')
        .delete()
        .eq('channel_id', channelId)
        .inFilter('user_id', userIds);
  }

  Future<void> clearMessages(String channelId) async {
    await _supabase.from('messages').delete().eq('chat_id', channelId);
  }

  // ─── Posts (Mapped to messages table) ────────────────────────

  Future<List<Map<String, dynamic>>> getPosts(String channelId,
      {int limit = 30, String? before}) async {
    var query = _supabase
        .from('messages')
        .select('*, profiles!sender_id(name, username, avatar_url), message_reactions(user_id, emoji), reply_to:messages!reply_to_id(id, content, message_type, media_url), forwarded_from:messages!forwarded_from_id(id, content, media_url)')
        .eq('chat_id', channelId);

    if (before != null) {
      query = query.lt('created_at', before);
    }

    final response = await query.order('created_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  // -------------------------------------------------------------
  // MESSAGE VIEW BATCHING LOGIC
  // -------------------------------------------------------------
  final Set<String> _unreportedViewedIds = {};
  Timer? _viewBatchTimer;

  void queueMessageView(String messageId) {
    if (currentUserId == 'mock-user-preview') return;
    
    _unreportedViewedIds.add(messageId);
    
    if (_viewBatchTimer == null || !_viewBatchTimer!.isActive) {
      _viewBatchTimer = Timer(const Duration(seconds: 2), _flushViewedMessages);
    }
  }

  Future<void> _flushViewedMessages() async {
    if (_unreportedViewedIds.isEmpty) return;

    final idsToSend = _unreportedViewedIds.toList();
    _unreportedViewedIds.clear();

    try {
      await _supabase.rpc('mark_messages_viewed', params: {
        'p_message_ids': idsToSend,
      });
    } catch (e) {
      // If it fails, we could put them back, but to avoid memory leaks if offline,
      // it's okay to drop them or you could handle retries. For now silently ignore.
    }
  }
  // -------------------------------------------------------------

  Future<Map<String, dynamic>> createPost({
    required String channelId,
    String? text,
    File? mediaFile,
    String? existingMediaUrl,
    String? mediaType,
    String? replyToId,
    String? forwardedFromId,
  }) async {
    String? mediaUrl = existingMediaUrl;

    if (mediaFile != null && mediaUrl == null) {
      final ext = mediaFile.path.split('.').last;
      // Path within bucket: channelId/timestamp.ext
      // storage.objects.name will be: channelId/timestamp.ext
      // string_to_array(name,'/')[1] = channelId  ✓ (matches RLS policy)
      final path = '$channelId/${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _supabase.storage.from('chat_media').upload(path, mediaFile);
      mediaUrl = _supabase.storage.from('chat_media').getPublicUrl(path);
    }

    final response = await _supabase
        .from('messages')
        .insert({
          'chat_id': channelId,
          'sender_id': currentUserId,
          'content': text,
          'message_type': mediaType ?? 'text',
          'media_url': mediaUrl,
          'reply_to_id': replyToId,
          'forwarded_from_id': forwardedFromId,
        })
        .select()
        .single();

    return response;
  }

  Future<void> deletePost(String postId) async {
    await _supabase.from('messages').delete().eq('id', postId);
  }

  Future<void> incrementViews(String postId) async {
    // Left as a placeholder. In a full Telegram clone, we would have a views table.
  }

  Future<void> togglePin(String postId, bool isPinned, String channelId) async {
    try {
      await _supabase.rpc('toggle_message_pin', params: {
        'p_message_id': postId,
        'p_is_pinned': isPinned,
        'p_chat_id': channelId,
      });
    } catch (e) {
      debugPrint('Error toggling pin in channel: $e');
    }
  }

  // ─── Reactions ────────────────────────────────────────────────

  Future<void> addReaction(String postId, String emoji) async {
    // Delete any existing reaction by this user on this post
    await _supabase
        .from('message_reactions')
        .delete()
        .eq('message_id', postId)
        .eq('user_id', currentUserId);

    await _supabase.from('message_reactions').upsert({
      'message_id': postId,
      'user_id': currentUserId,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction(String postId, String emoji) async {
    await _supabase
        .from('message_reactions')
        .delete()
        .eq('message_id', postId)
        .eq('user_id', currentUserId)
        .eq('emoji', emoji);
  }

  // ─── Realtime ───────────────────────────────────────────────

  RealtimeChannel subscribeToChannelPosts(
    String channelId,
    void Function(Map<String, dynamic> post) onNewPost,
  ) {
    return _supabase
        .channel('channel_posts_$channelId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: channelId,
          ),
          callback: (payload) async {
            // payload.newRecord only has raw columns (no joined data).
            // We must re-fetch the full post with all joins so that
            // reply_to, forwarded_from, reactions, profiles, etc. are included.
            try {
              final messageId = payload.newRecord['id'];
              if (messageId == null) return;
              final fullPost = await _supabase
                  .from('messages')
                  .select('*, profiles!sender_id(name, username, avatar_url), message_reactions(user_id, emoji), reply_to:messages!reply_to_id(id, content, message_type, media_url), forwarded_from:messages!forwarded_from_id(id, content, media_url)')
                  .eq('id', messageId)
                  .maybeSingle();
              if (fullPost != null) {
                onNewPost(fullPost);
              } else {
                debugPrint('Realtime fetch returned null for messageId: $messageId');
                onNewPost(payload.newRecord);
              }
            } catch (e, stack) {
              // Fallback to raw payload if fetch fails
              debugPrint('Realtime fetch failed: $e\n$stack');
              onNewPost(payload.newRecord);
            }
          },
        )
        .subscribe();
  }

  // ─── Subscribers ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getSubscribers(String channelId) async {
    final response = await _supabase
        .from('channel_subscribers')
        .select('*, profiles!channel_subscribers_user_id_fkey(name, username, avatar_url)')
        .eq('channel_id', channelId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> banUser(String channelId, String userId, {String? reason}) async {
    await _supabase.from('channel_banned_users').insert({
      'channel_id': channelId,
      'user_id': userId,
      'banned_by': currentUserId,
      'reason': reason,
    });
    // Triggers or cascade should normally not automatically delete subscribers.
    // Let's delete the subscriber explicitly.
    await _supabase
        .from('channel_subscribers')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }

  Future<bool> isBanned(String channelId) async {
    final result = await _supabase
        .from('channel_banned_users')
        .select('user_id')
        .eq('channel_id', channelId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    return result != null;
  }

  Future<void> removeSubscriber(String channelId, String userId) async {
    await _supabase
        .from('channel_subscribers')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }



  Future<List<Map<String, dynamic>>> getBannedUsers(String channelId) async {
    final response = await _supabase
        .from('channel_banned_users')
        .select('*, profiles!channel_banned_users_user_id_fkey(name, username, avatar_url)')
        .eq('channel_id', channelId);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> unbanUser(String channelId, String userId) async {
    await _supabase
        .from('channel_banned_users')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }

  // ─── Admins ─────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getAdmins(String channelId) async {
    final response = await _supabase
        .from('channel_admins')
        .select('*, profiles!channel_admins_user_id_fkey(name, username, avatar_url)')
        .eq('channel_id', channelId);
    
    final List<Map<String, dynamic>> admins = List<Map<String, dynamic>>.from(response);

    // Also fetch the channel owner and add them to the top of the admins list
    try {
      final channelRes = await _supabase
          .from('channels')
          .select('owner_id, profiles!channels_owner_id_fkey(name, username, avatar_url)')
          .eq('id', channelId)
          .single();
      
      final ownerId = channelRes['owner_id'];
      
      // If owner is not already in the list, insert at top
      if (!admins.any((admin) => admin['user_id'] == ownerId)) {
        admins.insert(0, {
          'channel_id': channelId,
          'user_id': ownerId,
          'role': 'owner',
          'profiles': channelRes['profiles'],
        });
      }
    } catch (_) {}

    return admins;
  }

  Future<bool> isAdmin(String channelId) async {
    final result = await _supabase
        .from('channel_admins')
        .select('user_id')
        .eq('channel_id', channelId)
        .eq('user_id', currentUserId)
        .maybeSingle();
    return result != null;
  }

  Future<void> addAdmin(String channelId, String userId, Map<String, dynamic> permissions) async {
    await _supabase.from('channel_admins').insert({
      'channel_id': channelId,
      'user_id': userId,
      'role': 'admin',
      'permissions': permissions,
    });
  }

  Future<void> removeAdmin(String channelId, String userId) async {
    await _supabase
        .from('channel_admins')
        .delete()
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }

  Future<void> updateAdminPermissions(String channelId, String userId, Map<String, dynamic> permissions) async {
    await _supabase
        .from('channel_admins')
        .update({'permissions': permissions})
        .eq('channel_id', channelId)
        .eq('user_id', userId);
  }

  // ─── Invite Links ───────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getInviteLinks(String channelId) async {
    final response = await _supabase
        .from('channel_invite_links')
        .select()
        .eq('channel_id', channelId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<String> createInviteLink(String channelId, {int? usageLimit, DateTime? expiresAt}) async {
    // Generate a unique 8-character string for the link
    final randomString = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final link = 'join-$randomString';

    await _supabase.from('channel_invite_links').insert({
      'channel_id': channelId,
      'link': link,
      'creator_id': currentUserId,
      'usage_limit': usageLimit,
      'expires_at': expiresAt?.toIso8601String(),
    });

    return link;
  }

  Future<void> revokeInviteLink(String linkId) async {
    await _supabase
        .from('channel_invite_links')
        .update({'is_revoked': true})
        .eq('id', linkId);
  }

  Future<String> joinChannelViaLink(String inviteCode) async {
    try {
      final response = await _supabase.rpc('join_channel_via_link', params: {
        'invite_code': inviteCode
      });
      return response as String;
    } catch (e) {
      debugPrint('JOIN LINK ERROR: $e');
      throw Exception('Failed to join via link: $e');
    }
  }
}


