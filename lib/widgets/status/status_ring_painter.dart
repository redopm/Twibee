import 'dart:math';
import 'package:flutter/material.dart';

class StatusRingPainter extends CustomPainter {
  final int totalSegments;
  final int viewedSegments; // How many from the START are viewed
  final Color viewedColor;
  final Color unviewedColor;
  final double strokeWidth;
  final double gapSpacing;

  StatusRingPainter({
    required this.totalSegments,
    required this.viewedSegments,
    this.viewedColor = Colors.grey,
    this.unviewedColor = Colors.green, // WhatsApp green
    this.strokeWidth = 2.5,
    this.gapSpacing = 4.0, // Degrees of gap between segments
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (totalSegments <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width / 2, size.height / 2) - strokeWidth / 2;

    final rect = Rect.fromCircle(center: center, radius: radius);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    if (totalSegments == 1) {
      // Draw a full circle if only 1 segment
      paint.color = viewedSegments == 1 ? viewedColor : unviewedColor;
      canvas.drawArc(rect, 0, 2 * pi, false, paint);
      return;
    }

    // Multiple segments
    // Total gap space in radians
    final totalGapRads = (gapSpacing * pi / 180) * totalSegments;
    // Length of each segment in radians
    final segmentLengthRads = (2 * pi - totalGapRads) / totalSegments;

    // Start at top (-pi/2)
    double currentAngle = -pi / 2;

    for (int i = 0; i < totalSegments; i++) {
      paint.color = i < viewedSegments ? viewedColor : unviewedColor;

      canvas.drawArc(
        rect,
        currentAngle,
        segmentLengthRads,
        false,
        paint,
      );

      // Advance by segment + gap
      currentAngle += segmentLengthRads + (gapSpacing * pi / 180);
    }
  }

  @override
  bool shouldRepaint(covariant StatusRingPainter oldDelegate) {
    return oldDelegate.totalSegments != totalSegments ||
        oldDelegate.viewedSegments != viewedSegments ||
        oldDelegate.viewedColor != viewedColor ||
        oldDelegate.unviewedColor != unviewedColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gapSpacing != gapSpacing;
  }
}

