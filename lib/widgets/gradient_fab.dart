import 'package:flutter/material.dart';
import 'package:twibee/theme.dart';
import 'package:twibee/widgets/hexagon_avatar.dart';

class GradientFab extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final String? tooltip;
  final Object? heroTag;
  final bool mini;
  final double? elevation;

  const GradientFab({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
    this.tooltip,
    this.heroTag,
    this.mini = false,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: HexagonClipper(),
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
        child: FloatingActionButton(
          onPressed: onPressed,
          foregroundColor: foregroundColor,
          backgroundColor: Colors.transparent, // Let gradient show through
          elevation: 0, // No shadow from FAB itself since we clipped
          tooltip: tooltip,
          heroTag: heroTag,
          mini: mini,
          child: child,
        ),
      ),
    );
  }
}

