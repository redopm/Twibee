import 'dart:async';
import 'package:flutter/material.dart';

enum CallStatus { idle, connecting, ringing, active, onHold, ended }

class CallService extends ChangeNotifier with WidgetsBindingObserver {
  Timer? _resumeTimer;

  CallService() {
    WidgetsBinding.instance.addObserver(this);
  }
  // ── Call Metadata ──
  String callerName = '';
  String callerPhone = '';
  String? callerAvatarUrl;
  bool isVideo = false;
  bool isIncoming = false;

  // ── Call Controls State ──
  bool isMuted = false;
  bool isSpeakerOn = false;
  bool isOnHold = false;
  bool isVideoOff = false;
  bool isFrontCamera = true;

  // ── Call Duration ──
  Duration callDuration = Duration.zero;
  Timer? _timer;

  // ── Status ──
  CallStatus status = CallStatus.idle;

  // ─────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────

  /// Start an outgoing call
  void startOutgoingCall({
    required String name,
    required String phone,
    String? avatarUrl,
    bool video = false,
  }) {
    callerName = name;
    callerPhone = phone;
    callerAvatarUrl = avatarUrl;
    isVideo = video;
    isIncoming = false;
    status = CallStatus.connecting;
    isMuted = false;
    isSpeakerOn = false;
    isOnHold = false;
    isVideoOff = false;
    isFrontCamera = true;
    callDuration = Duration.zero;

    notifyListeners();

    // Simulate connecting → ringing → active (replace with ZegoCloud hooks)
    Future.delayed(const Duration(seconds: 1), () {
      status = CallStatus.ringing;
      notifyListeners();
    });
    Future.delayed(const Duration(seconds: 3), () {
      status = CallStatus.active;
      _startTimer();
      notifyListeners();
    });
  }

  /// Simulate an incoming call
  void simulateIncomingCall({
    required String name,
    required String phone,
    String? avatarUrl,
    bool video = false,
  }) {
    callerName = name;
    callerPhone = phone;
    callerAvatarUrl = avatarUrl;
    isVideo = video;
    isIncoming = true;
    status = CallStatus.ringing;
    callDuration = Duration.zero;
    notifyListeners();
  }

  /// User accepted an incoming call
  void acceptCall() {
    status = CallStatus.active;
    _startTimer();
    notifyListeners();
  }

  /// End the call
  void endCall() {
    _stopTimer();
    status = CallStatus.ended;
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 500), () {
      _resetState();
      notifyListeners();
    });
  }

  void toggleMute() {
    isMuted = !isMuted;
    notifyListeners();
  }

  void toggleSpeaker() {
    isSpeakerOn = !isSpeakerOn;
    notifyListeners();
  }

  void toggleHold() {
    isOnHold = !isOnHold;
    if (isOnHold) {
      _stopTimer();
    } else {
      _startTimer();
    }
    notifyListeners();
  }

  void toggleVideo() {
    isVideoOff = !isVideoOff;
    notifyListeners();
  }

  void switchCamera() {
    isFrontCamera = !isFrontCamera;
    notifyListeners();
  }

  String get formattedDuration {
    final m = callDuration.inMinutes.toString().padLeft(2, '0');
    final s = (callDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String get statusText {
    switch (status) {
      case CallStatus.connecting: return 'Calling...';
      case CallStatus.ringing: return 'Ringing...';
      case CallStatus.active: return formattedDuration;
      case CallStatus.onHold: return 'On hold';
      case CallStatus.ended: return 'Call ended';
      default: return '';
    }
  }

  // ─────────────────────────────────────────
  // Private helpers
  // ─────────────────────────────────────────

  void _startTimer() {
    _stopTimer();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      callDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _resetState() {
    callerName = '';
    callerPhone = '';
    callerAvatarUrl = null;
    isVideo = false;
    isIncoming = false;
    isMuted = false;
    isSpeakerOn = false;
    isOnHold = false;
    isVideoOff = false;
    isFrontCamera = true;
    callDuration = Duration.zero;
    status = CallStatus.idle;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resumeTimer?.cancel();
    _stopTimer();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _resumeTimer?.cancel();
      if (!isOnHold) {
        isOnHold = true;
        notifyListeners();
      }
    } else if (state == AppLifecycleState.resumed) {
      _resumeTimer?.cancel();
      _resumeTimer = Timer(const Duration(milliseconds: 1500), () {
        if (isOnHold) {
          isOnHold = false;
          notifyListeners();
        }
      });
    }
  }
}

