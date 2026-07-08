import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import '../theme.dart';
import '../main.dart' as import_main;
import 'call_overlay_manager.dart';
import 'select_call_contact_screen.dart';
import 'video_call_screen.dart';
import 'individual_chat_screen.dart';

import '../services/call_foreground_service.dart';
import '../services/call_log_service.dart' as import_call_log_service;
import '../services/call_service.dart';
import '../services/zego_adapter.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';

// ── Call State Machine ──────────────────────────────────────────────────────
enum CallState {
  calling, // Outgoing: dialing, waiting for other side to receive signal
  ringing, // Outgoing: remote phone is ringing
  connected, // Both sides in the room
  ended, // Call rejected or ended
}

class VoiceCallScreen extends StatefulWidget {
  final ZegoCallInvitationData invitationData;

  const VoiceCallScreen({
    super.key,
    required this.invitationData,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with TickerProviderStateMixin {
  // ── Call flow state ──────────────────────────────────────────────────────
  CallState _callState = CallState.calling;
  int _duration = 0;
  Timer? _callTimer;
  Timer? _ringingTransitionTimer;
  Timer? _autoHangupTimer;
  StreamSubscription? _userJoinSub;
  StreamSubscription? _userLeaveSub;

  // ── Ringback tone ─────────────────────────────────────────────────────────
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  bool _isRingbackPlaying = false;

  // ── Screen sharing & permissions ──────────────────────────────────────────
  bool _isPermissionDenied = false;
  ValueNotifier<bool>? _remoteCameraStateNotifier;
  bool _isRemoteVideoOn = false;

  // ── Animation controllers ─────────────────────────────────────────────────
  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _ring3;
  late AnimationController _dotsController;

  // ── Dot animation for status text ─────────────────────────────────────────
  String get _statusText {
    switch (_callState) {
      case CallState.calling:
        return 'Calling$_dots';
      case CallState.ringing:
        return 'Ringing$_dots';
      case CallState.connected:
        final m = (_duration ~/ 60).toString().padLeft(2, '0');
        final s = (_duration % 60).toString().padLeft(2, '0');
        return '$m:$s';
      case CallState.ended:
        return 'Call Ended';
    }
  }

  String _dots = '';
  bool _isSpeakerOn = false;
  bool _isMicOn = true;
  DateTime? _callStartTime;
  bool _canPop = false;
  String? _remoteAvatarUrl;

  String _getDisplayName() {
    try {
      if (widget.invitationData.customData.isNotEmpty) {
        final data = jsonDecode(widget.invitationData.customData);
        if (data['groupName'] != null &&
            data['groupName'].toString().isNotEmpty) {
          return data['groupName'];
        }
      }
    } catch (_) {}

    String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final isInviter = widget.invitationData.inviter?.id == currentUserId;
    return isInviter
        ? (widget.invitationData.invitees.isNotEmpty
            ? widget.invitationData.invitees.first.name
            : 'Unknown')
        : (widget.invitationData.inviter?.name ?? 'Unknown');
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchRemoteAvatar();

    final globalState = CallOverlayManager().currentCallState.value;
    if (globalState == GlobalCallState.ringing) _callState = CallState.ringing;
    if (globalState == GlobalCallState.connected) {
      _callState = CallState.connected;
    }

    if (_callState != CallState.connected && _callState != CallState.ringing) {
      _setCallState(CallState.calling);
    }

    _initCallFlow();
    _initZego();
  }

  Future<void> _initZego() async {
    // 1. Request microphone permissions first
    final status = await [Permission.microphone].request();
    if (status[Permission.microphone]?.isDenied == true ||
        status[Permission.microphone]?.isPermanentlyDenied == true) {
      if (mounted) {
        setState(() => _isPermissionDenied = true);
        _showEndedAndPop('Permission Denied');
      }
      return;
    }

    // 2. Initialize ZegoUIKit Core Engine
    String? userId;
    String? userName;
    try {
      final user = Supabase.instance.client.auth.currentUser;
      userId = user?.id;
      userName = user?.userMetadata?['name'];
    } catch (_) {
      // Supabase not available in test environment
    }
    if (!mounted) return;
    await context.read<ZegoAdapter>().init(
          appID: 180991976,
          appSign:
              'f28a2e9a30aec3b74948af4f9a7a3ee276c1fc7cb3ddf5226a86c1626663f24e',
          scenario: ZegoScenario.Default,
        );
    context.read<ZegoAdapter>().login(userId?.replaceAll('-', '') ?? 'dummy', userName ?? 'User');

    // 3. Join the Zego room.
    await ZegoUIKit()
        .joinRoom(widget.invitationData.callID, markAsLargeRoom: false);

    // 3. Turn on mic and rebuild
    if (mounted) {
      context.read<ZegoAdapter>().turnMicrophoneOn(true);
      context.read<ZegoAdapter>().turnCameraOn(false);
      context.read<ZegoAdapter>().setAudioOutputToSpeaker(false);
      setState(() {});
    }
  }

  Future<void> _fetchRemoteAvatar() async {
    try {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final isInviter = widget.invitationData.inviter?.id == currentUserId;
      final targetId = isInviter
          ? (widget.invitationData.invitees.isNotEmpty
              ? widget.invitationData.invitees.first.id
              : null)
          : widget.invitationData.inviter?.id;

      if (targetId != null) {
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select('avatar_url')
              .eq('id', targetId)
              .maybeSingle();
          if (res != null && res['avatar_url'] != null && mounted) {
            setState(() => _remoteAvatarUrl = res['avatar_url']);
          }
        } catch (_) {}
      }
    } catch (_) {
      // Supabase not initialized (e.g. in test environment) — skip avatar fetch
    }
  }

  void _setCallState(CallState state) {
    if (!mounted) return;
    setState(() => _callState = state);
    switch (state) {
      case CallState.calling:
        CallOverlayManager().currentCallState.value = GlobalCallState.calling;
        break;
      case CallState.ringing:
        CallOverlayManager().currentCallState.value = GlobalCallState.ringing;
        break;
      case CallState.connected:
        CallOverlayManager().currentCallState.value = GlobalCallState.connected;
        break;
      case CallState.ended:
        CallOverlayManager().currentCallState.value = GlobalCallState.none;
        CallOverlayManager().globalCallStartTime = null;
        CallForegroundService().stopOngoingCallNotification();
        break;
    }
  }

  void _initAnimations() {
    // Pulsing rings — speed varies by call state
    _ring1 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat();
    _ring2 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _ring3 = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ring2.repeat();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _ring3.repeat();
    });

    // Dots animation for "Calling..." / "Ringing..."
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _dotsController.addListener(() {
      if (!mounted) return;
      final v = _dotsController.value;
      String d = '';
      if (v > 0.25) d = '.';
      if (v > 0.50) d = '..';
      if (v > 0.75) d = '...';
      if (_dots != d) setState(() => _dots = d);
    });
  }

  void _initCallFlow() {
    String? currentUserId;
    try {
      currentUserId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      // Supabase not initialized in test environment — currentUserId stays null
    }
    final isInviter = widget.invitationData.inviter?.id == currentUserId;

    if (!isInviter) {
      // ── Callee side: they already accepted — go straight to connected ──
      final callService = context.read<CallService>();
      if (callService.status == CallStatus.active) {
        // User is busy!
        context.read<ZegoAdapter>().rejectInvitation();
        _showEndedAndPop('User Busy');
        return;
      }

      if (_callState != CallState.connected) {
        _setCallState(CallState.connected);
        _startCallTimer();
      }
      try {
        import_call_log_service.CallLogService().updateParticipantStatus(
          callId: widget.invitationData.callID,
          status: 'joined',
        );
      } catch (_) {/* Supabase not available in test environment */}
    } else {
      // ── Caller side: check if already connected or start calling flow ──
      try {
        import_call_log_service.CallLogService().createOngoingCall(
          callId: widget.invitationData.callID,
          isVideo: false,
          inviteeIds: widget.invitationData.invitees.map((e) => e.id).toList(),
        );
      } catch (_) {/* Supabase not available in test environment */}
      final usersInRoom = context.read<ZegoAdapter>().getRemoteUsers();
      // PERMANENT FIX: Only auto-connect if room has been established for > 1s.
      // This prevents Zego's cached state from causing immediate "connected" bug
      // on first call after a previous session.
      final otherUsers =
          usersInRoom.where((u) => u.id != currentUserId).toList();

      // We only skip calling flow if we're RETURNING to an already-connected call.
      // For a FRESH call (callID never seen before), always start calling flow.
      final globalState = CallOverlayManager().currentCallState.value;
      final isReturningToExistingCall =
          otherUsers.isNotEmpty && globalState == GlobalCallState.connected;

      if (isReturningToExistingCall) {
        if (_callState != CallState.connected) {
          _setCallState(CallState.connected);
          _startCallTimer();
        }
        return;
      }

      // Start ringback tone for caller
      _startRingback();

      // After 3.5s assume signal delivered → ringing
      if (_callState == CallState.calling) {
        _ringingTransitionTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted && _callState == CallState.calling) {
            _setCallState(CallState.ringing);
            // Speed up ring animations slightly for ringing state
            _ring1.duration = const Duration(milliseconds: 1400);
            _ring2.duration = const Duration(milliseconds: 1400);
            _ring3.duration = const Duration(milliseconds: 1400);
          }
        });
      }

      // Auto-hangup if no one joins within 60 seconds
      _autoHangupTimer = Timer(const Duration(seconds: 60), () async {
        if (mounted && _callState != CallState.connected) {
          _showEndedAndPop('No answer');

          // Mark local participant as missed if still invited
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId != null) {
            for (var invitee in widget.invitationData.invitees) {
              await Supabase.instance.client
                  .from('call_participants')
                  .update({'status': 'missed'})
                  .eq('call_id', widget.invitationData.callID)
                  .eq('user_id', invitee.id)
                  .eq('status', 'invited');
            }
          }
        }
      });

      // Listen for the other user joining the room = call connected
      _userJoinSub =
          context.read<ZegoAdapter>().getUserJoinStream().listen((users) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final remoteJoined = users.where((u) => u.id != currentUserId).toList();

        if (remoteJoined.isNotEmpty && mounted) {
          _ringingTransitionTimer?.cancel();
          _dotsController.stop();

          // Listen to remote user's camera state
          final remoteUser = remoteJoined.first;
          _remoteCameraStateNotifier =
              ZegoUIKit().getCameraStateNotifier(remoteUser.id);
          _remoteCameraStateNotifier?.addListener(() {
            if (mounted) {
              setState(() {
                _isRemoteVideoOn = _remoteCameraStateNotifier?.value ?? false;
              });
            }
          });

          if (mounted) {
            if (_callState != CallState.connected) {
              _setCallState(CallState.connected);
              _dots = '';
              _stopRingback(); // Stop ringback when connected
              _startCallTimer();
            }
          }
        }
      });

      // Listen for user leaving = call ended
      _userLeaveSub =
          context.read<ZegoAdapter>().getUserLeaveStream().listen((users) {
        if (users.isNotEmpty && mounted) {
          _showEndedAndPop(_callState == CallState.connected
              ? 'Call Ended'
              : 'Call Declined');
        }
      });
    }
  }

  // ── Ringback tone methods ───────────────────────────────────────────────────
  void _startRingback() {
    if (_isRingbackPlaying) return;
    _isRingbackPlaying = true;
    _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
    _ringbackPlayer.setVolume(0.8);
    // Play local ringback tone
    _ringbackPlayer.play(AssetSource('sounds/ringback.mp3'));
  }

  void _stopRingback() {
    if (!_isRingbackPlaying) return;
    _isRingbackPlaying = false;
    _ringbackPlayer.stop();
  }

  void _startCallTimer() {
    _autoHangupTimer?.cancel();
    CallOverlayManager().globalCallStartTime ??= DateTime.now();
    _callStartTime = CallOverlayManager().globalCallStartTime;

    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted && _callStartTime != null) {
        setState(() =>
            _duration = DateTime.now().difference(_callStartTime!).inSeconds);
      }
    });

    final displayName = _getDisplayName();

    CallForegroundService().startOngoingCallNotification(
      remoteName: displayName,
      startTime: _callStartTime!,
      isVideo: false,
    );
  }

  void _showEndedAndPop(String message) {
    _stopRingback(); // Always stop ringback on any call end
    CallOverlayManager().currentCallState.value = GlobalCallState.none;
    CallOverlayManager().globalCallStartTime = null;
    CallForegroundService().stopOngoingCallNotification();

    if (!mounted) return;

    // Release Zego resources
    try {
      if (mounted) {
        context.read<ZegoAdapter>().turnMicrophoneOn(false);
        context.read<ZegoAdapter>().leaveRoom();
      } else {
        ZegoUIKit().turnMicrophoneOn(false);
        ZegoUIKit().leaveRoom();
      }
    } catch (_) {}

    setState(() {
      _canPop = true;
    });
    _setCallState(CallState.ended);

    final isInviter = widget.invitationData.inviter?.id ==
        context.read<ZegoAdapter>().getLocalUser().id;
    if (isInviter) {
      import_call_log_service.CallLogService()
          .endCall(callId: widget.invitationData.callID);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade800,
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  void _minimizeToChat() {
    if (_canPop) return;

    if (_callState == CallState.ended) {
      setState(() => _canPop = true);
      Navigator.of(context).pop();
      return;
    }

    setState(() => _canPop = true);

    final displayName = _getDisplayName();

    CallOverlayManager().show(
      context: context,
      remoteName: displayName,
      remoteAvatarUrl: _remoteAvatarUrl,
      isVideo: false,
      startTime: _callStartTime,
      onTapRestore: () {
        import_main.navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) =>
              VoiceCallScreen(invitationData: widget.invitationData),
        ));
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _callTimer?.cancel();
    _ringingTransitionTimer?.cancel();
    _autoHangupTimer?.cancel();
    _userJoinSub?.cancel();
    _userLeaveSub?.cancel();
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    _dotsController.dispose();
    _stopRingback();
    _ringbackPlayer.dispose();
    import_call_log_service.CallLogService().refreshLogs();
    super.dispose();
  }

  // ── Pulse ring builder ────────────────────────────────────────────────────
  Widget _buildPulseRing(AnimationController ctrl, double size) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (_, __) {
        final opacity = _callState == CallState.connected
            ? 0.0 // rings stop when connected
            : 0.10 * (1.0 - ctrl.value);
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: opacity),
            border: Border.all(
              color: Colors.white.withValues(alpha: opacity * 1.2),
              width: 1,
            ),
          ),
        );
      },
    );
  }

  void _goToChat() {
    setState(() => _canPop = true);

    final displayName = _getDisplayName();
    CallOverlayManager().show(
      context: context,
      remoteName: displayName,
      remoteAvatarUrl: _remoteAvatarUrl,
      isVideo: false,
      startTime: _callStartTime,
      onTapRestore: () {
        import_main.navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) =>
              VoiceCallScreen(invitationData: widget.invitationData),
        ));
      },
    );

    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.id;
    final isInviter = widget.invitationData.inviter?.id == currentUserId;
    final targetId = isInviter
        ? (widget.invitationData.invitees.isNotEmpty
            ? widget.invitationData.invitees.first.id
            : null)
        : widget.invitationData.inviter?.id;

    if (targetId != null) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => IndividualChatScreen(
              chatName: displayName,
              otherUserId: targetId,
              avatarUrl: _remoteAvatarUrl,
            ),
          ));
    } else {
      Navigator.maybePop(context);
    }
  }

  // ── Bottom sheet: More options ─────────────────────────────────────────────
  void _showMoreOptionsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 4),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('More Options',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
              // Screen share is removed from Voice Call
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text('More settings coming soon.',
                    style: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // ── Add participant sheet ─────────────────────────────────────────────────
  void _showAddParticipantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: SelectCallContactScreen(
            isAddParticipantMode: true,
            activeCallId: widget.invitationData.callID,
          ),
        ),
      ),
    );
  }

  // ── Control button builder ──────────────────────────────────────────────────
  Widget _buildCircularFAB(IconData icon,
      {required VoidCallback onTap,
      bool isActive = false,
      Color? backgroundColor,
      double size = 60}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor ??
              (isActive
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.white.withValues(alpha: 0.2)),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            color: backgroundColor != null
                ? Colors.white
                : (isActive ? Colors.black : Colors.white),
            size: size * 0.45,
          ),
        ),
      ),
    );
  }

  // ── Avatar color by state ───────────────────────────────────────────────────
  Color get _avatarColor {
    switch (_callState) {
      case CallState.calling:
        return AppColors.orange.withValues(alpha: 0.7);
      case CallState.ringing:
        return AppColors.orange.withValues(alpha: 0.85);
      case CallState.connected:
        return AppColors.orange;
      case CallState.ended:
        return Colors.grey;
    }
  }

  // ── Status badge color ──────────────────────────────────────────────────────
  Color get _statusBadgeColor {
    switch (_callState) {
      case CallState.calling:
      case CallState.ringing:
        return Colors.orange.withValues(alpha: 0.2);
      case CallState.connected:
        return Colors.green.withValues(alpha: 0.2);
      case CallState.ended:
        return Colors.red.withValues(alpha: 0.2);
    }
  }

  IconData get _statusIcon {
    switch (_callState) {
      case CallState.calling:
        return Icons.phone_forwarded;
      case CallState.ringing:
        return Icons.ring_volume;
      case CallState.connected:
        return Icons.call;
      case CallState.ended:
        return Icons.call_end;
    }
  }

  @override
  Widget build(BuildContext context) {
    final localUser = context.read<ZegoAdapter>().getLocalUser();
    final isInviter = widget.invitationData.inviter?.id == localUser.id;
    final displayName = _getDisplayName();

    final callService = context.watch<CallService>();
    final isOnHold = callService.isOnHold;

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_callState == CallState.ended) {
            setState(() => _canPop = true);
            Navigator.of(context).pop();
          } else {
            _minimizeToChat();
          }
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ── Background Frosted Glass Avatar ──
            if (_remoteAvatarUrl != null)
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: _remoteAvatarUrl!,
                  fit: BoxFit.cover,
                ),
              ),
            // Blur overlay
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  color: Colors.black
                      .withValues(alpha: 0.6), // Dim the blurred image
                ),
              ),
            ),

            SafeArea(
              child: Stack(
                children: [
                  Column(
                    children: [
                      // ── Top bar ──
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 12),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Left Action: Minimize
                            Align(
                              alignment: Alignment.centerLeft,
                              child: IconButton(
                                icon: const Icon(Icons.expand_more,
                                    color: Colors.white, size: 32),
                                onPressed: _minimizeToChat,
                              ),
                            ),
                            // Center: Name and Status
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  displayName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(color: Colors.black54, blurRadius: 8)
                                    ]
                                  ),
                                ),
                                const SizedBox(height: 6),
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 400),
                                  transitionBuilder: (child, anim) =>
                                      FadeTransition(
                                          opacity: anim, child: child),
                                  child: Text(
                                    _statusText,
                                    key: ValueKey(_statusText),
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16,
                                      fontWeight:
                                          _callState == CallState.connected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                      letterSpacing:
                                          _callState == CallState.connected
                                              ? 1.2
                                              : 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Right Actions: Add Participant & Chat
                            Align(
                              alignment: Alignment.centerRight,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.person_add_alt_1,
                                        color: Colors.white, size: 26),
                                    onPressed: _showAddParticipantSheet,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chat_bubble_rounded,
                                        color: Colors.white, size: 24),
                                    onPressed: _goToChat,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Encryption + Call State badge ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock,
                                    color: Colors.white54, size: 12),
                                SizedBox(width: 4),
                                Text('End-to-End Encrypted',
                                    style: TextStyle(
                                        color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          if (_callState != CallState.connected) ...[
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: _statusBadgeColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(_statusIcon,
                                      color: Colors.white54, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    _callState == CallState.calling
                                        ? 'Calling'
                                        : _callState == CallState.ringing
                                            ? 'Ringing'
                                            : 'Ended',
                                    style: const TextStyle(
                                        color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),

                      // ── Main area: Avatar + Pulse rings ──
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: 260,
                              height: 260,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _buildPulseRing(_ring1, 260),
                                  _buildPulseRing(_ring2, 205),
                                  _buildPulseRing(_ring3, 160),
                                  // Avatar
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    width: 140,
                                    height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _avatarColor,
                                      boxShadow:
                                          _callState == CallState.connected
                                              ? [
                                                  BoxShadow(
                                                    color: AppColors.orange
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 30,
                                                    spreadRadius: 5,
                                                  )
                                                ]
                                              : [],
                                    ),
                                    child: ClipOval(
                                      child: _remoteAvatarUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: _remoteAvatarUrl!,
                                              fit: BoxFit.cover,
                                              width: 140,
                                              height: 140,
                                              placeholder: (context, url) =>
                                                  Center(
                                                child: Text(
                                                  displayName.isNotEmpty
                                                      ? displayName.characters.first
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 56,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                              errorWidget:
                                                  (context, url, error) =>
                                                      Center(
                                                child: Text(
                                                  displayName.isNotEmpty
                                                      ? displayName.characters.first
                                                          .toUpperCase()
                                                      : '?',
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 56,
                                                      fontWeight:
                                                          FontWeight.bold),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                displayName.isNotEmpty
                                                    ? displayName.characters.first
                                                        .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 56,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                    ),
                                  ),
                                  AnimatedOpacity(
                                    opacity: isOnHold ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Container(
                                      width: 140,
                                      height: 140,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.black54,
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.pause,
                                            color: Colors.white, size: 60),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // ── Circular Controls (FAB style) ──
                      Padding(
                        padding: const EdgeInsets.only(
                            bottom: 40, left: 32, right: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // First Row: Video, Mic, Speaker
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCircularFAB(
                                  Icons.videocam,
                                  onTap: () {
                                    context
                                        .read<ZegoAdapter>()
                                        .turnCameraOn(true);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VideoCallScreen(
                                          invitationData: widget.invitationData,
                                        ),
                                      ),
                                    );
                                  },
                                  isActive: false,
                                ),
                                _buildCircularFAB(
                                  _isMicOn ? Icons.mic : Icons.mic_off,
                                  onTap: () {
                                    setState(() => _isMicOn = !_isMicOn);
                                    context
                                        .read<ZegoAdapter>()
                                        .turnMicrophoneOn(_isMicOn);
                                  },
                                  isActive: !_isMicOn,
                                ),
                                _buildCircularFAB(
                                  _isSpeakerOn
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  onTap: () {
                                    setState(
                                        () => _isSpeakerOn = !_isSpeakerOn);
                                    context
                                        .read<ZegoAdapter>()
                                        .setAudioOutputToSpeaker(_isSpeakerOn);
                                  },
                                  isActive: _isSpeakerOn,
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // Second Row: More Options & End Call
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                const SizedBox(
                                    width: 60), // Spacer to balance End Call
                                _buildCircularFAB(
                                  Icons.call_end,
                                  backgroundColor: Colors.red,
                                  size: 72,
                                  onTap: () => _showEndedAndPop('Call Ended'),
                                ),
                                _buildCircularFAB(
                                  Icons.more_horiz,
                                  onTap: _showMoreOptionsSheet,
                                  size: 60,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── Video Upgrade Banner (Positioned Absolute) ──
                  if (_isRemoteVideoOn)
                    Positioned(
                      top: 100, // Below header
                      left: 24,
                      right: 24,
                      child: GestureDetector(
                        onTap: () {
                          // Allow local user to turn on their camera if they want
                          // The `_isRemoteVideoOn` badge is just informational
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10)
                            ],
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.videocam,
                                  color: Colors.white, size: 20),
                              SizedBox(width: 8),
                              Text('Remote user turned on video',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ),

                  if (_isPermissionDenied)
                    Container(
                      color: Colors.black87,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.mic_off, color: Colors.red, size: 60),
                          SizedBox(height: 16),
                          Text('Permission Denied',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          Text('Microphone access is required for calls.',
                              style: TextStyle(color: Colors.white70)),
                        ],
                      ),
                    ),
                ], // Stack children
              ),
            ),
          ],
        ),
      ),
    );
  }
}
