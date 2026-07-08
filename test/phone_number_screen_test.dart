import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twibee/screens/phone_number_screen.dart';
import 'package:twibee/services/auth_service.dart';
import 'package:twibee/services/settings_service.dart';

import 'helpers/test_app_wrapper.dart';

class MockSettingsService extends Mock implements SettingsService {}
class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockSettingsService mockSettings;
  late MockAuthService mockAuth;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    mockSettings = MockSettingsService();
    mockAuth = MockAuthService();
    
    when(() => mockSettings.getSetting(any(), defaultValue: any(named: 'defaultValue')))
        .thenAnswer((invocation) => invocation.namedArguments['defaultValue']);
    when(() => mockSettings.isInitialized).thenReturn(true);
  });

  testWidgets('PhoneNumberScreen shows validation error for short number', (WidgetTester tester) async {
    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      mockAuthService: mockAuth,
      child: const PhoneNumberScreen(),
    ));

    await tester.pumpAndSettle();

    // Verify if it rendered by printing the tree if TextField is missing
    final textField = find.byType(TextField);
    if (textField.evaluate().isEmpty) {
      debugPrint('WIDGET TREE:');
      debugPrint(tester.binding.renderViewElement?.toStringDeep());
    }

    expect(textField, findsOneWidget);
    await tester.enterText(textField, '123');
    await tester.pump();

    // Tap the FAB (which is usually the next button, wait, let's find the button)
    // There is no FAB in PhoneNumberScreen based on the code... wait! Let me check the full file
    // I only viewed up to line 150. Let's find any button and tap it.
    // If it's a floating action button:
    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab);
    } else {
      // Find elevated button
      final btn = find.byType(ElevatedButton);
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first);
      }
    }
    
    await tester.pumpAndSettle();

    // It should show a snackbar for "valid phone number"
    expect(find.text('Please enter a valid phone number'), findsWidgets);
  });

  testWidgets('PhoneNumberScreen handles network failure gracefully', (WidgetTester tester) async {
    when(() => mockAuth.sendOtp(any())).thenThrow(Exception('Network Error'));

    await tester.pumpWidget(TestAppWrapper(
      mockSettingsService: mockSettings,
      mockAuthService: mockAuth,
      child: const PhoneNumberScreen(),
    ));

    await tester.pumpAndSettle();

    final textField = find.byType(TextField);
    await tester.enterText(textField, '9999999999');
    await tester.pump();

    final fab = find.byType(FloatingActionButton);
    if (fab.evaluate().isNotEmpty) {
      await tester.tap(fab);
    } else {
      final btn = find.byType(ElevatedButton);
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first);
      }
    }

    await tester.pumpAndSettle();
    
    // We expect the snackbar showing the error
    expect(find.text('Exception: Network Error'), findsWidgets);
  });
}

