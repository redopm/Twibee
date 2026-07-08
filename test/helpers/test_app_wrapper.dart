import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twibee/services/settings_service.dart';
import 'package:twibee/services/auth_service.dart';
import 'package:twibee/services/chat_service.dart';
import 'package:twibee/services/call_service.dart';
import 'package:twibee/services/status_service.dart';
import 'package:twibee/services/zego_adapter.dart';

/// A wrapper widget to easily test UI components that depend on 
/// Provider<SettingsService> and/or SupabaseClient.
class TestAppWrapper extends StatelessWidget {
  final Widget child;
  final SettingsService mockSettingsService;
  final SupabaseClient? mockSupabaseClient;
  final AuthService? mockAuthService;
  final ChatService? mockChatService;
  final CallService? mockCallService;
  final StatusService? mockStatusService;
  final ZegoAdapter? mockZegoAdapter;

  const TestAppWrapper({
    super.key,
    required this.child,
    required this.mockSettingsService,
    this.mockSupabaseClient,
    this.mockAuthService,
    this.mockChatService,
    this.mockCallService,
    this.mockStatusService,
    this.mockZegoAdapter,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsService>.value(value: mockSettingsService),
        if (mockAuthService != null)
          ChangeNotifierProvider<AuthService>.value(value: mockAuthService!),
        if (mockChatService != null)
          ChangeNotifierProvider<ChatService>.value(value: mockChatService!),
        if (mockCallService != null)
          ChangeNotifierProvider<CallService>.value(value: mockCallService!),
        if (mockStatusService != null)
          ChangeNotifierProvider<StatusService>.value(value: mockStatusService!),
        if (mockZegoAdapter != null)
          Provider<ZegoAdapter>.value(value: mockZegoAdapter!),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }
}

