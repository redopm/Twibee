import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/bot_service.dart';

class BotSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> bot;
  const BotSettingsScreen({super.key, required this.bot});

  @override
  State<BotSettingsScreen> createState() => _BotSettingsScreenState();
}

class _BotSettingsScreenState extends State<BotSettingsScreen> {
  final BotService _botService = BotService();
  bool _isLoading = false;
  late bool _privacyMode;
  List<Map<String, dynamic>> _commands = [];

  @override
  void initState() {
    super.initState();
    _privacyMode = widget.bot['privacy_mode'] ?? true;
    _fetchCommands();
  }

  Future<void> _fetchCommands() async {
    try {
      final cmds = await _botService.getBotCommands(widget.bot['id']);
      if (mounted) setState(() => _commands = cmds);
    } catch (e) {
      debugPrint('Error fetching bot commands: $e');
    }
  }

  void _regenerateToken() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate Token?'),
        content: const Text(
          'Warning: Your old token will immediately stop working. Any external scripts using it will fail. This cannot be undone.',
          style: TextStyle(color: Colors.red),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                final token = await _botService.regenerateToken(widget.bot['id']);
                if (mounted) _showNewTokenDialog(token);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Regenerate', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNewTokenDialog(String token) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('New Token Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy it NOW. You will NOT be able to see it again.', style: TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[200],
              child: SelectableText(token, style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: token));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied!')));
            },
            child: const Text('Copy'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _deleteBot() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bot?'),
        content: const Text('This will delete the bot, revoke its token, and remove it from all groups. Message history remains intact. This cannot be undone.', style: TextStyle(color: Colors.red)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _botService.deleteBot(widget.bot['id']);
                if (mounted) Navigator.pop(context); // Go back to My Bots
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                setState(() => _isLoading = false);
              }
            },
            child: const Text('DELETE FOREVER', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _addCommand() {
    final cmdController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Command'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: cmdController, decoration: const InputDecoration(hintText: 'Command (e.g. start)')),
            const SizedBox(height: 16),
            TextField(controller: descController, decoration: const InputDecoration(hintText: 'Description')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (cmdController.text.isEmpty || descController.text.isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isLoading = true);
              try {
                await _botService.addBotCommand(widget.bot['id'], cmdController.text, descController.text);
                await _fetchCommands();
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _togglePrivacyMode(bool value) async {
    setState(() => _privacyMode = value);
    try {
      await _botService.updateBotDetails(widget.bot['id'], privacyMode: value);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      setState(() => _privacyMode = !value); // revert on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.bot['profiles'];

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6),
      appBar: TwibeeAppBar(
        title: profile['name'] ?? 'Bot Settings',
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : ListView(
              children: [
                // Header profile section
                Container(
                  color: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.lightGrey,
                        backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                        child: profile['avatar_url'] == null ? const Icon(Icons.smart_toy, size: 40, color: AppColors.grey) : null,
                      ),
                      const SizedBox(height: 16),
                      Text(profile['name'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('@${profile['username'] ?? ''}', style: const TextStyle(color: AppColors.grey)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Group Settings
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('GROUP SETTINGS', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Container(
                  color: AppColors.white,
                  child: SwitchListTile(
                    title: const Text('Group Privacy Mode'),
                    subtitle: const Text('When enabled, the bot only receives messages that start with "/" or @mention it. Disable to receive all group messages.', style: TextStyle(fontSize: 12)),
                    activeThumbColor: AppColors.orange,
                    value: _privacyMode,
                    onChanged: _togglePrivacyMode,
                  ),
                ),
                const SizedBox(height: 24),

                // Commands
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('COMMANDS', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                      GestureDetector(
                        onTap: _addCommand,
                        child: const Text('Add', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                Container(
                  color: AppColors.white,
                  child: _commands.isEmpty
                      ? const ListTile(title: Text('No commands added', style: TextStyle(color: AppColors.grey)))
                      : Column(
                          children: _commands.map((cmd) {
                            return ListTile(
                              title: Text('/${cmd['command']}'),
                              subtitle: Text(cmd['description']),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () async {
                                  setState(() => _isLoading = true);
                                  await _botService.deleteBotCommand(cmd['id']);
                                  await _fetchCommands();
                                  setState(() => _isLoading = false);
                                },
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const SizedBox(height: 24),

                // Danger Zone
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text('DANGER ZONE', style: TextStyle(color: AppColors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                Container(
                  color: AppColors.white,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.refresh, color: AppColors.orange),
                        title: const Text('Regenerate API Token', style: TextStyle(color: AppColors.orange)),
                        onTap: _regenerateToken,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.delete_forever, color: Colors.red),
                        title: const Text('Delete Bot', style: TextStyle(color: Colors.red)),
                        onTap: _deleteBot,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

