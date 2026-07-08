import 'package:twibee/widgets/hexagon_border.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme.dart';

class PermissionUtils {
  /// Requests all permissions with a modern step-by-step dialog UI.
  /// Only shows the dialog for permissions that have NOT been granted yet.
  /// If OS already granted all permissions (e.g., after re-login), nothing is shown.
  static Future<void> requestAllPermissions(BuildContext context) async {
    final allPermissions = [
      const _PermissionItem(
        permission: Permission.camera,
        icon: Icons.camera_alt_rounded,
        title: 'Camera Access',
        description: 'To take photos and scan QR codes for sharing.',
        color: Color(0xFFFF6B35),
      ),
      const _PermissionItem(
        permission: Permission.microphone,
        icon: Icons.mic_rounded,
        title: 'Microphone Access',
        description: 'To record and send voice messages in chats.',
        color: Color(0xFF9C27B0),
      ),
      const _PermissionItem(
        permission: Permission.contacts,
        icon: Icons.contacts_rounded,
        title: 'Contacts Access',
        description: 'To find and connect with friends already on Twibee.',
        color: Color(0xFF2196F3),
      ),
      const _PermissionItem(
        permission: Permission.location,
        icon: Icons.location_on_rounded,
        title: 'Location Access',
        description: 'To share your location with friends in chats.',
        color: Color(0xFF4CAF50),
      ),
      const _PermissionItem(
        permission: Permission.storage,
        icon: Icons.folder_rounded,
        title: 'Storage Access',
        description: 'To save and share media files from your device.',
        color: Color(0xFFFF9800),
      ),
      const _PermissionItem(
        permission: Permission.notification,
        icon: Icons.notifications_rounded,
        title: 'Notifications',
        description: 'To receive message alerts and call notifications.',
        color: Color(0xFFF44336),
      ),
    ];

    // ✅ KEY FIX: Only keep permissions that are NOT yet granted.
    // This ensures we don't show the custom UI on re-login if OS already granted them.
    final List<_PermissionItem> pendingPermissions = [];
    for (final item in allPermissions) {
      final status = await item.permission.status;
      // Only show UI if: never asked (denied) — not if already granted or permanently denied
      if (status.isDenied) {
        pendingPermissions.add(item);
      }
    }

    // If everything is already granted, skip the modal entirely
    if (pendingPermissions.isEmpty) return;

    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => _ModernPermissionSheet(permissions: pendingPermissions),
    );
  }


  static void showPermissionDialog(BuildContext context, String featureName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: ShapeDecoration(
                  color: AppColors.orange.withValues(alpha: 0.1),
                  shape: const HexagonBorder(),
                ),
                child: const Icon(Icons.lock_rounded, color: AppColors.orange, size: 32),
              ),
              const SizedBox(height: 16),
              Text(
                '$featureName Permission Required',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.dark),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enable $featureName permission in app settings to use this feature.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: AppColors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        openAppSettings();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.orange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: const Text('Open Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionItem {
  final Permission permission;
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _PermissionItem({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}

class _ModernPermissionSheet extends StatefulWidget {
  final List<_PermissionItem> permissions;
  const _ModernPermissionSheet({required this.permissions});

  @override
  State<_ModernPermissionSheet> createState() => _ModernPermissionSheetState();
}

class _ModernPermissionSheetState extends State<_ModernPermissionSheet>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  bool _isRequesting = false;
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestCurrent() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    final item = widget.permissions[_step];
    await item.permission.request();

    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (_step < widget.permissions.length - 1) {
      setState(() => _step++);
      _animCtrl.reset();
      _animCtrl.forward();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _skipCurrent() {
    if (_step < widget.permissions.length - 1) {
      setState(() => _step++);
      _animCtrl.reset();
      _animCtrl.forward();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.permissions[_step];
    final total = widget.permissions.length;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(total, (i) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _step ? 20 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _step
                      ? item.color
                      : i < _step
                          ? item.color.withValues(alpha: 0.3)
                          : AppColors.border,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 32),

          // Icon
          ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              width: 96,
              height: 96,
              decoration: ShapeDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: const HexagonBorder(),
              ),
              child: Icon(item.icon, size: 48, color: item.color),
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            item.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.dark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Description
          Text(
            item.description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: AppColors.grey, height: 1.5),
          ),
          const SizedBox(height: 36),

          // Allow button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isRequesting ? null : _requestCurrent,
              style: ElevatedButton.styleFrom(
                backgroundColor: item.color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: _isRequesting
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      'Allow ${item.title.split(' ').first}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Skip
          TextButton(
            onPressed: _skipCurrent,
            child: Text(
              _step == total - 1 ? 'Continue without this' : 'Skip for now',
              style: const TextStyle(color: AppColors.grey, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

