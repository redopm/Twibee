import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:twibee/screens/settings_screen.dart';
import 'package:twibee/screens/my_profile_screen.dart';
import 'package:twibee/services/settings_service.dart';

class MockSettingsService extends Mock implements SettingsService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}
class MockGoTrueClient extends Mock implements GoTrueClient {}
class MockUser extends Mock implements User {}

void main() {
  late MockSettingsService mockSettings;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  setUp(() {
    mockSettings = MockSettingsService();
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenReturn(mockAuth);
    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockAuth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => mockUser.id).thenReturn('test-id');

    when(() => mockSettings.getSetting(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) => invocation.namedArguments['defaultValue']);
    when(() => mockSettings.updateSetting(any(), any())).thenAnswer((_) async {});
    when(() => mockSettings.isInitialized).thenReturn(true);
    when(() => mockSettings.isStrictModeEnabled).thenReturn(false);
    
    // Prevent network fetch hanging
    when(() => mockSupabase.from(any())).thenThrow(Exception('Network error'));
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: mockSettings),
      ],
      child: MaterialApp(
        home: SettingsScreen(supabaseClient: mockSupabase),
      ),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('should render settings screen and find items', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsWidgets);
      
      // Should show settings groups (by scrolling down if needed)
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Chats'), findsOneWidget);
      
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -500));
      await tester.pumpAndSettle();
      
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Storage and Data'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
    });

    testWidgets('Navigation Tests should navigate from Settings to MyProfile', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on the profile header (first ListTile in SettingsScreen)
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.byType(MyProfileScreen), findsOneWidget);
    });
  });
}

