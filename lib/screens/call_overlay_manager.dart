import 'dart:async';
import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';

enum GlobalCallState { none, calling, ringing, connected, ended }

class CallOverlayManager {
  static final CallOverlayManager _instance = CallOverlayManager._();
  factory CallOverlayManager() => _instance;
  CallOverlayManager._();

  OverlayEntry? _overlayEntry;
  VoidCallback? _onTapRestore;
  DateTime? globalCallStartTime;
  
  final ValueNotifier<GlobalCallState> currentCallState = ValueNotifier(GlobalCallState.none);

  bool get isShowing => _overlayEntry != null;

  bool canStartNewCall(BuildContext context) {
    if (isShowing || currentCallState.value != GlobalCallState.none) {
      return false;
    }
    return true;
  }

  void show({
    required BuildContext context,
    required String remoteName,
    String? remoteAvatarUrl,
    required bool isVideo,
    required VoidCallback onTapRestore,
    DateTime? startTime,
  }) {
    hide();
    _onTapRestore = onTapRestore;
    _overlayEntry = OverlayEntry(builder: (_) => _MiniCallOverlay(
      remoteName: remoteName,
      remoteAvatarUrl: remoteAvatarUrl,
      isVideo: isVideo,
      startTime: startTime,
      onTap: () {
        hide();
        _onTapRestore?.call();
      },
      onEnd: () {
        hide();
        currentCallState.value = GlobalCallState.none;
        globalCallStartTime = null;
        ZegoUIKit().leaveRoom();
      },
    ));
    Overlay.of(context).insert(_overlayEntry!);
  }

  void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void restoreCallScreen() {
    if (isShowing) {
      hide();
      _onTapRestore?.call();
    }
  }
}

class _MiniCallOverlay extends StatefulWidget {
  final String remoteName;
  final String? remoteAvatarUrl;
  final bool isVideo;
  final DateTime? startTime;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  const _MiniCallOverlay({
    required this.remoteName,
    this.remoteAvatarUrl,
    required this.isVideo,
    this.startTime,
    required this.onTap,
    required this.onEnd,
  });

  @override
  State<_MiniCallOverlay> createState() => _MiniCallOverlayState();
}

class _MiniCallOverlayState extends State<_MiniCallOverlay> with SingleTickerProviderStateMixin {
  late Offset _position;
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  Timer? _timer;
  String _timerString = '00:00';
  bool _isInit = false;
  double _baseScale = 1.0;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _bounceAnim = CurvedAnimation(parent: _bounceCtrl, curve: Curves.elasticOut);
    _bounceCtrl.forward();

    // Force Zego video renderer to cover the entire box (no black bars)
    ZegoUIKit().updateVideoViewMode(true);

    if (widget.startTime != null) {
      _updateTimer();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      if (widget.isVideo) {
        _position = const Offset(16, 100);
      } else {
        // Place it just below the status bar so touches aren't intercepted by the OS notification shade
        double topPadding = MediaQuery.of(context).padding.top;
        _position = Offset(16, topPadding + 8);
      }
      _isInit = true;
    }
  }

  void _updateTimer() {
    if (widget.startTime == null) return;
    final diff = DateTime.now().difference(widget.startTime!);
    final m = diff.inMinutes.toString().padLeft(2, '0');
    final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
    if (mounted) setState(() => _timerString = '$m:$s');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bounceCtrl.dispose();
    super.dispose();
  }

  Widget _buildVoiceContent() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Avatar Placeholder
        CircleAvatar(
          radius: 32 * _currentScale,
          backgroundColor: Colors.white10,
          backgroundImage: widget.remoteAvatarUrl != null && widget.remoteAvatarUrl!.isNotEmpty ? NetworkImage(widget.remoteAvatarUrl!) : null,
          child: (widget.remoteAvatarUrl == null || widget.remoteAvatarUrl!.isEmpty) 
              ? Icon(Icons.person, color: Colors.white54, size: 40 * _currentScale) 
              : null,
        ),
        // Timer/Status at bottom
        Positioned(
          bottom: 12 * _currentScale,
          child: ValueListenableBuilder<GlobalCallState>(
            valueListenable: CallOverlayManager().currentCallState,
            builder: (context, callState, child) {
              String displayText = '';
              if (callState == GlobalCallState.calling) {
                displayText = 'Calling...';
              } else if (callState == GlobalCallState.ringing) displayText = 'Ringing...';
              else if (callState == GlobalCallState.connected) displayText = _timerString;
              else displayText = 'Ongoing...';

              return Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * _currentScale, vertical: 5 * _currentScale),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12 * _currentScale),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: Colors.greenAccent, size: 12 * _currentScale),
                    SizedBox(width: 4 * _currentScale),
                    Text(displayText, style: TextStyle(color: Colors.white, fontSize: 11 * _currentScale, fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVideoContent() {
    final localUser = ZegoUIKit().getLocalUser();
    final remoteUsers = ZegoUIKit().getRemoteUsers().where((u) => u.id != localUser.id).toList();
    final remoteUser = remoteUsers.isNotEmpty ? remoteUsers.first : null;

    return Stack(
      children: [
        // Main PiP Video (Remote User if connected, else Local User)
        ClipRRect(
          borderRadius: BorderRadius.circular(15 * _currentScale),
          child: Container(
            color: Colors.black87,
            child: remoteUser != null
                ? AbsorbPointer(child: ZegoAudioVideoView(user: remoteUser))
                : AbsorbPointer(child: ZegoAudioVideoView(user: localUser)), // Show local camera when ringing
          ),
        ),
        
        // Local User Video (Tiny inset) - Only show if connected and remote user is visible
        if (remoteUser != null)
          Positioned(
            right: 8 * _currentScale, bottom: 8 * _currentScale,
            child: Container(
              width: 32 * _currentScale, height: 44 * _currentScale,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6 * _currentScale),
                border: Border.all(color: Colors.white38, width: 0.5),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6 * _currentScale),
                child: AbsorbPointer(child: ZegoAudioVideoView(user: localUser)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onScaleStart: (details) {
          _baseScale = _currentScale;
        },
        onScaleUpdate: (details) {
          setState(() {
            _position += details.focalPointDelta;
            // Clamp scaling between 0.6 (small) and 2.5 (large)
            _currentScale = (_baseScale * details.scale).clamp(0.6, 2.5);
          });
        },
        onScaleEnd: (details) {
          // Auto full-screen snap if zoomed beyond a threshold (approx 50% of screen)
          if (_currentScale > 1.8) {
             widget.onTap(); // Restore call screen
          }
        },
        child: ScaleTransition(
          scale: _bounceAnim,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onTap,
              child: Container(
                width: 120 * _currentScale,
                height: 160 * _currentScale,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(16 * _currentScale),
                  border: Border.all(color: Colors.white24, width: 1.5 * _currentScale),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 16 * _currentScale, spreadRadius: 2 * _currentScale),
                  ],
                ),
                child: widget.isVideo ? _buildVideoContent() : _buildVoiceContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


