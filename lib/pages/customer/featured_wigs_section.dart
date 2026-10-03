import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  FEATURED WIGS SECTION  +  WIG DETAIL PAGE
//
//  NEW: Works with inchPricing array from admin
//   inchPricing: [ {inches: '14"', price: 450.0}, {inches: '18"', price: 650.0} ]
//
//  Customer can:
//   1. Browse featured wigs grid
//   2. Tap a wig → WigDetailPage opens (slides up)
//   3. Select their preferred inch length → price updates live
//   4. Tap "Buy Now via WhatsApp" → opens WhatsApp with full details
//      including the chosen inch + price pre-filled in the message
// ─────────────────────────────────────────────────────────────────────────────

// ── WhatsApp number — change to your real number ──────────────────────────────
const String _kWhatsApp = '233506583829';

// ─────────────────────────────────────────────────────────────────────────────
//  FEATURED WIGS SECTION  (grid on homepage)
// ─────────────────────────────────────────────────────────────────────────────
class FeaturedWigsSection extends StatefulWidget {
  const FeaturedWigsSection({super.key});

  @override
  State<FeaturedWigsSection> createState() => _FeaturedWigsSectionState();
}

class _FeaturedWigsSectionState extends State<FeaturedWigsSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _headerCtrl;
  late Animation<double>   _headerFade;

  @override
  void initState() {
    super.initState();
    _headerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _headerFade =
        CurvedAnimation(parent: _headerCtrl, curve: Curves.easeIn);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _headerCtrl.forward();
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header ─────────────────────────────────────────────────
        FadeTransition(
          opacity: _headerFade,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 3, height: 18,
                  decoration: BoxDecoration(
                    gradient: TwTheme.accentGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text('Featured Wigs',
                    style: TwTheme.displayMd.copyWith(fontSize: 17)),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Text('View all',
                      style: TwTheme.label.copyWith(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),

        // ── Firestore stream ───────────────────────────────────────────────
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('wigs')
              .where('featured', isEqualTo: true)
              .limit(6)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _SectionError(message: snapshot.error.toString());
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _WigGridSkeleton();
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) return const _EmptyWigs();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  return _WigCard(
                      data: data, index: i, docId: docs[i].id);
                },
              ),
            );
          },
        ),

        const SizedBox(height: 32),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIG GRID CARD
// ─────────────────────────────────────────────────────────────────────────────
class _WigCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final int index;
  const _WigCard({required this.data, required this.index, required this.docId});

  @override
  State<_WigCard> createState() => _WigCardState();
}

class _WigCardState extends State<_WigCard> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;
  late AnimationController _pressCtrl;
  late Animation<double>   _scaleAnim;
  bool _favourited = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 150 * widget.index), () {
      if (mounted) _ctrl.forward();
    });

    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  // Helper: lowest price from inchPricing OR base price
  String _displayPrice() {
    final base = (widget.data['price'] as num?)?.toDouble() ?? 0;
    final inchPricing = widget.data['inchPricing'];
    if (inchPricing is List && inchPricing.isNotEmpty) {
      final prices = inchPricing
          .map((e) => (e['price'] as num?)?.toDouble() ?? 0)
          .where((p) => p > 0)
          .toList();
      if (prices.isNotEmpty) {
        final minP = prices.reduce((a, b) => a < b ? a : b);
        final maxP = prices.reduce((a, b) => a > b ? a : b);
        if (minP == maxP) return 'GH\u20B5 ${minP.toStringAsFixed(0)}';
        return 'GH\u20B5 ${minP.toStringAsFixed(0)} – ${maxP.toStringAsFixed(0)}';
      }
    }
    return 'GH\u20B5 ${base.toStringAsFixed(0)}';
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) =>
            WigDetailPage(data: widget.data, docId: widget.docId),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
              begin: const Offset(0, 1), end: Offset.zero)
              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name     = widget.data['name']     as String? ?? 'Wig';
    final imageUrl = widget.data['imageUrl'] as String? ?? '';
    final category = widget.data['category'] as String? ?? '';
    final inStock  = widget.data['inStock']  as bool?   ?? true;
    final inchPricing = widget.data['inchPricing'];
    final hasInches   = inchPricing is List && inchPricing.isNotEmpty;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            _openDetail(context);
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: ScaleTransition(
            scale: _scaleAnim,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                color: TwTheme.cardBg,
                border: Border.all(
                    color: TwTheme.primary.withOpacity(0.15), width: 1),
                boxShadow: TwTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image ─────────────────────────────────────────────────
                  Expanded(
                    child: Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(TwTheme.radiusMd)),
                        child: imageUrl.isNotEmpty
                            ? Image.network(imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                            const _ImgPlaceholder())
                            : const _ImgPlaceholder(),
                      ),

                      // Out of stock overlay
                      if (!inStock)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(TwTheme.radiusMd)),
                            child: Container(
                              color: Colors.black.withOpacity(0.55),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: TwTheme.error.withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text('Out of stock',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Category badge
                      if (category.isNotEmpty)
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: TwTheme.darkBg.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: TwTheme.accent.withOpacity(0.4)),
                            ),
                            child: Text(category,
                                style: TwTheme.caption.copyWith(
                                    color: TwTheme.accent, fontSize: 9)),
                          ),
                        ),

                      // Inches available badge
                      if (hasInches)
                        Positioned(
                          bottom: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: TwTheme.primary.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                                '${(inchPricing as List).length} lengths',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),

                      // Favourite
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _favourited = !_favourited),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _favourited
                                  ? TwTheme.primary
                                  : TwTheme.darkBg.withOpacity(0.75),
                              border: Border.all(
                                  color: TwTheme.primary.withOpacity(0.5)),
                            ),
                            child: Icon(
                              _favourited
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: _favourited ? Colors.white : TwTheme.textMid,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ]),
                  ),

                  // ── Info ──────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: TwTheme.titleSm.copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(_displayPrice(),
                                  style: TwTheme.label.copyWith(fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              width: 28, height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: inStock
                                    ? TwTheme.primaryGradient
                                    : null,
                                color: inStock
                                    ? null
                                    : TwTheme.textLow.withOpacity(0.3),
                              ),
                              child: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  color: Colors.white,
                                  size: 13),
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  WIG DETAIL PAGE
// ─────────────────────────────────────────────────────────────────────────────
class WigDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  const WigDetailPage({super.key, required this.data, required this.docId});

  @override
  State<WigDetailPage> createState() => _WigDetailPageState();
}

class _WigDetailPageState extends State<WigDetailPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;
  bool _favourited = false;
  bool _buyLoading = false;

  // Selected inch entry — null means no selection yet (use base price)
  Map<String, dynamic>? _selectedInch;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();

    // Auto-select first inch if available
    final inchPricing = widget.data['inchPricing'];
    if (inchPricing is List && inchPricing.isNotEmpty) {
      _selectedInch = Map<String, dynamic>.from(inchPricing.first as Map);
    }
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  // ── Effective price — from selected inch or base price ─────────────────────
  double get _effectivePrice {
    if (_selectedInch != null) {
      return (_selectedInch!['price'] as num?)?.toDouble() ?? 0;
    }
    return (widget.data['price'] as num?)?.toDouble() ?? 0;
  }

  // ── Parse inchPricing list safely ─────────────────────────────────────────
  List<Map<String, dynamic>> get _inchPricingList {
    final raw = widget.data['inchPricing'];
    if (raw is List) {
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  // ── Build WhatsApp message ─────────────────────────────────────────────────
  String _buildWhatsAppMessage() {
    final d        = widget.data;
    final name     = d['name']        as String? ?? 'Wig';
    final category = d['category']    as String? ?? '';
    final hairType = d['hairType']    as String? ?? '';
    final capSize  = d['capSize']     as String? ?? '';
    final wigType  = d['wigType']     as String? ?? '';
    final density  = d['density']     as String? ?? '';
    final color    = d['color']       as String? ?? '';
    final brand    = d['brand']       as String? ?? '';
    final desc     = d['description'] as String? ?? '';
    final inches   = _selectedInch?['inches'] as String? ?? '';

    final buf = StringBuffer();
    buf.writeln('Hello Tiwigsstrand! \uD83D\uDC51');
    buf.writeln('');
    buf.writeln('I would like to order the following wig:');
    buf.writeln('');
    buf.writeln('\uD83D\uDC86 *Wig:* $name');
    if (category.isNotEmpty) buf.writeln('\uD83D\uDCC2 *Category:* $category');
    if (inches.isNotEmpty)   buf.writeln('\uD83D\uDCCF *Length:* $inches');
    buf.writeln('\uD83D\uDCB0 *Price:* GH\u20B5 ${_effectivePrice.toStringAsFixed(0)}');
    if (hairType.isNotEmpty) buf.writeln('\uD83D\uDC87 *Hair Type:* $hairType');
    if (capSize.isNotEmpty)  buf.writeln('\uD83C\uDFA9 *Cap Size:* $capSize');
    if (wigType.isNotEmpty && wigType != 'None')
      buf.writeln('\u2702\uFE0F *Wig Type:* $wigType');
    if (density.isNotEmpty)  buf.writeln('\uD83D\uDD22 *Density:* $density');
    if (color.isNotEmpty)    buf.writeln('\uD83C\uDFA8 *Color:* $color');
    if (brand.isNotEmpty)    buf.writeln('\uD83C\uDFF7\uFE0F *Brand:* $brand');
    if (desc.isNotEmpty) {
      buf.writeln('');
      buf.writeln('\uD83D\uDCDD *Description:* $desc');
    }
    buf.writeln('');
    buf.writeln('Please confirm availability and next steps. Thank you!');
    return buf.toString();
  }

  Future<void> _openWhatsApp() async {
    if (_inchPricingList.isNotEmpty && _selectedInch == null) {
      _showSnack('Please select your preferred inch length first.');
      return;
    }
    setState(() => _buyLoading = true);
    try {
      final msg = Uri.encodeComponent(_buildWhatsAppMessage());
      final url = 'https://wa.me/$_kWhatsApp?text=$msg';
      final launched =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnack('Could not open WhatsApp. Is it installed?');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _buyLoading = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: TwTheme.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final d        = widget.data;
    final name     = d['name']        as String? ?? 'Wig';
    final imageUrl = d['imageUrl']    as String? ?? '';
    final category = d['category']    as String? ?? '';
    final inStock  = d['inStock']     as bool?   ?? true;
    final desc     = d['description'] as String? ?? '';
    final hairType = d['hairType']    as String? ?? '';
    final capSize  = d['capSize']     as String? ?? '';
    final wigType  = d['wigType']     as String? ?? '';
    final density  = d['density']     as String? ?? '';
    final color    = d['color']       as String? ?? '';
    final brand    = d['brand']       as String? ?? '';
    final stock    = (d['stock'] as num?)?.toInt() ?? 0;
    final inchList = _inchPricingList;

    return Scaffold(
      backgroundColor: TwTheme.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: TwTheme.bgGradient),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            children: [
              // ── Scrollable ───────────────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero image ─────────────────────────────────────
                      _HeroImage(
                        imageUrl: imageUrl,
                        inStock: inStock,
                        isFavourited: _favourited,
                        onBack: () => Navigator.pop(context),
                        onFavourite: () =>
                            setState(() => _favourited = !_favourited),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Category + stock badges ─────────────────
                            Row(children: [
                              if (category.isNotEmpty)
                                _Pill(
                                    label: _categoryEmoji(category) + '  $category',
                                    color: TwTheme.primary,
                                    light: true),
                              const SizedBox(width: 8),
                              _Pill(
                                label: inStock ? '\u2705  In Stock' : '\u274C  Out of Stock',
                                color: inStock ? TwTheme.success : TwTheme.error,
                                light: true,
                              ),
                            ]),

                            const SizedBox(height: 12),

                            // ── Name ────────────────────────────────────
                            Text(name,
                                style: TwTheme.displayMd.copyWith(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900)),

                            const SizedBox(height: 10),

                            // ── Live price display ───────────────────────
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Row(
                                key: ValueKey(_effectivePrice),
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'GH\u20B5 ${_effectivePrice.toStringAsFixed(0)}',
                                    style: TwTheme.label.copyWith(
                                        fontSize: 28,
                                        color: TwTheme.accent),
                                  ),
                                  if (_selectedInch != null) ...[
                                    const SizedBox(width: 8),
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'for ${_selectedInch!['inches']}',
                                        style: TwTheme.body.copyWith(
                                            fontSize: 12,
                                            color: TwTheme.textMid),
                                      ),
                                    ),
                                  ],
                                  if (stock > 0 && inStock) ...[
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: Colors.red
                                        ),
                                      ),
                                      child: Text('$stock left',
                                          style: TwTheme.caption.copyWith(
                                              color: Colors.red,
                                              fontSize: 11)),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // ── Description ─────────────────────────────
                            if (desc.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text(desc,
                                  style: TwTheme.body.copyWith(
                                      fontSize: 14, height: 1.7)),
                            ],

                            // ── INCH SELECTOR ────────────────────────────
                            if (inchList.isNotEmpty) ...[
                              const SizedBox(height: 20),
                              _InchSelector(
                                inchPricing: inchList,
                                selected: _selectedInch,
                                onSelect: (entry) =>
                                    setState(() => _selectedInch = entry),
                              ),
                            ],

                            // ── Specs ─────────────────────────────────────
                            const SizedBox(height: 20),
                            _SpecsCard(fields: {
                              if (hairType.isNotEmpty) 'Hair Type': hairType,
                              if (capSize.isNotEmpty)  'Cap Size':  capSize,
                              if (wigType.isNotEmpty && wigType != 'None')
                                'Wig Type': wigType,
                              if (density.isNotEmpty)  'Density':   density,
                              if (color.isNotEmpty)    'Color':     color,
                              if (brand.isNotEmpty)    'Brand':     brand,
                            }),

                            const SizedBox(height: 16),

                            // ── WhatsApp note ─────────────────────────────
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                borderRadius:
                                BorderRadius.circular(TwTheme.radiusMd),
                                color: const Color(0xFF25D366).withOpacity(0.08),
                                border: Border.all(
                                    color: const Color(0xFF25D366)
                                        .withOpacity(0.3)),
                              ),
                              child: Row(children: [
                                const Text('\uD83D\uDCAC',
                                    style: TextStyle(fontSize: 22)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        const Text('Order via WhatsApp',
                                            style: TextStyle(
                                                color: Color(0xFF25D366),
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        const SizedBox(height: 3),
                                        Text(
                                          inchList.isNotEmpty
                                              ? 'Select your preferred length above then tap Buy Now.'
                                              : 'Tap "Buy Now" and all wig details will be sent automatically.',
                                          style: TwTheme.body.copyWith(fontSize: 11),
                                        ),
                                      ]),
                                ),
                              ]),
                            ),

                            const SizedBox(height: 100),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Bottom action bar ─────────────────────────────────────────
              _BottomBar(
                inStock: inStock,
                isLoading: _buyLoading,
                price: _effectivePrice,
                selectedInch: _selectedInch?['inches'] as String?,
                onBuyNow: _openWhatsApp,
                isFavourited: _favourited,
                onFavourite: () =>
                    setState(() => _favourited = !_favourited),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Wig Making':  return '\uD83E\uDDF5';
      case 'Revamping':   return '\u2728';
      case 'Styling':     return '\uD83D\uDC87\u200D\u2640\uFE0F';
      case 'Factory Wig': return '\uD83C\uDFED';
      default:            return '\uD83D\uDC51';
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  INCH SELECTOR  — the new component
// ─────────────────────────────────────────────────────────────────────────────
class _InchSelector extends StatelessWidget {
  final List<Map<String, dynamic>> inchPricing;
  final Map<String, dynamic>?      selected;
  final void Function(Map<String, dynamic>) onSelect;

  const _InchSelector({
    required this.inchPricing,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TwTheme.radiusMd),
        color: TwTheme.cardBg,
        border: Border.all(color: TwTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(children: [
            const Text('\uD83D\uDCCF',
                style: TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text('Select Length',
                style: TwTheme.titleSm.copyWith(fontSize: 14)),
            const Spacer(),
            if (selected != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  gradient: TwTheme.accentGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selected!['inches'] as String,
                  style: const TextStyle(
                      color: TwTheme.primaryDark,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
          ]),

          const SizedBox(height: 6),
          Text(
            'Each length has its own price. Tap to select yours.',
            style: TwTheme.body.copyWith(fontSize: 11),
          ),

          const SizedBox(height: 14),
          Container(height: 1, color: TwTheme.divider),
          const SizedBox(height: 14),

          // Inch grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.5,
            ),
            itemCount: inchPricing.length,
            itemBuilder: (_, i) {
              final entry   = inchPricing[i];
              final inches  = entry['inches'] as String;
              final price   = (entry['price'] as num?)?.toDouble() ?? 0;
              final isSelected = selected != null &&
                  selected!['inches'] == inches;

              return GestureDetector(
                onTap: () => onSelect(entry),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                    color: isSelected
                        ? TwTheme.primary.withOpacity(0.18)
                        : TwTheme.darkBg.withOpacity(0.5),
                    border: Border.all(
                      color: isSelected
                          ? TwTheme.primary.withOpacity(0.8)
                          : TwTheme.divider,
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                      BoxShadow(
                          color: TwTheme.primary.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Inch label
                      Text(
                        inches,
                        style: TextStyle(
                          color: isSelected
                              ? TwTheme.accent
                              : TwTheme.textHigh,
                          fontWeight: isSelected
                              ? FontWeight.w900
                              : FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Price
                      Text(
                        'GH\u20B5 ${price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: isSelected
                              ? TwTheme.accent
                              : TwTheme.textMid,
                          fontSize: 10,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      // Selected tick
                      if (isSelected) ...[
                        const SizedBox(height: 3),
                        Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: TwTheme.primaryGradient,
                          ),
                          child: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 10),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  HERO IMAGE
// ─────────────────────────────────────────────────────────────────────────────
class _HeroImage extends StatelessWidget {
  final String imageUrl;
  final bool   inStock, isFavourited;
  final VoidCallback onBack, onFavourite;

  const _HeroImage({
    required this.imageUrl,
    required this.inStock,
    required this.isFavourited,
    required this.onBack,
    required this.onFavourite,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 340,
      width: double.infinity,
      child: Stack(fit: StackFit.expand, children: [
        imageUrl.isNotEmpty
            ? Image.network(imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _ImgPlaceholder())
            : const _ImgPlaceholder(),

        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                TwTheme.darkBg.withOpacity(0.85),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.45, 1.0],
            ),
          ),
        ),

        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: TwTheme.darkBg.withOpacity(0.7),
                      border: Border.all(
                          color: TwTheme.primary.withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                GestureDetector(
                  onTap: onFavourite,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFavourited
                          ? TwTheme.primary
                          : TwTheme.darkBg.withOpacity(0.7),
                      border: Border.all(
                          color: TwTheme.primary.withOpacity(0.4)),
                    ),
                    child: Icon(
                      isFavourited
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: Colors.white, size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (!inStock)
          Positioned(
            bottom: 16, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 7),
                decoration: BoxDecoration(
                  color: TwTheme.error.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Out of Stock',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold)),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SPECS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SpecsCard extends StatelessWidget {
  final Map<String, String> fields;
  const _SpecsCard({required this.fields});

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TwTheme.radiusMd),
        color: TwTheme.cardBg,
        border: Border.all(color: TwTheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Specifications', style: TwTheme.titleSm.copyWith(fontSize: 13)),
          const SizedBox(height: 12),
          Container(height: 1, color: TwTheme.divider),
          const SizedBox(height: 12),
          ...fields.entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 90,
                  child: Text(e.key,
                      style: TwTheme.caption
                          .copyWith(color: TwTheme.textLow, fontSize: 11)),
                ),
                Expanded(
                  child: Text(e.value,
                      style: TwTheme.body.copyWith(
                          fontSize: 12,
                          color: TwTheme.textHigh,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  BOTTOM ACTION BAR
// ─────────────────────────────────────────────────────────────────────────────
class _BottomBar extends StatefulWidget {
  final bool         inStock, isLoading, isFavourited;
  final double       price;
  final String?      selectedInch;
  final VoidCallback onBuyNow, onFavourite;

  const _BottomBar({
    required this.inStock,
    required this.isLoading,
    required this.isFavourited,
    required this.price,
    required this.selectedInch,
    required this.onBuyNow,
    required this.onFavourite,
  });

  @override
  State<_BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<_BottomBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(_ctrl);
  }

  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 14, 20, MediaQuery.of(context).padding.bottom + 14),
      decoration: BoxDecoration(
        color: TwTheme.cardBg,
        border: Border(top: BorderSide(color: TwTheme.divider, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Row(children: [
        // Fav button
        GestureDetector(
          onTap: widget.onFavourite,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(TwTheme.radiusMd),
              color: widget.isFavourited ? TwTheme.primary : TwTheme.darkBg,
              border: Border.all(color: TwTheme.primary.withOpacity(0.4)),
            ),
            child: Icon(
              widget.isFavourited
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: widget.isFavourited ? Colors.white : TwTheme.textMid,
              size: 22,
            ),
          ),
        ),

        const SizedBox(width: 14),

        // Buy Now button
        Expanded(
          child: GestureDetector(
            onTapDown: widget.inStock ? (_) => _ctrl.forward() : null,
            onTapUp: widget.inStock
                ? (_) {
              _ctrl.reverse();
              if (!widget.isLoading) widget.onBuyNow();
            }
                : null,
            onTapCancel: () => _ctrl.reverse(),
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                  gradient: widget.inStock
                      ? const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                      : null,
                  color: widget.inStock
                      ? null
                      : TwTheme.textLow.withOpacity(0.3),
                  boxShadow: widget.inStock
                      ? [
                    BoxShadow(
                        color: const Color(0xFF25D366).withOpacity(0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4)),
                  ]
                      : [],
                ),
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                      width: 24, height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5))
                      : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('\uD83D\uDCAC',
                          style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.inStock
                                ? 'Buy Now via WhatsApp'
                                : 'Out of Stock',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold),
                          ),
                          if (widget.inStock && widget.selectedInch != null)
                            Text(
                              'GH\u20B5 ${widget.price.toStringAsFixed(0)}  \u00b7  ${widget.selectedInch}',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 10),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SHARED HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _Pill extends StatelessWidget {
  final String label;
  final Color  color;
  final bool   light;
  const _Pill({required this.label, required this.color, this.light = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(light ? 0.12 : 1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: light ? color : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  const _ImgPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      color: TwTheme.primary.withOpacity(0.12),
      child: Center(
        child: Text('\uD83D\uDC51',
            style: TextStyle(
                fontSize: 48,
                color: TwTheme.primary.withOpacity(0.4))),
      ),
    );
  }
}

class _EmptyWigs extends StatelessWidget {
  const _EmptyWigs();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TwTheme.radiusMd),
          color: TwTheme.cardBg,
          border: Border.all(color: TwTheme.divider),
        ),
        child: Column(children: [
          const Text('\uD83D\uDC51', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('No wigs listed yet',
              style: TwTheme.titleSm.copyWith(color: TwTheme.textMid)),
          const SizedBox(height: 6),
          Text('Check back soon \u2014 our stylists are adding new pieces.',
              textAlign: TextAlign.center,
              style: TwTheme.body.copyWith(fontSize: 12)),
        ]),
      ),
    );
  }
}

class _WigGridSkeleton extends StatefulWidget {
  const _WigGridSkeleton();
  @override State<_WigGridSkeleton> createState() => _WigGridSkeletonState();
}

class _WigGridSkeletonState extends State<_WigGridSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.25, end: 0.6)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: 4,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                color: TwTheme.cardBg.withOpacity(_anim.value)),
          ),
        ),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  final String message;
  const _SectionError({required this.message});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TwTheme.radiusMd),
          color: TwTheme.error.withOpacity(0.1),
          border: Border.all(color: TwTheme.error.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline_rounded, color: TwTheme.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Could not load wigs. Please try again.',
                style: TwTheme.body.copyWith(color: TwTheme.error)),
          ),
        ]),
      ),
    );
  }
}