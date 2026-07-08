import 'package:flutter/material.dart';
import '../theme.dart';
import 'dart:convert';
import '../services/chat_service.dart';
import 'package:provider/provider.dart';

class CreateEventScreen extends StatefulWidget {
  final String chatId;
  const CreateEventScreen({super.key, required this.chatId});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  bool _includeEndTime = false;
  bool _callLink = false;
  bool _allowGuests = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F6), // iOS system grey background
      appBar: TwibeeAppBar(
        title: 'Create event',
        centerTitle: true,
        onBack: () => Navigator.pop(context),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.dark),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final title = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : 'Event';
              final desc = _descController.text.trim();
              final data = {
                'title': title,
                'description': desc,
                'date': 'Jun 22, 2026, 8:00 PM', // Hardcoded for demo
                'call_link': _callLink,
              };
              context.read<ChatService>().sendMessage(
                chatId: widget.chatId,
                messageType: 'event',
                content: jsonEncode(data),
              );
              Navigator.pop(context);
            },
            child: const Text('Send', style: TextStyle(color: AppColors.green, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Name and Description Section
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Add event name',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                Container(
                  height: 120,
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _descController,
                    maxLines: null,
                    decoration: const InputDecoration(
                      hintText: 'Add description (optional)',
                      hintStyle: TextStyle(color: Colors.grey),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(right: 16, bottom: 8),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text('2048', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Time Section
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  title: const Text('Starts'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F6), borderRadius: BorderRadius.circular(6)),
                        child: const Text('Jun 22, 2026', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF2F2F6), borderRadius: BorderRadius.circular(6)),
                        child: const Text('8:00 PM', style: TextStyle(fontSize: 16)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: const Text('Include end time'),
                  value: _includeEndTime,
                  activeThumbColor: AppColors.green,
                  onChanged: (val) => setState(() => _includeEndTime = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Location and Call Link Section
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Add location (optional)',
                    hintStyle: TextStyle(color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
                const Divider(height: 1, indent: 16),
                SwitchListTile(
                  title: const Text('Twibee call link'), // Changed from WhatsApp to Twibee
                  value: _callLink,
                  activeThumbColor: AppColors.green,
                  onChanged: (val) => setState(() => _callLink = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reminder Section
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: const ListTile(
              title: Text('Reminder'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('1 hour before', style: TextStyle(color: Colors.grey, fontSize: 16)),
                  Icon(Icons.unfold_more, color: Colors.grey),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 24),
            child: Text('Guests also get notified at the time of the event.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),

          // Guests Section
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: SwitchListTile(
              title: const Text('Allow guests'),
              value: _allowGuests,
              activeThumbColor: AppColors.green,
              onChanged: (val) => setState(() => _allowGuests = val),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 24),
            child: Text('Allow people to bring one additional guest.', style: TextStyle(color: Colors.grey, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

