import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../services/call_service.dart';

class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String callerPhone;
  final String? avatarUrl;
  final bool isVideo;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    required this.callerPhone,
    this.avatarUrl,
    this.isVideo = false,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _ring3;

  @override
  void initState() {
    super.initState();
    _ring1 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
    _ring2 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward()
      ..addStatusListener((s) { if (s == AnimationStatus.completed) { Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _ring2.repeat(); }); } });
    _ring3 = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..forward()
      ..addStatusListener((s) { if (s == AnimationStatus.completed) { Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _ring3.repeat(); }); } });
    Future.delayed(const Duration(milliseconds: 600), () { if (mounted) _ring2.repeat(); });
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _ring3.repeat(); });
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    super.dispose();
  }

  void _accept() {
    final callService = context.read<CallService>();
    callService.acceptCall();
    Navigator.pop(context);
  }

  void _decline() {
    context.read<CallService>().endCall();
    Navigator.maybePop(context);
  }

  void _showQuickReply() {
    final replies = [
      'Can\'t talk right now',
      'I\'ll call you back',
      'On my way!',
      'What\'s up?',
      'In a meeting, will call later',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2C),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const Text('Send a message', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...replies.map((r) => ListTile(
              title: Text(r, style: const TextStyle(color: Colors.white70)),
              onTap: () {
                Navigator.pop(ctx);
                _decline();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent: "$r"')));
              },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseRing(AnimationController controller, double size, Color color) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.15 * (1.0 - controller.value)),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            // ── Call Type Label ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.isVideo ? Icons.videocam : Icons.call, color: Colors.white54, size: 16),
                const SizedBox(width: 6),
                Text(
                  widget.isVideo ? 'Twibee Video Call' : 'Twibee Voice Call',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, color: Colors.white38, size: 12),
                SizedBox(width: 4),
                Text('end-to-end encrypted', style: TextStyle(color: Colors.white38, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 48),
            // ── Avatar with animated rings ──
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildPulseRing(_ring1, 220, AppColors.orange),
                  _buildPulseRing(_ring2, 180, AppColors.orange),
                  _buildPulseRing(_ring3, 140, AppColors.orange),
                  // Avatar
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.orange,
                      image: widget.avatarUrl != null
                          ? DecorationImage(image: NetworkImage(widget.avatarUrl!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: widget.avatarUrl == null
                        ? Center(
                            child: Text(
                              widget.callerName.isNotEmpty ? widget.callerName.characters.first.toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // ── Caller Name ──
            Text(widget.callerName,
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(widget.callerPhone,
                style: const TextStyle(color: Colors.white54, fontSize: 16)),
            const Spacer(),
            // ── Quick actions ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(Icons.chat_bubble_outline, 'Reply', _showQuickReply),
                _buildQuickAction(Icons.alarm, 'Remind me', () {
                  _decline();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminder set for 5 minutes')));
                }),
              ],
            ),
            const SizedBox(height: 48),
            // ── Accept / Decline buttons ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Decline
                  _buildCallButton(
                    icon: Icons.call_end,
                    color: Colors.red,
                    label: 'Decline',
                    onTap: _decline,
                  ),
                  // Accept
                  _buildCallButton(
                    icon: widget.isVideo ? Icons.videocam : Icons.call,
                    color: Colors.green,
                    label: 'Accept',
                    onTap: _accept,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildCallButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }

  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            child: Icon(icon, color: Colors.white70, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
}

