import 'dart:io';
import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/chat_service.dart';
import '../theme/theme.dart';
import 'share_contacts_screen.dart';
import 'media_links_docs_screen.dart';
import 'video_viewer_screen.dart';
import '../widgets/chat/video_thumbnail_widget.dart';

class MediaViewerScreen extends StatefulWidget {
  final String initialMediaUrl;
  final String initialMessageType;
  final String senderName;
  final String time;
  final String chatId;
  final String messageId;

  const MediaViewerScreen({
    super.key,
    required this.initialMediaUrl,
    this.initialMessageType = 'image',
    required this.senderName,
    required this.time,
    required this.chatId,
    required this.messageId,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  List<Map<String, dynamic>> _mediaList = [];
  PageController _pageController = PageController();
  int _currentIndex = 0;
  String _currentMessageId = '';
  bool _showEmojiPicker = false;
  bool _barsVisible = true;
  final Map<String, String> _urlCache = {};

  @override
  void initState() {
    super.initState();
    _currentMessageId = widget.messageId;
    _loadGallery();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    try {
      final media = await context.read<ChatService>().getChatMedia(widget.chatId);
      if (!mounted) return;
      final filtered = media
          .where((m) => m['message_type'] == 'image' || m['message_type'] == 'video')
          .toList();
      int idx = 0;
      for (int i = 0; i < filtered.length; i++) {
        if (filtered[i]['media_url'] == widget.initialMediaUrl ||
            filtered[i]['id']?.toString() == widget.messageId) {
          idx = i;
          break;
        }
      }
      if (mounted) {
        setState(() {
          _mediaList = filtered;
          _currentIndex = idx;
          if (filtered.isNotEmpty) {
            _currentMessageId = filtered[idx]['id']?.toString() ?? widget.messageId;
          }
        });
        _pageController = PageController(initialPage: idx);
        _cacheUrl(widget.initialMediaUrl);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mediaList = [
            {
              'media_url': widget.initialMediaUrl,
              'id': widget.messageId,
              'message_type': widget.initialMessageType,
            }
          ];
          _currentIndex = 0;
          _currentMessageId = widget.messageId;
        });
        _cacheUrl(widget.initialMediaUrl);
      }
    }
  }

  Future<void> _cacheUrl(String storagePath) async {
    if (_urlCache.containsKey(storagePath)) return;
    if (storagePath.startsWith('http')) {
      if (mounted) setState(() => _urlCache[storagePath] = storagePath);
      return;
    }
    final url = await context.read<ChatService>().getMediaSignedUrl(storagePath);
    if (url != null && mounted) setState(() => _urlCache[storagePath] = url);
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _currentMessageId = _mediaList[index]['id']?.toString() ?? widget.messageId;
      _showEmojiPicker = false;
    });
    _cacheUrl(_mediaList[index]['media_url'] as String);
    if (index + 1 < _mediaList.length) {
      _cacheUrl(_mediaList[index + 1]['media_url'] as String);
    }
  }

  void _toggleBars() => setState(() {
    _barsVisible = !_barsVisible;
    if (!_barsVisible) _showEmojiPicker = false;
  });

  String get _currentStoragePath =>
      _mediaList.isNotEmpty
          ? (_mediaList[_currentIndex]['media_url'] as String)
          : widget.initialMediaUrl;

  Widget _buildMediaPage(Map<String, dynamic> item) {
    final path = item['media_url'] as String;
    final isVideo = item['message_type'] == 'video';
    final cachedUrl = _urlCache[path];
    return GestureDetector(
      onTap: _toggleBars,
      child: Center(
        child: cachedUrl != null
            ? isVideo
                ? GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => VideoViewerScreen(videoUrl: cachedUrl, senderName: widget.senderName, time: widget.time)));
                    },
                    child: SizedBox(
                      width: double.infinity,
                      height: double.infinity,
                      child: VideoThumbnailWidget(mediaUrl: path, chatService: context.read<ChatService>()),
                    ),
                  )
                : InteractiveViewer(
                    child: cachedUrl.startsWith('http')
                        ? Image.network(cachedUrl, fit: BoxFit.contain)
                        : Image.file(File(cachedUrl), fit: BoxFit.contain),
                  )
            : Builder(builder: (ctx) {
                _cacheUrl(path);
                return const CircularProgressIndicator(color: Colors.white);
              }),
      ),
    );
  }

  Widget _buildTopBar() {
    return AnimatedOpacity(
      opacity: _barsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_barsVisible,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  ),
                ),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(widget.senderName,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(widget.time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  if (_mediaList.length > 1)
                    Text('${_currentIndex + 1} / ${_mediaList.length}',
                        style: const TextStyle(color: Colors.white54, fontSize: 11)),
                ]),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: Colors.grey[900],
                  onSelected: (val) {
                    if (val == 'gallery') {
                      Navigator.pushReplacement(context,
                          MaterialPageRoute(builder: (_) => MediaLinksDocsScreen(chatId: widget.chatId)));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                        value: 'gallery',
                        child: Text('View Gallery', style: TextStyle(color: Colors.white))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return AnimatedOpacity(
      opacity: _barsVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_barsVisible,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_showEmojiPicker)
            SizedBox(
              height: 260,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) async {
                  setState(() => _showEmojiPicker = false);
                  if (widget.chatId.isNotEmpty) {
                    await context.read<ChatService>().sendMessage(
                      chatId: widget.chatId,
                      messageType: 'text',
                      content: emoji.emoji,
                      replyToId: _currentMessageId,
                    );
                  }
                  if (mounted) Navigator.pop(context, 'replied');
                },
                config: const Config(
                  height: 260,
                  emojiViewConfig: EmojiViewConfig(columns: 7),
                  bottomActionBarConfig: BottomActionBarConfig(enabled: false),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _showEmojiPicker = !_showEmojiPicker),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_reaction_outlined, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('React', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context, 'reply'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                        color: AppColors.orange, borderRadius: BorderRadius.circular(20)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.reply, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Reply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          Container(
            color: Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      final url = _urlCache[_currentStoragePath] ?? _currentStoragePath;
                      if (url.startsWith('http')) {
                        Share.share(url);
                      } else {
                        Share.shareXFiles([XFile(url)]);
                      }
                    },
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.ios_share, color: Colors.white, size: 24),
                      SizedBox(height: 4),
                      Text('Share', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final contactData = await Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const ShareContactsScreen()));
                      if (contactData != null && mounted) {
                        context.read<ChatService>().sendMessage(
                          chatId: widget.chatId,
                          messageType: 'image',
                          mediaUrl: _currentStoragePath,
                          content: '',
                        );
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('Forwarded')));
                      }
                    },
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.shortcut, color: Colors.white, size: 24),
                      SizedBox(height: 4),
                      Text('Forward', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () {
                      context.read<ChatService>().starMessage(widget.messageId, true);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message starred')));
                    },
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.star_border, color: Colors.white, size: 24),
                      SizedBox(height: 4),
                      Text('Star', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    ]),
                  ),
                  GestureDetector(
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('Delete message?'),
                          actions: [
                            TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Delete',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        await context.read<ChatService>().deleteMessage(_currentMessageId);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                    child: const Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.delete_outline, color: Colors.red, size: 24),
                      SizedBox(height: 4),
                      Text('Delete', style: TextStyle(color: Colors.red, fontSize: 10)),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        if (_mediaList.isEmpty)
          GestureDetector(
            onTap: _toggleBars,
            child: Center(
              child: _urlCache[widget.initialMediaUrl] != null
                  ? widget.initialMessageType == 'video'
                      ? GestureDetector(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => VideoViewerScreen(videoUrl: _urlCache[widget.initialMediaUrl]!, senderName: widget.senderName, time: widget.time)));
                          },
                          child: SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: VideoThumbnailWidget(mediaUrl: widget.initialMediaUrl, chatService: context.read<ChatService>()),
                          ),
                        )
                      : InteractiveViewer(
                          child: widget.initialMediaUrl.startsWith('http')
                              ? Image.network(widget.initialMediaUrl, fit: BoxFit.contain)
                              : Image.file(File(widget.initialMediaUrl), fit: BoxFit.contain),
                        )
                  : const CircularProgressIndicator(color: Colors.white),
            ),
          )
        else
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _mediaList.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _buildMediaPage(_mediaList[index]),
          ),
        Positioned(top: 0, left: 0, right: 0, child: _buildTopBar()),
        Positioned(bottom: 0, left: 0, right: 0, child: _buildBottomControls()),
      ]),
    );
  }
}
