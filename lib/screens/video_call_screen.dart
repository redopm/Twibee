import 'dart:async';
import 'dart:convert';
import 'package:twibee/main.dart' as import_main;
import 'package:flutter/material.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:audioplayers/audioplayers.dart';

import 'call_overlay_manager.dart';
import 'select_call_contact_screen.dart';
import 'individual_chat_screen.dart';

import '../services/call_foreground_service.dart';
import '../services/call_log_service.dart' as import_call_log_service;
import '../services/zego_adapter.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import 'package:provider/provider.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Call State Machine
// ──────────────────────────────────────────────────────────────────────────────
enum VideoCallState { calling, ringing, connected, ended }

// ──────────────────────────────────────────────────────────────────────────────
// Draggable + Resizable PiP (self-view during connected state)
// ──────────────────────────────────────────────────────────────────────────────
class _DraggablePip extends StatefulWidget {
  final String localUserId;

  const _DraggablePip({required this.localUserId});

  @override
  State<_DraggablePip> createState() => _DraggablePipState();
}

class _DraggablePipState extends State<_DraggablePip> {
  Offset _position = const Offset(16, 100);
  Size _size = const Size(100, 140);
  double _baseScale = 1.0;
  double _currentScale = 1.0;

  static const double _minW = 70;
  static const double _maxW = 200;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Positioned(
      left: _position.dx.clamp(0, screenSize.width - _size.width),
      top: _position.dy.clamp(0, screenSize.height - _size.height),
      child: GestureDetector(
        // FIXED: Scale gesture is a superset of pan — handles BOTH drag and pinch.
        // Using onPanUpdate + onScaleUpdate together causes a Flutter assertion error.
        onScaleStart: (_) => _baseScale = _size.width / 100,
        onScaleUpdate: (d) {
          // Handle drag (pan) via focalPointDelta — works even when scale == 1.0
          setState(() {
            _position = Offset(
              (_position.dx + d.focalPointDelta.dx)
                  .clamp(0, screenSize.width - _size.width),
              (_position.dy + d.focalPointDelta.dy)
                  .clamp(0, screenSize.height - _size.height),
            );
          });
          // Handle pinch-to-resize
          if (d.scale != 1.0) {
            _currentScale =
                (_baseScale * d.scale).clamp(_minW / 100, _maxW / 100);
            final newW = (_currentScale * 100).clamp(_minW, _maxW);
            final newH = newW * 1.4;
            setState(() => _size = Size(newW, newH));
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: _size.width,
            height: _size.height,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white24, width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6), blurRadius: 12),
              ],
            ),
            child: Stack(
              children: [
                // Local camera view
                ZegoAudioVideoView(
                  user: context.read<ZegoAdapter>().getLocalUser(),
                  avatarConfig: ZegoAvatarConfig(
                    showInAudioMode: false,
                    showSoundWavesInAudioMode: false,
                    builder: (context, size, user, extraInfo) =>
                        const SizedBox.shrink(),
                  ),
                ),
                // "You" label
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text('You',
                        style: TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
                // Drag handle indicator
                const Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.drag_indicator,
                      color: Colors.white38, size: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Main Video Call Screen
// ──────────────────────────────────────────────────────────────────────────────
class VideoCallScreen extends StatefulWidget {
  final ZegoCallInvitationData invitationData;

  const VideoCallScreen({
    super.key,
    required this.invitationData,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen>
    with TickerProviderStateMixin {
  // ── State ─────────────────────────────────────────────────────────────────
  VideoCallState _callState = VideoCallState.calling;
  int _duration = 0;
  Timer? _callTimer;
  Timer? _ringingTimer;
  Timer? _autoHangupTimer;
  StreamSubscription? _userJoinSub;
  StreamSubscription? _userLeaveSub;

  // ── Remote users ──────────────────────────────────────────────────────────
  List<ZegoUIKitUser> _remoteUsers = [];

  // ── Ringback tone ───────────────────────────────────────────────────
  final AudioPlayer _ringbackPlayer = AudioPlayer();
  bool _isRingbackPlaying = false;

  // ── UI State ──────────────────────────────────────────────────────────────
  bool _controlsVisible = true;
  bool _isFrontCamera = true;
  bool _isSharingScreen = false;
  Timer? _controlsHideTimer;

  bool _isMicOn = true;
  bool _isCamOn = true;
  bool _isSpeakerOn = true;

  // ── Dots animation ────────────────────────────────────────────────────────
  late AnimationController _dotsCtrl;
  String _dots = '';
  bool _isMinimizing = false;
  String? _remoteAvatarUrl;

  String get _displayName {
    try {
      if (widget.invitationData.customData.isNotEmpty) {
        final data = jsonDecode(widget.invitationData.customData);
        if (data['group_name'] != null &&
            data['group_name'].toString().isNotEmpty) {
          return data['group_name'];
        }
      }
    } catch (_) {}

    if (_remoteUsers.isNotEmpty) {
      if (_remoteUsers.length == 1) {
        return _remoteUsers.first.name;
      }
      return '${_remoteUsers.first.name} and ${_remoteUsers.length - 1} others';
    }

    String? currentUserId = Supabase.instance.client.auth.currentUser?.id;

    final isInviter = widget.invitationData.inviter?.id == currentUserId;
    return isInviter
        ? (widget.invitationData.invitees.isNotEmpty
            ? widget.invitationData.invitees.first.name
            : 'Unknown')
        : (widget.invitationData.inviter?.name ?? 'Unknown');
  }

  String get _statusText {
    switch (_callState) {
      case VideoCallState.calling:
        return 'Calling$_dots';
      case VideoCallState.ringing:
        return 'Ringing$_dots';
      case VideoCallState.connected:
        final m = (_duration ~/ 60).toString().padLeft(2, '0');
        final s = (_duration % 60).toString().padLeft(2, '0');
        return '$m:$s';
      case VideoCallState.ended:
        return 'Call Ended';
    }
  }

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchRemoteAvatar();
    _initZego();

    // Ensure the video fills the entire screen (BoxFit.cover equivalent)
    context.read<ZegoAdapter>().updateVideoViewMode(true);

    final globalState = CallOverlayManager().currentCallState.value;
    if (globalState == GlobalCallState.ringing) {
      _callState = VideoCallState.ringing;
    }
    if (globalState == GlobalCallState.connected) {
      _callState = VideoCallState.connected;
    }

    if (_callState != VideoCallState.connected &&
        _callState != VideoCallState.ringing) {
      _setCallState(VideoCallState.calling);
    }

    _initCallFlow();
    _startControlsTimer();
  }

  Future<void> _initZego() async {
    // 1. Request permissions first (awaited BEFORE joining)
    await [Permission.camera, Permission.microphone].request();

    // 2. Initialize ZegoUIKit Core Engine directly here
    final user = Supabase.instance.client.auth.currentUser;
    if (!mounted) return;
    await context.read<ZegoAdapter>().init(
          appID: 180991976,
          appSign:
              'f28a2e9a30aec3b74948af4f9a7a3ee276c1fc7cb3ddf5226a86c1626663f24e',
          scenario: ZegoScenario.Default,
        );
    if (!mounted) return;
    context
        .read<ZegoAdapter>()
        .login(user?.id.replaceAll('-', '') ?? 'dummy', user?.userMetadata?['name'] ?? 'User');

    // Check data_less_calls
    final isLowData = context
        .read<SettingsService>()
        .getSetting('data_less_calls', defaultValue: false);
    context.read<ZegoAdapter>().setLowDataMode(isLowData);

    // Fix video glitch (aadha se pura)
    ZegoUIKit().updateVideoViewMode(true);

    // 3. Join the Zego room.
    await context
        .read<ZegoAdapter>()
        .joinRoom(widget.invitationData.callID, markAsLargeRoom: false);

    // 3. Turn on camera and REBUILD UI to fetch the REAL local user object.
    // The initial getLocalUser() before joinRoom returns a dummy object!
    if (mounted) {
      context.read<ZegoAdapter>().turnCameraOn(true);
      context.read<ZegoAdapter>().useFrontFacingCamera(true);
      context.read<ZegoAdapter>().turnMicrophoneOn(true);
      context.read<ZegoAdapter>().setAudioOutputToSpeaker(true);
      setState(() {}); // THIS IS THE CRITICAL FIX!
    }
  }

  void _setCallState(VideoCallState state) {
    if (!mounted) return;
    setState(() => _callState = state);
    switch (state) {
      case VideoCallState.calling:
        CallOverlayManager().currentCallState.value = GlobalCallState.calling;
        break;
      case VideoCallState.ringing:
        CallOverlayManager().currentCallState.value = GlobalCallState.ringing;
        break;
      case VideoCallState.connected:
        CallOverlayManager().currentCallState.value = GlobalCallState.connected;
        break;
      case VideoCallState.ended:
        CallOverlayManager().currentCallState.value = GlobalCallState.none;
        CallOverlayManager().globalCallStartTime = null;
        CallForegroundService().stopOngoingCallNotification();
        break;
    }
  }

  void _initAnimations() {
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
    _dotsCtrl.addListener(() {
      if (!mounted) return;
      final v = _dotsCtrl.value;
      final d = v > 0.75
          ? '...'
          : v > 0.50
              ? '..'
              : v > 0.25
                  ? '.'
                  : '';
      if (_dots != d) setState(() => _dots = d);
    });
  }

  Future<void> _fetchRemoteAvatar() async {
    try {
      final authService = context.read<AuthService>();
      final currentUserId = authService.currentUser?.id;
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
    } catch (_) {}
  }

  void _initCallFlow() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isInviter = widget.invitationData.inviter?.id == currentUserId;

    if (!isInviter) {
      // Callee: already connected
      if (_callState != VideoCallState.connected) {
        _setCallState(VideoCallState.connected);
        _onConnected();
      }
      import_call_log_service.CallLogService().updateParticipantStatus(
        callId: widget.invitationData.callID,
        status: 'joined',
      );
    } else {
      // Caller flow: check if already connected first (mid-call transition from voice to video)
      import_call_log_service.CallLogService().createOngoingCall(
        callId: widget.invitationData.callID,
        isVideo: true,
        inviteeIds: widget.invitationData.invitees.map((e) => e.id).toList(),
      );
      final usersInRoom = context.read<ZegoAdapter>().getRemoteUsers();
      final otherUsers =
          usersInRoom.where((u) => u.id != currentUserId).toList();

      // PERMANENT FIX: Only skip calling flow if RETURNING to an existing connected call.
      // Prevents Zego cached state from causing immediate connected bug on first call.
      final globalState = CallOverlayManager().currentCallState.value;
      final isReturningToExistingCall =
          otherUsers.isNotEmpty && globalState == GlobalCallState.connected;

      if (isReturningToExistingCall) {
        if (_callState != VideoCallState.connected) {
          _setCallState(VideoCallState.connected);
          _remoteUsers = otherUsers;
          _onConnected();
        }
        return;
      }

      // Start ringback tone for caller
      _startRingback();

      // calling → ringing → connected
      if (_callState == VideoCallState.calling) {
        _ringingTimer = Timer(const Duration(milliseconds: 3500), () {
          if (mounted && _callState == VideoCallState.calling) {
            _setCallState(VideoCallState.ringing);
          }
        });
      }

      // Auto-hangup if no one joins within 60 seconds
      _autoHangupTimer = Timer(const Duration(seconds: 60), () async {
        if (mounted && _callState != VideoCallState.connected) {
          _setCallState(VideoCallState.ended);
          _showEndSnack('No answer');

          // Mark local participant as missed if still invited
          final currentUserId = Supabase.instance.client.auth.currentUser?.id;
          if (currentUserId != null) {
            try {
              for (var invitee in widget.invitationData.invitees) {
                await Supabase.instance.client
                    .from('call_participants')
                    .update({'status': 'missed'})
                    .eq('call_id', widget.invitationData.callID)
                    .eq('user_id', invitee.id)
                    .eq('status', 'invited');
              }
            } catch (_) {}
          }
        }
      });

      _userJoinSub =
          context.read<ZegoAdapter>().getUserJoinStream().listen((users) {
        final currentUserId = Supabase.instance.client.auth.currentUser?.id;
        final remoteJoined = users.where((u) => u.id != currentUserId).toList();

        if (remoteJoined.isNotEmpty &&
            mounted &&
            _callState != VideoCallState.connected) {
          _ringingTimer?.cancel();
          if (_callState != VideoCallState.connected) {
            _remoteUsers = remoteJoined;
            _setCallState(VideoCallState.connected);
            _stopRingback(); // Stop ringback when other user joins
            _onConnected();
          }
        }
      });

      _userLeaveSub =
          context.read<ZegoAdapter>().getUserLeaveStream().listen((users) {
        if (users.isNotEmpty && mounted) {
          // Filter out left users
          setState(() {
            _remoteUsers
                .removeWhere((remote) => users.any((u) => u.id == remote.id));
          });

          if (_remoteUsers.isEmpty) {
            _setCallState(VideoCallState.ended);
            _showEndSnack(_callState == VideoCallState.connected
                ? 'Call Ended'
                : 'Call Declined');

            // Clear Ghost Call from DB
            final isInviter = widget.invitationData.inviter?.id ==
                context.read<ZegoAdapter>().getLocalUser().id;
            if (isInviter) {
              import_call_log_service.CallLogService()
                  .endCall(callId: widget.invitationData.callID);
            }

            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) Navigator.maybePop(context);
            });
          }
        }
      });
    }

    // Also listen for remote user list to get the remote user object
    context.read<ZegoAdapter>().getUserJoinStream().listen((users) {
      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
      final remoteJoined = users.where((u) => u.id != currentUserId).toList();
      if (remoteJoined.isNotEmpty && mounted) {
        setState(() => _remoteUsers = remoteJoined);
      }
    });
  }

  void _onConnected() {
    _dotsCtrl.stop();
    _ringingTimer?.cancel();
    _autoHangupTimer?.cancel();
    _stopRingback();
    CallOverlayManager().globalCallStartTime ??= DateTime.now();
    final startTime = CallOverlayManager().globalCallStartTime!;

    _callTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (mounted) {
        setState(
            () => _duration = DateTime.now().difference(startTime).inSeconds);
      }
    });

    CallForegroundService().startOngoingCallNotification(
      remoteName: _displayName,
      startTime: startTime,
      isVideo: true,
    );

    _startControlsTimer();
  }

  void _startControlsTimer() {
    _controlsHideTimer?.cancel();
    if (_callState == VideoCallState.connected) {
      _controlsHideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _controlsVisible = false);
      });
    }
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _startControlsTimer();
  }

  void _showEndSnack(String msg) {
    _stopRingback(); // Stop ringback when call ends

    CallOverlayManager().currentCallState.value = GlobalCallState.none;
    CallOverlayManager().globalCallStartTime = null;
    CallForegroundService().stopOngoingCallNotification();

    if (!mounted) return;

    // Release Zego resources
    try {
      if (mounted) {
        context.read<ZegoAdapter>().turnMicrophoneOn(false);
        context.read<ZegoAdapter>().turnCameraOn(false);
        context.read<ZegoAdapter>().leaveRoom();
      } else {
        ZegoUIKit().turnMicrophoneOn(false);
        ZegoUIKit().turnCameraOn(false);
        ZegoUIKit().leaveRoom();
      }
    } catch (_) {}

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red.shade800,
          duration: const Duration(seconds: 2)),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  void _minimizeToChat() {
    CallOverlayManager().show(
      context: context,
      remoteName: _displayName,
      isVideo: true,
      onTapRestore: () {
        // Restore: push video call back
        import_main.navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) =>
              VideoCallScreen(invitationData: widget.invitationData),
        ));
      },
    );
    _isMinimizing = true;
    Navigator.maybePop(context);
  }

  void _goToChat() {
    final authService = context.read<AuthService>();
    final currentUserId = authService.currentUser?.id;
    final isInviter = widget.invitationData.inviter?.id == currentUserId;
    final targetId = isInviter
        ? (widget.invitationData.invitees.isNotEmpty
            ? widget.invitationData.invitees.first.id
            : null)
        : widget.invitationData.inviter?.id;

    CallOverlayManager().show(
      context: context,
      remoteName: _displayName,
      remoteAvatarUrl: _remoteAvatarUrl,
      isVideo: true,
      onTapRestore: () {
        import_main.navigatorKey.currentState?.push(MaterialPageRoute(
          builder: (_) =>
              VideoCallScreen(invitationData: widget.invitationData),
        ));
      },
    );

    _isMinimizing = true;

    if (targetId != null) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => IndividualChatScreen(
              chatName: _displayName,
              otherUserId: targetId,
              avatarUrl: _remoteAvatarUrl,
            ),
          ));
    } else {
      Navigator.maybePop(context);
    }
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

  Future<void> _toggleScreenShare() async {
    if (_callState != VideoCallState.connected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Call is not connected. Let them connect first!'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    if (_isSharingScreen) {
      await context.read<ZegoAdapter>().stopSharingScreen();
      if (mounted) setState(() => _isSharingScreen = false);
    } else {
      await context.read<ZegoAdapter>().startSharingScreen();
      if (mounted) setState(() => _isSharingScreen = true);
    }
  }

  void _flipCamera() {
    setState(() => _isFrontCamera = !_isFrontCamera);
    context.read<ZegoAdapter>().useFrontFacingCamera(_isFrontCamera);
  }

  @override
  void dispose() {
    if (!_isMinimizing) {
      CallOverlayManager().hide();
      CallOverlayManager().currentCallState.value = GlobalCallState.none;
    }
    _callTimer?.cancel();
    _ringingTimer?.cancel();
    _autoHangupTimer?.cancel();
    _controlsHideTimer?.cancel();
    _userJoinSub?.cancel();
    _userLeaveSub?.cancel();
    _dotsCtrl.dispose();
    _stopRingback();
    _ringbackPlayer.dispose();
    if (_isSharingScreen) context.read<ZegoAdapter>().stopSharingScreen();
    CallOverlayManager().globalCallStartTime = null;
    CallForegroundService().stopOngoingCallNotification();
    import_call_log_service.CallLogService().refreshLogs();
    super.dispose();
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

  // ── CALLING / RINGING overlay (own camera full screen + overlay) ───────────
  Widget _buildPreConnectedView() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Own camera preview - full screen
        SizedBox.expand(
          child: ZegoAudioVideoView(
            user: context.read<ZegoAdapter>().getLocalUser(),
            avatarConfig: ZegoAvatarConfig(
              showInAudioMode: false,
              showSoundWavesInAudioMode: false,
              builder: (context, size, user, extraInfo) =>
                  const SizedBox.shrink(),
            ),
          ),
        ),
        // Dark gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.55),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.75),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── CONNECTED view (remote full screen + local PiP) ────────────────────────
  Widget _buildConnectedView() {
    final localUser = context.read<ZegoAdapter>().getLocalUser();

    return Stack(
      fit: StackFit.expand,
      children: [
        // Remote video — full screen or grid
        if (_remoteUsers.isEmpty)
          Container(color: Colors.black)
        else if (_remoteUsers.length == 1)
          SizedBox.expand(
            child: ZegoAudioVideoView(
              user: _remoteUsers.first,
              avatarConfig: ZegoAvatarConfig(
                showInAudioMode: false,
                showSoundWavesInAudioMode: false,
                builder: (context, size, user, extraInfo) =>
                    const SizedBox.shrink(),
              ),
            ),
          )
        else
          GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _remoteUsers.length == 2 ? 1 : 2,
              childAspectRatio: _remoteUsers.length == 2 ? 1.0 : 0.7,
            ),
            itemCount: _remoteUsers.length,
            itemBuilder: (ctx, i) => ZegoAudioVideoView(
              user: _remoteUsers[i],
              avatarConfig: ZegoAvatarConfig(
                showInAudioMode: false,
                showSoundWavesInAudioMode: false,
                builder: (context, size, user, extraInfo) =>
                    const SizedBox.shrink(),
              ),
            ),
          ),

        // Draggable local camera PiP
        _DraggablePip(localUserId: localUser.id),

        // ── Animated Pause Icon for Hold state ──
        if (context.watch<CallService>().isOnHold)
          Center(
            child: AnimatedOpacity(
              opacity: 1.0,
              duration: const Duration(milliseconds: 300),
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black54,
                ),
                child: const Center(
                  child: Icon(Icons.pause, color: Colors.white, size: 60),
                ),
              ),
            ),
          ),

        // Screen share indicator
        if (_isSharingScreen)
          Positioned(
            top: 90,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.red.shade800.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.screen_share,
                        color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    const Text('Sharing screen',
                        style: TextStyle(color: Colors.white, fontSize: 12)),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _toggleScreenShare,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Text('Stop',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return SafeArea(
      child: AnimatedOpacity(
        opacity: (_callState != VideoCallState.connected || _controlsVisible)
            ? 1.0
            : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Minimize / back
              GestureDetector(
                onTap: _minimizeToChat,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _callState == VideoCallState.connected
                        ? Icons.close_fullscreen
                        : Icons.close,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const Spacer(),
              // Name + timer
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_displayName,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w600,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8)
                          ])),
                  const SizedBox(height: 2),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _statusText,
                      key: ValueKey(_callState == VideoCallState.connected
                          ? _duration
                          : _callState),
                      style: TextStyle(
                        color: _callState == VideoCallState.connected
                            ? Colors.white70
                            : Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Right placeholder to keep name perfectly centered
              const SizedBox(width: 44),
            ],
          ),
        ),
      ),
    );
  }

  // ── Right Vertical Controls (WhatsApp Style) ──────────────────────────────
  Widget _buildRightControls() {
    return SafeArea(
      child: AnimatedOpacity(
        opacity: (_callState != VideoCallState.connected || _controlsVisible)
            ? 1.0
            : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Padding(
          padding: const EdgeInsets.only(top: 16, right: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Add Participant
              GestureDetector(
                onTap: _showAddParticipantSheet,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(
                      color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.person_add_alt_1,
                      color: Colors.white, size: 22),
                ),
              ),
              // Chat / Minimize
              GestureDetector(
                onTap: _goToChat,
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: const BoxDecoration(
                      color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.chat_bubble,
                      color: Colors.white, size: 20),
                ),
              ),
              // Flip Camera
              GestureDetector(
                onTap: _flipCamera,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: Colors.black45, shape: BoxShape.circle),
                  child: const Icon(Icons.flip_camera_ios,
                      color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return AnimatedOpacity(
      opacity: (_callState != VideoCallState.connected || _controlsVisible)
          ? 1.0
          : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black.withValues(alpha: 0.85), Colors.transparent],
            stops: const [0.0, 1.0],
          ),
        ),
        padding:
            const EdgeInsets.only(bottom: 40, left: 24, right: 24, top: 20),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularFAB(
                Icons.more_horiz,
                onTap: _showMoreSheet,
              ),
              _buildCircularFAB(
                _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                onTap: () {
                  setState(() => _isSpeakerOn = !_isSpeakerOn);
                  context
                      .read<ZegoAdapter>()
                      .setAudioOutputToSpeaker(_isSpeakerOn);
                },
                isActive: _isSpeakerOn,
              ),
              _buildCircularFAB(
                _isMicOn ? Icons.mic : Icons.mic_off,
                onTap: () {
                  setState(() => _isMicOn = !_isMicOn);
                  context.read<ZegoAdapter>().turnMicrophoneOn(_isMicOn);
                },
                isActive: !_isMicOn,
              ),
              _buildCircularFAB(
                _isCamOn ? Icons.videocam : Icons.videocam_off,
                onTap: () {
                  setState(() => _isCamOn = !_isCamOn);
                  context.read<ZegoAdapter>().turnCameraOn(_isCamOn);
                },
                isActive: !_isCamOn,
              ),
              _buildCircularFAB(
                Icons.call_end,
                onTap: () {
                  if (_isSharingScreen) {
                    context.read<ZegoAdapter>().stopSharingScreen();
                  }
                  context.read<ZegoAdapter>().turnCameraOn(false);
                  context.read<ZegoAdapter>().leaveRoom();

                  final isInviter = widget.invitationData.inviter?.id ==
                      context.read<ZegoAdapter>().getLocalUser().id;
                  if (isInviter) {
                    import_call_log_service.CallLogService()
                        .endCall(callId: widget.invitationData.callID);
                  }

                  Navigator.maybePop(context);
                },
                backgroundColor: Colors.red,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMoreSheet() {
    _showControls();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
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
              padding: EdgeInsets.all(14),
              child: Text('More Options',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold)),
            ),
            // Share Screen
            ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    _isSharingScreen ? Colors.red : Colors.orange.shade700,
                child: Icon(
                    _isSharingScreen
                        ? Icons.stop_screen_share
                        : Icons.screen_share,
                    color: Colors.white),
              ),
              title: Text(
                  _isSharingScreen ? 'Stop Sharing Screen' : 'Share Screen',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: Text(
                _isSharingScreen
                    ? 'Your screen is currently shared'
                    : 'Share your screen with the other person',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              trailing: _isSharingScreen
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade400),
                      ),
                      child: const Text('LIVE',
                          style: TextStyle(
                              color: Colors.red,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    )
                  : null,
              onTap: () {
                Navigator.pop(ctx);
                _toggleScreenShare();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ZegoScreenUtilInit(
        child: Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _callState == VideoCallState.connected ? _showControls : null,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── Background Video Layer ──
            if (_callState == VideoCallState.connected)
              _buildConnectedView()
            else
              _buildPreConnectedView(),

            // ── Top Bar ──
            Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),

            // ── Right Controls (WhatsApp Style) ──
            Positioned(top: 0, right: 0, child: _buildRightControls()),

            // ── Bottom Controls ──
            Positioned(bottom: 0, left: 0, right: 0, child: _buildControls()),
          ],
        ),
      ),
    ));
  }
}
