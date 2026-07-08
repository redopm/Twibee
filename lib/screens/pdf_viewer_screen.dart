import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../theme.dart';
import '../utils/download_helper.dart';

class PdfViewerScreen extends StatefulWidget {
  final String pathOrUrl;
  final String title;

  const PdfViewerScreen({super.key, required this.pathOrUrl, required this.title});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  String? _localPath;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    if (widget.pathOrUrl.startsWith('http')) {
      final fileName = widget.pathOrUrl.split('/').last.split('?').first;
      final path = await DownloadHelper.downloadToTemp(widget.pathOrUrl, fileName);
      if (mounted) {
        setState(() {
          _localPath = path;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _localPath = widget.pathOrUrl;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: TwibeeAppBar(
        title: widget.title,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              final fileName = widget.pathOrUrl.split('/').last.split('?').first;
              DownloadHelper.downloadToGalleryOrDocuments(context, widget.pathOrUrl, fileName);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _localPath == null
              ? const Center(child: Text('Failed to load PDF'))
              : PDFView(
                  filePath: _localPath!,
                  enableSwipe: true,
                  swipeHorizontal: true,
                  autoSpacing: false,
                  pageFling: false,
                ),
    );
  }
}

