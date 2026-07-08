import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme.dart';
import '../utils/permission_utils.dart';
import 'phone_number_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _agreedToTerms = false;

  Future<void> _showTermsDialog(bool showPrivacy) async {
    final url = Uri.parse(
      showPrivacy 
        ? 'https://twibee2.web.app/privacy-policy.html' 
        : 'https://twibee2.web.app/terms.html'
    );
    
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not launch ${showPrivacy ? 'Privacy Policy' : 'Terms'}')),
        );
      }
    }
  }

  void _onGetStarted() async {
    if (!_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Please accept Terms & Privacy Policy first'),
            ],
          ),
          backgroundColor: AppColors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }
    await PermissionUtils.requestAllPermissions(context);
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PhoneNumberScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          // Top Half (Orange background with graphic)
          SizedBox(
            height: size.height * 0.52,
            width: double.infinity,
            child: Stack(
              children: [
                Container(color: AppColors.orange, width: double.infinity, height: double.infinity),
                Positioned(
                  top: -50, left: -50,
                  child: Container(width: 200, height: 200,
                    decoration: const BoxDecoration(color: AppColors.orangeLight, shape: BoxShape.circle)),
                ),
                Positioned(
                  bottom: -100, right: -80,
                  child: Container(width: 250, height: 250,
                    decoration: const BoxDecoration(color: Color(0xFFD35400), shape: BoxShape.circle)),
                ),
                Center(
                  child: Container(
                    width: 180, height: 280,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, 8))],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildChatBubble(true, AppColors.orangePale, 100),
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerRight, child: _buildChatBubble(false, AppColors.border, 90)),
                      const SizedBox(height: 16),
                      _buildChatBubble(true, AppColors.orangePale, 110),
                      const SizedBox(height: 16),
                      Align(alignment: Alignment.centerRight, child: _buildChatBubble(false, AppColors.border, 80)),
                    ]),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Half
          Expanded(
            child: Container(
              color: AppColors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stay Connected,\n', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.dark, height: 0.5)),
                  const Text('Always.', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: AppColors.orange)),
                  const SizedBox(height: 12),
                  const Text(
                    'The best of WhatsApp & Telegram\ncombined in one powerful app.',
                    style: TextStyle(fontSize: 15, color: AppColors.grey, height: 1.5),
                  ),
                  const Spacer(),

                  // ── Terms & Conditions Checkbox ──
                  GestureDetector(
                    onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 22,
                          height: 22,
                          margin: const EdgeInsets.only(top: 1),
                          decoration: BoxDecoration(
                            color: _agreedToTerms ? AppColors.orange : Colors.transparent,
                            border: Border.all(
                              color: _agreedToTerms ? AppColors.orange : AppColors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: _agreedToTerms
                              ? const Icon(Icons.check, color: Colors.white, size: 14)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: AppColors.grey, height: 1.5),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()..onTap = () => _showTermsDialog(false),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()..onTap = () => _showTermsDialog(true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Get Started Button ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onGetStarted,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _agreedToTerms ? AppColors.orange : AppColors.grey.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        elevation: _agreedToTerms ? 4 : 0,
                        shadowColor: AppColors.orange.withValues(alpha: 0.4),
                      ),
                      child: const Text('Get Started', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.white)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: GestureDetector(
                      onTap: _onGetStarted,
                      child: RichText(
                        text: const TextSpan(
                          text: 'Already have an account? ',
                          style: TextStyle(color: AppColors.grey, fontSize: 15),
                          children: [TextSpan(text: 'Log In', style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold))],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatBubble(bool isLeft, Color color, double width) {
    return Container(
      width: width, height: 28,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
    );
  }
}

