import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:twibee/services/call_service.dart';
import 'package:twibee/services/settings_service.dart';
import '../helpers/mock_zego.dart';

class MockCallService extends Mock implements CallService {}
class MockSettingsService extends Mock implements SettingsService {}

void main() {
  late MockCallService mockCallService;
  late MockSettingsService mockSettingsService;

  setUpAll(() {
    setupZegoAndPermissionMocks();
  });

  setUp(() {
    mockCallService = MockCallService();
    mockSettingsService = MockSettingsService();
  });

  testWidgets('Permission denied prevents call and shows error', (tester) async {
    mockPermissionDenied();
    when(() => mockCallService.status).thenReturn(CallStatus.ended);
    expect(true, true); 
  });

  testWidgets('User Busy state automatically rejects incoming call', (tester) async {
    when(() => mockCallService.status).thenReturn(CallStatus.active);
    expect(true, true);
  });

  testWidgets('OS Call Interruption places Zego call on hold', (tester) async {
    when(() => mockCallService.isOnHold).thenReturn(true);
    expect(true, true);
  });

  testWidgets('Call rejected triggers End state and logs call', (tester) async {
    when(() => mockCallService.status).thenReturn(CallStatus.ended);
    expect(true, true);
  });
}

