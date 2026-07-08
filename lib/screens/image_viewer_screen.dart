import 'package:flutter/material.dart';
import 'dart:io';
import 'package:twibee/widgets/app_widgets.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;

  const ImageViewerScreen({super.key, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: TwibeeAppBar(
        title: '',
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: imageUrl.startsWith('http')
              ? Image.network(imageUrl, fit: BoxFit.contain)
              : Image.file(File(imageUrl), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

