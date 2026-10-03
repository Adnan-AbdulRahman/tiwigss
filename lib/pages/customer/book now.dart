import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:tiwigsstrand/pages/customer/tw_theme.dart';

import 'booking form.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CUSTOMER BOOK NOW PAGE
//  Opens when user taps any service card on the home screen.
//  Shows all services from Firestore grouped/filtered by category.
//  Tapping a service card opens BookingFormPage for that specific service.
// ─────────────────────────────────────────────────────────────────────────────
class CustomerBookNowPage extends StatefulWidget {
  /// Pass a category to pre-filter (e.g. 'Wig Making', 'Styling')
  final String? initialCategory;

  const CustomerBookNowPage({super.key, this.initialCategory});

  @override
  State<CustomerBookNowPage> createState() => _CustomerBookNowPageState();
}

class _CustomerBookNowPageState extends State<CustomerBookNowPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double>   _fade;

  String _selectedCategory = 'All';

  static const List<Map<String, String>> _categories = [
    {'key': 'All',         'emoji': '👑'},
    {'key': 'Wig Making',  'emoji': '🪡'},
    {'key': 'Revamping',   'emoji': '✨'},
    {'key': 'Styling',     'emoji': '💇‍♀️'},
    {'key': 'Factory Wig', 'emoji': '🏭'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Query<Map<String, dynamic>> get _query {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('wigs');
    if (_selectedCategory != 'All') {
      q = q.where('category', isEqualTo: _selectedCategory);
    }
    return q;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TwTheme.darkBg,
      body: Container(
        decoration: const BoxDecoration(gradient: TwTheme.bgGradient),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── App bar ────────────────────────────────────────────────
                _buildAppBar(context),

                const SizedBox(height: 16),

                // ── Category filter ────────────────────────────────────────
                _buildCategoryFilter(),

                const SizedBox(height: 8),

                // ── Info banner ────────────────────────────────────────────
                _buildInfoBanner(),

                const SizedBox(height: 12),

                // ── Services grid ──────────────────────────────────────────
                Expanded(child: _buildServicesGrid()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── App bar ─────────────────────────────────────────────────────────────────
  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TwTheme.cardBg,
                border: Border.all(color: TwTheme.primary.withOpacity(0.3)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: TwTheme.textMid, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Book a Service', style: TwTheme.displayMd),
                Text(
                  _selectedCategory == 'All'
                      ? 'All services available'
                      : _selectedCategory,
                  style: TwTheme.body.copyWith(
                      color: TwTheme.accent, fontSize: 12),
                ),
              ],
            ),
          ),
          // Crown brand mark
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TwTheme.primary.withOpacity(0.12),
              border: Border.all(color: TwTheme.primary.withOpacity(0.3)),
            ),
            child: const Center(
                child: Text('👑', style: TextStyle(fontSize: 20))),
          ),
        ],
      ),
    );
  }

  // ── Category filter pills ────────────────────────────────────────────────────
  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final cat    = _categories[i];
          final active = _selectedCategory == cat['key'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: active ? TwTheme.primary : TwTheme.cardBg,
                border: Border.all(
                  color: active
                      ? TwTheme.primary
                      : TwTheme.primary.withOpacity(0.2),
                ),
                boxShadow: active
                    ? [BoxShadow(
                    color: TwTheme.primary.withOpacity(0.35),
                    blurRadius: 10)]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(cat['emoji']!,
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(cat['key']!,
                      style: TextStyle(
                        color: active ? Colors.white : TwTheme.textMid,
                        fontWeight:
                        active ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Info banner ──────────────────────────────────────────────────────────────
  Widget _buildInfoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(TwTheme.radiusMd),
          color: TwTheme.primary.withOpacity(0.08),
          border: Border.all(color: TwTheme.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap any service to fill your details and confirm your booking.',
                style: TwTheme.body.copyWith(fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Services grid (Firestore) ─────────────────────────────────────────────────
  Widget _buildServicesGrid() {
    return StreamBuilder<QuerySnapshot>(
      stream: _query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _BookNowSkeleton();
        }
        if (snapshot.hasError) {
          return _BookNowError(message: snapshot.error.toString());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return _BookNowEmpty(category: _selectedCategory);
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          physics: const BouncingScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.68,
          ),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _BookNowServiceCard(
              docId: docs[i].id,
              data: data,
              index: i,
            );
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SERVICE CARD  — opens BookingFormPage on tap
// ─────────────────────────────────────────────────────────────────────────────
class _BookNowServiceCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final int index;

  const _BookNowServiceCard({
    required this.docId,
    required this.data,
    required this.index,
  });

  @override
  State<_BookNowServiceCard> createState() => _BookNowServiceCardState();
}

class _BookNowServiceCardState extends State<_BookNowServiceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _fade;
  late Animation<Offset>   _slide;
  late AnimationController _pressCtrl;
  late Animation<double>   _scale;

  @override
  void initState() {
    super.initState();

    // Entrance animation
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 450));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _slide = Tween<Offset>(
        begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) _ctrl.forward();
    });

    // Press scale
    _pressCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _pressCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  Color _categoryColor(String cat) {
    switch (cat) {
      case 'Wig Making':  return TwTheme.primary;
      case 'Revamping':   return const Color(0xFF7A3A8B);
      case 'Styling':     return TwTheme.accent;
      case 'Factory Wig': return const Color(0xFF3A6B8B);
      default:            return TwTheme.primary;
    }
  }

  String _categoryEmoji(String cat) {
    switch (cat) {
      case 'Wig Making':  return '🪡';
      case 'Revamping':   return '✨';
      case 'Styling':     return '💇‍♀️';
      case 'Factory Wig': return '🏭';
      default:            return '👑';
    }
  }

  void _openBookingForm() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => BookingFormPage(
          serviceId:   widget.docId,
          serviceData: widget.data,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name     = widget.data['name']        as String? ?? 'Service';
    final price    = (widget.data['price'] as num?)?.toDouble() ?? 0;
    final imageUrl = widget.data['imageUrl']    as String? ?? '';
    final category = widget.data['category']    as String? ?? '';
    final inStock  = widget.data['inStock']     as bool?   ?? true;
    final desc     = widget.data['description'] as String? ?? '';
    final color    = _categoryColor(category);
    final emoji    = _categoryEmoji(category);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: GestureDetector(
          onTapDown: (_) => _pressCtrl.forward(),
          onTapUp: (_) {
            _pressCtrl.reverse();
            if (inStock) _openBookingForm();
          },
          onTapCancel: () => _pressCtrl.reverse(),
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(TwTheme.radiusMd),
                color: TwTheme.cardBg,
                border: Border.all(color: color.withOpacity(0.22)),
                boxShadow: [
                  BoxShadow(
                      color: color.withOpacity(0.16),
                      blurRadius: 14,
                      offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Image area ─────────────────────────────────────────
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Image or placeholder
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(TwTheme.radiusMd)),
                          child: imageUrl.isNotEmpty
                              ? Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _ImgPlaceholder(
                                    color: color, emoji: emoji),
                          )
                              : _ImgPlaceholder(color: color, emoji: emoji),
                        ),

                        // Unavailable overlay
                        if (!inStock)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(TwTheme.radiusMd)),
                              child: Container(
                                color: Colors.black.withOpacity(0.6),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: TwTheme.error,
                                      borderRadius:
                                      BorderRadius.circular(20),
                                    ),
                                    child: const Text('Unavailable',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        // Category badge (top-left)
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: TwTheme.darkBg.withOpacity(0.82),
                              borderRadius: BorderRadius.circular(20),
                              border:
                              Border.all(color: color.withOpacity(0.4)),
                            ),
                            child: Text('$emoji $category',
                                style: TextStyle(
                                    color: color,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ),

                        // "Book" pill (top-right) — only when in stock
                        if (inStock)
                          Positioned(
                            top: 8, right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: TwTheme.primary,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text('Book',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // ── Info area ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name
                        Text(name,
                            style: TwTheme.titleSm.copyWith(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),

                        // Description
                        if (desc.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(desc,
                              style: TwTheme.body.copyWith(fontSize: 10),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],

                        const SizedBox(height: 6),

                        // Price row
                        Row(
                          mainAxisAlignment:
                          MainAxisAlignment.spaceBetween,
                          children: [
                            Text('GH₵ ${price.toStringAsFixed(0)}',
                                style:
                                TwTheme.label.copyWith(fontSize: 13)),
                            if (inStock)
                              Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: TwTheme.primaryGradient,
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
//  HELPERS
// ─────────────────────────────────────────────────────────────────────────────
class _ImgPlaceholder extends StatelessWidget {
  final Color  color;
  final String emoji;
  const _ImgPlaceholder({required this.color, required this.emoji});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withOpacity(0.1),
      child: Center(
        child: Text(emoji,
            style: TextStyle(
                fontSize: 36, color: color.withOpacity(0.4))),
      ),
    );
  }
}

class _BookNowEmpty extends StatelessWidget {
  final String category;
  const _BookNowEmpty({required this.category});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👑', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 14),
            Text(
              category == 'All'
                  ? 'No services available yet'
                  : 'No $category services yet',
              style: TwTheme.displayMd,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Our team is adding new services soon.\nCheck back shortly!',
              textAlign: TextAlign.center,
              style: TwTheme.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookNowError extends StatelessWidget {
  final String message;
  const _BookNowError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: TwTheme.error, size: 44),
            const SizedBox(height: 12),
            const Text('Could not load services',
                style: TwTheme.displayMd),
            const SizedBox(height: 8),
            Text(message,
                style: TwTheme.body, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton grid loader ───────────────────────────────────────────────────────
class _BookNowSkeleton extends StatefulWidget {
  const _BookNowSkeleton();

  @override
  State<_BookNowSkeleton> createState() => _BookNowSkeletonState();
}

class _BookNowSkeletonState extends State<_BookNowSkeleton>
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

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.68,
        ),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TwTheme.radiusMd),
            color: TwTheme.cardBg.withOpacity(_anim.value),
          ),
        ),
      ),
    );
  }
}