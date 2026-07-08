import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:twibee/services/zego_adapter.dart';

void setupZegoAndPermissionMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
  registerFallbackValue(ZegoScenario.Default);

  // Mock Permission Handler
  const MethodChannel permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    permissionChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'requestPermissions') {
        // Return granted for all requested permissions by default
        final List<dynamic> args = methodCall.arguments;
        final Map<int, int> result = {};
        for (var perm in args) {
          result[perm] = 1; // 1 = granted, 2 = denied
        }
        return result;
      }
      if (methodCall.method == 'checkPermissionStatus') {
        return 1; // granted
      }
      return null;
    },
  );

  // Mock ZegoUIKit Core Methods if they use method channels
  // ZegoUIKit is usually a singleton, so for UI tests we might need to mock its channels
  // Or we can just mock the specific channels it uses
  const MethodChannel zegoChannel = MethodChannel('zego_uikit');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    zegoChannel,
    (MethodCall methodCall) async {
      return null;
    }
  );
}

void mockPermissionDenied() {
  const MethodChannel permissionChannel = MethodChannel('flutter.baseflow.com/permissions/methods');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    permissionChannel,
    (MethodCall methodCall) async {
      if (methodCall.method == 'requestPermissions') {
        final List<dynamic> args = methodCall.arguments;
        final Map<int, int> result = {};
        for (var perm in args) {
          result[perm] = 2; // 2 = denied
        }
        return result;
      }
      if (methodCall.method == 'checkPermissionStatus') {
        return 2; // denied
      }
      return null;
    },
  );
}

class MockZegoAdapter extends Mock implements ZegoAdapter {
  MockZegoAdapter() {
    when(() => init(appID: any(named: 'appID'), appSign: any(named: 'appSign'), scenario: any(named: 'scenario'))).thenAnswer((_) async {});
    when(() => joinRoom(any(), markAsLargeRoom: any(named: 'markAsLargeRoom'))).thenAnswer((_) async {});
    when(() => startSharingScreen()).thenAnswer((_) async {});
    when(() => stopSharingScreen()).thenAnswer((_) async {});
    when(() => getRemoteUsers()).thenReturn([]);
    // Assuming a dummy local user
    when(() => getLocalUser()).thenReturn(ZegoUIKitUser(id: 'dummy', name: 'Dummy'));
    when(() => getUserJoinStream()).thenAnswer((_) => const Stream.empty());
    when(() => getUserLeaveStream()).thenAnswer((_) => const Stream.empty());
  }
}


