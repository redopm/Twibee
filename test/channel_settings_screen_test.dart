import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:twibee/screens/channel_settings_screen.dart';
import 'package:twibee/services/chat_service.dart';
import 'package:twibee/theme.dart';

class MockChatService extends Mock implements ChatService {}

void main() {
  late MockChatService mockChatService;

  setUp(() {
    mockChatService = MockChatService();
  });

  Widget createTestWidget(Map<String, dynamic> channel) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatService>.value(value: mockChatService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChannelSettingsScreen(channel: channel),
      ),
    );
  }

  group('ChannelSettingsScreen Tests', () {
    final mockChannel = {
      'id': 'test-channel-id',
      'name': 'Test Channel',
      'description': 'A channel for testing',
      'owner_id': 'owner-id',
      'is_public': true,
      'direct_messages_enabled': false,
    };

    testWidgets('renders channel info and settings correctly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(mockChannel));
      await tester.pumpAndSettle();

      // Check if title is present
      expect(find.text('Channel Settings'), findsOneWidget);
      
      // Check if channel name is displayed
      expect(find.text('Name & Description'), findsOneWidget);
      expect(find.text('Test Channel'), findsOneWidget);
      
      // Check sections
      expect(find.text('ENGAGEMENT'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
      expect(find.text('MANAGEMENT'), findsOneWidget);

      // Check specific tiles
      expect(find.text('Direct Messages'), findsOneWidget);
      expect(find.text('Administrators'), findsOneWidget);
      expect(find.text('Subscribers'), findsOneWidget);
      expect(find.text('Leave Channel'), findsOneWidget); // since current user is not owner-id
    });

    testWidgets('toggles Direct Messages switch without crashing', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(mockChannel));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch).first;
      expect(switchFinder, findsOneWidget);
      
      // Tap the switch
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      
      // It should show a snackbar (error or success) depending on the DB mock
      // Since DB is not fully mocked, it will throw, catch, and show a SnackBar with 'Failed to update'
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Failed to update'), findsOneWidget);
    });
  });
}

