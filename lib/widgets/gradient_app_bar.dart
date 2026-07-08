import 'package:flutter/material.dart';
import 'package:twibee/theme.dart';

class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;

  const GradientAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: title,
      actions: actions,
      leading: leading,
      centerTitle: centerTitle,
      elevation: elevation,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.primaryGradient,
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
