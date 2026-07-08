import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/auth_service.dart';
import 'profile_setup_screen.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phoneNumber;

  const OtpVerificationScreen({super.key, required this.phoneNumber});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  int _timerSeconds = 45;
  Timer? _timer;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // Listen for auto-verification success (Android auto-read)
    _authStateSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.session != null && mounted) {
        // User successfully signed in via auto-verification
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
          (route) => false,
        );
      }
    });
  }

  void _startTimer() {
    setState(() => _timerSeconds = 45);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  Future<void> _verifyOtp() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter all 6 digits')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthService>().verifyOtp(widget.phoneNumber, otp);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authStateSubscription?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    for (var f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.orange,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.white, size: 18),
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
        ),
        title: const Text(
          'OTP Verification',
          style: TextStyle(color: AppColors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Lock Icon
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.orangePale,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('🔐', style: TextStyle(fontSize: 32)),
              ),
            ),
            const SizedBox(height: 32),
            // Heading
            const Text(
              'Enter Verification Code',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            Text(
              'Code sent to ${widget.phoneNumber}',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.grey,
              ),
            ),
            const SizedBox(height: 40),
            // OTP Boxes
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) => _buildOtpBox(index)),
            ),
            const SizedBox(height: 32),
            // Resend Code
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Didn't receive code? ",
                  style: TextStyle(color: AppColors.grey, fontSize: 16),
                ),
                GestureDetector(
                  onTap: _timerSeconds == 0
                      ? () {
                          context
                              .read<AuthService>()
                              .sendOtp(widget.phoneNumber);
                          _startTimer();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('OTP Resent!')));
                        }
                      : null,
                  child: Text(
                    _timerSeconds > 0
                        ? 'Resend in 0:${_timerSeconds.toString().padLeft(2, '0')}'
                        : 'Resend Code',
                    style: TextStyle(
                      color:
                          _timerSeconds > 0 ? AppColors.orange : AppColors.dark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            // Verify Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: AppColors.white)
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Verify & Continue',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.white,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward,
                              color: AppColors.white, size: 20),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    return Container(
      width: 45,
      height: 55,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              _focusNodes[index].hasFocus ? AppColors.orange : AppColors.border,
          width: 1.5,
        ),
      ),
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppColors.dark,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          counterText: '', // Hide the max length counter
        ),
        onChanged: (value) {
          if (value.isNotEmpty && index < 5) {
            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
          } else if (value.isEmpty && index > 0) {
            FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
          }
          setState(() {}); // Rebuild for border color change
        },
      ),
    );
  }
}
