import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twibee/screens/status_stories_screen.dart';
import 'package:twibee/services/status_service.dart';
import 'package:twibee/services/chat_service.dart';
import 'package:twibee/services/settings_service.dart';
import 'package:twibee/services/auth_service.dart';
import '../helpers/test_app_wrapper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:visibility_detector/visibility_detector.dart';

class MockStatusService extends Mock implements StatusService {}
class MockChatService extends Mock implements ChatService {}
class MockSettingsService extends Mock implements SettingsService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  late MockStatusService mockStatusService;
  late MockChatService mockChatService;
  late MockSettingsService mockSettingsService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockStatusService = MockStatusService();
    mockChatService = MockChatService();
    mockSettingsService = MockSettingsService();
    mockAuthService = MockAuthService();
    
    when(() => mockAuthService.currentUser).thenReturn(null);

    // Removed invalid mock settings

    // Mocks for my statuses
    when(() => mockStatusService.isUploadingStatus).thenReturn(false);
    when(() => mockStatusService.isUploadFailed).thenReturn(false);
    when(() => mockStatusService.uploadingThumbnail).thenReturn(null);
    when(() => mockStatusService.getMyStatuses()).thenAnswer((_) => Stream.value([]));
    
    // Mocks for contacts
    when(() => mockStatusService.getContactStatusesGrouped()).thenAnswer((_) => Stream.value([]));
    when(() => mockStatusService.fetchMutes()).thenAnswer((_) async {});
    when(() => mockStatusService.isMuted(any())).thenReturn(false);
  });

  testWidgets('Golden Test: Empty Status UI', (tester) async {
    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettingsService,
      mockStatusService: mockStatusService,
      mockChatService: mockChatService,
      mockAuthService: mockAuthService,
      child: const StatusStoriesScreen(),
    ));

    await tester.pump(const Duration(seconds: 1)); // allow streams to emit

    await expectLater(
      find.byType(StatusStoriesScreen),
      matchesGoldenFile('goldens/status_empty.png'),
    );
  });

  testWidgets('Golden Test: Upload Failed State UI', (tester) async {
    // Mock the failed upload state
    when(() => mockStatusService.isUploadFailed).thenReturn(true);
    
    // We need a dummy image file that Flutter can actually decode for Image.file
    // Writing 1x1 transparent PNG bytes
    final bytes = [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 
      0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196, 137, 
      0, 0, 0, 11, 73, 68, 65, 84, 8, 215, 99, 96, 0, 2, 0, 0, 
      5, 0, 1, 226, 38, 5, 155, 0, 0, 0, 0, 73, 69, 78, 68, 174, 
      66, 96, 130
    ];
    final file = File('${Directory.systemTemp.path}/test_thumb.png');
    file.writeAsBytesSync(bytes);
    
    when(() => mockStatusService.uploadingThumbnail).thenReturn(file);

    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettingsService,
      mockStatusService: mockStatusService,
      mockChatService: mockChatService,
      mockAuthService: mockAuthService,
      child: const StatusStoriesScreen(),
    ));

    await tester.pump(const Duration(seconds: 1)); 

    await expectLater(
      find.byType(StatusStoriesScreen),
      matchesGoldenFile('goldens/status_upload_failed.png'),
    );
  });

  testWidgets('Golden Test: Contact Statuses Grid and Rings', (tester) async {
    // 1 Unviewed Status Group, 1 Viewed Status Group
    final groupedStatuses = [
      {
        'user_id': 'user1',
        'profile': {'name': 'Alice', 'avatar_url': null},
        'all_viewed': false,
        'is_muted': false,
        'statuses': [
          {'type': 'text', 'content': 'Hello world', 'bg_color': '#FF0000', 'is_viewed': true},
          {'type': 'text', 'content': 'Unviewed', 'bg_color': '#00FF00', 'is_viewed': false},
        ]
      },
      {
        'user_id': 'user2',
        'profile': {'name': 'Bob', 'avatar_url': null},
        'all_viewed': true,
        'is_muted': false,
        'statuses': [
          {'type': 'text', 'content': 'Viewed status', 'bg_color': '#0000FF', 'is_viewed': true},
        ]
      }
    ];

    when(() => mockStatusService.getContactStatusesGrouped()).thenAnswer((_) => Stream.value(groupedStatuses));

    await tester.runAsync(() async {
      await tester.pumpWidget(TestAppWrapper(
        mockSettingsService: mockSettingsService,
        mockStatusService: mockStatusService,
        mockChatService: mockChatService,
        mockAuthService: mockAuthService,
        child: const StatusStoriesScreen(),
      ));
      // Give google_fonts enough real time to finish fetching the font
      await Future.delayed(const Duration(seconds: 3));
    });

    await tester.pumpAndSettle();  

    await expectLater(
      find.byType(StatusStoriesScreen),
      matchesGoldenFile('goldens/status_grid_rings.png'),
    );
  });
}

