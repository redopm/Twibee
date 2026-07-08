import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChannelPreferences {
  static const String _archivedKey = 'archived_channels';
  static const String _pinnedKey = 'pinned_channels';
  static const String _mutedKey = 'muted_channels';
  static const String _readKey = 'read_channels';

  static Future<List<String>> _getList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(key) ?? [];
  }

  static Future<void> _setList(String key, List<String> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(key, list);
  }

  // Archive
  static Future<List<String>> getArchivedChannels() => _getList(_archivedKey);
  static Future<void> toggleArchive(String channelId) async {
    final list = await getArchivedChannels();
    if (list.contains(channelId)) {
      list.remove(channelId);
    } else {
      list.add(channelId);
    }
    await _setList(_archivedKey, list);
  }
  static Future<bool> isArchived(String channelId) async {
    final list = await getArchivedChannels();
    return list.contains(channelId);
  }

  // Pin
  static Future<List<String>> getPinnedChannels() => _getList(_pinnedKey);
  static Future<void> togglePin(String channelId) async {
    final list = await getPinnedChannels();
    if (list.contains(channelId)) {
      list.remove(channelId);
    } else {
      list.add(channelId);
    }
    await _setList(_pinnedKey, list);
  }

  // Mute
  static Future<List<String>> getMutedChannels() => _getList(_mutedKey);
  static Future<void> toggleMute(String channelId) async {
    final list = await getMutedChannels();
    if (list.contains(channelId)) {
      list.remove(channelId);
    } else {
      list.add(channelId);
    }
    await _setList(_mutedKey, list);
  }

  // Read
  static Future<List<String>> getReadChannels() => _getList(_readKey);
  static Future<void> toggleRead(String channelId) async {
    final list = await getReadChannels();
    if (list.contains(channelId)) {
      list.remove(channelId);
    } else {
      list.add(channelId);
    }
    await _setList(_readKey, list);
  }
  // Auto-delete
  static const String _autoDeleteKey = 'auto_delete_channels';
  
  static Future<Map<String, String>> getAutoDeleteSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_autoDeleteKey);
    if (jsonString == null) return {};
    try {
      return Map<String, String>.from(jsonDecode(jsonString));
    } catch (_) {
      return {};
    }
  }

  static Future<void> setAutoDelete(String channelId, String duration) async {
    final prefs = await SharedPreferences.getInstance();
    final map = await getAutoDeleteSettings();
    if (duration.isEmpty) {
      map.remove(channelId);
    } else {
      map[channelId] = duration;
    }
    await prefs.setString(_autoDeleteKey, jsonEncode(map));
  }

  static Future<String?> getAutoDelete(String channelId) async {
    final map = await getAutoDeleteSettings();
    return map[channelId];
  }
}

