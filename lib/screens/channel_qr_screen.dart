import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../theme.dart';

class ChannelQrScreen extends StatelessWidget {
  final Map<String, dynamic> channel;

  const ChannelQrScreen({super.key, required this.channel});

  @override
  Widget build(BuildContext context) {
    // Generate a pseudo-link that points to this channel
    // In a real app, this would be a deep link (e.g. Twibee://channel/ID) or dynamic link
    final String channelLink = 'Twibee://channel/${channel['id']}';
    
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Channel QR Code'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.orange.withValues(alpha: 0.2),
                      backgroundImage: channel['avatar_url'] != null
                          ? NetworkImage(channel['avatar_url'])
                          : null,
                      child: channel['avatar_url'] == null
                          ? Text(
                              channel['name'][0].toUpperCase(),
                              style: const TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      channel['name'],
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.dark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (channel['username'] != null)
                      Text(
                        '@${channel['username']}',
                        style: const TextStyle(color: AppColors.grey, fontSize: 16),
                      ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: QrImageView(
                        data: channelLink,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.orange),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.dark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Share.share('Join my channel on Twibee: $channelLink');
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Share QR Code Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

