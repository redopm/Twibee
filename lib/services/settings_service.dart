import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  late final SupabaseClient _supabase;
  late SharedPreferences _prefs;
  
  Map<String, dynamic> _settings = {};
  bool _isInitialized = false;

  Map<String, dynamic> get settings => _settings;
  bool get isInitialized => _isInitialized;

  SettingsService({SupabaseClient? supabaseClient}) {
    _supabase = supabaseClient ?? Supabase.instance.client;
    _init();
  }

  Future<void> _init() async {
    _prefs = await SharedPreferences.getInstance();
    
    // Load local cached settings first
    final localSettings = _prefs.getString('user_settings');
    if (localSettings != null) {
      try {
        _settings = jsonDecode(localSettings);
        _isInitialized = true;
        notifyListeners();
      } catch (e) {
        debugPrint('Error decoding local settings: $e');
      }
    }

    // Then try to fetch from Supabase if logged in
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _fetchRemoteSettings();
      } else {
        _clearSettings();
      }
    });
    
    if (_supabase.auth.currentUser != null) {
      await _fetchRemoteSettings();
    }
  }

  Future<void> _fetchRemoteSettings() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('user_settings')
          .select('settings')
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null && data['settings'] != null) {
        _settings = data['settings'] as Map<String, dynamic>;
        await _prefs.setString('user_settings', jsonEncode(_settings));
      } else {
        // If row doesn't exist, create it with default empty settings
        await _supabase.from('user_settings').insert({
          'user_id': userId,
          'settings': _settings,
        });
      }
    } catch (e) {
      debugPrint('Error fetching remote settings: $e');
    } finally {
      if (!_isInitialized) {
        _isInitialized = true;
        notifyListeners();
      }
    }
  }

  void _clearSettings() {
    _settings.clear();
    _prefs.remove('user_settings');
    notifyListeners();
  }

  /// Get a setting value, returning defaultValue if not found
  dynamic getSetting(String key, {dynamic defaultValue}) {
    return _settings[key] ?? defaultValue;
  }

  /// Update a single setting and sync to Supabase
  Future<void> updateSetting(String key, dynamic value) async {
    _settings[key] = value;
    notifyListeners();
    
    // Save locally
    await _prefs.setString('user_settings', jsonEncode(_settings));

    // Sync to Supabase
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('user_settings').update({
          'settings': _settings,
        }).eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('Error syncing setting "$key" to Supabase: $e');
    }
  }

  /// Update multiple settings at once
  Future<void> updateSettings(Map<String, dynamic> newSettings) async {
    _settings.addAll(newSettings);
    notifyListeners();
    
    // Save locally
    await _prefs.setString('user_settings', jsonEncode(_settings));

    // Sync to Supabase
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId != null) {
        await _supabase.from('user_settings').update({
          'settings': _settings,
        }).eq('user_id', userId);
      }
    } catch (e) {
      debugPrint('Error syncing settings to Supabase: $e');
    }
  }

  /// Returns the app ThemeMode based on the 'chat_theme' setting
  ThemeMode get themeMode {
    final theme = getSetting('chat_theme', defaultValue: 'Default');
    switch (theme) {
      case 'Dark':
        return ThemeMode.dark;
      case 'Light':
      case 'Default':
      default:
        return ThemeMode.light;
    }
  }

  /// Strict Account Settings logic
  bool get isStrictModeEnabled => getSetting('privacy_strict_mode', defaultValue: false);

  /// Ask the backend if we are allowed to view a specific privacy setting of the target
  Future<bool> canViewTargetStatus(String targetUserId, String settingKey) async {
    try {
      final res = await _supabase.rpc('can_view_target_status', params: {
        'target_id': targetUserId,
        'setting_key': settingKey,
      });
      if (res != null && res is bool) {
        return res;
      }
    } catch (e) {
      debugPrint('Error evaluating target privacy: $e');
    }
    // Fail closed if we can't determine
    return false;
  }

  /// Check if the current user can see the target user's Last Seen
  /// Enforces both Target's rules and Current User's Reciprocity rules.
  Future<bool> canSeeLastSeen(String targetUserId) async {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) return false;

    // 1. Reciprocity check: Does current user share with target?
    final myLastSeen = getSetting('privacy_last_seen', defaultValue: 'Everyone');
    if (myLastSeen == 'Nobody') return false;
    if (myLastSeen == 'My contacts except...') {
      final myExcluded = List<String>.from(getSetting('privacy_last_seen_excluded', defaultValue: []));
      if (myExcluded.contains(targetUserId)) return false;
    }

    // 2. Target check: Does target share with current user? (Backend evaluation)
    final targetAllows = await canViewTargetStatus(targetUserId, 'privacy_last_seen');
    if (!targetAllows) return false;

    return true;
  }

  /// Check if the current user can see the target user's Online status
  Future<bool> canSeeOnline(String targetUserId) async {
    final myUserId = _supabase.auth.currentUser?.id;
    if (myUserId == null) return false;

    // 1. Reciprocity check: Does current user share online status with target?
    final myOnline = getSetting('privacy_online', defaultValue: 'Everyone');
    if (myOnline == 'Same as last seen') {
      final myLastSeen = getSetting('privacy_last_seen', defaultValue: 'Everyone');
      if (myLastSeen == 'Nobody') return false;
      if (myLastSeen == 'My contacts except...') {
        final myExcluded = List<String>.from(getSetting('privacy_last_seen_excluded', defaultValue: []));
        if (myExcluded.contains(targetUserId)) return false;
      }
    }

    // 2. Target check: Does target share online status with current user? (Backend evaluation)
    final targetAllows = await canViewTargetStatus(targetUserId, 'privacy_online');
    if (!targetAllows) return false;

    return true;
  }
}


