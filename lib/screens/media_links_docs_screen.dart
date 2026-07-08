import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme.dart';
import '../services/chat_service.dart';

class MediaLinksDocsScreen extends StatefulWidget {
  final String chatId;
  
  const MediaLinksDocsScreen({super.key, required this.chatId});

  @override
  State<MediaLinksDocsScreen> createState() => _MediaLinksDocsScreenState();
}

class _MediaLinksDocsScreenState extends State<MediaLinksDocsScreen> {
  final List<Map<String, dynamic>> _media = [];
  final List<Map<String, dynamic>> _links = [];
  final List<Map<String, dynamic>> _docs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final chatService = context.read<ChatService>();
    final messages = await chatService.getChatMedia(widget.chatId);
    
    // Process messages
    for (var msg in messages) {
      final type = msg['message_type'];
      final content = msg['content']?.toString() ?? '';
      
      if (type == 'image' || type == 'video') {
        _media.add(msg);
      } else if (type == 'document') {
        _docs.add(msg);
      } else {
        // Simple URL extraction logic
        if (content.contains('http://') || content.contains('https://') || content.contains('www.')) {
          _links.add(msg);
        }
      }
    }
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.white,
        appBar: AppBar(
          backgroundColor: AppColors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 52,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.orange, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          title: const TabBar(
            indicatorColor: AppColors.orange,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: AppColors.dark,
            unselectedLabelColor: AppColors.grey,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'Media'),
              Tab(text: 'Links'),
              Tab(text: 'Docs'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {},
              child: const Text('Select', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
            : TabBarView(
                children: [
                  _buildMediaTab(),
                  _buildLinksTab(),
                  _buildDocsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildMediaTab() {
    if (_media.isEmpty) {
      return _buildEmptyState('No media found');
    }
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: _media.length,
      itemBuilder: (context, index) {
        final item = _media[index];
        return Container(
          color: AppColors.lightGrey,
          child: item['media_url'] != null
              ? CachedNetworkImage(
                  imageUrl: item['media_url'], 
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: AppColors.lightGrey),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                )
              : const Icon(Icons.image, color: AppColors.grey),
        );
      },
    );
  }

  Widget _buildLinksTab() {
    if (_links.isEmpty) {
      return _buildEmptyState('No links found');
    }
    return ListView.builder(
      itemCount: _links.length,
      itemBuilder: (context, index) {
        final item = _links[index];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.lightGrey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.link, color: AppColors.grey),
          ),
          title: Text(item['content'], maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: const Text('Link', style: TextStyle(color: AppColors.grey)),
          onTap: () {},
        );
      },
    );
  }

  Widget _buildDocsTab() {
    if (_docs.isEmpty) {
      return _buildEmptyState('No documents found');
    }
    return ListView.builder(
      itemCount: _docs.length,
      itemBuilder: (context, index) {
        final item = _docs[index];
        return ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insert_drive_file, color: AppColors.orange),
          ),
          title: Text(item['content'] ?? 'Document', maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: const Text('Document', style: TextStyle(color: AppColors.grey)),
          onTap: () {},
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(color: AppColors.grey, fontSize: 16),
      ),
    );
  }
}

