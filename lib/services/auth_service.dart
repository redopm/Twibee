import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase;
import 'dart:async';
import 'encryption_service.dart';
import 'push_notification_service.dart';

class AuthService extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  AuthService() {
    _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      if (session != null) {
        // Encryption keys are now handled by E2EERoutingWrapper and ChatBackupPinScreen
      } else {
        // CallService.uninitUser();
      }
      notifyListeners();
    });
  }

  String? _verificationId;
  int? _resendToken;

  // Send OTP using Firebase
  Future<void> sendOtp(String phoneNumber) async {
    final completer = Completer<void>();

    await firebase.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (firebase.PhoneAuthCredential credential) async {
        try {
          final userCredential = await firebase.FirebaseAuth.instance
              .signInWithCredential(credential);
          final uid = userCredential.user?.uid;
          if (uid != null) {
            await _syncFirebaseWithSupabase(phoneNumber, uid);
          }
          if (!completer.isCompleted) {
            completer
                .complete(); // Auto-verified, proceed to next screen where it will auto-redirect
          }
        } catch (e) {
          debugPrint('Auto-verification failed: $e');
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        }
      },
      verificationFailed: (firebase.FirebaseAuthException e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        _resendToken = resendToken;
        if (!completer.isCompleted) {
          completer.complete(); // UI can now navigate to OTP screen
        }
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );

    return completer.future;
  }

  // Verify OTP using Firebase
  Future<void> verifyOtp(String phoneNumber, String otp) async {
    if (_verificationId == null) throw Exception('No verification ID found');
    try {
      final credential = firebase.PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: otp,
      );
      final userCredential =
          await firebase.FirebaseAuth.instance.signInWithCredential(credential);
      final uid = userCredential.user?.uid;

      if (uid != null) {
        await _syncFirebaseWithSupabase(phoneNumber, uid);
      } else {
        throw Exception('Firebase authentication failed');
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      rethrow;
    }
  }

  // Sync Firebase user with Supabase
  Future<void> _syncFirebaseWithSupabase(
      String phone, String firebaseUid) async {
    try {
      // 1. Try to login with the Firebase UID as the password
      await _supabase.auth.signInWithPassword(
        phone: phone,
        password: firebaseUid,
      );
    } on AuthException catch (e) {
      // 2. If login fails (Invalid credentials), it's likely a new user
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        try {
          await _supabase.auth.signUp(
            phone: phone,
            password: firebaseUid,
          );
        } on AuthException catch (signupError) {
          if (signupError.message
              .toLowerCase()
              .contains('user already registered')) {
            throw Exception(
                'Account exists without a password (legacy Twilio OTP). Please delete this test user from Supabase Dashboard and try again.');
          } else {
            rethrow;
          }
        }
      } else {
        rethrow;
      }
    }
  }

  // Sign out
  Future<void> signOut() async {
    await PushNotificationService().unregisterDeviceToken();
    await _supabase.auth.signOut();
  }
}
