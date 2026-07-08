import 'package:flutter/material.dart';
import '../theme.dart';

class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final String? header;
  final String? footer;

  const SettingsGroup({super.key, required this.children, this.header, this.footer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
              child: Text(
                header!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 13,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  children: children,
                ),
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 8.0, right: 16.0),
              child: Text(
                footer!,
                style: const TextStyle(
                  color: AppColors.grey,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class SettingsItem extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconBackgroundColor;
  final Widget? trailing;
  final bool showDivider;
  final VoidCallback? onTap;
  final Color titleColor;
  final bool isDestructive;

  const SettingsItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.iconBackgroundColor,
    this.trailing,
    this.showDivider = true,
    this.onTap,
    this.titleColor = AppColors.dark,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTitleColor = isDestructive ? Colors.red : titleColor;
    final effectiveIconColor = iconBackgroundColor ?? (isDestructive ? Colors.red : AppColors.grey);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: effectiveIconColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Icon(icon, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: effectiveTitleColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppColors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (onTap != null)
                    const Icon(Icons.arrow_forward_ios, color: AppColors.grey, size: 16),
                ],
              ),
            ),
            if (showDivider)
              const Padding(
                padding: EdgeInsets.only(left: 60.0), // Align divider with text
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: AppColors.lightGrey,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

