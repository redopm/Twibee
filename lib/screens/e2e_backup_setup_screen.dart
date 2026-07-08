import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../theme.dart';

class E2EBackupSetupScreen extends StatefulWidget {
  const E2EBackupSetupScreen({super.key});

  @override
  State<E2EBackupSetupScreen> createState() => _E2EBackupSetupScreenState();
}

class _E2EBackupSetupScreenState extends State<E2EBackupSetupScreen> {
  final _storage = const FlutterSecureStorage();
  final _passwordController = TextEditingController();
  bool _isEncrypting = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingStatus();
  }

  Future<void> _checkExistingStatus() async {
    final pass = await _storage.read(key: 'e2e_backup_password');
    if (mounted) {
      setState(() {
        _isEncrypting = pass != null && pass.isNotEmpty;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleEncryption(bool value) async {
    if (!value) {
      // Turn off encryption
      await _storage.delete(key: 'e2e_backup_password');
      setState(() {
        _isEncrypting = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E2E Backup encryption disabled')));
      }
    } else {
      // Turn on encryption -> Show password dialog
      _showPasswordDialog();
    }
  }

  void _showPasswordDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set Encryption Password', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('This password will be used to encrypt your backup. If you forget it, you won\'t be able to restore your chats.', style: TextStyle(color: AppColors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Enter a strong password',
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.green)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _passwordController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
            ),
            TextButton(
              onPressed: () async {
                final pass = _passwordController.text.trim();
                if (pass.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
                  return;
                }
                
                await _storage.write(key: 'e2e_backup_password', value: pass);
                _passwordController.clear();
                if (mounted) {
                  setState(() {
                    _isEncrypting = true;
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('E2E Backup encryption enabled!')));
                }
              },
              child: const Text('Save', style: TextStyle(color: AppColors.green, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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
      appBar: const TwibeeAppBar(title: 'End-to-end encrypted backup'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: AppColors.green),
            const SizedBox(height: 16),
            const Text(
              'Use End-to-end encryption',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.dark),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your backup will be encrypted before it gets uploaded. This means nobody, not even Twibee or Supabase, can read your messages or media without your password.',
              style: TextStyle(color: AppColors.grey, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 32),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.green,
              title: const Text('Enable Encryption', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_isEncrypting ? 'On' : 'Off'),
              value: _isEncrypting,
              onChanged: _toggleEncryption,
            ),
          ],
        ),
      ),
    );
  }
}

