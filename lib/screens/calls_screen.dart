import 'package:flutter/material.dart';
import 'package:zego_uikit/zego_uikit.dart';
import 'package:zego_uikit_prebuilt_call/zego_uikit_prebuilt_call.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../services/chat_service.dart';
import 'contact_info_screen.dart';
import 'voice_call_screen.dart';
import 'video_call_screen.dart';
import '../services/call_log_service.dart' as import_call_log_service;
import 'select_call_contact_screen.dart';
import 'schedule_call_screen.dart';
import 'call_overlay_manager.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  bool _isEditing = false;
  final Set<String> _selectedLogIds = {};

  @override
  void initState() {
    super.initState();
  }

  String _formatDuration(DateTime start, DateTime? end) {
    if (end == null) return '';
    final diff = end.difference(start);
    if (diff.inSeconds <= 0) return '';
    if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ${diff.inSeconds % 60}s';
    }
    return '${diff.inSeconds}s';
  }

  String _formatTime(DateTime date) {
    return DateFormat.jm().format(date); // e.g. "5:30 PM"
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return DateFormat('d MMM').format(date); // e.g. "5 Jul"
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<ChatService>().currentUserId;

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: Colors.black12,
        centerTitle: false,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.orange, Color(0xFFFF8C42)],
            ).createShader(bounds),
            child: const Text(
              'Calls',
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
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _selectedLogIds.isEmpty
                    ? null
                    : () async {
                        await import_call_log_service.CallLogService()
                            .deleteIndividualLogs(_selectedLogIds.toList());
                        setState(() {
                          _isEditing = false;
                          _selectedLogIds.clear();
                        });
                      },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: GestureDetector(
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const SelectCallContactScreen()));
                  import_call_log_service.CallLogService().refreshLogs();
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.add, color: AppColors.white, size: 20),
                ),
              ),
            ),
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.close, color: AppColors.dark),
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _selectedLogIds.clear();
                  });
                },
              ),
            )
          else
            PopupMenuButton<String>(
              color: Colors.white,
              icon: const Icon(Icons.more_vert, color: AppColors.dark),
              onSelected: (value) async {
                if (value == 'edit') {
                  setState(() {
                    _isEditing = true;
                    _selectedLogIds.clear();
                  });
                } else if (value == 'clear_all') {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear Call Logs'),
                      content: const Text(
                          'Are you sure you want to clear your ENTIRE call history?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Clear All',
                                style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await import_call_log_service.CallLogService()
                        .clearCallLogs();
                  }
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                    value: 'clear_all', child: Text('Clear call log')),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    hintStyle: TextStyle(color: AppColors.grey),
                    prefixIcon:
                        Icon(Icons.search, color: AppColors.grey, size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildQuickAction(context, Icons.add_link, 'Call link',
                      () => _showCallLinkSheet(context)),
                  _buildQuickAction(context, Icons.calendar_month, 'Schedule',
                      () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ScheduleCallScreen()));
                  }),
                  _buildQuickAction(context, Icons.favorite, 'Favorite',
                      () => _showFavoritesSheet(context)),
                  _buildQuickAction(context, Icons.add_ic_call, 'Add call',
                      () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SelectCallContactScreen()));
                    import_call_log_service.CallLogService().refreshLogs();
                  }),
                ],
              ),
            ),

            // Favorites Section
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: context.read<ChatService>().favoritesStream,
              builder: (context, snapshot) {
                final favorites = snapshot.data ?? [];
                if (favorites.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 14,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Favorites',
                            style: TextStyle(
                              color: AppColors.grey,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 90,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: favorites.length,
                        itemBuilder: (context, index) {
                          final fav = favorites[index];
                          final profile = fav['profile'] ?? {};
                          final name = profile['name'] ?? 'Unknown';
                          final avatarUrl = profile['avatar_url'];
                          final favUserId = fav['favorite_user_id'];

                          return GestureDetector(
                            onTap: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => ContactInfoScreen(
                                            name: name,
                                            avatarText: name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            avatarColor: AppColors.orange,
                                            chatId: favUserId,
                                          )));
                            },
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: AppColors.lightGrey,
                                    backgroundImage: avatarUrl != null
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                                color: AppColors.orange,
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold))
                                        : null,
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    width: 56,
                                    child: Text(
                                      name,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.orange,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent',
                    style: TextStyle(
                      color: AppColors.grey,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),

            StreamBuilder<List<Map<String, dynamic>>>(
              stream: import_call_log_service.CallLogService().callLogsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: Padding(
                          padding: EdgeInsets.all(32),
                          child: CircularProgressIndicator(
                              color: AppColors.orange)));
                }
                final callLogs = snapshot.data ?? [];
                if (callLogs.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No recent calls',
                          style: TextStyle(color: AppColors.grey)),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: callLogs.length,
                  itemBuilder: (context, index) {
                    final log = callLogs[index];
                    final isInviter = log['inviter']['id'] == currentUserId;
                    final startedAt = log['started_at'] != null
                        ? DateTime.parse(log['started_at']).toLocal()
                        : DateTime.now();
                    final endedAt = log['ended_at'] != null
                        ? DateTime.parse(log['ended_at']).toLocal()
                        : null;
                    final bool isVideo = log['is_video'] == true;

                    // Compute display status and icon
                    String displayStatus = '';
                    Color statusColor = AppColors.grey;
                    IconData statusIcon;

                    if (isInviter) {
                      statusIcon = Icons.call_made;
                      if (log['status'] == 'completed') {
                        displayStatus = 'Outgoing';
                      } else if (log['status'] == 'ongoing') {
                        displayStatus = 'Ongoing';
                        statusColor = Colors.green;
                      } else {
                        displayStatus = 'Cancelled';
                      }
                    } else {
                      // Callee
                      final participants = log['participants'] as List? ?? [];
                      final myParticipantMap = participants.firstWhere(
                          (p) => p['user_id'] == currentUserId,
                          orElse: () => null);
                      final myStatus = myParticipantMap?['status'] ?? 'missed';

                      if (myStatus == 'missed' || myStatus == 'declined') {
                        statusIcon = Icons.call_missed;
                        displayStatus =
                            myStatus == 'missed' ? 'Missed' : 'Declined';
                        statusColor = Colors.red;
                      } else if (log['status'] == 'ongoing') {
                        statusIcon = Icons.call_received;
                        displayStatus = 'Ongoing';
                        statusColor = Colors.green;
                      } else {
                        statusIcon = Icons.call_received;
                        displayStatus = 'Incoming';
                      }
                    }

                    // Determine display name and avatar
                    String displayName = 'Unknown';
                    String avatarUrl = '';
                    String callTargetId = '';

                    if (isInviter) {
                      final participants = log['participants'] as List? ?? [];
                      final others = participants
                          .where((p) => p['user_id'] != currentUserId)
                          .toList();
                      if (others.isNotEmpty) {
                        final profile = others.first['profiles'];
                        if (profile != null) {
                          displayName = profile['name'] ?? 'Unknown';
                          avatarUrl = profile['avatar_url'] ?? '';
                        }
                        callTargetId = others.first['user_id'];
                        if (others.length > 1) {
                          displayName += ' and ${others.length - 1} others';
                        }
                      } else if (log['id'] != null) {
                        callTargetId = 'unknown';
                        displayName = 'Unknown';
                      }
                    } else {
                      displayName = log['inviter']['name'] ?? 'Unknown';
                      avatarUrl = log['inviter']['avatar_url'] ?? '';
                      callTargetId = log['inviter']['id'];
                    }

                    DateTime? actualTalkStartTime;
                    final allParticipants = log['participants'] as List? ?? [];
                    for (var p in allParticipants) {
                      if (p['joined_at'] != null) {
                        final joined = DateTime.parse(p['joined_at']).toLocal();
                        if (actualTalkStartTime == null ||
                            joined.isAfter(actualTalkStartTime)) {
                          actualTalkStartTime =
                              joined; // The time the callee actually answered
                        }
                      }
                    }

                    String durationText = '';
                    if (displayStatus != 'Missed' &&
                        displayStatus != 'Declined' &&
                        displayStatus != 'Cancelled') {
                      durationText = _formatDuration(
                          actualTalkStartTime ?? startedAt, endedAt);
                    }

                    final timeText = _formatTime(startedAt);

                    final logId = log['id'] as String;
                    final isSelected = _selectedLogIds.contains(logId);

                    return ListTile(
                      onTap: () {
                        if (_isEditing) {
                          setState(() {
                            if (isSelected) {
                              _selectedLogIds.remove(logId);
                            } else {
                              _selectedLogIds.add(logId);
                            }
                          });
                        } else {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => ContactInfoScreen(
                                        name: displayName,
                                        avatarText: displayName.isNotEmpty
                                            ? displayName[0].toUpperCase()
                                            : '?',
                                        avatarColor: AppColors.orange,
                                        chatId: callTargetId,
                                      )));
                        }
                      },
                      onLongPress: !_isEditing
                          ? () {
                              setState(() {
                                _isEditing = true;
                                _selectedLogIds.add(logId);
                              });
                            }
                          : null,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 0),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isEditing)
                            Checkbox(
                              value: isSelected,
                              activeColor: AppColors.orange,
                              onChanged: (bool? val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedLogIds.add(logId);
                                  } else {
                                    _selectedLogIds.remove(logId);
                                  }
                                });
                              },
                            ),
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: avatarUrl.isEmpty
                                  ? LinearGradient(
                                      colors: _nameToGradient(displayName),
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                              image: avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: avatarUrl.isEmpty
                                ? Center(
                                    child: Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 20,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      title: Text(
                        displayName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: statusColor == Colors.red
                                ? Colors.red
                                : AppColors.dark),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Row(
                        children: [
                          Icon(statusIcon, color: statusColor, size: 14),
                          const SizedBox(width: 4),
                          Icon(isVideo ? Icons.videocam : Icons.call,
                              color: AppColors.grey, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '$displayStatus${durationText.isNotEmpty ? ' • $durationText' : ''}',
                              style: const TextStyle(color: AppColors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: !_isEditing
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(_formatTime(startedAt),
                                    style: const TextStyle(
                                        color: AppColors.grey, fontSize: 12)),
                                Text(_formatDate(startedAt),
                                    style: const TextStyle(
                                        color: AppColors.grey, fontSize: 12)),
                              ],
                            )
                          : null,
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── Action Handlers ──────────────────────────────────────────────────────────

  void _showCallLinkSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.only(bottom: 20),
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2))),
              ),
              const Text('Create call link',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Anyone with Twibee can use this link to join this call. Only share it with people you trust.',
                  style: TextStyle(color: AppColors.grey, fontSize: 14)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                        color: AppColors.orangePale, shape: BoxShape.circle),
                    child: const Icon(Icons.videocam, color: AppColors.orange),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('https://Twibee.app/call/abc-xyz-123',
                            style: TextStyle(color: Colors.blue, fontSize: 15)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.call_outlined, color: AppColors.dark),
                title: const Text('Call type'),
                trailing: const Text('Video',
                    style: TextStyle(color: AppColors.grey)),
                onTap: () {},
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading:
                    const Icon(Icons.share_outlined, color: AppColors.dark),
                title: const Text('Share link'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link ready to share')));
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.copy_outlined, color: AppColors.dark),
                title: const Text('Copy link'),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Link copied to clipboard')));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFavoritesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite_border,
                  size: 48, color: AppColors.orange),
              const SizedBox(height: 16),
              const Text('Add to Favorites',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                  'Add the people you call most often to your favorites for quick access.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 16)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const SelectCallContactScreen(
                                isFavoriteMode: true)));
                  },
                  child: const Text('Select contacts',
                      style: TextStyle(color: AppColors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAction(
      BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.lightGrey,
            child: Icon(icon, color: AppColors.dark, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: AppColors.dark,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
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
