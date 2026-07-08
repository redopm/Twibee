import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../services/channel_service.dart';
import '../services/channel_preferences.dart';
import 'channel_qr_screen.dart';
import 'channel_subscribers_screen.dart';
import 'channel_admins_screen.dart';
import 'invite_share_screen.dart';
import 'channel_settings_screen.dart';
import 'select_group_members_screen.dart';

class ChannelInfoScreen extends StatefulWidget {
  final Map<String, dynamic> channel;

  const ChannelInfoScreen({super.key, required this.channel});

  @override
  State<ChannelInfoScreen> createState() => _ChannelInfoScreenState();
}

class _ChannelInfoScreenState extends State<ChannelInfoScreen> {
  final ChannelService _channelService = ChannelService();

  late Map<String, dynamic> _channel;
  bool _isLoading = true;
  bool _isSubscribed = false;
  bool _isOwner = false;
  bool _isAdmin = false;
  int _subscriberCount = 0;
  bool _isArchived = false;

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _presenceChannel;
  int _onlineCount = 0;

  final GlobalKey _liveStreamKey = GlobalKey();
  final GlobalKey _muteKey = GlobalKey();
  final GlobalKey _discussKey = GlobalKey();
  final GlobalKey _moreKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _channel = Map<String, dynamic>.from(widget.channel);
    _init();
    _setupPresence();
  }

  void _setupPresence() {
    _presenceChannel = _supabase.channel('presence:channel_${_channel['id']}');

    _presenceChannel!.onPresenceSync((payload) {
      final onlineUsers = _presenceChannel!.presenceState();
      if (mounted) {
        setState(() {
          _onlineCount = onlineUsers.length;
        });
      }
    });

    _presenceChannel!.subscribe((status, error) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        await _presenceChannel!.track({
          'user_id': _supabase.auth.currentUser!.id,
        });
      }
    });
  }

  Future<void> _init() async {
    final channelId = _channel['id'] as String;
    final currentUserId = _channelService.currentUserId;

    final results = await Future.wait([
      _channelService.isSubscribed(channelId),
      _channelService.isAdmin(channelId),
      _channelService.getSubscribers(channelId).then((subs) => subs.length),
      ChannelPreferences.isArchived(channelId),
    ]);

    if (mounted) {
      setState(() {
        _isSubscribed = results[0] as bool;
        _isAdmin = results[1] as bool;
        _subscriberCount = results[2] as int;
        _isArchived = results[3] as bool;
        _isOwner = _channel['owner_id'] == currentUserId;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateAvatar() async {
    if (!_isOwner && !_isAdmin) return;
    
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) {
      if (mounted) setState(() => _isLoading = true);
      try {
         await _channelService.updateChannel(
           channelId: _channel['id'],
           avatarFile: File(picked.path),
         );
         
         final refreshed = await _channelService.getChannel(_channel['id']);
         
         if (mounted) {
            setState(() {
               _channel = refreshed;
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
         }
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating photo: $e')));
      } finally {
         if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // ignore: unused_element
  Future<void> _toggleSubscription() async {
    final channelId = _channel['id'] as String;
    try {
      if (_isSubscribed) {
        await _channelService.unsubscribe(channelId);
        setState(() {
          _isSubscribed = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left channel.')));
          Navigator.pop(context, _channel);
          Navigator.pop(context, true);
        }
      } else {
        await _channelService.subscribe(channelId);
        setState(() {
          _isSubscribed = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined channel!')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteChannel() async {
    try {
      await _channelService.deleteChannel(_channel['id']);
      if (mounted) {
        Navigator.pop(context, true);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void dispose() {
    if (_presenceChannel != null) {
      _supabase.removeChannel(_presenceChannel!);
    }
    super.dispose();
  }

  // ignore: unused_element
  void _showDeleteChannelDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Channel'),
        content: const Text('Are you sure you want to permanently delete this channel? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteChannel();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.white,
        body: Center(child: CircularProgressIndicator(color: AppColors.orange)),
      );
    }

    final name = _channel['name'] ?? 'Channel';
    final description = _channel['description'] ?? '';
    final avatarUrl = _channel['avatar_url'];

    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) {
        if (!didPop) Navigator.pop(context, _channel);
      },
      child: DefaultTabController(
        length: 4,
        child: Scaffold(
          backgroundColor: AppColors.lightGrey,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _MorphingHeaderDelegate(
                  expandedHeight: description.isNotEmpty ? 290.0 : 250.0,
                  collapsedHeight: MediaQuery.of(context).padding.top + kToolbarHeight,
                  avatarUrl: avatarUrl,
                  name: name,
                  subscriberCount: _subscriberCount,
                  onlineCount: _onlineCount,
                  description: description,
                  isOwner: _isOwner,
                  isAdmin: _isAdmin,
                  channel: _channel,
                  onAvatarTap: _updateAvatar,
                  onBack: () => Navigator.pop(context, _channel),
                  onQr: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ChannelQrScreen(channel: _channel)
                    ));
                  },
                  onEdit: () async {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ChannelSettingsScreen(channel: _channel)),
                    );
                    if (updated == true) {
                      final refreshed = await _channelService.getChannel(_channel['id']);
                      setState(() => _channel = refreshed);
                    }
                  },
                  onMoreSelected: (val) async {
                    if (val == 'copy_link') {
                      await Clipboard.setData(ClipboardData(text: 'Twibee://channel/${_channel['id']}'));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                      }
                    }
                    if (val == 'settings') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelSettingsScreen(channel: _channel)));
                    }
                  },
                ),
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildActionButton(_liveStreamKey, Icons.graphic_eq, 'live stream', _showLiveStreamMenu),
                          _buildActionButton(_muteKey, Icons.notifications, 'mute', _showMuteMenu),
                          _buildActionButton(_discussKey, Icons.chat_bubble_outline, 'discuss', () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectGroupMembersScreen()));
                          }),
                          _buildActionButton(_moreKey, Icons.more_horiz, 'more', _showMoreMenu),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isOwner || _isAdmin) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          elevation: 2,
                          shadowColor: Colors.black.withValues(alpha: 0.1),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(Icons.people_alt, color: AppColors.orange),
                                title: const Text('Subscribers'),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.grey2),
                                onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ChannelSubscribersScreen(channel: _channel, isAdminOrOwner: _isOwner || _isAdmin),
                                  ));
                                  _init();
                                },
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.admin_panel_settings, color: AppColors.orange),
                                title: const Text('Administrators'),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.grey2),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ChannelAdminsScreen(channel: _channel, isOwner: _isOwner),
                                  ));
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 2,
                        shadowColor: Colors.black.withValues(alpha: 0.1),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.link, color: AppColors.orange),
                              title: const Text('Invite via Link'),
                              trailing: const Icon(Icons.chevron_right, color: AppColors.grey2),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => InviteShareScreen(
                                    id: _channel['id'],
                                    isChannel: true,
                                    isAdmin: _isAdmin || _isOwner,
                                    name: _channel['name'] ?? 'Channel',
                                  ),
                                ));
                              },
                            ),
                            if (_isAdmin || _isOwner) ...[
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(Icons.settings, color: AppColors.orange),
                                title: const Text('Channel Settings'),
                                trailing: const Icon(Icons.chevron_right, color: AppColors.grey2),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ChannelSettingsScreen(channel: _channel)
                                  ));
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  const TabBar(
                    isScrollable: true,
                    labelColor: AppColors.orange,
                    unselectedLabelColor: AppColors.grey2,
                    indicatorColor: AppColors.orange,
                    indicatorWeight: 3,
                    labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    tabs: [
                      Tab(text: 'Media'),
                      Tab(text: 'Files'),
                      Tab(text: 'Music'),
                      Tab(text: 'Links'),
                    ],
                  ),
                ),
              ),
              SliverFillRemaining(
                child: TabBarView(
                  children: [
                    _buildDummyTab('No media found.'),
                    _buildDummyTab('No files found.'),
                    _buildDummyTab('No music found.'),
                    _buildDummyTab('No links found.'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDummyTab(String message) {
    return Container(
      color: Colors.white,
      child: Center(
        child: Text(message, style: const TextStyle(color: AppColors.grey2, fontSize: 15)),
      ),
    );
  }

  Widget _buildActionButton(GlobalKey key, IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          key: key,
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Icon(icon, color: AppColors.orange),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showMenuForButton(GlobalKey key, List<PopupMenuEntry<String>> items) {
    final RenderBox renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy + renderBox.size.height + 10,
        MediaQuery.of(context).size.width - position.dx - renderBox.size.width,
        0,
      ),
      items: items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.white,
      elevation: 4,
    );
  }

  void _showLiveStreamMenu() {
    _showMenuForButton(_liveStreamKey, [
      PopupMenuItem(
        value: 'display_as',
        child: ListTile(
          leading: CircleAvatar(
            radius: 12, 
            backgroundColor: AppColors.orange,
            backgroundImage: _channelService.currentUserAvatar != null ? NetworkImage(_channelService.currentUserAvatar!) : null,
          ),
          title: const Text('Display Me As...'),
          subtitle: Text(_channelService.currentUserName ?? 'You', style: const TextStyle(fontSize: 10)),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem(
        value: 'start_stream',
        child: ListTile(
          leading: Icon(Icons.live_tv, color: AppColors.dark),
          title: Text('Start Live Stream'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      const PopupMenuItem(
        value: 'schedule_stream',
        child: ListTile(
          leading: Icon(Icons.schedule, color: AppColors.dark),
          title: Text('Schedule Live Stream'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
      const PopupMenuItem(
        value: 'stream_with',
        child: ListTile(
          leading: Icon(Icons.connected_tv, color: AppColors.dark),
          title: Text('Stream With...'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
      ),
    ]);
  }

  void _showMuteMenu() {
    _showMenuForButton(_muteKey, [
      PopupMenuItem(
        value: 'mute_for',
        child: const ListTile(
          leading: Icon(Icons.volume_off, color: AppColors.dark),
          title: Text('Mute for...'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        onTap: () {
            Future.delayed(Duration.zero, () {
               showModalBottomSheet(
                 context: context,
                 builder: (ctx) => SafeArea(
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const ListTile(
                         title: Text('Mute Channel'),
                         subtitle: Text('Choose how long you want to mute notifications for this channel.'),
                       ),
                       const Divider(),
                       ListTile(title: const Text('8 hours'), onTap: () {
                         Navigator.pop(ctx);
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted for 8 hours')));
                       }),
                       ListTile(title: const Text('1 week'), onTap: () {
                         Navigator.pop(ctx);
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted for 1 week')));
                       }),
                       ListTile(title: const Text('Always'), onTap: () {
                         Navigator.pop(ctx);
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted forever')));
                       }),
                     ],
                   ),
                 ),
               );
            });
        }
      ),
      PopupMenuItem(
        value: 'disable_sound',
        child: const ListTile(
          leading: Icon(Icons.notifications_off, color: AppColors.dark),
          title: Text('Disable sound'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        onTap: () {
            Future.delayed(Duration.zero, () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sound disabled')));
            });
        }
      ),
      PopupMenuItem(
        value: 'forever_mute',
        child: const ListTile(
          leading: Icon(Icons.notifications_paused, color: AppColors.dark),
          title: Text('Forever mute'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        onTap: () {
            Future.delayed(Duration.zero, () {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Muted forever')));
            });
        }
      ),
    ]);
  }

  void _showMoreMenu() {
    _showMenuForButton(_moreKey, [
      PopupMenuItem(
        value: 'search',
        child: const ListTile(
          leading: Icon(Icons.search, color: AppColors.dark),
          title: Text('Search'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        onTap: () {
          Future.delayed(Duration.zero, () {
            Navigator.pop(context, 'search');
          });
        },
      ),
      PopupMenuItem(
        value: 'archive_channel',
        child: ListTile(
          leading: Icon(_isArchived ? Icons.unarchive : Icons.archive, color: AppColors.dark),
          title: Text(_isArchived ? 'Unarchive Channel' : 'Archive Channel'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        onTap: () {
          Future.delayed(Duration.zero, () async {
             await ChannelPreferences.toggleArchive(_channel['id']);
             if (mounted) {
               setState(() {
                 _isArchived = !_isArchived;
               });
               ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_isArchived ? 'Channel Archived' : 'Channel Unarchived')));
             }
          });
        }
      ),
      if (_isOwner || _isAdmin)
        PopupMenuItem(
          value: 'auto_delete',
          child: const ListTile(
            leading: Icon(Icons.auto_delete_outlined, color: AppColors.dark),
            title: Text('Enable Auto-Delete'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          onTap: () {
            Future.delayed(Duration.zero, () {
               showModalBottomSheet(
                 context: context,
                 builder: (ctx) => SafeArea(
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       const ListTile(
                         title: Text('Auto-delete messages'),
                         subtitle: Text('Automatically delete new messages sent in this channel after a certain period of time.'),
                       ),
                       const Divider(),
                       ListTile(title: const Text('Off'), onTap: () async {
                         Navigator.pop(ctx);
                         await ChannelPreferences.setAutoDelete(_channel['id'], '');
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-delete disabled')));
                       }),
                       ListTile(title: const Text('24 hours'), onTap: () async {
                         Navigator.pop(ctx);
                         await ChannelPreferences.setAutoDelete(_channel['id'], '24h');
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-delete set to 24 hours')));
                       }),
                       ListTile(title: const Text('1 week'), onTap: () async {
                         Navigator.pop(ctx);
                         await ChannelPreferences.setAutoDelete(_channel['id'], '1w');
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-delete set to 1 week')));
                       }),
                       ListTile(title: const Text('1 month'), onTap: () async {
                         Navigator.pop(ctx);
                         await ChannelPreferences.setAutoDelete(_channel['id'], '1m');
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto-delete set to 1 month')));
                       }),
                     ],
                   ),
                 ),
               );
            });
          }
        ),
      if (_isOwner || _isAdmin)
        PopupMenuItem(
          value: 'clear_messages',
          child: const ListTile(
            leading: Icon(Icons.cleaning_services_outlined, color: AppColors.dark),
            title: Text('Clear Messages'),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          onTap: () {
             Future.delayed(Duration.zero, () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear Messages'),
                    content: const Text('Are you sure you want to clear all messages? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.dark)),
                      ),
                      TextButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _channelService.clearMessages(_channel['id']);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messages cleared')));
                          }
                        },
                        child: const Text('Clear', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
             });
          }
        ),
      if (!_isOwner && !_isAdmin)
        PopupMenuItem(
          value: 'leave_channel',
          child: const ListTile(
            leading: Icon(Icons.exit_to_app, color: Colors.red),
            title: Text('Leave Channel', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          onTap: () async {
             try {
                await _channelService.removeSubscriber(_channel['id'], _channelService.currentUserId);
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You left the channel')));
                   Navigator.pop(context);
                   Navigator.pop(context);
                }
             } catch(e) {}
          }
        ),
      if (_isOwner)
        PopupMenuItem(
          value: 'delete_channel',
          child: const ListTile(
            leading: Icon(Icons.delete_forever, color: Colors.red),
            title: Text('Delete Channel', style: TextStyle(color: Colors.red)),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
          onTap: () {
             Future.delayed(Duration.zero, () => _showDeleteChannelDialog());
          }
        ),
    ]);
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return _tabBar.tabs.length != oldDelegate._tabBar.tabs.length;
  }
}

class _MorphingHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double expandedHeight;
  final double collapsedHeight;
  final String? avatarUrl;
  final String name;
  final int subscriberCount;
  final int onlineCount;
  final String description;
  final bool isOwner;
  final bool isAdmin;
  final Map<String, dynamic> channel;
  final VoidCallback onAvatarTap;
  final VoidCallback onBack;
  final VoidCallback onQr;
  final VoidCallback onEdit;
  final Function(String) onMoreSelected;

  _MorphingHeaderDelegate({
    required this.expandedHeight,
    required this.collapsedHeight,
    required this.avatarUrl,
    required this.name,
    required this.subscriberCount,
    required this.onlineCount,
    required this.description,
    required this.isOwner,
    required this.isAdmin,
    required this.channel,
    required this.onAvatarTap,
    required this.onBack,
    required this.onQr,
    required this.onEdit,
    required this.onMoreSelected,
  });

  @override
  double get maxExtent => expandedHeight;

  @override
  double get minExtent => collapsedHeight;

  @override
  bool shouldRebuild(covariant _MorphingHeaderDelegate oldDelegate) => true;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final double currentExtent = (maxExtent - shrinkOffset).clamp(minExtent, double.infinity);
    
    double collapseRatio = (maxExtent - currentExtent) / (maxExtent - minExtent);
    collapseRatio = collapseRatio.clamp(0.0, 1.0);

    double stretchRatio = 0.0;
    if (shrinkOffset < 0) {
      stretchRatio = (-shrinkOffset) / 200.0;
      stretchRatio = stretchRatio.clamp(0.0, 1.0);
    }

    final double screenWidth = MediaQuery.of(context).size.width;

    final double normalAvatarSize = 80.0;
    final double currentAvatarSize = lerpDouble(normalAvatarSize, screenWidth, stretchRatio)!;
    final double currentBorderRadius = lerpDouble(normalAvatarSize / 2, 0.0, stretchRatio)!;

    final double normalAvatarTop = minExtent + 16.0;
    final double currentAvatarTop = lerpDouble(normalAvatarTop, 0.0, stretchRatio)!;
    
    final double normalAvatarLeft = (screenWidth - normalAvatarSize) / 2;
    final double currentAvatarLeft = lerpDouble(normalAvatarLeft, 0.0, stretchRatio)!;

    final double normalContentOpacity = (1.0 - collapseRatio).clamp(0.0, 1.0);
    final double descOpacity = (normalContentOpacity * (1.0 - stretchRatio)).clamp(0.0, 1.0);
    
    final double normalTextTop = normalAvatarTop + normalAvatarSize + 12;
    final double stretchedTextTop = currentExtent - 70.0;
    
    final double currentTextTop = lerpDouble(normalTextTop, stretchedTextTop, stretchRatio)!;
    
    final Alignment currentTextAlignment = Alignment.lerp(Alignment.topCenter, Alignment.bottomLeft, stretchRatio)!;

    return Container(
      color: AppColors.lightGrey,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Container(color: AppColors.lightGrey),
          
          Positioned(
            top: currentAvatarTop - (collapseRatio * 50),
            left: currentAvatarLeft,
            width: currentAvatarSize,
            height: currentAvatarSize,
            child: Opacity(
              opacity: normalContentOpacity,
              child: GestureDetector(
                onTap: onAvatarTap,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(currentBorderRadius),
                    color: AppColors.orange,
                    image: avatarUrl != null ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover) : null,
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (avatarUrl == null)
                        Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'C', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32 + (30 * stretchRatio)))),
                      if ((isOwner || isAdmin) && stretchRatio > 0.5)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(currentBorderRadius),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.camera_alt, color: Colors.white, size: 30),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (stretchRatio > 0)
            Positioned(
              top: currentAvatarTop, left: 0, right: 0, height: currentAvatarSize,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.7 * stretchRatio), Colors.transparent],
                  )
                )
              ),
            ),

          Positioned(
            top: currentTextTop - (collapseRatio * 100),
            left: stretchRatio > 0 ? 16.0 : 0.0,
            right: stretchRatio > 0 ? 16.0 : 0.0,
            child: Opacity(
              opacity: normalContentOpacity,
              child: Align(
                alignment: currentTextAlignment,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: stretchRatio > 0.5 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Text(name, style: TextStyle(
                      fontSize: 20 + (4 * stretchRatio), 
                      fontWeight: FontWeight.bold, 
                      color: stretchRatio > 0.5 ? Colors.white : AppColors.dark
                    )),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$subscriberCount subscriber${subscriberCount == 1 ? '' : 's'}', style: TextStyle(
                          fontSize: 13 + (1 * stretchRatio), 
                          color: stretchRatio > 0.5 ? Colors.white70 : AppColors.grey2
                        )),
                        if (onlineCount > 0) ...[
                          Text(' • ', style: TextStyle(color: stretchRatio > 0.5 ? Colors.white70 : AppColors.grey2, fontSize: 13 + (1 * stretchRatio))),
                          const Icon(Icons.circle, color: Colors.green, size: 8),
                          const SizedBox(width: 4),
                          Text('$onlineCount online', style: TextStyle(color: Colors.green, fontSize: 13 + (1 * stretchRatio), fontWeight: FontWeight.w600)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (description.isNotEmpty)
            Positioned(
              top: normalTextTop + 50 - (collapseRatio * 150),
              left: 24,
              right: 24,
              child: Opacity(
                opacity: descOpacity,
                child: Text(description, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, color: AppColors.dark)),
              ),
            ),

          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: minExtent,
            child: Row(
              children: [
                const SizedBox(width: 4),
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.orange),
                  onPressed: onBack,
                ),
                Expanded(
                  child: Opacity(
                    opacity: collapseRatio,
                    child: Text(name, style: const TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code, color: AppColors.orange),
                  onPressed: onQr,
                ),
                if (isOwner)
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.orange),
                    onPressed: onEdit,
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.orange),
                  onSelected: onMoreSelected,
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'copy_link', child: Text('Copy Link')),
                    if (isOwner || isAdmin)
                      const PopupMenuItem(value: 'settings', child: Text('Channel Settings')),
                  ],
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

