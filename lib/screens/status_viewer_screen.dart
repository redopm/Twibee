import 'dart:async';
import 'dart:ui';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../services/status_service.dart';
import '../services/chat_service.dart';
import '../theme.dart';
import '../widgets/status/status_video_widget.dart';
import 'forward_select_screen.dart';

class StatusViewerScreen extends StatefulWidget {
  final String userId;
  final String name;
  final String avatarText;
  final Color avatarColor;
  final String? avatarUrl;
  final List<Map<String, dynamic>> statuses;
  final int initialIndex;

  const StatusViewerScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.avatarText,
    required this.avatarColor,
    this.avatarUrl,
    required this.statuses,
    this.initialIndex = 0,
  });

  @override
  State<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends State<StatusViewerScreen> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late int _currentIndex;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _nextStatus();
      }
    });

    _replyFocusNode.addListener(() {
      if (_replyFocusNode.hasFocus) {
        _animationController.stop();
      } else {
        _animationController.forward();
      }
    });

    _animationController.forward();
    
    // Mark first as viewed
    if (widget.statuses.isNotEmpty) {
       _markViewed(0);
    }
  }

  void _markViewed(int index) {
    if (widget.statuses.isNotEmpty) {
      final status = widget.statuses[index];
      if (status['is_viewed'] != true) {
         final currentUserId = context.read<StatusService>().currentUserId;
         if (widget.userId != currentUserId) {
           context.read<StatusService>().markViewed(status['id']);
         }
         status['is_viewed'] = true;
      }
    }
  }

  void _nextStatus() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.forward(from: 0.0);
      _markViewed(_currentIndex);
    } else {
      Navigator.maybePop(context);
    }
  }

  void _previousStatus() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: GestureDetector(
          onTapUp: (details) {
            final screenWidth = MediaQuery.of(context).size.width;
            if (details.globalPosition.dx < screenWidth / 2) {
              _previousStatus();
            } else {
              _nextStatus();
            }
          },
          onLongPressStart: (_) {
            _animationController.stop();
          },
          onLongPressEnd: (_) {
            _animationController.forward();
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image/Text Viewer
              PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe to change, rely on taps
                itemCount: widget.statuses.length,
                itemBuilder: (context, index) {
                  final status = widget.statuses[index];
                  if (status['type'] == 'text') {
                    Color bg = Colors.black;
                    if (status['bg_color'] != null) {
                      try {
                        bg = Color(int.parse(status['bg_color'].replaceFirst('#', '0xff')));
                      } catch(e) {}
                    }
                    final fontStyle = status['font_style'] ?? 'Roboto';
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            bg,
                            bg.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        status['content'] ?? '',
                        style: GoogleFonts.getFont(
                          fontStyle,
                          color: Colors.white, 
                          fontSize: 38, 
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(0, 2))],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  } else {
                    String url = status['media_url'] ?? '';
                    if (!url.startsWith('http') && url.isNotEmpty) {
                      url = Supabase.instance.client.storage.from('chat_media').getPublicUrl(url);
                    }
                    if (url.isNotEmpty) {
                      if (status['type'] == 'video') {
                        return StatusVideoWidget(videoUrl: url);
                      } else {
                        return Image.network(url, fit: BoxFit.cover);
                      }
                    } else {
                      return Container(color: Colors.grey);
                    }
                  }
                },
              ),

              // Gradient Overlay for top and bottom
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withOpacity(0.5), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black.withValues(alpha: 0.5), Colors.transparent],
                    ),
                  ),
                ),
              ),

              // Top UI
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: Column(
                  children: [
                    // Progress Bars
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: List.generate(widget.statuses.length, (index) {
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  double progress = 0.0;
                                  if (index < _currentIndex) {
                                    progress = 1.0;
                                  } else if (index == _currentIndex) {
                                    progress = _animationController.value;
                                  }
                                  return _buildProgressBar(progress);
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // App Bar Info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: widget.avatarColor,
                            child: Text(widget.avatarText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                Text(
                                  widget.statuses.isNotEmpty && widget.statuses[_currentIndex]['created_at'] != null
                                    ? DateFormat('hh:mm a').format(DateTime.parse(widget.statuses[_currentIndex]['created_at']).toLocal())
                                    : 'Just now', 
                                  style: const TextStyle(color: Colors.white70, fontSize: 13)
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, color: Colors.white),
                            color: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            onSelected: (value) async {
                              final status = widget.statuses[_currentIndex];
                              if (value == 'forward') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForwardSelectScreen(
                                      message: {
                                        'id': status['id']?.toString(),
                                        'content': status['content']?.toString() ?? '',
                                        'message_type': status['type']?.toString() ?? 'image',
                                        'media_url': status['media_url']?.toString(),
                                      },
                                      currentChannelId: '', // Status doesn't have a chat ID
                                    ),
                                  ),
                                );
                              } else if (value == 'hide') {
                                await context.read<StatusService>().muteUser(widget.userId);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Status updates from ${widget.name} are hidden')),
                                  );
                                  Navigator.pop(context); // Exit viewer after hiding
                                }
                              } else if (value == 'report') {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${widget.name} has been reported')),
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'forward',
                                child: Row(
                                  children: [
                                    Icon(Icons.shortcut, color: Colors.black87, size: 20),
                                    SizedBox(width: 12),
                                    Text('Forward', style: TextStyle(color: Colors.black87)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'hide',
                                child: Row(
                                  children: [
                                    const Icon(Icons.visibility_off_outlined, color: Colors.black87, size: 20),
                                    const SizedBox(width: 12),
                                    Text('Hide ${widget.name}', style: const TextStyle(color: Colors.black87)),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(Icons.report_problem_outlined, color: Colors.red, size: 20),
                                    SizedBox(width: 12),
                                    Text('Report', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom UI (Reply)
              if (widget.userId != context.read<StatusService>().currentUserId)
                Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        _replyFocusNode.requestFocus();
                      },
                      child: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  focusNode: _replyFocusNode,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                  decoration: const InputDecoration(
                                    hintText: 'Reply',
                                    hintStyle: TextStyle(color: Colors.white70, fontSize: 16),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onSubmitted: (text) async {
                                    if (text.trim().isNotEmpty) {
                                      try {
                                        final status = widget.statuses[_currentIndex];
                                        await context.read<StatusService>().replyToStatus(status, text.trim());
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent!')));
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send reply.')));
                                        }
                                      }
                                      _replyController.clear();
                                      _replyFocusNode.unfocus();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(onTap: () => _sendReaction('😂'), child: const Text('😂', style: TextStyle(fontSize: 22))),
                              const SizedBox(width: 8),
                              GestureDetector(onTap: () => _sendReaction('😍'), child: const Text('😍', style: TextStyle(fontSize: 22))),
                              const SizedBox(width: 8),
                              GestureDetector(onTap: () => _sendReaction('😲'), child: const Text('😲', style: TextStyle(fontSize: 22))),
                              const SizedBox(width: 8),
                              GestureDetector(onTap: () => _sendReaction('😥'), child: const Text('😥', style: TextStyle(fontSize: 22))),
                              const SizedBox(width: 8),
                              GestureDetector(onTap: () => _sendReaction('🙏'), child: const Text('🙏', style: TextStyle(fontSize: 22))),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendReaction(String emoji) {
    if (widget.statuses.isNotEmpty) {
      final status = widget.statuses[_currentIndex];
      context.read<StatusService>().addReaction(status, emoji);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reacted $emoji'), duration: const Duration(seconds: 1)));
      _nextStatus();
    }
  }



  Widget _buildProgressBar(double progress) {
    return Container(
      height: 3,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(3),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.5),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

