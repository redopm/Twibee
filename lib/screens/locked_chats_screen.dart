import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'individual_chat_screen.dart';

class LockedChatsScreen extends StatefulWidget {
  const LockedChatsScreen({super.key});

  @override
  State<LockedChatsScreen> createState() => _LockedChatsScreenState();
}

class _LockedChatsScreenState extends State<LockedChatsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticated = false;
  bool _isAuthenticating = true;

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      if (!canCheck) {
        // Fallback for devices without biometric support - in a real app, maybe ask for a custom PIN.
        // Here we just let them in if device has no secure lock at all, or we could block them.
        setState(() {
          _isAuthenticated = true;
          _isAuthenticating = false;
        });
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Unlock to view your locked chats',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: false),
      );

      if (mounted) {
        if (authenticated) {
          setState(() {
            _isAuthenticated = true;
            _isAuthenticating = false;
          });
        } else {
          Navigator.pop(context); // Auth failed or cancelled, go back
        }
      }
    } catch (e) {
      debugPrint('Biometric auth failed: $e');
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticating) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: const TwibeeAppBar(title: ''),
        body: const Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    if (!_isAuthenticated) {
      return const SizedBox.shrink(); // Should have popped
    }

    final chatService = context.watch<ChatService>();
    final lockedChats = chatService.lockedChatIds;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: const TwibeeAppBar(title: 'Locked chats', centerTitle: true),
      body: lockedChats.isEmpty
          ? const Center(
              child: Text(
                'No locked chats',
                style: TextStyle(color: AppColors.grey, fontSize: 16),
              ),
            )
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: chatService.getChatsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.orange));
                }
                
                final List<Map<String, dynamic>> allChats = List.from(snapshot.data ?? []);
                if (allChats.isEmpty) {
                  allChats.add({
                    'id': '22222222-2222-2222-2222-222222222222',
                    'is_group': false,
                    'last_message_at': DateTime.now().toIso8601String(),
                    'other_user': {
                      'name': 'Twibee Team',
                      'is_online': true,
                    },
                    'last_message': {
                      'content': 'Welcome to Twibee!',
                      'is_read': false,
                    }
                  });
                }

                final visibleLockedChats = allChats.where((c) => lockedChats.contains(c['id'])).toList();

                return ListView.builder(
                  itemCount: visibleLockedChats.length,
                  itemBuilder: (context, index) {
                    final chat = visibleLockedChats[index];
                    final isGroup = chat['is_group'] ?? false;
                    
                    String name = 'Unknown';
                    String avatarText = '?';
                    
                    if (isGroup) {
                      name = chat['group_name'] ?? 'Group Chat';
                      avatarText = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                    } else {
                      final otherUser = chat['other_user'];
                      if (otherUser != null) {
                        name = otherUser['name'] ?? 'Unknown';
                        avatarText = name.isNotEmpty ? name.characters.first.toUpperCase() : '?';
                      }
                    }

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.orange,
                        child: Text(
                          avatarText,
                          style: const TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      subtitle: const Text('Locked', style: TextStyle(color: AppColors.grey)),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IndividualChatScreen(
                              chatId: chat['id'],
                              chatName: name,
                            ),
                          ),
                        );
                      },
                      onLongPress: () {
                        _showUnlockMenu(context, chatService, chat['id'], name);
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  void _showUnlockMenu(BuildContext context, ChatService chatService, String chatId, String chatName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Text(chatName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              ListTile(
                leading: const Icon(Icons.lock_open), 
                title: const Text('Unlock chat'), 
                onTap: () async {
                  Navigator.pop(context);
                  await chatService.unlockChat(chatId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$chatName unlocked.')));
                  }
                }
              ),
            ],
          ),
        );
      },
    );
  }
}

