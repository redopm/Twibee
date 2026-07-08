import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:twibee/services/settings_service.dart';

class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}
class MockPostgrestFilterBuilder extends Mock implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

void main() {
  late MockSharedPreferences mockPrefs;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockPrefs = MockSharedPreferences();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => mockUser.id).thenReturn('test-id');
    
    // Prevent network fetch hanging and handle upserts
    when(() => mockSupabase.from(any())).thenThrow(Exception('Network disconnected'));

    SharedPreferences.setMockInitialValues({
      'read_receipts': true,
      'strict_mode': false,
    });
  });

  group('SettingsService Unit Tests', () {
    test('initializes with default values if none exist', () async {
      SharedPreferences.setMockInitialValues({});
      final settingsService = SettingsService(supabaseClient: mockSupabase);
      
      // wait a bit for async init to complete
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(settingsService.isInitialized, true);
      expect(settingsService.getSetting('read_receipts', defaultValue: true), true);
    });

    test('loads saved values from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'user_settings': '{"read_receipts":false,"allow_camera_effects":true}',
      });
      final settingsService = SettingsService(supabaseClient: mockSupabase);
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(settingsService.getSetting('read_receipts', defaultValue: true), false);
      expect(settingsService.getSetting('allow_camera_effects', defaultValue: false), true);
    });

    test('updateSetting changes value and notifies listeners', () async {
      final settingsService = SettingsService(supabaseClient: mockSupabase);
      await Future.delayed(const Duration(milliseconds: 50));
      
      bool notified = false;
      settingsService.addListener(() {
        notified = true;
      });

      // Update setting
      await settingsService.updateSetting('read_receipts', false);
      
      expect(settingsService.getSetting('read_receipts', defaultValue: true), false);
      expect(notified, true);
    });

    test('isStrictModeEnabled returns correct strict mode status', () async {
      SharedPreferences.setMockInitialValues({
        'user_settings': '{"privacy_strict_mode":true}',
      });
      final settingsService = SettingsService(supabaseClient: mockSupabase);
      await Future.delayed(const Duration(milliseconds: 50));
      
      expect(settingsService.isStrictModeEnabled, true);
    });
  });
}

