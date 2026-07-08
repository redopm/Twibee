import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:async';

class CallLogService {
  static final CallLogService _instance = CallLogService._internal();
  factory CallLogService() => _instance;
  CallLogService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final _secureStorage = const FlutterSecureStorage();

  StreamController<List<Map<String, dynamic>>>? _logsController;
  RealtimeChannel? _channel;

  /// Creates a new call log and adds initial participants.
  /// Called by the Inviter when the call initiates.
  Future<void> createOngoingCall({
    required String callId,
    required bool isVideo,
    required List<String> inviteeIds,
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      // 1. Create the core call log (use upsert to prevent duplicate key crashes)
      await _supabase.from('call_logs').upsert({
        'id': callId,
        'inviter_id': currentUserId,
        'is_video': isVideo,
        'status': 'ongoing',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 2. Add the inviter as 'joined'
      await _supabase.from('call_participants').insert({
        'call_id': callId,
        'user_id': currentUserId,
        'status': 'joined',
        'joined_at': DateTime.now().toUtc().toIso8601String(),
      });

      // 3. Add invitees as 'invited'
      final inviteeRows = inviteeIds
          .where((id) => id != '44444444-4444-4444-4444-444444444444')
          .map((id) => {
                'call_id': callId,
                'user_id': id,
                'status': 'invited',
              })
          .toList();

      if (inviteeRows.isNotEmpty) {
        // Upsert to handle potential duplicate call invitations gracefully
        await _supabase
            .from('call_participants')
            .upsert(inviteeRows, onConflict: 'call_id,user_id');
      }
    } catch (e) {
      debugPrint('Error creating ongoing call log: $e');
    }
  }

  /// Adds a new participant to an ongoing call.
  /// Called by the Inviter mid-call.
  Future<void> addParticipant({
    required String callId,
    required String userId,
  }) async {
    try {
      await _supabase.from('call_participants').insert({
        'call_id': callId,
        'user_id': userId,
        'status': 'invited',
      });
    } catch (e) {
      debugPrint('Error adding participant to call log: $e');
    }
  }

  /// Updates the status of a participant (e.g., invited -> joined / declined).
  /// Called by the Callee when they accept or decline.
  Future<void> updateParticipantStatus({
    required String callId,
    required String status, // 'joined', 'declined'
  }) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      final data = {'status': status};
      if (status == 'joined') {
        data['joined_at'] = DateTime.now().toUtc().toIso8601String();
      }

      await _supabase
          .from('call_participants')
          .update(data)
          .eq('call_id', callId)
          .eq('user_id', currentUserId);
    } catch (e) {
      debugPrint('Error updating participant status: $e');
    }
  }

  /// Ends the call, setting it to 'completed' and converting pending invites to 'missed'.
  /// Called by the Inviter when the call terminates.
  Future<void> endCall({required String callId}) async {
    try {
      await _supabase.rpc('end_call', params: {
        'p_call_id': callId,
        'p_ended_at': DateTime.now().toUtc().toIso8601String(),
      });
      refreshLogs(); // Trigger immediate UI refresh
    } catch (e) {
      debugPrint('Error ending call log: $e');
    }
  }

  /// Clears ALL call logs for this user — persists to DB so re-login doesn't restore them
  Future<void> clearCallLogs() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    try {
      // ✅ DB fix: mark all call_participants rows as cleared for this user via RPC
      await _supabase.rpc('clear_user_call_logs', params: {
        'p_user_id': currentUserId,
      });
    } catch (e) {
      debugPrint('DB clear failed (using local fallback): $e');
    }

    // Also save locally as fallback (in case DB update is slow)
    await _secureStorage.write(
      key: 'call_logs_cleared_at_$currentUserId',
      value: DateTime.now().toUtc().toIso8601String(),
    );
    refreshLogs();
  }

  Future<void> refreshLogs() async {
    if (_logsController != null && !_logsController!.isClosed) {
      final logs = await fetchUserCallLogs();
      _logsController?.add(logs);
    }
  }

  Stream<List<Map<String, dynamic>>> get callLogsStream {
    _logsController ??= StreamController<List<Map<String, dynamic>>>.broadcast(
        onListen: () {
          _startRealtimeListener();
          refreshLogs();
        },
        onCancel: () {
          _channel?.unsubscribe();
          _channel = null;
          _logsController?.close();
          _logsController = null;
        },
      );
    return _logsController!.stream;
  }

  void _startRealtimeListener() {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return;

    _channel = _supabase
        .channel('public:call_logs_$currentUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'call_logs',
          callback: (payload) {
            refreshLogs();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'call_participants',
          callback: (payload) {
            refreshLogs();
          },
        );
    _channel?.subscribe();
  }

  /// Deletes SPECIFIC call logs — persists to DB so re-login doesn't restore them
  Future<void> deleteIndividualLogs(List<String> logIds) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null || logIds.isEmpty) return;

    try {
      // ✅ DB fix: mark specific call_participants rows as deleted for this user via RPC
      await _supabase.rpc('delete_user_call_logs', params: {
        'p_user_id': currentUserId,
        'p_call_ids': logIds,
      });
    } catch (e) {
      debugPrint('DB delete failed (using local fallback): $e');
    }

    // Also save locally as fallback
    final key = 'deleted_call_logs_$currentUserId';
    final existingStr = await _secureStorage.read(key: key);
    List<String> deletedIds = [];
    if (existingStr != null) {
      try {
        deletedIds = List<String>.from(jsonDecode(existingStr));
      } catch (_) {}
    }
    deletedIds.addAll(logIds);
    await _secureStorage.write(key: key, value: jsonEncode(deletedIds));
    refreshLogs();
  }

  /// Fetches the user's call history, respecting both DB-level and local deletions.
  Future<List<Map<String, dynamic>>> fetchUserCallLogs() async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) return [];

    try {
      final clearedAtStr =
          await _secureStorage.read(key: 'call_logs_cleared_at_$currentUserId');
      DateTime? clearedAt =
          clearedAtStr != null ? DateTime.tryParse(clearedAtStr) : null;

      // Query call_logs where the current user is a participant
      // ✅ DB FIX: Exclude calls where this user has cleared/deleted via DB status
      final response = await _supabase.from('call_logs').select('''
            id,
            is_video,
            started_at,
            ended_at,
            status,
            inviter:profiles!inviter_id (id, name, avatar_url),
            participants:call_participants (
              user_id,
              status,
              profiles!user_id (name, avatar_url)
            )
          ''').order('started_at', ascending: false).limit(50);

      var logs = List<Map<String, dynamic>>.from(response);

      // ✅ DB-level filter: exclude logs where this user's participant status is cleared/deleted
      logs = logs.where((log) {
        final participants = log['participants'] as List? ?? [];
        final myParticipant = participants.firstWhere(
          (p) => p['user_id'] == currentUserId,
          orElse: () => null,
        );
        if (myParticipant != null) {
          final status = myParticipant['status'] as String? ?? '';
          if (status == 'cleared_by_user' || status == 'deleted_by_user') {
            return false;
          }
        }
        return true;
      }).toList();

      // Local fallback filter: deleted IDs stored in secure storage
      final deletedIdsStr =
          await _secureStorage.read(key: 'deleted_call_logs_$currentUserId');
      List<String> deletedIds = [];
      if (deletedIdsStr != null) {
        try {
          deletedIds = List<String>.from(jsonDecode(deletedIdsStr));
        } catch (_) {}
      }

      // Local fallback filter: cleared timestamp
      logs = logs.where((log) {
        final logId = log['id'] as String;
        if (deletedIds.contains(logId)) return false;

        if (clearedAt != null) {
          final startedAtStr = log['started_at'];
          if (startedAtStr == null) return false;
          final startedAt = DateTime.tryParse(startedAtStr);
          if (startedAt == null) return false;
          if (!startedAt.isAfter(clearedAt)) return false;
        }
        return true;
      }).toList();

      return logs;
    } catch (e) {
      debugPrint('Error fetching call logs: $e');
      return [];
    }
  }
}


