import 'package:flutter/material.dart';
import 'package:twibee/widgets/hexagon_border.dart';
import 'package:twibee/widgets/hexagon_avatar.dart'; // for HexagonClipper

class HexagonImage extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final Color? borderColor;
  final double borderWidth;

  const HexagonImage({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderColor,
    this.borderWidth = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = ClipPath(
      clipper: HexagonClipper(),
      child: SizedBox(
        width: width,
        height: height,
        child: child,
      ),
    );

    if (borderWidth > 0 && borderColor != null) {
      content = CustomPaint(
        foregroundPainter: _HexagonBorderPainter(
          color: borderColor!,
          width: borderWidth,
        ),
        child: content,
      );
    }

    return content;
  }
}

class _HexagonBorderPainter extends CustomPainter {
  final Color color;
  final double width;

  _HexagonBorderPainter({required this.color, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    final double w = size.width;
    final double h = size.height;
    
    path.moveTo(w * 0.25, 0);
    path.lineTo(w * 0.75, 0);
    path.lineTo(w, h * 0.5);
    path.lineTo(w * 0.75, h);
    path.lineTo(w * 0.25, h);
    path.lineTo(0, h * 0.5);
    path.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HexagonBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.width != width;
  }
}

