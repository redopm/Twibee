import 'package:flutter/material.dart';
import '../theme.dart';

/// Screen 21 - Call Logs
/// Shows recent voice/video calls with direction (incoming/outgoing/missed).
class CallLogsScreen extends StatefulWidget {
  const CallLogsScreen({super.key});

  @override
  State<CallLogsScreen> createState() => _CallLogsScreenState();
}

class _CallLogsScreenState extends State<CallLogsScreen> {
  int _tabIndex = 0; // 0 = All, 1 = Missed
  int _navIndex = 2; // Calls tab active in bottom nav

  final List<_CallLog> _calls = [
    _CallLog('Priya Kapoor', 'Video', CallDirection.incoming, '9:30 AM', const Color(0xFFCC4D4D)),
    _CallLog('Dev Sharma', 'Voice', CallDirection.outgoing, 'Yesterday', AppColors.blue),
    _CallLog('Team Alpha ðŸš€', 'Group Voice', CallDirection.incoming, 'Yesterday', AppColors.orange),
    _CallLog('Rahul Mehta', 'Voice', CallDirection.missed, 'Monday', const Color(0xFFB34DCC)),
    _CallLog('Anjali Singh', 'Video', CallDirection.outgoing, 'Monday', const Color(0xFF4DBF66)),
    _CallLog('Mom â¤ï¸', 'Voice', CallDirection.incoming, 'Sunday', const Color(0xFFF2802E)),
  ];

  @override
  Widget build(BuildContext context) {
    final filtered = _tabIndex == 0
        ? _calls
        : _calls.where((c) => c.direction == CallDirection.missed).toList();

    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: 'Calls',
        showBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_call, color: AppColors.orange),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Tabs: All / Missed
          Row(
            children: [
              _buildTab('All', 0),
              _buildTab('Missed', 1),
            ],
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: ListView.separated(
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const Divider(
                height: 0.5,
                indent: 80,
                color: AppColors.border,
              ),
              itemBuilder: (context, i) => _buildCallTile(filtered[i]),
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final active = _tabIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tabIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: active ? AppColors.orange : AppColors.grey,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 3,
                width: 40,
                decoration: BoxDecoration(
                  color: active ? AppColors.orange : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCallTile(_CallLog call) {
    final isMissed = call.direction == CallDirection.missed;
    final isVideo = call.type.contains('Video');

    IconData arrowIcon;
    Color arrowColor;
    switch (call.direction) {
      case CallDirection.incoming:
        arrowIcon = Icons.call_received;
        arrowColor = AppColors.orange;
        break;
      case CallDirection.outgoing:
        arrowIcon = Icons.call_made;
        arrowColor = AppColors.orange;
        break;
      case CallDirection.missed:
        arrowIcon = Icons.call_received;
        arrowColor = AppColors.red;
        break;
    }

    return ListTile(
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ListTile(
                  leading: const Icon(Icons.call, color: AppColors.orange),
                  title: const Text('Voice Call'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please start calls from the Individual Chat screen.')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: AppColors.orange),
                  title: const Text('Video Call'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please start calls from the Individual Chat screen.')));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.message, color: AppColors.orange),
                  title: const Text('Send Message'),
                  onTap: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: call.color,
        child: Text(
          call.name[0],
          style: const TextStyle(color: AppColors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      title: Text(
        call.name,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isMissed ? AppColors.red : AppColors.dark,
        ),
      ),
      subtitle: Row(
        children: [
          Icon(arrowIcon, size: 14, color: arrowColor),
          const SizedBox(width: 4),
          Text(call.type, style: TextStyle(fontSize: 13, color: arrowColor)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(call.time, style: AppTextStyles.subtitle),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please start calls from the Individual Chat screen.')));
              },
            child: Icon(
              isVideo ? Icons.videocam_outlined : Icons.call_outlined,
              size: 18,
              color: AppColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

enum CallDirection { incoming, outgoing, missed }

class _CallLog {
  final String name;
  final String type;
  final CallDirection direction;
  final String time;
  final Color color;

  _CallLog(this.name, this.type, this.direction, this.time, this.color);
}

