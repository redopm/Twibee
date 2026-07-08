import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:get_thumbnail_video/index.dart';
import 'package:get_thumbnail_video/video_thumbnail.dart';
import 'dart:typed_data';
import 'package:video_trimmer/video_trimmer.dart';

import '../services/chat_service.dart';
import '../services/channel_service.dart';
import '../services/status_service.dart';
import '../theme.dart';

class MediaItemModel {
  final AssetEntity originalAsset;
  File? file; // The actual file to upload (could be edited)
  bool isUploading = false;
  bool isFailed = false;
  double progress = 0.0;
  bool isEdited = false;
  
  Trimmer? trimmer;
  double trimStart = 0.0;
  double trimEnd = 0.0;
  bool isPlaying = false;

  MediaItemModel(this.originalAsset);
}

class MediaPreviewEditScreen extends StatefulWidget {
  final List<AssetEntity> initialAssets;
  final String? chatId;
  final bool isForStatus;
  final bool isChannel;

  const MediaPreviewEditScreen({
    super.key,
    required this.initialAssets,
    this.chatId,
    this.isForStatus = false,
    this.isChannel = false,
  });

  @override
  State<MediaPreviewEditScreen> createState() => _MediaPreviewEditScreenState();
}

class _MediaPreviewEditScreenState extends State<MediaPreviewEditScreen> {
  late List<MediaItemModel> _items;
  int _currentIndex = 0;
  final TextEditingController _captionController = TextEditingController();
  bool _isUploadingBatch = false;

  @override
  void initState() {
    super.initState();
    _items = widget.initialAssets.map((e) => MediaItemModel(e)).toList();
    _initFiles();
  }

  Future<void> _initFiles() async {
    for (var item in _items) {
      if (item.file == null) {
        final file = await item.originalAsset.file;
        if (mounted) {
          setState(() {
            item.file = file;
          });
          if (item.originalAsset.type == AssetType.video && widget.isForStatus) {
            item.trimmer = Trimmer();
            await item.trimmer!.loadVideo(videoFile: file!);
            item.trimEnd = item.originalAsset.duration.toDouble() * 1000.0;
            if (item.trimEnd > 30000.0) {
              item.trimEnd = 30000.0; // Max 30s
            }
            if (mounted) setState(() {});
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    for (var item in _items) {
      item.trimmer?.dispose();
    }
    super.dispose();
  }

  Future<void> _openEditor(MediaItemModel item) async {
    if (item.file == null || item.originalAsset.type != AssetType.image) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProImageEditor.file(
          item.file!,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (bytes) async {
              final tempDir = Directory.systemTemp;
              final newFile = File('${tempDir.path}/edited_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await newFile.writeAsBytes(bytes);
              setState(() {
                item.file = newFile;
                item.isEdited = true;
              });
              if (mounted) Navigator.pop(context); // Close editor
            },
          ),
        ),
      ),
    );
  }

  void _removeItem(int index) {
    setState(() {
      final item = _items.removeAt(index);
      item.trimmer?.dispose();
      
      if (_items.isEmpty) {
        Navigator.pop(context);
      } else if (_currentIndex >= _items.length) {
        _currentIndex = _items.length - 1;
      }
    });
  }

  Future<void> _sendBatch() async {
    if (_items.isEmpty) return;
    
    setState(() {
      _isUploadingBatch = true;
    });

    final chatService = context.read<ChatService>();
    final statusService = context.read<StatusService>();
    final currentUserId = statusService.currentUserId;
    final mediaGroupId = const Uuid().v4();
    
    // Process trimmed videos before backgrounding
    for (var item in _items) {
      if (item.originalAsset.type == AssetType.video && item.trimmer != null) {
        final completer = Completer<String?>();
        await item.trimmer!.saveTrimmedVideo(
          startValue: item.trimStart,
          endValue: item.trimEnd,
          onSave: (outputPath) {
            completer.complete(outputPath);
          },
        );
        final path = await completer.future;
        if (path != null) {
          item.file = File(path);
          item.isEdited = true;
        }
      }
    }

    if (widget.isForStatus) {
      final uploadItems = _items.map((item) {
        return StatusUploadItem(
          file: item.file!,
          type: item.originalAsset.type == AssetType.video ? 'video' : 'image',
          caption: _captionController.text.trim(),
          isEdited: item.isEdited,
        );
      }).toList();
      statusService.uploadStatusBatch(uploadItems);
      Navigator.pop(context, true); // Pop immediately for seamless background upload!
      return;
    }
    
    // Upload each file for chat
    List<Map<String, dynamic>> successfulUploads = [];
    bool hasFailures = false;

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.isFailed) {
         if (mounted) {
           setState(() {
             item.isFailed = false;
           });
         }
      }
      
      File uploadFile = item.file!;
      
      if (item.originalAsset.type == AssetType.video) {
          if (!item.isEdited) {
            try {
              final info = await VideoCompress.compressVideo(
                uploadFile.path,
                quality: VideoQuality.MediumQuality,
                deleteOrigin: false,
                includeAudio: true,
              );
              if (info != null && info.file != null && info.file!.lengthSync() > 1024) {
                uploadFile = info.file!;
              }
            } catch (e) {
              debugPrint('Video compression failed: $e');
            }
          }
      } else {
         final tempDir = await getTemporaryDirectory();
         final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
         var result = await FlutterImageCompress.compressAndGetFile(
           uploadFile.path, 
           targetPath,
           quality: 70,
         );
         if (result != null) {
           uploadFile = File(result.path);
         }
      }

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${const Uuid().v4()}';
      final ext = item.originalAsset.type == AssetType.video ? '.mp4' : '.jpg';
      final storagePath = widget.isForStatus 
          ? 'status_$currentUserId/$fileName$ext'
          : '${widget.chatId}/$fileName$ext';

      try {
        await Supabase.instance.client.storage.from('chat_media').upload(
          storagePath,
          uploadFile,
        );

        successfulUploads.add({
          'url': storagePath,
          'type': item.originalAsset.type == AssetType.video ? 'video' : 'image',
          'caption': _captionController.text.trim(),
        });
      } catch (e) {
        debugPrint('[DEBUG] Upload failed for item $i: $e');
        hasFailures = true;
        if (mounted) {
          setState(() {
            item.isFailed = true;
          });
        }
      }
    }

    if (hasFailures) {
      if (mounted) {
        setState(() {
          _isUploadingBatch = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Some media failed to upload. Tap the refresh icon to retry.')));
      }
      return;
    }

    try {
      if (widget.isChannel) {
        final channelService = ChannelService();
        for (var item in successfulUploads) {
          await channelService.createPost(
            channelId: widget.chatId!,
            existingMediaUrl: item['url'],
            mediaType: item['type'],
            text: item['caption'],
          );
        }
      } else {
        await chatService.sendMediaBatch(
          chatId: widget.chatId!,
          mediaItems: successfulUploads,
          mediaGroupId: mediaGroupId,
        );
      }
      if (mounted) Navigator.pop(context); // Go back to chat screen
    } catch (e) {
      debugPrint('[DEBUG] _sendBatch Exception: $e');
      if (mounted) {
        setState(() {
          _isUploadingBatch = false;
        });
        showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Error'), content: Text(e.toString())));
      }
    }
  }

  void _addMore() async {
    final List<AssetEntity>? assets = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 30,
        selectedAssets: _items.map((e) => e.originalAsset).toList(),
        requestType: RequestType.common,
        themeColor: AppColors.orange,
      ),
    );
    if (assets != null && assets.isNotEmpty) {
      setState(() {
        final currentAssetIds = _items.map((e) => e.originalAsset.id).toSet();
        for (var asset in assets) {
          if (!currentAssetIds.contains(asset.id)) {
            _items.add(MediaItemModel(asset));
          }
        }
        _items.removeWhere((item) => !assets.any((a) => a.id == item.originalAsset.id));
        if (_currentIndex >= _items.length) {
          _currentIndex = _items.length - 1;
        }
      });
      _initFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const Scaffold(backgroundColor: Colors.black);

    final currentItem = _items[_currentIndex];
    final isVideo = currentItem.originalAsset.type == AssetType.video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            if (isVideo && currentItem.trimmer != null)
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                        const Row(
                          children: [
                            Icon(Icons.crop_rotate, color: Colors.white),
                            SizedBox(width: 16),
                            Icon(Icons.emoji_emotions_outlined, color: Colors.white),
                            SizedBox(width: 16),
                            Icon(Icons.title, color: Colors.white),
                            SizedBox(width: 16),
                            Icon(Icons.edit, color: Colors.white),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TrimViewer(
                      trimmer: currentItem.trimmer!,
                      viewerHeight: 50.0,
                      viewerWidth: MediaQuery.of(context).size.width - 32,
                      maxVideoLength: const Duration(seconds: 30),
                      editorProperties: const TrimEditorProperties(
                        borderPaintColor: AppColors.orange,
                        circlePaintColor: AppColors.orange,
                        scrubberPaintColor: Colors.white,
                      ),
                      onChangeStart: (value) => currentItem.trimStart = value,
                      onChangeEnd: (value) => currentItem.trimEnd = value,
                      onChangePlaybackState: (value) {
                        if (mounted) setState(() { currentItem.isPlaying = value; });
                      },
                    ),
                  ],
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
                  if (!isVideo)
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () => _openEditor(currentItem),
                    ),
                ],
              ),

            // Main Preview (Video or Image)
            Expanded(
              child: Center(
                child: currentItem.file != null
                    ? (isVideo
                        ? (currentItem.trimmer != null
                            ? Stack(
                                alignment: Alignment.center,
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      bool playbackState = await currentItem.trimmer!.videoPlaybackControl(
                                        startValue: currentItem.trimStart,
                                        endValue: currentItem.trimEnd,
                                      );
                                      setState(() { currentItem.isPlaying = playbackState; });
                                    },
                                    child: VideoViewer(trimmer: currentItem.trimmer!),
                                  ),
                                  if (!currentItem.isPlaying)
                                    const Icon(Icons.play_circle_fill, color: Colors.white, size: 60),
                                ],
                              )
                            : Stack(
                                alignment: Alignment.center,
                                children: [
                                  FutureBuilder<Uint8List?>(
                                    future: VideoThumbnail.thumbnailData(
                                      video: currentItem.file!.path,
                                      imageFormat: ImageFormat.JPEG,
                                      quality: 50,
                                    ),
                                    builder: (context, snapshot) {
                                      if (snapshot.connectionState == ConnectionState.waiting) {
                                        return const CircularProgressIndicator(color: AppColors.orange);
                                      }
                                      if (snapshot.hasData && snapshot.data != null) {
                                        return Image.memory(snapshot.data!, fit: BoxFit.contain);
                                      }
                                      return Container(color: Colors.black26, child: const Icon(Icons.broken_image, color: Colors.white54, size: 60));
                                    },
                                  ),
                                  const Icon(Icons.play_circle_fill, color: Colors.white, size: 60),
                                ],
                              ))
                        : Image.file(currentItem.file!, fit: BoxFit.contain))
                    : const CircularProgressIndicator(),
              ),
            ),

            // Bottom Batch Strip (if multiple items or chat)
            if (_items.length > 1 || !widget.isForStatus)
              Container(
                color: Colors.black87,
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _items.length,
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            final isSelected = index == _currentIndex;
                            return GestureDetector(
                              onTap: () => setState(() => _currentIndex = index),
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                width: 50,
                                decoration: BoxDecoration(
                                  border: Border.all(color: isSelected ? AppColors.orange : Colors.transparent, width: 2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: AssetEntityImage(item.originalAsset, isOriginal: false, fit: BoxFit.cover),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (_items.length < 30 && !_isUploadingBatch)
                      GestureDetector(
                        onTap: _addMore,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),

            // Caption Field & Send Button
            Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, -5))
                ],
              ),
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 24),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1C1E),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white54),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          prefixIcon: Icon(Icons.add_photo_alternate_rounded, color: Colors.white54, size: 22),
                        ),
                        enabled: !_isUploadingBatch,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isUploadingBatch ? null : _sendBatch,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: _isUploadingBatch 
                            ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                            : LinearGradient(
                                colors: [AppColors.orange, AppColors.orange.withValues(alpha: 0.8)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!_isUploadingBatch)
                            BoxShadow(color: AppColors.orange.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: _isUploadingBatch 
                          ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                    ),
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

