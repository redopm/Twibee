import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import 'qr_scanner_screen.dart';

class QRContactScreen extends StatelessWidget {
  const QRContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.lightGrey,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: Container(
              margin: const EdgeInsets.only(left: 4),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.orange, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('QR Code', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w700, fontSize: 17)),
          bottom: const TabBar(
            labelColor: AppColors.green,
            unselectedLabelColor: AppColors.grey,
            indicatorColor: AppColors.green,
            tabs: [
              Tab(text: 'My Code'),
              Tab(text: 'Scan Code'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyQRCodeTab(),
            _ScanQRCodeTab(), // Wrapper around QRScannerScreen
          ],
        ),
      ),
    );
  }
}

class _MyQRCodeTab extends StatelessWidget {
  const _MyQRCodeTab();

  @override
  Widget build(BuildContext context) {
    final chatService = context.watch<ChatService>();
    final userId = chatService.currentUserId;
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: chatService.getProfileStream(userId).first,
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final profile = snapshot.data!.first;
        final name = profile['name'] ?? 'Unknown User';
        final phone = profile['phone_number'] ?? '';
        final avatar = profile['avatar_url'];
        
        // Format: Twibee://user/UUID?name=Name&phone=Phone
        final qrData = 'Twibee://user/$userId?name=${Uri.encodeComponent(name)}&phone=${Uri.encodeComponent(phone)}';

        return Center(
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (avatar != null)
                  CircleAvatar(radius: 30, backgroundImage: NetworkImage(avatar))
                else
                  const CircleAvatar(radius: 30, backgroundColor: AppColors.green, child: Icon(Icons.person, color: Colors.white, size: 30)),
                const SizedBox(height: 16),
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.dark)),
                const SizedBox(height: 4),
                const Text('Twibee Contact', style: TextStyle(color: AppColors.grey)),
                const SizedBox(height: 24),
                QrImageView(
                  data: 'Twibee://add?user_id=$userId',
                  version: QrVersions.auto,
                  size: 250.0,
                  backgroundColor: AppColors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.orange),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.dark),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your QR code is private. If you share it with someone, they can scan it with their Twibee camera to add you as a contact.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScanQRCodeTab extends StatelessWidget {
  const _ScanQRCodeTab();

  @override
  Widget build(BuildContext context) {
    // We can just embed the scanner body here, or provide a button to open it full screen.
    // Given the design, it's easier to just show a button to launch the scanner, 
    // since the scanner screen manages the camera heavily and relies on its own full-screen Scaffold.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code_scanner, size: 100, color: AppColors.grey),
          const SizedBox(height: 24),
          const Text('Scan a Twibee QR code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark)),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Align the QR code within the frame to easily add a contact.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.grey),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QRScannerScreen()));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Open Scanner', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

