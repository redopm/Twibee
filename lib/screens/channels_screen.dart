import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../theme.dart';
import '../services/channel_service.dart';
import 'create_channel_screen.dart';
import 'channel_chat_screen.dart';
import 'archived_channels_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/channel_preferences.dart';

class ChannelsScreen extends StatefulWidget {
  const ChannelsScreen({super.key});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen>
    with SingleTickerProviderStateMixin {
  final ChannelService _channelService = ChannelService();
  late TabController _tabController;

  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  List<Map<String, dynamic>> _myChannels = [];
  List<Map<String, dynamic>> _searchResults = [];

  List<String> _archivedChannels = [];
  List<String> _pinnedChannels = [];
  List<String> _mutedChannels = [];
  List<String> _readChannels = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPreferencesAndChannels();
  }

  Future<void> _loadPreferencesAndChannels() async {
    await _loadPreferences();
    await _fetchChannels();
  }

  Future<void> _loadPreferences() async {
    final archived = await ChannelPreferences.getArchivedChannels();
    final pinned = await ChannelPreferences.getPinnedChannels();
    final muted = await ChannelPreferences.getMutedChannels();
    final read = await ChannelPreferences.getReadChannels();
    if (mounted) {
      setState(() {
        _archivedChannels = archived;
        _pinnedChannels = pinned;
        _mutedChannels = muted;
        _readChannels = read;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchChannels() async {
    setState(() => _isLoading = true);
    try {
      final channels = await _channelService.getMyChannels();
      setState(() => _myChannels = channels);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading channels: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchChannels(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await _channelService.searchChannels(query);
      setState(() => _searchResults = results);
    } catch (e) {
      // silent
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black12,
        titleSpacing: 16,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search channels...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                ),
                style: const TextStyle(fontSize: 16),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _searchChannels(val);
                },
              )
            : const Text(
                'Channels',
                style: TextStyle(
                  color: AppColors.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: AppColors.dark,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _searchQuery = '';
                  _searchResults = [];
                }
              });
            },
          ),
          if (!_isSearching)
            GestureDetector(
              onTap: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateChannelScreen()),
                );
                if (created == true) _fetchChannels();
              },
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.orange, Color(0xFFFF9800)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
        ],
      ),
      body: _isSearching
          ? _buildSearchResults()
          : Column(
              children: [
                if (!_isSearching && _archivedChannels.isNotEmpty)
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: const Icon(Icons.archive, color: AppColors.grey),
                    title: const Text('Archived Channels',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Text(_archivedChannels.length.toString(),
                        style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.bold)),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ArchivedChannelsScreen()),
                      );
                      _loadPreferencesAndChannels();
                    },
                  ),
                Expanded(
                    child:
                        _isSearching ? const SizedBox() : _buildMyChannels()),
              ],
            ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchQuery.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: AppColors.grey2),
            SizedBox(height: 12),
            Text('Search globally for public channels',
                style: TextStyle(color: AppColors.grey2)),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text('No channels found for "$_searchQuery"',
            style: const TextStyle(color: AppColors.grey2)),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (ctx, i) => _buildChannelTile(_searchResults[i]),
    );
  }

  Widget _buildMyChannels() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.orange));
    }

    if (_myChannels.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.campaign_rounded, size: 80, color: AppColors.grey),
            const SizedBox(height: 16),
            const Text('No channels yet',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dark)),
            const SizedBox(height: 8),
            const Text('Create or find channels to follow',
                style: TextStyle(color: AppColors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Create Channel',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                final created = await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const CreateChannelScreen()),
                );
                if (created == true) _fetchChannels();
              },
            ),
          ],
        ),
      );
    }

    final visibleChannels =
        _myChannels.where((c) => !_archivedChannels.contains(c['id'])).toList();
    visibleChannels.sort((a, b) {
      final aPinned = _pinnedChannels.contains(a['id']);
      final bPinned = _pinnedChannels.contains(b['id']);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      return 0;
    });

    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _loadPreferencesAndChannels,
      child: visibleChannels.isEmpty
          ? const Center(
              child: Text('No visible channels. Check your archives!',
                  style: TextStyle(color: AppColors.grey2)))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: visibleChannels.length,
              itemBuilder: (ctx, i) => _buildChannelTile(visibleChannels[i]),
            ),
    );
  }

  Widget _buildChannelTile(Map<String, dynamic> channel) {
    final name = channel['name'] ?? 'Unknown';
    final description = channel['description'] ?? '';
    final avatarUrl = channel['avatar_url'];
    final subCount = channel['subscriber_count'] ?? 0;
    final createdAt = channel['created_at'] != null
        ? timeago.format(DateTime.parse(channel['created_at']))
        : '';

    final channelId = channel['id'];
    final isPinned = _pinnedChannels.contains(channelId);
    final isMuted = _mutedChannels.contains(channelId);
    final isRead = _readChannels.contains(channelId);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        clipBehavior: Clip.antiAlias,
        child: Slidable(
          key: ValueKey(channelId),
          startActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (_) async {
                  await ChannelPreferences.toggleRead(channelId);
                  _loadPreferences();
                },
                backgroundColor: AppColors.blue,
                foregroundColor: Colors.white,
                icon: isRead ? Icons.mark_chat_unread : Icons.mark_chat_read,
                label: isRead ? 'Unread' : 'Read',
              ),
              SlidableAction(
                onPressed: (_) async {
                  await ChannelPreferences.togglePin(channelId);
                  _loadPreferences();
                },
                backgroundColor: AppColors.orange,
                foregroundColor: Colors.white,
                icon: isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                label: isPinned ? 'Unpin' : 'Pin',
              ),
            ],
          ),
          endActionPane: ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (_) async {
                  await ChannelPreferences.toggleMute(channelId);
                  _loadPreferences();
                },
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                icon: isMuted
                    ? Icons.notifications_active
                    : Icons.notifications_off,
                label: isMuted ? 'Unmute' : 'Mute',
              ),
              SlidableAction(
                onPressed: (_) async {
                  await ChannelPreferences.toggleArchive(channelId);
                  _loadPreferences();
                },
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                icon: Icons.archive,
                label: 'Archive',
              ),
              SlidableAction(
                onPressed: (_) {
                  _channelService.leaveChannel(channelId);
                  _fetchChannels();
                },
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                icon: Icons.delete,
                label: 'Delete',
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            leading: Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: avatarUrl == null
                        ? LinearGradient(
                            colors: _nameToGradient(name),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    image: avatarUrl != null
                        ? DecorationImage(
                            image: NetworkImage(avatarUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: avatarUrl == null
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                        )
                      : null,
                ),
                if (isMuted)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                          color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.notifications_off,
                          size: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(name,
                      style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.normal : FontWeight.bold,
                          color: AppColors.dark)),
                ),
                if (isPinned)
                  const Icon(Icons.push_pin, size: 16, color: AppColors.grey2),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (description.isNotEmpty)
                  Text(description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.grey2, fontSize: 13)),
                Text('$subCount subscribers · $createdAt',
                    style:
                        const TextStyle(color: AppColors.grey2, fontSize: 12)),
              ],
            ),
            onTap: () async {
              if (!isRead) {
                await ChannelPreferences.toggleRead(
                    channelId); // Mark as read on tap
              }
              if (context.mounted) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChannelChatScreen(channel: channel),
                  ),
                );
              }
              _loadPreferencesAndChannels();
            },
          ), // ListTile
        ), // Slidable
      ), // ClipRRect
    ); // Container
  }

  /// Returns a consistent gradient pair based on the name string
  List<Color> _nameToGradient(String name) {
    const gradients = [
      [Color(0xFFFF6B00), Color(0xFFFF8C42)], // orange
      [Color(0xFF6C63FF), Color(0xFF9C8FFF)], // purple
      [Color(0xFF00B4D8), Color(0xFF48CAE4)], // teal
      [Color(0xFF2DC653), Color(0xFF51CF66)], // green
      [Color(0xFFE63946), Color(0xFFFF6B6B)], // red
      [Color(0xFFFFB703), Color(0xFFFFD166)], // yellow
      [Color(0xFF3A86FF), Color(0xFF74B3FF)], // blue
      [Color(0xFFE040FB), Color(0xFFEA80FC)], // pink
    ];
    final hash = name.isEmpty ? 0 : name.codeUnits.fold(0, (a, b) => a + b);
    final pair = gradients[hash % gradients.length];
    return [pair[0], pair[1]];
  }
}
