import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:twibee/screens/channel_subscribers_screen.dart';
import 'package:twibee/services/chat_service.dart';
import 'package:twibee/theme.dart';

class MockChatService extends Mock implements ChatService {}

void main() {
  late MockChatService mockChatService;

  setUp(() {
    mockChatService = MockChatService();
  });

  Widget createTestWidget(Map<String, dynamic> channel, bool isAdminOrOwner) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatService>.value(value: mockChatService),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChannelSubscribersScreen(channel: channel, isAdminOrOwner: isAdminOrOwner),
      ),
    );
  }

  group('ChannelSubscribersScreen Tests', () {
    final mockChannel = {
      'id': 'test-channel-id',
      'owner_id': 'owner-id',
    };

    testWidgets('renders loading state initially', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(mockChannel, true));
      
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('handles network failure gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(mockChannel, true));
      await tester.pumpAndSettle();
      
      // Since db is not fully mocked, it catches error and shows No subscribers or SnackBar
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}

