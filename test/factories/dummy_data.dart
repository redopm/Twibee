import 'dart:math';

class DummyData {
  static final _random = Random();

  /// Generate a valid dummy profile map suitable for Supabase mocking
  static Map<String, dynamic> generateProfile({String? id, String? name, String? phone}) {
    final userId = id ?? 'user_${_random.nextInt(10000)}';
    return {
      'id': userId,
      'phone_number': phone ?? '+1234567890',
      'name': name ?? 'Test User',
      'about': 'Hey there! I am using MissMe.',
      'avatar_url': 'https://example.com/avatar.png',
      'is_online': true,
      'last_seen': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().subtract(const Duration(days: 10)).toIso8601String(),
    };
  }

  /// Generate a valid dummy message map
  static Map<String, dynamic> generateMessage({
    String? id,
    required String chatId,
    required String senderId,
    String? text,
  }) {
    return {
      'id': id ?? 'msg_${_random.nextInt(10000)}',
      'chat_id': chatId,
      'sender_id': senderId,
      'text_content': text ?? 'Hello world!',
      'media_url': null,
      'media_type': null,
      'is_read': false,
      'is_delivered': true,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Generate a valid dummy status map
  static Map<String, dynamic> generateStatus({
    String? id,
    required String userId,
    String? mediaType,
  }) {
    return {
      'id': id ?? 'status_${_random.nextInt(10000)}',
      'user_id': userId,
      'media_url': 'https://example.com/status.jpg',
      'media_type': mediaType ?? 'image',
      'text_content': 'Check this out',
      'bg_color': '#FF0000',
      'expires_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}

