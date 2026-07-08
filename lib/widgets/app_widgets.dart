import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/theme.dart';

// ─── TwibeeAppBar ────────────────────────────────────────────────────────────
/// The unified premium AppBar for all screens in Twibee.
/// Matches the floating nav bar aesthetic: subtle shadow, orange pill back
/// button, theme-adaptive, optional subtitle for chat/info screens.
class TwibeeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// Optional subtitle (e.g. "typing…", "last seen", "3 members online")
  final String? subtitle;

  final List<Widget>? actions;

  /// Custom leading widget — if provided, overrides the default back button.
  final Widget? leading;

  /// If false, the back button is hidden (e.g. Settings root screen).
  final bool showBackButton;

  /// Override background color (e.g. transparent for viewer screens).
  final Color? backgroundColor;

  /// Custom back callback. Defaults to Navigator.maybePop.
  final VoidCallback? onBack;

  /// Center the title (defaults to false — left-aligned modern look).
  final bool centerTitle;

  const TwibeeAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.backgroundColor,
    this.onBack,
    this.centerTitle = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark ? const Color(0xFF1E1E1E) : AppColors.white);
    final titleColor = isDark ? Colors.white : AppColors.dark;
    final subtitleColor = isDark ? Colors.white60 : AppColors.grey;
    final shadowColor = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : AppColors.orange.withValues(alpha: 0.08);

    // Determine leading widget
    Widget? leadingWidget;
    if (leading != null) {
      leadingWidget = leading;
    } else if (showBackButton) {
      leadingWidget = _OrangePillBackButton(
        onTap: onBack ?? () => Navigator.maybePop(context),
        isDark: isDark,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Container(
        height: preferredSize.height + MediaQuery.of(context).padding.top,
        decoration: BoxDecoration(
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 16,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border(
            bottom: BorderSide(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.border.withValues(alpha: 0.6),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Leading
              if (leadingWidget != null) ...[
                const SizedBox(width: 4),
                SizedBox(width: 52, child: leadingWidget),
              ] else
                const SizedBox(width: 16),

              // Title + subtitle
              Expanded(
                child: centerTitle
                    ? Center(child: _TitleColumn(title: title, subtitle: subtitle, titleColor: titleColor, subtitleColor: subtitleColor))
                    : _TitleColumn(title: title, subtitle: subtitle, titleColor: titleColor, subtitleColor: subtitleColor),
              ),

              // Actions
              if (actions != null)
                ...actions!.map((a) => a),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleColumn extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color titleColor;
  final Color subtitleColor;

  const _TitleColumn({
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    if (subtitle == null || subtitle!.isEmpty) {
      return Text(
        title,
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: titleColor,
          letterSpacing: 0.1,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: titleColor,
            letterSpacing: 0.1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 1),
        Text(
          subtitle!,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: subtitleColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// Orange pill back button — matching the floating nav bar aesthetic
class _OrangePillBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _OrangePillBackButton({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.orange.withValues(alpha: isDark ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.orange,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── AppHeader ───────────────────────────────────────────────────────────────
/// Backward-compatible alias for TwibeeAppBar.
/// Any screen already using AppHeader gets the new design for free.
class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  const AppHeader({super.key, required this.title, this.actions, this.onBack});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return TwibeeAppBar(
      title: title,
      actions: actions,
      onBack: onBack,
    );
  }
}

// ─── AppToggle ───────────────────────────────────────────────────────────────
/// Reusable toggle switch matching the orange theme.
class AppToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const AppToggle({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppColors.white,
      activeTrackColor: AppColors.orange,
      inactiveThumbColor: AppColors.white,
      inactiveTrackColor: AppColors.border,
    );
  }
}

// ─── AppBottomNav ────────────────────────────────────────────────────────────
/// Bottom navigation bar shared across main screens.
class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.orange,
        unselectedItemColor: AppColors.grey,
        showUnselectedLabels: true,
        elevation: 0,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
          BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), label: 'Channels'),
          BottomNavigationBarItem(icon: Icon(Icons.call_outlined), label: 'Calls'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
