import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:add_2_calendar/add_2_calendar.dart';

import '../../theme.dart';
import '../../services/chat_service.dart';
import '../chat/signed_image_widget.dart';
import '../chat/signed_audio_widget.dart';
import '../chat/video_thumbnail_widget.dart';
import '../chat/tail_painter.dart';
import '../../screens/media_viewer_screen.dart';
import '../../screens/pdf_viewer_screen.dart';
import '../../screens/video_viewer_screen.dart';
import '../../screens/map_viewer_screen.dart';
import '../../screens/individual_chat_screen.dart'; // for routing
import '../../utils/download_helper.dart';

class MessageBubbleWidget extends StatefulWidget {
  final String text;
  final String time;
  final bool isMe;
  final String messageType;
  final String? mediaUrl;
  final String? messageId;
  final Map<String, dynamic>? replyMarkup;
  final Map<String, dynamic>? rawMsg;
  final Map<String, dynamic>? replyToMsg;
  final bool isGroupedBottom;
  final Color bubbleColor;
  final Color receiverBubbleColor;
  final Color senderTextColor;
  final Color receiverTextColor;
  final Color timeColor;
  final bool isPending;
  final bool isRead;
  final int? viewCount;
  final String chatName;
  final String? chatId;
  final String? otherUserId;
  final String fontFamily;
  final Function(Map<String, dynamic>)? onReply;
  final Function(Map<String, dynamic>)? onForward;
  final Function(String)? onScrollToMessage;
  final Function(String)? onBotCommand;
  final String? senderName;
  final List<Map<String, dynamic>> reactions;
  final bool isForwarded;
  final bool isEdited;
  final bool isStarred;
  final Function(String, String)? onReactionTap;

  const MessageBubbleWidget({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    this.messageType = 'text',
    this.mediaUrl,
    this.messageId,
    this.replyMarkup,
    this.rawMsg,
    this.replyToMsg,
    this.isGroupedBottom = false,
    this.bubbleColor = const Color(0xFFFACC15),
    this.receiverBubbleColor = const Color(0xFFFFFFFF),
    this.senderTextColor = const Color(0xFF1E293B),
    this.receiverTextColor = const Color(0xFF334155),
    this.timeColor = const Color(0xFF94A3B8),
    this.isPending = false,
    this.isRead = false,
    this.viewCount,
    this.chatName = '',
    this.chatId,
    this.otherUserId,
    this.fontFamily = 'Inter',
    this.onReply,
    this.onForward,
    this.onScrollToMessage,
    this.onBotCommand,
    this.senderName,
    this.reactions = const [],
    this.isForwarded = false,
    this.isEdited = false,
    this.isStarred = false,
    this.onReactionTap,
  });

  @override
  State<MessageBubbleWidget> createState() => _MessageBubbleWidgetState();
}

class _MessageBubbleWidgetState extends State<MessageBubbleWidget> {
  // We rename the extracted method from _buildMessage to build
  Widget _buildParsedText(String text, TextStyle defaultStyle, bool isMe) {
    final regex = RegExp(r'(@[a-zA-Z0-9_]+)');
    final matches = regex.allMatches(text);
    
    if (matches.isEmpty) {
      return Text(text, textAlign: TextAlign.left, style: defaultStyle);
    }
    
    final List<TextSpan> spans = [];
    int lastMatchEnd = 0;
    
    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: text.substring(lastMatchEnd, match.start), style: defaultStyle));
      }
      
      final mentionStyle = defaultStyle.copyWith(
        fontWeight: FontWeight.bold,
        color: isMe ? Colors.white : AppColors.orange,
      );
      
      spans.add(TextSpan(text: match.group(0), style: mentionStyle));
      lastMatchEnd = match.end;
    }
    
    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastMatchEnd), style: defaultStyle));
    }
    
    return Text.rich(
      TextSpan(children: spans),
      textAlign: TextAlign.left,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Mapping widget properties to local variables for the extracted code
    final text = widget.text;
    final time = widget.time;
    final isMe = widget.isMe;
    String messageType = widget.messageType;
    final mediaUrl = widget.mediaUrl;
    
    if (messageType == 'document' && mediaUrl != null) {
      final lowerUrl = mediaUrl.toLowerCase();
      if (lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg') || lowerUrl.endsWith('.png') || lowerUrl.endsWith('.gif') || lowerUrl.endsWith('.webp')) {
        messageType = 'image';
      } else if (lowerUrl.endsWith('.mp4') || lowerUrl.endsWith('.mov') || lowerUrl.endsWith('.mkv') || lowerUrl.endsWith('.avi')) {
        messageType = 'video';
      }
    }

    final messageId = widget.messageId;
    final replyMarkup = widget.replyMarkup;
    final rawMsg = widget.rawMsg;
    final replyToMsg = widget.replyToMsg;
    final isGroupedBottom = widget.isGroupedBottom;
    final actualBubbleColor = isMe ? widget.bubbleColor : widget.receiverBubbleColor;
    final textColor = isMe ? widget.senderTextColor : widget.receiverTextColor;
    final timeColor = isMe ? widget.senderTextColor.withOpacity(0.8) : widget.timeColor;
    final isPending = widget.isPending;
    final fontFamily = widget.fontFamily;

    bool isStatusReply = false;
    Map<String, dynamic>? statusData;
    String displayText = text;

    final isDeleted = rawMsg?['is_deleted_for_everyone'] == true;
    if (isDeleted) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
              bottom: 4, top: 4, left: isMe ? 60 : 10, right: isMe ? 10 : 60),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? widget.bubbleColor.withValues(alpha: 0.5) : widget.receiverBubbleColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'This message was deleted',
                  style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (messageType == 'text' && text.startsWith('{') && text.contains('"is_status_reply":true')) {
      try {
        final data = jsonDecode(text) as Map<String, dynamic>;
        if (data['is_status_reply'] == true) {
          isStatusReply = true;
          statusData = data;
          displayText = data['text'] ?? '';
        }
      } catch (_) {}
    }

    return DefaultTextStyle.merge(
      style: GoogleFonts.getFont(fontFamily),
      child: SwipeTo(
      key: ValueKey(
          messageId ?? rawMsg?['id']?.toString() ?? UniqueKey().toString()),
      iconOnRightSwipe: Icons.reply,
      onRightSwipe: (details) {
        if (rawMsg != null) if (widget.onReply != null) widget.onReply!(rawMsg);
      },
      iconOnLeftSwipe: Icons.shortcut,
      onLeftSwipe: (details) {
        if (rawMsg != null) if (widget.onForward != null) widget.onForward!(rawMsg);
      },
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: EdgeInsets.only(
              bottom: 2, top: 2, left: isMe ? 60 : 10, right: isMe ? 10 : 60),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [

              Flexible(
                child: GestureDetector(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: widget.reactions.isNotEmpty ? 14.0 : 0,
                          ),
                          child: Container(
                      padding: EdgeInsets.all((messageType == 'image' ||
                            messageType == 'video' ||
                            messageType == 'location')
                        ? 4
                        : 8),
                      decoration: BoxDecoration(
                        color: actualBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(!isMe && !isGroupedBottom ? 4 : 20),
                        bottomRight: Radius.circular(isMe && !isGroupedBottom ? 4 : 20),
                      ),
                      boxShadow: [
                        if (!isMe)
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2))
                      ],
                    ),
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.isForwarded)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2, left: 4),
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Icon(Icons.shortcut, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Forwarded',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 11,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isMe && widget.senderName != null && !isGroupedBottom)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2, left: 4),
                              child: Text(
                                widget.senderName!,
                                style: TextStyle(
                                  color: AppColors.orange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          if (isStatusReply && statusData != null)
                            _buildStatusQuotedBubble(statusData),
                          if (replyToMsg != null)
                            _buildQuotedBubble(replyToMsg),
                          if (messageType == 'image' && mediaUrl != null)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () async {
                                  final sName = isMe ? 'You' : widget.chatName;
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => MediaViewerScreen(
                                        initialMediaUrl: mediaUrl,
                                        initialMessageType: 'image',
                                        senderName: sName,
                                        time: time,
                                        chatId: widget.chatId ?? '',
                                        messageId:
                                            rawMsg?['id']?.toString() ?? '',
                                      ),
                                    ),
                                  );
                                  if (result == 'reply' &&
                                      mounted &&
                                      rawMsg != null) {
                                    if (widget.onReply != null) widget.onReply!(rawMsg);
                                  }
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: MediaQuery.of(context).size.width * 0.55,
                                      maxWidth: MediaQuery.of(context).size.width * 0.6,
                                      minHeight: 150,
                                      maxHeight: 250,
                                    ),
                                    child: SignedImageWidget(
                                      mediaUrl: mediaUrl,
                                      chatService: Provider.of<ChatService>(context, listen: false),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (messageType == 'audio' && mediaUrl != null)
                            Align(
                                alignment: Alignment.centerLeft,
                                child: SignedAudioWidget(
                                  mediaUrl: mediaUrl,
                                  chatService: Provider.of<ChatService>(context, listen: false),
                                ))
                          else if (messageType == 'document')
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () async {
                                  if (mediaUrl != null) {
                                    final url = await context
                                        .read<ChatService>()
                                        .getMediaSignedUrl(mediaUrl);
                                    if (url != null) {
                                      final lowerUrl = url.toLowerCase();
                                      if (lowerUrl.endsWith('.pdf')) {
                                        if (!context.mounted) return;
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => PdfViewerScreen(
                                                    pathOrUrl: url,
                                                    title: text)));
                                      } else if (lowerUrl.endsWith('.jpg') || lowerUrl.endsWith('.jpeg') || lowerUrl.endsWith('.png') || lowerUrl.endsWith('.gif') || lowerUrl.endsWith('.webp')) {
                                        if (!context.mounted) return;
                                        final sName = isMe ? 'You' : widget.chatName;
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => MediaViewerScreen(
                                                    initialMediaUrl: url,
                                                    initialMessageType: 'image',
                                                    senderName: sName,
                                                    time: widget.time,
                                                    chatId: widget.chatId ?? '',
                                                    messageId: widget.messageId ?? '')));
                                      } else if (lowerUrl.endsWith('.mp4') || lowerUrl.endsWith('.mov') || lowerUrl.endsWith('.mkv') || lowerUrl.endsWith('.avi')) {
                                        if (!context.mounted) return;
                                        final sName = isMe ? 'You' : widget.chatName;
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (_) => VideoViewerScreen(
                                                    videoUrl: url,
                                                    senderName: sName,
                                                    time: widget.time)));
                                      } else {
                                        final uri = Uri.parse(url);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .inAppBrowserView);
                                        }
                                      }
                                    }
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      borderRadius: BorderRadius.circular(8)),
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 240),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                            text.toLowerCase().endsWith('.pdf')
                                                ? Icons.picture_as_pdf
                                                : (text
                                                            .toLowerCase()
                                                            .endsWith('.xls') ||
                                                        text
                                                            .toLowerCase()
                                                            .endsWith(
                                                                '.xlsx') ||
                                                        text
                                                            .toLowerCase()
                                                            .endsWith('.csv'))
                                                    ? Icons.table_chart
                                                    : (text
                                                                .toLowerCase()
                                                                .endsWith(
                                                                    '.doc') ||
                                                            text
                                                                .toLowerCase()
                                                                .endsWith(
                                                                    '.docx') ||
                                                            text
                                                                .toLowerCase()
                                                                .endsWith(
                                                                    '.txt'))
                                                        ? Icons.description
                                                        : (text
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                        '.zip') ||
                                                                text
                                                                    .toLowerCase()
                                                                    .endsWith(
                                                                        '.rar'))
                                                            ? Icons.folder_zip
                                                            : Icons
                                                                .insert_drive_file,
                                            color: isMe
                                                ? AppColors.orange
                                                : AppColors.dark,
                                            size: 30),
                                        const SizedBox(width: 8),
                                        Flexible(
                                            child: Text(
                                                text.isNotEmpty
                                                    ? text
                                                    : 'Document',
                                                style: const TextStyle(
                                                    color: AppColors.dark,
                                                    fontWeight:
                                                        FontWeight.bold),
                                                maxLines: 2,
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                        if (!isMe) ...[
                                          const SizedBox(width: 8),
                                          FutureBuilder<bool>(
                                            future: DownloadHelper.isFileDownloaded(text.isNotEmpty ? text : 'document'),
                                            builder: (context, snapshot) {
                                              if (snapshot.connectionState == ConnectionState.waiting) {
                                                return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
                                              }
                                              final isDownloaded = snapshot.data ?? false;
                                              if (isDownloaded) return const SizedBox.shrink();

                                              return GestureDetector(
                                                onTap: () async {
                                                  if (mediaUrl != null) {
                                                    final url = await context.read<ChatService>().getMediaSignedUrl(mediaUrl);
                                                    if (url != null && context.mounted) {
                                                      await DownloadHelper.downloadToGalleryOrDocuments(context, url, text.isNotEmpty ? text : 'document');
                                                      if (context.mounted) {
                                                        // Force a rebuild to hide the icon after download
                                                        (context as Element).markNeedsBuild();
                                                      }
                                                    }
                                                  }
                                                },
                                                child: const Icon(Icons.download, color: AppColors.dark, size: 24),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else if (messageType == 'location')
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Builder(
                                builder: (context) {
                                  final lines = text
                                      .replaceFirst('place:', '')
                                      .trim()
                                      .split('\n');
                                  String mapsUrl = '';
                                  for (var i = lines.length - 1; i >= 0; i--) {
                                    if (lines[i].trim().startsWith('http')) {
                                      mapsUrl = lines[i].trim();
                                      break;
                                    }
                                  }
                                  String? lat;
                                  String? lng;
                                  if (text.startsWith('live_location:')) {
                                    final parts = text.split(':')[1].split(',');
                                    if (parts.length == 2) {
                                      lat = parts[0];
                                      lng = parts[1];
                                    }
                                  } else {
                                    final coordMatch =
                                        RegExp(r'[?&]q=([-\d.]+),([-\d.]+)')
                                            .firstMatch(mapsUrl);
                                    lat = coordMatch?.group(1);
                                    lng = coordMatch?.group(2);
                                  }

                                  return GestureDetector(
                                    onTap: () async {
                                      if (lat != null && lng != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => MapViewerScreen(
                                              lat: double.parse(lat!),
                                              lng: double.parse(lng!),
                                              title: 'Location',
                                              subtitle: '',
                                            ),
                                          ),
                                        );
                                      } else if (mapsUrl.isNotEmpty) {
                                        final uri = Uri.parse(mapsUrl);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        }
                                      } else if (text.isNotEmpty) {
                                        final query = Uri.encodeComponent(
                                            text.startsWith('place:')
                                                ? text.substring(6)
                                                : text);
                                        final uri = Uri.parse(
                                            'https://maps.google.com/?q=$query');
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode
                                                  .externalApplication);
                                        }
                                      }
                                    },
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (lat != null && lng != null)
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            child: SizedBox(
                                              height: 160,
                                              width: 250,
                                              child: AbsorbPointer(
                                                child: GoogleMap(
                                                  initialCameraPosition:
                                                      CameraPosition(
                                                    target: LatLng(
                                                        double.parse(lat),
                                                        double.parse(lng)),
                                                    zoom: 15,
                                                  ),
                                                  markers: {
                                                    Marker(
                                                      markerId: const MarkerId(
                                                          'preview'),
                                                      position: LatLng(
                                                          double.parse(lat),
                                                          double.parse(lng)),
                                                    )
                                                  },
                                                  zoomControlsEnabled: false,
                                                  myLocationButtonEnabled:
                                                      false,
                                                  mapToolbarEnabled: false,
                                                ),
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            width: 250,
                                            decoration: BoxDecoration(
                                                color: AppColors.lightGrey,
                                                borderRadius:
                                                    BorderRadius.circular(12)),
                                            child: Padding(
                                              padding: const EdgeInsets.all(12),
                                              child: Column(
                                                children: [
                                                  const Icon(Icons.location_on,
                                                      color: AppColors.orange,
                                                      size: 40),
                                                  if (text.isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Text(
                                                      text.startsWith('place:')
                                                          ? text.substring(6)
                                                          : text,
                                                      style: const TextStyle(
                                                          color: AppColors.dark,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 14),
                                                      textAlign:
                                                          TextAlign.center,
                                                    ),
                                                  ]
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            )
                          else if (messageType == 'contact')
                            Builder(builder: (context) {
                              String name = 'Contact';
                              String phone = '';
                              String initial = 'C';
                              try {
                                final data = jsonDecode(text);
                                name = data['name'] ?? 'Contact';
                                phone = data['phone'] ?? '';
                                initial = name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'C';
                              } catch (_) {
                                name = text;
                                initial = name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : 'C';
                              }
                              return Container(
                                width: 240,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                            radius: 20,
                                            backgroundColor: Colors.pink,
                                            child: Text(initial,
                                                style: const TextStyle(
                                                    color: AppColors.white,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(name,
                                                    style: const TextStyle(
                                                        color: AppColors.dark,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 16),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                                if (phone.isNotEmpty)
                                                  Text(phone,
                                                      style: const TextStyle(
                                                          color: AppColors.grey,
                                                          fontSize: 12)),
                                              ]),
                                        )
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1),
                                    InkWell(
                                      onTap: () async {
                                        if (phone.isEmpty) return;

                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(SnackBar(
                                                content:
                                                    Text('Checking $name...'),
                                                duration: const Duration(
                                                    seconds: 1)));

                                        try {
                                          final chatService =
                                              Provider.of<ChatService>(context, listen: false);
                                          final supabase =
                                              chatService.supabaseClient;

                                          String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
                                          if (digitsOnly.length > 10) {
                                            digitsOnly = digitsOnly.substring(digitsOnly.length - 10);
                                          }

                                          final response = await supabase
                                              .from('profiles')
                                              .select('id, name, phone_number')
                                              .like('phone_number', '%$digitsOnly%')
                                              .maybeSingle();

                                          if (response != null &&
                                              response['id'] != null) {
                                            final targetUserId =
                                                response['id'] as String;
                                            final targetUserName =
                                                response['name'] ?? name;
                                            final newChatId = await chatService
                                                .createChat(targetUserId);

                                            if (context.mounted) {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      IndividualChatScreen(
                                                    chatId: newChatId,
                                                    chatName: targetUserName,
                                                    otherUserId: targetUserId,
                                                  ),
                                                ),
                                              );
                                            }
                                          } else {
                                            if (context.mounted) {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: const Text(
                                                      'User Not Found'),
                                                  content: Text(
                                                      '$name is not on the app yet. Would you like to invite them?'),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child: const Text(
                                                          'Cancel',
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .grey)),
                                                    ),
                                                    TextButton(
                                                      onPressed: () async {
                                                        Navigator.pop(context);
                                                        final body =
                                                            Uri.encodeComponent(
                                                                "Hey! Join me on the Twibee app to chat!");
                                                        final uri = Uri.parse(
                                                            'sms:$phone?body=$body');
                                                        try {
                                                          await launchUrl(uri);
                                                        } catch (e) {
                                                          if (context.mounted) {
                                                            ScaffoldMessenger
                                                                    .of(context)
                                                                .showSnackBar(
                                                                    const SnackBar(
                                                                        content:
                                                                            Text('Could not open messaging app.')));
                                                          }
                                                        }
                                                      },
                                                      child: const Text(
                                                          'Invite',
                                                          style: TextStyle(
                                                              color: AppColors
                                                                  .orange,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(SnackBar(
                                                    content:
                                                        Text('Error: $e')));
                                          }
                                        }
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Center(
                                            child: Text('Message',
                                                style: TextStyle(
                                                    color: AppColors.dark,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            })
                          else if (messageType == 'poll')
                            Builder(builder: (context) {
                              int? selectedIndex;
                              String question = 'Poll';
                              List<String> options = ['Option 1', 'Option 2'];
                              bool isClosed = false;
                              Map<String, dynamic> votes = {};
                              try {
                                final data =
                                    jsonDecode(text) as Map<String, dynamic>;
                                question =
                                    data['question']?.toString() ?? 'Poll';
                                options = (data['options'] as List?)
                                        ?.map((e) => e.toString())
                                        .toList() ??
                                    [];
                                isClosed = rawMsg?['is_closed'] == true;
                                if (data['votes'] != null) {
                                  votes =
                                      Map<String, dynamic>.from(data['votes']);
                                }
                                final currentUserId =
                                    Provider.of<ChatService>(context, listen: false).currentUserId;
                                if (votes.containsKey(currentUserId)) {
                                  selectedIndex = votes[currentUserId] as int?;
                                }
                              } catch (_) {}
                              return Container(
                                width: 260,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(question,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.dark)),
                                    const SizedBox(height: 12),
                                    ...List.generate(options.length, (index) {
                                      final isSelected = selectedIndex == index;
                                      int voteCount = votes.values
                                          .where((v) => v == index)
                                          .length;
                                      return InkWell(
                                        onTap: isClosed
                                            ? null
                                            : () {
                                                final msgId = rawMsg?['id'];
                                                if (msgId != null) {
                                                  setState(() {
                                                    votes[context
                                                            .read<ChatService>()
                                                            .currentUserId] =
                                                        index;
                                                    try {
                                                      final data =
                                                          jsonDecode(text)
                                                              as Map<String,
                                                                  dynamic>;
                                                      data['votes'] = votes;
                                                      rawMsg!['content'] =
                                                          jsonEncode(data);
                                                    } catch (_) {}
                                                  });
                                                  context
                                                      .read<ChatService>()
                                                      .voteOnPoll(
                                                          msgId,
                                                          widget.chatId!,
                                                          index);
                                                }
                                              },
                                        child: _buildPollOption(
                                            '${options[index]} ($voteCount)',
                                            isSelected: isSelected),
                                      );
                                    }),
                                    const SizedBox(height: 8),
                                    if (isClosed)
                                      const Text('Poll closed',
                                          style: TextStyle(
                                              color: Colors.red, fontSize: 12))
                                    else
                                      Text('${votes.length} votes',
                                          style: const TextStyle(
                                              color: AppColors.grey,
                                              fontSize: 12)),
                                  ],
                                ),
                              );
                            })
                          else if (messageType == 'event')
                            GestureDetector(
                              onTap: () {
                                String title = 'Event';
                                String desc = '';
                                String date = '';
                                try {
                                  final data = jsonDecode(text);
                                  title = data['title'] ?? 'Event';
                                  desc = data['description'] ?? '';
                                  date = data['date'] ?? '';
                                } catch (_) {}
                                showDialog(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                            title: Text(title),
                                            content: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (date.isNotEmpty)
                                                    Text('Date: $date',
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold)),
                                                  if (date.isNotEmpty)
                                                    const SizedBox(height: 8),
                                                  Text(desc.isNotEmpty
                                                      ? desc
                                                      : 'No details available'),
                                                ]),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  DateTime? eventDate;
                                                  try {
                                                    eventDate =
                                                        DateTime.parse(date);
                                                  } catch (_) {
                                                    eventDate = DateTime.now();
                                                  }
                                                  final Event event = Event(
                                                    title: title,
                                                    description: desc,
                                                    startDate: eventDate,
                                                    endDate: eventDate.add(
                                                        const Duration(
                                                            hours: 1)),
                                                  );
                                                  Add2Calendar.addEvent2Cal(
                                                      event);
                                                  Navigator.pop(context);
                                                },
                                                child: const Text(
                                                    'Add to Calendar',
                                                    style: TextStyle(
                                                        color:
                                                            AppColors.orange)),
                                              ),
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('OK'))
                                            ]));
                              },
                              child: Container(
                                width: 240,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.event,
                                            color: AppColors.orange),
                                        const SizedBox(width: 8),
                                        Expanded(
                                            child: Text((() {
                                          try {
                                            return jsonDecode(text)['title'] ??
                                                'Event';
                                          } catch (_) {
                                            return text.isNotEmpty
                                                ? text
                                                : 'Event';
                                          }
                                        })(),
                                                style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                    color: AppColors.dark),
                                                overflow:
                                                    TextOverflow.ellipsis)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text((() {
                                      try {
                                        return jsonDecode(text)['date'] ?? '';
                                      } catch (_) {
                                        return '';
                                      }
                                    })(),
                                        style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.dark)),
                                    const SizedBox(height: 8),
                                    const Text('View details',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.orange)),
                                  ],
                                ),
                              ),
                            )
                          else if (messageType == 'video')
                            Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: () async {
                                  if (mediaUrl != null) {
                                    final url = await context
                                        .read<ChatService>()
                                        .getMediaSignedUrl(mediaUrl);
                                    if (url != null) {
                                      if (!context.mounted) return;
                                      final sName =
                                          isMe ? 'You' : widget.chatName;
                                      Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (_) => VideoViewerScreen(
                                                  videoUrl: url,
                                                  senderName: sName,
                                                  time: time)));
                                    }
                                  }
                                },
                                child: Container(
                                    width: MediaQuery.of(context).size.width * 0.55,
                                    height: MediaQuery.of(context).size.width * 0.55 * 0.7,
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: mediaUrl != null
                                      ? VideoThumbnailWidget(
                                          mediaUrl: mediaUrl,
                                          chatService:
                                              Provider.of<ChatService>(context, listen: false))
                                      : Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            const Icon(Icons.videocam,
                                                color: Colors.white24,
                                                size: 80),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: const BoxDecoration(
                                                  color: Colors.black45,
                                                  shape: BoxShape.circle),
                                              child: const Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 40),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          if (displayText.isNotEmpty &&
                              messageType != 'event' &&
                              messageType != 'location' &&
                              messageType != 'contact' &&
                              messageType != 'poll' &&
                              messageType != 'document')
                            Padding(
                              padding: EdgeInsets.only(
                                  top: messageType != 'text' ? 8.0 : 0,
                                  right: 4,
                                  left: 4),
                              child: _buildParsedText(
                                displayText,
                                TextStyle(
                                  color: textColor,
                                  fontSize: 15,
                                ),
                                isMe,
                              ),
                            ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (rawMsg?['is_edited'] == true) ...[
                                Text(
                                  '(edited)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: timeColor.withOpacity(0.8),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (widget.isStarred) ...[
                                const Icon(Icons.star, size: 10, color: Colors.orangeAccent),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                time,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: timeColor,
                                ),
                              ),
                              if (widget.viewCount != null) ...[
                                const SizedBox(width: 8),
                                Icon(Icons.visibility, size: 14, color: timeColor),
                                const SizedBox(width: 4),
                                Text(
                                  '${widget.viewCount}',
                                  style: TextStyle(fontSize: 11, color: timeColor, fontWeight: FontWeight.bold),
                                ),
                              ] else if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isPending ? Icons.access_time : (widget.isRead ? Icons.done_all : Icons.check),
                                  size: 14, 
                                  color: widget.isRead ? Colors.blue : timeColor,
                                ),
                              ],
                            ],
                          ),
                          ),
                          if (replyMarkup != null &&
                              replyMarkup['inline_keyboard'] != null)
                            _buildInlineKeyboard(
                                replyMarkup['inline_keyboard']),
                        ],
                      ),
                     ),
                    ), // End Container
                        ), // End Padding
                        if (widget.reactions.isNotEmpty)
                          Positioned(
                            bottom: 0,
                            right: isMe ? 8 : null,
                            left: isMe ? null : 8,
                            child: _buildReactionsBadge(),
                          ),
                      ],
                    ), // End Stack
                   ),
                 ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildReactionsBadge() {
    if (widget.reactions.isEmpty) return const SizedBox.shrink();
    final Map<String, int> counts = {};
    for (var r in widget.reactions) {
      final emoji = r['emoji'] as String;
      counts[emoji] = (counts[emoji] ?? 0) + 1;
    }
    final displayEmojis = counts.keys.take(3).join('');
    final totalCount = widget.reactions.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: counts.keys.take(3).map((e) => Text(
              e, 
              style: TextStyle(
                fontSize: 14, 
                color: e.contains('❤') ? Colors.red : null,
                fontFamilyFallback: const ['Apple Color Emoji', 'Segoe UI Emoji', 'Noto Color Emoji']
              )
            )).toList(),
          ),
          if (totalCount > 1) ...[
            const SizedBox(width: 3),
            Text(
              totalCount.toString(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.dark,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusQuotedBubble(Map<String, dynamic> statusData) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: IntrinsicHeight(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 4, color: Colors.purpleAccent),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status',
                        style: TextStyle(
                            color: Colors.purpleAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        statusData['status_caption']?.toString().isNotEmpty == true 
                            ? statusData['status_caption'] 
                            : (statusData['status_media_type'] == 'video' ? 'Video' : 'Image'),
                        style: const TextStyle(
                            color: AppColors.grey2, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (statusData['status_media_url'] != null)
                SizedBox(
                  width: 40,
                  height: 40,
                  child: statusData['status_media_type'] == 'video' 
                    ? const Icon(Icons.videocam, color: Colors.grey)
                    : SignedImageWidget(
                      mediaUrl: statusData['status_media_url'],
                      chatService: Provider.of<ChatService>(context, listen: false),
                      fit: BoxFit.cover,
                    ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuotedBubble(Map<String, dynamic> msg) {
    final isMe = msg['sender_id'] == Provider.of<ChatService>(context, listen: false).currentUserId;
    final senderName = isMe ? 'You' : widget.chatName;

    return GestureDetector(
      onTap: () {
        if (msg['id'] != null) {
          if (widget.onScrollToMessage != null) widget.onScrollToMessage!(msg['id'].toString());
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isMe ? Colors.black.withValues(alpha: 0.05) : AppColors.lightGrey.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: buildReplySnippet(context, msg, senderName, isPreview: false, isMe: isMe, bubbleColor: widget.bubbleColor),
        ),
      ),
    );
  }

  Widget _buildPollOption(String text,
      {bool isSelected = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: isSelected ? AppColors.orange : AppColors.border,
              width: isSelected ? 1.5 : 0.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
                child: Text(text,
                    style: TextStyle(
                        color: AppColors.dark,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal))),
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? AppColors.orange : AppColors.border,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineKeyboard(List<dynamic> inlineKeyboard) {
    if (inlineKeyboard.isEmpty) return const SizedBox.shrink();
    return Column(
      children: inlineKeyboard.map((row) {
        if (row is! List) return const SizedBox.shrink();
        return Row(
          children: row.map((btn) {
            final text = btn['text']?.toString() ?? '';
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(2.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.white,
                    foregroundColor: AppColors.orange,
                    side: const BorderSide(color: AppColors.orange),
                  ),
                  onPressed: () {
                    if (btn['callback_data'] != null) {
                      if (widget.onBotCommand != null) { widget.onBotCommand!(btn['callback_data']!); }
                      
                    }
                  },
                  child: Text(text),
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }


}

Widget buildReplySnippet(BuildContext context, Map<String, dynamic> msg, String senderName,
      {bool isPreview = false, bool isMe = false, Color bubbleColor = AppColors.orange}) {
    final replyType = msg['message_type'] ?? 'text';
    final replyContent = msg['content'] ?? '';
    final replyMediaUrl = msg['media_url'];
    final colorBorder = bubbleColor;

    Widget? replyThumbnailWidget;
    Widget replyTextWidget;

    if (replyType == 'image') {
      replyTextWidget = const Row(children: [
        Icon(Icons.camera_alt, size: 14, color: AppColors.grey2),
        SizedBox(width: 4),
        Text('Photo',
            style: TextStyle(color: AppColors.grey2, fontSize: 13))
      ]);
      if (replyMediaUrl != null) {
        replyThumbnailWidget = SignedImageWidget(
          mediaUrl: replyMediaUrl,
          chatService: Provider.of<ChatService>(context, listen: false),
          width: 50,
          height: 50,
        );
      } else {
        replyThumbnailWidget = Container(
          width: 50,
          height: 50,
          color: Colors.black.withValues(alpha: 0.05),
          child: const Icon(Icons.image, color: AppColors.grey2, size: 24),
        );
      }
    } else if (replyType == 'video') {
      replyTextWidget = const Row(children: [
        Icon(Icons.videocam, size: 14, color: AppColors.grey2),
        SizedBox(width: 4),
        Text('Video',
            style: TextStyle(color: AppColors.grey2, fontSize: 13))
      ]);
      if (replyMediaUrl != null) {
        replyThumbnailWidget = Container(
          width: 50,
          height: 50,
          color: AppColors.dark,
          child: const Icon(Icons.videocam, color: AppColors.white, size: 24),
        );
      }
    } else if (replyType == 'location') {
      replyTextWidget = const Row(children: [
        Icon(Icons.location_on, size: 14, color: AppColors.grey2),
        SizedBox(width: 4),
        Text('Location',
            style: TextStyle(color: AppColors.grey2, fontSize: 13))
      ]);

      String? lat, lng;
      try {
        if (replyContent.startsWith('live_location:')) {
          final parts = replyContent.substring(14).split(',');
          if (parts.length >= 2) {
            lat = parts[0];
            lng = parts[1];
          }
        } else if (replyContent.contains('https://maps.google.com/?q=')) {
          final idx = replyContent.indexOf('https://maps.google.com/?q=');
          final q = replyContent.substring(idx + 27).trim();
          final parts = q.split(',');
          if (parts.length >= 2) {
            lat = parts[0];
            lng = parts[1];
          }
        }
      } catch (_) {}

      if (lat != null && lng != null) {
        replyThumbnailWidget = SizedBox(
          width: 50,
          height: 50,
          child: AbsorbPointer(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                  target: LatLng(double.parse(lat), double.parse(lng)),
                  zoom: 14),
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              liteModeEnabled: true,
            ),
          ),
        );
      } else {
        replyThumbnailWidget = Container(
          width: 50,
          height: 50,
          color: Colors.blue.withValues(alpha: 0.1),
          child: const Icon(Icons.map, size: 24, color: Colors.blue),
        );
      }
    } else if (replyType == 'voice') {
      replyTextWidget = const Row(children: [
        Icon(Icons.mic, size: 14, color: AppColors.grey2),
        SizedBox(width: 4),
        Text('Voice message',
            style: TextStyle(color: AppColors.grey2, fontSize: 13))
      ]);
    } else if (replyType == 'document') {
      final fileName = replyContent.isNotEmpty ? replyContent : 'Document';
      replyTextWidget = Text(fileName,
          style: const TextStyle(color: AppColors.grey2, fontSize: 13),
          maxLines: 1,
          overflow: TextOverflow.ellipsis);
      replyThumbnailWidget = Container(
        width: 50,
        height: 50,
        color: Colors.black.withValues(alpha: 0.05),
        child: Icon(
            fileName.toLowerCase().endsWith('.pdf')
                ? Icons.picture_as_pdf
                : (fileName.toLowerCase().endsWith('.xls') ||
                        fileName.toLowerCase().endsWith('.xlsx') ||
                        fileName.toLowerCase().endsWith('.csv'))
                    ? Icons.table_chart
                    : (fileName.toLowerCase().endsWith('.doc') ||
                            fileName.toLowerCase().endsWith('.docx') ||
                            fileName.toLowerCase().endsWith('.txt'))
                        ? Icons.description
                        : (fileName.toLowerCase().endsWith('.zip') ||
                                fileName.toLowerCase().endsWith('.rar'))
                            ? Icons.folder_zip
                            : Icons.insert_drive_file,
            color: AppColors.grey2,
            size: 24),
      );
    } else if (replyType == 'contact') {
      String contactName = 'Contact';
      try {
        final decoded = jsonDecode(replyContent) as Map;
        contactName = decoded['name']?.toString() ?? 'Contact';
      } catch (_) {}
      replyTextWidget = Row(children: [
        const Icon(Icons.person, size: 14, color: AppColors.grey2),
        const SizedBox(width: 4),
        Text(contactName,
            style: const TextStyle(color: AppColors.grey2, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis)
      ]);
      replyThumbnailWidget = Container(
        width: 50,
        height: 50,
        color: Colors.blue.withValues(alpha: 0.1),
        child: const Icon(Icons.person, size: 24, color: Colors.blue),
      );
    } else if (replyType == 'poll') {
      replyTextWidget = const Row(children: [
        Icon(Icons.poll, size: 14, color: AppColors.grey2),
        SizedBox(width: 4),
        Text('Poll',
            style: TextStyle(color: AppColors.grey2, fontSize: 13))
      ]);
      replyThumbnailWidget = Container(
        width: 50,
        height: 50,
        color: Colors.black.withValues(alpha: 0.05),
        child: const Icon(Icons.poll, size: 24, color: AppColors.orange),
      );
    } else if (replyType == 'event') {
      replyTextWidget = const Row(children: [
        Icon(Icons.event, size: 14, color: AppColors.grey2),
        SizedBox(width: 4),
        Text('Event',
            style: TextStyle(color: AppColors.grey2, fontSize: 13))
      ]);
      replyThumbnailWidget = Container(
        width: 50,
        height: 50,
        color: Colors.black.withValues(alpha: 0.05),
        child: const Icon(Icons.event, color: AppColors.grey2, size: 24),
      );
    } else {
      replyTextWidget = Text(
        replyContent,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.dark, fontSize: 13),
      );
    }

    return IntrinsicHeight(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(color: isMe ? AppColors.dark.withValues(alpha: 0.6) : colorBorder),
            ),
            Flexible(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(senderName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isMe ? AppColors.dark.withValues(alpha: 0.8) : colorBorder,
                            fontSize: 13)),
                    const SizedBox(height: 2),
                    replyTextWidget,
                  ],
                ),
              ),
            ),
            if (replyThumbnailWidget != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8)),
                child: replyThumbnailWidget,
              ),
          ],
        ),
      ),
    );
  }
