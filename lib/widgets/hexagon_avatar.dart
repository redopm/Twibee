import 'package:twibee/widgets/hexagon_avatar.dart';
import 'dart:math';
import 'package:flutter/material.dart';

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final double width = size.width;
    final double height = size.height;

    // A flat-topped hexagon
    path.moveTo(width * 0.25, 0);
    path.lineTo(width * 0.75, 0);
    path.lineTo(width, height * 0.5);
    path.lineTo(width * 0.75, height);
    path.lineTo(width * 0.25, height);
    path.lineTo(0, height * 0.5);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// A replacement for [CircleAvatar] that draws a hexagon shape.
class HexagonAvatar extends StatelessWidget {
  final double? radius;
  final Widget? child;
  final Color? backgroundColor;
  final ImageProvider? backgroundImage;
  final Color? foregroundColor;

  const HexagonAvatar({
    super.key,
    this.radius,
    this.child,
    this.backgroundColor,
    this.backgroundImage,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final double defaultRadius = 20.0;
    final double r = radius ?? defaultRadius;
    final double diameter = r * 2;
    
    // Default theme logic similar to CircleAvatar
    final ThemeData theme = Theme.of(context);
    final Color effectiveBackgroundColor = backgroundColor ?? theme.primaryColorLight;
    final Color effectiveForegroundColor = foregroundColor ?? theme.primaryColorDark;

    return ClipPath(
      clipper: HexagonClipper(),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          color: effectiveBackgroundColor,
          image: backgroundImage != null
              ? DecorationImage(
                  image: backgroundImage!,
                  fit: BoxFit.cover,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: child != null
            ? IconTheme.merge(
                data: IconThemeData(color: effectiveForegroundColor),
                child: DefaultTextStyle(
                  style: TextStyle(color: effectiveForegroundColor),
                  child: child!,
                ),
              )
            : null,
      ),
    );
  }
}

