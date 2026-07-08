import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import '../theme.dart';
import '../services/status_service.dart';
import 'status_viewer_screen.dart';
import 'own_status_viewer_screen.dart';
import 'text_status_screen.dart';
import 'media_preview_edit_screen.dart';
import 'status_privacy_screen.dart';
import '../widgets/status/status_ring_painter.dart';
import '../widgets/chat/video_thumbnail_widget.dart';
import '../services/chat_service.dart';

class StatusStoriesScreen extends StatefulWidget {
  const StatusStoriesScreen({super.key});

  @override
  State<StatusStoriesScreen> createState() => _StatusStoriesScreenState();
}

class _StatusStoriesScreenState extends State<StatusStoriesScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Stream<List<Map<String, dynamic>>>? _myStatusesStream;
  Stream<List<Map<String, dynamic>>>? _contactStatusesStream;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {});
    });
    final statusService = context.read<StatusService>();
    statusService.fetchMutes();
    _myStatusesStream = statusService.getMyStatuses();
    _contactStatusesStream = statusService.getContactStatusesGrouped();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search statuses...',
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.toLowerCase();
                  });
                },
              )
            : Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.orange, Color(0xFFFF8C42)],
                  ).createShader(bounds),
                  child: const Text(
                    'Status',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
        actions: [
          if (!_isSearching)
            IconButton(
              icon:
                  const Icon(Icons.camera_alt_outlined, color: AppColors.dark),
              onPressed: () => _showCreateStatusOptions(context),
            ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.orange),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const TextStatusScreen()));
              },
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search,
                color: AppColors.dark),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchController.clear();
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (!_isSearching)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.dark),
              color: AppColors.white,
              onSelected: (value) {
                if (value == 'privacy') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const StatusPrivacyScreen()));
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'privacy', child: Text('Status privacy')),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Status',
                    style: TextStyle(
                        color: AppColors.dark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            if (!_isSearching)
              StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _myStatusesStream,
                  builder: (context, snapshot) {
                    final myStatuses = snapshot.data ?? [];

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 8.0),
                      child: GridView(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.65,
                        ),
                        children: [
                          _buildMyStatusGridCard(context, myStatuses),
                        ],
                      ),
                    );
                  }),
            if (!_isSearching)
              const Divider(
                  color: AppColors.lightGrey, thickness: 1, indent: 70),
            StreamBuilder<List<Map<String, dynamic>>>(
                stream: _contactStatusesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.orange)),
                    );
                  }

                  var groups = snapshot.data ?? [];

                  if (_isSearching && _searchQuery.isNotEmpty) {
                    groups = groups.where((g) {
                      final name = (g['profile']['name'] ?? 'Unknown')
                          .toString()
                          .toLowerCase();
                      return name.contains(_searchQuery);
                    }).toList();
                  }

                  final statusService = context.watch<StatusService>();
                  final recentUpdates = groups
                      .where((g) =>
                          !g['all_viewed'] &&
                          !statusService.isMuted(g['user_id']))
                      .toList();
                  final viewedUpdates = groups
                      .where((g) =>
                          g['all_viewed'] &&
                          !statusService.isMuted(g['user_id']))
                      .toList();
                  final mutedUpdates = groups
                      .where((g) => statusService.isMuted(g['user_id']))
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (recentUpdates.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text('Recent updates',
                              style: TextStyle(
                                  color: AppColors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                        _buildStatusGrid(context, recentUpdates),
                      ],
                      if (viewedUpdates.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 8.0),
                          child: Text('Viewed updates',
                              style: TextStyle(
                                  color: AppColors.grey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                        ),
                        _buildStatusGrid(context, viewedUpdates),
                      ],
                      if (mutedUpdates.isNotEmpty) ...[
                        Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            title: const Text('Muted updates',
                                style: TextStyle(
                                    color: AppColors.grey,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            children: [
                              _buildStatusGrid(context, mutedUpdates,
                                  isMuted: true),
                            ],
                          ),
                        ),
                      ],
                      if (groups.isEmpty && _isSearching)
                        const Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Center(
                              child: Text('No results found.',
                                  style: TextStyle(color: AppColors.grey))),
                        ),
                      const SizedBox(height: 80),
                    ],
                  );
                }),
          ],
        ),
      ),
    );
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
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MediaPreviewEditScreen(
                      initialAssets: assets,
                      isForStatus: true,
                    )));
      }
    } catch (e) {
      // ignore
    }
  }

  Widget _buildStatusGrid(BuildContext context, List<dynamic> groups,
      {bool isMuted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.65, // Rectangular card ratio
        ),
        itemCount: groups.length,
        itemBuilder: (context, index) =>
            _buildStatusGridCard(context, groups[index], isMuted: isMuted),
      ),
    );
  }

  Widget _buildStatusGridCard(BuildContext context, Map<String, dynamic> group,
      {bool isMuted = false}) {
    final profile = group['profile'];
    final name = profile['name'] ?? 'Unknown';
    final avatarUrl = profile['avatar_url'];
    final statuses = group['statuses'] as List;
    final viewedCount = statuses.where((s) => s['is_viewed'] == true).length;
    final totalCount = statuses.length;

    // Get latest status for background
    final latestStatus = statuses.last;
    final isText = latestStatus['type'] == 'text';

    Widget background;
    if (isText) {
      Color bgColor = AppColors.orange;
      if (latestStatus['bg_color'] != null) {
        try {
          bgColor = Color(
              int.parse(latestStatus['bg_color'].replaceFirst('#', '0xFF')));
        } catch (_) {}
      }
      final fontStyle = latestStatus['font_style'] ?? 'Roboto';
      background = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgColor,
              bgColor.withValues(alpha: 0.7),
            ],
          ),
        ),
        padding: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Text(
          latestStatus['content'] ?? '',
          style: TextStyle(
              fontFamily: fontStyle,
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
      );
    } else {
      String url = latestStatus['media_url'] ?? '';
      if (!url.startsWith('http') && url.isNotEmpty) {
        url = Supabase.instance.client.storage
            .from('chat_media')
            .getPublicUrl(url);
      }
      if (url.isNotEmpty) {
        if (latestStatus['type'] == 'video') {
          background = SizedBox.expand(
              child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: VideoThumbnailWidget(
                        mediaUrl: url,
                        chatService: context.read<ChatService>()),
                  )));
        } else {
          background = Image.network(url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                  color: AppColors.grey,
                  child: const Icon(Icons.image_not_supported,
                      color: Colors.white54)));
        }
      } else {
        background = Container(color: AppColors.grey);
      }
    }

    return GestureDetector(
      onLongPress: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(isMuted ? 'Unmute Status' : 'Mute Status'),
            content: Text(isMuted
                ? 'New status updates from $name will appear under recent updates.'
                : 'New status updates from $name won\'t appear under recent updates anymore.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL',
                    style: TextStyle(color: AppColors.orange)),
              ),
              TextButton(
                onPressed: () {
                  if (isMuted) {
                    context.read<StatusService>().unmuteUser(group['user_id']);
                  } else {
                    context.read<StatusService>().muteUser(group['user_id']);
                  }
                  Navigator.pop(context);
                },
                child: Text(isMuted ? 'UNMUTE' : 'MUTE',
                    style: const TextStyle(color: AppColors.orange)),
              ),
            ],
          ),
        );
      },
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StatusViewerScreen(
              userId: group['user_id'],
              name: name,
              avatarText: name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
              avatarColor: AppColors.orange,
              avatarUrl: avatarUrl,
              statuses: List<Map<String, dynamic>>.from(statuses),
              initialIndex: viewedCount == totalCount ? 0 : viewedCount,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7)
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            // Avatar
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: CustomPaint(
                  painter: StatusRingPainter(
                    totalSegments: totalCount,
                    viewedSegments: viewedCount,
                    viewedColor: AppColors.grey,
                    unviewedColor: isMuted ? AppColors.grey : AppColors.orange,
                    strokeWidth: 2,
                  ),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.lightGrey,
                    backgroundImage:
                        avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? const Icon(Icons.person,
                            color: AppColors.grey, size: 20)
                        : null,
                  ),
                ),
              ),
            ),
            // Name
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                name,
                style: TextStyle(
                  color: isMuted ? Colors.white70 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyStatusGridCard(
      BuildContext context, List<Map<String, dynamic>> myStatuses) {
    final statusService = context.watch<StatusService>();
    final isUploading = statusService.isUploadingStatus;
    final isUploadFailed = statusService.isUploadFailed;
    final uploadingThumbnail = statusService.uploadingThumbnail;
    final hasStatus = myStatuses.isNotEmpty;

    Widget background;
    if ((isUploading || isUploadFailed) && uploadingThumbnail != null) {
      final isVideo = uploadingThumbnail.path.toLowerCase().endsWith('.mp4');
      background = Stack(
        fit: StackFit.expand,
        children: [
          if (isVideo)
            Container(
                color: AppColors.grey,
                child:
                    const Icon(Icons.videocam, color: Colors.white54, size: 30))
          else
            Image.file(uploadingThumbnail, fit: BoxFit.cover),
          Container(color: Colors.black45),
          if (isUploading)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else if (isUploadFailed)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                  SizedBox(height: 4),
                  Text('Failed to upload\nTap to retry',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 10)),
                ],
              ),
            ),
        ],
      );
    } else if (hasStatus) {
      final latestStatus = myStatuses.last;
      if (latestStatus['type'] == 'text') {
        Color bgColor = AppColors.orange;
        if (latestStatus['bg_color'] != null) {
          try {
            bgColor = Color(
                int.parse(latestStatus['bg_color'].replaceFirst('#', '0xFF')));
          } catch (_) {}
        }
        final fontStyle = latestStatus['font_style'] ?? 'Roboto';
        background = Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                bgColor,
                bgColor.withValues(alpha: 0.7),
              ],
            ),
          ),
          padding: const EdgeInsets.all(8),
          alignment: Alignment.center,
          child: Text(
            latestStatus['content'] ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: fontStyle,
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        );
      } else {
        String url = latestStatus['media_url'] ?? '';
        if (!url.startsWith('http') && url.isNotEmpty) {
          url = Supabase.instance.client.storage
              .from('chat_media')
              .getPublicUrl(url);
        }
        if (url.isNotEmpty) {
          if (latestStatus['type'] == 'video') {
            background = SizedBox.expand(
                child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 100,
                      height: 100,
                      child: VideoThumbnailWidget(
                          mediaUrl: url,
                          chatService: context.read<ChatService>()),
                    )));
          } else {
            background = Image.network(url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                    color: AppColors.grey,
                    child: const Icon(Icons.image_not_supported,
                        color: Colors.white54)));
          }
        } else {
          background = Container(color: AppColors.grey);
        }
      }
    } else {
      background = Container(color: AppColors.lightGrey);
    }

    return GestureDetector(
      onTap: () async {
        if (isUploadFailed) {
          statusService.retryStatusUpload();
        } else if (hasStatus) {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const OwnStatusViewerScreen()));
          if (context.mounted) setState(() {});
        } else {
          _showCreateStatusOptions(context);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            background,
            if (hasStatus)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.3),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7)
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            // Avatar
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => _showCreateStatusOptions(context),
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(shape: BoxShape.circle),
                      child: CustomPaint(
                        painter: hasStatus
                            ? StatusRingPainter(
                                totalSegments: myStatuses.length,
                                viewedSegments: myStatuses.length,
                                viewedColor: AppColors.grey,
                                strokeWidth: 2,
                              )
                            : null,
                        child: Builder(
                          builder: (context) {
                            final myAvatarUrl = context
                                .watch<ChatService>()
                                .currentUserProfile?['avatar_url'];
                            return CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.white,
                              backgroundImage: myAvatarUrl != null
                                  ? NetworkImage(myAvatarUrl)
                                  : null,
                              child: myAvatarUrl == null
                                  ? const Icon(Icons.person,
                                      color: AppColors.grey, size: 20)
                                  : null,
                            );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.white, width: 2),
                        ),
                        child: const Icon(Icons.add,
                            color: AppColors.white, size: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Text
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Text(
                hasStatus ? 'My status' : 'Add status',
                style: TextStyle(
                  color: hasStatus ? Colors.white : AppColors.dark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(time.year, time.month, time.day);

    final timeStr =
        '${time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour)}:${time.minute.toString().padLeft(2, '0')} ${time.hour >= 12 ? 'PM' : 'AM'}';

    if (msgDate == today) {
      return 'Today, $timeStr';
    } else if (msgDate == yesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return '${time.day}/${time.month}/${time.year}, $timeStr';
    }
  }
}
