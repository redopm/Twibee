import 'package:flutter/material.dart';
import '../../theme.dart';
import '../../services/chat_service.dart';
import 'package:provider/provider.dart';

class PrivacyChatLockScreen extends StatelessWidget {
  const PrivacyChatLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F2F2),
        elevation: 0,
        centerTitle: true,
        title: const Text('Chat lock', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.dark),
          onPressed: () => Navigator.maybePop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: AppColors.green),
              const SizedBox(height: 16),
              const Text(
                'Chat lock keeps your chats locked and hidden',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.dark),
              ),
              const SizedBox(height: 16),
              const Text(
                'If you have locked chats, pull down on your chat list or type your secret code in the search bar to find them.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.grey),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    // Logic to clear all locked chats
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Unlock and clear locked chats?'),
                        content: const Text('This will clear the secret code and also unlock and clear messages, photos and videos in locked chats.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear', style: TextStyle(color: AppColors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      context.read<ChatService>().clearAllLockedChats();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Locked chats cleared')));
                    }
                  },
                  child: const Text('Unlock and clear locked chats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'If you forgot your secret code, you can clear it. This will also unlock and clear messages, photos and videos in locked chats.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

