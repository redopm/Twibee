import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../theme.dart';
import '../services/chat_service.dart';

class TwoStepVerificationScreen extends StatefulWidget {
  const TwoStepVerificationScreen({super.key});

  @override
  State<TwoStepVerificationScreen> createState() => _TwoStepVerificationScreenState();
}

class _TwoStepVerificationScreenState extends State<TwoStepVerificationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isTwoStepEnabled = false;
  
  final _pinController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStatus();
  }

  Future<void> _fetchStatus() async {
    try {
      final supabase = context.read<ChatService>().supabaseClient;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await supabase
          .from('user_profiles')
          .select('two_step_pin, recovery_email')
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _isTwoStepEnabled = data['two_step_pin'] != null && data['two_step_pin'].toString().isNotEmpty;
          if (data['recovery_email'] != null) {
            _emailController.text = data['recovery_email'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disableTwoStep() async {
    setState(() => _isSaving = true);
    try {
      final supabase = context.read<ChatService>().supabaseClient;
      final userId = supabase.auth.currentUser?.id;
      
      await supabase.from('user_profiles').update({
        'two_step_pin': null,
        'recovery_email': null,
      }).eq('id', userId as Object);

      if (mounted) {
        setState(() {
          _isTwoStepEnabled = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Two-step verification disabled')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showSetupDialog() {
    String step = 'pin'; // 'pin' or 'email'
    String enteredPin = '';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(step == 'pin' ? 'Create a 6-digit PIN' : 'Add an email address', style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step == 'pin' 
                        ? 'This PIN will be asked when you register your phone number with Twibee again.'
                        : 'This email will be used to reset your PIN if you forget it.',
                    style: const TextStyle(color: AppColors.grey),
                  ),
                  const SizedBox(height: 16),
                  if (step == 'pin')
                    TextField(
                      controller: _pinController,
                      keyboardType: TextInputType.number,
                      obscureText: true,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        counterText: '',
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                      ),
                      onChanged: (val) {
                        if (val.length == 6) {
                          enteredPin = val;
                          setDialogState(() => step = 'email');
                        }
                      },
                    )
                  else
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Email address',
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    _pinController.clear();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
                ),
                if (step == 'email')
                  TextButton(
                    onPressed: () async {
                      final email = _emailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid email')));
                        return;
                      }

                      Navigator.pop(context);
                      await _saveTwoStep(enteredPin, email);
                    },
                    child: const Text('Save', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
                  ),
              ],
            );
          }
        );
      },
    );
  }

  Future<void> _saveTwoStep(String pin, String email) async {
    setState(() => _isSaving = true);
    try {
      final supabase = context.read<ChatService>().supabaseClient;
      final userId = supabase.auth.currentUser?.id;
      
      // Hash the PIN before storing it in DB (SHA-256 for simplicity here)
      final hashedPin = sha256.convert(utf8.encode(pin)).toString();

      await supabase.from('user_profiles').update({
        'two_step_pin': hashedPin,
        'recovery_email': email,
      }).eq('id', userId as Object);

      if (mounted) {
        setState(() {
          _isTwoStepEnabled = true;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Two-step verification enabled!')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.lightGrey,
        body: Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }
    
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Two-step verification'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Center(child: Icon(Icons.password, size: 80, color: AppColors.green)),
            const SizedBox(height: 24),
            Text(
              _isTwoStepEnabled 
                  ? 'Two-step verification is enabled. You\'ll need to enter your PIN when registering your phone number with Twibee again.'
                  : 'For extra security, turn on two-step verification, which will require a PIN when registering your phone number with Twibee again.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            if (!_isTwoStepEnabled)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
//                     backgroundColor: AppColors.green,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: _isSaving ? null : _showSetupDialog,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.white, strokeWidth: 2))
                      : const Text('Turn on', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              )
            else
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.cancel_outlined, color: AppColors.dark),
                    title: const Text('Turn off', style: TextStyle(color: AppColors.dark, fontSize: 16)),
                    onTap: _isSaving ? null : _disableTwoStep,
                  ),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined, color: AppColors.dark),
                    title: const Text('Change PIN', style: TextStyle(color: AppColors.dark, fontSize: 16)),
                    onTap: _isSaving ? null : _showSetupDialog,
                  ),
                  ListTile(
                    leading: const Icon(Icons.email_outlined, color: AppColors.dark),
                    title: const Text('Change email address', style: TextStyle(color: AppColors.dark, fontSize: 16)),
                    onTap: _isSaving ? null : () {
                      _pinController.text = '123456'; // mock existing pin flow for email change
                      _showSetupDialog();
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

