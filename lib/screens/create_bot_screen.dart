import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/bot_service.dart';

class CreateBotScreen extends StatefulWidget {
  const CreateBotScreen({super.key});

  @override
  State<CreateBotScreen> createState() => _CreateBotScreenState();
}

class _CreateBotScreenState extends State<CreateBotScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _shortDescController = TextEditingController();
  final _descController = TextEditingController();

  final BotService _botService = BotService();
  bool _isLoading = false;

  void _createBot() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await _botService.createBot(
        name: _nameController.text.trim(),
        username: _usernameController.text.trim().toLowerCase(),
        shortDescription: _shortDescController.text.trim(),
        description: _descController.text.trim(),
      );

      if (mounted) {
        _showTokenDialog(result['token']);
      }
    } catch (e) {
      print("BOT CREATE ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showTokenDialog(String token) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Bot Created Successfully! 🎉'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Here is your bot token. Copy it NOW. You will NOT be able to see it again.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
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
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token copied to clipboard!')));
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Close screen
            },
            child: const Text('I saved it, Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Create New Bot'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Bot Display Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Weather Bot',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 24),
                    
                    const Text('Username', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Must be unique. Example: weatherbot', style: TextStyle(fontSize: 12, color: AppColors.grey)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        prefixText: '@ ',
                        hintText: 'username',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (v!.isEmpty) return 'Username is required';
                        if (v.contains(' ')) return 'Username cannot contain spaces';
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    const Text('Short Description (About)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _shortDescController,
                      decoration: const InputDecoration(
                        hintText: 'A brief 1-line description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text('Full Description', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Text('Shown before someone starts the chat', style: TextStyle(fontSize: 12, color: AppColors.grey)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'What can this bot do?',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _createBot,
                        child: const Text('Create Bot', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}

