import 'package:flutter/material.dart';

class ChatTheme {
  final String id;
  final String name;
  final String desc;
  final String type; // 'color', 'gradient', 'image'
  final Color bgColor;
  final Color bubbleColor; // Sender bubble (My Message)
  final Color receiverBubbleColor;
  final Color senderTextColor;
  final Color receiverTextColor;
  final Color timeColor;
  final LinearGradient? bgGradient;
  final String? bgImageUrl;

  const ChatTheme({
    required this.id,
    required this.name,
    required this.desc,
    required this.type,
    required this.bgColor,
    required this.bubbleColor,
    required this.receiverBubbleColor,
    required this.senderTextColor,
    required this.receiverTextColor,
    required this.timeColor,
    this.bgGradient,
    this.bgImageUrl,
  });

  static const List<ChatTheme> themes = [
    // 1. WhatsApp Classic (Doodle Background)
    ChatTheme(
      id: 'whatsapp_classic',
      name: 'Classic Chat',
      desc: 'The iconic light green bubble with doodle background.',
      type: 'image',
      bgColor: Color(0xFFE5DDD5),
      bgImageUrl: 'https://user-images.githubusercontent.com/15075759/28719144-86dc0f70-73b1-11e7-911d-60d70fcded21.png',
      bubbleColor: Color(0xFFDCF8C6), // Light WhatsApp Green
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF303030),
      receiverTextColor: Color(0xFF303030),
      timeColor: Color(0xFF8A9AA9),
    ),
    // 2. Abstract Fluid (Aesthetic Wallpaper)
    ChatTheme(
      id: 'abstract_fluid',
      name: 'Abstract Fluid',
      desc: 'Beautiful abstract flowing colors background.',
      type: 'image',
      bgColor: Color(0xFFF0F0F0),
      bgImageUrl: 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?q=80&w=600&auto=format&fit=crop', // Lightweight abstract img
      bubbleColor: Color(0xFFE0E7FF), // Soft Indigo/Blue
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF1E1E24),
      receiverTextColor: Color(0xFF1E1E24),
      timeColor: Color(0xFF8D99AE),
    ),
    // 3. Floral Doodle (Design Wallpaper)
    ChatTheme(
      id: 'floral_doodle',
      name: 'Floral Doodle',
      desc: 'Elegant floral pattern with peach chat bubbles.',
      type: 'image',
      bgColor: Color(0xFFFDFBF7),
      bgImageUrl: 'https://images.unsplash.com/photo-1579546929518-9e396f3cc809?q=80&w=600&auto=format&fit=crop',
      bubbleColor: Color(0xFFFFEDD5), 
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF431407),
      receiverTextColor: Color(0xFF431407),
      timeColor: Color(0xFFC2A385),
    ),
    // 4. Pastel Clouds (Abstract Light Wallpaper)
    ChatTheme(
      id: 'pastel_clouds',
      name: 'Pastel Clouds',
      desc: 'Dreamy sky and clouds abstract background.',
      type: 'image',
      bgColor: Color(0xFFF0F9FF),
      bgImageUrl: 'https://images.unsplash.com/photo-1509803874385-db7c23652552?q=80&w=600&auto=format&fit=crop',
      bubbleColor: Color(0xFFE0F2FE), 
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF0C4A6E),
      receiverTextColor: Color(0xFF0C4A6E),
      timeColor: Color(0xFF7DD3FC),
    ),
    // 5. Minimal Waves (Abstract Design Wallpaper)
    ChatTheme(
      id: 'minimal_waves',
      name: 'Minimal Waves',
      desc: 'Modern wavy design with mint green bubbles.',
      type: 'image',
      bgColor: Color(0xFFF0FDF4),
      bgImageUrl: 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?q=80&w=600&auto=format&fit=crop',
      bubbleColor: Color(0xFFD1FAE5), 
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF064E3B),
      receiverTextColor: Color(0xFF064E3B),
      timeColor: Color(0xFF6EE7B7),
    ),
    // 6. Twibee Signature (Soft Orange)
    ChatTheme(
      id: 'default',
      name: 'Twibee Signature',
      desc: 'Light, modern pastel orange.',
      type: 'color',
      bgColor: Color(0xFFF9F9FB),
      bubbleColor: Color(0xFFFFE5D9), // Very light pastel orange
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF4A2B1E), // Dark brownish orange for contrast
      receiverTextColor: Color(0xFF2D3436),
      timeColor: Color(0xFF9E9E9E),
    ),
    // 7. Lavender Mist
    ChatTheme(
      id: 'lavender_mist',
      name: 'Lavender Mist',
      desc: 'Elegant, calming light lilac.',
      type: 'color',
      bgColor: Color(0xFFFAF9FE),
      bubbleColor: Color(0xFFF3E8FF), // Light Lilac
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF3B205E),
      receiverTextColor: Color(0xFF374151),
      timeColor: Color(0xFFA78BFA),
    ),
    // 8. Mint Breeze
    ChatTheme(
      id: 'mint_breeze',
      name: 'Mint Breeze',
      desc: 'Soothing pastel mint.',
      type: 'color',
      bgColor: Color(0xFFF2FBF5),
      bubbleColor: Color(0xFFD1FAE5), // Light Mint
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF064E3B),
      receiverTextColor: Color(0xFF1F2937),
      timeColor: Color(0xFF9CA3AF),
    ),
    // 9. Cloudy Sky
    ChatTheme(
      id: 'cloudy_sky',
      name: 'Cloudy Sky',
      desc: 'Cool, light professional blue.',
      type: 'color',
      bgColor: Color(0xFFF8FAFC),
      bubbleColor: Color(0xFFE0F2FE), // Light Sky Blue
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF0C4A6E),
      receiverTextColor: Color(0xFF334155),
      timeColor: Color(0xFF94A3B8),
    ),
    // 10. Peach Cream
    ChatTheme(
      id: 'peach_cream',
      name: 'Peach Cream',
      desc: 'Sweet, warm pastel peach.',
      type: 'color',
      bgColor: Color(0xFFFFFBF9),
      bubbleColor: Color(0xFFFFEDD5), // Light Peach
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF7C2D12),
      receiverTextColor: Color(0xFF431407),
      timeColor: Color(0xFFC2A385),
    ),
    // 11. Sakura Whisper
    ChatTheme(
      id: 'sakura_whisper',
      name: 'Sakura Whisper',
      desc: 'Delicate light cherry blossom pink.',
      type: 'color',
      bgColor: Color(0xFFFFF5F7),
      bubbleColor: Color(0xFFFCE7F3), // Light Pink
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF831843),
      receiverTextColor: Color(0xFF4A4A4A),
      timeColor: Color(0xFFD6A8B8),
    ),
    // 12. Ocean Sand
    ChatTheme(
      id: 'ocean_sand',
      name: 'Ocean Sand',
      desc: 'Premium combination of warm sand and soft teal.',
      type: 'color',
      bgColor: Color(0xFFF9F8F6),
      bubbleColor: Color(0xFFCCFBF1), // Light Teal
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF115E59),
      receiverTextColor: Color(0xFF264653),
      timeColor: Color(0xFF94A3B8),
    ),
    // 13. Vanilla Latte
    ChatTheme(
      id: 'vanilla_latte',
      name: 'Vanilla Latte',
      desc: 'Warm and comfortable creamy beige.',
      type: 'color',
      bgColor: Color(0xFFFDFBF7),
      bubbleColor: Color(0xFFFEF3C7), // Light Latte/Beige
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF78350F),
      receiverTextColor: Color(0xFF5D4037),
      timeColor: Color(0xFFA1887F),
    ),
    // 14. Icy Cyan
    ChatTheme(
      id: 'icy_cyan',
      name: 'Icy Cyan',
      desc: 'Futuristic, cool pale cyan.',
      type: 'color',
      bgColor: Color(0xFFF2F9F9),
      bubbleColor: Color(0xFFCFFAFE), // Pale Cyan
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF164E63),
      receiverTextColor: Color(0xFF1E293B),
      timeColor: Color(0xFF94A3B8),
    ),
    // 15. Monochrome Minimalist
    ChatTheme(
      id: 'monochrome_minimalist',
      name: 'Monochrome Minimalist',
      desc: 'Strict minimalist light grey focus.',
      type: 'color',
      bgColor: Color(0xFFF5F5F5),
      bubbleColor: Color(0xFFE5E7EB), // Distinct Light Grey
      receiverBubbleColor: Color(0xFFFFFFFF),
      senderTextColor: Color(0xFF111827),
      receiverTextColor: Color(0xFF212121),
      timeColor: Color(0xFF9E9E9E),
    ),
  ];

  static ChatTheme getTheme(String id) {
    return themes.firstWhere((t) => t.id == id, orElse: () => themes[0]);
  }
}

