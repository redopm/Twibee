import 'package:flutter/material.dart';
import '../theme.dart';

class ChannelAdminLogsScreen extends StatelessWidget {
  final Map<String, dynamic> channel;
  const ChannelAdminLogsScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Recent Actions'),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: AppColors.grey),
            SizedBox(height: 16),
            Text('No Recent Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Admin actions in the last 48 hours will appear here.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey2)),
          ],
        ),
      ),
    );
  }
}

