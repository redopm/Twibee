import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme.dart';
import '../services/channel_service.dart';

class ChannelInviteLinksScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const ChannelInviteLinksScreen({super.key, required this.channel});

  @override
  State<ChannelInviteLinksScreen> createState() => _ChannelInviteLinksScreenState();
}

class _ChannelInviteLinksScreenState extends State<ChannelInviteLinksScreen> {
  final ChannelService _channelService = ChannelService();
  List<Map<String, dynamic>> _links = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLinks();
  }

  Future<void> _fetchLinks() async {
    setState(() => _isLoading = true);
    try {
      final links = await _channelService.getInviteLinks(widget.channel['id']);
      if (mounted) setState(() => _links = links);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createLink() async {
    try {
      await _channelService.createInviteLink(widget.channel['id']);
      _fetchLinks();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _showLinkOptions(Map<String, dynamic> link) {
    final linkUrl = 'Twibee://channel/${link['link']}';
    final isRevoked = link['is_revoked'] == true;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy, color: AppColors.orange),
              title: const Text('Copy Link'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: linkUrl));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied to clipboard')));
              },
            ),
            if (!isRevoked)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Revoke Link', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await _channelService.revokeInviteLink(link['id']);
                    _fetchLinks();
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Invite Links'),
      body: Column(
        children: [
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.link),
              label: const Text('Create New Link'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _createLink,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                : _links.isEmpty
                    ? const Center(child: Text('No invite links yet', style: TextStyle(color: AppColors.grey2)))
                    : ListView.separated(
                        itemCount: _links.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final link = _links[i];
                          final isRevoked = link['is_revoked'] == true;
                          final usageCount = link['usage_count'] ?? 0;
                          final createdAt = link['created_at'] != null ? timeago.format(DateTime.parse(link['created_at'])) : '';

                          return ListTile(
                            tileColor: AppColors.white,
                            title: Text(
                              'Twibee://channel/${link['link']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isRevoked ? AppColors.grey2 : AppColors.dark,
                                decoration: isRevoked ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text('$usageCount joined · Created $createdAt', style: const TextStyle(color: AppColors.grey2)),
                            trailing: const Icon(Icons.more_vert, color: AppColors.grey),
                            onTap: () => _showLinkOptions(link),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

