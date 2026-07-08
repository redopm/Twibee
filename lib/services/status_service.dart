import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'encryption_service.dart';

class StatusUploadItem {
  final File file;
  final String type;
  final String caption;
  final bool isEdited;
  StatusUploadItem({required this.file, required this.type, this.caption = '', this.isEdited = false});
}

class StatusService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  String get currentUserId =>
      _supabase.auth.currentUser?.id ?? 'mock-user-preview';

  bool isUploadingStatus = false;
  bool isUploadFailed = false;
  File? uploadingThumbnail;
  List<StatusUploadItem> _pendingUploads = [];

  final Set<String> _mutedUserIds = {};
  bool _mutesLoaded = false;

  bool isMuted(String uid) => _mutedUserIds.contains(uid);

  Future<void> fetchMutes() async {
    if (_mutesLoaded || currentUserId == 'mock-user-preview') return;
    try {
      final mutesRes = await _supabase.from('status_mutes').select('muted_user_id').eq('user_id', currentUserId);
      _mutedUserIds.clear();
      _mutedUserIds.addAll((mutesRes as List).map((m) => m['muted_user_id'] as String));
      _mutesLoaded = true;
      notifyListeners();
    } catch (_) {}
  }

  void setUploadingStatus(bool uploading, File? thumbnail) {
    isUploadingStatus = uploading;
    uploadingThumbnail = thumbnail;
    notifyListeners();
  }

  void _setUploadFailed(bool failed) {
    isUploadFailed = failed;
    isUploadingStatus = false;
    notifyListeners();
  }

  Future<void> uploadStatusBatch(List<StatusUploadItem> items) async {
    isUploadingStatus = true;
    isUploadFailed = false;
    uploadingThumbnail = items.first.file;
    _pendingUploads = items;
    notifyListeners();

    bool hasFailures = false;

    for (var item in items) {
      File uploadFile = item.file;
      
      // We skip complex video compression here assuming the UI trimmed it,
      // but in a production app, we would compress here. For this test phase,
      // we'll rely on the file passed, or we can just upload it directly.

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecondsSinceEpoch}';
      final ext = item.type == 'video' ? '.mp4' : '.jpg';
      final storagePath = 'status_$currentUserId/$fileName$ext';

      try {
        await _supabase.storage.from('chat_media').upload(
          storagePath,
          uploadFile,
        );

        await _supabase.from('statuses').insert({
          'user_id': currentUserId,
          'type': item.type,
          'media_url': storagePath,
          'content': item.caption,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'expires_at': DateTime.now().toUtc().add(const Duration(hours: 24)).toIso8601String(),
        });
      } catch (e) {
        debugPrint('[StatusService] Upload failed: $e');
        hasFailures = true;
      }
    }

    if (hasFailures) {
      _setUploadFailed(true);
    } else {
      isUploadingStatus = false;
      _pendingUploads.clear();
      uploadingThumbnail = null;
      notifyListeners();
    }
  }

  Future<void> retryStatusUpload() async {
    if (_pendingUploads.isEmpty) return;
    await uploadStatusBatch(_pendingUploads);
  }

  Future<void> postTextStatus(
      String content, String bgColor, String fontStyle) async {
    if (currentUserId == 'mock-user-preview') return;
    await _supabase.from('statuses').insert({
      'user_id': currentUserId,
      'type': 'text',
      'content': content,
      'bg_color': bgColor,
      'font_style': fontStyle,
    });
  }

  Future<void> postMediaStatus(
      String mediaUrl, String type, String caption) async {
    if (currentUserId == 'mock-user-preview') return;
    await _supabase.from('statuses').insert({
      'user_id': currentUserId,
      'type': type,
      'media_url': mediaUrl,
      'content': caption,
    });
  }

  Stream<List<Map<String, dynamic>>> getContactStatusesGrouped() {
    return _supabase
        .from('statuses')
        .stream(primaryKey: ['id'])
        .neq('user_id', currentUserId)
        .order('created_at', ascending: true) // oldest first for sequence
        .asyncMap((statuses) async {
          final cutoff = DateTime.now().subtract(const Duration(hours: 24));

          // 1. Filter out expired
          final activeStatuses = statuses.where((s) {
            final ca = DateTime.parse(s['created_at']);
            return ca.isAfter(cutoff);
          }).toList();

          if (activeStatuses.isEmpty) return [];

          // 2. Fetch views & mutes
          final viewsRes = await _supabase
              .from('status_views')
              .select('status_id')
              .eq('viewer_id', currentUserId);
          final viewedIds =
              (viewsRes as List).map((v) => v['status_id'] as String).toSet();

          final mutesRes = await _supabase
              .from('status_mutes')
              .select('muted_user_id')
              .eq('user_id', currentUserId);
          final mutedIds = (mutesRes as List)
              .map((m) => m['muted_user_id'] as String)
              .toSet();

          // 3. Group by user_id
          final Map<String, List<Map<String, dynamic>>> grouped = {};
          for (var s in activeStatuses) {
            final uid = s['user_id'];
            s['is_viewed'] = viewedIds.contains(s['id']);
            if (!grouped.containsKey(uid)) grouped[uid] = [];
            grouped[uid]!.add(s);
          }

          // 4. Enrich with profiles
          List<Map<String, dynamic>> finalGroups = [];
          for (var uid in grouped.keys) {
            final profile = await _supabase
                .from('profiles')
                .select('name, avatar_url, status_privacy')
                .eq('id', uid)
                .maybeSingle();
            
            bool canView = true;
            if (profile != null && profile['status_privacy'] != null) {
              final privacy = profile['status_privacy'] as Map<String, dynamic>;
              final type = privacy['type'] as String?;
              if (type == 'except') {
                final excluded = List<String>.from(privacy['excluded'] ?? []);
                if (excluded.contains(currentUserId)) canView = false;
              } else if (type == 'only') {
                final included = List<String>.from(privacy['included'] ?? []);
                if (!included.contains(currentUserId)) canView = false;
              }
            }

            if (!canView) continue;

            final userStatuses = grouped[uid]!;
            final allViewed = userStatuses.every((s) => s['is_viewed'] == true);
            final isMuted = mutedIds.contains(uid);

            finalGroups.add({
              'user_id': uid,
              'profile': profile ?? {'name': 'Unknown'},
              'statuses': userStatuses,
              'all_viewed': allViewed,
              'is_muted': isMuted,
              'latest_timestamp': userStatuses.last['created_at'],
            });
          }

          // Sort by latest_timestamp descending
          finalGroups.sort(
              (a, b) => b['latest_timestamp'].compareTo(a['latest_timestamp']));

          return finalGroups;
        });
  }

  Stream<List<Map<String, dynamic>>> getMyStatuses() {
    return _supabase
        .from('statuses')
        .stream(primaryKey: ['id'])
        .eq('user_id', currentUserId)
        .order('created_at', ascending: true) // oldest first
        .map((statuses) {
          final cutoff = DateTime.now().subtract(const Duration(hours: 24));
          return statuses.where((s) {
            final ca = DateTime.parse(s['created_at']);
            return ca.isAfter(cutoff);
          }).toList();
        });
  }

  Future<void> markViewed(String statusId) async {
    if (currentUserId == 'mock-user-preview') return;
    try {
      await _supabase.from('status_views').insert({
        'status_id': statusId,
        'viewer_id': currentUserId,
      });
    } catch (e) {
      // Ignored if already viewed (due to UNIQUE constraint)
    }
  }

  Future<List<Map<String, dynamic>>> getViewers(String statusId) async {
    final res = await _supabase
        .from('status_views')
        .select('viewer_id, viewed_at, profiles(name, avatar_url)')
        .eq('status_id', statusId)
        .neq('viewer_id', currentUserId)  // Exclude the owner's own views
        .order('viewed_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> deleteStatus(String statusId) async {
    await _supabase.from('statuses').delete().eq('id', statusId);
  }

  Future<void> muteUser(String userId) async {
    if (currentUserId == 'mock-user-preview') return;
    _mutedUserIds.add(userId);
    notifyListeners();
    try {
      await _supabase.from('status_mutes').upsert({
        'user_id': currentUserId,
        'muted_user_id': userId,
      }, onConflict: 'user_id,muted_user_id');
    } catch (e) {
      // Ignore if it already exists or errors
    }
  }

  Future<void> unmuteUser(String userId) async {
    if (currentUserId == 'mock-user-preview') return;
    _mutedUserIds.remove(userId);
    notifyListeners();
    await _supabase
        .from('status_mutes')
        .delete()
        .eq('user_id', currentUserId)
        .eq('muted_user_id', userId);
  }

  Future<void> reportStatus(String statusId, String reportedUserId, String reason) async {
    if (currentUserId == 'mock-user-preview') return;
    try {
      await _supabase.from('reports').insert({
        'reporter_id': currentUserId,
        'reported_id': reportedUserId,
        'item_id': statusId,
        'item_type': 'status',
        'reason': reason,
      });
    } catch (e) {
      debugPrint('Error reporting status: $e');
    }
  }

  Future<void> updateStatusPrivacy(
      String type, List<String> included, List<String> excluded) async {
    if (currentUserId == 'mock-user-preview') return;
    await _supabase.from('profiles').update({
      'status_privacy': {
        'type': type,
        'included': included,
        'excluded': excluded
      }
    }).eq('id', currentUserId);
  }

  Future<Map<String, dynamic>?> getStatusPrivacy() async {
    if (currentUserId == 'mock-user-preview') return null;
    final res = await _supabase
        .from('profiles')
        .select('status_privacy')
        .eq('id', currentUserId)
        .maybeSingle();
    return res?['status_privacy'] as Map<String, dynamic>?;
  }

  Future<void> replyToStatus(
      Map<String, dynamic> status, String message) async {
    if (currentUserId == 'mock-user-preview') return;
    final ownerId = status['user_id'];

    // First find if there's an existing 1-on-1 chat
    String? chatId;

    // Check if chat exists
    final chatRes = await _supabase
        .from('chats')
        .select('id, chat_participants!inner(user_id)')
        .eq('is_group', false);

    for (var c in chatRes) {
      final participants = c['chat_participants'] as List;
      final ids = participants.map((p) => p['user_id'] as String).toList();
      if (ids.length == 2 &&
          ids.contains(currentUserId) &&
          ids.contains(ownerId)) {
        chatId = c['id'];
        break;
      }
    }

    if (chatId == null) {
      // Create new chat
      final newChatRes = await _supabase
          .from('chats')
          .insert({
            'is_group': false,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      chatId = newChatRes['id'];

      if (chatId != null) {
        await _supabase.from('chat_participants').insert([
          {'chat_id': chatId, 'user_id': currentUserId},
          {'chat_id': chatId, 'user_id': ownerId},
        ]);
      }
    }

    if (chatId == null) return;

    // Send message referring to status
    final contentJson = jsonEncode({
      'is_status_reply': true,
      'text': message,
      'status_media_url': status['media_url'],
      'status_media_type': status['type'] == 'video' ? 'video' : 'image',
      'status_caption': status['content'] ?? '',
    });

    // Encrypt the status reply JSON payload
    String finalContent = contentJson;
    try {
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
    } catch (e) {
      debugPrint('[DEBUG] E2EE Error for status reply: $e');
    }

    await _supabase.from('messages').insert({
      'chat_id': chatId,
      'sender_id': currentUserId,
      'message_type': 'text',
      'content': finalContent,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> addReaction(Map<String, dynamic> status, String emoji) async {
    if (currentUserId == 'mock-user-preview') return;
    try {
      // Send it as a message to chat first
      await replyToStatus(status, emoji);

      // Then try to upsert the reaction in the database
      await _supabase.from('status_reactions').upsert({
        'status_id': status['id'],
        'user_id': currentUserId,
        'emoji': emoji,
      }, onConflict: 'status_id,user_id');
    } catch (e) {
      debugPrint('Error adding reaction: $e');
    }
  }
}

