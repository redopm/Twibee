import 'dart:async';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';

/// Adapter interface for ZegoUIKit methods to allow mocking in widget tests
abstract class ZegoAdapter {
  Future<void> init({required int appID, required String appSign, required ZegoScenario scenario});
  void login(String id, String name);
  Future<void> joinRoom(String roomID, {bool markAsLargeRoom = false});
  void leaveRoom();
  void turnMicrophoneOn(bool isOn);
  void turnCameraOn(bool isOn);
  void useFrontFacingCamera(bool isFrontFacing);
  void updateVideoViewMode(bool useVideoViewAspectFill);
  void setAudioOutputToSpeaker(bool isSpeaker);
  void setLowDataMode(bool isLowData);
  Future<void> startSharingScreen();
  Future<void> stopSharingScreen();
  
  List<ZegoUIKitUser> getRemoteUsers();
  ZegoUIKitUser getLocalUser();
  Stream<List<ZegoUIKitUser>> getUserJoinStream();
  Stream<List<ZegoUIKitUser>> getUserLeaveStream();

  void rejectInvitation();
  void cancelInvitation(List<ZegoCallUser> callees);
}

/// Real implementation of ZegoAdapter using ZegoUIKit
class ZegoAdapterImpl implements ZegoAdapter {
  @override
  Future<void> init({required int appID, required String appSign, required ZegoScenario scenario}) async {
    await ZegoUIKit().init(appID: appID, appSign: appSign, scenario: scenario);
  }

  @override
  void login(String id, String name) {
    ZegoUIKit().login(id, name);
  }

  @override
  Future<void> joinRoom(String roomID, {bool markAsLargeRoom = false}) async {
    await ZegoUIKit().joinRoom(roomID, markAsLargeRoom: markAsLargeRoom);
  }

  @override
  void leaveRoom() {
    ZegoUIKit().leaveRoom();
  }

  @override
  void turnMicrophoneOn(bool isOn) {
    ZegoUIKit().turnMicrophoneOn(isOn);
  }

  @override
  void turnCameraOn(bool isOn) {
    ZegoUIKit().turnCameraOn(isOn);
  }

  @override
  void useFrontFacingCamera(bool isFrontFacing) {
    ZegoUIKit().useFrontFacingCamera(isFrontFacing);
  }

  @override
  void updateVideoViewMode(bool useVideoViewAspectFill) {
    ZegoUIKit().updateVideoViewMode(useVideoViewAspectFill);
  }

  @override
  void setAudioOutputToSpeaker(bool isSpeaker) {
    ZegoUIKit().setAudioOutputToSpeaker(isSpeaker);
  }

  @override
  void setLowDataMode(bool isLowData) {
    if (isLowData) {
      ZegoUIKit().setVideoConfig(ZegoUIKitVideoConfig.preset360P());
    } else {
      ZegoUIKit().setVideoConfig(ZegoUIKitVideoConfig.preset720P());
    }
  }

  @override
  Future<void> startSharingScreen() async {
    await ZegoUIKit().startSharingScreen();
  }

  @override
  Future<void> stopSharingScreen() async {
    await ZegoUIKit().stopSharingScreen();
  }

  @override
  List<ZegoUIKitUser> getRemoteUsers() {
    return ZegoUIKit().getRemoteUsers();
  }

  @override
  ZegoUIKitUser getLocalUser() {
    return ZegoUIKit().getLocalUser();
  }

  @override
  Stream<List<ZegoUIKitUser>> getUserJoinStream() {
    return ZegoUIKit().getUserJoinStream();
  }

  @override
  Stream<List<ZegoUIKitUser>> getUserLeaveStream() {
    return ZegoUIKit().getUserLeaveStream();
  }

  @override
  void rejectInvitation() {
    try {
      ZegoUIKitPrebuiltCallInvitationService().reject();
    } catch (_) {}
  }

  @override
  void cancelInvitation(List<ZegoCallUser> callees) {
    try {
      ZegoUIKitPrebuiltCallInvitationService().cancel(callees: callees);
    } catch (_) {}
  }
}

