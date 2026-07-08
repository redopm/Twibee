import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/channel_service.dart';

class ChannelReactionsScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  const ChannelReactionsScreen({super.key, required this.channel});

  @override
  State<ChannelReactionsScreen> createState() => _ChannelReactionsScreenState();
}

class _ChannelReactionsScreenState extends State<ChannelReactionsScreen> {
  final ChannelService _channelService = ChannelService();
  bool _enableReactions = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _enableReactions = widget.channel['reactions_enabled'] ?? true;
  }

  Future<void> _updateReactions(bool val) async {
    setState(() {
      _enableReactions = val;
      _isLoading = true;
    });
    try {
      await _channelService.updateChannelFields(widget.channel['id'], {'reactions_enabled': val});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reactions setting updated')));
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() => _enableReactions = !val);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Reactions'),
      body: ListView(
        children: [
          Container(
            color: AppColors.white,
            child: SwitchListTile(
              title: const Text('Enable Reactions'),
              value: _enableReactions,
              activeThumbColor: AppColors.orange,
              onChanged: _isLoading ? null : _updateReactions,
              secondary: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.orange)) : null,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Subscribers will be able to react to messages in this channel.', style: TextStyle(color: AppColors.grey2)),
          ),
        ],
      ),
    );
  }
}

