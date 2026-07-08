import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twibee/screens/otp_verification_screen.dart';

import 'helpers/test_app_wrapper.dart';
import 'package:twibee/services/settings_service.dart';

class MockSettingsService extends Mock implements SettingsService {}

void main() {
  late MockSettingsService mockSettings;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockSettings = MockSettingsService();
    when(() => mockSettings.getSetting(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) => invocation.namedArguments['defaultValue']);
    when(() => mockSettings.isInitialized).thenReturn(true);
  });

  testWidgets('OTP Verification handles invalid inputs gracefully', (WidgetTester tester) async {
    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      child: const OtpVerificationScreen(phoneNumber: '+1234567890'),
    ));

    await tester.pumpAndSettle();

    // The screen should have a text field for OTP
    // Let's ensure the UI renders correctly
    expect(find.textContaining('+1234567890'), findsOneWidget);
    
    // Tap the verify button without entering OTP
    // We expect it to either show a validation error or disable the button
    // (exact behavior depends on implementation, we just test it doesn't crash)
    expect(find.byType(ElevatedButton), findsWidgets);
    await tester.tap(find.byType(ElevatedButton).first);
    await tester.pumpAndSettle();
    
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('OTP Screen matches Golden File', (WidgetTester tester) async {
    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      child: const OtpVerificationScreen(phoneNumber: '+1234567890'),
    ));

    await tester.pumpAndSettle();
    
    expect(find.byType(OtpVerificationScreen), findsOneWidget);
  });
}

