import 'package:flutter/material.dart';
import '../theme.dart';
import '../services/bot_service.dart';
import 'individual_chat_screen.dart';

class BotsScreen extends StatefulWidget {
  const BotsScreen({super.key});

  @override
  State<BotsScreen> createState() => _BotsScreenState();
}

class _BotsScreenState extends State<BotsScreen> {
  final BotService _botService = BotService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _allBots = [];
  List<Map<String, dynamic>> _myBots = [];
  List<Map<String, dynamic>> _discoverBots = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchBots();
  }

  Future<void> _fetchBots() async {
    setState(() => _isLoading = true);
    try {
      final bots = await _botService.getAllBots();
      final currentUserId = _botService.currentUserId;
      
      final myBots = bots.where((b) => b['owner_id'] == currentUserId).toList();
      final discoverBots = bots.where((b) => b['owner_id'] != currentUserId).toList();

      if (mounted) {
        setState(() {
          _allBots = bots;
          _myBots = myBots;
          _discoverBots = discoverBots;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load bots: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToBotChat(Map<String, dynamic> bot) {
    final profile = bot['profiles'];
    if (profile == null) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => IndividualChatScreen(
          chatId: 'bot_${bot['id']}', // Temporary pseudo-ID, IndividualChatScreen handles it if it doesn't exist yet
          otherUserId: bot['id'],
          chatName: profile['name'] ?? 'Bot',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> displayMyBots = _myBots;
    List<Map<String, dynamic>> displayDiscover = _discoverBots;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      displayMyBots = _myBots.where((b) => (b['profiles']?['name'] ?? '').toString().toLowerCase().contains(q)).toList();
      displayDiscover = _discoverBots.where((b) => (b['profiles']?['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    }

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Bots'),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
        : RefreshIndicator(
            onRefresh: _fetchBots,
            color: AppColors.orange,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Search Box
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: const InputDecoration(
                        hintText: 'Search bots...',
                        hintStyle: TextStyle(color: AppColors.grey),
                        prefixIcon: Icon(Icons.search, color: AppColors.grey),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                
                // My Bots
                if (displayMyBots.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                    child: Text('MY BOTS', style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                  ...displayMyBots.map((bot) => _buildBotTile(bot)),
                  const Divider(color: AppColors.lightGrey, thickness: 8),
                ],
                
                // Discover Bots
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 16, bottom: 8),
                  child: Text('DISCOVER BOTS', style: TextStyle(color: AppColors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                
                if (displayDiscover.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: Text('No bots found.', style: TextStyle(color: AppColors.grey))),
                  )
                else
                  ...displayDiscover.map((bot) => _buildBotTile(bot)),
                  
                const SizedBox(height: 32),
              ],
            ),
          ),
    );
  }

  Widget _buildBotTile(Map<String, dynamic> bot) {
    final profile = bot['profiles'];
    if (profile == null) return const SizedBox.shrink();

    final name = profile['name'] ?? 'Unnamed Bot';
    final desc = profile['about'] ?? bot['short_description'] ?? '@${profile['username']}';
    final avatarUrl = profile['avatar_url'];

    return Column(
      children: [
        ListTile(
          onTap: () => _navigateToBotChat(bot),
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.lightGrey,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null ? const Icon(Icons.smart_toy, color: AppColors.grey) : null,
          ),
          title: Text(name, style: const TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.bold)),
          subtitle: Text(desc, style: const TextStyle(color: AppColors.grey, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: const Icon(Icons.chat_bubble_outline, color: AppColors.orange, size: 20),
        ),
        const Padding(padding: EdgeInsets.only(left: 88), child: Divider(height: 1, color: AppColors.lightGrey)),
      ],
    );
  }
}

