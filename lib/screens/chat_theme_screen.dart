import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme.dart';
import '../services/settings_service.dart';
import 'dart:ui';

class ChatThemeScreen extends StatefulWidget {
  final String? chatId;

  const ChatThemeScreen({super.key, this.chatId});

  @override
  State<ChatThemeScreen> createState() => _ChatThemeScreenState();
}

class _ChatThemeScreenState extends State<ChatThemeScreen> {
  late PageController _pageController;
  int _currentIndex = 0;

  final List<ChatTheme> _themes = ChatTheme.themes;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.65);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<SettingsService>();
      final currentId = widget.chatId != null 
          ? settings.getSetting('chat_theme_${widget.chatId}', defaultValue: settings.getSetting('chat_theme_id'))
          : settings.getSetting('chat_theme_id');
      
      if (currentId == null && widget.chatId == null) {
        settings.updateSetting('chat_theme_id', 'default');
        settings.updateSetting('chat_bubble_color', _themes[0].bubbleColor.value);
        settings.updateSetting('chat_bg_color', _themes[0].bgColor.value);
      }

      final activeId = currentId ?? 'default';
      int idx = _themes.indexWhere((t) => t.id == activeId);
      if (idx != -1) {
        _pageController.jumpToPage(idx);
        setState(() => _currentIndex = idx);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsService>();
    final isCustomThemeSet = widget.chatId != null && settings.getSetting('chat_theme_${widget.chatId}') != null;
    final selectedThemeId = widget.chatId != null 
        ? settings.getSetting('chat_theme_${widget.chatId}', defaultValue: settings.getSetting('chat_theme_id', defaultValue: 'default'))
        : settings.getSetting('chat_theme_id', defaultValue: 'default');

    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      extendBodyBehindAppBar: true,
      appBar: const TwibeeAppBar(
        title: 'Chat Experience',
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          // Dynamic background gradient/image based on current theme
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: _themes[_currentIndex].bgGradient ?? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _themes[_currentIndex].bgColor.withOpacity(0.6),
                  AppColors.dark,
                ],
              ),
              image: _themes[_currentIndex].bgImageUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(_themes[_currentIndex].bgImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            ),
          ),
          
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 20),
              children: [
                const Text('Choose Your Style', textAlign: TextAlign.center, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.white, letterSpacing: -0.5)),
                const SizedBox(height: 8),
                Text(_themes[_currentIndex].desc, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppColors.white.withOpacity(0.8))),
                const SizedBox(height: 24),

                // Font Selection
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      'Inter',
                      'Roboto',
                      'Nunito',
                      'Poppins',
                      'Comic Neue',
                      'JetBrains Mono',
                      'Lobster',
                      'Playfair Display'
                    ].map((fontName) {
                      final currentFont = widget.chatId != null
                          ? settings.getSetting('chat_font_${widget.chatId}', defaultValue: settings.getSetting('chat_font', defaultValue: 'Inter'))
                          : settings.getSetting('chat_font', defaultValue: 'Inter');
                      final isSelected = currentFont == fontName;
                      return GestureDetector(
                        onTap: () {
                          if (widget.chatId != null) {
                            settings.updateSetting('chat_font_${widget.chatId}', fontName);
                          } else {
                            settings.updateSetting('chat_font', fontName);
                          }
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.white : AppColors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            fontName,
                            style: GoogleFonts.getFont(
                              fontName,
                              color: isSelected ? AppColors.dark : AppColors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Premium Carousel
                SizedBox(
                  height: 380,
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (idx) => setState(() => _currentIndex = idx),
                    itemCount: _themes.length,
                    itemBuilder: (context, index) {
                      final theme = _themes[index];
                      final isSelected = theme.id == selectedThemeId;
                      return _buildCarouselItem(index, theme, isSelected, settings);
                    },
                  ),
                ),

                const SizedBox(height: 20),

                // Customization Panel
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.orange.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.palette_outlined, color: AppColors.orange),
                            ),
                            title: const Text('Custom Colors', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Fine-tune your chat bubbles', style: TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              final currentBubbleColor = Color(settings.getSetting('chat_bubble_color', defaultValue: 0xFFFF6B00));
                              Color pickerColor = currentBubbleColor;
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return AlertDialog(
                                    title: const Text('Pick a color!'),
                                    content: SingleChildScrollView(
                                      child: BlockPicker(
                                        pickerColor: currentBubbleColor,
                                        onColorChanged: (Color color) {
                                          pickerColor = color;
                                        },
                                      ),
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                        child: const Text('Got it'),
                                        onPressed: () {
                                          settings.updateSetting('chat_bubble_color', pickerColor.value);
                                          setState(() {});
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            },
                          ),
                          Divider(height: 1, color: AppColors.grey.withOpacity(0.1)),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: AppColors.blue.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.wallpaper, color: AppColors.blue),
                            ),
                            title: const Text('Wallpaper', style: TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: const Text('Change chat background', style: TextStyle(fontSize: 12)),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                              if (image != null) {
                                settings.updateSetting('chat_wallpaper_path', image.path);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallpaper updated!')));
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                ),
                if (widget.chatId != null && isCustomThemeSet) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.9),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Remove Custom Theme', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        // Remove custom theme keys for this chat
                        final s = settings.settings;
                        s.remove('chat_theme_${widget.chatId}');
                        s.remove('chat_bubble_color_${widget.chatId}');
                        s.remove('chat_bg_color_${widget.chatId}');
                        s.remove('chat_wallpaper_path_${widget.chatId}');
                        settings.updateSettings(s);
                        setState(() {
                           final gId = settings.getSetting('chat_theme_id', defaultValue: 'default');
                           final idx = _themes.indexWhere((t) => t.id == gId);
                           if (idx != -1) {
                             _pageController.jumpToPage(idx);
                             _currentIndex = idx;
                           }
                        });
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Custom theme removed!')));
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarouselItem(int index, ChatTheme theme, bool isSelected, SettingsService settings) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double value = 1.0;
        if (_pageController.position.haveDimensions) {
          value = _pageController.page! - index;
          value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
        } else {
          value = index == _currentIndex ? 1.0 : 0.7;
        }

        return Center(
          child: SizedBox(
            height: Curves.easeOut.transform(value) * 380,
            width: Curves.easeOut.transform(value) * 220,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () {
          _pageController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
          if (widget.chatId != null) {
            settings.updateSetting('chat_theme_${widget.chatId}', theme.id);
            settings.updateSetting('chat_bubble_color_${widget.chatId}', theme.bubbleColor.value);
            settings.updateSetting('chat_bg_color_${widget.chatId}', theme.bgColor.value);
          } else {
            settings.updateSetting('chat_theme_id', theme.id);
            settings.updateSetting('chat_bubble_color', theme.bubbleColor.value);
            settings.updateSetting('chat_bg_color', theme.bgColor.value);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
          decoration: BoxDecoration(
            color: theme.bgColor,
            gradient: theme.bgGradient,
            image: theme.bgImageUrl != null
                ? DecorationImage(
                    image: CachedNetworkImageProvider(theme.bgImageUrl!),
                    fit: BoxFit.cover,
                  )
                : null,
            borderRadius: BorderRadius.circular(32),
            boxShadow: isSelected ? [
              BoxShadow(
                color: theme.bubbleColor.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ] : [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
            ],
            border: isSelected ? Border.all(color: theme.bubbleColor, width: 3) : null,
          ),
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
              // Mock chat bubbles
              _buildMockBubble(isSent: false, color: theme.receiverBubbleColor, width: 100, theme: theme, settings: settings),
              const SizedBox(height: 16),
              _buildMockBubble(isSent: true, color: theme.bubbleColor, width: 120, theme: theme, settings: settings),
              const SizedBox(height: 16),
              _buildMockBubble(isSent: false, color: theme.receiverBubbleColor, width: 80, theme: theme, settings: settings),
              
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  theme.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.dark, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: AppColors.white, size: 20),
                ),
            ],
          ),
        ), // Closes SingleChildScrollView
        ),
      ),
    );
  }

  Widget _buildMockBubble({required bool isSent, required Color color, required double width, required ChatTheme theme, required SettingsService settings}) {
    final currentFont = widget.chatId != null
        ? settings.getSetting('chat_font_${widget.chatId}', defaultValue: settings.getSetting('chat_font', defaultValue: 'Inter'))
        : settings.getSetting('chat_font', defaultValue: 'Inter');

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(left: isSent ? 20 : 20, right: isSent ? 20 : 20),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: width),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isSent ? 16 : 4),
            bottomRight: Radius.circular(isSent ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          isSent ? 'Hello!' : 'Hi there!',
          style: GoogleFonts.getFont(
            currentFont,
            color: isSent ? theme.senderTextColor : theme.receiverTextColor,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

