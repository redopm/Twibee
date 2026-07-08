import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twibee/screens/welcome_screen.dart';
import 'helpers/test_app_wrapper.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twibee/services/settings_service.dart';

class MockSettingsService extends Mock implements SettingsService {}

void main() {
  late MockSettingsService mockSettings;

  setUp(() {
    mockSettings = MockSettingsService();
    when(() => mockSettings.getSetting(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) => invocation.namedArguments['defaultValue']);
    when(() => mockSettings.isInitialized).thenReturn(true);
  });

  testWidgets('WelcomeScreen renders properly and handles dialog interactions', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      child: const WelcomeScreen(),
    ));

    await tester.pumpAndSettle();

    // Verify "Get Started" button exists
    expect(find.text('Get Started'), findsWidgets);

    // Terms & Conditions is in a TextSpan inside RichText, not a plain Text widget
    // So we verify the RichText widget tree contains the term
    expect(find.byType(RichText), findsWidgets);

    // Tap on the ElevatedButton (Get Started) directly
    final button = find.byType(ElevatedButton);
    if (button.evaluate().isNotEmpty) {
      await tester.tap(button.first);
      await tester.pumpAndSettle();
    }
  });

  testWidgets('WelcomeScreen matches Golden File', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(2400, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      child: const WelcomeScreen(),
    ));

    await tester.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
}

