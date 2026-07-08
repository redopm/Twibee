import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../screens/call_overlay_manager.dart';

class CallForegroundService {
  static final CallForegroundService _instance = CallForegroundService._internal();
  factory CallForegroundService() => _instance;
  CallForegroundService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    const androidInitialize = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitialize = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: androidInitialize,
      iOS: iosInitialize,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        CallOverlayManager().restoreCallScreen();
      },
    );

    // Request permissions for Android 13+ (if applicable)
    _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();

    _isInitialized = true;
  }

  Future<void> startOngoingCallNotification({
    required String remoteName,
    required DateTime startTime,
    required bool isVideo,
  }) async {
    if (!_isInitialized) await init();

    final androidDetails = AndroidNotificationDetails(
      'ongoing_call_channel',
      'Ongoing Calls',
      channelDescription: 'Notification channel for ongoing active calls.',
      importance: Importance.low, // popup nahi, silent shade entry
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      color: const Color(0xFF4CAF50), // Green
      usesChronometer: true,
      chronometerCountDown: false,
      showWhen: true,
      when: startTime.millisecondsSinceEpoch,
    );

    final platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      888, // Constant ID for ongoing call
      remoteName,
      isVideo ? 'Ongoing Video Call' : 'Ongoing Voice Call',
      platformDetails,
    );
  }

  Future<void> stopOngoingCallNotification() async {
    await _notificationsPlugin.cancel(888);
  }
}

