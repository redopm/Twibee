import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import 'package:app_links/app_links.dart';
import 'dart:async';
import '../theme.dart';
import '../services/settings_service.dart';
import '../services/channel_service.dart';
import 'chats_home_screen.dart';
import 'status_stories_screen.dart';
import 'calls_screen.dart';
import 'channels_screen.dart';
import 'my_profile_screen.dart';
import 'channel_chat_screen.dart';
import 'individual_chat_screen.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  late int _currentIndex;
  bool _isLocked = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final TextEditingController _pinController = TextEditingController();
  StreamSubscription? _linkSub;

  final List<Widget> _screens = const [
    ChatsHomeScreen(),
    StatusStoriesScreen(),
    ChannelsScreen(),
    CallsScreen(),
    MyProfileScreen(), 
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);
    _checkAppLock();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    // Handle link when app is already running
    _linkSub = appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
    // Handle link when app was launched from a cold start via link
    try {
      final initialLink = await appLinks.getInitialLink();
      if (initialLink != null) _handleDeepLink(initialLink);
    } catch (_) {}
  }

  void _handleDeepLink(Uri uri) async {
    if (!mounted) return;
    // Twibee://channel/{channelId}/post/{postId}
    if (uri.scheme == 'Twibee' && uri.host == 'channel') {
      final segments = uri.pathSegments;
      final channelId = segments.isNotEmpty ? segments[0] : null;
      if (channelId == null) return;
      try {
        final channelService = ChannelService();
        final channels = await channelService.getMyChannels();
        final ch = channels.firstWhere(
          (c) => c['id'] == channelId,
          orElse: () => <String, dynamic>{'id': channelId, 'name': 'Channel'},
        );
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(
            builder: (_) => ChannelChatScreen(channel: ch),
          ));
        }
      } catch (_) {}
    }
    // Twibee://chat/{chatId}
    else if (uri.scheme == 'Twibee' && uri.host == 'chat') {
      final chatId = uri.pathSegments.isNotEmpty ? uri.pathSegments[0] : null;
      if (chatId == null) return;
      if (mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => IndividualChatScreen(chatId: chatId, chatName: 'Chat'),
        ));
      }
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pinController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAppLock();
    } else if (state == AppLifecycleState.paused) {
      final settings = context.read<SettingsService>();
      if (settings.getSetting('app_lock', defaultValue: false)) {
        setState(() => _isLocked = true);
      }
    }
  }

  Future<void> _checkAppLock() async {
    final settings = context.read<SettingsService>();
    if (!settings.getSetting('app_lock', defaultValue: false)) return;

    setState(() => _isLocked = true);
    await _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) {
        // Fallback to PIN handled in UI if biometrics are totally unavailable
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock Twibee',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );

      if (authenticated && mounted) {
        setState(() => _isLocked = false);
        _pinController.clear();
      }
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
    }
  }

  void _verifyPin() {
    // In a real app, you'd compare this to a securely stored PIN.
    // For now, if local_auth fails, we just accept "1234" as the fallback PIN for demonstration
    // based on the user's request for a fallback.
    if (_pinController.text == '1234') {
      setState(() => _isLocked = false);
      _pinController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN')));
    }
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocked) {
      return Scaffold(
        backgroundColor: AppColors.white,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: AppColors.orange),
              const SizedBox(height: 24),
              const Text('Twibee is locked', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.dark)),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 4,
                  style: const TextStyle(fontSize: 24, letterSpacing: 16),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: 'PIN (try 1234)',
                  ),
                  onChanged: (val) {
                    if (val.length == 4) _verifyPin();
                  },
                ),
              ),
              const SizedBox(height: 40),
              TextButton.icon(
                icon: const Icon(Icons.fingerprint, size: 30),
                label: const Text('Use Biometrics', style: TextStyle(fontSize: 18)),
                onPressed: _authenticate,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
    );
  }
}

// ─── Premium Floating Navigation Bar ─────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon, required this.label});
}

class _FloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _FloatingNavBar({required this.currentIndex, required this.onTap});

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  static const _items = [
    _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: 'Chats'),
    _NavItem(icon: Icons.circle_outlined, activeIcon: Icons.data_usage_rounded, label: 'Status'),
    _NavItem(icon: Icons.campaign_outlined, activeIcon: Icons.campaign_rounded, label: 'Channels'),
    _NavItem(icon: Icons.call_outlined, activeIcon: Icons.call_rounded, label: 'Calls'),
    _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: 'You'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(_FloatingNavBar old) {
    super.didUpdateWidget(old);
    if (old.currentIndex != widget.currentIndex) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPad + 10),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: AppColors.orange.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final isSelected = widget.currentIndex == i;
            return Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => widget.onTap(i),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return _NavBarItem(
                      item: _items[i],
                      isSelected: isSelected,
                      animProgress: isSelected ? _controller.value : 0.0,
                    );
                  },
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isSelected;
  final double animProgress;

  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.animProgress,
  });

  @override
  Widget build(BuildContext context) {
    final scale = isSelected ? (1.0 + 0.08 * Curves.elasticOut.transform(animProgress.clamp(0.0, 1.0))) : 1.0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Icon with animated pill background
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          width: isSelected ? 48 : 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.orange.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Transform.scale(
              scale: scale,
              child: Icon(
                isSelected ? item.activeIcon : item.icon,
                size: 22,
                color: isSelected ? AppColors.orange : const Color(0xFFAAAAAA),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        // Label
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: isSelected ? 10.5 : 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected ? AppColors.orange : const Color(0xFFAAAAAA),
            letterSpacing: isSelected ? 0.2 : 0,
          ),
          child: Text(item.label),
        ),
      ],
    );
  }
}

