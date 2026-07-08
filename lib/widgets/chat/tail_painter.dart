import 'package:flutter/material.dart';

class TailPainter extends CustomPainter {
  final bool isMe;
  final Color color;

  TailPainter({required this.isMe, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    if (isMe) {
      // Bottom right
      path.moveTo(0, size.height); 
      path.lineTo(size.width, size.height); 
      path.lineTo(0, 0); 
      path.close();
    } else {
      // Bottom left
      path.moveTo(size.width, size.height); 
      path.lineTo(0, size.height); 
      path.lineTo(size.width, 0); 
      path.close();
    }
    
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.05), 1, false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => oldDelegate != this;
}

