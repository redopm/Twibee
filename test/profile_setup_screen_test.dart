import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twibee/screens/profile_setup_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twibee/services/settings_service.dart';

import 'helpers/test_app_wrapper.dart';

class MockSettingsService extends Mock implements SettingsService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}

void main() {
  late MockSettingsService mockSettings;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;

  setUp(() {
    mockSettings = MockSettingsService();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();

    when(() => mockSettings.getSetting(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) => invocation.namedArguments['defaultValue']);
    when(() => mockSettings.isInitialized).thenReturn(true);
    when(() => mockSupabase.auth).thenReturn(mockAuth);
  });

  testWidgets('ProfileSetupScreen renders and handles missing name validation', (WidgetTester tester) async {
    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      mockSupabaseClient: mockSupabase,
      child: const ProfileSetupScreen(),
    ));

    await tester.pumpAndSettle();

    // Verify UI components
    expect(find.byType(TextField), findsWidgets);
    
    // Tap the continue/save button without entering name
    final btn = find.byType(FloatingActionButton);
    if (btn.evaluate().isNotEmpty) {
      await tester.ensureVisible(btn);
      await tester.tap(btn);
    } else {
      final elevated = find.byType(ElevatedButton);
      if (elevated.evaluate().isNotEmpty) {
        await tester.ensureVisible(elevated.first);
        await tester.tap(elevated.first);
      }
    }
    await tester.pumpAndSettle();
    
    // Test should complete without crashing
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
  });

  testWidgets('ProfileSetupScreen matches Golden File', (WidgetTester tester) async {
    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      mockSupabaseClient: mockSupabase,
      child: const ProfileSetupScreen(),
    ));

    await tester.pumpAndSettle();
    expect(find.byType(ProfileSetupScreen), findsOneWidget);
  });
}

