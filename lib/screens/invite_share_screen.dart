import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/chat_service.dart';
import '../../theme.dart';

class InviteShareScreen extends StatefulWidget {
  final String id;
  final bool isChannel;
  final bool isAdmin;
  final String name;

  const InviteShareScreen({
    super.key,
    required this.id,
    required this.isChannel,
    required this.isAdmin,
    required this.name,
  });

  @override
  State<InviteShareScreen> createState() => _InviteShareScreenState();
}

class _InviteShareScreenState extends State<InviteShareScreen> {
  String? _inviteLink;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLink();
  }

  Future<void> _fetchLink() async {
    setState(() => _isLoading = true);
    final link = await context.read<ChatService>().getInviteLink(widget.id, isChannel: widget.isChannel);
    if (mounted) {
      setState(() {
        _inviteLink = link;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateLink() async {
    setState(() => _isLoading = true);
    final link = await context.read<ChatService>().generateInviteLink(widget.id, isChannel: widget.isChannel);
    if (mounted) {
      setState(() {
        _inviteLink = link;
        _isLoading = false;
      });
    }
  }

  void _shareLink() {
    if (_inviteLink != null) {
      Share.share('Join my ${widget.isChannel ? 'channel' : 'group'} "${widget.name}" on Twibee!\n\nTap to join: $_inviteLink');
    }
  }

  void _copyLink() {
    if (_inviteLink != null) {
      Clipboard.setData(ClipboardData(text: _inviteLink!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TwibeeAppBar(title: 'Invite via Link'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'Scan QR Code',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  if (_inviteLink != null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          )
                        ],
                      ),
                      child: QrImageView(
                        data: _inviteLink!,
                        version: QrVersions.auto,
                        size: 200.0,
                        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppColors.orange),
                        dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppColors.dark),
                      ),
                    )
                  else
                    Container(
                      height: 200,
                      width: 200,
                      decoration: BoxDecoration(
                        color: AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'No link generated yet',
                          style: TextStyle(color: AppColors.grey),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  if (_inviteLink != null) ...[
                    Text(
                      _inviteLink!,
                      style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.lightGrey,
                            foregroundColor: AppColors.dark,
                          ),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _shareLink,
                          icon: const Icon(Icons.share),
                          label: const Text('Share Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.orange,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.isAdmin) ...[
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _generateLink,
                      icon: const Icon(Icons.refresh),
                      label: Text(_inviteLink == null ? 'Generate Link' : 'Reset Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Anyone with Twibee can follow this link to join. Resetting the link will make the old one invalid.',
                      style: TextStyle(fontSize: 12, color: AppColors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ] else if (_inviteLink == null) ...[
                    const Spacer(),
                    const Text(
                      'Ask an admin to generate an invite link for this group.',
                      style: TextStyle(color: AppColors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ]
                ],
              ),
            ),
    );
  }
}

