import 'dart:math';
import 'package:flutter/material.dart';

class HexagonBorder extends ShapeBorder {
  final BorderSide side;

  const HexagonBorder({this.side = BorderSide.none});

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _getHexagonPath(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _getHexagonPath(rect);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    final path = getOuterPath(rect, textDirection: textDirection);
    final paint = side.toPaint();
    canvas.drawPath(path, paint);
  }

  @override
  ShapeBorder scale(double t) => HexagonBorder(side: side.scale(t));

  Path _getHexagonPath(Rect rect) {
    final path = Path();
    final double width = rect.width;
    final double height = rect.height;
    
    path.moveTo(rect.left + width * 0.25, rect.top);
    path.lineTo(rect.left + width * 0.75, rect.top);
    path.lineTo(rect.left + width, rect.top + height * 0.5);
    path.lineTo(rect.left + width * 0.75, rect.top + height);
    path.lineTo(rect.left + width * 0.25, rect.top + height);
    path.lineTo(rect.left, rect.top + height * 0.5);
    path.close();
    
    return path;
  }
}

