import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/encryption_service.dart';
import 'chat_backup_pin_screen.dart';
import 'main_screen.dart';
import '../theme.dart';

class E2EERoutingWrapper extends StatefulWidget {
  const E2EERoutingWrapper({super.key});

  @override
  State<E2EERoutingWrapper> createState() => _E2EERoutingWrapperState();
}

class _E2EERoutingWrapperState extends State<E2EERoutingWrapper> {
  bool _isLoading = true;
  Widget? _nextScreen;

  @override
  void initState() {
    super.initState();
    _determineRoute();
  }

  Future<void> _determineRoute() async {
    try {
      final hasPrivateKey = await EncryptionService.hasPrivateKey();
      if (hasPrivateKey) {
        if (mounted) {
          setState(() {
            _nextScreen = const MainScreen();
            _isLoading = false;
          });
        }
        return;
      }

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No user');

      final profileData = await Supabase.instance.client
          .from('profiles')
          .select('encrypted_private_key')
          .eq('id', user.id)
          .maybeSingle();

      final encryptedKey = profileData?['encrypted_private_key'];

      if (mounted) {
        setState(() {
          if (encryptedKey != null && encryptedKey.toString().isNotEmpty) {
            // Returning user on new device (needs to restore)
            _nextScreen = ChatBackupPinScreen(
              isSettingUp: false,
              userId: user.id,
              encryptedPrivateKeyBase64: encryptedKey.toString(),
              onSuccess: () => _goToMain(),
            );
          } else {
            // Completely new user or no backup yet (needs to set up)
            _nextScreen = ChatBackupPinScreen(
              isSettingUp: true,
              userId: user.id,
              onSuccess: () => _goToMain(),
            );
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback
      if (mounted) {
        setState(() {
          _nextScreen = const MainScreen();
          _isLoading = false;
        });
      }
    }
  }

  void _goToMain() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.dark,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
      );
    }
    return _nextScreen ?? const MainScreen();
  }
}
