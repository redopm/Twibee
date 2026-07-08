import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class BotService {
  SupabaseClient get _supabase => Supabase.instance.client;

  String get currentUserId => _supabase.auth.currentUser!.id;

  // Retrieve all bots owned by the current user
  Future<List<Map<String, dynamic>>> getMyBots() async {
    final response = await _supabase
        .from('bots')
        .select('*, profiles!bots_id_fkey(name, username, avatar_url)')
        .eq('owner_id', currentUserId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Retrieve all bots globally
  Future<List<Map<String, dynamic>>> getAllBots() async {
    final response = await _supabase
        .from('bots')
        .select('*, profiles!bots_id_fkey(name, username, avatar_url, about)')
        .eq('privacy_mode', true) // Assuming true means public/available
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Creates a bot directly in the database (no Edge Function needed)
  Future<Map<String, dynamic>> createBot({
    required String name,
    required String username,
    required String shortDescription,
    required String description,
  }) async {
    // 1. Check if username already taken
    final existing = await _supabase
        .from('profiles')
        .select('id')
        .eq('username', username.toLowerCase())
        .maybeSingle();
    if (existing != null) {
      throw Exception(
          'Username "@$username" is already taken. Please choose another.');
    }

    // 2. Try Edge Function first (if deployed)
    try {
      final response = await _supabase.functions.invoke(
        'bot_management',
        body: {
          'action': 'create_bot',
          'name': name,
          'username': username.toLowerCase(),
          'short_description': shortDescription,
          'description': description,
        },
      );
      if (response.status == 200 && response.data != null) {
        return response.data;
      }
    } catch (_) {
      // Edge function not deployed - fall through to direct DB creation
    }

    // 3. Fallback: Create bot directly in DB
    // Generate a simple token (UUID-based)
    final botId = _generateUuid();
    final token = '$botId:${_generateUuid().replaceAll('-', '')}';

    // Insert into profiles first
    await _supabase.from('profiles').insert({
      'id': botId,
      'name': name,
      'username': username.toLowerCase(),
      'about': shortDescription.isNotEmpty ? shortDescription : null,
      'phone_number': 'bot_$botId',
    });

    // Insert into bots table
    try {
      await _supabase.from('bots').insert({
        'id': botId,
        'owner_id': currentUserId,
        'token_hash':
            token, // In prod this should be hashed; Edge Function handles that
        'short_description':
            shortDescription.isNotEmpty ? shortDescription : null,
        'description': description.isNotEmpty ? description : null,
        'privacy_mode': true,
      });
    } catch (e) {
      // Rollback profile
      await _supabase.from('profiles').delete().eq('id', botId);
      throw Exception('Failed to create bot: $e');
    }

    return {'bot_id': botId, 'token': token};
  }

  String _generateUuid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rand = now ^ (now >> 16);
    return '${rand.toRadixString(16).padLeft(8, '0')}-'
        '${(rand >> 4).toRadixString(16).padLeft(4, '0')}-'
        '4${(rand >> 8).toRadixString(16).padLeft(3, '0')}-'
        '${(8 + (rand & 3)).toRadixString(16)}${(rand >> 12).toRadixString(16).padLeft(3, '0')}-'
        '${DateTime.now().microsecondsSinceEpoch.toRadixString(16).padLeft(12, '0')}';
  }

  // Regenerates the token via the Edge Function
  Future<String> regenerateToken(String botId) async {
    final response = await _supabase.functions.invoke(
      'bot_management',
      body: {
        'action': 'regenerate_token',
        'bot_id': botId,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to regenerate token: ${response.data}');
    }

    return response.data['token'];
  }

  // Update Bot details (allowed via RLS for owner)
  Future<void> updateBotDetails(
    String botId, {
    String? name,
    String? shortDescription,
    String? description,
    bool? privacyMode,
  }) async {
    if (name != null) {
      await _supabase.from('profiles').update({'name': name}).eq('id', botId);
    }

    final updates = <String, dynamic>{};
    if (shortDescription != null) {
      updates['short_description'] = shortDescription;
    }
    if (description != null) updates['description'] = description;
    if (privacyMode != null) updates['privacy_mode'] = privacyMode;

    if (updates.isNotEmpty) {
      await _supabase.from('bots').update(updates).eq('id', botId);
    }
  }

  // Delete a bot (cascades deleting profile because of FK constraints if setup correctly,
  // or we can manually delete the profile which cascades to bot)
  Future<void> deleteBot(String botId) async {
    // Delete profile, which cascades to bots, bot_commands, and bot_updates based on schema
    await _supabase.from('profiles').delete().eq('id', botId);
  }

  // --- Bot Commands Management ---
  Future<List<Map<String, dynamic>>> getBotCommands(String botId) async {
    final response = await _supabase
        .from('bot_commands')
        .select()
        .eq('bot_id', botId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addBotCommand(
      String botId, String command, String description) async {
    await _supabase.from('bot_commands').insert({
      'bot_id': botId,
      'command':
          command.replaceAll('/', '').trim().toLowerCase(), // Remove slashes
      'description': description.trim(),
    });
  }

  Future<void> deleteBotCommand(String commandId) async {
    await _supabase.from('bot_commands').delete().eq('id', commandId);
  }

  // --- Utility ---
  Future<bool> checkIfBot(String userId) async {
    if (userId == 'mock-user-preview') return false;
    try {
      final response = await _supabase
          .from('bots')
          .select('id')
          .eq('id', userId)
          .maybeSingle();
      return response != null;
    } catch (_) {
      return false;
    }
  }

  // --- Callbacks ---
  Future<Map<String, dynamic>?> triggerCallback({
    required String botId,
    required String messageId,
    required String data,
  }) async {
    // 1. Call the edge function
    final response = await _supabase.functions.invoke(
      'bot_interaction',
      body: {
        'bot_id': botId,
        'message_id': messageId,
        'data': data,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to trigger callback: ${response.data}');
    }

    final callbackQueryId = response.data['result']['callback_query_id'];

    // 2. Wait for response via Realtime (with 15 second timeout)
    final completer = Completer<Map<String, dynamic>?>();

    final channel =
        _supabase.channel('public:callback_responses:id=$callbackQueryId');
    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'callback_responses',
          filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'callback_query_id',
              value: callbackQueryId),
          callback: (payload) {
            if (!completer.isCompleted) {
              completer.complete(payload.newRecord);
            }
          },
        )
        .subscribe();

    try {
      final result =
          await completer.future.timeout(const Duration(seconds: 15));
      await channel.unsubscribe();
      return result;
    } on TimeoutException {
      await channel.unsubscribe();
      return null;
    }
  }
}

