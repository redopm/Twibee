import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadHelper {
  static Future<String?> downloadToTemp(String url, String fileName) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';
      final file = File(savePath);
      
      if (await file.exists()) {
        return savePath; // Already cached
      }
      
      await Dio().download(url, savePath);
      return savePath;
    } catch (e) {
      debugPrint('Error downloading to temp: $e');
      return null;
    }
  }

  static Future<bool> isFileDownloaded(String fileName) async {
    try {
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) return false;

      final savePath = '${downloadsDir.path}/$fileName';
      return await File(savePath).exists();
    } catch (e) {
      return false;
    }
  }

  static Future<void> downloadToGalleryOrDocuments(BuildContext context, String url, String fileName) async {
    try {
      // Request permissions
      if (Platform.isAndroid) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          debugPrint('Storage permission not granted');
        }
      }

      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        throw Exception('Could not find downloads directory');
      }

      final savePath = '${downloadsDir.path}/$fileName';
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Downloading...')),
      );

      await Dio().download(url, savePath);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved to Downloads')),
        );
      }
    } catch (e) {
      debugPrint('Error downloading file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download file')),
        );
      }
    }
  }
}
