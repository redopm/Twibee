import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twibee/screens/individual_chat_screen.dart';
import 'package:twibee/services/chat_service.dart';
import 'package:twibee/services/settings_service.dart';
import '../helpers/test_app_wrapper.dart';
import 'dart:async';

class MockChatService extends Mock implements ChatService {}
class MockSettingsService extends Mock implements SettingsService {}
class MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late MockChatService mockChatService;
  late MockSettingsService mockSettingsService;
  late MockSupabaseClient mockSupabaseClient;

  setUp(() {
    mockChatService = MockChatService();
    mockSettingsService = MockSettingsService();
    mockSupabaseClient = MockSupabaseClient();

    when(() => mockSettingsService.getSetting(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) {
      final key = invocation.positionalArguments[0];
      final defaultValue = invocation.namedArguments[#defaultValue];
      if (key == 'chat_bg_color') return 0xFFFFF2E0;
      if (key == 'chat_bubble_color') return 0xFFFFB74D;
      return defaultValue;
    });
    
    when(() => mockChatService.supabaseClient).thenReturn(mockSupabaseClient);
    when(() => mockChatService.currentUserId).thenReturn('test_user_id');
    when(() => mockChatService.pingOnlineStatus(any(), isChannel: any(named: 'isChannel'))).thenAnswer((_) async {});
    when(() => mockChatService.getActiveMembersCount(any(), isChannel: any(named: 'isChannel'))).thenAnswer((_) async => 1);
    when(() => mockChatService.getProfileStream(any())).thenAnswer((_) => Stream.value([]));
  });

  testWidgets('Offline Queueing: Shows clock icon for pending messages', (WidgetTester tester) async {
    // 1. Setup mock to return a pending offline message
    final pendingMessage = {
      'id': 'temp-123',
      'chat_id': 'chat_1',
      'sender_id': 'test_user_id',
      'content': 'Hello Offline',
      'message_type': 'text',
      'created_at': DateTime.now().toIso8601String(),
      'is_pending': true,
      'local_id': 'pending-123'
    };

    when(() => mockChatService.offlineQueue).thenReturn([pendingMessage]);
    
    // 2. Setup mock stream to return empty messages from cloud
    final streamController = StreamController<List<Map<String, dynamic>>>();
    when(() => mockChatService.getMessagesStream('chat_1', limit: any(named: 'limit')))
        .thenAnswer((_) => streamController.stream);

    // 3. Pump widget
    await tester.pumpWidget(
      TestAppWrapper(
        mockSettingsService: mockSettingsService,
        mockChatService: mockChatService,
        child: const IndividualChatScreen(
          chatId: 'chat_1',
          chatName: 'Test Friend',
          otherUserId: 'friend_1',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 4. Send empty data to stream
    streamController.add([]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // 5. Verify the pending message is displayed
    expect(find.text('Hello Offline'), findsOneWidget);

    // 6. Verify the clock icon is rendered (access_time)
    expect(find.byIcon(Icons.access_time), findsOneWidget);

    await streamController.close();
  });

  testWidgets('Pagination Failure: Shows Retry button on stream error', (WidgetTester tester) async {
    // 1. Setup mock stream that immediately throws an error
    when(() => mockChatService.offlineQueue).thenReturn([]);
    final streamController = StreamController<List<Map<String, dynamic>>>();
    when(() => mockChatService.getMessagesStream('chat_1', limit: any(named: 'limit')))
        .thenAnswer((_) => streamController.stream);

    // 2. Pump widget
    await tester.pumpWidget(
      TestAppWrapper(
        mockSettingsService: mockSettingsService,
        mockChatService: mockChatService,
        child: const IndividualChatScreen(
          chatId: 'chat_1',
          chatName: 'Test Friend',
          otherUserId: 'friend_1',
        ),
      ),
    );
    await tester.pump();

    // 3. Simulate existing messages, then a failure (simulating pagination failure)
    when(() => mockChatService.offlineQueue).thenReturn([
      {
        'id': 'msg_offline',
        'chat_id': 'chat_1',
        'sender_id': 'friend_1',
        'content': 'First message',
        'message_type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      }
    ]);
    
    streamController.add([
      {
        'id': 'msg_1',
        'chat_id': 'chat_1',
        'sender_id': 'friend_1',
        'content': 'First message stream',
        'message_type': 'text',
        'created_at': DateTime.now().toIso8601String(),
      }
    ]);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Now emit an error
    streamController.addError('Database timeout');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Print all text widgets to see what's actually rendered
    final texts = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
    debugPrint('Rendered texts: $texts');

    // 4. Verify existing message remains on screen (doesn't wipe chat)
    expect(find.text('First message'), findsOneWidget);

    // 5. Verify Retry button appears
    expect(find.text('Failed to load older messages.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await streamController.close();
  });
}

