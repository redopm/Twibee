import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';

import '../firebase_options.dart';
import '../main.dart'; // For navigatorKey
import '../screens/video_call_screen.dart';
import '../screens/voice_call_screen.dart';
import '../screens/individual_chat_screen.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // Initialize Local Notifications inside the background isolate
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings();
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initSettingsIOS,
  );
  await PushNotificationService._localNotificationsPlugin.initialize(initializationSettings);

  if (message.data['type'] == 'INCOMING_CALL') {
    PushNotificationService._handleIncomingCallMessage(message.data);
  } else if (message.data['type'] == 'chat_message') {
    await PushNotificationService._handleIncomingChatMessage(message.data);
  }
}

class PushNotificationService {
  static final PushNotificationService _instance = PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    try {
      // Request permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Listen for foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.data['type'] == 'INCOMING_CALL') {
          _handleIncomingCallMessage(message.data);
        } else if (message.data['type'] == 'chat_message') {
          _handleForegroundChatMessage(message.data);
        }
      });

      // Handle user tapping on a notification (FCM)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleNotificationTap(message.data);
      });

      // Initialize Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initSettingsIOS = DarwinInitializationSettings();
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initSettingsIOS,
      );
      
      await _localNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse details) {
          if (details.payload != null) {
             _handleNotificationTap({'type': 'chat_message', 'chat_id': details.payload});
          }
        },
      );
      
      // Handle when the app is opened from a terminated state via a notification tap
      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationTap(message.data);
        }
      });

      // Listen to FCM token refreshes to keep DB updated silently
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        _updateTokenInDb(newToken);
      });

      // Handle CallKit Events
      FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
        if (event == null) return;
        switch (event.event) {
          case Event.actionCallAccept:
            _handleCallAccept(event.body);
            break;
          case Event.actionCallDecline:
            _handleCallDecline(event.body);
            break;
          default:
            break;
        }
      });

      // Check if app was opened from a terminated state via CallKit accept
      var activeCalls = await FlutterCallkitIncoming.activeCalls();
      if (activeCalls is List && activeCalls.isNotEmpty) {
        _handleCallAccept(activeCalls.first);
      }

      log('PushNotificationService initialized successfully.');
    } catch (e) {
      log('Error initializing PushNotificationService: $e');
    }
  }

  Future<void> registerDeviceToken() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) return;

      // Update linked_devices with FCM Token
      await _updateTokenInDb(fcmToken);

      log('FCM Token registered: $fcmToken');
    } catch (e) {
      log('Error registering FCM token: $e');
    }
  }

  Future<void> _updateTokenInDb(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final existing = await _supabase
          .from('linked_devices')
          .select('id')
          .eq('user_id', user.id)
          .eq('device_type', 'mobile')
          .maybeSingle();

      if (existing != null) {
        await _supabase
            .from('linked_devices')
            .update({
              'fcm_token': token,
              'last_active': 'now()',
              'os_name': Platform.operatingSystem,
            })
            .eq('id', existing['id']);
      } else {
        await _supabase.from('linked_devices').insert({
          'user_id': user.id,
          'device_type': 'mobile',
          'device_name': '${Platform.operatingSystem} App',
          'os_name': Platform.operatingSystem,
          'fcm_token': token,
        });
      }
    } catch (_) {}
  }

  Future<void> unregisterDeviceToken() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      await _supabase
          .from('linked_devices')
          .delete()
          .eq('user_id', user.id)
          .eq('device_type', 'mobile');
      log('FCM Token unregistered successfully.');
    } catch (e) {
      log('Error unregistering FCM token: $e');
    }
  }

  static Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (data['type'] == 'chat_message' && data['chat_id'] != null) {
      // Small delay to ensure the app UI is ready
      await Future.delayed(const Duration(milliseconds: 500));
      if (navigatorKey.currentContext != null) {
        // Deep link to IndividualChatScreen
        // Note: For a production app, checking if already on this screen would be ideal
        Navigator.of(navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (_) => IndividualChatScreen(
              chatId: data['chat_id'],
              chatName: 'Chat', // Will be loaded by the screen
            ),
          ),
        );
      }
    }
  }

  static Future<void> _handleForegroundChatMessage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    // In foreground, we can just show a snackbar if enabled, or rely on chat stream
    // Since we don't want to double ping when already in the chat, we check if in-app is on
    // For V1, we rely on msg_notif_enabled
    final showNotif = prefs.getBool('msg_notif_enabled') ?? true;
    if (!showNotif) return;
    
    // For V1, we still pop a local notification so they see it at the top,
    // which behaves like a banner.
    await _handleIncomingChatMessage(data);
  }

  static Future<void> _handleIncomingChatMessage(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Check Global Settings
    final showNotif = prefs.getBool('msg_notif_enabled') ?? true;
    if (!showNotif) return;

    final showPreview = prefs.getBool('notif_show_preview') ?? true;
    
    final title = data['title'] ?? 'Twibee';
    final body = showPreview 
        ? (data['body'] ?? 'New message received.') 
        : 'New message received.';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'twibee_messages',
      'Messages',
      channelDescription: 'Message notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
    
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _localNotificationsPlugin.show(
      data['message_id']?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title,
      body,
      platformDetails,
      payload: data['chat_id'],
    );
  }

  static Future<void> _handleIncomingCallMessage(Map<String, dynamic> data) async {
    if (data['type'] != 'INCOMING_CALL') return;

    final prefs = await SharedPreferences.getInstance();
    final callRingtone = prefs.getString('call_ringtone') ?? 'Default';
    
    final ringtonePath = callRingtone == 'None' ? '' : 'system_ringtone_default';

    final callId = data['call_id'];
    final callerName = data['caller_name'] ?? 'Unknown Caller';
    final isVideo = data['is_video'] == 'true';
    final uuid = const Uuid().v4();

    final params = CallKitParams(
      id: callId ?? uuid,
      nameCaller: callerName,
      appName: 'Twibee',
      avatar: data['caller_avatar']?.isNotEmpty == true ? data['caller_avatar'] : 'https://i.pravatar.cc/100',
      handle: 'Incoming Call',
      type: isVideo ? 1 : 0, // 1 for video, 0 for audio
      duration: 60000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: false,
        subtitle: 'Missed call',
      ),
      extra: <String, dynamic>{
        'call_id': callId,
        'caller_id': data['caller_id'],
        'is_video': isVideo,
      },
      headers: <String, dynamic>{'apiKey': 'TwibeeApp', 'platform': 'flutter'},
      android: AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: ringtonePath,
        backgroundColor: '#0955fa',
        backgroundUrl: 'https://i.pravatar.cc/500',
        actionColor: '#4CAF50',
      ),
      ios: IOSParams(
        iconName: 'CallKitLogo',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: 'default',
        audioSessionActive: true,
        audioSessionPreferredSampleRate: 44100.0,
        audioSessionPreferredIOBufferDuration: 0.005,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: ringtonePath,
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> _handleCallAccept(dynamic data) async {
    final Map<String, dynamic> body = data is Map ? Map<String, dynamic>.from(data) : {};
    final extra = body['extra'] ?? body;
    final String? callId = extra['call_id']?.toString();
    final String? callerId = extra['caller_id']?.toString();
    final bool isVideo = extra['is_video'] == true || extra['is_video'] == 'true';
    final nameCaller = body['nameCaller'] ?? 'Caller';

    if (callId == null || callerId == null) return;

    // Wait for Supabase to be ready if app just launched
    await Future.delayed(const Duration(seconds: 1)); 

    // Navigate to appropriate Call Screen
    if (navigatorKey.currentContext != null) {
      final user = Supabase.instance.client.auth.currentUser;
      final invitationData = ZegoCallInvitationData(
        timeoutSeconds: 60,
        callID: callId,
        invitationID: callId,
        inviter: ZegoUIKitUser(id: callerId.replaceAll('-', ''), name: nameCaller),
        invitees: [ZegoUIKitUser(id: (user?.id ?? '').replaceAll('-', ''), name: 'Me')],
        type: isVideo ? ZegoCallInvitationType.videoCall : ZegoCallInvitationType.voiceCall,
        customData: '',
      );

      if (isVideo) {
        Navigator.of(navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (context) => VideoCallScreen(
              invitationData: invitationData,
            ),
          ),
        );
      } else {
        Navigator.of(navigatorKey.currentContext!).push(
          MaterialPageRoute(
            builder: (context) => VoiceCallScreen(
              invitationData: invitationData,
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleCallDecline(dynamic data) async {
    final Map<String, dynamic> body = data is Map ? Map<String, dynamic>.from(data) : {};
    final extra = body['extra'] ?? body;
    final String? callId = extra['call_id']?.toString();
    final user = _supabase.auth.currentUser;

    if (callId != null && user != null) {
      try {
        await _supabase
            .from('call_participants')
            .update({'status': 'declined'})
            .eq('call_id', callId)
            .eq('user_id', user.id);
      } catch (e) {
        log('Error declining call in DB: $e');
      }
    }
  }
}

