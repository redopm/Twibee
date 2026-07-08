import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/channel_service.dart';

class EditChannelTypeScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const EditChannelTypeScreen({super.key, required this.channel});

  @override
  State<EditChannelTypeScreen> createState() => _EditChannelTypeScreenState();
}

class _EditChannelTypeScreenState extends State<EditChannelTypeScreen> {
  final ChannelService _channelService = ChannelService();
  bool _isLoading = false;

  late bool _isPublic;
  late TextEditingController _usernameController;
  late bool _restrictSaving;

  @override
  void initState() {
    super.initState();
    _isPublic = widget.channel['is_public'] ?? false;
    _usernameController = TextEditingController(text: widget.channel['username'] ?? '');
    _restrictSaving = widget.channel['restrict_saving'] ?? false;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_isPublic && _usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Username is required for public channels')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _channelService.updateChannel(
        channelId: widget.channel['id'],
        isPublic: _isPublic,
        username: _isPublic ? _usernameController.text.trim() : null,
        restrictSaving: _restrictSaving,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel type updated!'), backgroundColor: Colors.green));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Channel Type',
        actions: [
          _isLoading
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: AppColors.orange, strokeWidth: 2))))
              : IconButton(icon: const Icon(Icons.check, color: AppColors.orange), onPressed: _saveChanges),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Channel Type', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 18)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                RadioListTile<bool>(
                  value: false,
                  groupValue: _isPublic,
                  activeColor: AppColors.orange,
                  title: const Text('Private Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Only people with an invite link can join.'),
                  onChanged: (val) => setState(() => _isPublic = val!),
                ),
                const Divider(height: 1),
                RadioListTile<bool>(
                  value: true,
                  groupValue: _isPublic,
                  activeColor: AppColors.orange,
                  title: const Text('Public Channel', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Anyone can find and join your channel.'),
                  onChanged: (val) => setState(() => _isPublic = val!),
                ),
              ],
            ),
          ),
          if (_isPublic) ...[
            const SizedBox(height: 24),
            const Text('Public Link', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 16)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                prefixText: 'Twibee.app/ ',
                prefixStyle: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold),
                hintText: 'username',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: AppColors.white,
              ),
            ),
          ],
          const SizedBox(height: 32),
          const Text('Security', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.dark, fontSize: 18)),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text('Restrict Saving Content', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Subscribers won\'t be able to copy, save, or forward content from this channel.'),
              value: _restrictSaving,
              activeThumbColor: AppColors.orange,
              onChanged: (val) => setState(() => _restrictSaving = val),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }
}

