import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart' hide Config;
import '../services/status_service.dart';
import '../theme.dart';

class TextStatusScreen extends StatefulWidget {
  const TextStatusScreen({super.key});

  @override
  State<TextStatusScreen> createState() => _TextStatusScreenState();
}

class _TextStatusScreenState extends State<TextStatusScreen> {
  final TextEditingController _statusController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  final List<Color> _bgColors = [
    const Color(0xFFE74C3C),
    const Color(0xFF9B59B6),
    const Color(0xFF3498DB),
    const Color(0xFF2ECC71),
    const Color(0xFFE67E22),
    AppColors.orange,
    const Color(0xFF2C3E50),
    const Color(0xFF1ABC9C),
  ];
  int _currentColorIndex = 0;

  final List<String> _fonts = [
    'Roboto',
    'Lobster',
    'Pacifico',
    'Oswald',
    'Dancing Script',
    'Cinzel',
    'Creepster',
  ];
  int _currentFontIndex = 0;

  XFile? _backgroundImage;
  bool _showEmoji = false;

  void _changeBgColor() {
    setState(() {
      _backgroundImage = null;
      _currentColorIndex = (_currentColorIndex + 1) % _bgColors.length;
    });
  }

  void _changeFont() {
    setState(() {
      _currentFontIndex = (_currentFontIndex + 1) % _fonts.length;
    });
  }

  Future<void> _pickWallpaper() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _backgroundImage = image;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  void _toggleEmoji() {
    setState(() {
      _showEmoji = !_showEmoji;
      if (_showEmoji) {
        FocusScope.of(context).unfocus();
      } else {
        FocusScope.of(context).requestFocus(_focusNode);
      }
    });
  }

  void _openCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        setState(() {
          _backgroundImage = image;
        });
      }
    } catch (e) {
      // ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    Decoration? bgDecoration;
    if (_backgroundImage != null) {
      bgDecoration = BoxDecoration(
        image: DecorationImage(
          image: kIsWeb ? NetworkImage(_backgroundImage!.path) as ImageProvider : FileImage(File(_backgroundImage!.path)),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.4), BlendMode.darken),
        ),
      );
    } else {
      // Gradient background
      final color = _bgColors[_currentColorIndex];
      bgDecoration = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
      );
    }

    final currentFont = _fonts[_currentFontIndex];

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: bgDecoration,
              child: SafeArea(
                child: Stack(
                  children: [
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: TextField(
                          focusNode: _focusNode,
                          controller: _statusController,
                          style: GoogleFonts.getFont(
                            currentFont,
                            color: Colors.white, 
                            fontSize: 38, 
                            fontWeight: FontWeight.w600,
                            shadows: const [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(0, 2))],
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: 'Type a status',
                            hintStyle: GoogleFonts.getFont(
                              currentFont,
                              color: Colors.white.withValues(alpha: 0.6), 
                              fontSize: 38,
                              shadows: const [Shadow(blurRadius: 4, color: Colors.black45, offset: Offset(0, 2))],
                            ),
                            border: InputBorder.none,
                          ),
                          autofocus: true,
                          maxLines: null,
                          onTap: () {
                            if (_showEmoji) {
                              setState(() {
                                _showEmoji = false;
                              });
                            }
                          },
                        ),
                      ),
                    ),

                    // Floating Pill Control Bar
                    Positioned(
                      bottom: MediaQuery.of(context).viewInsets.bottom + 20, // Keep above keyboard
                      left: 20,
                      right: 80, // Leave space for FAB
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            IconButton(
                              icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: Colors.white),
                              onPressed: _toggleEmoji,
                            ),
                            IconButton(
                              icon: const Icon(Icons.text_fields, color: Colors.white),
                              onPressed: _changeFont,
                            ),
                            IconButton(
                              icon: const Icon(Icons.color_lens, color: Colors.white),
                              onPressed: _changeBgColor,
                            ),
                            IconButton(
                              icon: const Icon(Icons.image, color: Colors.white),
                              onPressed: _pickWallpaper,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_showEmoji)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                textEditingController: _statusController,
                config: const Config(
                  bottomActionBarConfig: BottomActionBarConfig(showBackspaceButton: false, showSearchViewButton: false),
                  categoryViewConfig: CategoryViewConfig(
                    iconColorSelected: AppColors.orange,
                    indicatorColor: AppColors.orange,
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: _showEmoji ? 0 : MediaQuery.of(context).viewInsets.bottom),
        child: FloatingActionButton(
          heroTag: 'send_status_fab',
          onPressed: () async {
            if (_statusController.text.trim().isNotEmpty) {
              String hexColor = '#${_bgColors[_currentColorIndex].toARGB32().toRadixString(16).padLeft(8, '0')}';
              final statusService = context.read<StatusService>();
              try {
                await statusService.postTextStatus(_statusController.text, hexColor, currentFont);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status updated')));
                }
              } catch (e) {
                if (context.mounted) {
                  showDialog(context: context, builder: (_) => AlertDialog(title: const Text('Error'), content: Text(e.toString())));
                }
              }
            } else {
               Navigator.pop(context);
            }
          },
          backgroundColor: AppColors.orange,
          child: const Icon(Icons.send, color: AppColors.white),
        ),
      ),
    );
  }
}

