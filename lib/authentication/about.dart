import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'login and register.dart';

// ── Brand colours ────────────────────────────────────────────────────────────
class _C {
  static const primary     = Color(0xFF49243F);
  static const primaryDark = Color(0xFF2E1228);
  static const accent      = Color(0xFFD6B77A);
  static const accentLight = Color(0xFFEDD9A3);
  static const darkBg      = Color(0xFF1A0A16);
  static const cardBg      = Color(0xFF2E1228);
  static const inputBg     = Color(0xFF3D1A35);
  static const text        = Color(0xFFF7F2E8);
  static const subText     = Color(0xFFD6B77A);
  static const border      = Color(0xFF3D1A35);
  static const success     = Color(0xFF4CAF7D);
  static const error       = Color(0xFFE05C72);
  static const divider     = Color(0xFF3D1A35);
}

bool _isWide(BuildContext ctx) => MediaQuery.of(ctx).size.width >= 900;

const _primaryGrad = LinearGradient(
  colors: [_C.primary, _C.primaryDark],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);
const _accentGrad = LinearGradient(
  colors: [_C.accentLight, _C.accent],
  begin: Alignment.topLeft, end: Alignment.bottomRight,
);
const _bgGrad = RadialGradient(
  center: Alignment(0, -0.4), radius: 1.5,
  colors: [Color(0xFF3D1A35), Color(0xFF0D0510)],
);

// ── Scroll-triggered fade + slide ────────────────────────────────────────────
class _FadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;
  const _FadeSlideIn({required this.index, required this.child});
  @override State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 580));
  late final Animation<double> _anim =
  CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
  ScrollPosition? _pos;
  bool _triggered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final pos = Scrollable.maybeOf(context)?.position;
    if (pos != _pos) {
      _pos?.removeListener(_check);
      _pos = pos;
      _pos?.addListener(_check);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  void _check() {
    if (_triggered || !mounted) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.attached || !ro.hasSize) return;
    final vh = MediaQuery.of(context).size.height;
    if (ro.localToGlobal(Offset.zero).dy < vh * 0.9) {
      _triggered = true;
      _pos?.removeListener(_check);
      Future.delayed(
          Duration(milliseconds: (widget.index * 80).clamp(0, 500)),
              () { if (mounted) _ctrl.forward(); });
    }
  }

  @override
  void dispose() {
    _pos?.removeListener(_check);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, child) => Opacity(
      opacity: _anim.value,
      child: Transform.translate(
          offset: Offset(0, (1 - _anim.value) * 28), child: child),
    ),
    child: widget.child,
  );
}

// ── Eyebrow label ────────────────────────────────────────────────────────────
Widget _eyebrow(String text) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
  decoration: BoxDecoration(
    color: _C.accent.withOpacity(0.12),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: _C.accent.withOpacity(0.35)),
  ),
  child: Text(text,
      style: const TextStyle(
          color: _C.accent,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.2)),
);

// ── URL launcher ─────────────────────────────────────────────────────────────
Future<void> _launchUrl(BuildContext ctx, String url,
    {String? errorMessage}) async {
  final uri = Uri.parse(url);
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(errorMessage ?? 'Could not open link.'),
          backgroundColor: _C.error));
    }
  } catch (e) {
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text('Could not open link: $e'),
          backgroundColor: _C.error));
    }
  }
}

// ── Section container ────────────────────────────────────────────────────────
class _SC extends StatelessWidget {
  final Widget child;
  final Color? bg;
  final EdgeInsetsGeometry? pad;
  const _SC({super.key, required this.child, this.bg, this.pad});
  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return Container(
      width: double.infinity,
      color: bg,
      padding: pad ??
          EdgeInsets.symmetric(
              horizontal: wide ? 60 : 20, vertical: wide ? 88 : 56),
      child: Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100), child: child),
      ),
    );
  }
}

// ── Pressable gradient button ─────────────────────────────────────────────────
class _Btn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool outlined;
  final bool isAccent;
  final VoidCallback onPressed;
  const _Btn({
    required this.label,
    this.icon,
    this.outlined = false,
    this.isAccent = false,
    required this.onPressed,
  });
  @override State<_Btn> createState() => _BtnState();
}

class _BtnState extends State<_Btn> {
  bool _p = false, _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _p = true),
        onTapUp:     (_) { setState(() => _p = false); widget.onPressed(); },
        onTapCancel: () => setState(() => _p = false),
        child: AnimatedScale(
          scale: _p ? 0.96 : (_h ? 1.03 : 1.0),
          duration: const Duration(milliseconds: 140),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: widget.outlined
                  ? null
                  : (widget.isAccent ? _accentGrad : _primaryGrad),
              border: widget.outlined
                  ? Border.all(color: _C.accent, width: 1.6)
                  : null,
              boxShadow: (!widget.outlined && _h)
                  ? [
                BoxShadow(
                  color: (widget.isAccent ? _C.accent : _C.primary)
                      .withOpacity(0.45),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                )
              ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.label,
                    style: TextStyle(
                      color: widget.outlined
                          ? _C.accent
                          : (widget.isAccent ? _C.primaryDark : Colors.white),
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                    )),
                if (widget.icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(widget.icon,
                      color: widget.outlined
                          ? _C.accent
                          : (widget.isAccent ? _C.primaryDark : Colors.white),
                      size: 16),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Animated counter ──────────────────────────────────────────────────────────
class _Counter extends StatelessWidget {
  final int target;
  final String suffix, label;
  const _Counter(
      {required this.target, required this.label, this.suffix = ''});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(children: [
        TweenAnimationBuilder<int>(
          tween: IntTween(begin: 0, end: target),
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text('$v$suffix',
              style: const TextStyle(
                  color: _C.accent, fontSize: 30, fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 6),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: _C.subText, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Full-screen image viewer ──────────────────────────────────────────────────
class _ImageViewer extends StatelessWidget {
  final String asset;
  const _ImageViewer({required this.asset});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white)),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4,
          child: Image.asset(asset,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.white54, size: 64)),
        ),
      ),
    );
  }
}

// ── Contact row ───────────────────────────────────────────────────────────────
class _ContactRow extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String label, subtitle;
  final VoidCallback onTap;
  const _ContactRow(
      {required this.icon,
        required this.color,
        required this.label,
        required this.subtitle,
        required this.onTap});
  @override State<_ContactRow> createState() => _ContactRowState();
}

class _ContactRowState extends State<_ContactRow> {
  bool _h = false, _p = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTapDown:   (_) => setState(() => _p = true),
        onTapUp:     (_) { setState(() => _p = false); widget.onTap(); },
        onTapCancel: () => setState(() => _p = false),
        child: AnimatedScale(
          scale: _p ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _h ? widget.color.withOpacity(0.1) : _C.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _h ? widget.color.withOpacity(0.5) : _C.border),
            ),
            child: Row(children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withOpacity(0.14)),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.label,
                          style: const TextStyle(
                              color: _C.text,
                              fontWeight: FontWeight.bold,
                              fontSize: 13.5)),
                      Text(widget.subtitle,
                          style:
                          const TextStyle(color: _C.subText, fontSize: 11.5)),
                    ]),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  color: widget.color, size: 13),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Contact sheet ────────────────────────────────────────────────────────────
class _ContactSheet extends StatefulWidget {
  const _ContactSheet();
  @override State<_ContactSheet> createState() => _ContactSheetState();
}

class _ContactSheetState extends State<_ContactSheet>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale, _fade;

  static const String _phone  = '233000000000';
  static const String _dispPh = '+233 00 000 0000';
  static const String _email  = 'hello@tiwigsstrand.com';
  static const String _insta  = 'tiwigsstrand';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _fade,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 380),
              decoration: BoxDecoration(
                color: _C.cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: _C.primary.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                      color: _C.primary.withOpacity(0.35),
                      blurRadius: 40,
                      offset: const Offset(0, 20))
                ],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _C.primary.withOpacity(0.12)),
                  child: const Center(
                      child: Text('👑', style: TextStyle(fontSize: 26))),
                ),
                const SizedBox(height: 16),
                const Text('Get in Touch',
                    style: TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 20)),
                const SizedBox(height: 6),
                const Text("We'd love to hear from you",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _C.subText, fontSize: 12.5)),
                const SizedBox(height: 24),
                _FadeSlideIn(
                  index: 0,
                  child: _ContactRow(
                    icon: Icons.chat_bubble_rounded,
                    color: const Color(0xFF25D366),
                    label: 'WhatsApp',
                    subtitle: _dispPh,
                    onTap: () => _launchUrl(context,
                        'https://wa.me/$_phone?text=Hello%20Tiwigsstrand!'),
                  ),
                ),
                const SizedBox(height: 10),
                _FadeSlideIn(
                  index: 1,
                  child: _ContactRow(
                    icon: Icons.phone_rounded,
                    color: _C.accent,
                    label: 'Call Us',
                    subtitle: _dispPh,
                    onTap: () => _launchUrl(context, 'tel:+$_phone'),
                  ),
                ),
                const SizedBox(height: 10),
                _FadeSlideIn(
                  index: 2,
                  child: _ContactRow(
                    icon: Icons.email_rounded,
                    color: const Color(0xFFEA4335),
                    label: 'Email',
                    subtitle: _email,
                    onTap: () => _launchUrl(context,
                        'mailto:$_email?subject=Inquiry%20from%20Website'),
                  ),
                ),
                const SizedBox(height: 10),
                _FadeSlideIn(
                  index: 3,
                  child: _ContactRow(
                    icon: Icons.camera_alt_rounded,
                    color: _C.primary,
                    label: 'Instagram',
                    subtitle: '@$_insta',
                    onTap: () => _launchUrl(
                        context, 'https://www.instagram.com/$_insta'),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text('Close',
                      style: TextStyle(
                          color: _C.subText,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

void _showContact(BuildContext ctx) {
  showGeneralDialog(
    context: ctx,
    barrierDismissible: true,
    barrierLabel: 'Contact',
    barrierColor: Colors.black.withOpacity(0.6),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (_, __, ___) => const _ContactSheet(),
    transitionBuilder: (_, a, __, child) =>
        FadeTransition(opacity: a, child: child),
  );
}

void _goToLogin(BuildContext ctx) {
  Navigator.push(
    ctx,
    PageRouteBuilder(
      pageBuilder: (_, __, ___) => TiwigsstrandLoginPage(),
      transitionsBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
        child: child,
      ),
      transitionDuration: const Duration(milliseconds: 300),
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ANIMATED WIG SHOWCASE CAROUSEL  (new — goes above Our Story text)
// ═══════════════════════════════════════════════════════════════════════════════
class _WigShowcase extends StatefulWidget {
  /// Called when user taps the cart icon — opens contact sheet
  final VoidCallback onCartTap;
  const _WigShowcase({required this.onCartTap});
  @override State<_WigShowcase> createState() => _WigShowcaseState();
}

class _WigShowcaseState extends State<_WigShowcase> {
  final PageController _pageCtrl = PageController(viewportFraction: 0.78);
  int   _current = 0;
  Timer? _autoTimer;

  // ── Wig data — swap assets & prices for your real ones ─────────────────────
  static const List<Map<String, dynamic>> _wigs = [
    {
      'name'    : 'Lace Front Wig',
      'subtitle': 'Human Hair · 18 inches',
      'price'   : 'GH₵ 850',
      'badge'   : '⭐ Best Seller',
      'asset'   : 'assets/images/image1.jpg',
      'color'   : Color(0xFF49243F),
    },
    {
      'name'    : 'Full Lace Wig',
      'subtitle': 'Brazilian Hair · 20 inches',
      'price'   : 'GH₵ 1,200',
      'badge'   : '✨ New Arrival',
      'asset'   : 'assets/images/image1.jpg',
      'color'   : Color(0xFF7A3A8B),
    },
    {
      'name'    : 'Closure Wig',
      'subtitle': 'Peruvian Hair · 16 inches',
      'price'   : 'GH₵ 650',
      'badge'   : '🔥 Hot Deal',
      'asset'   : 'assets/images/image1.jpg',
      'color'   : Color(0xFFD6B77A),
    },
    {
      'name'    : '360 Lace Wig',
      'subtitle': 'Cambodian Hair · 22 inches',
      'price'   : 'GH₵ 1,450',
      'badge'   : '💎 Premium',
      'asset'   : 'assets/images/image1.jpg',
      'color'   : Color(0xFF3A6B8B),
    },
    {
      'name'    : 'Headband Wig',
      'subtitle': 'Synthetic Blend · 14 inches',
      'price'   : 'GH₵ 380',
      'badge'   : '🏷️ Budget Pick',
      'asset'   : 'assets/images/image1.jpg',
      'color'   : Color(0xFF2E7D32),
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  void _startAuto() {
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_current + 1) % _wigs.length;
      _pageCtrl.animateToPage(next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic);
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section eyebrow ──────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              _eyebrow('FEATURED WIGS'),
              const SizedBox(width: 10),
              Text('Swipe to explore',
                  style: TextStyle(
                      color: _C.subText.withOpacity(0.7), fontSize: 11)),
            ],
          ),
        ),

        // ── Carousel ─────────────────────────────────────────────────────────
        SizedBox(
          height: 280,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: _wigs.length,
            itemBuilder: (_, i) {
              final wig    = _wigs[i];
              final active = i == _current;
              return AnimatedScale(
                scale: active ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: active ? 1.0 : 0.65,
                  duration: const Duration(milliseconds: 350),
                  child: _WigCard(
                    wig: wig,
                    onCartTap: widget.onCartTap,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        // ── Dot indicators ────────────────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_wigs.length, (i) {
            final active = i == _current;
            return GestureDetector(
              onTap: () => _pageCtrl.animateToPage(i,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOutCubic),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width:  active ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: active ? _C.accent : _C.border,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

// ── Single wig card in carousel ───────────────────────────────────────────────
class _WigCard extends StatefulWidget {
  final Map<String, dynamic> wig;
  final VoidCallback onCartTap;
  const _WigCard({required this.wig, required this.onCartTap});
  @override State<_WigCard> createState() => _WigCardState();
}

class _WigCardState extends State<_WigCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressCtrl;
  late Animation<double>   _pressScale;
  bool _cartAdded = false;

  @override
  void initState() {
    super.initState();
    _pressCtrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _pressScale = Tween<double>(begin: 1.0, end: 0.95).animate(_pressCtrl);
  }

  @override
  void dispose() { _pressCtrl.dispose(); super.dispose(); }

  void _onCartTap() {
    setState(() => _cartAdded = true);
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _cartAdded = false);
    });
    widget.onCartTap();
  }

  @override
  Widget build(BuildContext context) {
    final wig   = widget.wig;
    final color = wig['color'] as Color;

    return GestureDetector(
      onTapDown:   (_) => _pressCtrl.forward(),
      onTapUp:     (_) => _pressCtrl.reverse(),
      onTapCancel: () => _pressCtrl.reverse(),
      child: ScaleTransition(
        scale: _pressScale,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _C.cardBg,
            border: Border.all(color: color.withOpacity(0.35)),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Background image ─────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  wig['asset'] as String,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: color.withOpacity(0.12),
                    ),
                    child: Center(
                        child: Text('👑',
                            style: TextStyle(
                                fontSize: 52,
                                color: color.withOpacity(0.4)))),
                  ),
                ),
              ),

              // ── Gradient overlay ─────────────────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _C.darkBg.withOpacity(0.92),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.35, 1.0],
                    ),
                  ),
                ),
              ),

              // ── Badge (top-left) ──────────────────────────────────────────
              Positioned(
                top: 12, left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _C.darkBg.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.45)),
                  ),
                  child: Text(wig['badge'] as String,
                      style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ),
              ),

              // ── Cart button (top-right) ───────────────────────────────────
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: _onCartTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _cartAdded ? _C.success : _C.primary,
                      boxShadow: [
                        BoxShadow(
                            color: (_cartAdded ? _C.success : _C.primary)
                                .withOpacity(0.5),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Icon(
                      _cartAdded
                          ? Icons.check_rounded
                          : Icons.shopping_bag_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),

              // ── Name + price (bottom) ─────────────────────────────────────
              Positioned(
                bottom: 14, left: 14, right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(wig['name'] as String,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    const SizedBox(height: 3),
                    Text(wig['subtitle'] as String,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Price pill
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: _accentGrad,
                          ),
                          child: Text(wig['price'] as String,
                              style: const TextStyle(
                                  color: _C.primaryDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13)),
                        ),
                        // Order now mini button
                        GestureDetector(
                          onTap: _onCartTap,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white.withOpacity(0.12),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3)),
                            ),
                            child: const Text('Order now',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  MAIN LANDING PAGE
// ════════════════════════════════════════════════════════════════════════════
class TiwigsstrandAboutPage extends StatefulWidget {
  const TiwigsstrandAboutPage({super.key});
  @override State<TiwigsstrandAboutPage> createState() => _State();
}

class _State extends State<TiwigsstrandAboutPage> {
  final _scroll      = ScrollController();
  final _aboutKey    = GlobalKey();
  final _servicesKey = GlobalKey();
  final _howKey      = GlobalKey();
  final _galleryKey  = GlobalKey();
  final _contactKey  = GlobalKey();
  bool _showTop = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final show = _scroll.offset > 400;
      if (show != _showTop) setState(() => _showTop = show);
    });
  }

  @override void dispose() { _scroll.dispose(); super.dispose(); }

  void _scrollTo(GlobalKey k) {
    final ctx = k.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 620),
          curve: Curves.easeInOutCubic);
    }
  }

  void _toTop() => _scroll.animateTo(0,
      duration: const Duration(milliseconds: 620),
      curve: Curves.easeInOutCubic);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.darkBg,
      appBar: _buildNav(context),
      body: Container(
        decoration: const BoxDecoration(gradient: _bgGrad),
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroSection(
                    onExplore: () => _scrollTo(_servicesKey),
                    onJoin: () => _goToLogin(context)),
                _StatsBand(),
                _AboutSection(
                    sectionKey: _aboutKey,
                    onCartTap: () => _showContact(context)),
                _ServicesSection(
                    sectionKey: _servicesKey,
                    onTap: () => _goToLogin(context)),
                _HowItWorksSection(sectionKey: _howKey),
                _GallerySection(sectionKey: _galleryKey),
                _CtaBanner(onGetStarted: () => _goToLogin(context)),
                _FooterSection(sectionKey: _contactKey),
              ]),
        ),
      ),
      floatingActionButton: IgnorePointer(
        ignoring: !_showTop,
        child: AnimatedOpacity(
          opacity: _showTop ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: AnimatedScale(
            scale: _showTop ? 1 : 0.7,
            duration: const Duration(milliseconds: 250),
            child: FloatingActionButton(
              backgroundColor: _C.primary,
              onPressed: _toTop,
              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNav(BuildContext context) {
    final wide = _isWide(context);
    return PreferredSize(
      preferredSize: const Size.fromHeight(68),
      child: Container(
        decoration: BoxDecoration(
          color: _C.darkBg.withOpacity(0.95),
          border: Border(
              bottom: BorderSide(color: _C.primary.withOpacity(0.2))),
          boxShadow: [
            BoxShadow(
                color: _C.primary.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 2))
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: wide ? 40 : 16),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: _primaryGrad,
                    boxShadow: [
                      BoxShadow(
                          color: _C.primary.withOpacity(0.4),
                          blurRadius: 12)
                    ]),
                child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 18))),
              ),
              const SizedBox(width: 10),
              RichText(
                text: const TextSpan(children: [
                  TextSpan(
                      text: 'Tiwigs',
                      style: TextStyle(
                          color: _C.accent,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5)),
                  TextSpan(
                      text: 'strand',
                      style: TextStyle(
                          color: _C.text,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          letterSpacing: 0.5)),
                ]),
              ),
              const Spacer(),
              if (wide) ...[
                _navLink('Home', _toTop),
                _navLink('About', () => _scrollTo(_aboutKey)),
                _navLink('Services', () => _scrollTo(_servicesKey)),
                _navLink('Gallery', () => _scrollTo(_galleryKey)),
                _navLink('Contact', () => _showContact(context)),
                _navLink('Log In', () => _goToLogin(context)),
                const SizedBox(width: 10),
                _Btn(
                    label: 'Get Started',
                    icon: Icons.arrow_forward_rounded,
                    isAccent: true,
                    onPressed: () => _goToLogin(context)),
              ] else
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: _C.text),
                  onPressed: () => _openMobileMenu(context),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _navLink(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    child: Text(label,
        style: const TextStyle(
            color: _C.subText,
            fontWeight: FontWeight.w600,
            fontSize: 13.5)),
  );

  void _openMobileMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 32),
        decoration: BoxDecoration(
          color: _C.cardBg,
          borderRadius:
          const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _C.primary.withOpacity(0.2)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _C.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Text('👑', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            RichText(
              text: const TextSpan(children: [
                TextSpan(
                    text: 'Tiwigs',
                    style: TextStyle(
                        color: _C.accent,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
                TextSpan(
                    text: 'strand',
                    style: TextStyle(
                        color: _C.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 16)),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          _menuItem(context, 'Home', Icons.home_outlined, _toTop),
          _menuItem(context, 'About', Icons.info_outline_rounded,
                  () => _scrollTo(_aboutKey)),
          _menuItem(context, 'Services', Icons.content_cut_rounded,
                  () => _scrollTo(_servicesKey)),
          _menuItem(context, 'Gallery', Icons.photo_library_outlined,
                  () => _scrollTo(_galleryKey)),
          _menuItem(context, 'Contact Us', Icons.mail_outline_rounded,
                  () => _showContact(context)),
          _menuItem(context, 'Log In', Icons.login_rounded,
                  () => _goToLogin(context)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: _Btn(
                  label: 'Get Started',
                  icon: Icons.arrow_forward_rounded,
                  isAccent: true,
                  onPressed: () {
                    Navigator.pop(context);
                    _goToLogin(context);
                  }),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _menuItem(
      BuildContext ctx, String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
      leading: Icon(icon, color: _C.primary),
      title: Text(label,
          style: const TextStyle(color: _C.text, fontWeight: FontWeight.w600)),
    );
  }
}

// ── HERO ─────────────────────────────────────────────────────────────────────
class _HeroSection extends StatefulWidget {
  final VoidCallback onExplore, onJoin;
  const _HeroSection({required this.onExplore, required this.onJoin});
  @override State<_HeroSection> createState() => _HeroState();
}

class _HeroState extends State<_HeroSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _zoom = AnimationController(
      vsync: this, duration: const Duration(seconds: 22))
    ..repeat(reverse: true);
  late final Animation<double> _zoomAnim = Tween<double>(begin: 1.0, end: 1.14)
      .animate(CurvedAnimation(parent: _zoom, curve: Curves.easeInOut));

  @override void dispose() { _zoom.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return SizedBox(
      height: wide ? 640 : 600,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        AnimatedBuilder(
          animation: _zoomAnim,
          builder: (_, child) =>
              Transform.scale(scale: _zoomAnim.value, child: child),
          child: Image.asset('assets/images/image1.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(gradient: _primaryGrad),
                child: const Center(
                    child: Text('👑', style: TextStyle(fontSize: 80))),
              )),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _C.primaryDark.withOpacity(0.65),
                _C.darkBg.withOpacity(0.95),
              ],
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _FadeSlideIn(
                index: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: _C.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _C.accent.withOpacity(0.45)),
                  ),
                  child: const Text('👑  PREMIUM WIG SERVICES, ON DEMAND',
                      style: TextStyle(
                          color: _C.accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.4)),
                ),
              ),
              const SizedBox(height: 24),
              _FadeSlideIn(
                index: 1,
                child: Text('Tiwigsstrand',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: wide ? 58 : 38,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        letterSpacing: 1)),
              ),
              const SizedBox(height: 10),
              _FadeSlideIn(
                index: 2,
                child: Text(
                    'Wig Making \u00b7 Revamping \u00b7 Styling \u00b7 Factory Wigs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: _C.accent,
                        fontSize: wide ? 16 : 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2)),
              ),
              const SizedBox(height: 14),
              _FadeSlideIn(
                index: 3,
                child: Text(
                    'Your dream wig, crafted to perfection and delivered to your door.\nCustom wigs, revamping, styling and ready-to-wear \u2014 all in one place.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: wide ? 15.5 : 13,
                        height: 1.65)),
              ),
              const SizedBox(height: 34),
              _FadeSlideIn(
                index: 4,
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    _Btn(
                        label: 'Explore Services',
                        icon: Icons.arrow_forward_rounded,
                        isAccent: true,
                        onPressed: widget.onExplore),
                    _Btn(
                        label: 'Get Started',
                        icon: Icons.person_add_rounded,
                        outlined: true,
                        onPressed: widget.onJoin),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ── STATS BAND ────────────────────────────────────────────────────────────────
class _StatsBand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.primary.withOpacity(0.9), _C.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: const Wrap(
            alignment: WrapAlignment.spaceAround,
            runSpacing: 28,
            children: [
              _Counter(target: 300, suffix: '+', label: 'Happy Customers'),
              _Counter(target: 4, label: 'Service Types'),
              _Counter(target: 100, suffix: '%', label: 'Custom Made'),
              _Counter(target: 5, label: 'Star Rating'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── ABOUT (now includes _WigShowcase above the story text) ────────────────────
class _AboutSection extends StatelessWidget {
  final GlobalKey sectionKey;
  final VoidCallback onCartTap;
  const _AboutSection({required this.sectionKey, required this.onCartTap});

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);

    final txt = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _eyebrow('OUR STORY'),
      const SizedBox(height: 14),
      Text('Crafting confidence, one wig at a time',
          style: TextStyle(
              color: _C.text,
              fontSize: wide ? 30 : 24,
              fontWeight: FontWeight.w900,
              height: 1.2)),
      const SizedBox(height: 16),
      const Text(
          'Tiwigsstrand was born from a passion for beautiful, high-quality wigs. We connect customers with expert wig stylists who make, revamp and style wigs to perfection \u2014 so every woman can look and feel her best.',
          style: TextStyle(color: _C.subText, fontSize: 15, height: 1.75)),
      const SizedBox(height: 24),
      ...const [
        'Custom wigs made from scratch to your exact spec',
        'Old wig revamping & restoration service',
        'Professional styling for any occasion',
        'Premium factory wigs \u2014 ready to wear',
      ].map((t) => Padding(
        padding: const EdgeInsets.only(bottom: 11),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
                gradient: _primaryGrad, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 13),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(t,
                style: const TextStyle(
                    color: _C.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      )),
    ]);

    // ── Showcase + story stacked vertically; side-by-side on wide ─────────────
    if (wide) {
      return _SC(
        key: sectionKey,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Left: carousel + story text
          Expanded(
            child: Column(children: [
              _FadeSlideIn(
                  index: 0,
                  child: _WigShowcase(onCartTap: onCartTap)),
              const SizedBox(height: 32),
              _FadeSlideIn(index: 1, child: txt),
            ]),
          ),
          const SizedBox(width: 60),
          // Right: about image (tall, fills the space)
          Expanded(
            child: _FadeSlideIn(
              index: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.asset('assets/images/kolo.jpeg',
                    fit: BoxFit.cover,
                    height: 680,
                    errorBuilder: (_, __, ___) => Container(
                      height: 680,
                      decoration: BoxDecoration(
                        color: _C.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Center(
                          child: Text('👑',
                              style: TextStyle(fontSize: 64))),
                    )),
              ),
            ),
          ),
        ]),
      );
    }

    // Mobile layout — stack vertically
    return _SC(
      key: sectionKey,
      child: Column(children: [
        // Wig showcase carousel
        _FadeSlideIn(index: 0, child: _WigShowcase(onCartTap: onCartTap)),
        const SizedBox(height: 28),
        // About image
        _FadeSlideIn(
          index: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset('assets/images/kolo.jpeg',
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 300,
                  decoration: BoxDecoration(
                      color: _C.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: const Center(
                      child:
                      Text('👑', style: TextStyle(fontSize: 64))),
                )),
          ),
        ),
        const SizedBox(height: 28),
        // Story text
        _FadeSlideIn(index: 2, child: txt),
      ]),
    );
  }
}

// ── SERVICES ──────────────────────────────────────────────────────────────────
class _ServicesSection extends StatelessWidget {
  final GlobalKey sectionKey;
  final VoidCallback onTap;
  const _ServicesSection({required this.sectionKey, required this.onTap});

  static const List<Map<String, dynamic>> _services = [
    {
      'emoji': '🪡',
      'title': 'Wig Making',
      'desc': 'Fully custom wigs crafted from scratch \u2014 any length, texture and style.',
      'color': Color(0xFF49243F),
      'asset': 'assets/images/image1.jpg',
    },
    {
      'emoji': '✨',
      'title': 'Wig Revamping',
      'desc': 'Deep condition, re-curl, re-dye or restore your old wig back to life.',
      'color': Color(0xFF7A3A8B),
      'asset': 'assets/images/image1.jpg',
    },
    {
      'emoji': '💇‍♀️',
      'title': 'Wig Styling',
      'desc': 'Professional styling for any occasion \u2014 flat iron, curls, braids and more.',
      'color': Color(0xFFD6B77A),
      'asset': 'assets/images/image1.jpg',
    },
    {
      'emoji': '🏭',
      'title': 'Factory Wigs',
      'desc': 'Premium ready-to-wear wigs in a range of styles, colors and densities.',
      'color': Color(0xFF3A6B8B),
      'asset': 'assets/images/image1.jpg',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return _SC(
      key: sectionKey,
      bg: _C.cardBg.withOpacity(0.4),
      child: Column(children: [
        _FadeSlideIn(index: 0, child: _eyebrow('OUR SERVICES')),
        const SizedBox(height: 14),
        _FadeSlideIn(
          index: 1,
          child: Text('Everything you need for the perfect wig',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _C.text,
                  fontSize: wide ? 32 : 24,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 10),
        _FadeSlideIn(
          index: 2,
          child: const Text('Tap any service to book',
              textAlign: TextAlign.center,
              style: TextStyle(color: _C.subText, fontSize: 13)),
        ),
        const SizedBox(height: 36),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _services.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 4 : 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: wide ? 0.82 : 0.78,
          ),
          itemBuilder: (_, i) =>
              _ServiceCard(data: _services[i], onTap: onTap),
        ),
      ]),
    );
  }
}

class _ServiceCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _ServiceCard({required this.data, required this.onTap});
  @override State<_ServiceCard> createState() => _ServiceCardState();
}

class _ServiceCardState extends State<_ServiceCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.data['color'] as Color;
    final asset = widget.data['asset'] as String;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _h ? -5 : 0, 0),
          decoration: BoxDecoration(
            color: _C.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _h ? color.withOpacity(0.6) : _C.border,
                width: _h ? 1.5 : 1),
            boxShadow: [
              BoxShadow(
                  color: color.withOpacity(_h ? 0.25 : 0.08),
                  blurRadius: _h ? 24 : 12,
                  offset: const Offset(0, 6))
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(asset,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: color.withOpacity(0.12),
                        child: Center(
                            child: Text(widget.data['emoji'] as String,
                                style: const TextStyle(fontSize: 36))),
                      )),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, color.withOpacity(0.6)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _C.darkBg.withOpacity(0.75),
                        shape: BoxShape.circle,
                      ),
                      child: Text(widget.data['emoji'] as String,
                          style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.data['title'] as String,
                          style: const TextStyle(
                              color: _C.text,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      const SizedBox(height: 5),
                      Expanded(
                        child: Text(widget.data['desc'] as String,
                            style: const TextStyle(
                                color: _C.subText, fontSize: 11, height: 1.45),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(height: 6),
                      Text('Book now \u2192',
                          style: TextStyle(
                              color: _h ? color : _C.subText,
                              fontWeight: FontWeight.bold,
                              fontSize: 11.5)),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── HOW IT WORKS ──────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const _HowItWorksSection({required this.sectionKey});

  static const List<Map<String, dynamic>> _steps = [
    {'title': 'Browse & Pick a Service', 'desc': 'Explore wig making, revamping, styling and factory wigs. Filter by category.', 'icon': Icons.search_rounded},
    {'title': 'Fill Your Details', 'desc': 'Choose your preferred date and time, then tell us your wig specifications.', 'icon': Icons.edit_note_rounded},
    {'title': 'We Get to Work', 'desc': 'Our expert stylists craft, revamp or style your wig to your exact requirements.', 'icon': Icons.content_cut_rounded},
    {'title': 'Look & Feel Amazing', 'desc': 'Collect or receive your wig, then leave a review to help the next customer.', 'icon': Icons.star_rounded},
  ];

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return _SC(
      key: sectionKey,
      child: Column(children: [
        _FadeSlideIn(index: 0, child: _eyebrow('HOW IT WORKS')),
        const SizedBox(height: 14),
        _FadeSlideIn(
          index: 1,
          child: Text('From browsing to glowing in four steps',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _C.text,
                  fontSize: wide ? 32 : 24,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 48),
        Column(
          children: List.generate(_steps.length, (i) {
            final step   = _steps[i];
            final isLast = i == _steps.length - 1;
            return _FadeSlideIn(
              index: i + 2,
              child: IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(
                      width: 46, height: 46,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, gradient: _primaryGrad),
                      child: Center(
                          child: Text('${i + 1}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 17))),
                    ),
                    if (!isLast)
                      Expanded(
                          child: Container(
                              width: 2,
                              color: _C.primary.withOpacity(0.25))),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 32),
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: _C.cardBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _C.primary.withOpacity(0.2)),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: _primaryGrad,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(step['icon'] as IconData,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(step['title'] as String,
                                  style: const TextStyle(
                                      color: _C.text,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15)),
                              const SizedBox(height: 5),
                              Text(step['desc'] as String,
                                  style: const TextStyle(
                                      color: _C.subText,
                                      fontSize: 12.5,
                                      height: 1.55)),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  ),
                ]),
              ),
            );
          }),
        ),
      ]),
    );
  }
}

// ── GALLERY ───────────────────────────────────────────────────────────────────
class _GallerySection extends StatelessWidget {
  final GlobalKey sectionKey;
  const _GallerySection({required this.sectionKey});

  static const List<String> _assets = [
    'assets/images/image1.jpg',
    'assets/images/image1.jpg',
    'assets/images/image1.jpg',
    'assets/images/image1.jpg',
    'assets/images/image1.jpg',
    'assets/images/image1.jpg',
  ];

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return _SC(
      key: sectionKey,
      bg: _C.cardBg.withOpacity(0.3),
      child: Column(children: [
        _FadeSlideIn(index: 0, child: _eyebrow('OUR GALLERY')),
        const SizedBox(height: 14),
        _FadeSlideIn(
          index: 1,
          child: Text('A glimpse of our work',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _C.text,
                  fontSize: wide ? 32 : 24,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 32),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _assets.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: wide ? 3 : 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1,
          ),
          itemBuilder: (_, i) => _GalleryTile(asset: _assets[i]),
        ),
      ]),
    );
  }
}

class _GalleryTile extends StatefulWidget {
  final String asset;
  const _GalleryTile({required this.asset});
  @override State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit:  (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(
                builder: (_) => _ImageViewer(asset: widget.asset))),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(fit: StackFit.expand, children: [
            AnimatedScale(
              scale: _h ? 1.1 : 1.0,
              duration: const Duration(milliseconds: 260),
              child: Image.asset(widget.asset,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      color: _C.primary.withOpacity(0.1),
                      child: const Center(
                          child: Text('👑',
                              style: TextStyle(fontSize: 36))))),
            ),
            AnimatedOpacity(
              opacity: _h ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_C.primaryDark.withOpacity(0.7), Colors.transparent],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
                child: const Center(
                    child: Icon(Icons.zoom_in_rounded,
                        color: Colors.white, size: 32)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── CTA BANNER ────────────────────────────────────────────────────────────────
class _CtaBanner extends StatelessWidget {
  final VoidCallback onGetStarted;
  const _CtaBanner({required this.onGetStarted});

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: _primaryGrad),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: wide ? 80 : 56),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(children: [
            _FadeSlideIn(
                index: 0,
                child: const Text('👑',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 48))),
            const SizedBox(height: 16),
            _FadeSlideIn(
              index: 1,
              child: Text('Ready for your perfect wig?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: wide ? 30 : 24,
                      fontWeight: FontWeight.w900,
                      height: 1.3)),
            ),
            const SizedBox(height: 14),
            _FadeSlideIn(
              index: 2,
              child: Text(
                  'Join Tiwigsstrand today and book your first service in minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 14.5,
                      height: 1.65)),
            ),
            const SizedBox(height: 30),
            _FadeSlideIn(
              index: 3,
              child: _Btn(
                  label: 'Create Your Account',
                  icon: Icons.arrow_forward_rounded,
                  isAccent: true,
                  onPressed: onGetStarted),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── FOOTER ────────────────────────────────────────────────────────────────────
class _FooterSection extends StatelessWidget {
  final GlobalKey sectionKey;
  const _FooterSection({required this.sectionKey});

  static const _phone  = '233000000000';
  static const _dispPh = '+233 00 000 0000';
  static const _email  = 'hello@tiwigsstrand.com';
  static const _insta  = 'tiwigsstrand';

  @override
  Widget build(BuildContext context) {
    final wide = _isWide(context);
    return Container(
      key: sectionKey,
      width: double.infinity,
      color: const Color(0xFF0D0510),
      padding: EdgeInsets.symmetric(
          horizontal: wide ? 60 : 20, vertical: wide ? 64 : 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(children: [
            wide
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: _about()),
              Expanded(child: _links('Quick Links', const ['About', 'Services', 'How It Works', 'Gallery'])),
              Expanded(child: _links('Services', const ['Wig Making', 'Revamping', 'Styling', 'Factory Wigs'])),
              Expanded(child: _contactCol(context)),
            ])
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _about(),
              const SizedBox(height: 28),
              _links('Quick Links', const ['About', 'Services', 'How It Works', 'Gallery']),
              const SizedBox(height: 24),
              _links('Services', const ['Wig Making', 'Revamping', 'Styling', 'Factory Wigs']),
              const SizedBox(height: 24),
              _contactCol(context),
            ]),
            const SizedBox(height: 40),
            Divider(color: Colors.white.withOpacity(0.1), height: 1),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 12,
              children: [
                Text('\u00a9 2026 Tiwigsstrand. All rights reserved.',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 12)),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _social(context, Icons.camera_alt_outlined, 'https://instagram.com/$_insta'),
                  _social(context, Icons.facebook_rounded, 'https://facebook.com/$_insta'),
                  _social(context, Icons.chat_bubble_outline_rounded, 'https://wa.me/$_phone'),
                ]),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Widget _about() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(
        width: 32, height: 32,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, gradient: _primaryGrad),
        child: const Center(child: Text('👑', style: TextStyle(fontSize: 16))),
      ),
      const SizedBox(width: 8),
      RichText(
        text: const TextSpan(children: [
          TextSpan(text: 'Tiwigs', style: TextStyle(color: _C.accent, fontWeight: FontWeight.w900, fontSize: 15)),
          TextSpan(text: 'strand', style: TextStyle(color: _C.text, fontWeight: FontWeight.w900, fontSize: 15)),
        ]),
      ),
    ]),
    const SizedBox(height: 12),
    Text('Premium wig services crafted with love.\nWig Making \u00b7 Revamping \u00b7 Styling \u00b7 Factory Wigs.',
        style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5, height: 1.65)),
  ]);

  Widget _links(String title, List<String> items) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 14),
        ...items.map((l) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(l, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5)),
        )),
      ]);

  Widget _contactCol(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Contact', style: TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 14),
        _cRow(context, Icons.email_outlined, _email, 'mailto:$_email?subject=Inquiry'),
        _cRow(context, Icons.phone_outlined, _dispPh, 'tel:+$_phone'),
        _cRow(context, Icons.chat_bubble_outline_rounded, 'WhatsApp us', 'https://wa.me/$_phone?text=Hello%20Tiwigsstrand!'),
        _cRow(context, Icons.camera_alt_outlined, '@$_insta', 'https://instagram.com/$_insta'),
      ]);

  Widget _cRow(BuildContext ctx, IconData icon, String text, String url) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: () => _launchUrl(ctx, url),
          child: Row(children: [
            Icon(icon, color: Colors.white.withOpacity(0.55), size: 14),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 12.5,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white24)),
            ),
          ]),
        ),
      );

  Widget _social(BuildContext ctx, IconData icon, String url) => Padding(
    padding: const EdgeInsets.only(left: 10),
    child: GestureDetector(
      onTap: () => _launchUrl(ctx, url),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.primary.withOpacity(0.15),
            border: Border.all(color: _C.primary.withOpacity(0.3))),
        child: Icon(icon, color: Colors.white.withOpacity(0.75), size: 16),
      ),
    ),
  );
}