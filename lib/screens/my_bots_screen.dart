import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bot_service.dart';
import 'create_bot_screen.dart';
import 'bot_settings_screen.dart';

class MyBotsScreen extends StatefulWidget {
  const MyBotsScreen({super.key});

  @override
  State<MyBotsScreen> createState() => _MyBotsScreenState();
}

class _MyBotsScreenState extends State<MyBotsScreen> {
  final BotService _botService = BotService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _bots = [];

  @override
  void initState() {
    super.initState();
    _fetchBots();
  }

  Future<void> _fetchBots() async {
    setState(() => _isLoading = true);
    try {
      final bots = await _botService.getMyBots();
      setState(() => _bots = bots);
    } catch (e) {
      print("BOTS FETCH ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading bots: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'My Bots'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _bots.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _bots.length,
                  itemBuilder: (context, index) {
                    final bot = _bots[index];
                    final profile = bot['profiles'];
                    
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.lightGrey,
                        backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                        child: profile['avatar_url'] == null
                            ? const Icon(Icons.smart_toy, color: AppColors.grey)
                            : null,
                      ),
                      title: Text(profile['name'] ?? 'Unnamed Bot', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('@${profile['username'] ?? 'NoUsername'}', style: const TextStyle(color: AppColors.grey)),
                      trailing: const Icon(Icons.chevron_right, color: AppColors.grey),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => BotSettingsScreen(bot: bot)),
                        ).then((_) => _fetchBots());
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.orange,
        child: const Icon(Icons.add, color: AppColors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateBotScreen()),
          ).then((_) => _fetchBots());
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 80, color: AppColors.grey),
          const SizedBox(height: 16),
          const Text('No bots yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.dark)),
          const SizedBox(height: 8),
          const Text('Create your first bot and connect via API', style: TextStyle(color: AppColors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateBotScreen()),
              ).then((_) => _fetchBots());
            },
            child: const Text('Create Bot', style: TextStyle(color: AppColors.white)),
          )
        ],
      ),
    );
  }
}

