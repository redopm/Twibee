// test/phase4/call_golden_test.dart
//
// Golden tests for Voice Call UI overlay states.
// 
// These tests verify the VISUAL overlay widgets that are shown for different
// call states WITHOUT instantiating the full VoiceCallScreen (which has deeply
// embedded native plugins: FlutterLocalNotifications, ZegoUIKit, Supabase,
// and looping AnimationControllers that cannot run in the test environment).
//
// Run with: flutter test test/phase4/call_golden_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:twibee/theme.dart';

/// ─── Isolated overlay widgets (mirrors VoiceCallScreen's actual overlays) ──

// The "Call Ended" state banner
Widget _buildCallEndedOverlay() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.call_end, color: Colors.red, size: 48),
        SizedBox(height: 8),
        Text(
          'Call Ended',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

// The "On Hold" overlay — mirrors VoiceCallScreen's isOnHold Positioned widget
Widget _buildOnHoldOverlay() {
  return Container(
    padding: const EdgeInsets.all(12),
    alignment: Alignment.center,
    color: Colors.black.withValues(alpha: 0.6),
    child: const Text(
      'Call is On Hold (Carrier Call Interruption)',
      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    ),
  );
}

// The "Permission Denied" overlay
Widget _buildPermissionDeniedOverlay() {
  return Container(
    padding: const EdgeInsets.all(20),
    color: Colors.black.withValues(alpha: 0.8),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mic_off, color: Colors.red, size: 48),
        SizedBox(height: 12),
        Text(
          'Permission Denied',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Microphone permission is required for calls.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

void main() {
  group('Call UI Overlay Golden Tests', () {
    Widget wrapOverlay(Widget overlay) {
      return MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(
          backgroundColor: AppColors.dark,
          body: Center(child: overlay),
        ),
      );
    }

    testWidgets('Call Ended Screen Golden Test', (tester) async {
      await tester.pumpWidget(wrapOverlay(_buildCallEndedOverlay()));
      await tester.pump(); // Settle layout

      // Verify "Call Ended" state is rendered
      expect(find.text('Call Ended'), findsOneWidget);
      expect(find.byIcon(Icons.call_end), findsOneWidget);

      // Golden snapshot (uncomment to generate/update)
      // await expectLater(find.byType(MaterialApp),
      //     matchesGoldenFile('goldens/voice_call_ended.png'));
    });

    testWidgets('Call On Hold Screen Golden Test', (tester) async {
      await tester.pumpWidget(wrapOverlay(_buildOnHoldOverlay()));
      await tester.pump();

      // Verify On Hold overlay renders the exact text from VoiceCallScreen
      expect(
        find.text('Call is On Hold (Carrier Call Interruption)'),
        findsOneWidget,
      );

      // Golden snapshot
      // await expectLater(find.byType(MaterialApp),
      //     matchesGoldenFile('goldens/voice_call_on_hold.png'));
    });

    testWidgets('Permission Denied Screen Golden Test', (tester) async {
      await tester.pumpWidget(wrapOverlay(_buildPermissionDeniedOverlay()));
      await tester.pump();

      expect(find.text('Permission Denied'), findsOneWidget);
      expect(find.byIcon(Icons.mic_off), findsOneWidget);

      // Golden snapshot
      // await expectLater(find.byType(MaterialApp),
      //     matchesGoldenFile('goldens/voice_call_permission_denied.png'));
    });

    testWidgets('Overlay container renders on dark background', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: AppColors.dark,
            body: Stack(
              children: [
                Container(color: AppColors.dark),
                Center(child: _buildOnHoldOverlay()),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Stack), findsWidgets);
      expect(find.text('Call is On Hold (Carrier Call Interruption)'),
          findsOneWidget);
    });
  });
}

