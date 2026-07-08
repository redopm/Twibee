import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/chat_service.dart';
import '../theme.dart';

// ---------------------------------------------------------
// Manage Storage Screen
// ---------------------------------------------------------
class ManageStorageScreen extends StatefulWidget {
  final String contactName;
  final String? chatId;
  const ManageStorageScreen({super.key, required this.contactName, this.chatId});

  @override
  State<ManageStorageScreen> createState() => _ManageStorageScreenState();
}

class _ManageStorageScreenState extends State<ManageStorageScreen> {
  List<Map<String, dynamic>> _media = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    if (widget.chatId == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final chatService = context.read<ChatService>();
      final messages = await chatService.getChatMedia(widget.chatId!);
      
      final media = <Map<String, dynamic>>[];
      for (var msg in messages) {
        if (msg['message_type'] == 'image' || msg['message_type'] == 'video') {
          media.add(msg);
        }
      }
      
      if (mounted) {
        setState(() {
          _media = media;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSortSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Sort by', style: TextStyle(color: AppColors.grey, fontSize: 13)),
              ),
              ListTile(title: const Text('Newest'), onTap: () => Navigator.pop(context)),
              ListTile(title: const Text('Oldest'), onTap: () => Navigator.pop(context)),
              ListTile(title: const Text('Largest'), onTap: () => Navigator.pop(context)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: TwibeeAppBar(
        title: widget.contactName,
        centerTitle: true,
        actions: [
          TextButton(onPressed: () {}, child: const Text('Select', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Size', style: TextStyle(color: AppColors.dark)),
                GestureDetector(
                  onTap: () => _showSortSheet(context),
                  child: const Icon(Icons.sort, color: AppColors.dark),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
                : _media.isEmpty
                    ? const Center(child: Text('No media found', style: TextStyle(color: AppColors.grey)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(2),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        itemCount: _media.length,
                        itemBuilder: (context, index) {
                          final item = _media[index];
                          return Container(
                            color: AppColors.lightGrey,
                            child: item['media_url'] != null
                                ? Image.network(item['media_url'], fit: BoxFit.cover)
                                : const Icon(Icons.image, color: AppColors.grey),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}



// ---------------------------------------------------------
// Notifications Screen
// ---------------------------------------------------------
class NotificationsScreen extends StatefulWidget {
  final String contactName;
  const NotificationsScreen({super.key, required this.contactName});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _muteStatus = 'No';
  String _alertTone = 'Default (Note)';

  void _showMuteSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    const Text('Mute notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text('Other members will not see that you muted this chat, and you will still be notified if you are mentioned.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.grey)),
              ),
              _buildMuteOption('None'),
              _buildMuteOption('8 hours'),
              _buildMuteOption('1 week'),
              _buildMuteOption('Always'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMuteOption(String title) {
    bool isSelected = _muteStatus == title || (_muteStatus == 'No' && title == 'None');
    return ListTile(
      leading: isSelected ? const Icon(Icons.check, color: AppColors.green) : const SizedBox(width: 24),
      title: Text(title),
      onTap: () {
        setState(() => _muteStatus = title == 'None' ? 'No' : title);
        Navigator.pop(context);
      },
    );
  }

  void _showAlertToneSheet() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => AlertTonesScreen(currentTone: _alertTone, onSelect: (t) { setState(() => _alertTone = t); })));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Notifications',
        subtitle: widget.contactName,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Messages', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    title: const Text('Mute notifications'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_muteStatus, style: const TextStyle(color: AppColors.grey)),
                        const Icon(Icons.chevron_right, color: AppColors.grey),
                      ],
                    ),
                    onTap: _showMuteSheet,
                  ),
                  const Divider(height: 1, indent: 16),
                  ListTile(
                    title: const Text('Alert tone'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_alertTone, style: const TextStyle(color: AppColors.grey)),
                        const Icon(Icons.chevron_right, color: AppColors.grey),
                      ],
                    ),
                    onTap: _showAlertToneSheet,
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

class AlertTonesScreen extends StatelessWidget {
  final String currentTone;
  final Function(String) onSelect;
  
  AlertTonesScreen({super.key, required this.currentTone, required this.onSelect});

  final List<String> tones = ['Default (Note)', 'None', 'Aurora', 'Bamboo', 'Chord', 'Circles', 'Complete', 'Hello', 'Input', 'Keys', 'Popcorn', 'Pulse', 'Synth'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Sound',
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: const Icon(Icons.close, color: AppColors.dark, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Save', style: TextStyle(color: AppColors.dark, fontWeight: FontWeight.bold))),
        ],
      ),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Alert tones', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Container(
            color: Colors.white,
            child: Column(
              children: tones.map((tone) => Column(
                children: [
                  ListTile(
                    leading: tone == currentTone ? const Icon(Icons.check, color: AppColors.green) : const SizedBox(width: 24),
                    title: Text(tone),
                    onTap: () {
                      onSelect(tone);
                      Navigator.pop(context);
                    },
                  ),
                  if (tone != tones.last) const Divider(height: 1, indent: 56),
                ],
              )).toList(),
            ),
          )
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
// Disappearing Messages Screen
// ---------------------------------------------------------
class DisappearingMessagesScreen extends StatefulWidget {
  final String chatId;
  final String contactName;
  const DisappearingMessagesScreen({super.key, required this.chatId, required this.contactName});

  @override
  State<DisappearingMessagesScreen> createState() => _DisappearingMessagesScreenState();
}

class _DisappearingMessagesScreenState extends State<DisappearingMessagesScreen> {
  String _selectedTimer = 'Off';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchSetting();
  }

  Future<void> _fetchSetting() async {
    try {
      final chatData = await Supabase.instance.client
          .from('chats')
          .select('settings')
          .eq('id', widget.chatId)
          .maybeSingle();
          
      if (chatData != null && chatData['settings'] != null) {
        final timer = chatData['settings']['disappearing_timer'];
        if (timer == 24) _selectedTimer = '24 Hours';
        else if (timer == 168) _selectedTimer = '7 Days';
        else if (timer == 2160) _selectedTimer = '90 Days';
        else _selectedTimer = 'Off';
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _updateTimer(String label, int hours) async {
    setState(() {
      _selectedTimer = label;
    });
    await context.read<ChatService>().updateChatDbSetting(widget.chatId, 'disappearing_timer', hours);
    // Send system message
    if (hours > 0) {
      await context.read<ChatService>().sendMessage(
        chatId: widget.chatId,
        messageType: 'event',
        content: 'You turned on disappearing messages. All new messages will disappear from this chat after $label.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Disappearing messages',
        subtitle: 'You, ${widget.contactName}',
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Icon(Icons.timer_outlined, size: 100, color: AppColors.green), // Dummy icon for illustration
              ),
              const SizedBox(height: 24),
              const Text('Make messages in this chat disappear', style: TextStyle(color: AppColors.dark, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text(
                'For more privacy and storage, all new messages will disappear from this chat for everyone after the selected duration, except when kept. Anyone in the chat can change this setting.',
                style: TextStyle(color: AppColors.grey),
              ),
              const SizedBox(height: 24),
              const Text('Message timer', style: TextStyle(color: AppColors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      {'label': '24 Hours', 'hours': 24},
                      {'label': '7 Days', 'hours': 168},
                      {'label': '90 Days', 'hours': 2160},
                      {'label': 'Off', 'hours': 0},
                    ].map((timerObj) {
                      final label = timerObj['label'] as String;
                      final hours = timerObj['hours'] as int;
                      return Column(
                        children: [
                          ListTile(
                            title: Text(label),
                            trailing: _selectedTimer == label ? const Icon(Icons.check, color: AppColors.green) : null,
                            onTap: () => _updateTimer(label, hours),
                          ),
                          if (label != 'Off') const Divider(height: 1, indent: 16),
                        ],
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Advanced Chat Privacy Screen
// ---------------------------------------------------------
class AdvancedChatPrivacyScreen extends StatefulWidget {
  const AdvancedChatPrivacyScreen({super.key});

  @override
  State<AdvancedChatPrivacyScreen> createState() => _AdvancedChatPrivacyScreenState();
}

class _AdvancedChatPrivacyScreenState extends State<AdvancedChatPrivacyScreen> {
  bool _isAdvancedEnabled = false;

  void _showInfoModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: AppColors.grey.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 20),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const Text('All chats are private by default', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                const Text('Your personal messages are always protected with end-to-end encryption.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.dark)),
                const SizedBox(height: 24),
                const ListTile(
                  leading: Icon(Icons.block, color: AppColors.dark),
                  title: Text('Meta AI can\'t access your chats. It can only read the messages people choose to send it, nothing else.'),
                ),
                const ListTile(
                  leading: Icon(Icons.toggle_on_outlined, color: AppColors.dark),
                  title: Text('This is true whether advanced chat privacy is ON or OFF.'),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                    onPressed: () => Navigator.pop(context),
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Text('Got it', style: TextStyle(color: Colors.white))),
                  ),
                ),
                TextButton(onPressed: () {}, child: const Text('Learn more', style: TextStyle(color: AppColors.dark))),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(
        title: 'Advanced chat privacy',
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: _showInfoModal,
                      child: RichText(
                        text: const TextSpan(
                          style: TextStyle(color: AppColors.dark, fontSize: 14),
                          children: [
                            TextSpan(text: 'All chats are private by default. '),
                            TextSpan(text: 'This is true whether you turn this setting on or not. ', style: TextStyle(fontWeight: FontWeight.bold)),
                            TextSpan(text: 'Learn more', style: TextStyle(color: AppColors.green)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Icon(Icons.lock_outline, size: 60, color: AppColors.green),
            const SizedBox(height: 16),
            const Text('Limit how messages and media from this chat can be shared outside of Twibee', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const ListTile(
              leading: Icon(Icons.image_outlined),
              title: Text("Can't save media to their device gallery automatically"),
            ),
            const ListTile(
              leading: Icon(Icons.smart_toy_outlined),
              title: Text("Can't ask Meta AI questions, or to create images or summaries in this chat"),
            ),
            const ListTile(
              leading: Icon(Icons.upload_outlined),
              title: Text("Can't export the chat"),
            ),
            const SizedBox(height: 24),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: SwitchListTile(
                title: const Text('Advanced chat privacy'),
                value: _isAdvancedEnabled,
                onChanged: (val) => setState(() => _isAdvancedEnabled = val),
                activeThumbColor: AppColors.green,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// Encryption Screen
// ---------------------------------------------------------
class EncryptionScreen extends StatelessWidget {
  final String contactName;
  const EncryptionScreen({super.key, required this.contactName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: TwibeeAppBar(
        title: 'Verify Encryption',
        subtitle: 'You, $contactName',
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.upload_outlined, color: AppColors.dark, size: 16),
            ),
            onPressed: () {},
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.qr_code_2, size: 150, color: AppColors.dark),
            ),
            const SizedBox(height: 24),
            Text(
              'To verify that messages and calls with $contactName are end-to-end encrypted, scan this code on their device. You can also compare the number above.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: List.generate(12, (index) {
                  return Text(
                    (12345 + index * 11111).toString().substring(0, 5),
                    style: const TextStyle(color: AppColors.dark, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w500),
                  );
                }),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scanning code...')));
                },
                child: const Text('Scan Code', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

