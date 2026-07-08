import 'dart:async';
import 'package:flutter/material.dart';
import '../theme.dart';
import 'welcome_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  // Arrow bounce animation (same as original)
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Page auto-slide
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoSlideTimer;

  final List<Map<String, dynamic>> _slides = const [
    {
      'image': 'assets/images/onboard1.png',
      'title': 'Stay Connected',
      'subtitle': 'Always.',
    },
    {
      'image': 'assets/images/onboard2.png',
      'title': 'Express Yourself',
      'subtitle': 'Freely.',
    },
    {
      'image': 'assets/images/onboard3.png',
      'title': 'Private & Secure',
      'subtitle': 'Always.',
    },
  ];

  @override
  void initState() {
    super.initState();

    // Original bounce animation for arrow button
    _bounceController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: 15).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Auto-slide images every 2.5 seconds
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoSlideTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goToWelcome() {
    _autoSlideTimer?.cancel();
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const WelcomeScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.orange,
      body: Stack(
        children: [
          // ── Top left decorative circle ──
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: const BoxDecoration(
                color: AppColors.orangeLight,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // ── Top right decorative circle ──
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                color: AppColors.orangeLight.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // ── Bottom decorative semi-circle with PAGE DOTS ──
          Positioned(
            bottom: -150,
            left: -50,
            right: -50,
            child: Container(
              height: 400,
              decoration: const BoxDecoration(
                color: Color(0xFFD35400),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 80),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _currentPage ? 20 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: i == _currentPage ? 1.0 : 0.45),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  );
                }),
              ),
            ),
          ),

          // ── Sliding Image in the center ──
          Positioned(
            top: 170,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.44,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (_, i) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Image.asset(
                    _slides[i]['image']!,
                    fit: BoxFit.contain,
                  ),
                );
              },
            ),
          ),

          // ── App name + subtitle (same as original) ──
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Push down below image
                SizedBox(height: MediaQuery.of(context).size.height * 0.44 + 60),
                // App Name
                const Text(
                  'Twibee',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    _slides[_currentPage]['subtitle']!,
                    key: ValueKey(_currentPage),
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.white,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── App Logo (top-center) ──
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Image.asset(
                'assets/images/logo.png',
                height: 70,
                errorBuilder: (context, error, stackTrace) => const SizedBox(height: 70),
              ),
            ),
          ),

          // ── Animated Arrow Button (ORIGINAL DESIGN) ──
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedBuilder(
                animation: _bounceAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -_bounceAnimation.value),
                    child: child,
                  );
                },
                child: InkWell(
                  onTap: _goToWelcome,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_forward_ios, color: AppColors.orange, size: 24),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

