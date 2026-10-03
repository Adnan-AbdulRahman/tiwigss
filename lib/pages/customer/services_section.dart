import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

import 'book now.dart';

/// Horizontally scrolling service cards with staggered entrance animation.
/// Tapping a card opens CustomerBookNowPage filtered to that service category.
class ServicesSection extends StatefulWidget {
  const ServicesSection({super.key});

  @override
  State<ServicesSection> createState() => _ServicesSectionState();
}

class _ServicesSectionState extends State<ServicesSection>
    with TickerProviderStateMixin {
  final List<AnimationController> _controllers = [];
  final List<Animation<double>>   _fades       = [];
  final List<Animation<Offset>>   _slides      = [];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < kServices.length; i++) {
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
      _controllers.add(ctrl);
      _fades.add(CurvedAnimation(parent: ctrl, curve: Curves.easeIn));
      _slides.add(
        Tween<Offset>(begin: const Offset(0.4, 0), end: Offset.zero)
            .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic)),
      );

      // Stagger each card by 110ms
      Future.delayed(Duration(milliseconds: 200 + i * 110), () {
        if (mounted) ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  gradient: TwTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text('Our Services',
                  style: TwTheme.displayMd.copyWith(fontSize: 17)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) =>
                    const CustomerBookNowPage(),
                    transitionsBuilder: (_, anim, __, child) =>
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                              parent: anim, curve: Curves.easeOutCubic)),
                          child: child,
                        ),
                    transitionDuration: const Duration(milliseconds: 350),
                  ),
                ),
                child: Text('See all',
                    style: TwTheme.label.copyWith(fontSize: 12)),
              ),
            ],
          ),
        ),

        // ── Horizontally scrolling cards ──────────────────────────────────
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: kServices.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              return FadeTransition(
                opacity: _fades[i],
                child: SlideTransition(
                  position: _slides[i],
                  child: _ServiceCard(
                    service: kServices[i],
                    onTap: () => Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => CustomerBookNowPage(
                          initialCategory: kServices[i].title,
                        ),
                        transitionsBuilder: (_, anim, __, child) =>
                            SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(1, 0),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: anim,
                                  curve: Curves.easeOutCubic)),
                              child: child,
                            ),
                        transitionDuration:
                        const Duration(milliseconds: 350),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Individual service card ────────────────────────────────────────────────────
class _ServiceCard extends StatefulWidget {
  final TwService service;
  final VoidCallback onTap;

  const _ServiceCard({required this.service, required this.onTap});

  @override
  State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.93)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.service;
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapUp: (_) {
        _pressCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          width: 118,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            color: TwTheme.cardBg,
            border: Border.all(color: s.tint.withOpacity(0.25), width: 1),
            boxShadow: [
              BoxShadow(
                color: s.tint.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Emoji in tinted circle
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: s.tint.withOpacity(0.15),
                  border: Border.all(color: s.tint.withOpacity(0.3)),
                ),
                child: Center(
                  child: Text(s.emoji,
                      style: const TextStyle(fontSize: 20)),
                ),
              ),
              // Title + subtitle
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.title,
                      style: TwTheme.titleSm.copyWith(fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(s.subtitle,
                      style: TwTheme.body.copyWith(fontSize: 10),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}