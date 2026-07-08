import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';

import '../theme.dart';

class AdvancedImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String senderName;
  final String time;
  final List<dynamic>? groupItems;

  const AdvancedImageViewerScreen({
    super.key, 
    required this.imageUrl, 
    required this.senderName, 
    required this.time,
    this.groupItems,
  });

  @override
  State<AdvancedImageViewerScreen> createState() => _AdvancedImageViewerScreenState();
}

class _AdvancedImageViewerScreenState extends State<AdvancedImageViewerScreen> {
  final TextEditingController _replyController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // final isNetwork = widget.imageUrl.startsWith('http');
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
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
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.senderName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(widget.time, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.star_border, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.forward, color: Colors.white), onPressed: () {}),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) async {
              if (value == 'all_media') {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All media coming soon')));
              } else if (value == 'show_in_chat') {
                Navigator.pop(context); // Simple pop for now to return to chat
              } else if (value == 'save') {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saving...')));
                    bool hasAccess = await Gal.hasAccess();
                    if (!hasAccess) {
                        await Gal.requestAccess();
                    }
                    if (widget.imageUrl.startsWith('http')) {
                      var response = await Dio().get(widget.imageUrl, options: Options(responseType: ResponseType.bytes));
                      await Gal.putImageBytes(Uint8List.fromList(response.data));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
                    } else {
                      await Gal.putImage(widget.imageUrl);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image saved to gallery')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save image: ')));
                  }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all_media', child: Text('All media')),
              const PopupMenuItem(value: 'show_in_chat', child: Text('Show in chat')),
              const PopupMenuItem(value: 'save', child: Text('Save')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: widget.groupItems != null && widget.groupItems!.isNotEmpty 
                  ? PageView.builder(
                      itemCount: widget.groupItems!.length,
                      itemBuilder: (context, index) {
                         final item = widget.groupItems![widget.groupItems!.length - 1 - index];
                         final url = item['media_url'];
                         final isVideo = item['message_type'] == 'video';
                         final isLocal = !url.startsWith('http');
                         
                         if (isVideo) {
                            return Center(
                               child: Stack(
                                 alignment: Alignment.center,
                                 children: [
                                    isLocal 
                                      ? Image.file(File(url), fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.error, color: Colors.white)))
                                      : Image.network(url, fit: BoxFit.contain, errorBuilder: (c,e,s) => const Center(child: Icon(Icons.error, color: Colors.white))),
                                    const Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
                                 ]
                               )
                            );
                         }
                         return InteractiveViewer(
                           child: Center(
                             child: isLocal ? Image.file(File(url), fit: BoxFit.contain) : Image.network(url, fit: BoxFit.contain),
                           ),
                         );
                      },
                  )
                  : InteractiveViewer(
                child: Center(
                  child: !widget.imageUrl.startsWith('http') ? Image.file(File(widget.imageUrl), fit: BoxFit.contain) : Image.network(widget.imageUrl, fit: BoxFit.contain),
                ),
              ),
            ),
            // Bottom Reply Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.black.withValues(alpha: 0.8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: _replyController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Reply',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.emoji_emotions_outlined, color: Colors.white70),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      if (_replyController.text.isNotEmpty) {
                        Navigator.pop(context, _replyController.text);
                      }
                    },
                    child: const CircleAvatar(
                      backgroundColor: AppColors.orange,
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

