import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import 'qr_scanner_screen.dart';

class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});

  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesScreenState();
}

class _LinkedDevicesScreenState extends State<LinkedDevicesScreen> {
  SupabaseClient get _supabase => Supabase.instance.client;
  List<Map<String, dynamic>> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;
      final data = await _supabase
          .from('linked_devices')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      if (mounted) setState(() { _devices = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      debugPrint('Error loading devices: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeDevice(String deviceId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove device'),
        content: const Text('This device will be logged out of Twibee. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _supabase.from('linked_devices').delete().eq('id', deviceId);
        await _loadDevices();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Device removed')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  /// Navigate to QR Scanner to link with Twibee Web
  void _openScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QRScannerScreen()),
    );
  }

  IconData _deviceIcon(String? type) {
    switch (type?.toLowerCase()) {
      case 'desktop': return Icons.computer;
      case 'web': return Icons.web;
      case 'tablet': return Icons.tablet;
      default: return Icons.devices;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Linked devices'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _devices.isEmpty
              ? _buildEmptyState()
              : _buildDeviceList(),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: const BoxDecoration(
              color: AppColors.orangePale,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.devices_outlined, size: 72, color: AppColors.orange),
          ),
          const SizedBox(height: 28),
          const Text(
            'Use Twibee on\nother devices',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.dark, fontSize: 26, fontWeight: FontWeight.bold, height: 1.2),
          ),
          const SizedBox(height: 14),
          const Text(
            'Link other devices like Windows, Mac and Web to use Twibee without your phone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.grey, fontSize: 14, height: 1.5),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner, color: AppColors.white),
              label: const Text('Link a device', style: TextStyle(color: AppColors.white, fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 14, color: AppColors.grey),
              SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Your messages are end-to-end encrypted on all devices.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('CONNECTED DEVICES',
              style: TextStyle(color: AppColors.grey, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _devices.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final d = _devices[i];
              final linkedAt = d['created_at'] != null
                  ? DateTime.tryParse(d['created_at'])
                  : null;
              final timeStr = linkedAt != null
                  ? '${linkedAt.day}/${linkedAt.month}/${linkedAt.year}'
                  : 'Unknown';
              return Card(
                elevation: 0,
                color: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.orangePale, borderRadius: BorderRadius.circular(12)),
                    child: Icon(_deviceIcon(d['device_type']), color: AppColors.orange, size: 24),
                  ),
                  title: Text(d['device_name'] ?? 'Unknown Device',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  subtitle: Text('Linked on $timeStr',
                      style: const TextStyle(color: AppColors.grey, fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                    onPressed: () => _removeDevice(d['id'].toString()),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner, color: AppColors.white),
              label: const Text('Link another device', style: TextStyle(color: AppColors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orange,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

