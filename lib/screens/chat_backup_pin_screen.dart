import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/encryption_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../services/chat_service.dart'; // Just in case we need user id from here, or we can pass it

class ChatBackupPinScreen extends StatefulWidget {
  final bool isSettingUp; // true = new user setting up, false = restoring
  final String userId;
  final String? encryptedPrivateKeyBase64; // required if restoring
  final VoidCallback onSuccess;

  const ChatBackupPinScreen({
    super.key,
    required this.isSettingUp,
    required this.userId,
    this.encryptedPrivateKeyBase64,
    required this.onSuccess,
  });

  @override
  State<ChatBackupPinScreen> createState() => _ChatBackupPinScreenState();
}

class _ChatBackupPinScreenState extends State<ChatBackupPinScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _isLoading = false;
  bool _hasError = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    // A sine wave for shaking left and right
    _shakeAnimation = Tween<double>(begin: 0, end: 24).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reset();
          setState(() {
            _hasError = false;
            _pin = '';
            if (_isConfirming) _confirmPin = '';
          });
        }
      });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerError() {
    HapticFeedback.heavyImpact();
    setState(() => _hasError = true);
    _shakeController.forward();
  }

  void _onKeyPressed(String value) {
    if (_isLoading) return;
    HapticFeedback.lightImpact();

    setState(() {
      if (_pin.length < 6) {
        _pin += value;
        if (_pin.length == 6) {
          _processPin();
        }
      }
    });
  }

  void _onBackspace() {
    if (_isLoading || _pin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _processPin() async {
    if (widget.isSettingUp) {
      if (!_isConfirming) {
        // Move to confirm state
        setState(() {
          _confirmPin = _pin;
          _pin = '';
          _isConfirming = true;
        });
      } else {
        // Confirming
        if (_pin == _confirmPin) {
          _setupBackup();
        } else {
          _triggerError();
        }
      }
    } else {
      // Restoring
      _restoreBackup();
    }
  }

  Future<void> _setupBackup() async {
    setState(() => _isLoading = true);
    try {
      if (!await EncryptionService.hasPrivateKey()) {
        final pubKey = await EncryptionService.initKeys();
        await Supabase.instance.client.from('profiles').update({'public_key': pubKey}).eq('id', widget.userId);
      }

      final encryptedData = await EncryptionService.backupPrivateKey(_pin, widget.userId);
      if (encryptedData != null) {
        await Supabase.instance.client.from('profiles').update({'encrypted_private_key': encryptedData}).eq('id', widget.userId);
        widget.onSuccess();
      } else {
        _triggerError();
      }
    } catch (e) {
      _triggerError();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _isLoading = true);
    try {
      if (widget.encryptedPrivateKeyBase64 == null) {
        throw Exception("No backup data");
      }
      final success = await EncryptionService.restorePrivateKey(_pin, widget.userId, widget.encryptedPrivateKeyBase64!);
      if (success) {
        widget.onSuccess();
      } else {
        _triggerError();
      }
    } catch (e) {
      _triggerError();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.isSettingUp 
        ? (_isConfirming ? "Confirm your PIN" : "Create a 6-digit PIN")
        : "Enter your 6-digit PIN";
    String subtitle = widget.isSettingUp
        ? "This PIN will be used to encrypt and backup your chats securely."
        : "Restoring your secure chats";

    return Scaffold(
      backgroundColor: const Color(0xFF111827), // Dark aesthetic
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Icon(Icons.lock_outline, color: AppColors.orange, size: 48),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            const SizedBox(height: 48),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(sin(_shakeAnimation.value * pi) * 10, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(6, (index) {
                  bool isFilled = index < _pin.length;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _hasError
                          ? Colors.red
                          : (isFilled ? AppColors.orange : Colors.transparent),
                      border: Border.all(
                        color: _hasError ? Colors.red : (isFilled ? AppColors.orange : Colors.white38),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_isLoading) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppColors.orange),
            ],
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          _buildKeypadRow(['1', '2', '3']),
          const SizedBox(height: 20),
          _buildKeypadRow(['4', '5', '6']),
          const SizedBox(height: 20),
          _buildKeypadRow(['7', '8', '9']),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              const SizedBox(width: 70, height: 70), // Empty space
              _buildKeyButton('0'),
              SizedBox(
                width: 70,
                height: 70,
                child: IconButton(
                  onPressed: _onBackspace,
                  icon: const Icon(Icons.backspace_outlined, color: Colors.white, size: 28),
                  splashRadius: 35,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) => _buildKeyButton(key)).toList(),
    );
  }

  Widget _buildKeyButton(String text) {
    return InkWell(
      onTap: () => _onKeyPressed(text),
      borderRadius: BorderRadius.circular(35),
      splashColor: AppColors.orange.withValues(alpha: 0.3),
      child: Container(
        width: 70,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.05),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
