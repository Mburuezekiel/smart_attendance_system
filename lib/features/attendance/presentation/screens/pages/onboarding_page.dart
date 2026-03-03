// lib/features/onboarding/presentation/onboarding_page.dart
//
// Shown once on first launch. After completion, navigates to /login.
// Uses shared_preferences to track whether onboarding was already seen.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with TickerProviderStateMixin {

  final PageController _pageCtrl = PageController();
  int _currentPage = 0;

  static const _green     = Color(0xFF2E7D32);
  static const _greenMid  = Color(0xFF43A047);
  static const _indigo    = Color(0xFF283593);
  static const _teal      = Color(0xFF00695C);

  static const _pages = [
    _OnboardPage(
      gradient: [_green, _greenMid],
      icon: Icons.school_rounded,
      emoji: '🎓',
      title: 'Welcome to\nSmartTrack',
      subtitle: 'Murang\'a University of Technology\'s smart attendance system — fast, accurate, and contactless.',
      badge: 'MUT · SMARTTRACK',
    ),
    _OnboardPage(
      gradient: [_indigo, Color(0xFF3949AB)],
      icon: Icons.fingerprint_rounded,
      emoji: '🔐',
      title: 'Biometric\nAttendance',
      subtitle: 'Mark your attendance in seconds using your fingerprint or face — no queues, no paper.',
      badge: 'SECURE · FAST',
    ),
    _OnboardPage(
      gradient: [_teal, Color(0xFF00796B)],
      icon: Icons.bar_chart_rounded,
      emoji: '📊',
      title: 'Live Analytics\n& Reports',
      subtitle: 'Students track attendance in real-time. Lecturers and admins get instant insights and alerts.',
      badge: 'REAL-TIME DATA',
    ),
    _OnboardPage(
      gradient: [Color(0xFF6A1B9A), Color(0xFF8E24AA)],
      icon: Icons.people_rounded,
      emoji: '🏫',
      title: 'Built For\nEveryone',
      subtitle: 'Dedicated dashboards for students, lecturers, and administrators. One app, three roles.',
      badge: 'STUDENTS · STAFF · ADMIN',
    ),
  ];

  late List<AnimationController> _animControllers;
  late List<Animation<double>>   _fadeAnims;
  late List<Animation<Offset>>   _slideAnims;

  @override
  void initState() {
    super.initState();
    _animControllers = List.generate(_pages.length, (i) =>
        AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _fadeAnims  = _animControllers.map((c) =>
        CurvedAnimation(parent: c, curve: Curves.easeOut)).toList();
    _slideAnims = _animControllers.map((c) =>
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero)
            .animate(CurvedAnimation(parent: c, curve: Curves.easeOutCubic))).toList();
    _animControllers[0].forward();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final c in _animControllers) c.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _animControllers[page].reset();
    _animControllers[page].forward();
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
    if (mounted) context.go('/login');
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _currentPage == _pages.length - 1;
    final page   = _pages[_currentPage];
    final grad   = page.gradient;

    return Scaffold(
      body: Stack(children: [
        // ── Animated background ────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [...grad, grad.last.withOpacity(0.7)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
        ),

        // ── Decorative circles ─────────────────────────────────────────────
        Positioned(top: -60, right: -60, child: Container(
          width: 200, height: 200,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07)))),
        Positioned(bottom: 200, left: -40, child: Container(
          width: 120, height: 120,
          decoration: BoxDecoration(shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05)))),

        // ── Skip button ────────────────────────────────────────────────────
        SafeArea(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 8, right: 16),
              child: TextButton(
                onPressed: _finish,
                child: Text('Skip', style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),

        // ── Page content ───────────────────────────────────────────────────
        PageView.builder(
          controller: _pageCtrl,
          onPageChanged: _onPageChanged,
          itemCount: _pages.length,
          itemBuilder: (_, i) => _buildPage(i),
        ),

        // ── Bottom controls ────────────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 44),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, Colors.black.withOpacity(0.3)],
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
              ),
            ),
            child: Row(children: [
              // Dot indicators
              ...List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 6),
                width: i == _currentPage ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i == _currentPage ? Colors.white : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              )),
              const Spacer(),
              // CTA button
              GestureDetector(
                onTap: _next,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(
                      horizontal: isLast ? 28 : 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(50),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isLast) ...[
                      Text('Get Started',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800,
                              color: _pages[_currentPage].gradient.first)),
                      const SizedBox(width: 8),
                    ],
                    Icon(isLast ? Icons.arrow_forward_rounded : Icons.chevron_right_rounded,
                        color: _pages[_currentPage].gradient.first, size: 22),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildPage(int i) {
    final page = _pages[i];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 60, 28, 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Badge
            FadeTransition(
              opacity: _fadeAnims[i],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(page.badge, style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800,
                    color: Colors.white, letterSpacing: 1.5)),
              ),
            ),
            const Spacer(),

            // Big emoji + icon
            SlideTransition(
              position: _slideAnims[i],
              child: FadeTransition(
                opacity: _fadeAnims[i],
                child: Container(
                  width: 120, height: 120,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Stack(alignment: Alignment.center, children: [
                    Text(page.emoji, style: const TextStyle(fontSize: 52)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Title
            SlideTransition(
              position: _slideAnims[i],
              child: FadeTransition(
                opacity: _fadeAnims[i],
                child: Text(page.title,
                    style: const TextStyle(
                        fontSize: 36, fontWeight: FontWeight.w900,
                        color: Colors.white, height: 1.1, letterSpacing: -0.5)),
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle
            FadeTransition(
              opacity: _fadeAnims[i],
              child: Text(page.subtitle,
                  style: TextStyle(
                      fontSize: 16, color: Colors.white.withOpacity(0.85),
                      height: 1.6, fontWeight: FontWeight.w400)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _OnboardPage {
  final List<Color> gradient;
  final IconData    icon;
  final String      emoji, title, subtitle, badge;

  const _OnboardPage({
    required this.gradient, required this.icon,
    required this.emoji,    required this.title,
    required this.subtitle, required this.badge,
  });
}