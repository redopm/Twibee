import 'dart:io';
import 'package:google_fonts/google_fonts.dart' hide Config;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../services/status_service.dart';
import '../services/chat_service.dart';
import 'contact_selection_screen.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'media_preview_edit_screen.dart';
import '../widgets/chat/video_thumbnail_widget.dart';
import 'status_viewer_screen.dart';

class OwnStatusViewerScreen extends StatefulWidget {
  const OwnStatusViewerScreen({super.key});

  @override
  State<OwnStatusViewerScreen> createState() => _OwnStatusViewerScreenState();
}

class _OwnStatusViewerScreenState extends State<OwnStatusViewerScreen> {
  bool _isEditing = false;
  final Set<String> _selectedStatuses = {};
  bool _isProcessing = false;

  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      _selectedStatuses.clear();
    });
  }
  
  void _toggleSelection(String statusId) {
    setState(() {
      if (_selectedStatuses.contains(statusId)) {
        _selectedStatuses.remove(statusId);
      } else {
        _selectedStatuses.add(statusId);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final statusService = context.read<StatusService>();
    for (String id in _selectedStatuses) {
      await statusService.deleteStatus(id);
    }
    if (mounted) {
      setState(() {
        _isEditing = false;
        _selectedStatuses.clear();
      });
    }
  }

  Future<void> _saveSelected(List<Map<String, dynamic>> statuses, {String? singleStatusId}) async {
    setState(() => _isProcessing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      bool savedAny = false;
      for (var status in statuses) {
        if ((singleStatusId != null && status['id'] == singleStatusId) || 
            (singleStatusId == null && _selectedStatuses.contains(status['id']))) {
          if (status['type'] != 'text') {
            String url = status['media_url'] ?? '';
            if (!url.startsWith('http') && url.isNotEmpty) {
              url = Supabase.instance.client.storage.from('chat_media').getPublicUrl(url);
            }
            if (url.isNotEmpty) {
              final savePath = '${tempDir.path}/status_${DateTime.now().millisecondsSinceEpoch}.${status['type'] == 'video' ? 'mp4' : 'jpg'}';
              await Dio().download(url, savePath);
              if (status['type'] == 'video') {
                await Gal.putVideo(savePath);
              } else {
                await Gal.putImage(savePath);
              }
              savedAny = true;
            }
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(savedAny ? 'Saved to Gallery!' : 'Text statuses cannot be saved to gallery.'))
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    }
    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (singleStatusId == null) {
          _isEditing = false;
          _selectedStatuses.clear();
        }
      });
    }
  }

  Future<void> _shareSelected(List<Map<String, dynamic>> statuses, {String? singleStatusId}) async {
    setState(() => _isProcessing = true);
    try {
      final tempDir = await getTemporaryDirectory();
      List<XFile> filesToShare = [];
      List<String> textsToShare = [];

      for (var status in statuses) {
        if ((singleStatusId != null && status['id'] == singleStatusId) || 
            (singleStatusId == null && _selectedStatuses.contains(status['id']))) {
          if (status['type'] != 'text') {
            String url = status['media_url'] ?? '';
            if (!url.startsWith('http') && url.isNotEmpty) {
              url = Supabase.instance.client.storage.from('chat_media').getPublicUrl(url);
            }
            if (url.isNotEmpty) {
              final savePath = '${tempDir.path}/status_${DateTime.now().millisecondsSinceEpoch}.${status['type'] == 'video' ? 'mp4' : 'jpg'}';
              await Dio().download(url, savePath);
              filesToShare.add(XFile(savePath));
            }
          } else {
            textsToShare.add(status['content'] ?? '');
          }
        }
      }
      
      if (filesToShare.isNotEmpty) {
        await Share.shareXFiles(filesToShare, text: textsToShare.isNotEmpty ? textsToShare.join('\n') : null);
      } else if (textsToShare.isNotEmpty) {
        await Share.share(textsToShare.join('\n'));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share: $e')));
    }
    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (singleStatusId == null) {
          _isEditing = false;
          _selectedStatuses.clear();
        }
      });
    }
  }

  Future<void> _forwardSelected(List<Map<String, dynamic>> statuses, {String? singleStatusId}) async {
    final selectedContactIds = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactSelectionScreen(
          title: 'Forward to',
          subtitle: 'Select contacts to forward to',
          initialSelectedIds: [],
        ),
      ),
    );

    if (selectedContactIds == null || selectedContactIds.isEmpty) return;
    
    setState(() => _isProcessing = true);
    try {
      final chatService = context.read<ChatService>();
      
      List<Map<String, dynamic>> itemsToForward = [];
      for (var status in statuses) {
        if ((singleStatusId != null && status['id'] == singleStatusId) || 
            (singleStatusId == null && _selectedStatuses.contains(status['id']))) {
          itemsToForward.add(status);
        }
      }

      for (String contactId in selectedContactIds) {
        final chatId = await chatService.createChat(contactId);
        
        for (var status in itemsToForward) {
          if (status['type'] == 'text') {
            await chatService.sendMessage(chatId: chatId, content: status['content'] ?? '');
          } else {
            String url = status['media_url'] ?? '';
            if (!url.startsWith('http') && url.isNotEmpty) {
              url = Supabase.instance.client.storage.from('chat_media').getPublicUrl(url);
            }
            if (url.isNotEmpty) {
              // we will send it as a regular message for now since sendMediaBatch requires local files
              // and downloading multiple files just to upload them again is redundant.
              // Actually, sendMediaBatch uses local paths. Let's just use chatService's message insert!
              await Supabase.instance.client.from('messages').insert({
                'chat_id': chatId,
                'sender_id': chatService.currentUserId,
                'content': status['content'] ?? '',
                'media_url': url,
                'media_type': status['type'] == 'video' ? 'video' : 'image',
              });
            }
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forwarded successfully!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to forward: $e')));
    }
    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (singleStatusId == null) {
          _isEditing = false;
          _selectedStatuses.clear();
        }
      });
    }
  }

  void _showCreateStatusOptions(BuildContext context) async {
    try {
      final assets = await AssetPicker.pickAssets(
        context,
        pickerConfig: const AssetPickerConfig(
          maxAssets: 30,
          requestType: RequestType.common,
          themeColor: AppColors.orange,
        ),
      );
      if (assets != null && assets.isNotEmpty && context.mounted) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => MediaPreviewEditScreen(
            initialAssets: assets, 
            isForStatus: true,
          )
        ));
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: context.read<StatusService>().getMyStatuses(),
      builder: (context, snapshot) {
        final statuses = snapshot.data ?? [];
        final hasStatuses = statuses.isNotEmpty;
        
        // Auto exit edit mode if no statuses left
        if (!hasStatuses && _isEditing) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isEditing = false;
                _selectedStatuses.clear();
              });
            }
          });
        }

        return Scaffold(
          backgroundColor: AppColors.lightGrey,
          appBar: TwibeeAppBar(
            title: 'My status',
            centerTitle: true,
            actions: [
              if (hasStatuses)
                TextButton(
                  onPressed: _toggleEditMode,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: _isEditing 
                      ? const Icon(Icons.check, color: AppColors.dark)
                      : const Text('Edit', style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              const SizedBox(width: 16),
            ],
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 16),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: snapshot.connectionState == ConnectionState.waiting
                        ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                        : SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Column(
                                    children: [
                                      if (statuses.isEmpty)
                                        const Padding(
                                          padding: EdgeInsets.all(24.0),
                                          child: Text('No statuses', style: TextStyle(color: AppColors.grey)),
                                        ),
                                      ...statuses.map((status) {
                                        final timeText = _formatTime(status['created_at']);
                                        final statusId = status['id'];
                                        
                                        return Column(
                                          children: [
                                            Material(
                                              color: Colors.transparent,
                                              child: ListTile(
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                                leading: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    if (_isEditing)
                                                      Padding(
                                                        padding: const EdgeInsets.only(right: 12.0),
                                                        child: GestureDetector(
                                                          onTap: () => _toggleSelection(statusId),
                                                          child: Container(
                                                            width: 24, height: 24,
                                                            decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              border: Border.all(color: _selectedStatuses.contains(statusId) ? AppColors.orange : Colors.grey, width: 2),
                                                              color: _selectedStatuses.contains(statusId) ? AppColors.orange : Colors.transparent,
                                                            ),
                                                            child: _selectedStatuses.contains(statusId) 
                                                                ? const Icon(Icons.check, size: 16, color: Colors.white)
                                                                : null,
                                                          ),
                                                        ),
                                                      ),
                                                    GestureDetector(
                                                      onTap: _isEditing ? null : () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => StatusViewerScreen(
                                                              userId: context.read<ChatService>().currentUserId,
                                                              name: 'My Status',
                                                              avatarText: 'M',
                                                              avatarColor: AppColors.orange,
                                                              statuses: statuses,
                                                              initialIndex: statuses.indexOf(status),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                      child: _buildThumbnail(status),
                                                    ),
                                                  ],
                                                ),
                                                title: FutureBuilder<List<Map<String, dynamic>>>(
                                                  future: context.read<StatusService>().getViewers(statusId),
                                                  builder: (context, snapshot) {
                                                    if (snapshot.connectionState == ConnectionState.waiting) {
                                                      return const Text('Loading...', style: TextStyle(color: AppColors.grey, fontSize: 14));
                                                    }
                                                    final views = snapshot.data?.length ?? 0;
                                                    if (views == 0) {
                                                      return const Text('No views yet', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600, fontSize: 16));
                                                    } else {
                                                      return Text('$views view${views > 1 ? 's' : ''}', style: const TextStyle(color: AppColors.dark, fontWeight: FontWeight.w600, fontSize: 16));
                                                    }
                                                  },
                                                ),
                                                subtitle: Text(timeText, style: const TextStyle(color: AppColors.grey)),
                                                trailing: _isEditing ? null : PopupMenuButton<String>(
                                                  icon: const Icon(Icons.more_horiz, color: AppColors.grey),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  onSelected: (value) async {
                                                    if (value == 'delete') {
                                                      await context.read<StatusService>().deleteStatus(statusId);
                                                      if (mounted) setState(() {});
                                                    } else if (value == 'share') {
                                                      await _shareSelected(statuses, singleStatusId: statusId);
                                                    } else if (value == 'save') {
                                                      await _saveSelected(statuses, singleStatusId: statusId);
                                                    } else if (value == 'forward') {
                                                      await _forwardSelected(statuses, singleStatusId: statusId);
                                                    }
                                                  },
                                                  itemBuilder: (context) => [
                                                    const PopupMenuItem(value: 'forward', child: ListTile(leading: Icon(Icons.turn_right), title: Text('Forward'), contentPadding: EdgeInsets.zero)),
                                                    const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.ios_share), title: Text('Share'), contentPadding: EdgeInsets.zero)),
                                                    const PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save_alt), title: Text('Save'), contentPadding: EdgeInsets.zero)),
                                                    const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)), contentPadding: EdgeInsets.zero)),
                                                  ],
                                                ),
                                                onTap: () {
                                                  if (_isEditing) {
                                                    _toggleSelection(statusId);
                                                  } else {
                                                    _showViewers(context, statusId);
                                                  }
                                                },
                                              ),
                                            ),
                                            const Divider(height: 1, indent: 76, color: AppColors.lightGrey),
                                          ],
                                        );
                                      }),
                                      
                                      // Add Status Row
                                      Material(
                                        color: Colors.transparent,
                                        child: ListTile(
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                          leading: Container(
                                            width: 50, height: 50,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade50,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.add, color: AppColors.orange, size: 28),
                                          ),
                                          title: const Text('Add status', style: TextStyle(color: AppColors.dark, fontSize: 16, fontWeight: FontWeight.w500)),
                                          onTap: () {
                                            _showCreateStatusOptions(context);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.lock, size: 12, color: AppColors.grey),
                                    const SizedBox(width: 6),
                                    RichText(
                                      text: const TextSpan(
                                        text: 'Your status updates are ',
                                        style: TextStyle(color: AppColors.grey, fontSize: 12),
                                        children: [
                                          TextSpan(text: 'end-to-end encrypted.', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                              ],
                            ),
                          ),
                    ),
                  ),
                  
                  if (_isEditing)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                      ),
                      child: SafeArea(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildBottomAction(Icons.turn_right, () => _forwardSelected(statuses)),
                            _buildBottomAction(Icons.ios_share, () => _shareSelected(statuses)),
                            _buildBottomAction(Icons.save_alt, () => _saveSelected(statuses)),
                            _buildBottomAction(Icons.delete_outline, _deleteSelected, isDestructive: true),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (_isProcessing)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator(color: AppColors.orange)),
                ),
            ],
          ),
        );
      }
    );
  }

  Widget _buildBottomAction(IconData icon, VoidCallback onTap, {bool isDestructive = false}) {
    final color = isDestructive ? Colors.red : AppColors.grey;
    final bool disabled = _selectedStatuses.isEmpty;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: disabled ? 0.0 : 0.05), blurRadius: 10)
          ]
        ),
        child: Icon(icon, color: disabled ? Colors.grey.shade300 : color),
      ),
    );
  }

  String _formatTime(String isoString) {
    DateTime date;
    try {
      // Parse the ISO string — Dart handles timezone offsets automatically
      date = DateTime.parse(isoString);
      // If timezone info present (Z or +offset), convert to local
      if (isoString.contains('+') || isoString.endsWith('Z')) {
        date = date.toLocal();
      }
      // OLD BUG: Some statuses were inserted as local IST time but stored as if UTC.
      // This makes them appear 5h30m in the future. Detect & correct:
      final now = DateTime.now();
      if (date.isAfter(now.add(const Duration(minutes: 2)))) {
        // Subtract the local UTC offset to undo the timezone misinterpretation
        date = date.subtract(now.timeZoneOffset);
      }
    } catch (e) {
      return 'Unknown';
    }

    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (now.day == date.day) return 'Today at ${DateFormat('hh:mm a').format(date)}';
    if (diff.inDays == 1) return 'Yesterday at ${DateFormat('hh:mm a').format(date)}';
    return DateFormat('MMM d, hh:mm a').format(date);
  }

  /// Parses a timestamp string and corrects for the known bug where local IST
  /// time was inserted as if it were UTC, making the timestamp 5h30m ahead.
  static DateTime _parseTimestamp(String isoString) {
    DateTime date;
    try {
      date = DateTime.parse(isoString);
      if (isoString.contains('+') || isoString.endsWith('Z')) {
        date = date.toLocal();
      }
      final now = DateTime.now();
      if (date.isAfter(now.add(const Duration(minutes: 2)))) {
        date = date.subtract(now.timeZoneOffset);
      }
    } catch (_) {
      date = DateTime.now();
    }
    return date;
  }

  Widget _buildThumbnail(Map<String, dynamic> status) {
    Widget content;
    if (status['type'] == 'text') {
      Color bg = AppColors.orange;
      if (status['bg_color'] != null) {
        try {
          bg = Color(int.parse(status['bg_color'].replaceFirst('#', '0xff')));
        } catch(e) {}
      }
      final fontStyle = status['font_style'] ?? 'Roboto';
      content = Container(
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
        child: Text(
          status['content'] != null ? (status['content'].length > 2 ? status['content'].substring(0, 2) : status['content']) : 'T', 
          style: GoogleFonts.getFont(fontStyle, color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
      } else {
        String url = status['media_url'] ?? '';
        if (!url.startsWith('http') && url.isNotEmpty) {
          url = Supabase.instance.client.storage.from('chat_media').getPublicUrl(url);
        }
        
        final isVideo = status['type'] == 'video';

        content = Container(
          color: AppColors.lightGrey,
          child: url.isNotEmpty
              ? (isVideo 
                  ? VideoThumbnailWidget(mediaUrl: url, chatService: context.read<ChatService>(), showPlayIcon: false)
                  : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, color: AppColors.grey)))
              : const Icon(Icons.image, color: AppColors.grey),
        );
      }

    return ClipOval(
      child: SizedBox(
        width: 50, height: 50,
        child: content,
      ),
    );
  }

  void _showViewers(BuildContext context, String statusId) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: context.read<StatusService>().getViewers(statusId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: AppColors.orange)));
            }
            final viewers = snapshot.data ?? [];
            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                  minHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        children: [
                          const Icon(Icons.visibility, color: AppColors.orange),
                          const SizedBox(width: 8),
                          Text('Viewed by ${viewers.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        ],
                      ),
                    ),
                    const Divider(),
                    if (viewers.isEmpty)
                      const Expanded(
                        child: Center(
                          child: Text('No views yet', style: TextStyle(color: AppColors.grey)),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: viewers.length,
                          itemBuilder: (context, index) {
                            final v = viewers[index];
                            final profile = v['profiles'] ?? {};
                            final viewedDate = _parseTimestamp(v['viewed_at']);
                            final time = DateFormat('hh:mm a').format(viewedDate);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.orange,
                                backgroundImage: profile['avatar_url'] != null ? NetworkImage(profile['avatar_url']) : null,
                                child: profile['avatar_url'] == null ? Text((profile['name'] ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white)) : null,
                              ),
                              title: Text(profile['name'] ?? 'Unknown'),
                              trailing: Text(time, style: const TextStyle(color: AppColors.grey)),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

