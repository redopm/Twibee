import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';
import '../services/settings_service.dart';

class StorageDataScreen extends StatefulWidget {
  const StorageDataScreen({super.key});

  @override
  State<StorageDataScreen> createState() => _StorageDataScreenState();
}

class _StorageDataScreenState extends State<StorageDataScreen> {
  bool _loadingStorage = true;
  int _photosBytes = 0;
  int _videosBytes = 0;
  int _audioBytes = 0;
  int _docsBytes = 0;
  int _otherBytes = 0;
  int _totalBytes = 0;

  @override
  void initState() {
    super.initState();
    _calculateStorage();
  }

  Future<void> _calculateStorage() async {
    setState(() => _loadingStorage = true);
    try {
      final dirs = <Directory>[];
      // App documents + cache
      dirs.add(await getApplicationDocumentsDirectory());
      try { dirs.add(await getTemporaryDirectory()); } catch (_) {}
      try {
        final support = await getApplicationSupportDirectory();
        dirs.add(support);
      } catch (_) {}

      int photos = 0, videos = 0, audio = 0, docs = 0, other = 0;

      for (final dir in dirs) {
        if (!dir.existsSync()) continue;
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          if (entity is File) {
            final size = await entity.length().catchError((_) => 0);
            final ext = entity.path.split('.').last.toLowerCase();
            if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic'].contains(ext)) {
              photos += size;
            } else if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(ext)) {
              videos += size;
            } else if (['mp3', 'aac', 'ogg', 'wav', 'm4a', 'opus'].contains(ext)) {
              audio += size;
            } else if (['pdf', 'doc', 'docx', 'xls', 'xlsx', 'txt', 'json'].contains(ext)) {
              docs += size;
            } else {
              other += size;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _photosBytes = photos;
          _videosBytes = videos;
          _audioBytes = audio;
          _docsBytes = docs;
          _otherBytes = other;
          _totalBytes = photos + videos + audio + docs + other;
          _loadingStorage = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingStorage = false);
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  double _fraction(int bytes) {
    if (_totalBytes == 0) return 0;
    return (bytes / _totalBytes).clamp(0.0, 1.0);
  }

  Widget _buildTrailingText(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text, style: const TextStyle(color: AppColors.grey, fontSize: 14)),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: AppColors.grey, size: 20),
      ],
    );
  }

  Future<void> _showMediaDownloadPicker(
      BuildContext context, SettingsService settings, String title, String settingKey) async {
    final options = ['Off', 'Wi-Fi', 'Wi-Fi and Cellular'];
    final currentValue = settings.getSetting(settingKey, defaultValue: 'Off');
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.dark)),
            ),
            ...options.map((opt) => ListTile(
                  title: Text(opt),
                  trailing: opt == currentValue
                      ? const Icon(Icons.check, color: AppColors.orange)
                      : null,
                  onTap: () => Navigator.pop(context, opt),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (selected != null && selected != currentValue) {
      settings.updateSetting(settingKey, selected);
    }
  }

  Future<void> _showProxyDialog(
      BuildContext context, SettingsService settings) async {
    final ipController =
        TextEditingController(text: settings.getSetting('proxy_ip', defaultValue: ''));
    final portController =
        TextEditingController(text: settings.getSetting('proxy_port', defaultValue: ''));
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Proxy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: ipController,
                decoration: const InputDecoration(labelText: 'Proxy IP')),
            TextField(
                controller: portController,
                decoration: const InputDecoration(labelText: 'Proxy Port'),
                keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (result == true) {
      settings.updateSetting('proxy_ip', ipController.text.trim());
      settings.updateSetting('proxy_port', portController.text.trim());
    }
  }

  void _showManageStorage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text('Storage Usage',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                _loadingStorage ? 'Calculating...' : 'Total: ${_formatBytes(_totalBytes)}',
                style: const TextStyle(color: AppColors.grey, fontSize: 13),
              ),
              const SizedBox(height: 16),
              if (_loadingStorage)
                const Center(child: CircularProgressIndicator(color: AppColors.orange))
              else ...[
                _buildStorageRow('Photos & Videos',
                    _formatBytes(_photosBytes + _videosBytes),
                    _fraction(_photosBytes + _videosBytes)),
                _buildStorageRow(
                    'Documents', _formatBytes(_docsBytes), _fraction(_docsBytes)),
                _buildStorageRow(
                    'Audio', _formatBytes(_audioBytes), _fraction(_audioBytes)),
                _buildStorageRow(
                    'Other', _formatBytes(_otherBytes), _fraction(_otherBytes)),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total used',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatBytes(_totalBytes),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.orange)),
                  ],
                ),
                if (_totalBytes == 0) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'No media files found in app storage.',
                    style: TextStyle(color: AppColors.grey, fontSize: 12),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorageRow(String label, String size, double fraction) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontSize: 14)),
              Text(size, style: const TextStyle(fontSize: 13, color: AppColors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: fraction,
            backgroundColor: AppColors.lightGrey,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.orange),
            borderRadius: BorderRadius.circular(4),
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Storage and data'),
      body: Consumer<SettingsService>(
        builder: (context, settings, _) {
          final proxyIp = settings.getSetting('proxy_ip', defaultValue: '');
          final proxyState = proxyIp.isEmpty ? 'Off' : 'Set';
          return ListView(
            children: [
              SettingsGroup(
                header: 'Storage',
                children: [
                  SettingsItem(
                    title: 'Manage storage',
                    icon: Icons.pie_chart,
                    iconBackgroundColor: AppColors.orange,
                    subtitle: _loadingStorage
                        ? 'Calculating...'
                        : _formatBytes(_totalBytes),
                    showDivider: false,
                    onTap: _showManageStorage,
                  ),
                ],
              ),

              SettingsGroup(
                header: 'Network',
                children: [
                  SettingsItem(
                    title: 'Use less data for calls',
                    icon: Icons.data_saver_on,
                    iconBackgroundColor: AppColors.orange,
                    trailing: CupertinoSwitch(
                      value: settings.getSetting('data_less_calls', defaultValue: false),
                      activeTrackColor: AppColors.orange,
                      onChanged: (v) => settings.updateSetting('data_less_calls', v),
                    ),
                    showDivider: false,
                  ),
                  /*
                  SettingsItem(
                    title: 'Proxy',
                    icon: Icons.router,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(proxyState),
                    showDivider: false,
                    onTap: () => _showProxyDialog(context, settings),
                  ),
                  */
                ],
              ),

              SettingsGroup(
                header: 'Media auto-download',
                children: [
                  SettingsItem(
                    title: 'Photos',
                    icon: Icons.image,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(
                        settings.getSetting('media_auto_photo', defaultValue: 'Off')),
                    onTap: () => _showMediaDownloadPicker(
                        context, settings, 'Photos', 'media_auto_photo'),
                  ),
                  SettingsItem(
                    title: 'Audio',
                    icon: Icons.audiotrack,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(
                        settings.getSetting('media_auto_audio', defaultValue: 'Off')),
                    onTap: () => _showMediaDownloadPicker(
                        context, settings, 'Audio', 'media_auto_audio'),
                  ),
                  SettingsItem(
                    title: 'Video',
                    icon: Icons.videocam,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(
                        settings.getSetting('media_auto_video', defaultValue: 'Off')),
                    onTap: () => _showMediaDownloadPicker(
                        context, settings, 'Video', 'media_auto_video'),
                  ),
                  SettingsItem(
                    title: 'Documents',
                    icon: Icons.insert_drive_file,
                    iconBackgroundColor: AppColors.orange,
                    trailing: _buildTrailingText(
                        settings.getSetting('media_auto_docs', defaultValue: 'Off')),
                    showDivider: false,
                    onTap: () => _showMediaDownloadPicker(
                        context, settings, 'Documents', 'media_auto_docs'),
                  ),
                ],
              ),

              SettingsGroup(
                footer: 'Voice Messages are always automatically downloaded.',
                children: [
                  SettingsItem(
                    title: 'Reset auto-download settings',
                    icon: Icons.restore,
                    isDestructive: true,
                    showDivider: false,
                    onTap: () {
                      settings.updateSetting('media_auto_photo', 'Off');
                      settings.updateSetting('media_auto_audio', 'Off');
                      settings.updateSetting('media_auto_video', 'Off');
                      settings.updateSetting('media_auto_docs', 'Off');
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Auto-download settings reset')));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}

