import 'package:flutter/material.dart';
import '../theme.dart';

class InviteFriendScreen extends StatelessWidget {
  const InviteFriendScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Invite a friend'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_alt_outlined, color: AppColors.orange, size: 60),
            ),
            const SizedBox(height: 24),
            const Text(
              'Invite your friends\nto Twibee',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.dark, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'Connect with your friends securely and privately. Share a link to invite them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.grey, fontSize: 16),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing link...')));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Share Invite Link', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

