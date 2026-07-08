import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme.dart';

class MessageContextMenu extends StatefulWidget {
  final Widget messageWidget;
  final Rect childRect;
  final bool isMe;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onCopy;
  final VoidCallback? onInfo;
  final VoidCallback? onStar;
  final VoidCallback? onSave;
  final bool isSaved;
  final VoidCallback? onPin;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final Function(String) onReact;

  const MessageContextMenu({
    super.key,
    required this.messageWidget,
    required this.childRect,
    required this.isMe,
    this.onReply,
    this.onForward,
    this.onCopy,
    this.onInfo,
    this.onStar,
    this.onSave,
    this.isSaved = false,
    this.onPin,
    this.onDelete,
    this.onEdit,
    required this.onReact,
  });

  @override
  State<MessageContextMenu> createState() => _MessageContextMenuState();
}

class _MessageContextMenuState extends State<MessageContextMenu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() async {
    await _controller.reverse();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    const double menuWidth = 220;
    const double reactionPillHeight = 56.0;
    const double gap = 8.0;

    final double msgTop = widget.childRect.top;
    final double msgBottom = widget.childRect.bottom;
    final double msgLeft = widget.childRect.left;
    final double msgWidth = widget.childRect.width;

    // ── Positioning Logic ──────────────────────
    double reactionTop = msgTop - reactionPillHeight - gap;
    double menuTop = msgBottom + gap;

    if (reactionTop < 50) {
      // Message is too close to top → push BOTH below
      reactionTop = msgBottom + gap;
      menuTop = reactionTop + reactionPillHeight + gap;
    } else if (menuTop + 300 > screenSize.height) {
      // Message is too close to bottom → push BOTH above
      menuTop = msgTop - 300 - gap;
      reactionTop = menuTop - reactionPillHeight - gap;
      if (menuTop < 50) menuTop = 50;
      if (reactionTop < 50) reactionTop = 50;
    }

    double reactionLeft = widget.isMe ? msgLeft + msgWidth - 310 : msgLeft;
    if (reactionLeft < 10) reactionLeft = 10;
    if (reactionLeft + 310 > screenSize.width) reactionLeft = screenSize.width - 320;

    double menuLeft = widget.isMe
        ? msgLeft + msgWidth - menuWidth
        : msgLeft;
    if (menuLeft < 10) menuLeft = 10;
    if (menuLeft + menuWidth > screenSize.width) menuLeft = screenSize.width - menuWidth - 10;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Blur Background
          GestureDetector(
            onTap: _close,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, child) {
                return BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5 * value, sigmaY: 5 * value),
                  child: Container(color: Colors.white.withValues(alpha: 0.1 * value)),
                );
              },
            ),
          ),
          
          // Message Clone
          Positioned(
            top: msgTop,
            left: msgLeft,
            width: widget.childRect.width,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: widget.messageWidget,
            ),
          ),
          
          // Reaction Pill
          Positioned(
            top: reactionTop,
            left: reactionLeft,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 1)
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildReactionEmoji('👍'),
                    _buildReactionEmoji('❤️'),
                    _buildReactionEmoji('😂'),
                    _buildReactionEmoji('😮'),
                    _buildReactionEmoji('😢'),
                    _buildReactionEmoji('🙏'),
                    _buildReactionEmoji('🍯'),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        // More emojis logic
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.grey.shade200, shape: BoxShape.circle),
                        child: const Icon(Icons.add, size: 20, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Options Menu
          Positioned(
            top: menuTop,
            left: menuLeft,
            width: menuWidth,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, spreadRadius: 1)
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onReply != null) _buildMenuOption(Icons.reply, 'Reply', () { Navigator.pop(context); widget.onReply!(); }),
                    if (widget.onForward != null) _buildMenuOption(Icons.forward, 'Forward', () { Navigator.pop(context); widget.onForward!(); }),
                    if (widget.onCopy != null) _buildMenuOption(Icons.copy, 'Copy', () { Navigator.pop(context); widget.onCopy!(); }),
                    if (widget.onInfo != null) _buildMenuOption(Icons.info_outline, 'Info', () { Navigator.pop(context); widget.onInfo!(); }),
                    if (widget.isMe && widget.onEdit != null) _buildMenuOption(Icons.edit, 'Edit', () { Navigator.pop(context); widget.onEdit!(); }),
                    if (widget.onStar != null) _buildMenuOption(Icons.star_border, 'Star', () { Navigator.pop(context); widget.onStar!(); }),
                    if (widget.onSave != null) _buildMenuOption(widget.isSaved ? Icons.bookmark : Icons.bookmark_border, widget.isSaved ? 'Unsave' : 'Save', () { Navigator.pop(context); widget.onSave!(); }),
                    if (widget.onPin != null) _buildMenuOption(Icons.push_pin_outlined, 'Pin', () { Navigator.pop(context); widget.onPin!(); }),
                    if (widget.onDelete != null) _buildMenuOption(Icons.delete_outline, 'Delete', () { Navigator.pop(context); widget.onDelete!(); }, isDestructive: true),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactionEmoji(String emoji) {
    return GestureDetector(
      onTap: () {
        widget.onReact(emoji);
        Navigator.pop(context); // Instant pop to feel snappy and remove lag
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: 24, 
            color: emoji.contains('❤') ? Colors.red : null,
            fontFamilyFallback: const ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji']
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? Colors.red : AppColors.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(title, style: TextStyle(color: color, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

