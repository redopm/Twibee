import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import '../services/channel_service.dart';
import 'individual_chat_screen.dart';

class ChannelDiscussionScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  const ChannelDiscussionScreen({super.key, required this.channel});

  @override
  State<ChannelDiscussionScreen> createState() => _ChannelDiscussionScreenState();
}

class _ChannelDiscussionScreenState extends State<ChannelDiscussionScreen> {
  bool _isLoading = false;
  late Map<String, dynamic> _channel;

  @override
  void initState() {
    super.initState();
    _channel = Map.from(widget.channel);
  }

  Future<void> _createAndLinkGroup() async {
    setState(() => _isLoading = true);
    try {
      final chatService = context.read<ChatService>();
      final channelService = context.read<ChannelService>();
      
      final groupId = await chatService.createGroup('${_channel['name']} Discussion', []);
      await channelService.updateChannelFields(_channel['id'], {'discussion_group_id': groupId});
      
      setState(() {
        _channel['discussion_group_id'] = groupId;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discussion group created and linked!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _unlinkGroup() async {
    setState(() => _isLoading = true);
    try {
      final channelService = context.read<ChannelService>();
      await channelService.updateChannelFields(_channel['id'], {'discussion_group_id': null});
      setState(() {
        _channel['discussion_group_id'] = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Discussion group unlinked.')));
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
    final hasGroup = _channel['discussion_group_id'] != null;

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Discussion'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(hasGroup ? Icons.forum : Icons.forum_outlined, size: 80, color: hasGroup ? AppColors.orange : AppColors.grey),
              const SizedBox(height: 16),
              Text(hasGroup ? 'Discussion Linked' : 'Link a Group', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                hasGroup 
                  ? 'Subscribers can now leave comments on posts.'
                  : 'Subscribers will see a "Leave a comment" button.', 
                textAlign: TextAlign.center, 
                style: const TextStyle(color: AppColors.grey2),
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator(color: AppColors.orange)
                  : Column(
                      children: [
                        if (hasGroup)
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => IndividualChatScreen(
                                    chatId: _channel['discussion_group_id'],
                                    chatName: '${_channel['name']} Discussion',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.chat),
                            label: const Text('Open Group', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              minimumSize: const Size(200, 48),
                            ),
                          ),
                        if (hasGroup) const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: hasGroup ? _unlinkGroup : _createAndLinkGroup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hasGroup ? Colors.red : AppColors.orange,
                            minimumSize: const Size(200, 48),
                          ),
                          child: Text(
                            hasGroup ? 'Unlink Group' : 'Create a New Group',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

