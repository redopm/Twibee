import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';

class MediaCompressor {
    static Future<File?> compressImage(File file) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      if (ext == 'gif') {
        return file; // flutter_image_compress does not support gif
      }
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70, // 70% quality is a good balance for chat apps
        minWidth: 1080,
        minHeight: 1080,
      );
      
      if (result != null) {
        return File(result.path);
      }
      return file; // fallback to original if compression fails
    } catch (e) {
      debugPrint('Error compressing image: ');
      return file;
    }
  }

  static Future<File?> compressVideo(File file) async {
    try {
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        file.absolute.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );
      
      if (mediaInfo != null && mediaInfo.file != null) {
        return mediaInfo.file!;
      }
      return file; // fallback to original
    } catch (e) {
      debugPrint('Error compressing video: $e');
      return file;
    }
  }
}

