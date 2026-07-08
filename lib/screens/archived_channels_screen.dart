import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme.dart';
import '../services/channel_service.dart';
import '../services/channel_preferences.dart';
import 'channel_chat_screen.dart';

class ArchivedChannelsScreen extends StatefulWidget {
  const ArchivedChannelsScreen({super.key});

  @override
  State<ArchivedChannelsScreen> createState() => _ArchivedChannelsScreenState();
}

class _ArchivedChannelsScreenState extends State<ArchivedChannelsScreen> {
  final ChannelService _channelService = ChannelService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _myChannels = [];
  List<String> _archivedChannels = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final archived = await ChannelPreferences.getArchivedChannels();
      final channels = await _channelService.getMyChannels();
      
      if (mounted) {
        setState(() {
          _archivedChannels = archived;
          _myChannels = channels.where((c) => _archivedChannels.contains(c['id'])).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Archived Channels'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _myChannels.isEmpty
              ? const Center(child: Text('No archived channels.', style: TextStyle(color: AppColors.grey2)))
              : ListView.builder(
                  itemCount: _myChannels.length,
                  itemBuilder: (context, index) {
                    final channel = _myChannels[index];
                    final name = channel['name'] ?? 'Unknown';
                    final description = channel['description'] ?? '';
                    final avatarUrl = channel['avatar_url'];
                    final subCount = channel['subscriber_count'] ?? 0;
                    final createdAt = channel['created_at'] != null
                        ? timeago.format(DateTime.parse(channel['created_at']))
                        : '';
                    final channelId = channel['id'];

                    return Slidable(
                      key: ValueKey(channelId),
                      endActionPane: ActionPane(
                        motion: const ScrollMotion(),
                        children: [
                          SlidableAction(
                            onPressed: (_) async {
                              await ChannelPreferences.toggleArchive(channelId);
                              _loadData(); // refresh list
                            },
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            icon: Icons.unarchive,
                            label: 'Unarchive',
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                          backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                          child: avatarUrl == null
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'C',
                                  style: const TextStyle(
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20),
                                )
                              : null,
                        ),
                        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (description.isNotEmpty)
                              Text(description, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.grey2, fontSize: 13)),
                            Text('$subCount subscribers · $createdAt', style: const TextStyle(color: AppColors.grey2, fontSize: 12)),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChannelChatScreen(channel: channel),
                            ),
                          );
                          _loadData();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

