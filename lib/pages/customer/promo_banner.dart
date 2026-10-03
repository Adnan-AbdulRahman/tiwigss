import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';


/// Auto-scrolling promo banner carousel
class PromoBanner extends StatefulWidget {
  const PromoBanner({super.key});

  @override
  State<PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<PromoBanner>
    with SingleTickerProviderStateMixin {
  final PageController _pageCtrl = PageController();
  int _currentPage = 0;
  Timer? _autoScrollTimer;

  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeIn;

  static const List<_PromoData> _promos = [
    _PromoData(
      headline: 'New Season,\nNew Wig ✨',
      sub: 'Up to 30% off custom wigs this month',
      emoji: '👑',
      gradientColors: [Color(0xFF8B1A4A), Color(0xFF5C0F30)],
    ),
    _PromoData(
      headline: 'Wig Revamp\nSpecial 💫',
      sub: 'Breathe new life into your old wigs',
      emoji: '✂️',
      gradientColors: [Color(0xFF7A3A8B), Color(0xFF4A1A60)],
    ),
    _PromoData(
      headline: 'Factory Wigs\nNow In Stock 🏭',
      sub: 'Premium ready-to-wear styles available',
      emoji: '💇‍♀️',
      gradientColors: [Color(0xFF3A5A8B), Color(0xFF1A2A60)],
    ),
  ];

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fadeCtrl.forward();
    });

    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _promos.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Column(
          children: [
            // Banner
            SizedBox(
              height: 150,
              child: PageView.builder(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _promos.length,
                itemBuilder: (_, i) => _BannerSlide(promo: _promos[i]),
              ),
            ),
            const SizedBox(height: 10),
            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _promos.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width:  _currentPage == i ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    color: _currentPage == i
                        ? TwTheme.accent
                        : TwTheme.textLow,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single banner slide ────────────────────────────────────────────────────────
class _BannerSlide extends StatelessWidget {
  final _PromoData promo;
  const _BannerSlide({required this.promo});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TwTheme.radiusMd),
        gradient: LinearGradient(
          colors: promo.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: promo.gradientColors.first.withOpacity(0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative large emoji background
          Positioned(
            right: -10,
            top: -10,
            child: Text(
              promo.emoji,
              style: TextStyle(
                fontSize: 100,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Eyebrow
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'TIWIGSSTRAND OFFER',
                    style: TwTheme.caption.copyWith(
                      color: Colors.white70,
                      fontSize: 9,
                    ),
                  ),
                ),
                // Headline
                Text(
                  promo.headline,
                  style: TwTheme.displayMd.copyWith(
                    fontSize: 18,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                // Sub + CTA
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        promo.sub,
                        style: TwTheme.body.copyWith(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {}, // TODO: navigate to promo page
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Shop now',
                          style: TextStyle(
                            color: promo.gradientColors.first,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PromoData {
  final String headline;
  final String sub;
  final String emoji;
  final List<Color> gradientColors;

  const _PromoData({
    required this.headline,
    required this.sub,
    required this.emoji,
    required this.gradientColors,
  });
}
