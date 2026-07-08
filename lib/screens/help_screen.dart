import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../widgets/settings_group.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  final List<_FaqItem> _faqs = const [
    _FaqItem(
      q: 'How do I create a group?',
      a: 'Tap the compose/edit icon on the Chats screen, then select "New Group". Add participants, set a group name and photo, then tap Create.',
    ),
    _FaqItem(
      q: 'How do I enable two-step verification?',
      a: 'Go to Settings → Account → Two-step verification. Scan the QR code with an authenticator app (Google Authenticator, Authy) and enter the 6-digit code to verify.',
    ),
    _FaqItem(
      q: 'How do I block someone?',
      a: 'Open the contact\'s profile and scroll down to tap "Block". Or go to Settings → Privacy → Blocked Contacts and add them there.',
    ),
    _FaqItem(
      q: 'How do I delete my account?',
      a: 'Go to Settings → Account → Delete account. Note: this will permanently delete all your messages, profile data, and settings.',
    ),
    _FaqItem(
      q: 'Why are my messages not delivering?',
      a: 'Check your internet connection. If the issue persists, try force-quitting the app and reopening it. Make sure notifications are enabled in your device settings.',
    ),
    _FaqItem(
      q: 'How do I save a message?',
      a: 'Long-press any message in a chat and tap "Save". View all saved messages in Settings → Saved Messages.',
    ),
    _FaqItem(
      q: 'How do I change my profile photo?',
      a: 'Tap your profile photo or name at the top of the Settings tab, then tap the camera icon on your avatar.',
    ),
    _FaqItem(
      q: 'How do I export a chat?',
      a: 'Open the chat, tap the group/contact name to open Info, then scroll down to find "Export chat" option.',
    ),
  ];
  Future<void> _sendFeedback() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'twibee7@gmail.com',
      query: Uri.encodeFull('subject=Twibee Feedback&body=Hi Twibee Team,\n\n'),
    );
    final messenger = ScaffoldMessenger.of(context);
    if (!await launchUrl(emailUri)) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open email app. Contact: twibee7@gmail.com')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGrey,
      appBar: const TwibeeAppBar(title: 'Twibee', subtitle: 'Version 1.0.0', centerTitle: true),
      body: ListView(
        children: [
          // ── Hero ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.orange.withValues(alpha: 0.15),
                      AppColors.orange.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.help_outline, size: 60, color: AppColors.orange),
              ),
            ),
          ),

          // ── Contact & Feedback ──
          SettingsGroup(
            children: [
              SettingsItem(
                title: 'Send feedback',
                subtitle: 'Report issues or suggest improvements',
                icon: Icons.feedback_outlined,
                iconBackgroundColor: AppColors.orange,
                onTap: _sendFeedback,
              ),
              SettingsItem(
                title: 'Email us',
                subtitle: 'twibee7@gmail.com',
                icon: Icons.mail_outline,
                iconBackgroundColor: AppColors.orange,
                showDivider: false,
                onTap: _sendFeedback,
              ),
            ],
          ),

          // ── FAQ ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Frequently Asked Questions',
              style: TextStyle(
                color: AppColors.dark.withValues(alpha: 0.5),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: _faqs.asMap().entries.map((entry) {
                  final i = entry.key;
                  final faq = entry.value;
                  return _FaqTile(faq: faq, showDivider: i < _faqs.length - 1);
                }).toList(),
              ),
            ),
          ),

          // ── Legal ──
          SettingsGroup(
            footer: '© 2026 Twibee. All rights reserved.',
            children: [
              SettingsItem(
                title: 'Terms and Privacy Policy',
                icon: Icons.privacy_tip_outlined,
                iconBackgroundColor: AppColors.orange,
                onTap: () async {
                  final uri = Uri.parse('https://Twibee.app/privacy');
                  final messenger = ScaffoldMessenger.of(context);
                  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Visit: Twibee.app/privacy')),
                    );
                  }
                },
              ),
              SettingsItem(
                title: 'Licenses',
                icon: Icons.receipt_long_outlined,
                iconBackgroundColor: AppColors.orange,
                showDivider: false,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Twibee',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2026 Twibee',
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FaqItem {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});
}

class _FaqTile extends StatefulWidget {
  final _FaqItem faq;
  final bool showDivider;
  const _FaqTile({required this.faq, required this.showDivider});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.faq.q,
                    style: const TextStyle(
                      color: AppColors.dark,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.keyboard_arrow_down,
                      color: AppColors.grey, size: 22),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Text(
              widget.faq.a,
              style: const TextStyle(
                  color: AppColors.grey, fontSize: 14, height: 1.5),
            ),
          ),
          crossFadeState:
              _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        if (widget.showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: AppColors.lightGrey),
          ),
      ],
    );
  }
}

