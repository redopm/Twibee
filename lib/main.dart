import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/call_logs_screen.dart';
import 'screens/linked_devices_screen.dart';
import 'screens/help_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/phone_number_screen.dart';
import 'screens/otp_verification_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'screens/main_screen.dart';
import 'screens/individual_chat_screen.dart';
import 'screens/status_stories_screen.dart';
import 'screens/status_viewer_screen.dart';
import 'screens/channels_screen.dart';
import 'screens/my_profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/privacy_settings_screen.dart';
import 'screens/notifications_settings_screen.dart';
import 'screens/storage_data_screen.dart';
import 'screens/bots_screen.dart';
import 'screens/saved_messages_screen.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import 'screens/group_info_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/chats_home_screen.dart';
import 'screens/join_preview_screen.dart';
import 'screens/e2ee_routing_wrapper.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/chat_service.dart';
import 'services/settings_service.dart';
import 'services/call_service.dart';
import 'services/status_service.dart';
import 'services/zego_adapter.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit_signaling_plugin/zego_uikit_signaling_plugin.dart';

import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/push_notification_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase FIRST
  // Use try/catch instead of Firebase.apps.isEmpty because on hot restart,
  // Dart VM state resets while the native Firebase instance persists,
  // causing a [core/duplicate-app] crash even when the isEmpty check passes.
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // [core/duplicate-app] is expected on hot restart — safe to ignore.
    debugPrint('Firebase already initialized: $e');
  }
  
  // Supabase also throws on duplicate init during hot restart
  try {
    await Supabase.initialize(
      url: 'https://xfynwiyungfkckhjhzsg.supabase.co',
      publishableKey: 'sb_publishable_OK7XVN9Mq4qZiGYva-TCgQ_jFzrphag',
    );
  } catch (e) {
    debugPrint('Supabase already initialized: $e');
  }

  ZegoUIKitPrebuiltCallInvitationService().setNavigatorKey(navigatorKey);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ChatService()),
        ChangeNotifierProvider(create: (_) => SettingsService()),
        ChangeNotifierProvider(create: (_) => CallService()),
        ChangeNotifierProvider(create: (_) => StatusService()),
        Provider<ZegoAdapter>(create: (_) => ZegoAdapterImpl()),
      ],
      child: const TwibeeApp(),
    ),
  );
}

class TwibeeApp extends StatefulWidget {
  const TwibeeApp({super.key});

  @override
  State<TwibeeApp> createState() => _TwibeeAppState();
}

class _TwibeeAppState extends State<TwibeeApp> with WidgetsBindingObserver {
  bool _isZegoInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize Push Notification Service after UI starts
    PushNotificationService().init();
    
    _initDeepLinks();

    // Re-init Zego if a user is already logged in at startup
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      _initZego(session.user.id);
      PushNotificationService().registerDeviceToken();
      _updateOnlineStatus(true);
    }
    
    // Listen for auth changes to init/uninit Zego
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      if ((event == AuthChangeEvent.signedIn || event == AuthChangeEvent.initialSession) && session != null) {
        _initZego(session.user.id);
        PushNotificationService().registerDeviceToken();
        _updateOnlineStatus(true);
      } else if (event == AuthChangeEvent.signedOut) {
        _updateOnlineStatus(false);
        _isZegoInitialized = false;
        ZegoUIKitPrebuiltCallInvitationService().uninit();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateOnlineStatus(true);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _updateOnlineStatus(false);
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;
    try {
      await Supabase.instance.client.from('profiles').update({
        'is_online': isOnline,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', session.user.id);
    } catch (_) {}
  }

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // Handle link when app is in background or killed
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleDeepLink(uri);
      }
    });

    // Handle link when app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint('Deep Link Error: $err');
    });
  }

  void _handleDeepLink(Uri uri) {
    if (uri.scheme == 'Twibee' && uri.host == 'join') {
      final code = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (code != null && navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (_) => JoinPreviewScreen(inviteCode: code)),
        );
      }
    }
  }

  Future<void> _initZego(String userId) async {
    if (_isZegoInitialized) return;
    _isZegoInitialized = true;
    
    userId = userId.replaceAll('-', ''); // Fix for Zego's 32-byte userId limit
    
    final user = Supabase.instance.client.auth.currentUser;
    final userName = user?.phone ?? user?.id ?? 'User';

    ZegoUIKitPrebuiltCallInvitationService().init(
      appID: 180991976,
      appSign: 'f28a2e9a30aec3b74948af4f9a7a3ee276c1fc7cb3ddf5226a86c1626663f24e',
      userID: userId,
      userName: userName,
      plugins: [ZegoUIKitSignalingPlugin()],
      notificationConfig: ZegoCallInvitationNotificationConfig(
        androidNotificationConfig: ZegoCallAndroidNotificationConfig(
          showOnFullScreen: true,
          showOnLockedScreen: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settings, _) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'Twibee',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: settings.themeMode,
          home: Consumer<AuthService>(
            builder: (context, auth, _) {
              return auth.isAuthenticated ? const E2EERoutingWrapper() : const SplashScreen();
            },
          ),
        );
      },
    );
  }
}

/// Simple menu to preview each newly built screen.
/// Replace this with your actual app navigation later.
class ScreenMenu extends StatelessWidget {
  const ScreenMenu({super.key});

  @override
  Widget build(BuildContext context) {
    final screens = [
      _MenuEntry('01 - Splash Screen', Icons.water_drop_outlined, const SplashScreen()),
      _MenuEntry('02 - Welcome Screen', Icons.waving_hand_outlined, const WelcomeScreen()),
      _MenuEntry('03 - Phone Number Entry', Icons.phone_android_outlined, const PhoneNumberScreen()),
      _MenuEntry('04 - OTP Verification', Icons.password_outlined, const OtpVerificationScreen(phoneNumber: '+91 98765 43210')),
      _MenuEntry('05 - Profile Setup', Icons.person_add_outlined, const ProfileSetupScreen()),
      _MenuEntry('06 - Chats Home', Icons.chat_bubble_outline, const ChatsHomeScreen()),
      _MenuEntry('07 - Individual Chat', Icons.person, const IndividualChatScreen(chatId: 'demo_id', chatName: 'Test Chat')),
      // _MenuEntry('09 - Voice Call', Icons.call, const VoiceCallScreen(callerName: 'Test Caller', callerPhone: '123')),
      // _MenuEntry('10 - Video Call', Icons.videocam, const VideoCallScreen(callerName: 'Test Caller', callerPhone: '123')),
      _MenuEntry('11 - Status & Stories', Icons.amp_stories, const StatusStoriesScreen()),
      _MenuEntry('12 - Status Viewer', Icons.remove_red_eye, const StatusViewerScreen(userId: 'debug_id', name: 'Demo', avatarText: 'D', avatarColor: AppColors.orange, statuses: [])),
      _MenuEntry('13 - Channels', Icons.rss_feed, const ChannelsScreen()),
      _MenuEntry('14 - My Profile', Icons.account_circle, const MyProfileScreen()),
      _MenuEntry('15 - Settings', Icons.settings, const SettingsScreen()),
      _MenuEntry('16 - Privacy Settings', Icons.lock, const PrivacySettingsScreen()),
      _MenuEntry('17 - Notifications Settings', Icons.notifications, const NotificationsSettingsScreen()),
      _MenuEntry('18 - Storage and Data', Icons.save, const StorageDataScreen()),
      _MenuEntry('19 - Bots', Icons.smart_toy, const BotsScreen()),
      _MenuEntry('20 - Saved Messages', Icons.bookmark, const SavedMessagesScreen()),
      _MenuEntry('Call Logs', Icons.call_outlined, const CallLogsScreen()),
      _MenuEntry('Linked Devices', Icons.devices_outlined, const LinkedDevicesScreen()),
      _MenuEntry('Help & Support', Icons.help_outline, const HelpScreen()),
      _MenuEntry('Group Info', Icons.groups_outlined, const GroupInfoScreen(chatId: 'demo', groupName: 'Demo Group')),
    ];

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        title: const Text('Twibee - Screen Preview', style: TextStyle(color: AppColors.white)),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: screens.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final entry = screens[i];
          return Card(
            elevation: 0,
            color: AppColors.orangePale,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: Icon(entry.icon, color: AppColors.orange),
              title: Text(entry.title, style: AppTextStyles.title),
              trailing: const Icon(Icons.chevron_right, color: AppColors.orange),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => entry.screen),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MenuEntry {
  final String title;
  final IconData icon;
  final Widget screen;

  _MenuEntry(this.title, this.icon, this.screen);
}

