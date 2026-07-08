import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:provider/provider.dart';

import '../../services/chat_service.dart';
import '../../services/channel_service.dart';
import '../../theme.dart';
import '../../screens/media_preview_edit_screen.dart';
import '../../screens/location_picker_screen.dart';
import '../../screens/share_contacts_screen.dart';
import '../../screens/create_poll_screen.dart';
import '../../screens/create_event_screen.dart';

class AttachmentMenuBottomSheet {
  static Future<void> _sendMessage(
    BuildContext context,
    String chatId,
    String messageType,
    String? content,
    String? mediaUrl,
    String? replyToId,
    bool isChannel,
  ) async {
    if (isChannel) {
      await ChannelService().createPost(
        channelId: chatId,
        text: content,
        mediaFile: mediaUrl != null ? File(mediaUrl) : null,
        mediaType: messageType,
        replyToId: replyToId,
      );
    } else {
      await context.read<ChatService>().sendMessage(
        chatId: chatId,
        messageType: messageType,
        content: content,
        mediaUrl: mediaUrl,
        replyToId: replyToId,
      );
    }
  }

  static void show(
    BuildContext context, 
    String chatId, 
    String? replyingToMessageId,
    VoidCallback onAttachmentSent, {
    bool isChannel = false,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
          decoration: BoxDecoration(
            color: const Color(0xFFEFEFEF),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAttachmentIcon(Icons.image, Colors.blue, 'Photos', () async {
                    Navigator.pop(context);
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
                          builder: (_) => MediaPreviewEditScreen(initialAssets: assets, chatId: chatId, isChannel: isChannel),
                        ),
                      );
                      onAttachmentSent();
                    }
                  }),
                  _buildAttachmentIcon(Icons.camera_alt, Colors.blueGrey, 'Camera', () async {
                    Navigator.pop(context);
                    final file = await ImagePicker().pickImage(source: ImageSource.camera);
                    if (file != null && context.mounted) {
                      _sendMessage(context, chatId, 'image', '', file.path, null, isChannel);
                      onAttachmentSent();
                    }
                  }),
                  _buildAttachmentIcon(Icons.location_on, Colors.green, 'Location', () async {
                    Navigator.pop(context);
                    final locationData = await Navigator.push(context, MaterialPageRoute(builder: (_) => const LocationPickerScreen()));
                    if (locationData != null && context.mounted) {
                      _sendMessage(context, chatId, 'location', locationData as String, null, replyingToMessageId, isChannel);
                      onAttachmentSent();
                    }
                  }),
                  _buildAttachmentIcon(Icons.person, Colors.grey, 'Contact', () async {
                    Navigator.pop(context);
                    final contactData = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShareContactsScreen()));
                    if (contactData != null && context.mounted) {
                      _sendMessage(context, chatId, 'contact', contactData as String, null, replyingToMessageId, isChannel);
                      onAttachmentSent();
                    }
                  }),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildAttachmentIcon(Icons.insert_drive_file, Colors.blueAccent, 'Document', () async {
                    Navigator.pop(context);
                    FilePickerResult? result = await FilePicker.platform.pickFiles();
                    if (result != null && context.mounted) {
                      _sendMessage(context, chatId, 'document', result.files.single.name, result.files.single.path, replyingToMessageId, isChannel);
                      onAttachmentSent();
                    }
                  }),
                  _buildAttachmentIcon(Icons.poll, Colors.orange, 'Poll', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePollScreen(chatId: chatId)));
                  }),
                  _buildAttachmentIcon(Icons.event, Colors.pink, 'Event', () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateEventScreen(chatId: chatId)));
                  }),
                  _buildAttachmentIcon(Icons.headset, Colors.deepOrange, 'Audio', () async {
                    Navigator.pop(context);
                    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.audio);
                    if (result != null && context.mounted) {
                      _sendMessage(context, chatId, 'audio', result.files.single.name, result.files.single.path, replyingToMessageId, isChannel);
                      onAttachmentSent();
                    }
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildAttachmentIcon(IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF2E2E2E),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

