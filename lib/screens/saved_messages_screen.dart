import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';

class SavedMessagesScreen extends StatefulWidget {
  const SavedMessagesScreen({super.key});

  @override
  State<SavedMessagesScreen> createState() => _SavedMessagesScreenState();
}

class _SavedMessagesScreenState extends State<SavedMessagesScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allSaved = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();

  final _filters = ['All', 'Text', 'Photos', 'Videos', 'Docs', 'Links'];

  @override
  void initState() {
    super.initState();
    _fetchSavedMessages();
    _searchController.addListener(_applyFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSavedMessages() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final data = await _supabase
          .from('saved_messages')
          .select('''
            id,
            saved_at,
            messages (
              id,
              content,
              message_type,
              media_url,
              created_at,
              sender_id,
              is_deleted_for_everyone,
              profiles!messages_sender_id_fkey (name, avatar_url)
            )
          ''')
          .eq('user_id', userId)
          .order('saved_at', ascending: false);

      if (mounted) {
        final list = List<Map<String, dynamic>>.from(data);
        setState(() {
          _allSaved = list;
          _isLoading = false;
        });
        _applyFilter();
      }
    } catch (e) {
      debugPrint('Error fetching saved messages: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchController.text.trim().toLowerCase();
    
    // First, filter out soft-deleted messages globally
    List<Map<String, dynamic>> result = _allSaved.where((item) {
      final msg = item['messages'] as Map<String, dynamic>?;
      if (msg == null) return false;
      if (msg['is_deleted_for_everyone'] == true) return false;
      return true;
    }).toList();

    // Type filter
    if (_selectedFilter != 'All') {
      result = result.where((item) {
        final msg = item['messages'] as Map<String, dynamic>;
        final type = (msg['message_type'] ?? 'text') as String;
        final content = (msg['content'] ?? '') as String;
        switch (_selectedFilter) {
          case 'Text':
            return type == 'text';
          case 'Photos':
            return type == 'image';
          case 'Videos':
            return type == 'video';
          case 'Docs':
            return type == 'file' || type == 'document';
          case 'Links':
            return type == 'text' &&
                (content.contains('http://') || content.contains('https://'));
          default:
            return true;
        }
      }).toList();
    }

    // Search filter
    if (query.isNotEmpty) {
      result = result.where((item) {
        final msg = item['messages'] as Map<String, dynamic>;
        final content = (msg['content'] ?? '').toString().toLowerCase();
        final sender = (msg['profiles'] as Map<String, dynamic>?)?['name']
                ?.toString()
                .toLowerCase() ??
            '';
        return content.contains(query) || sender.contains(query);
      }).toList();
    }

    setState(() => _filtered = result);
  }

  Future<void> _unsaveMessage(String savedId, String messageId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from Saved'),
        content: const Text('Remove this message from your saved messages?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _supabase.from('saved_messages').delete().eq('id', savedId);
      setState(() {
        _allSaved.removeWhere((e) => e['id'] == savedId);
        _filtered.removeWhere((e) => e['id'] == savedId);
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Message removed from saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const TwibeeAppBar(title: 'Saved Messages'),
      body: Column(
        children: [
          // ── Search ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(22),
              ),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search saved messages...',
                  hintStyle: TextStyle(color: AppColors.grey),
                  prefixIcon: Icon(Icons.search, color: AppColors.grey, size: 20),
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // ── Filter Chips ──
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final f = _filters[i];
                final active = _selectedFilter == f;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedFilter = f);
                    _applyFilter();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? AppColors.orange : AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f,
                      style: TextStyle(
                        color: active ? AppColors.white : AppColors.dark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── Content ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                : _filtered.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppColors.orange,
                        onRefresh: _fetchSavedMessages,
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildSavedItem(_filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.bookmark_border,
                size: 44, color: AppColors.orange),
          ),
          const SizedBox(height: 16),
          const Text('No saved messages',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.dark)),
          const SizedBox(height: 8),
          const Text(
            'Long-press any message and tap\n"Save" to keep it here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedItem(Map<String, dynamic> item) {
    final savedId = item['id'] as String;
    final msg = item['messages'] as Map<String, dynamic>?;
    if (msg == null) return const SizedBox.shrink();

    final sender = (msg['profiles'] as Map<String, dynamic>?)?['name'] as String? ?? 'Unknown';
    final senderAvatar = (msg['profiles'] as Map<String, dynamic>?)?['avatar_url'] as String?;
    final content = (msg['content'] ?? '') as String;
    final type = (msg['message_type'] ?? 'text') as String;
    final savedAt = item['saved_at'] != null
        ? _formatDate(DateTime.parse(item['saved_at'].toString()).toLocal())
        : '';
    final messageId = msg['id'] as String;

    final icon = _iconForType(type, content);
    final displayText = _displayText(type, content);

    return GestureDetector(
      onLongPress: () => _unsaveMessage(savedId, messageId),
      child: Column(
        children: [
          ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.orange.withValues(alpha: 0.15),
              backgroundImage:
                  senderAvatar != null ? NetworkImage(senderAvatar) : null,
              child: senderAvatar == null
                  ? Icon(icon, color: AppColors.orange, size: 22)
                  : null,
            ),
            title: Text(displayText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.dark,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 13, color: AppColors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(sender,
                        style:
                            const TextStyle(color: AppColors.grey, fontSize: 12),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(savedAt,
                      style: const TextStyle(
                          color: AppColors.grey2, fontSize: 12)),
                ],
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.bookmark_remove_outlined,
                  color: AppColors.grey, size: 20),
              onPressed: () => _unsaveMessage(savedId, messageId),
              tooltip: 'Remove from saved',
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 80),
            child: Divider(height: 1, color: AppColors.lightGrey),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type, String content) {
    if (type == 'image') return Icons.image_outlined;
    if (type == 'video') return Icons.videocam_outlined;
    if (type == 'file' || type == 'document') return Icons.insert_drive_file_outlined;
    if (type == 'audio' || type == 'voice') return Icons.mic_outlined;
    if (content.contains('http://') || content.contains('https://')) {
      return Icons.link;
    }
    return Icons.chat_bubble_outline;
  }

  String _displayText(String type, String content) {
    if (type == 'image') return '📷 Photo';
    if (type == 'video') return '🎥 Video';
    if (type == 'file' || type == 'document') return '📄 Document';
    if (type == 'audio' || type == 'voice') return '🎤 Voice message';
    return content.isNotEmpty ? content : '[Message]';
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[dt.month - 1]} ${dt.day}';
  }
}

